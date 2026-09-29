import SwiftUI

/// The dial, at hero scale.
///
/// Two constraints from `DESIGN.md` shape this, and both are easy to violate by
/// accident:
///
///   * The dial carries ambient motion only while a session is running, within
///     the ambient budget, and settles to a static presentation when paused or
///     finished. `completionBurst` fires once, on a persisted completion, from
///     the parent.
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
    /// Non-nil once the ending is persisted; the clock freezes at that instant.
    var settledAt: Date? = nil
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var isStill: Bool { settledAt != nil || session.state == .paused }

    var body: some View {
        ActiveVisibleTimeline(every: 1) { context in
            let date = settledAt ?? context.date
            let display = FocusClock.display(
                session: session,
                companion: store.focusCompanion,
                at: date
            )
            FocusDial(
                // Persisted ending: the arc sweeps closed — the session is
                // over — and the reflection below takes it from there.
                progress: settledAt != nil ? 1 : FocusClock.progress(
                    session: session,
                    companion: store.focusCompanion,
                    at: date
                ),
                isPaused: isStill,
                accessibilityValue: display.label
            ) {
                dialCentre(display)
            }
        }
        // The session's hero. 300 on a 13-inch iPad or a Mac window was a small
        // ring in a large empty screen; pad widths get a dial sized for them.
        .frame(maxWidth: layoutClass.isPad ? 440 : 300)
        .frame(maxWidth: .infinity)
        // A running session should read as running even between ticks. Only
        // while actually running: a paused dial that keeps breathing would be
        // saying the opposite of what the state is. DESIGN.md's Focus dial
        // contract permits exactly this, bounded by the ambient budget.
        .lifeBoardAmbientBreath(role: .activeMetric, intensity: isStill ? 0 : 1)
        .lifeboardCompletionBurst(trigger: completionTrigger)
        .accessibilityIdentifier("focus.surface.dial")
    }

    @ViewBuilder
    private func dialCentre(_ display: FocusClockDisplay) -> some View {
        VStack(spacing: 8) {
            if display.showsClock {
                // A timer reads in minutes and seconds. "25m" stood still for
                // a whole minute, so a running session looked frozen.
                Text(FocusClock.clockText(display.value))
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
                Text("No timer")
                    .font(Typography.sectionTitle())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            }

            Text(settledAt != nil ? "Saved" : session.state == .paused ? "Paused" : "In focus")
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
    /// "24:37", or "1:05:09" past an hour.
    nonisolated static func clockText(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3_600, minutes = (total % 3_600) / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

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
                    ? String(localized: "Time’s up")
                    : String(localized: "\(PlanSectionCopy.duration(value)) left") + pausedSuffix(session),
                showsClock: true
            )
        case .pomodoro:
            let endsAt = companion?.pomodoroPhase?.phaseEndsAt ?? date
            let value = max(0, endsAt.timeIntervalSince(date))
            return FocusClockDisplay(
                value: value,
                label: value == 0
                    ? String(localized: "Phase done")
                    : String(localized: "\(PlanSectionCopy.duration(value)) left in phase") + pausedSuffix(session),
                showsClock: true
            )
        case .stopwatch, .none:
            let value = session.focusedDuration(at: date)
            return FocusClockDisplay(
                value: value,
                label: String(localized: "\(PlanSectionCopy.duration(value)) elapsed") + pausedSuffix(session),
                showsClock: true
            )
        case .openEnded:
            return FocusClockDisplay(
                value: 0,
                label: String(localized: "Open-ended focus") + pausedSuffix(session),
                showsClock: false
            )
        }
    }

    private static func pausedSuffix(_ session: FocusSessionV2) -> String {
        session.state == .paused ? String(localized: ", paused") : ""
    }
}
