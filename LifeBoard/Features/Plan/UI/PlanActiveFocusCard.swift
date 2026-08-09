import SwiftUI
import UIKit

/// The running focus session: dial, transport controls, and the end-of-session
/// confirmation that appears inline rather than as a sheet.
struct PlanActiveFocusCard: View {
    let store: PlanStore
    let session: FocusSessionV2
    @Binding var pendingFocusEndOutcome: FocusCompletionOutcome?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(
                session.state == .paused ? "Focus paused" : "Focus in progress",
                systemImage: session.state == .paused ? "pause.circle.fill" : "timer"
            )
            .font(.headline)

            if let companion = store.focusCompanion {
                HStack {
                    Text(modeLabel(companion.mode))
                    if let phase = companion.pomodoroPhase,
                       case let .pomodoro(_, _, rounds) = companion.mode {
                        Text("· \(phase.kind == .focus ? "Focus" : "Rest") \(phase.round) of \(rounds)")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                if companion.intention.isEmpty == false {
                    Text(companion.intention)
                        .font(.subheadline)
                }
            }

            dial
                .frame(maxWidth: 246)
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Group {
                    if session.state == .paused {
                        Button("Resume", systemImage: "play.fill") { Task { await store.resumeFocus() } }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Pause", systemImage: "pause.fill") { Task { await store.pauseFocus() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)

                Menu("More", systemImage: "ellipsis.circle") {
                    if store.focusCompanion?.pomodoroPhase != nil {
                        Button("Next phase", systemImage: "forward.end.fill") {
                            Task { await store.advancePomodoro() }
                        }
                    }
                    Menu("Record interruption", systemImage: "bell.slash") {
                        Button("Call or message") {
                            Task { await store.recordInterruption(reason: "Call or message") }
                        }
                        Button("Someone needed me") {
                            Task { await store.recordInterruption(reason: "Someone needed me") }
                        }
                        Button("Lost focus") {
                            Task { await store.recordInterruption(reason: "Lost focus") }
                        }
                    }
                    Divider()
                    Button("Finish focus", systemImage: "checkmark.circle") {
                        pendingFocusEndOutcome = .completed
                    }
                    Button("Continue later", systemImage: "clock.arrow.circlepath") {
                        pendingFocusEndOutcome = .continueLater
                    }
                    Button("Abandon focus", systemImage: "xmark.circle", role: .destructive) {
                        pendingFocusEndOutcome = .abandoned
                    }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 48)
                .accessibilityIdentifier("plan.focus.more")
            }

            if let outcome = pendingFocusEndOutcome {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(endPrompt(outcome))
                            .font(.subheadline)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        Spacer(minLength: 8)
                        Button("Cancel") { pendingFocusEndOutcome = nil }
                            .font(.subheadline.weight(.semibold))
                    }
                    CommitControl(
                        title: endTitle(outcome),
                        runningTitle: "Ending focus",
                        successTitle: "Focus saved",
                        phase: store.focusCommitPhase
                    ) {
                        Task { await store.endFocus(outcome: outcome) }
                    }
                    .accessibilityIdentifier("plan.focus.commit")
                }
                .padding(12)
                .lifeBoardClaySurface(.well, cornerRadius: 16)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }
        }
        .foundationClayCard()
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Color(LifeBoardColorTokens.foundationFocusRing).opacity(0.25), lineWidth: 1)
        }
        .lifeBoardMotion(.contentInsertion, value: pendingFocusEndOutcome)
        .accessibilityIdentifier("plan.activeFocus")
    }

    @ViewBuilder
    private var dial: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let display = clockDisplay(at: context.date)
            let pausedSuffix = session.state == .paused ? ", paused" : ""
            FocusDial(
                progress: progress(at: context.date),
                isPaused: session.state == .paused,
                accessibilityValue: display.label + pausedSuffix
            ) {
                VStack(spacing: 5) {
                    if case .openEnded? = store.focusCompanion?.mode {
                        Text("Here with you")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(PlanSectionCopy.duration(display.value))
                            .font(Typography.screenTitle().weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Text(session.state == .paused ? "Paused" : "In focus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
            }
        }
    }

    private func progress(at date: Date) -> Double? {
        switch store.focusCompanion?.mode {
        case .countdown:
            guard session.targetDuration > 0 else { return nil }
            return FocusDialMetrics.elapsedFraction(
                totalDuration: session.targetDuration,
                remainingDuration: session.targetDuration - session.focusedDuration(at: date)
            )
        case .pomodoro:
            guard let phase = store.focusCompanion?.pomodoroPhase else { return nil }
            let duration = phase.phaseEndsAt.timeIntervalSince(phase.phaseStartedAt)
            guard duration > 0 else { return 1 }
            return FocusDialMetrics.elapsedFraction(
                totalDuration: duration,
                remainingDuration: phase.phaseEndsAt.timeIntervalSince(date)
            )
        case .stopwatch, .openEnded, .none:
            return nil
        }
    }

    private func clockDisplay(at date: Date) -> (value: TimeInterval, label: String) {
        switch store.focusCompanion?.mode {
        case .countdown:
            let value = max(0, session.targetDuration - session.focusedDuration(at: date))
            return (
                value,
                value == 0 ? "Time is up. Choose what happens next." : "\(PlanSectionCopy.duration(value)) remaining"
            )
        case .pomodoro:
            let value = max(
                0,
                (store.focusCompanion?.pomodoroPhase?.phaseEndsAt ?? date).timeIntervalSince(date)
            )
            return (
                value,
                value == 0 ? "This phase is complete." : "\(PlanSectionCopy.duration(value)) in this phase"
            )
        case .stopwatch, .none:
            let value = session.focusedDuration(at: date)
            return (value, "\(PlanSectionCopy.duration(value)) elapsed")
        case .openEnded:
            return (0, "Open-ended focus")
        }
    }

    private func endTitle(_ outcome: FocusCompletionOutcome) -> String {
        switch outcome {
        case .completed: "Finish focus"
        case .continueLater, .intentionallyDeferred: "Save for later"
        case .abandoned: "Abandon focus"
        case .stopped, .interrupted: "End focus"
        }
    }

    private func endPrompt(_ outcome: FocusCompletionOutcome) -> String {
        switch outcome {
        case .completed: "Save this session as complete?"
        case .continueLater, .intentionallyDeferred: "Keep the context so it is easy to return?"
        case .abandoned: "End this session without marking it complete?"
        case .stopped, .interrupted: "End and keep the time already focused?"
        }
    }

    private func modeLabel(_ mode: FocusMode) -> String {
        switch mode {
        case .countdown: "Countdown"
        case .stopwatch: "Stopwatch"
        case let .pomodoro(_, _, rounds): "Pomodoro · \(rounds) rounds"
        case .openEnded: "Open-ended focus"
        }
    }
}
