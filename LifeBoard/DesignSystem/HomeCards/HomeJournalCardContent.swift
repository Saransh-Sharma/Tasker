import SwiftUI

/// Identical native Journal actions in Home and inert gallery previews.
struct HomeJournalCardContent: View {
    var onCapture: () -> Void = {}
    var onSearch: () -> Void = {}
    var onReflection: () -> Void = {}
    let palette: DaypartPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HomeWidgetTitle("Journal", symbol: "book.closed", palette: palette)
                .accessibilityIdentifier("home.widget.journal")
                .homeCardEvidence("journal.title", role: "title", copy: "Journal", typography: .init(role: "headline", points: 17, weight: "semibold"))
            Text("Keep one honest moment from today—words, photos, or audio.")
                .font(.subheadline)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .homeCardEvidence("journal.body", role: "text", copy: "Keep one honest moment from today—words, photos, or audio.", typography: .init(role: "subheadline", points: 15, weight: "regular"))
            // In a half-width card these two buttons get about 63pt each, which
            // is narrower than "Search" plus its symbol. Laid out in a fixed
            // HStack the labels wrapped to one character per line and the
            // buttons grew to ~350pt tall. `ViewThatFits` keeps the side-by-side
            // arrangement wherever it genuinely fits and stacks otherwise.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    captureButton
                    searchButton
                }
                VStack(spacing: 8) {
                    captureButton
                    searchButton
                }
            }
            Button {
                onReflection()
            } label: {
                HStack {
                    Label("Weekly reflection", systemImage: "sparkles.rectangle.stack")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.journal.weeklyReflection")
            .homeCardEvidence("journal.reflection", role: "control", copy: "Weekly reflection", typography: .init(role: "subheadline", points: 15, weight: "semibold"))
        }
        .padding(16)
    }

    private var captureButton: some View {
        Button {
            onCapture()
        } label: {
            Label("Write", systemImage: "square.and.pencil")
                .lineLimit(1)
        }
        .buttonStyle(PrimaryActionStyle(fill: palette.color(for: .foreground)))
        .accessibilityIdentifier("home.journal.capture")
        .homeCardEvidence("journal.write", role: "control", copy: "Write", typography: .init(role: "button", points: 17, weight: "semibold", alignment: "center"))
    }

    private var searchButton: some View {
        Button {
            onSearch()
        } label: {
            Label("Search", systemImage: "magnifyingglass")
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("home.journal.search")
        .homeCardEvidence("journal.search", role: "control", copy: "Search", typography: .init(role: "body", points: 17, weight: "regular", alignment: "center"))
    }
}
