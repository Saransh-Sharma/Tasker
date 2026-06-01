//
//  TimelinePhoneRenderModel.swift
//  LifeBoard
//
//  Move-only timeline decomposition.
//

import SwiftUI

enum TimelinePhoneRenderModel: Equatable, Identifiable {
    case normal(TimelinePlanItem)
    case flock(TimelineFlockModel)

    var id: String {
        switch self {
        case .normal(let item):
            return "normal:\(item.id)"
        case .flock(let model):
            return model.id
        }
    }

    static func make(from block: TimelineTimeBlock, now: Date) -> TimelinePhoneRenderModel {
        switch block.kind {
        case .single(let item):
            return .normal(item)
        case .conflict:
            return .flock(TimelineFlockModel(block: block, now: now))
        }
    }
}

struct TimelineFlockModel: Equatable, Identifiable {
    enum DensityMode: Equatable {
        case smallFlock
        case mediumFlock
        case denseFlock
        case extremeFlock
    }

    struct Row: Equatable, Identifiable {
        let id: String
        let item: TimelinePlanItem?
        let title: String
        let timeText: String
        let isActiveNow: Bool
        let isCompleted: Bool
        let isSummary: Bool
    }

    static let headerHeight: CGFloat = 36
    static let verticalPadding: CGFloat = 16
    static let rowSpacing: CGFloat = 4
    static let effectiveTapTargetHeight: CGFloat = 44
    static let maximumDisplayHeight: CGFloat = 280

    let id: String
    let startDate: Date
    let endDate: Date
    let countLabel: String
    let densityMode: DensityMode
    let rows: [Row]
    let visibleItemIDs: [String]
    let isCollapsedExtreme: Bool
    let activeItemID: String?

    init(block: TimelineTimeBlock, now: Date) {
        let sortedItems = Self.sortedItems(block.items)
        let visibleItems = Self.visibleItems(from: sortedItems, now: now)
        let titles = TimelineDenseTitleFormatter.displayTitles(for: visibleItems)
        let rowItems = visibleItems.map { item in
            Row(
                id: item.id,
                item: item,
                title: titles[item.id] ?? item.title,
                timeText: Self.compactTimeText(for: item),
                isActiveNow: Self.item(item, contains: now),
                isCompleted: item.isComplete,
                isSummary: false
            )
        }
        let collapsed = sortedItems.count > visibleItems.count
        let summaryRows = collapsed
            ? [
                Row(
                    id: "\(block.id):summary",
                    item: nil,
                    title: "View all \(sortedItems.count) items",
                    timeText: "",
                    isActiveNow: false,
                    isCompleted: false,
                    isSummary: true
                )
            ]
            : []

        self.id = "flock:\(block.id)"
        self.startDate = block.startDate
        self.endDate = block.endDate
        self.countLabel = block.countLabel.lowercased()
        self.densityMode = Self.densityMode(for: sortedItems.count)
        self.rows = rowItems + summaryRows
        self.visibleItemIDs = visibleItems.map(\.id)
        self.isCollapsedExtreme = collapsed
        self.activeItemID = visibleItems.first { Self.item($0, contains: now) }?.id
    }

    var rowVisualHeight: CGFloat {
        Self.rowVisualHeight(for: densityMode)
    }

    var displayHeight: CGFloat {
        Self.displayHeight(itemCount: rows.count, densityMode: densityMode)
    }

    static func densityMode(for itemCount: Int) -> DensityMode {
        switch itemCount {
        case ..<3:
            return .smallFlock
        case 3...4:
            return .mediumFlock
        case 5...7:
            return .denseFlock
        default:
            return .extremeFlock
        }
    }

    static func rowVisualHeight(for densityMode: DensityMode) -> CGFloat {
        switch densityMode {
        case .smallFlock:
            return 40
        case .mediumFlock:
            return 34
        case .denseFlock:
            return 28
        case .extremeFlock:
            return 26
        }
    }

    static func displayHeight(itemCount: Int, densityMode: DensityMode? = nil) -> CGFloat {
        switch itemCount {
        case ..<3:
            return 104
        case 3:
            return 132
        case 4:
            return 156
        default:
            break
        }

        let mode = densityMode ?? Self.densityMode(for: itemCount)
        let rowHeight = Self.rowVisualHeight(for: mode)
        let rawHeight = Self.headerHeight
            + Self.verticalPadding
            + (CGFloat(itemCount) * rowHeight)
            + (CGFloat(max(itemCount - 1, 0)) * Self.rowSpacing)
        return min(max(rawHeight, 156), Self.maximumDisplayHeight)
    }

    private static func visibleItems(from sortedItems: [TimelinePlanItem], now: Date) -> [TimelinePlanItem] {
        guard sortedItems.count >= 8 else { return sortedItems }

        var selected: [TimelinePlanItem] = []
        func appendUnique(_ item: TimelinePlanItem?) {
            guard let item, selected.contains(where: { $0.id == item.id }) == false else { return }
            selected.append(item)
        }

        appendUnique(sortedItems.first { item($0, contains: now) })
        appendUnique(sortedItems.first { ($0.startDate ?? .distantFuture) >= now })
        appendUnique(sortedItems.first { $0.source == .task && $0.isComplete == false })

        for item in sortedItems where selected.count < 6 {
            appendUnique(item)
        }

        return Array(selected.prefix(6))
    }

    private static func sortedItems(_ items: [TimelinePlanItem]) -> [TimelinePlanItem] {
        items.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
            }
            if lhs.endDate != rhs.endDate {
                return (lhs.endDate ?? .distantPast) < (rhs.endDate ?? .distantPast)
            }
            return TimelineTimeBlock.itemSort(lhs, rhs)
        }
    }

    private static func item(_ item: TimelinePlanItem, contains date: Date) -> Bool {
        guard let start = item.startDate, let end = item.endDate else { return false }
        return start <= date && date < end
    }

    private static func compactTimeText(for item: TimelinePlanItem) -> String {
        guard let start = item.startDate else { return "All day" }
        guard let end = item.endDate else {
            return start.formatted(date: .omitted, time: .shortened)
        }
        return TimelineFormatting.timeRangeText(start: start, end: end)
    }
}

