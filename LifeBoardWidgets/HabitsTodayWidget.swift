import SwiftUI
import WidgetKit
#if canImport(AppIntents)
import AppIntents
#endif

/// Today's habits, loggable from the Home Screen without opening the app:
/// up to four rings on the medium widget, the primary habit on the Lock
/// Screen circle. One tap adds a step (or logs a check-in); the app
/// drains the queued command the next time it is active and the timeline
/// reloads from the refreshed snapshot.
struct HabitsTodayWidget: Widget {
    let kind = "HabitsTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakResilienceProvider()) { entry in
            HabitsTodayWidgetView(entry: entry)
                .modifier(TaskWidgetContainerBackgroundModifier(enabled: true))
        }
        .configurationDisplayName("Habits")
        .description("Log today’s habits.")
        .supportedFamilies([.systemMedium, .accessoryCircular])
    }
}

struct HabitsTodayWidgetView: View {
    let entry: StreakResilienceEntry
    @Environment(\.widgetFamily) private var family

    private var habits: [TaskListWidgetHabitPrimary] {
        let today = entry.snapshot.habit.today ?? []
        if today.isEmpty, let primary = entry.snapshot.habit.primaryHabit { return [primary] }
        return Array(today.prefix(4))
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        default:
            medium
        }
    }

    private var medium: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Today", title: "Habits", detail: nil, accent: WidgetBrand.textPrimary)
                if habits.isEmpty {
                    Text("No habits today")
                        .font(TaskWidgetTypography.support)
                        .foregroundStyle(WidgetBrand.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(habits) { habit in
                            HabitsTodayRing(habit: habit, reduceMotion: context.reduceMotion)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .widgetURL(URL(string: "lifeboard://habits"))
    }

    @ViewBuilder
    private var circular: some View {
        if let habit = habits.first {
            HabitsTodayRing(habit: habit, reduceMotion: true, compact: true)
                .widgetURL(URL(string: "lifeboard://habits/habit/\(habit.habitID.uuidString)"))
        } else {
            Image(systemName: "repeat")
                .font(.system(size: 22, weight: .semibold))
                .widgetURL(URL(string: "lifeboard://habits"))
        }
    }
}

/// One habit's ring, drawn with `Circle().trim` because the app's
/// `HabitProgressRing` is not in the widget target. The tap is an intent that
/// runs without opening the app.
struct HabitsTodayRing: View {
    let habit: TaskListWidgetHabitPrimary
    let reduceMotion: Bool
    var compact = false

    private var target: Double { habit.targetValue ?? 1 }
    private var current: Double {
        if let amount = habit.currentAmount { return amount }
        return habit.todayState == .completedToday ? 1 : 0
    }
    private var progress: Double { target > 0 ? min(1, current / target) : 0 }
    private var isDone: Bool { progress >= 1 }
    private var isAmount: Bool { habit.targetValue != nil }
    private var stepSize: Double { habit.stepValue ?? 1 }

    private var readout: String {
        guard isAmount else { return isDone ? "Done" : "Tap" }
        if habit.targetIsTimed == true {
            return "\(Int((current / 60).rounded(.down)))/\(Int((target / 60).rounded()))"
        }
        return "\(Int(current.rounded()))/\(Int(target.rounded()))"
    }

    private var accessibilityValue: String {
        guard isAmount else { return isDone ? "Done" : "Not done" }
        if habit.targetIsTimed == true {
            return "\(Int((current / 60).rounded(.down))) of \(Int((target / 60).rounded())) minutes"
        }
        let unit = habit.targetUnit ?? ""
        return unit.isEmpty ? "\(Int(current.rounded())) of \(Int(target.rounded()))" : "\(Int(current.rounded())) of \(Int(target.rounded())) \(unit)"
    }

    var body: some View {
        #if canImport(AppIntents)
        if isDone {
            ring
        } else if isAmount {
            // One tap logs: that is the widget's whole job.
            Button(intent: LogHabitStepFromWidgetIntent(habitID: habit.habitID.uuidString, step: stepSize)) { ring }
                .buttonStyle(.plain)
                .accessibilityLabel("Add 1 to \(habit.title)")
                .accessibilityValue(accessibilityValue)
        } else {
            Button(intent: CompleteHabitFromWidgetIntent(habitID: habit.habitID.uuidString, isQuitHabit: habit.isQuitHabit ?? false)) { ring }
                .buttonStyle(.plain)
                .accessibilityLabel("Log \(habit.title)")
                .accessibilityValue(accessibilityValue)
        }
        #else
        ring
        #endif
    }

    private var ring: some View {
        let side: CGFloat = compact ? 52 : 44
        let width: CGFloat = compact ? 6 : 5
        let tint = WidgetBrand.sunriseGold
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(WidgetBrand.line, lineWidth: width)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(MotionProfile.localState.animation(reduceMotion: reduceMotion), value: progress)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: compact ? 18 : 14, weight: .bold))
                        .foregroundStyle(tint)
                } else if compact {
                    Image(systemName: habit.iconSymbolName)
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Text(readout)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetBrand.textPrimary)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(width: side, height: side)
            if compact == false {
                Text(habit.title)
                    .font(TaskWidgetTypography.support)
                    .foregroundStyle(WidgetBrand.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(habit.title)
        .accessibilityValue(accessibilityValue)
    }
}
