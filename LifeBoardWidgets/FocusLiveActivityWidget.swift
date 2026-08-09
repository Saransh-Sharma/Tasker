import ActivityKit
import SwiftUI
import WidgetKit

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.state.phase == "paused" ? "pause.circle.fill" : "scope")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.35, green: 0.24, blue: 0.12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                    focusTime(context.state)
                }
                Spacer(minLength: 8)
                Link(destination: primaryURL(context)) {
                    Image(systemName: context.state.phase == "paused" ? "play.fill" : "pause.fill")
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.94, green: 0.80, blue: 0.53), in: Circle())
                }
                .accessibilityLabel(context.state.phase == "paused" ? "Resume focus" : "Pause focus")
                Link(destination: FocusActivityLink.url(
                    sessionID: context.attributes.sessionID,
                    command: "end",
                    token: context.state.endCommandToken
                )) {
                    Image(systemName: "stop.fill").frame(width: 44, height: 44)
                }
                .accessibilityLabel("End focus")
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 1.0, green: 0.97, blue: 0.85))
            .activitySystemActionForegroundColor(Color(red: 0.17, green: 0.13, blue: 0.09))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "scope") }
                DynamicIslandExpandedRegion(.trailing) { focusTime(context.state) }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.title).font(.caption).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "scope")
            } compactTrailing: {
                focusTime(context.state)
            } minimal: {
                Image(systemName: "scope")
            }
            .keylineTint(Color(red: 0.94, green: 0.80, blue: 0.53))
        }
    }

    @ViewBuilder
    private func focusTime(_ state: FocusActivityAttributes.ContentState) -> some View {
        if state.phase == "running", let end = state.expectedEndAt {
            Text(timerInterval: Date()...max(Date().addingTimeInterval(1), end), countsDown: true)
                .font(.subheadline.monospacedDigit())
        } else {
            Text(durationLabel(state.remainingDuration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func primaryURL(_ context: ActivityViewContext<FocusActivityAttributes>) -> URL {
        FocusActivityLink.url(
            sessionID: context.attributes.sessionID,
            command: context.state.phase == "paused" ? "resume" : "pause",
            token: context.state.primaryCommandToken
        )
    }

    private func durationLabel(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct FastingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.35, green: 0.24, blue: 0.12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                    fastingTime(context.state)
                }
                Spacer(minLength: 8)
                if context.state.phase == "active" {
                    Link(destination: FastingActivityLink.url(
                        sessionID: context.attributes.sessionID,
                        command: "finish",
                        token: context.state.finishCommandToken
                    )) {
                        Image(systemName: "checkmark")
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.77, green: 0.85, blue: 0.68), in: Circle())
                    }
                    .accessibilityLabel("End fast")
                    Link(destination: FastingActivityLink.url(
                        sessionID: context.attributes.sessionID,
                        command: "cancel",
                        token: context.state.cancelCommandToken
                    )) {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Cancel fast")
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 1.0, green: 0.97, blue: 0.85))
            .activitySystemActionForegroundColor(Color(red: 0.17, green: 0.13, blue: 0.09))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "timer") }
                DynamicIslandExpandedRegion(.trailing) { fastingTime(context.state) }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.title).font(.caption).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                fastingTime(context.state)
            } minimal: {
                Image(systemName: "timer")
            }
            .keylineTint(Color(red: 0.77, green: 0.85, blue: 0.68))
        }
    }

    @ViewBuilder
    private func fastingTime(_ state: FastingActivityAttributes.ContentState) -> some View {
        if state.phase == "active", let targetEndAt = state.targetEndAt {
            Text(timerInterval: Date()...max(Date().addingTimeInterval(1), targetEndAt), countsDown: true)
                .font(.subheadline.monospacedDigit())
        } else if state.phase == "active" {
            Text(state.startedAt, style: .timer)
                .font(.subheadline.monospacedDigit())
        } else {
            Text(durationLabel(state.elapsedDuration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func durationLabel(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct RoutineLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutineActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "repeat.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.35, green: 0.24, blue: 0.12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title).font(.headline).lineLimit(1)
                    Text(context.state.stepTitle).font(.caption).lineLimit(1)
                    Text("\(context.state.completedStepCount) of \(context.state.totalStepCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if context.state.status == "running"
                    || context.state.status == "paused"
                    || context.state.status == "interrupted" {
                    Link(destination: primaryURL(context)) {
                        Image(systemName: context.state.status == "running" ? "pause.fill" : "play.fill")
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.94, green: 0.80, blue: 0.53), in: Circle())
                    }
                    .accessibilityLabel(context.state.status == "running" ? "Pause routine" : "Resume routine")
                    Link(destination: RoutineActivityLink.url(
                        runID: context.attributes.runID,
                        command: "stop",
                        token: context.state.stopCommandToken
                    )) {
                        Image(systemName: "stop.fill").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Stop routine")
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 1.0, green: 0.97, blue: 0.85))
            .activitySystemActionForegroundColor(Color(red: 0.17, green: 0.13, blue: 0.09))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "repeat.circle.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.completedStepCount)/\(context.state.totalStepCount)")
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.stepTitle).font(.caption).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "repeat")
            } compactTrailing: {
                Text("\(context.state.completedStepCount)/\(context.state.totalStepCount)")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "repeat")
            }
            .keylineTint(Color(red: 0.94, green: 0.80, blue: 0.53))
        }
    }

    private func primaryURL(
        _ context: ActivityViewContext<RoutineActivityAttributes>
    ) -> URL {
        RoutineActivityLink.url(
            runID: context.attributes.runID,
            command: context.state.status == "running" ? "pause" : "resume",
            token: context.state.primaryCommandToken
        )
    }
}
