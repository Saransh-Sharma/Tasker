import SwiftUI
import UIKit

/// Resolves a flick on the repair deck into one of four repair actions.
///
/// The deck used to read only left and right, so a proposal offering four ways
/// out could surface just two of them to the hand; the rest were reachable only
/// by hunting the button row. Vertical intent now carries the third and fourth.
///
/// A flick has to commit to an axis. Diagonals resolve to nothing rather than
/// guessing, because picking wrong here mutates the plan.
/// The physics now live in `DeckPhysics` so the Inbox triage deck feels
/// identical to this one. This remains the Plan-facing name — it is what the
/// repair-deck tests and call sites spell — but it owns no behaviour of its own.
enum PlanRepairDeckDragResolver {
    static let threshold = DeckPhysics.threshold
    static let minimumIntent = DeckPhysics.minimumIntent
    static let dominance = DeckPhysics.dominance

    /// Declaration order is the slot order actions are assigned to.
    typealias Direction = DeckDirection

    static func direction(
        translation: CGSize,
        predictedEndTranslation: CGSize
    ) -> Direction? {
        DeckPhysics.direction(
            translation: translation,
            predictedEndTranslation: predictedEndTranslation
        )
    }

    /// The action a direction carries, or nil when the proposal offers fewer
    /// ways out than the deck has directions.
    static func action(
        for direction: Direction,
        candidates: [PlanRepairAction]
    ) -> PlanRepairAction? {
        DeckPhysics.action(for: direction, candidates: candidates)
    }

    static func action(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        candidates: [PlanRepairAction]
    ) -> PlanRepairAction? {
        DeckPhysics.action(
            translation: translation,
            predictedEndTranslation: predictedEndTranslation,
            candidates: candidates
        )
    }

    /// Where a committed card leaves the screen.
    static func exitOffset(for direction: Direction, distance: CGFloat = DeckPhysics.exitDistance) -> CGSize {
        direction.exitOffset(distance: distance)
    }
}

/// Assigns overlapping timeline items to side-by-side lanes.
///
/// The day canvas used to position every commitment and block at the same x with
/// only a y offset, so anything concurrent was drawn literally on top of
/// everything else: with three or four overlapping meetings the spine became an
/// unreadable stack where only the last-drawn title was legible.
///
/// Items are grouped into clusters — maximal runs connected by overlap — and
/// greedily packed into the first free lane inside each cluster. Lane counts are
/// per cluster rather than per day, so one busy hour cannot narrow the whole
/// schedule.
enum PlanTimelineLaneResolver {
    /// How many lanes are on screen at once.
    ///
    /// Two is what a phone can show while a card still reads as a title and a
    /// time rather than an ellipsis. Dividing the width by the true lane count
    /// was tried and rejected: at three lanes every title collapsed to "…".
    /// Anything past the second lane scrolls instead.
    static let visibleLaneLimit = 2

    struct Item: Equatable {
        let id: String
        let start: Date
        let end: Date
    }

    struct Placement: Equatable {
        /// Zero-based column within the cluster.
        let lane: Int
        /// How many lanes the cluster needs. Drives width and scrolling.
        let laneCount: Int
        /// Stable identifier for the overlapping group this item belongs to.
        let clusterID: Int
    }

    /// Packs `items` into lanes, keyed by item id.
    ///
    /// Zero-length and reversed intervals are tolerated: a malformed event
    /// should take a lane, not break the day.
    static func placements(for items: [Item]) -> [String: Placement] {
        let sorted = items.sorted {
            $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start
        }
        var result: [String: Placement] = [:]
        var clusterID = 0
        var clusterMembers: [String] = []
        var laneEnds: [Date] = []
        var clusterEnd: Date?

        func closeCluster() {
            guard clusterMembers.isEmpty == false else { return }
            let count = max(1, laneEnds.count)
            for member in clusterMembers {
                guard let existing = result[member] else { continue }
                result[member] = Placement(
                    lane: existing.lane,
                    laneCount: count,
                    clusterID: existing.clusterID
                )
            }
            clusterMembers = []
            laneEnds = []
            clusterEnd = nil
            clusterID += 1
        }

        for item in sorted {
            let end = max(item.end, item.start)
            // A gap with everything placed so far ends the cluster, so the next
            // item starts a fresh set of lanes back at full width.
            if let currentEnd = clusterEnd, item.start >= currentEnd {
                closeCluster()
            }
            let lane = laneEnds.firstIndex { $0 <= item.start } ?? laneEnds.count
            if lane < laneEnds.count {
                laneEnds[lane] = end
            } else {
                laneEnds.append(end)
            }
            result[item.id] = Placement(lane: lane, laneCount: laneEnds.count, clusterID: clusterID)
            clusterMembers.append(item.id)
            clusterEnd = clusterEnd.map { max($0, end) } ?? end
        }
        closeCluster()
        return result
    }

