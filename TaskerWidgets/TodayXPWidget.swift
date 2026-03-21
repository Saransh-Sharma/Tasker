import SwiftUI
import WidgetKit

struct TodayXPWidget: Widget {
    let kind = "TodayXPWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayXPProvider()) { entry in
            TodayXPWidgetView(entry: entry)
                .modifier(TaskWidgetContainerBackgroundModifier(enabled: true))
        }
        .configurationDisplayName("Today's XP")
        .description("Track your daily XP progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayXPProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayXPEntry {
        TodayXPEntry(date: Date(), snapshot: GamificationWidgetSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayXPEntry) -> Void) {
        let snapshot = GamificationWidgetSnapshot.load()
        completion(TodayXPEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayXPEntry>) -> Void) {
        let snapshot = GamificationWidgetSnapshot.load()
        let entry = TodayXPEntry(date: Date(), snapshot: snapshot)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct TodayXPEntry: TimelineEntry {
    let date: Date
    let snapshot: GamificationWidgetSnapshot
}

struct TodayXPWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodayXPEntry

    private var progress: CGFloat {
        guard entry.snapshot.dailyCap > 0 else { return 0 }
        return min(1.0, CGFloat(entry.snapshot.dailyXP) / CGFloat(entry.snapshot.dailyCap))
    }

    private var freshnessText: String {
        let minutes = max(0, Int(Date().timeIntervalSince(entry.snapshot.updatedAt) / 60))
        if minutes < 1 {
            return "Updated now"
        }
        if minutes < 60 {
            return "Updated \(minutes)m ago"
        }
        return "Updated \(minutes / 60)h ago"
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            default:
                mediumView
            }
        }
        .widgetURL(URL(string: "tasker://home"))
    }

    private var smallView: some View {
        TaskWidgetScene(alignment: .topLeading) { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Today", title: "XP", detail: "L\(entry.snapshot.level)", accent: WidgetBrand.textPrimary)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 14) {
                    xpRing(size: 82, lineWidth: 7, reduceMotion: context.reduceMotion)
                        .frame(width: 82, height: 82)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(entry.snapshot.dailyXP)")
                            .font(TaskWidgetTypography.display)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .taskWidgetNumericTransition(Double(entry.snapshot.dailyXP), reduceMotion: context.reduceMotion)
                        Text("/ \(entry.snapshot.dailyCap) XP")
                            .font(TaskWidgetTypography.body)
                            .foregroundStyle(WidgetBrand.textSecondary)
                        TaskWidgetInlineMetadata(items: ["\(entry.snapshot.streakDays)d streak", freshnessText])
                    }
                }

                Spacer(minLength: 0)

                TaskWidgetProgressBar(
                    progress: Double(progress),
                    tint: entry.snapshot.dailyXP >= entry.snapshot.dailyCap ? WidgetBrand.emerald : WidgetBrand.magenta
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's XP \(entry.snapshot.dailyXP) of \(entry.snapshot.dailyCap). Level \(entry.snapshot.level). \(entry.snapshot.streakDays) day streak. \(freshnessText).")
    }

    private var mediumView: some View {
        TaskWidgetScene(alignment: .topLeading) { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TaskWidgetSectionHeader(eyebrow: "Today", title: "XP Arc", detail: nil, accent: WidgetBrand.textPrimary)
                    Spacer(minLength: 0)
                    Text(freshnessText)
                        .font(TaskWidgetTypography.meta)
                        .foregroundStyle(WidgetBrand.textSecondary)
                }

                HStack(alignment: .center, spacing: 18) {
                    xpRing(size: 104, lineWidth: 8, reduceMotion: context.reduceMotion)
                        .frame(width: 104, height: 104)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(entry.snapshot.dailyXP)")
                            .font(TaskWidgetTypography.display)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .taskWidgetNumericTransition(Double(entry.snapshot.dailyXP), reduceMotion: context.reduceMotion)
                        Text("/ \(entry.snapshot.dailyCap) XP")
                            .font(TaskWidgetTypography.title)
                            .foregroundStyle(WidgetBrand.textSecondary)
                        TaskWidgetProgressBar(
                            progress: Double(progress),
                            tint: entry.snapshot.dailyXP >= entry.snapshot.dailyCap ? WidgetBrand.emerald : WidgetBrand.magenta
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                TaskWidgetPanel(accent: WidgetBrand.magenta, style: .softSection, padding: 12) {
                    TaskWidgetStatStrip(items: [
                        TaskWidgetStatItem(title: "Level", value: "L\(entry.snapshot.level)", tint: WidgetBrand.textPrimary),
                        TaskWidgetStatItem(title: "Streak", value: "\(entry.snapshot.streakDays)d", tint: WidgetBrand.marigold),
                        TaskWidgetStatItem(title: "Focus", value: "\(entry.snapshot.focusMinutesToday)m", tint: WidgetBrand.magenta)
                    ])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's XP \(entry.snapshot.dailyXP) of \(entry.snapshot.dailyCap). Level \(entry.snapshot.level). \(entry.snapshot.streakDays) day streak. \(freshnessText).")
    }

    private func xpRing(size: CGFloat, lineWidth: CGFloat, reduceMotion: Bool) -> some View {
        TaskWidgetRing(
            progress: progress,
            lineWidth: lineWidth,
            accent: WidgetBrand.magenta,
            track: WidgetBrand.line,
            centerText: "\(entry.snapshot.dailyXP)",
            numericValue: reduceMotion ? nil : Double(entry.snapshot.dailyXP)
        )
        .frame(width: size, height: size)
    }
}
