import SwiftUI
import WidgetKit

struct StreakResilienceWidget: Widget {
    let kind = "StreakResilienceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakResilienceProvider()) { entry in
            StreakResilienceWidgetView(entry: entry)
                .containerBackground(WidgetBrand.canvas, for: .widget)
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
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 36))
                .foregroundStyle(entry.snapshot.streakDays > 0 ? WidgetBrand.marigold : WidgetBrand.line)

            Text("\(entry.snapshot.streakDays)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetBrand.textPrimary)
            Text("days")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetBrand.textSecondary)

            VStack(spacing: 2) {
                Text("Best: \(entry.snapshot.bestStreak) days")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetBrand.textSecondary)
                ProgressView(value: streakProgress)
                    .tint(WidgetBrand.magenta)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current streak \(entry.snapshot.streakDays) days. Best streak \(entry.snapshot.bestStreak) days."
        )
        .widgetURL(URL(string: "tasker://insights"))
    }
}