    /// Total width a cluster's lanes occupy, including the gaps between them.
    static func stripWidth(laneCount: Int, laneWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let lanes = max(1, laneCount)
        return laneWidth * CGFloat(lanes) + spacing * CGFloat(lanes - 1)
    }

    /// Keeps a pan inside the strip: never past the first lane, never beyond the
    /// last one's trailing edge, so the band cannot be dragged into empty space.
    static func clampedStripOffset(
        _ offset: CGFloat,
        contentWidth: CGFloat,
        stripWidth: CGFloat
    ) -> CGFloat {
        min(0, max(min(0, contentWidth - stripWidth), offset))
    }

    /// Width of one lane, and whether the cluster extends past the visible edge.
    ///
    /// A lane is always sized so that `visibleLaneLimit` of them fill the
    /// canvas, however many there really are. One overlap splits the width in
    /// two and sits still; a third and beyond keep that same readable width and
    /// scroll horizontally, so a busy hour costs a swipe rather than legibility.
    static func laneMetrics(
        laneCount: Int,
        availableWidth: CGFloat,
        spacing: CGFloat
    ) -> (laneWidth: CGFloat, scrolls: Bool) {
        let lanes = max(1, laneCount)
        let width = max(0, availableWidth)
        guard lanes > 1 else { return (width, false) }
        let visible = min(lanes, visibleLaneLimit)
        let laneWidth = (width - spacing * CGFloat(visible - 1)) / CGFloat(visible)
        return (max(1, laneWidth), lanes > visibleLaneLimit)
    }
}

/// Quantizes a time-block drag onto the schedule grid.
///
/// The canvas previously tracked the finger continuously and only snapped on
/// release, so the grid was invisible during the gesture: there was no detent to
/// feel, and no way to see which slot the block would land in.
enum PlanBlockSnapResolver {
    /// Correction grid, used while the block is close to where it started.
    static let fineStepMinutes = 5
    /// Travel grid, used once the drag is a real move.
    static let coarseStepMinutes = 15
    /// Below this much travel the drag is treated as a correction.
    static let fineThresholdMinutes = 30.0
    /// Proximity within which a real neighboring edge unlocks the five-minute
    /// correction grid.
    static let boundaryProximityMinutes = 7.5

    /// Minutes the block should move for a given finger travel, snapped to the
    /// grid and clamped to the drawn day.
    ///
    /// A single coarse grid makes nudging a block by five minutes impossible; a
    /// single fine grid makes crossing the day feel notchy. Splitting on travel
    /// distance keeps both gestures available without a mode switch.
    static func snappedMinutes(
        translation: CGFloat,
        hourHeight: CGFloat,
        bounds: ClosedRange<Int>
    ) -> Int {
        guard hourHeight > 0 else { return 0 }
        let raw = Double(translation / hourHeight * 60)
        let step = Double(abs(raw) < fineThresholdMinutes ? fineStepMinutes : coarseStepMinutes)
        let snapped = Int((raw / step).rounded() * step)
        return min(max(snapped, bounds.lowerBound), bounds.upperBound)
    }

    /// Resize snapping is driven by nearby schedule edges, not by how far the
    /// finger happened to travel. Away from an event/block boundary the edge
    /// remains on the calm 15-minute grid; close to a real edge it gains a
    /// five-minute correction grid.
    static func boundaryAwareSnappedMinutes(
        translation: CGFloat,
        hourHeight: CGFloat,
        movingEdgeAt: Date,
        boundaries: [Date],
        bounds: ClosedRange<Int>,
        proximityMinutes: Double = boundaryProximityMinutes
    ) -> Int {
        guard hourHeight > 0 else { return 0 }
        let raw = Double(translation / hourHeight * 60)
        let nearestBoundaryDelta = boundaries
            .map { $0.timeIntervalSince(movingEdgeAt) / 60 }
            .min { abs($0 - raw) < abs($1 - raw) }
        let isNearBoundary = nearestBoundaryDelta.map {
            abs($0 - raw) <= proximityMinutes
        } ?? false
        let step = Double(isNearBoundary ? fineStepMinutes : coarseStepMinutes)
        let source = isNearBoundary ? (nearestBoundaryDelta ?? raw) : raw
        let snapped = Int((source / step).rounded() * step)
        return min(max(snapped, bounds.lowerBound), bounds.upperBound)
    }
}
