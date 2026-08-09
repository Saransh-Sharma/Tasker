import SwiftUI
import SwiftData
import TranscriptionKit
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

    var composerTools: [ComposerToolDescriptor] {
        var tools: [ComposerToolDescriptor] = [
            .init(id: "task", title: "Task", systemImage: "checkmark.circle", action: .capture(.task)),
            .init(id: "habit", title: "Habit", systemImage: "repeat", action: .capture(.habit))
        ]
        if V2FeatureFlags.planningCoreV1Enabled {
            tools.append(.init(id: "timeBlock", title: "Time block", systemImage: "clock", action: .capture(.timeBlock)))
        }
        if V2FeatureFlags.journalV1Enabled {
            tools.append(.init(id: "journal", title: "Journal", systemImage: "book.closed", action: .capture(.journal)))
        }
        if V2FeatureFlags.careModulesV2Enabled {
            tools.append(.init(id: "mood", title: "Mood", systemImage: "face.smiling", action: .capture(.mood)))
            tools.append(.init(id: "metric", title: "Metric", systemImage: "waveform.path.ecg", action: .capture(.hydration)))
        }
        if V2FeatureFlags.trackersV1Enabled {
            tools.append(.init(id: "tracker", title: "Tracker", systemImage: "list.bullet.rectangle", action: .capture(.trackerEntry)))
        }
        tools.append(.init(id: "voice", title: "Voice", systemImage: "waveform", action: .voice))
        tools.append(.init(id: "scan", title: "Scan", systemImage: "doc.viewfinder", action: .scan))
        if V2FeatureFlags.knowledgeNotesV1Enabled {
            tools.append(.init(id: "note", title: "Note", systemImage: "note.text", action: .capture(.note)))
        }
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
            LifeBoardFeedback.light()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: Capsule())
                .overlay { Capsule().stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
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
                .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: Capsule())
                .overlay { Capsule().stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
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
                title: "Scanning isn’t available here",
                message: "Use LifeBoard on an iPhone or iPad with a camera, or paste text into the composer."
            )
            return
        }
        composer.beginScanning()
        showsDocumentScanner = true
    }

    func composerPlaceholder(for destination: Destination) -> String {
        switch destination {
        case .home: "Ask Eva or capture what is on your mind"
        case .plan: "Plan, move, or make sense of your time"
        case .track: "Log something or reflect on how you feel"
        case .insights: "Ask about a pattern or what to try next"
        case .eva: "Talk with Eva"
        }
    }

    func formatElapsedSeconds(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

}
