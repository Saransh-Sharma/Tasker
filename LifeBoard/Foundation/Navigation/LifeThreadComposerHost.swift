import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// The universal capture composer that sits above the dock on every root.
///
/// Lifted out of `FoundationShell` as a whole surface rather than as a set
/// of helpers: it owns a coordinator, a dictation controller, live intent
/// resolution, document scanning, and the receipt/undo path, and splitting those
/// apart would have spread one interaction across several types.
///
/// The shell keeps ownership of every piece of `@State` this reads. The composer
/// is rebuilt whenever the destination changes, so state held here would drop a
/// half-typed draft on every root switch.
struct LifeThreadComposerHost: View {
    let router: AppRouter
    let composer: LifeThreadComposerCoordinator
    let dictationController: UniversalDictationController
    let homeViewModel: HomeViewModel
    let runtime: FoundationCoordinator
    let lifeBoardMutationCoordinator: MutationCoordinator
    let universalInputCoordinator: UniversalInputCoordinator
    let phaseIIRepository: any PhaseIIRepository
    let presentPlanOverdueRescue: (OverdueRescueLaunchContext) -> Void
    @Binding var liveIntentResolveTask: Task<Void, Never>?
    @Binding var composerAudioStore: JournalStore?
    @Binding var showsComposerAudioCapture: Bool
    @Binding var showsDocumentScanner: Bool
    @Binding var lifeBoardActionReceipt: ActionReceipt?
    @FocusState.Binding var lifeThreadComposerIsFocused: Bool
    /// Nil where the host is mounted without a reporting scroll view (regular
    /// width, and any root that has not opted in). Absent an observer the
    /// composer simply never compresses, which is the correct default.
    var scrollObserver: ComposerScrollObserver? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Namespace private var composerMorph
    @State private var presentation: ComposerPresentation = .capsule

    var body: some View {
        host(router: router)
    }



    /// One ordered capture tray. Kinds with a working capture host each get a
    /// visible control — `habit`, `trackerEntry` and `timeBlock` previously had
    /// hosts wired with no way to reach them.
}

/// The compression decision, in its own extension.
///
/// Separated from the struct above for the file-size gate's `largest` metric —
/// the `-Onone` stack predictor. `LifeThreadComposerHost` assembles nine
/// conditional sections in one body and was already the largest declaration in
/// the file; the orb branch pushed it past the ceiling.
extension LifeThreadComposerHost {
    /// Recomputed from observable state rather than stored. Storing it would let
    /// the never-collapse rules go stale in the window between a scroll event
    /// and a composer state change — which is precisely when a draft would be
    /// lost.
    var resolvedPresentation: ComposerPresentation {
        guard let scrollObserver else { return .capsule }
        return ComposerCompressionPolicy.presentation(
            ComposerCompressionInput(
                contentOffset: scrollObserver.contentOffset,
                isTrackingDownward: scrollObserver.isTrackingDownward,
                composerState: composer.state,
                hasDraft: composer.hasDraft,
                hasPreview: composer.preview != nil,
                hasReceipt: lifeBoardActionReceipt != nil,
                isKeyboardFocused: lifeThreadComposerIsFocused,
                voiceOverEnabled: voiceOverEnabled
            ),
            current: presentation
        )
    }

