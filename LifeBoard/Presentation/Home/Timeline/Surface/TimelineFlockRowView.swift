import SwiftUI

struct TimelineFlockRowView: View {
    let row: TimelineFlockModel.Row
    let visualHeight: CGFloat
    let renderRow: TimelineRenderableRow?
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    var item: TimelinePlanItem? { row.item }
    var palette: TimelinePalette { .resolve(from: item?.tintHex) }

    var body: some View {
        Button(action: onTap) {
            rowContent
                .frame(maxWidth: .infinity, minHeight: visualHeight, maxHeight: visualHeight, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let item {
                Button("Open", action: onTap)
                if item.source == .task {
                    Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(row.isSummary ? "Opens the full list." : "Opens the item details.")
    }

    var rowContent: some View {
        HStack(alignment: .center, spacing: 8) {
            if row.isSummary {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: item?.systemImageName ?? "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.icon)
                    .frame(width: 24, height: 24)
                    .background(palette.fill.opacity(0.9), in: Circle())
                    .accessibilityHidden(true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.title)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(titleColor)
                        .strikethrough(row.isCompleted, color: titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(2)

                    trailingStatus
                        .layoutPriority(1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(titleColor)
                        .strikethrough(row.isCompleted, color: titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    trailingStatus
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    var trailingStatus: some View {
        if row.isActiveNow {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.lifeboard.statusDanger)
                    .frame(width: 5, height: 5)
                Text("Now")
                    .font(.lifeboard(.meta).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.statusDanger)
            }
            .lineLimit(1)
        } else if row.timeText.isEmpty == false {
            Text(row.timeText)
                .font(.lifeboard(.meta).weight(.medium))
                .foregroundStyle(metaColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }

    var rowBackground: Color {
        if row.isActiveNow {
            return Color.lifeboard.statusDanger.opacity(0.10)
        }
        return Color.lifeboard.surfacePrimary.opacity(row.isSummary ? 0.42 : 0.72)
    }

    var titleColor: Color {
        guard let renderRow else {
            return row.isSummary ? Color.lifeboard.textSecondary : Color.lifeboard.textPrimary
        }
        return timelineTitleColor(for: renderRow, item: item)
    }

    var metaColor: Color {
        guard let renderRow else { return TimelineVisualTokens.metaText }
        return timelineMetaColor(for: renderRow)
    }

    var accessibilityLabel: String {
        if row.isSummary { return row.title }
        guard let item, let renderRow else { return row.title }
        return timelineAccessibilityLabel(for: renderRow, item: item)
    }

    var accessibilityValue: String {
        if row.isSummary { return "" }
        if row.isCompleted { return "Completed" }
        if row.isActiveNow { return "Now" }
        return item?.source == .calendarEvent ? "Calendar event" : "Scheduled"
    }
}
