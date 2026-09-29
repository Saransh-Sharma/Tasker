import SwiftUI

extension PlanDayTimeCanvas {
    /// Every scheduled thing on the spine, as intervals the lane resolver can
    /// pack. Commitments and blocks share one lane space because they overlap
    /// each other, not just their own kind.
    private var lanePlacements: [String: PlanTimelineLaneResolver.Placement] {
        let items = displayCommitments.map {
            PlanTimelineLaneResolver.Item(id: "commitment:\($0.id)", start: $0.startAt, end: $0.endAt)
        } + snapshot.blocks.map {
            PlanTimelineLaneResolver.Item(id: "block:\($0.id.uuidString)", start: $0.startAt, end: $0.endAt)
        }
        return PlanTimelineLaneResolver.placements(for: items)
    }

    /// One horizontally scrollable strip per overlapping cluster.
    ///
    /// Concurrent items used to be drawn at the same x, so a busy hour rendered
    /// as an unreadable pile. Each cluster now gets its own lane space: two
    /// abreast share the width, and anything denser keeps a readable lane width
    /// and scrolls sideways inside its own time band, so the vertical position
    /// still tells the truth about when things happen.
    func clusterLayer(width: CGFloat) -> some View {
        let placements = lanePlacements
        let contentWidth = max(1, width - rulerWidth - 18)
        let clusters = timelineClusters(placements: placements)
        return ForEach(clusters) { cluster in
            let metrics = PlanTimelineLaneResolver.laneMetrics(
                laneCount: cluster.laneCount,
                availableWidth: contentWidth,
                spacing: laneSpacing
            )
            // Sizing happens inside `clusterBody`. A second frame out here used
            // to wrap the scrolling case, and the pair of them left the
            // ScrollView free to size itself to its content: nothing scrolled,
            // and the lanes past the edge were merely clipped by the card.
            clusterBody(cluster, metrics: metrics, contentWidth: contentWidth)
                .offset(x: rulerWidth + 6, y: cluster.top)
        }
    }

    @ViewBuilder
    private func clusterBody(
        _ cluster: TimelineCluster,
        metrics: (laneWidth: CGFloat, scrolls: Bool),
        contentWidth: CGFloat
    ) -> some View {
        if metrics.scrolls {
            PlanClusterStrip(
                contentWidth: contentWidth,
                laneCount: cluster.laneCount,
                laneWidth: metrics.laneWidth,
                spacing: laneSpacing,
                height: cluster.height
            ) {
                clusterLanes(cluster, laneWidth: metrics.laneWidth)
            }
            .accessibilityLabel("\(cluster.laneCount) overlapping blocks")
        } else {
            clusterLanes(cluster, laneWidth: metrics.laneWidth)
                .frame(width: contentWidth, height: cluster.height, alignment: .topLeading)
        }
    }

