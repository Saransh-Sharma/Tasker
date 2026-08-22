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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isPaused: Bool { session.state == .paused }

    var body: some View {
        VStack(spacing: 14) {
            primaryRow
            if store.focusCompanion?.pomodoroPhase != nil {
                nextPhaseButton
            }
            endRow
            FocusInterruptionControl(store: store)
        }
        .accessibilityIdentifier("focus.surface.transport")
    }

    private var primaryRow: some View {
        Button {
            Task {
                if isPaused { await store.resumeFocus() } else { await store.pauseFocus() }
            }
        } label: {
            Label(
                isPaused ? "Resume" : "Pause",
                systemImage: isPaused ? "play.fill" : "pause.fill"
            )
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.lifeBoardPrimaryCompact)
        .lifeBoardPressResponse(.hero, haptic: .pick)
        .accessibilityIdentifier("focus.surface.pauseResume")
    }

    private var nextPhaseButton: some View {
        Button("Next phase", systemImage: "forward.end.fill") {
            Task { await store.advancePomodoro() }
        }
        .font(.subheadline.weight(.medium))
        .frame(maxWidth: .infinity, minHeight: 44)
        .buttonStyle(.bordered)
        .accessibilityIdentifier("focus.surface.nextPhase")
    }

    @ViewBuilder
    private var endRow: some View {
        if showsEndOptions {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                endButton("Finish", systemImage: "checkmark.circle", outcome: .completed)
                endButton("Continue later", systemImage: "clock.arrow.circlepath", outcome: .continueLater)
                endButton("Stop", systemImage: "xmark.circle", outcome: .abandoned)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            Button("End session…") {
                showsEndOptions = true
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.plain)
            .accessibilityIdentifier("focus.surface.endSession")
        }
    }

    private func endButton(
        _ title: String,
        systemImage: String,
        outcome: FocusCompletionOutcome
    ) -> some View {
        Button(title, systemImage: systemImage) {
            pendingOutcome = outcome
        }
        .font(.subheadline.weight(.medium))
        .frame(maxWidth: .infinity, minHeight: 44)
        .buttonStyle(.bordered)
        .accessibilityIdentifier("focus.surface.end.\(outcome.rawValue)")
    }
}
