import SwiftUI
import WidgetKit
import UIKit

enum WidgetBrand {
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.082, green: 0.067, blue: 0.055, alpha: 1) : UIColor(red: 1.0, green: 0.973, blue: 0.937, alpha: 1)
    })
    static let canvasElevated = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.114, green: 0.09, blue: 0.071, alpha: 1) : UIColor(red: 1.0, green: 0.988, blue: 0.973, alpha: 1)
    })
    static let emerald = Color(red: 0.161, green: 0.227, blue: 0.094)
    static let magenta = Color(red: 0.694, green: 0.125, blue: 0.373)
    static let marigold = Color(red: 0.996, green: 0.749, blue: 0.169)
    static let red = Color(red: 0.757, green: 0.075, blue: 0.09)
    static let sandstone = Color(red: 0.62, green: 0.373, blue: 0.039)
    static let actionPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.996, green: 0.749, blue: 0.169, alpha: 1) : UIColor(red: 0.161, green: 0.227, blue: 0.094, alpha: 1)
    })
    static let textPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 1.0, green: 0.953, blue: 0.902, alpha: 1) : UIColor(red: 0.106, green: 0.082, blue: 0.067, alpha: 1)
    })
    static let textSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.906, green: 0.851, blue: 0.796, alpha: 1) : UIColor(red: 0.416, green: 0.349, blue: 0.294, alpha: 1)
    })
    static let line = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.227, green: 0.18, blue: 0.141, alpha: 1) : UIColor(red: 0.886, green: 0.827, blue: 0.761, alpha: 1)
    })
}

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