    private func clusterLanes(_ cluster: TimelineCluster, laneWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(cluster.commitments) { entry in
                PlanCanvasCommitmentCard(
                    commitment: entry.commitment,
                    width: laneWidth,
                    height: blockHeight(from: entry.commitment.startAt, to: entry.commitment.endAt),
                    conflict: conflicts(
                        start: entry.commitment.startAt,
                        end: entry.commitment.endAt,
                        excludingCommitmentID: entry.commitment.id,
                        excludingBlockID: UUID(uuidString: entry.commitment.id)
                    )
                )
                    .offset(
                        x: CGFloat(entry.lane) * (laneWidth + laneSpacing),
                        y: yPosition(entry.commitment.startAt) - cluster.top
                    )
            }
            ForEach(cluster.blocks) { entry in
                blockCard(entry.block, width: laneWidth)
                    .offset(
                        x: CGFloat(entry.lane) * (laneWidth + laneSpacing),
                        y: yPosition(entry.block.startAt) - cluster.top
                    )
            }
        }
        .frame(
            width: CGFloat(cluster.laneCount) * laneWidth + CGFloat(max(0, cluster.laneCount - 1)) * laneSpacing,
            alignment: .topLeading
        )
    }

    private func blockCard(_ block: InternalTimeBlock, width: CGFloat) -> some View {
        PlanCanvasBlock(
                block: block,
                width: max(1, width),
                height: blockHeight(from: block.startAt, to: block.endAt),
                hourHeight: hourHeight,
                hasConflict: conflicts(
                    start: block.startAt,
                    end: block.endAt,
                    excludingCommitmentID: block.id.uuidString,
                    excludingBlockID: block.id
                ),
                // Evaluated against the snapped candidate slot while dragging,
                // so a conflict is shown on the spine before the drop rather
                // than reported afterwards.
                conflictAt: { minutesDelta in
                    conflicts(
                        start: block.startAt.addingTimeInterval(TimeInterval(minutesDelta * 60)),
                        end: block.endAt.addingTimeInterval(TimeInterval(minutesDelta * 60)),
                        excludingCommitmentID: block.id.uuidString,
                        excludingBlockID: block.id
                    )
                },
                minuteBounds: minuteBounds(for: block),
                boundaryDates: boundaryDates(excluding: block.id),
                move: { moveBlock(block, $0) },
                resize: { resizeBlock(block, $0) },
                resizeEdges: { resizeBlockEdges(block, $0, $1) },
                split: { splitBlock(block) },
                delete: { deleteBlock(block) },
                focus: { startFocus(block) }
        )
    }

    private func boundaryDates(excluding blockID: UUID) -> [Date] {
        displayCommitments.flatMap { [$0.startAt, $0.endAt] }
            + snapshot.blocks
                .filter { $0.id != blockID }
                .flatMap { [$0.startAt, $0.endAt] }
    }

    private var laneSpacing: CGFloat { 6 }

    /// A group of items that overlap each other, positioned as one band.
    struct TimelineCluster: Identifiable {
        struct CommitmentEntry: Identifiable {
            let commitment: PlanningFixedCommitment
            let lane: Int
            var id: String { commitment.id }
        }

        struct BlockEntry: Identifiable {
            let block: InternalTimeBlock
            let lane: Int
            var id: UUID { block.id }
        }

        let id: Int
        let laneCount: Int
        let top: CGFloat
        let height: CGFloat
        let commitments: [CommitmentEntry]
        let blocks: [BlockEntry]
    }

    private func timelineClusters(
        placements: [String: PlanTimelineLaneResolver.Placement]
    ) -> [TimelineCluster] {
        var commitmentsByCluster: [Int: [TimelineCluster.CommitmentEntry]] = [:]
        var blocksByCluster: [Int: [TimelineCluster.BlockEntry]] = [:]
        var laneCounts: [Int: Int] = [:]
        var spans: [Int: (top: CGFloat, bottom: CGFloat)] = [:]

        func extend(_ clusterID: Int, start: Date, end: Date) {
            let top = yPosition(start)
            let bottom = top + blockHeight(from: start, to: end)
            let current = spans[clusterID]
            spans[clusterID] = (
                min(current?.top ?? top, top),
                max(current?.bottom ?? bottom, bottom)
            )
        }

        for commitment in displayCommitments {
            guard let placement = placements["commitment:\(commitment.id)"] else { continue }
            commitmentsByCluster[placement.clusterID, default: []].append(
                .init(commitment: commitment, lane: placement.lane)
            )
            laneCounts[placement.clusterID] = placement.laneCount
            extend(placement.clusterID, start: commitment.startAt, end: commitment.endAt)
        }
        for block in snapshot.blocks {
            guard let placement = placements["block:\(block.id.uuidString)"] else { continue }
            blocksByCluster[placement.clusterID, default: []].append(
                .init(block: block, lane: placement.lane)
            )
            laneCounts[placement.clusterID] = placement.laneCount
            extend(placement.clusterID, start: block.startAt, end: block.endAt)
        }

        return laneCounts.keys.sorted().compactMap { clusterID in
            guard let span = spans[clusterID] else { return nil }
            return TimelineCluster(
                id: clusterID,
                laneCount: laneCounts[clusterID] ?? 1,
                top: span.top,
                height: max(1, span.bottom - span.top),
                commitments: commitmentsByCluster[clusterID] ?? [],
                blocks: blocksByCluster[clusterID] ?? []
            )
        }
    }

    /// A hairline at the current minute, the one live element on the canvas.
    func nowLineLayer(width: CGFloat) -> some View {
        TimelineView(.everyMinute) { context in
            let y = yPosition(context.date)
            if y > 0, y < timelineHeight {
                HStack(spacing: 0) {
                    // Hour and minute only: "7:19 PM" wraps inside the ruler, and
                        // the ruler beside it already says which half of the day.
                        // A filled pill, not bare text: within ten minutes of
                        // the hour the ruler's own label sat behind "9:05" and
                        // read as a doubled "9". The pill occludes it.
                        Text(PlanCanvasGeometry.nowLabel(context.date))
                        .lifeboardFont(.caption2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(Color.lifeboard(.textInverse))
                        .padding(.horizontal, 4)
                        .background(Color(SemanticColorTokens.foundationApricotInk), in: Capsule())
                        .frame(width: rulerWidth - 4, alignment: .trailing)
                        .padding(.trailing, 4)
                    Circle()
                        .fill(Color(SemanticColorTokens.foundationApricotInk))
                        .frame(width: 8, height: 8)
                        // The one live element on the canvas breathes, inside the
                        // ambient budget, so "now" reads as happening.
                        .lifeBoardAmbientBreath(role: .liveIndicator)
                    Rectangle()
                        .fill(Color(SemanticColorTokens.foundationApricotInk))
                        .frame(width: max(0, width - rulerWidth - 7), height: 1.5)
                }
                .offset(y: y - 6)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Now, \(context.date.formatted(date: .omitted, time: .shortened))")
                .accessibilityIdentifier("plan.canvas.nowLine")
            }
        }
    }
}
