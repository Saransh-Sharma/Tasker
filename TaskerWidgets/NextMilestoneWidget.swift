import SwiftUI
import WidgetKit

struct NextMilestoneWidget: Widget {
    let kind = "NextMilestoneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextMilestoneProvider()) { entry in
            NextMilestoneWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Milestone")
        .description("Track progress toward your next milestone.")
        .supportedFamilies([.systemSmall])
    }
}

struct NextMilestoneProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextMilestoneEntry {
        NextMilestoneEntry(date: Date(), snapshot: GamificationWidgetSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (NextMilestoneEntry) -> Void) {
        completion(NextMilestoneEntry(date: Date(), snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextMilestoneEntry>) -> Void) {
        let entry = NextMilestoneEntry(date: Date(), snapshot: .load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct NextMilestoneEntry: TimelineEntry {
    let date: Date
    let snapshot: GamificationWidgetSnapshot
}

struct NextMilestoneWidgetView: View {
    let entry: NextMilestoneEntry

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(entry.snapshot.milestoneProgress))
                    .stroke(.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(entry.snapshot.milestoneProgress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(width: 64, height: 64)

            if let name = entry.snapshot.nextMilestoneName {
                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }

            if let target = entry.snapshot.nextMilestoneXP {
                Text("\(entry.snapshot.totalXP)/\(target)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Next milestone \(entry.snapshot.nextMilestoneName ?? "Unknown"). \(Int(entry.snapshot.milestoneProgress * 100)) percent complete. Total XP \(entry.snapshot.totalXP)."
        )
        .widgetURL(URL(string: "tasker://insights"))
    }
}
