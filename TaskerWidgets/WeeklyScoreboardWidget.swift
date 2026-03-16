import SwiftUI
import WidgetKit

struct WeeklyScoreboardWidget: Widget {
    let kind = "WeeklyScoreboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyScoreboardProvider()) { entry in
            WeeklyScoreboardWidgetView(entry: entry)
                .containerBackground(WidgetBrand.canvas, for: .widget)
        }
        .configurationDisplayName("Weekly XP")
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
    private enum WeekScaleMode {
        case goal
        case personalMax
    }

    let entry: WeeklyScoreboardEntry
    private let dayLabels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    private var personalMaxXP: Int {
        max(entry.snapshot.weeklyXP.max() ?? 1, 1)
    }

    private var scaleMode: WeekScaleMode {
        personalMaxXP >= entry.snapshot.dailyCap ? .goal : .personalMax
    }

    private var maxXP: Int {
        switch scaleMode {
        case .goal:
            return max(personalMaxXP, entry.snapshot.dailyCap)
        case .personalMax:
            return personalMaxXP
        }
    }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Convert Sun=1 to Mon-based index 0-6
        return weekday == 1 ? 6 : weekday - 2
    }

    private var freshnessText: String {
        let minutes = max(0, Int(Date().timeIntervalSince(entry.snapshot.updatedAt) / 60))
        if minutes < 1 {
            return "Updated now"
        }
        if minutes < 60 {
            return "Updated \(minutes)m ago"
        }
        let hours = minutes / 60
        return "Updated \(hours)h ago"
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("This Week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetBrand.textSecondary)
                Spacer()
                Text("Total: \(entry.snapshot.weeklyTotalXP)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetBrand.textPrimary)
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
                            .foregroundStyle(index == todayIndex ? WidgetBrand.textPrimary : WidgetBrand.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(dayLabels[index]) \(xp) XP")
                    .accessibilityValue(xp > 0 ? "\(xp) XP" : "No XP")
                    .accessibilityHint(index == todayIndex ? "Today" : (index > todayIndex ? "Future day" : "Past day"))
                }
            }
            .frame(height: 80)

            HStack {
                Text(scaleMode == .goal ? "Goal scale" : "Personal max")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetBrand.textSecondary)
                Spacer()
                Text(freshnessText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetBrand.textSecondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weekly XP total \(entry.snapshot.weeklyTotalXP). Scale \(scaleMode == .goal ? "goal" : "personal max"). \(freshnessText).")
        .widgetURL(URL(string: "tasker://insights"))
    }

    private func barColor(index: Int) -> Color {
        if index == todayIndex { return WidgetBrand.magenta }
        if index > todayIndex { return WidgetBrand.line }
        return WidgetBrand.marigold.opacity(0.55)
    }
}
