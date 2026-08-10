import SwiftUI

/// The confirmation that turns a chosen ending into a recorded one.
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
                    Button("Cancel") { pendingOutcome = nil }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("focus.surface.commit.cancel")
                }

                CommitControl(
                    title: Self.commitTitle(for: outcome),
                    runningTitle: "Ending focus",
                    successTitle: "Focus saved",
                    phase: store.focusCommitPhase
                ) {
                    Task {
                        await store.endFocus(outcome: outcome)
                        // Only a success closes the surface. On a recoverable
                        // failure the section stays mounted with the outcome
                        // still chosen, so retry costs one tap and no re-decision.
                        if case .success = store.focusCommitPhase {
                            pendingOutcome = nil
                            onCommitted(outcome)
                        }
                    }
                }
                .accessibilityIdentifier("focus.surface.commit")
            }
            .padding(14)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
        }
    }

    /// Says what happens to the time already spent. "Are you sure?" would not.
    static func consequence(for outcome: FocusCompletionOutcome) -> String {
        switch outcome {
        case .completed:
            "This session is recorded as finished, with the time you focused."
        case .continueLater:
            "Your progress is kept so you can pick this up again."
        case .abandoned, .stopped:
            "The session ends now. Time already focused is still recorded."
        case .interrupted:
            "The session is recorded as interrupted."
        case .intentionallyDeferred:
            "The session is recorded as deferred to another time."
        }
    }

    static func commitTitle(for outcome: FocusCompletionOutcome) -> String {
        switch outcome {
        case .completed: "Finish focus"
        case .continueLater: "Continue later"
        case .abandoned, .stopped: "Stop focus"
        case .interrupted: "Record interruption"
        case .intentionallyDeferred: "Defer focus"
        }
    }
}
