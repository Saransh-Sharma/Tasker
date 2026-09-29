import SwiftUI

/// Pause, resume, and the three ways a session can end.
///
/// The card this replaces put Finish, Continue later and Abandon inside a
/// `Menu("More")`, which `DESIGN.md` rules out twice over: "Every gesture has a
/// visible control", and destructive consequences must be explained rather than
/// hidden. Finishing a focus session is the *expected* end of the task — burying
/// it behind an ellipsis alongside "Abandon" made the ordinary outcome as hard
/// to reach as the destructive one.
///
/// So: Pause/Resume is the one dominant action, Finish sits beside it as the
/// quiet alternative, and the two consequential endings live in a disclosed row
/// that names what each does. Abandon still routes through the confirmation in
/// `FocusSurfaceCloseSection` — promoting it out of a menu makes it findable,
/// not immediate.
struct FocusSurfaceTransportSection: View {
    let store: PlanStore
    let session: FocusSessionV2
    @Binding var pendingOutcome: FocusCompletionOutcome?

    @State private var showsEndOptions = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isPaused: Bool { session.state == .paused }

    var body: some View {
        // Pause/resume has moved into the hero as its single primary action.
        // `DESIGN.md` allows a hero "one primary action with at most one quiet
        // alternative"; end, next phase and interruption logging are three more,
        // so they stay here, in clay, beneath it.
        VStack(spacing: 14) {
            if store.focusCompanion?.pomodoroPhase != nil {
                nextPhaseButton
            }
            endRow
            FocusInterruptionControl(store: store)
        }
        // A container identifier stamps every child unless the container is
        // declared as one; without this, "End session…" and the interruption
        // control both answered to `focus.surface.transport` in XCUITest.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus.surface.transport")
    }

}

/// Focus's single primary action, lifted out of the transport so the hero can
/// hold it.
struct FocusPauseResumeButton: View {
    let store: PlanStore
    let session: FocusSessionV2

    private var isPaused: Bool { session.state == .paused }

    var body: some View {
        Button {
            Task {
                // `DESIGN.md`: "Persistence precedes success motion and haptics."
                // The haptic confirms the transition that actually happened, so
                // it fires after the store settles rather than on touch-down —
                // and it carries the matching intent: resuming lifts a session
                // back up, pausing sets it down.
                // A failed command plays nothing: the store surfaces the error.
                if isPaused {
                    if await store.resumeFocus() { Haptic.lift.play() }
                } else {
                    if await store.pauseFocus() { Haptic.settle.play() }
                }
            }
        } label: {
            Label(
                isPaused ? "Resume" : "Pause",
                systemImage: isPaused ? "play.fill" : "pause.fill"
            )
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.lifeBoardPrimary)
        .lifeBoardPressResponse(.hero, haptic: nil)
        // Space, like every media transport. The session screen has no text
        // field while the timer runs, so the bare key is free.
        .keyboardShortcut(.space, modifiers: [])
        .accessibilityIdentifier("focus.surface.pauseResume")
    }
}

private extension FocusSurfaceTransportSection {
    var nextPhaseButton: some View {
        Button("Next phase", systemImage: "forward.end.fill") {
            Task { await store.advancePomodoro() }
        }
        .font(.subheadline.weight(.medium))
        .frame(maxWidth: .infinity, minHeight: 44)
        .buttonStyle(.lifeBoardChip)
        .accessibilityIdentifier("focus.surface.nextPhase")
    }

    /// Two taps to end: "End session…", then the ending. Each ending says
    /// what it does beside it, so there is no third confirmation step, and
    /// "Keep going" folds the choices away again.
    @ViewBuilder
    var endRow: some View {
        if showsEndOptions && pendingOutcome == nil {
            VStack(spacing: 12) {
                endButton("Finish", systemImage: "checkmark.circle", outcome: .completed)
                endButton("Continue later", systemImage: "clock.arrow.circlepath", outcome: .continueLater)
                endButton("Stop", systemImage: "xmark.circle", outcome: .abandoned)
                Button("Keep going", systemImage: "arrow.uturn.backward") {
                    withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                        showsEndOptions = false
                    }
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityIdentifier("focus.surface.keepGoing")
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if pendingOutcome == nil {
            Button("End session…") {
                withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                    showsEndOptions = true
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.plain)
            .accessibilityIdentifier("focus.surface.endSession")
        }
    }

    func endButton(
        _ title: String,
        systemImage: String,
        outcome: FocusCompletionOutcome
    ) -> some View {
        Button {
            // Choosing the ending is the commit; the close section runs it
            // and stays mounted only to show progress or a retry.
            showsEndOptions = false
            pendingOutcome = outcome
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(FocusSurfaceCloseSection.consequence(for: outcome))
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lifeBoardChip)
        .accessibilityIdentifier("focus.surface.end.\(outcome.rawValue)")
    }
}
