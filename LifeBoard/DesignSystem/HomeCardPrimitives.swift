import SwiftUI

// Shared by the Home card bodies in DesignSystem/HomeCards and by the live
// Home sections; kept at the DesignSystem top level so the HomeCards folder
// does not grow another sub-150-line file.

struct HomeWidgetTitle: View {
    let title: String
    let symbol: String
    let palette: DaypartPalette

    init(_ title: String, symbol: String, palette: DaypartPalette) {
        self.title = title
        self.symbol = symbol
        self.palette = palette
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(title).lifeboardFont(.headline)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

struct HomeEmptyStateRow: View {
    let text: String
    let symbol: String
    let palette: DaypartPalette

    init(_ text: String, symbol: String, palette: DaypartPalette) {
        self.text = text
        self.symbol = symbol
        self.palette = palette
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(text).font(.subheadline).foregroundStyle(palette.color(for: .foregroundSecondary))
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct HomeSnapshotMetric: View {
    let id: String
    let symbol: String
    let value: String
    let label: String
    let palette: DaypartPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).lifeboardFont(.title2)
                Text(value).font(.caption.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    .homeCardEvidence("snapshot.\(id).value", role: "value", copy: value, typography: .init(role: "caption", points: 12, weight: "semibold", alignment: "center"))
                Text(label).font(.caption2).foregroundStyle(palette.color(for: .foregroundSecondary))
                    .homeCardEvidence("snapshot.\(id).label", role: "text", copy: label, typography: .init(role: "caption2", points: 11, weight: "regular", alignment: "center"))
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .lifeBoardEmbeddedClayWell(palette: palette)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.snapshot.\(id)")
        .homeCardEvidence("snapshot.\(id).open", role: "control", copy: value + " " + label)
    }
}
