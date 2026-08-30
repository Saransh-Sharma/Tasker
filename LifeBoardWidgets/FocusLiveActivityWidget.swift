import ActivityKit
import SwiftUI
import WidgetKit

/// The widget's colours, resolved from the design tokens rather than
/// re-transcribed.
///
/// Every value below used to be a `Color(red:green:blue:)` literal, and each was
/// a hand-copied approximation of a token that already existed — off by a single
/// 8-bit unit in each channel, which is exactly what transcription drift looks
/// like. A Live Activity sits on the Lock Screen next to nothing else the app
/// draws, so nobody ever noticed the app and its activity were a shade apart.
///
/// The `foundation*` statics are used rather than `Color.lifeboard(_:)` because
/// a widget extension has no `ThemeStore`.
private enum WidgetPalette {
    /// Was a red/green/blue literal resolving to `#FFF7D9`, against the
    /// canvas token's `#FFF7D8`.
    static let canvas = Color(SemanticColorTokens.foundationCanvas)
    /// Was a red/green/blue literal resolving to `#2B2117`, against
    /// `inkPrimary`'s `#2B2118`.
    static let ink = Color(SemanticColorTokens.inkPrimary)
    /// Was a red/green/blue literal resolving to `#F0CC87`, against the
    /// sun accent's `#F0CD87`.
    static let sun = Color(SemanticColorTokens.foundationSunAccent)
    /// Was a red/green/blue literal resolving to `#593D1F`, one unit from
    /// the focus-ring token — but it is used as body ink on the warm canvas, not
    /// as a focus ring, so it resolves to the ink role it was always playing.
    /// That also darkens it, which raises contrast on the cream background.
    static let bodyInk = Color(SemanticColorTokens.inkPrimary)
    /// The one value with no counterpart in the palette: a soft sage used as a
    /// completion mark's ground. Left as a literal deliberately rather than
    /// bent onto `statusSuccess` (`#5D6A4D`), which is far darker and would
    /// invert the mark's contrast.
    static let completionGround = Color(red: 0.77, green: 0.85, blue: 0.68)
}

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.state.phase == "paused" ? "pause.circle.fill" : "scope")
                    .font(.title2)
                    .foregroundStyle(WidgetPalette.bodyInk)
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
                        .background(WidgetPalette.sun, in: Circle())
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
            .activityBackgroundTint(WidgetPalette.canvas)
            .activitySystemActionForegroundColor(WidgetPalette.ink)
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
            .keylineTint(WidgetPalette.sun)
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
                    .foregroundStyle(WidgetPalette.bodyInk)
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
                            .background(WidgetPalette.completionGround, in: Circle())
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
            .activityBackgroundTint(WidgetPalette.canvas)
            .activitySystemActionForegroundColor(WidgetPalette.ink)
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
            .keylineTint(WidgetPalette.completionGround)
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
                    .foregroundStyle(WidgetPalette.bodyInk)
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
                            .background(WidgetPalette.sun, in: Circle())
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
            .activityBackgroundTint(WidgetPalette.canvas)
            .activitySystemActionForegroundColor(WidgetPalette.ink)
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
            .keylineTint(WidgetPalette.sun)
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
