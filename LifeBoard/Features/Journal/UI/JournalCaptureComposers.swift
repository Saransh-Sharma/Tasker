import SwiftUI

// Journal's two capture surfaces.
//
// Extracted from `LifeBoardTrackAndJournalViews.swift` rather than converted in
// place: that file is pinned by the file-size ratchet and may only shrink, and
// the migration adds a section struct per section. Removing these two takes
// roughly 280 lines and two top-level types off it, which is the direction the
// baseline wants anyway.

// MARK: - Text

struct JournalTextComposer: View {
    let prompt: JournalPrompt
    let initialText: String
    let onDraftChanged: (String, Int?) -> Void
    /// Returns whether the entry reached disk, so the commit control can report
    /// what actually happened instead of assuming.
    let onSave: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var committed = false
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0

    init(
        prompt: JournalPrompt,
        initialText: String,
        onDraftChanged: @escaping (String, Int?) -> Void,
        onSave: @escaping (String) async -> Bool
    ) {
        self.prompt = prompt
        self.initialText = initialText
        self.onDraftChanged = onDraftChanged
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        ComposerScaffold(
            title: "Write",
            subtitle: prompt.supportiveCopy,
            titleDisplayMode: .inline,
            // Journal prose is the most obviously sensitive content in the
            // product and was rendering unredacted in the app switcher.
            isPrivacySensitive: true,
            identifier: "journal.text.composer"
        ) {
            JournalTextPromptSection(prompt: prompt, text: $text)
        } commit: {
            ComposerCommitBar(
                title: "Save entry",
                phase: commitPhase,
                isEnabled: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                identifier: "journal.text.commit",
                action: commit
            )
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
        .task(id: text) {
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard committed == false else { return }
                onDraftChanged(text, text.count)
            } catch {
                return
            }
        }
        .onDisappear {
            guard committed == false else { return }
            onDraftChanged(text, text.count)
        }
    }

    private func commit() {
        guard case .running = commitPhase else {
            commitPhase = .running(progress: nil)
            Task {
                if await onSave(text) {
                    // Only now. Setting `committed` before the await would
                    // discard the draft on a failed save and lose the entry.
                    committed = true
                    commitPhase = .success(receipt: ComposerReceipt())
                    successTrigger &+= 1
                    dismiss()
                } else {
                    commitPhase = .recoverableFailure(.init(
                        message: "The entry could not be saved. Your draft is still here.",
                        recovery: .retry
                    ))
                }
            }
            return
        }
    }
}

private struct JournalTextPromptSection: View {
    let prompt: JournalPrompt
    @Binding var text: String

    var body: some View {
        // The prompt title becomes the section header and its supportive copy
        // the scaffold subtitle: prose on the canvas, the control on clay.
        ComposerSection(
            prompt.title,
            footer: "Drafts are saved as you type and stay on this device."
        ) {
            ComposerField(
                "Journal text",
                prompt: "Write whatever is true right now",
                text: $text,
                shape: .prose(lineLimit: 6...24),
                identifier: "journal.text.body"
            )
        }
    }
}

// MARK: - Audio

struct JournalAudioCapture: View {
    enum Purpose { case journal, search }

    let purpose: Purpose
    let onSave: (String, TimeInterval, String?) async -> Bool
    let onTranscription: (String, String?) async -> Void
    let onDiscard: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = JournalAudioRecorder()
    @State private var capturedURL: URL?
    @State private var capturedDuration: TimeInterval = 0
    @State private var transcribes: Bool
    @State private var isTranscribing = false
    @State private var showsConsent = false
    @State private var transcription: String?
    @State private var manualTranscription = ""
    @State private var processingState: JournalMediaAttachment.ProcessingState = .ready
    @State private var didPersist = false
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0

    init(
        purpose: Purpose = .journal,
        onSave: @escaping (String, TimeInterval, String?) async -> Bool,
        onTranscription: @escaping (String, String?) async -> Void = { _, _ in },
        onDiscard: @escaping (String) async -> Void = { _ in }
    ) {
        self.purpose = purpose
        self.onSave = onSave
        self.onTranscription = onTranscription
        self.onDiscard = onDiscard
        _transcribes = State(initialValue: purpose == .search)
    }

