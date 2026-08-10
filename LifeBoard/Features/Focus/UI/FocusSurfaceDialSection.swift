import SwiftUI

/// The dial, at hero scale.
///
/// Two constraints from `DESIGN.md` shape this, and both are easy to violate by
/// accident:
///
///   * "The dial does not run an ambient shader and becomes a static progress
///     presentation under Reduce Motion." So there is no `.lifeboard*` effect
///     anywhere in this file. The one shader here is `completionBurst`, and it
///     fires once, on a persisted completion, from the parent.
///   * "Active, paused, and completed states use text, shape, and colour
///     together." Pause is therefore announced in the dial's own label, not
///     only by the arc changing tint.
///
/// Deliberately *not* implemented: scrub-to-extend. `PlanStore` exposes
/// `startFocus`/`pause`/`resume`/`advancePomodoro`/`recordInterruption`/`endFocus`
/// and nothing that changes a running session's target duration, so a scrub
/// gesture would either be a lie or would need new domain plumbing. A dial you
/// can drag but that changes nothing is worse than one you cannot drag.
struct FocusSurfaceDialSection: View {
    let store: PlanStore
    let session: FocusSessionV2
    let completionTrigger: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let display = FocusClock.display(
                session: session,
                companion: store.focusCompanion,
                at: context.date
            )
            FocusDial(
                progress: FocusClock.progress(
                    session: session,
                    companion: store.focusCompanion,
                    at: context.date
                ),
                isPaused: session.state == .paused,
                accessibilityValue: display.label
            ) {
                dialCentre(display)
            }
        }
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity)
        .lifeboardCompletionBurst(trigger: completionTrigger)
        .accessibilityIdentifier("focus.surface.dial")
    }

    @ViewBuilder
    private func dialCentre(_ display: FocusClockDisplay) -> some View {
        VStack(spacing: 6) {
            if display.showsClock {
                Text(PlanSectionCopy.duration(display.value))
                    // Token-backed rather than a fixed 46pt: a hard-coded size
                    // is the one thing that cannot scale, and this is the single
                    // most important number on the screen for someone who needs
                    // larger text. `hero()` is SF Rounded, which DESIGN.md
                    // reserves for exactly this — expressive metrics.
                    .font(Typography.hero())
                    .monospacedDigit()
                    // Digits roll rather than cut. At one update per second this
                    // is the difference between a clock and a flicker.
                    .contentTransition(.numericText())
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            } else {
                Text("Here with you")
                    .font(Typography.sectionTitle())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            }

            Text(session.state == .paused ? "Paused" : "In focus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
    }
}

struct FocusClockDisplay {
    let value: TimeInterval
    let label: String
    let showsClock: Bool
}

/// Clock and arc maths, lifted out of the view.
///
/// This logic previously lived as two private methods on `PlanActiveFocusCard`,
/// which meant the only way to test it was to render the card. As a plain enum
/// it is directly testable and the dial section stays a layout file.
///
/// `@MainActor` because it formats through `PlanSectionCopy.duration`, which is
/// main-actor isolated. Every caller is a view body, so this costs nothing and
/// is more honest than making the copy layer nonisolated to suit one consumer.
@MainActor
enum FocusClock {
    static func progress(
        session: FocusSessionV2,
        companion: FocusSessionCompanion?,
        at date: Date
    ) -> Double? {
        switch companion?.mode {
        case .countdown:
            guard session.targetDuration > 0 else { return nil }
            return FocusDialMetrics.elapsedFraction(
                totalDuration: session.targetDuration,
                remainingDuration: session.targetDuration - session.focusedDuration(at: date)
            )
        case .pomodoro:
            guard let phase = companion?.pomodoroPhase else { return nil }
            let duration = phase.phaseEndsAt.timeIntervalSince(phase.phaseStartedAt)
            guard duration > 0 else { return 1 }
            return FocusDialMetrics.elapsedFraction(
                totalDuration: duration,
                remainingDuration: phase.phaseEndsAt.timeIntervalSince(date)
            )
        case .stopwatch, .openEnded, .none:
            // An unbounded session has no fraction. Returning nil draws the
            // track alone rather than inventing a full or empty ring.
            return nil
        }
    }

    static func display(
        session: FocusSessionV2,
        companion: FocusSessionCompanion?,
        at date: Date
    ) -> FocusClockDisplay {
        switch companion?.mode {
        case .countdown:
            let value = max(0, session.targetDuration - session.focusedDuration(at: date))
            return FocusClockDisplay(
                value: value,
                label: value == 0
                    ? "Time is up. Choose what happens next."
                    : "\(PlanSectionCopy.duration(value)) remaining\(pausedSuffix(session))",
                showsClock: true
            )
        case .pomodoro:
            let endsAt = companion?.pomodoroPhase?.phaseEndsAt ?? date
            let value = max(0, endsAt.timeIntervalSince(date))
            return FocusClockDisplay(
                value: value,
                label: value == 0
                    ? "This phase is complete."
                    : "\(PlanSectionCopy.duration(value)) in this phase\(pausedSuffix(session))",
                showsClock: true
            )
        case .stopwatch, .none:
            let value = session.focusedDuration(at: date)
            return FocusClockDisplay(
                value: value,
                label: "\(PlanSectionCopy.duration(value)) elapsed\(pausedSuffix(session))",
                showsClock: true
            )
        case .openEnded:
            return FocusClockDisplay(
                value: 0,
                label: "Open-ended focus\(pausedSuffix(session))",
                showsClock: false
            )
        }
    }

    private static func pausedSuffix(_ session: FocusSessionV2) -> String {
        session.state == .paused ? ", paused" : ""
    }
}
