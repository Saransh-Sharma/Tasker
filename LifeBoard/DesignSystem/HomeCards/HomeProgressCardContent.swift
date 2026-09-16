import SwiftUI

struct HomeProgressCardContent: View {
    let title: String
    let completionRate: Double
    let openTaskCount: Int
    let rhythm: String?
    let palette: DaypartPalette
    var onOpen: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeWidgetTitle(title, symbol: "chart.line.uptrend.xyaxis", palette: palette)
                .accessibilityIdentifier("home.widget.progressReflection")
                .homeCardEvidence("progress.title", role: "title", copy: title, typography: .init(role: "headline", points: 17, weight: "semibold", alignment: "leading"))
            ProgressView(value: completionRate)
                .progressViewStyle(HomeCardLinearProgressStyle(track: palette.color(for: .canvasSecondary), tint: palette.color(for: .celestialCore)))
                .accessibilityLabel("Today’s progress")
                .accessibilityValue(completionRate.formatted(.percent))
                .homeCardEvidence("progress.bar", role: "progress", fraction: completionRate)
            // Half-width cards hyphenated "continuity" mid-word. These two
            // metrics wrap as a unit rather than breaking their own labels.
            ViewThatFits(in: .horizontal) {
                HStack {
                    metricLabels
                }
                VStack(alignment: .leading, spacing: 8) {
                    metricLabels
                }
            }
            .font(.caption.weight(.medium))
            Divider().overlay(Color(SemanticColorTokens.foundationHairline))
            Button {
                // The label promises evidence, so open the evidence route with
                // its disclosure already expanded rather than the Insights
                // overview the user then has to dig through.
                onOpen()
            } label: {
                HStack {
                    Label("See evidence behind today", systemImage: "chart.xyaxis.line")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.progress.openInsights")
            .homeCardEvidence("progress.open", role: "control", copy: "See evidence behind today", typography: .init(role: "body", points: 17, weight: "regular", alignment: "leading"))
        }
        .padding(16)
    }

    @ViewBuilder
    private var metricLabels: some View {
        Label("\(openTaskCount) open", systemImage: "checklist")
            .lineLimit(1)
            .homeCardEvidence("progress.openCount", role: "text", copy: "\(openTaskCount) open", typography: .init(role: "caption", points: 12, weight: "medium", alignment: "leading"))
        Spacer(minLength: 0)
        // Was `snapshot.streakDays` — `GamificationService`'s "consecutive days
        // with any XP event", which is not a fact about the loop at all. These
        // two come from applied close receipts, so the number cannot disagree
        // with what actually happened, and Undo moves it.
        if let rhythm = rhythm {
            // Two lines rather than one: the Progress card renders in a 2-up
            // grid, and truncating to "1 of 14 days · 1 day…" would hide one of
            // the two honest facts. DESIGN.md forbids
            // shrinking type to preserve a grid, so it wraps instead.
            Label(rhythm, systemImage: "circle.hexagongrid")
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .homeCardEvidence("progress.rhythm", role: "text", copy: rhythm, typography: .init(role: "caption", points: 12, weight: "medium", alignment: "leading"))
        }
    }
}

/// Native SwiftUI track avoids platform-view flattening in inert card previews
/// and explicit ImageRenderer exports. ProgressView retains its accessibility.
struct HomeCardLinearProgressStyle: ProgressViewStyle {
    let track: Color
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            Capsule().fill(track)
                .overlay(alignment: .leading) {
                    Capsule().fill(tint)
                        .frame(width: geometry.size.width * min(1, max(0, configuration.fractionCompleted ?? 0)))
                }
        }
        .frame(height: 4)
    }
}
