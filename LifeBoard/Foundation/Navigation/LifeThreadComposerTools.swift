import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// The composer's tool row and the capture actions behind it: audio, dictation,
/// and document scanning.
extension LifeThreadComposerHost {
    struct ComposerToolDescriptor: Identifiable {
        enum Action { case capture(CaptureKind), voice, scan }
        let id: String
        let title: String
        let systemImage: String
        let action: Action
    }

    /// Most-used first: the things people write, then the things they log,
    /// then the tools that start something else. "Metric" with a heart icon
    /// opened water logging; it now says so. Its id stays "metric" because UI
    /// tests address tools by identifier.
    var composerTools: [ComposerToolDescriptor] {
        var tools: [ComposerToolDescriptor] = [
            .init(id: "task", title: "Task", systemImage: "checkmark.circle", action: .capture(.task))
        ]
        if V2FeatureFlags.journalV1Enabled {
            tools.append(.init(id: "journal", title: "Journal", systemImage: "book.closed", action: .capture(.journal)))
        }
        if V2FeatureFlags.knowledgeNotesV1Enabled {
            tools.append(.init(id: "note", title: "Note", systemImage: "note.text", action: .capture(.note)))
        }
        tools.append(.init(id: "habit", title: "Habit", systemImage: "repeat", action: .capture(.habit)))
        if V2FeatureFlags.careModulesV2Enabled {
            tools.append(.init(id: "mood", title: "Mood", systemImage: "face.smiling", action: .capture(.mood)))
            tools.append(.init(id: "metric", title: "Water", systemImage: "drop", action: .capture(.hydration)))
        }
        if V2FeatureFlags.trackersV1Enabled {
            tools.append(.init(id: "tracker", title: "Tracker", systemImage: "list.bullet.rectangle", action: .capture(.trackerEntry)))
        }
        if V2FeatureFlags.planningCoreV1Enabled {
            tools.append(.init(id: "timeBlock", title: "Time block", systemImage: "clock", action: .capture(.timeBlock)))
        }
        tools.append(.init(id: "scan", title: "Scan", systemImage: "doc.viewfinder", action: .scan))
        tools.append(.init(id: "voice", title: "Voice", systemImage: "waveform", action: .voice))
        return tools
    }

    @ViewBuilder
    func composerToolChip(
        _ tool: ComposerToolDescriptor,
        router: AppRouter
    ) -> some View {
        Group {
            switch tool.action {
            case .capture(let kind):
                composerCaptureButton(tool.title, systemImage: tool.systemImage, kind: kind)
            case .voice:
                composerToolButton(tool.title, systemImage: tool.systemImage) { beginComposerAudioCapture() }
            case .scan:
                composerToolButton(tool.title, systemImage: tool.systemImage) { beginDocumentScan(router: router) }
            }
        }
        .accessibilityIdentifier("lifeThread.composer.tool.\(tool.id)")
    }