    var body: some View {
        ComposerScaffold(
            title: purpose == .search ? "Voice Search" : "Voice Journal",
            subtitle: purpose == .search
                ? "The temporary recording is deleted after transcription. Journal content is searched only inside LifeBoard."
                : "Audio is file-protected and stays on this device. Only its duration and optional transcription sync privately.",
            cancelTitle: didPersist ? "Done" : "Cancel",
            titleDisplayMode: .inline,
            isPrivacySensitive: purpose == .journal,
            identifier: "journal.audio.composer",
            // A swipe-down mid-recording used to drop the audio silently.
            isDismissBlocked: recorder.isRecording,
            onCancel: { if didPersist == false { recorder.cancel() } }
        ) {
            JournalAudioRecorderSection(
                recorder: recorder,
                capturedURL: capturedURL,
                onToggle: toggleRecording
            )
            JournalAudioTranscriptionSection(
                isTranscribing: isTranscribing,
                transcription: transcription
            )
            if processingState == .transcriptionFailed {
                JournalAudioRecoverySection(
                    purpose: purpose,
                    manualTranscription: $manualTranscription,
                    onRetry: { Task { await retryTranscription() } },
                    onUseText: { Task { await saveManualTranscription() } },
                    onKeepAudio: { dismiss() },
                    onDiscard: { Task { await discardRecording() } }
                )
            }
            if purpose == .journal {
                JournalAudioOptionsSection(
                    transcribes: $transcribes,
                    isDisabled: recorder.isRecording,
                    onRequestConsent: { showsConsent = true }
                )
            }
        } commit: {
            ComposerCommitBar(
                title: purpose == .search ? "Search journal" : "Save audio",
                phase: commitPhase,
                isEnabled: capturedURL != nil && isTranscribing == false && didPersist == false,
                identifier: "journal.audio.commit",
                action: { Task { await save() } }
            )
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
        .alert("About transcription", isPresented: $showsConsent) {
            Button("Continue") {
                UserDefaults.standard.set(true, forKey: "lifeboard.journal.speech_consent.v1")
                transcribes = true
            }
            Button("Not now", role: .cancel) { transcribes = false }
        } message: {
            Text("If you continue, Apple Speech may process this recording according to the system’s speech-recognition availability and privacy settings. You can keep audio without transcription.")
        }
    }

    private func toggleRecording() {
        if purpose == .search && Self.hasSpeechConsent == false {
            showsConsent = true
            return
        }
        if recorder.isRecording {
            if let result = recorder.stop() {
                capturedURL = result.url
                capturedDuration = result.duration
            }
        } else {
            Task { await recorder.start() }
        }
    }

    private func save() async {
        guard let capturedURL else { return }
        commitPhase = .running(progress: nil)
        let path = JournalAudioFiles.relativePath(for: capturedURL)
        if purpose == .journal {
            processingState = .queued
            guard await onSave(path, capturedDuration, nil) else {
                // The *save* failed, not the transcription. Reporting this as
                // `.transcriptionFailed` sent the person to a manual-transcript
                // recovery flow for a problem that had nothing to do with it.
                commitPhase = .recoverableFailure(.init(
                    message: "The recording is safe on this device but could not be filed.",
                    recovery: .retry
                ))
                return
            }
            didPersist = true
            commitPhase = .success(receipt: ComposerReceipt())
            successTrigger &+= 1
            guard transcribes else { dismiss(); return }
            await transcribeSavedAudio(capturedURL, path: path)
        } else {
            await transcribeSearchAudio(capturedURL, path: path)
        }
    }

    private func transcribeSavedAudio(_ url: URL, path: String) async {
        processingState = .transcribing
        isTranscribing = true
        let result = await JournalSpeechTranscriber().transcribe(url)
        isTranscribing = false
        guard let result, result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty == false else {
            processingState = .transcriptionFailed
            return
        }
        transcription = result
        processingState = .transcriptionComplete
        await onTranscription(path, result)
        dismiss()
    }

    private func transcribeSearchAudio(_ url: URL, path: String) async {
        processingState = .transcribing
        isTranscribing = true
        let result = await JournalSpeechTranscriber().transcribe(url)
        isTranscribing = false
        guard let result, result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty == false else {
            processingState = .transcriptionFailed
            commitPhase = .idle
            return
        }
        transcription = result
        processingState = .transcriptionComplete
        _ = await onSave(path, capturedDuration, result)
        dismiss()
    }

    private func retryTranscription() async {
        guard let capturedURL else { return }
        let path = JournalAudioFiles.relativePath(for: capturedURL)
        if purpose == .journal {
            await transcribeSavedAudio(capturedURL, path: path)
        } else {
            await transcribeSearchAudio(capturedURL, path: path)
        }
    }

    private func saveManualTranscription() async {
        guard let capturedURL else { return }
        let text = manualTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        let path = JournalAudioFiles.relativePath(for: capturedURL)
        processingState = .manualTranscription
        if purpose == .journal {
            await onTranscription(path, text)
        } else {
            _ = await onSave(path, capturedDuration, text)
        }
        dismiss()
    }

    private func discardRecording() async {
        guard let capturedURL else { return }
        let path = JournalAudioFiles.relativePath(for: capturedURL)
        processingState = .discarded
        if didPersist { await onDiscard(path) }
        else { try? JournalAudioFiles.delete(relativePath: path) }
        dismiss()
    }

    private static var hasSpeechConsent: Bool {
        UserDefaults.standard.bool(forKey: "lifeboard.journal.speech_consent.v1")
    }

    static func duration(_ interval: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(interval) / 60, Int(interval) % 60)
    }
}