    /// The composer's whole surface. It lives in the extension rather than
    /// the struct for the same reason `resolvedPresentation` does: this one
    /// function is ~380 lines of conditional sections, and the file-size gate's
    /// `largest` metric is the `-Onone` stack-overflow predictor.
    @ViewBuilder
    private func host(router: AppRouter) -> some View {
        @Bindable var composer = composer
        VStack(spacing: 8) {
            if let preview = composer.preview {
                ComposerPreviewCard(
                    preview: preview,
                    onApply: { applyLifeThreadPreview(preview, router: router) },
                    onEdit: {
                        composer.draftText = preview.summary
                        composer.focus()
                        lifeThreadComposerIsFocused = true
                        Task { await lifeBoardMutationCoordinator.discard(previewID: preview.id) }
                    },
                    onNotNow: {
                        composer.settle()
                        Task {
                            await lifeBoardMutationCoordinator.discard(previewID: preview.id)
                            try? await Task.sleep(for: .milliseconds(180))
                            await MainActor.run { composer.finishSettling() }
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let receipt = lifeBoardActionReceipt {
                ComposerReceiptView(
                    receipt: receipt,
                    onUndo: { undoLifeThreadReceipt(receipt, router: router) },
                    onDismiss: { lifeBoardActionReceipt = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let clarification = composer.clarification {
                ComposerClarificationRow(
                    clarification: clarification,
                    onDismiss: { composer.dismissClarification() },
                    onChoose: { option in
                        composer.dismissClarification()
                        handleLifeThreadResolution(option.resolution, router: router)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let interpretation = composer.interpretation {
                ComposerInterpretationRow(
                    interpretation: interpretation,
                    onAccept: {
                        let resolution = interpretation.resolution
                        composer.dismissInterpretation()
                        handleLifeThreadResolution(resolution, router: router)
                    },
                    onDismiss: { composer.dismissInterpretation() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if dictationController.isRecording || dictationController.phase == .preparing || dictationController.phase == .finalizing {
                HStack(spacing: 8) {
                    let phaseLabel: String = {
                        switch dictationController.phase {
                        case .preparing: return "Preparing…"
                        case .finalizing: return "Finalizing…"
                        default: return "Recording"
                        }
                    }()
                    Circle()
                        .fill(dictationController.phase == .preparing || dictationController.phase == .finalizing
                              ? Color(SemanticColorTokens.inkSecondary)
                              : Color.lifeboard(.statusDanger))
                        .frame(width: 8, height: 8)
                        .opacity(dictationController.phase == .recording ? (reduceMotion ? 1 : 0.55) : 1)
                        .scaleEffect(dictationController.phase == .recording && !reduceMotion ? 1.1 : 1)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: dictationController.isRecording)
                    Text("\(phaseLabel) \(formatElapsedSeconds(dictationController.elapsedSeconds))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .accessibilityLabel("\(phaseLabel) elapsed \(dictationController.elapsedSeconds) seconds")
                        .accessibilityIdentifier("lifeThread.composer.dictation.badge")
                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if composer.state == .tools {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(composerTools.enumerated()), id: \.element.id) { index, tool in
                            composerToolChip(tool, router: router)
                                .modifier(ComposerToolStagger(index: index, reduceMotion: reduceMotion))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .transition(.opacity)
                .accessibilityIdentifier("lifeThread.composer.tools")
            }

            if let workingLabel = composer.workingLabel {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(workingLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .accessibilityElement(children: .combine)
            }

            if let recovery = composer.recovery {
                HStack(spacing: 10) {
                    Text(composer.recoveryMessage ?? "Your draft is still here.")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    Spacer(minLength: 8)
                    Button(recovery == .continue ? "Continue" : "Retry") {
                        submitLifeThreadComposer(router: router)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityHint("Keeps the current draft and attachments")
                }
                .padding(.horizontal, 12)
                .accessibilityIdentifier("lifeThread.composer.recovery")
            }

            if presentation == .orb {
                ComposerCaptureOrb(morphNamespace: composerMorph) {
                    // Tap always restores, whatever the scroll position —
                    // DESIGN.md: "it must restore at the top or on tap."
                    presentation = .capsule
                    composer.focus()
                    lifeThreadComposerIsFocused = true
                }
            } else {
            HStack(spacing: 8) {
                Button {
                    withAnimation(MotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                        composer.state == .tools ? composer.focus() : composer.showTools()
                    }
                    HapticFeedback.light()
                } label: {
                    // The plus rotates into the close glyph rather than
                    // swapping, so the control reads as one object opening.
                    Image(systemName: "plus")
                        .lifeboardFont(.title2)
                        .rotationEffect(.degrees(composer.state == .tools ? 45 : 0))
                        .frame(width: 44, height: 44)
                        // Without an explicit shape the hit region collapses to
                        // the glyph itself, well under the 44pt minimum.
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(
                    composer.state == .working
                        || dictationController.phase == .preparing
                        || dictationController.phase == .recording
                        || dictationController.phase == .finalizing
                )
                .accessibilityLabel(composer.state == .tools ? "Close capture tools" : "Open capture tools")
                .accessibilityIdentifier("lifeThread.composer.toolsToggle")

                TextField(text: $composer.draftText, axis: .vertical) {
                    Text(composerPlaceholder(for: composer.destination))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                    .lineLimit(1...4)
                    .disabled(
                        composer.state == .working
                            || dictationController.phase == .preparing
                            || dictationController.phase == .recording
                            || dictationController.phase == .finalizing
                    )
                    .focused($lifeThreadComposerIsFocused)
                    .submitLabel(.send)
                    .onSubmit { submitLifeThreadComposer(router: router) }
                    .onChange(of: lifeThreadComposerIsFocused) { _, focused in
                        if focused { composer.focus() }
                    }
                    .onChange(of: composer.draftText) { _, _ in
                        liveResolveComposerIntent(router: router)
                    }
                    .onChange(of: dictationController.draftText) { _, newValue in
                        // Pull the live transcript back into the composer's
                        // editable text during recording. Don't run intent
                        // resolution from here — it's driven by the
                        // `composer.draftText` change above (and is
                        // suppressed during active recording).
                        guard dictationController.isRecording else { return }
                        if composer.draftText != newValue {
                            composer.draftText = newValue
                        }
                    }
                    .onChange(of: dictationController.recovery) { _, recovery in
                        guard let recovery else { return }
                        switch recovery.phase {
                        case .denied, .unsupportedLocale, .assetInstallFailed:
                            runtime.router.activeAlert = .init(
                                title: "Dictation isn't available",
                                message: recovery.message
                            )
                            composer.cancelDictating(
                                restoringText: dictationController.draftText.isEmpty ? composer.draftText : dictationController.draftText
                            )
                        case .failed:
                            runtime.router.activeAlert = .init(
                                title: "Dictation paused",
                                message: recovery.message
                            )
                            composer.finishDictating(composedText: dictationController.draftText)
                        case .idle, .preparing, .recording, .finalizing:
                            break
                        }
                    }
                    .accessibilityIdentifier("home.lifeThread.composer")

                if dictationController.isRecording || dictationController.phase == .preparing || dictationController.phase == .finalizing {
                    Button {
                        cancelComposerDictation()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .lifeboardFont(.headline)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .frame(width: 44, height: 44)
                            .background(Color.lifeboard(.surfaceSecondary), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(composer.state == .working)
                    .accessibilityLabel("Cancel dictation")
                    .accessibilityIdentifier("lifeThread.composer.dictation.cancel")

                    Button {
                        stopComposerDictation()
                    } label: {
                        Label("Done", systemImage: "stop.fill")
                            .labelStyle(.iconOnly)
                            .lifeboardFont(.headline)
                            .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceSolid))
                            .frame(width: 44, height: 44)
                            .background(Color(SemanticColorTokens.inkPrimary), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(composer.state == .working)
                    .accessibilityLabel("Stop dictation")
                    .accessibilityIdentifier("lifeThread.composer.dictation.done")
                } else {
                    Button {
                        if composer.hasDraft {
                            submitLifeThreadComposer(router: router)
                        } else {
                            beginComposerAudioCapture()
                        }
                    } label: {
                        Image(systemName: composer.hasDraft ? "arrow.up" : "waveform")
                            .lifeboardFont(.headline)
                            .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceSolid))
                            .frame(width: 44, height: 44)
                            .background(Color(SemanticColorTokens.inkPrimary), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(composer.state == .working)
                    .accessibilityLabel(
                        composer.hasDraft
                            ? "Interpret input"
                            : (V2FeatureFlags.universalInputDictationEnabled ? "Start dictation" : "Record journal audio")
                    )
                    .accessibilityIdentifier("lifeThread.composer.send")
                }
            }
            .padding(8)
            .lifeBoardGlassSurface(cornerRadius: 27, interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
            }
            .shadow(color: Color(SemanticColorTokens.foundationWarmShadow).opacity(0.16), radius: 12, y: 6)
            // Shares its identity with the orb, so the two are one surface
            // changing shape rather than two views crossfading. Both sit inside
            // the shell's single GlassEffectContainer, which is what lets the
            // shrinking capsule genuinely refract into the dock beneath it.
            .matchedGeometryEffect(id: "foundation.composer.capsule", in: composerMorph)
            .lifeBoardGlassIdentity(.capture)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88), value: composer.state)
        .lifeBoardMotion(.controlMorph, value: presentation)
        .onChange(of: resolvedPresentation) { previous, next in
            guard previous != next else { return }
            presentation = next
            Haptic.settle.play()
        }
    }
}
