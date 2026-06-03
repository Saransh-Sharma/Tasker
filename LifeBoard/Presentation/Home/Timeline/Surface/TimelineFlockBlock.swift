import SwiftUI

struct TimelineFlockBlock: View {
    let model: TimelineFlockModel
    let presentation: TimelineDayPresentation
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var accent: Color {
        if let item = model.rows.first(where: { $0.item != nil })?.item {
            return TimelinePalette.resolve(from: item.tintHex).progress
        }
        return Color.lifeboard.accentPrimary
    }

    var body: some View {
        let fallbackItem = model.rows.compactMap(\.item).first

        VStack(alignment: .leading, spacing: 6) {
            header

            VStack(alignment: .leading, spacing: TimelineFlockModel.rowSpacing) {
                ForEach(model.rows) { row in
                    TimelineFlockRowView(
                        row: row,
                        visualHeight: model.rowVisualHeight,
                        renderRow: row.item.map { presentation.row(for: $0) },
                        onTap: {
                            guard let item = row.item ?? fallbackItem else { return }
                            onTaskTap(item)
                        },
                        onToggleComplete: {
                            guard let item = row.item, item.source == .task else { return }
                            onToggleComplete(item)
                        }
                    )
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent.opacity(0.82))
                .frame(width: 4)
                .padding(.vertical, 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.54), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .compositingGroup()
        .zIndex(3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(TimelineFormatting.timeRangeText(start: model.startDate, end: model.endDate)), \(model.countLabel)")
        .accessibilityIdentifier("home.timeline.flockBlock")
    }

    var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(TimelineFormatting.timeRangeText(start: model.startDate, end: model.endDate))
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 6)

            Text(model.countLabel)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(accent.opacity(0.16), in: Capsule())
        }
        .frame(height: 24)
    }
}
