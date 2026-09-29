import SwiftUI

/// The progress and retry for a chosen ending.
///
/// Choosing Finish, Continue later or Stop in the transport is the commit —
/// each option already says what it does — so this section runs the ending as
/// soon as it appears and stays only to show it running, or to offer a retry
/// if it failed. It used to wait for a third confirming tap.
///
/// Three things `DESIGN.md` asks of a commit control, all of which `CommitControl`
/// already implements and which is why this section wraps it rather than
/// rolling its own button: running prevents duplicate submission while
/// preserving input, success feedback begins only after the canonical action
/// succeeds, and a recoverable failure keeps the user's work mounted with a
/// specific retry.
///
/// The consequence line above it is not decoration. Stopping a session discards
/// the elapsed time rather than banking it, and that is exactly the kind of
/// thing an interface must say *before* the action, not in a receipt afterwards.
struct FocusSurfaceCloseSection: View {
    let store: PlanStore
    @Binding var pendingOutcome: FocusCompletionOutcome?
    let onCommitted: (FocusCompletionOutcome) -> Void

    var body: some View {
        if let outcome = pendingOutcome {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Self.consequence(for: outcome))
                        .font(.subheadline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("Keep going") { pendingOutcome = nil }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("focus.surface.commit.cancel")
                }

                CommitControl(
                    title: Self.commitTitle(for: outcome),
                    runningTitle: String(localized: "Ending…"),
                    successTitle: String(localized: "Saved"),
                    phase: store.focusCommitPhase
                ) {
                    Task { await commit(outcome) }
                }
                .accessibilityIdentifier("focus.surface.commit")
            }
            .padding(14)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            .task(id: outcome) {
                if case .running = store.focusCommitPhase { return }
                await commit(outcome)
            }
        }
    }

    private func commit(_ outcome: FocusCompletionOutcome) async {
        await store.endFocus(outcome: outcome)
        // Only a success closes the surface. On a recoverable failure the
        // section stays mounted with the outcome still chosen, so retry costs
        // one tap and no re-decision.
        if case .success = store.focusCommitPhase {
            pendingOutcome = nil
            onCommitted(outcome)
        } else if case .recoverableFailure = store.focusCommitPhase {
            Haptic.fail.play()
        }
    }

    /// Says what happens to the time already spent. "Are you sure?" would not.
    static func consequence(for outcome: FocusCompletionOutcome) -> String {
        switch outcome {
        case .completed:
            String(localized: "Keeps your time. The task stays open.")
        case .continueLater:
            String(localized: "Keeps your time to pick up later.")
        case .abandoned, .stopped:
            String(localized: "Ends without finishing. Keeps your time.")
        case .interrupted:
            String(localized: "Saved as interrupted.")
        case .intentionallyDeferred:
            String(localized: "Saved for another time.")
        }
    }

    static func commitTitle(for outcome: FocusCompletionOutcome) -> String {
        switch outcome {
        case .completed: String(localized: "Finish focus")
        case .continueLater: String(localized: "Continue later")
        case .abandoned, .stopped: String(localized: "Stop focus")
        case .interrupted: String(localized: "Log interruption")
        case .intentionallyDeferred: String(localized: "Save for later")
        }
    }
}
