import SwiftUI

struct TimelineUtilityRow: View {
    let items: [TimelineUtilityItem]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { entry in
                utilityItemView(entry.element)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    func utilityItemView(_ item: TimelineUtilityItem) -> some View {
        switch item {
        case .checklist(let summary):
            Label("\(summary.completedCount)/\(summary.totalCount)", systemImage: "checklist")
                .font(.lifeboard(.caption1))
                .foregroundStyle(TimelineVisualTokens.utilityText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.lifeboard.surfaceSecondary, in: Capsule())
        case .note:
            utilityGlyph("note.text")
        case .recurring:
            utilityGlyph("repeat")
        case .calendar:
            utilityGlyph("calendar")
        case .meeting:
            utilityGlyph("video")
        case .project(let name):
            Label(name, systemImage: "line.3.horizontal.decrease.circle")
                .font(.lifeboard(.caption1))
                .foregroundStyle(TimelineVisualTokens.utilityText)
                .lineLimit(1)
        }
    }

    func utilityGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(TimelineVisualTokens.utilityText)
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)
    }
}
