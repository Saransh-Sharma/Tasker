import SwiftUI

/// Presentation receives already resolved capacity; it never invents an estimate.
struct HomeCapacityCardContent: View {
    let title: String
    let summary: String
    let detail: String
    var needsSetup = false
    let palette: DaypartPalette
    var onOpen: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HomeWidgetTitle(title, symbol: "calendar.badge.clock", palette: palette)
                .accessibilityIdentifier("home.widget.scheduleCapacity")
                .homeCardEvidence("capacity.title", role: "title", copy: title, typography: .init(role: "headline", points: 17, weight: "semibold", alignment: "leading"))
            if needsSetup {
                HomeEmptyStateRow(String(localized: "Connect Calendar to see free time"), symbol: "calendar.badge.plus", palette: palette)
            } else {
                Text(summary)
                    .font(.title3.weight(.semibold))
                    .homeCardEvidence("capacity.summary", role: "value", copy: summary, typography: .init(role: "title3", points: 20, weight: "semibold", alignment: "leading"))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.subheadline)
                    .homeCardEvidence("capacity.detail", role: "text", copy: detail, typography: .init(role: "subheadline", points: 15, weight: "regular", alignment: "leading"))
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Open day", action: onOpen)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.capacity.openDay")
                .homeCardEvidence("capacity.open", role: "control", copy: "Open day", typography: .init(role: "subheadline", points: 15, weight: "semibold", alignment: "leading"))
        }
        .padding(16)
    }
}
