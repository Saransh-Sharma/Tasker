import SwiftUI

struct TimelineTimeBlockCard: View {
    let block: TimelineTimeBlock
    let presentation: TimelineDayPresentation
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text("Time Block Conflict: \(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate))")
                    .font(.lifeboard(.support).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                Text(block.countLabel)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentOnPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.lifeboard.accentPrimary.opacity(0.82), in: Capsule())
            }

            VStack(spacing: 10) {
                ForEach(block.items) { item in
                    if item.source == .calendarEvent {
                        TimelineMeetingBlockRow(
                            item: item,
                            row: presentation.row(for: item),
                            isNested: true,
                            action: { onTaskTap(item) }
                        )
                    } else {
                        TimelineTaskBlockRow(
                            item: item,
                            row: presentation.row(for: item),
                            onTaskTap: onTaskTap,
                            onToggleComplete: onToggleComplete
                        )
                    }
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.lifeboard.surfaceSecondary.opacity(0.92))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.lifeboard.accentPrimary.opacity(0.82))
                .frame(width: 4)
                .padding(.vertical, 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.76), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Time block conflict, \(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate)), \(block.countLabel)")
        .accessibilityIdentifier("home.timeline.conflictBlock")
    }
}
