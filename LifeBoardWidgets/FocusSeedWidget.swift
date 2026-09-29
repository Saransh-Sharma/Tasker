import SwiftUI
import WidgetKit

struct FocusSeedWidget: Widget {
    let kind = "FocusSeedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusSeedProvider()) { entry in
            FocusSeedWidgetView(entry: entry)
                .modifier(TaskWidgetContainerBackgroundModifier(enabled: true))
        }
        .configurationDisplayName("Focus")
        .description("Today’s focus time.")
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
                TaskWidgetSectionHeader(eyebrow: "Focus", title: "Today", detail: nil, accent: WidgetBrand.textPrimary)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(WidgetBrand.sky.opacity(0.28), lineWidth: 6)
                        Image(systemName: "timer")
                            .widgetAccentedRenderingMode(.accented)
                            .font(TaskWidgetTypography.titleLarge)
                            .foregroundStyle(WidgetBrand.sky)
                            .widgetAccentable()
                    }
                    // 66pt plus the header and the action band overflowed a
                    // small widget: the eyebrow clipped at the top and
                    // "Start Focus" wrapped and clipped at the bottom.
                    .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entry.snapshot.focusMinutesToday)")
                            .font(TaskWidgetTypography.display)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .taskWidgetNumericTransition(Double(entry.snapshot.focusMinutesToday), reduceMotion: context.reduceMotion)
                        Text("min")
                            .font(TaskWidgetTypography.support)
                            .lineLimit(1)
                            .foregroundStyle(WidgetBrand.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                Link(destination: URL(string: "lifeboard://focus")!) {
                    // Short enough for a small widget; the header already says Focus.
                    TaskWidgetActionBandLabel(title: "Start", accent: WidgetBrand.actionPrimary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus today: \(entry.snapshot.focusMinutesToday) minutes")
        .accessibilityHint("Opens Focus")
        .widgetURL(URL(string: "lifeboard://focus"))
    }
}
