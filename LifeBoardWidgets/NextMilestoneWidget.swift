import SwiftUI
import WidgetKit

struct NextMilestoneWidget: Widget {
    let kind = "NextMilestoneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextMilestoneProvider()) { entry in
            NextMilestoneWidgetView(entry: entry)
                .modifier(TaskWidgetContainerBackgroundModifier(enabled: true))
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
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Milestone", title: "Next", detail: nil, accent: WidgetBrand.textPrimary)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 14) {
                    TaskWidgetRing(
                        progress: CGFloat(entry.snapshot.milestoneProgress),
                        lineWidth: 7,
                        accent: WidgetBrand.magenta,
                        track: WidgetBrand.line,
                        centerText: "\(Int(entry.snapshot.milestoneProgress * 100))%",
                        numericValue: context.reduceMotion ? nil : entry.snapshot.milestoneProgress * 100
                    )
                    .frame(width: 82, height: 82)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.snapshot.nextMilestoneName ?? "No milestone")
                            .font(TaskWidgetTypography.title)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(3)
                        if let target = entry.snapshot.nextMilestoneXP {
                            Text("\(entry.snapshot.totalXP) / \(target) XP")
                                .font(TaskWidgetTypography.body)
                                .foregroundStyle(WidgetBrand.textSecondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next milestone \(entry.snapshot.nextMilestoneName ?? "Unknown"). \(Int(entry.snapshot.milestoneProgress * 100)) percent complete. Total XP \(entry.snapshot.totalXP).")
        .widgetURL(URL(string: "tasker://insights"))
    }
}
