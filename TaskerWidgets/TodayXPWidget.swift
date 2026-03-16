import SwiftUI
import WidgetKit

struct TodayXPWidget: Widget {
    let kind = "TodayXPWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayXPProvider()) { entry in
            TodayXPWidgetView(entry: entry)
                .containerBackground(WidgetBrand.canvas, for: .widget)
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
        VStack(spacing: 6) {
            xpRing(size: 56, lineWidth: 5)
            Text("\(entry.snapshot.dailyXP)/\(entry.snapshot.dailyCap) XP")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetBrand.textSecondary)
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(WidgetBrand.marigold)
                Text("\(entry.snapshot.streakDays) days")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetBrand.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Today's XP \(entry.snapshot.dailyXP) of \(entry.snapshot.dailyCap). Level \(entry.snapshot.level). \(entry.snapshot.streakDays) day streak. \(freshnessText)."
        )
    }

    private var mediumView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                xpRing(size: 56, lineWidth: 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetBrand.textSecondary)
                    HStack(spacing: 4) {
                        Text("\(entry.snapshot.dailyXP)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetBrand.textPrimary)
                        Text("/ \(entry.snapshot.dailyCap) XP")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WidgetBrand.textSecondary)
                    }
                    ProgressView(value: progress)
                        .tint(entry.snapshot.dailyXP >= entry.snapshot.dailyCap ? WidgetBrand.emerald : WidgetBrand.magenta)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("L\(entry.snapshot.level)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetBrand.canvasElevated)
                        .frame(width: 28, height: 28)
                        .background(WidgetBrand.actionPrimary, in: Capsule())
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(WidgetBrand.marigold)
                        Text("\(entry.snapshot.streakDays)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(WidgetBrand.textPrimary)
                    }
                }
            }

            HStack {
                Spacer()
                Text(freshnessText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetBrand.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Today's XP \(entry.snapshot.dailyXP) of \(entry.snapshot.dailyCap). Level \(entry.snapshot.level). \(entry.snapshot.streakDays) day streak. \(freshnessText)."
        )
    }

    private func xpRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(WidgetBrand.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(WidgetBrand.magenta, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(entry.snapshot.dailyXP)")
                .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetBrand.textPrimary)
        }
        .frame(width: size, height: size)
    }
}
