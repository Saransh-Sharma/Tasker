import SwiftUI
import WidgetKit

struct FocusSeedWidget: Widget {
    let kind = "FocusSeedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusSeedProvider()) { entry in
            FocusSeedWidgetView(entry: entry)
                .containerBackground(WidgetBrand.canvas, for: .widget)
        }
        .configurationDisplayName("Focus Seed")
        .description("See today's focus time and start a session.")
        .supportedFamilies([.systemSmall])
    }
}

struct FocusSeedProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusSeedEntry {
        FocusSeedEntry(date: Date(), snapshot: GamificationWidgetSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusSeedEntry) -> Void) {
        completion(FocusSeedEntry(date: Date(), snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusSeedEntry>) -> Void) {
        let entry = FocusSeedEntry(date: Date(), snapshot: .load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct FocusSeedEntry: TimelineEntry {
    let date: Date
    let snapshot: GamificationWidgetSnapshot
}

struct FocusSeedWidgetView: View {
    let entry: FocusSeedEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 28))
                .foregroundStyle(WidgetBrand.magenta)

            Text("\(entry.snapshot.focusMinutesToday) min")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetBrand.textPrimary)
            Text("focused today")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetBrand.textSecondary)

            Link(destination: URL(string: "tasker://focus")!) {
                Text("Start Focus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetBrand.canvasElevated)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(WidgetBrand.actionPrimary, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus today \(entry.snapshot.focusMinutesToday) minutes. Double tap to start focus.")
        .accessibilityHint("Opens focus session")
        .widgetURL(URL(string: "tasker://focus"))
    }
}
