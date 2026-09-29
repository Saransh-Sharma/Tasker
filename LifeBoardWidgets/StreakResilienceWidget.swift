import SwiftUI
import WidgetKit
#if canImport(AppIntents)
import AppIntents
#endif

struct StreakResilienceWidget: Widget {
    let kind = "StreakResilienceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakResilienceProvider()) { entry in
            StreakResilienceWidgetView(entry: entry)
                .modifier(TaskWidgetContainerBackgroundModifier(enabled: true))
        }
        .configurationDisplayName("Active Days")
        .description("Active days for a habit.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakResilienceProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakResilienceEntry {
        StreakResilienceEntry(date: Date(), snapshot: TaskListWidgetSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakResilienceEntry) -> Void) {
        completion(StreakResilienceEntry(date: Date(), snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakResilienceEntry>) -> Void) {
        let entry = StreakResilienceEntry(date: Date(), snapshot: .load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct StreakResilienceEntry: TimelineEntry {
    let date: Date
    let snapshot: TaskListWidgetSnapshot
}

struct StreakResilienceWidgetView: View {
    let entry: StreakResilienceEntry

    private var primary: TaskListWidgetHabitPrimary? {
        entry.snapshot.habit.primaryHabit
    }

    private var actionableOccurrence: BehaviorOccurrenceSurfaceSnapshot? {
        guard let primary else { return nil }
        return entry.snapshot.behaviorOccurrences.first {
            $0.domain == .habit
                && $0.behaviorID == primary.habitID
                && $0.result == .unresolved
        }
    }

    private var streakProgress: CGFloat {
        guard let primary, primary.bestStreak > 0 else { return 0 }
        return min(1.0, CGFloat(primary.currentStreak) / CGFloat(primary.bestStreak))
    }

    /// What the one button on this widget does today. Chosen once so the
    /// button, its label, and the metadata line always agree.
    private enum TodayAction {
        case step(Double)
        case complete
        case resolve(BehaviorOccurrenceSurfaceSnapshot)
        case none
    }

    private var todayAction: TodayAction {
        guard let primary else { return .none }
        if primary.targetValue != nil {
            return (primary.currentAmount ?? 0) < (primary.targetValue ?? 1) ? .step(primary.stepValue ?? 1) : .none
        }
        if primary.todayState != .completedToday, actionableOccurrence != nil {
            return .complete
        }
        if let occurrence = actionableOccurrence {
            return .resolve(occurrence)
        }
        return .none
    }

    private var isDoneToday: Bool {
        guard let primary else { return false }
        if let target = primary.targetValue { return (primary.currentAmount ?? 0) >= target }
        return primary.todayState == .completedToday
    }

    private var habitURL: URL? {
        primary.map { URL(string: "lifeboard://habits/habit/\($0.habitID.uuidString)")! }
            ?? URL(string: "lifeboard://habits")
    }

    private var statusLine: String {
        switch todayAction {
        case .step, .complete, .resolve: return "Not logged today"
        case .none: return isDoneToday ? "Done today" : ""
        }
    }

    /// The widget always opens the habit; only the small button logs, so a tap
    /// anywhere else never records something by accident.
    var body: some View {
        content
            .widgetURL(habitURL)
    }

    @ViewBuilder
    private var actionButton: some View {
        #if canImport(AppIntents)
        if let primary {
            switch todayAction {
            case .step(let step):
                Button(intent: LogHabitStepFromWidgetIntent(habitID: primary.habitID.uuidString, step: step)) {
                    actionLabel(title: "+1", symbol: nil)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add 1 to \(primary.title)")
            case .complete:
                Button(intent: CompleteHabitFromWidgetIntent(habitID: primary.habitID.uuidString, isQuitHabit: primary.isQuitHabit ?? false)) {
                    actionLabel(title: nil, symbol: "checkmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log \(primary.title)")
            case .resolve(let occurrence):
                Button(intent: ResolveBehaviorOccurrenceIntent(
                    occurrenceID: occurrence.occurrenceID.uuidString,
                    behaviorID: occurrence.behaviorID.uuidString
                )) {
                    actionLabel(title: nil, symbol: "checkmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log \(primary.title)")
            case .none:
                EmptyView()
            }
        }
        #endif
    }

    private func actionLabel(title: String?, symbol: String?) -> some View {
        Group {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
            } else if let title {
                Text(title)
                    .font(TaskWidgetTypography.captionStrong)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(WidgetBrand.textInverse)
        .frame(width: 36, height: 28)
        .background(WidgetBrand.actionPrimary, in: Capsule())
        .widgetAccentable()
    }

    private var content: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: primary?.title ?? "Habits", title: "Active days", detail: nil, accent: WidgetBrand.textPrimary)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "leaf.fill")
                        .widgetAccentedRenderingMode(.accented)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle((primary?.currentStreak ?? 0) > 0 ? WidgetBrand.sunriseGold : WidgetBrand.line)
                        .widgetAccentable()
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(primary?.currentStreak ?? 0)")
                            .font(TaskWidgetTypography.display)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .taskWidgetNumericTransition(Double(primary?.currentStreak ?? 0), reduceMotion: context.reduceMotion)
                        Text("days active")
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                        TaskWidgetInlineMetadata(items: [
                            "Best \(primary?.bestStreak ?? 0)",
                            statusLine
                        ])
                    }
                }

                HStack(alignment: .center, spacing: 8) {
                    TaskWidgetProgressBar(progress: Double(streakProgress), tint: WidgetBrand.sunriseGold)
                    actionButton
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let name = primary?.title ?? "Habits"
        var parts = ["\(name): \(primary?.currentStreak ?? 0) active days", "best \(primary?.bestStreak ?? 0)"]
        if statusLine.isEmpty == false { parts.append(statusLine.lowercased()) }
        return parts.joined(separator: ", ") + "."
    }
}
