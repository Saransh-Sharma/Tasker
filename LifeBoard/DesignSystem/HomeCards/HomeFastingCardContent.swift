import SwiftUI

/// A clock-free view. Only the live adapter schedules time updates.
struct HomeFastingCardContent: View {
    let elapsed: String?
    let finish: String
    let progress: Double
    let palette: DaypartPalette
    var onOpen: () -> Void = {}
    var onEnd: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 14) {
                    HomeWidgetTitle("Active fast", symbol: "timer", palette: palette)
                        .accessibilityIdentifier("home.widget.fasting")
                .homeCardEvidence("fasting.title", role: "title", copy: "Active fast", typography: .init(role: "headline", points: 17, weight: "semibold", alignment: "leading"))
                    if let elapsed {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(elapsed).lifeboardFont(.metric).monospacedDigit()
                            Text(finish).font(.caption)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                                .fixedSize(horizontal: false, vertical: true)
                            ProgressView(value: min(1, max(0, progress)))
                                .progressViewStyle(HomeCardLinearProgressStyle(track: palette.color(for: .canvasSecondary), tint: palette.color(for: .celestialCore)))
                                .accessibilityLabel("Planned duration")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Active fast")
                        .accessibilityValue("\(elapsed) elapsed. \(finish)")
                    } else {
                        HomeEmptyStateRow("No fast is active", symbol: "checkmark.circle", palette: palette)
                            .homeCardEvidence("fasting.empty", role: "text", copy: "No fast is active", typography: .init(role: "subheadline", points: 15, weight: "regular", alignment: "leading"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if elapsed != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { endButton; detailsButton }
                    VStack(spacing: 8) { endButton; detailsButton }
                }
            } else {
                Button("Start a fast", action: onOpen)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .homeCardEvidence("fasting.start", role: "control", copy: "Start a fast", typography: .init(role: "subheadline", points: 15, weight: "semibold", alignment: "leading"))
            }
        }
        .padding(16)
    }

    private var endButton: some View {
        Button("End fast", action: onEnd)
            .buttonStyle(PrimaryActionStyle(fill: palette.color(for: .foreground)))
    }

    private var detailsButton: some View {
        Button("View details", action: onOpen)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}
