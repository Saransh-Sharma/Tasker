import SwiftUI

struct TimelineNormalItemCard: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let title: String
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onTap) {
                ZStack(alignment: .trailing) {
                    watermarkIcon(size: 72, trailingOffset: 18)

                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: item.systemImageName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(palette.icon)
                            .frame(width: 28, height: 28)
                            .background(palette.fill.opacity(0.92), in: Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.lifeboard(.headline).weight(.semibold))
                                .foregroundStyle(timelineTitleColor(for: row, item: item))
                                .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .layoutPriority(2)

                            Text(timeText)
                                .font(.lifeboard(.caption1).weight(.medium))
                                .foregroundStyle(timelineMetaColor(for: row))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .layoutPriority(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if item.source == .task {
                            Color.clear
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.progress.opacity(0.78))
                        .frame(width: 3)
                        .padding(.vertical, 8)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.lifeboard.strokeHairline.opacity(0.58), lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
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

            if item.source == .task {
                TimelineCompletionRing(
                    color: timelineRingColor(for: row, palette: palette),
                    isCompleted: item.isComplete,
                    isInteractive: true,
                    label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
                ) {
                    onToggleComplete()
                }
                .padding(.trailing, 12)
            }
        }
        .contextMenu {
            Button("Open", action: onTap)
            if item.source == .task {
                Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
            }
        }
    }

    var timeText: String {
        guard let start = item.startDate else { return "All day" }
        guard let end = item.endDate else {
            return start.formatted(date: .omitted, time: .shortened)
        }
        return TimelineFormatting.timeRangeText(start: start, end: end)
    }

    var cardBackground: Color {
        if item.source == .task {
            return palette.base.opacity(0.12)
        }
        return Color.lifeboard.surfacePrimary.opacity(0.95)
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
