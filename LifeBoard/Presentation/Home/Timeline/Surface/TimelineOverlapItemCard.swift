import SwiftUI

struct TimelineOverlapItemCard: View {
    let placement: TimelineTimeBlock.LanePlacement
    let row: TimelineRenderableRow
    let title: String
    let densityMode: TimelineTimeBlock.DensityMode
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    var item: TimelinePlanItem { placement.item }
    var palette: TimelinePalette { .resolve(from: item.tintHex) }
    var iconSize: CGFloat {
        switch densityMode {
        case .dualLane:
            return 22
        case .compactLane:
            return 18
        case .microLane, .densePacked:
            return 16
        case .normal:
            return 22
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .trailing) {
                watermarkIcon(size: watermarkSize, trailingOffset: watermarkTrailingOffset)

                HStack(alignment: .center, spacing: densityMode == .dualLane ? 7 : 5) {
                    Image(systemName: item.systemImageName)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(palette.icon)
                        .frame(width: iconSize + 8, height: iconSize + 8)
                        .background(palette.fill.opacity(0.9), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: densityMode == .dualLane ? 3 : 2) {
                        Text(title)
                            .font(titleFont)
                            .foregroundStyle(timelineTitleColor(for: row, item: item))
                            .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(timeText)
                            .font(.lifeboard(.meta).weight(.medium))
                            .foregroundStyle(timelineMetaColor(for: row))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, densityMode == .dualLane ? 8 : 6)
            .padding(.vertical, densityMode == .dualLane ? 7 : 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.progress.opacity(0.72))
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.6), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open", action: onTap)
            if item.source == .task {
                Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
        .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : item.source == .calendarEvent ? "Calendar event" : "Scheduled"))
        .accessibilityHint("Opens the item details.")
        .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
        .accessibilityAction(named: Text("Open")) {
            onTap()
        }
        .accessibilityAction(named: Text(item.isComplete ? "Mark Incomplete" : "Mark Complete")) {
            guard item.source == .task else { return }
            onToggleComplete()
        }
    }

    var titleFont: Font {
        switch densityMode {
        case .dualLane:
            return .lifeboard(.caption1).weight(.semibold)
        case .compactLane:
            return .lifeboard(.caption1).weight(.semibold)
        case .microLane, .densePacked:
            return .lifeboard(.meta).weight(.semibold)
        case .normal:
            return .lifeboard(.caption1).weight(.semibold)
        }
    }

    var timeText: String {
        guard let start = item.startDate else { return "All day" }
        if densityMode == .dualLane, let end = item.endDate {
            return TimelineFormatting.timeRangeText(start: start, end: end)
        }
        return start.formatted(date: .omitted, time: .shortened)
    }

    var cardBackground: Color {
        if item.source == .task {
            return palette.base.opacity(0.12)
        }
        return Color.lifeboard.surfacePrimary.opacity(0.96)
    }

    var watermarkSize: CGFloat {
        switch densityMode {
        case .dualLane, .normal:
            return 56
        case .compactLane:
            return 46
        case .microLane, .densePacked:
            return 38
        }
    }

    var watermarkTrailingOffset: CGFloat {
        densityMode == .dualLane || densityMode == .normal ? 14 : 10
    }

    @ViewBuilder
    func watermarkIcon(size: CGFloat, trailingOffset: CGFloat) -> some View {
        if item.source == .task, let lifeAreaSystemImageName = item.lifeAreaSystemImageName {
            Image(systemName: lifeAreaSystemImageName)
                .font(.system(size: size, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.base.opacity(0.14))
                .offset(x: trailingOffset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
