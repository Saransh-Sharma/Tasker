import ActivityKit
import SwiftUI
import WidgetKit

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LifeBoardFocusActivityAttributes.self) { context in
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
                Link(destination: LifeBoardFocusActivityLink.url(
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
    private func focusTime(_ state: LifeBoardFocusActivityAttributes.ContentState) -> some View {
        if state.phase == "running", let end = state.expectedEndAt {
            Text(timerInterval: Date()...max(Date().addingTimeInterval(1), end), countsDown: true)
                .font(.subheadline.monospacedDigit())
        } else {
            Text(durationLabel(state.remainingDuration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func primaryURL(_ context: ActivityViewContext<LifeBoardFocusActivityAttributes>) -> URL {
        LifeBoardFocusActivityLink.url(
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
