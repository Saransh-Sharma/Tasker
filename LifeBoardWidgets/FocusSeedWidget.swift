import SwiftUI
import WidgetKit

struct FocusSeedWidget: Widget {
    let kind = "FocusSeedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusSeedProvider()) { entry in
            FocusSeedWidgetView(entry: entry)
                .modifier(TaskWidgetContainerBackgroundModifier(enabled: true))
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
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                TaskWidgetSectionHeader(eyebrow: "Focus", title: "Seed", detail: nil, accent: WidgetBrand.textPrimary)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(WidgetBrand.magenta.opacity(0.28), lineWidth: 6)
                        Image(systemName: "timer")
                            .widgetAccentedRenderingMode(.accented)
                            .font(TaskWidgetTypography.titleLarge)
                            .foregroundStyle(WidgetBrand.magenta)
                            .widgetAccentable()
                    }
                    .frame(width: 66, height: 66)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entry.snapshot.focusMinutesToday)")
                            .font(TaskWidgetTypography.display)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .taskWidgetNumericTransition(Double(entry.snapshot.focusMinutesToday), reduceMotion: context.reduceMotion)
                        Text("minutes focused")
                            .font(TaskWidgetTypography.support)
                            .foregroundStyle(WidgetBrand.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                Link(destination: URL(string: "tasker://focus")!) {
                    TaskWidgetActionBandLabel(title: "Start Focus", accent: WidgetBrand.actionPrimary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus today \(entry.snapshot.focusMinutesToday) minutes. Double tap to start focus.")
        .accessibilityHint("Opens focus session")
        .widgetURL(URL(string: "tasker://focus"))
    }
}
