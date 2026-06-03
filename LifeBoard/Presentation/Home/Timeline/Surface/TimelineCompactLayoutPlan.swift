import SwiftUI

struct TimelineCompactLayoutPlan: Equatable {
    struct PositionedAnchor: Equatable, Identifiable {
        let anchor: TimelineAnchorItem
        let rowHeight: CGFloat

        var id: String { anchor.id }
    }

    struct PositionedItem: Equatable, Identifiable {
        let item: TimelinePlanItem
        let rowHeight: CGFloat
        let capsuleHeight: CGFloat

        var id: String { item.id }
    }

    struct PositionedGap: Equatable, Identifiable {
        let gap: TimelineGap
        let rowHeight: CGFloat

        var id: String { gap.id }
    }

    enum Entry: Equatable, Identifiable {
        case anchor(PositionedAnchor)
        case item(PositionedItem)
        case gap(PositionedGap)

        var id: String {
            switch self {
            case .anchor(let anchor):
                return "anchor:\(anchor.id)"
            case .item(let item):
                return "item:\(item.id)"
            case .gap(let gap):
                return "gap:\(gap.id)"
            }
        }

        var rowHeight: CGFloat {
            switch self {
            case .anchor(let anchor):
                return anchor.rowHeight
            case .item(let item):
                return item.rowHeight
            case .gap(let gap):
                return gap.rowHeight
            }
        }
    }

    let entries: [Entry]
    let connectorHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat

    init(
        projection: TimelineDayProjection,
        layoutClass: LifeBoardLayoutClass = .phone,
        anchorHeight: CGFloat? = nil,
        itemHeight: CGFloat? = nil,
        gapHeight: CGFloat? = nil,
        connectorHeight: CGFloat? = nil,
        topInset: CGFloat = 4,
        bottomInset: CGFloat = 12
    ) {
        let metrics = TimelineSurfaceMetrics.make(for: layoutClass)
        let resolvedAnchorHeight = anchorHeight ?? metrics.compactAnchorRowHeight
        let resolvedItemHeight = itemHeight ?? metrics.compactItemMinRowHeight
        let resolvedGapHeight = gapHeight ?? metrics.compactGapRowHeight
        let resolvedConnectorHeight = connectorHeight ?? metrics.compactConnectorHeight
        self.connectorHeight = resolvedConnectorHeight
        self.topInset = topInset
        self.bottomInset = bottomInset

        let beforeWakeItems = projection.beforeWakeItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let sortedItems = projection.timedItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let afterSleepItems = projection.afterSleepItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let sortedGaps = projection.actionableGaps.sorted { $0.startDate < $1.startDate }

        var itemIndex = 0
        var gapIndex = 0
        var resolvedEntries = beforeWakeItems.map {
            Self.itemEntry(for: $0, minimumRowHeight: resolvedItemHeight)
        }
        resolvedEntries.append(.anchor(.init(anchor: projection.wakeAnchor, rowHeight: resolvedAnchorHeight)))

        while itemIndex < sortedItems.count || gapIndex < sortedGaps.count {
            if itemIndex >= sortedItems.count {
                resolvedEntries.append(.gap(.init(gap: sortedGaps[gapIndex], rowHeight: resolvedGapHeight)))
                gapIndex += 1
                continue
            }
            if gapIndex >= sortedGaps.count {
                resolvedEntries.append(Self.itemEntry(for: sortedItems[itemIndex], minimumRowHeight: resolvedItemHeight))
                itemIndex += 1
                continue
            }

            if sortedGaps[gapIndex].startDate <= (sortedItems[itemIndex].startDate ?? .distantFuture) {
                resolvedEntries.append(.gap(.init(gap: sortedGaps[gapIndex], rowHeight: resolvedGapHeight)))
                gapIndex += 1
            } else {
                resolvedEntries.append(Self.itemEntry(for: sortedItems[itemIndex], minimumRowHeight: resolvedItemHeight))
                itemIndex += 1
            }
        }

        resolvedEntries.append(.anchor(.init(anchor: projection.sleepAnchor, rowHeight: resolvedAnchorHeight)))
        resolvedEntries.append(contentsOf: afterSleepItems.map {
            Self.itemEntry(for: $0, minimumRowHeight: resolvedItemHeight)
        })
        self.entries = resolvedEntries
    }

    var contentHeight: CGFloat {
        let rowsHeight = entries.reduce(CGFloat.zero) { $0 + $1.rowHeight }
        let connectorsHeight = CGFloat(max(entries.count - 1, 0)) * connectorHeight
        return topInset + rowsHeight + connectorsHeight + bottomInset
    }

    static func itemEntry(for item: TimelinePlanItem, minimumRowHeight: CGFloat) -> Entry {
        let capsuleHeight = timelineCapsuleHeight(for: item.duration)
        return .item(.init(
            item: item,
            rowHeight: max(minimumRowHeight, capsuleHeight + 20),
            capsuleHeight: capsuleHeight
        ))
    }
}