    func composerCaptureButton(
        _ title: String,
        systemImage: String,
        kind: CaptureKind
    ) -> some View {
        Button {
            runtime.captureRouter.request(
                kind: kind,
                source: .shell,
                presentationContext: .init(
                    sourceRoot: runtime.router.selectedDestination,
                    sourcePoint: .init(x: 0.08, y: 0.92),
                    preferredCaptureKind: kind
                )
            )
            Haptic.pick.play()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: Capsule())
                .overlay { Capsule().stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    func composerToolButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: Capsule())
                .overlay { Capsule().stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    /// Mounts the existing save-first Journal audio controls directly in the
    /// shared composer's recording state instead of detouring through the
    /// full Journal module. When the universal-input dictation kill switch
    /// is on, the microphone falls back to the Journal audio-attachment
    /// flow (pre-existing behavior) when the universal-input dictation kill
    /// switch is off.

    func beginComposerAudioCapture() {
        EvaSpokenOutputController.shared.stopForRecording()
        guard V2FeatureFlags.universalInputDictationEnabled else {
            guard V2FeatureFlags.journalV1Enabled else {
                runtime.captureRouter.request(kind: .journal, source: .shell)
                return
            }
            if composerAudioStore == nil {
                composerAudioStore = JournalStore(repository: phaseIIRepository)
            }
            composer.beginRecording()
            showsComposerAudioCapture = true
            return
        }
        if dictationController.isRecording || dictationController.phase == .preparing || dictationController.phase == .finalizing {
            stopComposerDictation()
            return
        }
        composer.beginDictating()
        dictationController.start(existingDraft: composer.draftText)
    }

    /// Stop the live dictation session: end input, await analyzer
    /// finalization, and retain the final transcript in the draft. The
    /// composer returns to the focused state with the combined typed +
    /// dictated text.

    func stopComposerDictation() {
        Task { @MainActor in
            await dictationController.stop()
            if let recovery = dictationController.recovery, recovery.phase == .failed {
                runtime.router.activeAlert = .init(
                    title: "Dictation paused",
                    message: recovery.message
                )
            }
            composer.finishDictating(composedText: dictationController.draftText)
        }
    }

    /// Cancel the live dictation session: tear down audio and restore the
    /// pre-dictation draft so the user can keep typing.

    func cancelComposerDictation() {
        Self.cancelDictation(composer: composer, controller: dictationController)
    }

    /// Also called by the shell when the scene leaves the foreground, which is
    /// why it is static: the shell owns `scenePhase` but no longer owns the
    /// composer's dictation state.

    static func cancelDictation(
        composer: LifeThreadComposerCoordinator,
        controller: UniversalDictationController
    ) {
        Task { @MainActor in
            await controller.cancel()
            composer.cancelDictating(restoringText: controller.draftText)
        }
    }

    func beginDocumentScan(router: AppRouter) {
        guard VNDocumentCameraViewController.isSupported else {
            router.activeAlert = .init(
                title: String(localized: "Can’t scan on this device"),
                message: String(localized: "Paste the text instead.")
            )
            return
        }
        composer.beginScanning()
        showsDocumentScanner = true
    }

    /// Keys ahead of Done on the capture keyboard: `#` tag, `+` project, `@`
    /// context. The syntax was invisible until someone typed it; a key puts the
    /// sigil where the completion row reads it, and the row opens by itself.
    @ViewBuilder
    var composerTokenKeys: some View {
        composerTokenKey(.tag, name: "tag")
        composerTokenKey(.project, name: "project")
        composerTokenKey(.context, name: "context")
    }

    func composerTokenKey(_ kind: CaptureTokenCompletion.Kind, name: String) -> some View {
        Button(String(kind.sigil)) {
            composer.draftText = CaptureTokenCompletion.insertingSigil(kind, into: composer.draftText)
        }
        .font(.lifeboard(.callout))
        // The glyph alone reads as "number sign"; the label says what the key
        // does, and the input labels give Voice Control the plain word too.
        .accessibilityLabel("Add \(name)")
        .accessibilityInputLabels(["Add \(name)", name.capitalized])
        .accessibilityIdentifier("lifeThread.composer.token.\(name)")
    }

    /// One helper row above the keyboard at a time. While a token is being
    /// typed its suggestions are what matters — an interpretation of a
    /// half-typed token is wrong anyway — and the two rows together left almost
    /// no content visible above the keyboard on a small phone.
    var showsInterpretationRow: Bool {
        CaptureTokenCompletion.activeToken(in: composer.draftText) == nil
    }

    /// The border says when the composer holds the keyboard, as Eva's does.
    var composerBorder: some View {
        RoundedRectangle(cornerRadius: Radius.dock, style: .continuous)
            .stroke(
                lifeThreadComposerIsFocused
                    ? Color.lifeboard(.actionFocus)
                    : Color(SemanticColorTokens.foundationHairline),
                lineWidth: lifeThreadComposerIsFocused ? 1.5 : 1
            )
            .lifeBoardMotion(.controlMorph, value: lifeThreadComposerIsFocused)
    }

    /// Takes a pending focus request once the field is on screen — after the
    /// orb restores, a Home card asks, or a sheet finishes dismissing. The
    /// one-turn hop lets a field that was only just inserted take the keyboard.
    func consumeFocusRequestIfNeeded() {
        guard composer.consumeFocusRequest() else { return }
        DispatchQueue.main.async { lifeThreadComposerIsFocused = true }
    }

    func composerPlaceholder(for destination: Destination) -> String {
        switch destination {
        case .home, .plan: String(localized: "Add a task or ask Eva")
        case .track: String(localized: "Log or ask Eva")
        case .insights: String(localized: "Ask about a pattern")
        case .eva: String(localized: "Ask Eva")
        }
    }

    func formatElapsedSeconds(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

}