// MARK: - Audio sections

private struct JournalAudioRecorderSection: View {
    let recorder: JournalAudioRecorder
    let capturedURL: URL?
    let onToggle: () -> Void

    var body: some View {
        ComposerSection {
            VStack(spacing: 16) {
                Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .lifeboardFont(.heroDisplay)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .symbolEffect(.pulse, isActive: recorder.isRecording)
                    .accessibilityHidden(true)

                // A genuinely live state, so it carries the live signature only
                // while something is actually happening.
                LiveStatePill(
                    label: recorder.isRecording ? "Recording" : "Microphone",
                    value: recorder.isRecording
                        ? JournalAudioCapture.duration(recorder.duration)
                        : (capturedURL == nil ? "Ready when you are" : "Recording ready"),
                    symbol: "waveform",
                    isLive: recorder.isRecording,
                    accessibilityID: "journal.audio.live"
                )

                if let error = recorder.errorMessage {
                    Text(error)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.statusDanger))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onToggle) {
                    Label(
                        recorder.isRecording ? "Stop recording" : "Start recording",
                        systemImage: recorder.isRecording ? "stop.fill" : "mic.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                // Starting is the promoted action; once it is rolling, stopping
                // is not the thing to shout about.
                .buttonStyle(.lifeBoardClay(.well, cornerRadius: Radius.pill))
                .accessibilityIdentifier("journal.audio.record")
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct JournalAudioTranscriptionSection: View {
    let isTranscribing: Bool
    let transcription: String?

    var body: some View {
        if isTranscribing || transcription != nil {
            ComposerSection("Transcript") {
                if isTranscribing {
                    ProgressView("Transcribing saved audio…")
                        .lifeboardFont(.caption1)
                }
                if let transcription {
                    Text(transcription)
                        .lifeboardFont(.body)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct JournalAudioRecoverySection: View {
    let purpose: JournalAudioCapture.Purpose
    @Binding var manualTranscription: String
    let onRetry: () -> Void
    let onUseText: () -> Void
    let onKeepAudio: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        ComposerSection(
            "Transcription didn't finish",
            detail: "The recording itself is safe."
        ) {
            ComposerField(
                "Transcription",
                prompt: "Add transcription manually",
                text: $manualTranscription,
                shape: .prose(lineLimit: 2...6),
                identifier: "journal.audio.manualTranscription"
            )
            HStack(spacing: 12) {
                Button("Retry", action: onRetry)
                    .buttonStyle(.lifeBoardChip)
                Button(purpose == .search ? "Use text" : "Save text", action: onUseText)
                    .buttonStyle(.lifeBoardChip)
                    .disabled(manualTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if purpose == .journal {
                Button("Keep audio without text", action: onKeepAudio)
                    .buttonStyle(.lifeBoardChip)
                DangerRow(
                    "Discard recording",
                    systemImage: "trash",
                    confirmationTitle: "Discard this recording?",
                    confirmationMessage: "The audio is deleted from this device and cannot be recovered.",
                    confirmActionTitle: "Discard",
                    identifier: "journal.audio.discard",
                    perform: onDiscard
                )
            }
        }
    }
}

private struct JournalAudioOptionsSection: View {
    @Binding var transcribes: Bool
    let isDisabled: Bool
    let onRequestConsent: () -> Void

    var body: some View {
        ComposerSection {
            Toggle("Transcribe after recording", isOn: Binding(
                get: { transcribes },
                set: { enabled in
                    // Consent logic, not styling: intercept before enabling.
                    if enabled && UserDefaults.standard.bool(forKey: "lifeboard.journal.speech_consent.v1") == false {
                        onRequestConsent()
                    } else {
                        transcribes = enabled
                    }
                }
            ))
            .toggleStyle(.lifeBoardClay)
            .disabled(isDisabled)
            .accessibilityIdentifier("journal.audio.transcribes")
        }
    }
}
