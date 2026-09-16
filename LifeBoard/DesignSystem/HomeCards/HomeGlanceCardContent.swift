import SwiftUI

struct HomeGlanceCardContent: View {
    let title: String
    let summary: String
    let symbol: String
    let palette: DaypartPalette
    var onOpen: () -> Void = {}

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .lifeboardFont(.title2)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .frame(width: 30, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(1)
                        .homeCardEvidence("glance.title", role: "title", copy: title, typography: .init(role: "caption", points: 12, weight: "semibold"))
                    Text(summary)
                        .lifeboardFont(.support)
                        .foregroundStyle(palette.color(for: .foreground))
                        .lineLimit(2)
                        .homeCardEvidence("glance.summary", role: "value", copy: summary, typography: .init(role: "support", points: 15, weight: "regular"))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the source")
        .homeCardEvidence("glance.open", role: "control", copy: "")
    }
}
