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
        .configurationDisplayName("Active Rhythm")
        .description("Track active days and weekly rhythm.")
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

    @ViewBuilder
    var body: some View {
        #if canImport(AppIntents)
        if let occurrence = actionableOccurrence {
            Button(intent: ResolveBehaviorOccurrenceIntent(
                occurrenceID: occurrence.occurrenceID.uuidString,
                behaviorID: occurrence.behaviorID.uuidString
            )) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint("Marks today’s canonical occurrence complete")
        } else {
            content
                .widgetURL(primary.map { URL(string: "lifeboard://habits/\($0.habitID.uuidString)")! }
                    ?? URL(string: "lifeboard://habits"))
        }
        #else
        content
            .widgetURL(URL(string: "lifeboard://habits"))
        #endif
    }

    private var content: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Consistency", title: "Active Days", detail: nil, accent: WidgetBrand.textPrimary)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "leaf.fill")
                        .widgetAccentedRenderingMode(.accented)
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                        .foregroundStyle((primary?.currentStreak ?? 0) > 0 ? WidgetBrand.sunriseGold : WidgetBrand.line)
                        .widgetAccentable()

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
                            actionableOccurrence == nil ? "No action waiting" : "Tap to record"
                        ])
                    }
                }

                TaskWidgetProgressBar(progress: Double(streakProgress), tint: WidgetBrand.sunriseGold)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current active rhythm \(primary?.currentStreak ?? 0) days. "
                + "Best rhythm \(primary?.bestStreak ?? 0) days."
        )
    }
}
