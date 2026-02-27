import SwiftUI
import WidgetKit

struct WeeklyScoreboardWidget: Widget {
    let kind = "WeeklyScoreboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyScoreboardProvider()) { entry in
            WeeklyScoreboardWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weekly Scoreboard")
        .description("View your XP for the week.")
        .supportedFamilies([.systemMedium])
    }
}

struct WeeklyScoreboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyScoreboardEntry {
        WeeklyScoreboardEntry(date: Date(), snapshot: GamificationWidgetSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyScoreboardEntry) -> Void) {
        completion(WeeklyScoreboardEntry(date: Date(), snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyScoreboardEntry>) -> Void) {
        let entry = WeeklyScoreboardEntry(date: Date(), snapshot: .load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct WeeklyScoreboardEntry: TimelineEntry {
    let date: Date
    let snapshot: GamificationWidgetSnapshot
}

struct WeeklyScoreboardWidgetView: View {
    let entry: WeeklyScoreboardEntry
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var maxXP: Int {
        max(entry.snapshot.weeklyXP.max() ?? 1, entry.snapshot.dailyCap)
    }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Convert Sun=1 to Mon-based index 0-6
        return weekday == 1 ? 6 : weekday - 2
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("This Week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Total: \(entry.snapshot.weeklyTotalXP)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    let xp = index < entry.snapshot.weeklyXP.count ? entry.snapshot.weeklyXP[index] : 0
                    VStack(spacing: 2) {
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                let height = xp > 0 ? max(4, geo.size.height * CGFloat(xp) / CGFloat(maxXP)) : 4
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(barColor(index: index))
                                    .frame(height: height)
                            }
                        }
                        Text(dayLabels[index])
                            .font(.system(size: 9, weight: index == todayIndex ? .bold : .regular))
                            .foregroundStyle(index == todayIndex ? .primary : .secondary)
                    }
                }
            }
            .frame(height: 80)
        }
    }

    private func barColor(index: Int) -> Color {
        if index == todayIndex { return .accentColor }
        if index > todayIndex { return Color(.systemGray5) }
        return .accentColor.opacity(0.4)
    }
}
