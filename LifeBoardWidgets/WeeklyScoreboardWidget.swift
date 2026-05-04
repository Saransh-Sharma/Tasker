import SwiftUI
import WidgetKit

struct WeeklyScoreboardWidget: Widget {
    let kind = "WeeklyScoreboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyScoreboardProvider()) { entry in
            WeeklyScoreboardWidgetView(entry: entry)
                .modifier(TaskWidgetContainerBackgroundModifier(enabled: true))
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
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

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
        TaskWidgetScene { context in
            HStack(alignment: .top, spacing: context.panelSpacing) {
                VStack(alignment: .leading, spacing: context.sectionSpacing) {
                    TaskWidgetSectionHeader(eyebrow: "XP", title: "This Week", detail: nil, accent: WidgetBrand.textPrimary)
                    Text("\(entry.snapshot.weeklyTotalXP)")
                        .font(TaskWidgetTypography.display)
                        .foregroundStyle(WidgetBrand.magenta)
                        .taskWidgetNumericTransition(Double(entry.snapshot.weeklyTotalXP), reduceMotion: context.reduceMotion)
                    Text(scaleMode == .goal ? "Scaled to daily goal." : "Scaled to personal max.")
                        .font(TaskWidgetTypography.body)
                        .foregroundStyle(WidgetBrand.textSecondary)
                        .lineLimit(2)
                    Text(freshnessText)
                        .font(TaskWidgetTypography.caption)
                        .foregroundStyle(WidgetBrand.textSecondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 10) {
                    TaskWidgetSectionHeader(eyebrow: "Week", title: "Scoreboard", detail: nil, accent: WidgetBrand.textPrimary)
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            let xp = index < entry.snapshot.weeklyXP.count ? entry.snapshot.weeklyXP[index] : 0
                            VStack(spacing: 6) {
                                GeometryReader { geo in
                                    VStack {
                                        Spacer()
                                        let height = xp > 0 ? max(6, geo.size.height * CGFloat(xp) / CGFloat(maxXP)) : 6
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(barColor(index: index))
                                            .frame(height: height)
                                    }
                                }
                                .frame(maxWidth: .infinity)

                                Text(dayLabels[index])
                                    .font(TaskWidgetTypography.meta)
                                    .foregroundStyle(index == todayIndex ? WidgetBrand.textPrimary : WidgetBrand.textSecondary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(dayLabels[index]) \(xp) XP")
                            .accessibilityHint(index == todayIndex ? "Today" : (index > todayIndex ? "Future day" : "Past day"))
                        }
                    }
                    .frame(height: max(context.chartHeight, 114))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .background(WidgetBrand.canvasSecondary.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.card, style: .continuous))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weekly XP total \(entry.snapshot.weeklyTotalXP). Scale \(scaleMode == .goal ? "goal" : "personal max"). \(freshnessText).")
        .widgetURL(URL(string: "lifeboard://insights"))
    }

    private func barColor(index: Int) -> Color {
        if index == todayIndex { return WidgetBrand.magenta }
        if index > todayIndex { return WidgetBrand.line }
        return WidgetBrand.marigold.opacity(0.55)
    }
}
