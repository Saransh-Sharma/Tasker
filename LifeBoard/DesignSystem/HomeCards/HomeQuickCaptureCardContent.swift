import SwiftUI

struct HomeQuickCaptureCardContent: View {
    let includesWater: Bool
    let palette: DaypartPalette
    var onCapture: (CaptureKind) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeWidgetTitle("Capture", symbol: "plus", palette: palette)
                .accessibilityIdentifier("home.widget.quickCapture")
                .homeCardEvidence("capture.title", role: "title", copy: "Capture", typography: .init(role: "headline", points: 17, weight: "semibold", alignment: "leading"))
            LazyVGrid(columns: columns, spacing: 8) {
                tile("Task", symbol: "checkmark.circle", kind: .task)
                tile("Habit", symbol: "repeat", kind: .habit)
                tile("Journal", symbol: "book.closed", kind: .journal)
                if includesWater { tile("Water", symbol: "drop.fill", kind: .hydration) }
            }
        }
        .padding(16)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 180 : 64), spacing: 8)]
    }

    private func tile(_ title: String, symbol: String, kind: CaptureKind) -> some View {
        Button { onCapture(kind) } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).lifeboardFont(.title2)
                Text(LocalizedStringKey(title)).font(.caption.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .homeCardEvidence("capture.\(kind.rawValue).label", role: "text", copy: title, typography: .init(role: "caption", points: 12, weight: "medium", alignment: "center"))
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .lifeBoardEmbeddedClayWell(palette: palette)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.capture.\(kind.rawValue)")
        .homeCardEvidence("capture.\(kind.rawValue)", role: "control", copy: title)
    }
}
