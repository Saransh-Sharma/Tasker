import SwiftUI
import WidgetKit

struct StreakResilienceWidget: Widget {
    let kind = "StreakResilienceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakResilienceProvider()) { entry in
            StreakResilienceWidgetView(entry: entry)
                .modifier(TaskWidgetContainerBackgroundModifier(enabled: true))
        }
        .configurationDisplayName("Streak")
        .description("Track your streak and best record.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakResilienceProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakResilienceEntry {
        StreakResilienceEntry(date: Date(), snapshot: GamificationWidgetSnapshot())
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
    let snapshot: GamificationWidgetSnapshot
}

struct StreakResilienceWidgetView: View {
    let entry: StreakResilienceEntry

    private var streakProgress: CGFloat {
        guard entry.snapshot.bestStreak > 0 else { return 0 }
        return min(1.0, CGFloat(entry.snapshot.streakDays) / CGFloat(entry.snapshot.bestStreak))
    }

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Consistency", title: "Streak", detail: nil, accent: WidgetBrand.textPrimary)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "flame.fill")
                        .widgetAccentedRenderingMode(.accented)
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.snapshot.streakDays > 0 ? WidgetBrand.marigold : WidgetBrand.line)
                        .widgetAccentable()

                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(entry.snapshot.streakDays)")
                            .font(TaskWidgetTypography.display)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .taskWidgetNumericTransition(Double(entry.snapshot.streakDays), reduceMotion: context.reduceMotion)
                        Text("days active")
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                        TaskWidgetInlineMetadata(items: ["Best \(entry.snapshot.bestStreak)", "Keep it alive"])
                    }
                }

                TaskWidgetProgressBar(progress: Double(streakProgress), tint: WidgetBrand.magenta)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current streak \(entry.snapshot.streakDays) days. Best streak \(entry.snapshot.bestStreak) days.")
        .widgetURL(URL(string: "lifeboard://insights"))
    }
}
