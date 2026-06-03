import SwiftUI

struct TimelineOverlapClusterCard: View {
    let block: TimelineTimeBlock
    let presentation: TimelineDayPresentation
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 12
            let laneGap = TimelineTimeBlock.laneGap
            let laneCount = max(block.visualLaneCount, 1)
            let laneWidth = max(
                (proxy.size.width - (horizontalPadding * 2) - (CGFloat(laneCount - 1) * laneGap)) / CGFloat(laneCount),
                56
            )
            let titles = TimelineDenseTitleFormatter.displayTitles(for: block.items)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.lifeboard.surfaceSecondary.opacity(0.94))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(clusterAccent.opacity(0.82))
                    .frame(width: 4)
                    .padding(.vertical, 3)

                header
                    .padding(.leading, horizontalPadding + 4)
                    .padding(.trailing, horizontalPadding)
                    .padding(.top, 10)

                ForEach(block.lanePlacements) { placement in
                    TimelineOverlapItemCard(
                        placement: placement,
                        row: presentation.row(for: placement.item),
                        title: titles[placement.item.id] ?? placement.item.title,
                        densityMode: block.densityMode,
                        onTap: { onTaskTap(placement.item) },
                        onToggleComplete: {
                            guard placement.item.source == .task else { return }
                            onToggleComplete(placement.item)
                        }
                    )
                    .frame(width: laneWidth, height: placement.height)
                    .offset(
                        x: horizontalPadding + CGFloat(placement.laneIndex) * (laneWidth + laneGap),
                        y: TimelineTimeBlock.clusterHeaderHeight + placement.relativeY
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(block.compressed ? "Compressed overlap" : "Overlap"), \(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate)), \(block.countLabel)")
        .accessibilityIdentifier("home.timeline.overlapCluster")
    }

    var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate))
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if block.compressed {
                    Label("Compressed", systemImage: "rectangle.compress.vertical")
                        .font(.lifeboard(.meta).weight(.medium))
                        .foregroundStyle(Color.lifeboard.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Text(block.countLabel.lowercased())
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(clusterAccent.opacity(0.18), in: Capsule())
        }
    }

    var clusterAccent: Color {
        if block.containsTask && block.containsCalendarEvent {
            return Color.lifeboard.accentPrimary
        }
        if let tintHex = block.items.first?.tintHex {
            return Color(uiColor: UIColor(lifeboardHex: tintHex))
        }
        return Color.lifeboard.accentPrimary
    }
}
