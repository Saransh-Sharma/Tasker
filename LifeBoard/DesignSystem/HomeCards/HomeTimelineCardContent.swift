import SwiftUI

struct HomeTimelineCardContent: View {
    let items: [AdaptiveTimelineItem]
    var onOpen: () -> Void = {}
    let palette: DaypartPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HomeWidgetTitle("Now & next", symbol: "timeline.selection", palette: palette)
                .accessibilityIdentifier("home.widget.compactTimeline")
                .homeCardEvidence("timeline.title", role: "title", copy: "Now & next", typography: .init(role: "headline", points: 17, weight: "semibold", alignment: "leading"))
            if items.isEmpty {
                HomeEmptyStateRow("Your next three commitments will appear here", symbol: "calendar", palette: palette)
            } else {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Text(item.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                            .frame(width: 62, alignment: .leading)
                            .homeCardEvidence("timeline.\(item.id).time", role: "text", copy: item.startDate.formatted(date: .omitted, time: .shortened), typography: .init(role: "caption.monospacedDigit", points: 12, weight: "semibold", alignment: "leading"))
                        Capsule().fill(palette.color(for: .layerTwo)).frame(width: 4, height: 34)
                        Text(item.title).font(.subheadline.weight(.medium)).lineLimit(2)
                            .homeCardEvidence("timeline.\(item.id).title", role: "text", copy: item.title, typography: .init(role: "subheadline", points: 15, weight: "medium", alignment: "leading"))
                        Spacer()
                    }
                }
            }
            Button("Open complete day shape", action: onOpen)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.timeline.openDay")
                .homeCardEvidence("timeline.open", role: "control", copy: "Open complete day shape", typography: .init(role: "subheadline", points: 15, weight: "semibold", alignment: "leading"))
        }
        .padding(16)
    }
}

