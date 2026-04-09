import Foundation

struct QuietTrackingRailCardPresentation: Equatable, Identifiable {
    let id: String
    let title: String
    let iconSymbolName: String
    let colorFamily: HabitColorFamily
    let cells: [HabitBoardCell]
    let accessibilityLabel: String
    let accessibilityValue: String

    init(row: HomeHabitRow) {
        let resolvedColorFamily = HabitColorFamily.family(
            for: row.accentHex,
            fallback: row.kind == .positive ? .green : .coral
        )

        self.id = row.id
        self.title = row.title
        self.iconSymbolName = row.iconSymbolName
        self.colorFamily = resolvedColorFamily
        self.cells = Self.resolveCells(for: row)
        self.accessibilityLabel = row.title
        self.accessibilityValue = "Current streak \(row.currentStreak) days. Last 7 days shown."
    }

    private static func resolveCells(for row: HomeHabitRow) -> [HabitBoardCell] {
        if row.boardCellsExpanded.count >= 7 {
            return Array(row.boardCellsExpanded.suffix(7))
        }

        let referenceDate = row.boardCellsExpanded.last?.date
            ?? row.boardCellsCompact.last?.date
            ?? row.last14Days.last?.date
            ?? row.dueAt
            ?? Date()

        return HabitBoardPresentationBuilder.buildCells(
            marks: row.last14Days,
            cadence: row.cadence,
            referenceDate: referenceDate,
            dayCount: 7
        )
    }
}

public struct FocusNowSectionState: Equatable {
    public let rows: [HomeTodayRow]
    public let pinnedTaskIDs: [UUID]
    public let maxVisibleCount: Int

    public init(
        rows: [HomeTodayRow],
        pinnedTaskIDs: [UUID],
        maxVisibleCount: Int = 3
    ) {
        let clampedMaxVisibleCount = max(0, maxVisibleCount)
        self.rows = Array(rows.prefix(clampedMaxVisibleCount))
        self.pinnedTaskIDs = pinnedTaskIDs
        self.maxVisibleCount = clampedMaxVisibleCount
    }

    public var visibleCount: Int { rows.count }
    public var showsShuffle: Bool { rows.isEmpty == false }
}

public struct TodayAgendaSectionState: Equatable {
    public let sections: [HomeListSection]

    public init(sections: [HomeListSection]) {
        self.sections = sections
    }

    public var totalCount: Int {
        sections.reduce(0) { $0 + $1.rows.filter(\.isOpenForHomeCount).count }
    }
}

public struct RescueSectionState: Equatable {
    public let rows: [HomeTodayRow]
    public let isExpandedByDefault: Bool
    public let previewCount: Int

    public init(
        rows: [HomeTodayRow],
        isExpandedByDefault: Bool = false,
        previewCount: Int = 3
    ) {
        self.rows = rows
        self.isExpandedByDefault = isExpandedByDefault
        self.previewCount = max(0, previewCount)
    }

    public var totalCount: Int { rows.count }
    public var previewRows: [HomeTodayRow] { Array(rows.prefix(previewCount)) }
    public var isEmpty: Bool { rows.isEmpty }
    public var isCollapsedByDefault: Bool { !isExpandedByDefault }
}

public struct QuietTrackingSummaryState: Equatable {
    public let stableRows: [HomeHabitRow]

    public init(stableRows: [HomeHabitRow]) {
        self.stableRows = stableRows
    }

    public var stableCount: Int { stableRows.count }
    public var isVisible: Bool { stableRows.isEmpty == false }
    var railCards: [QuietTrackingRailCardPresentation] {
        stableRows.map(QuietTrackingRailCardPresentation.init(row:))
    }

    public var summaryText: String {
        switch stableCount {
        case 0:
            return ""
        case 1:
            return "1 routine stable today"
        default:
            return "\(stableCount) routines stable today"
        }
    }
}

public struct HabitHomeSectionState: Equatable {
    public let primaryRows: [HomeHabitRow]
    public let recoveryRows: [HomeHabitRow]

    public init(
        primaryRows: [HomeHabitRow],
        recoveryRows: [HomeHabitRow]
    ) {
        self.primaryRows = primaryRows
        self.recoveryRows = recoveryRows
    }

    public var totalCount: Int { primaryRows.count + recoveryRows.count }
    public var onStreakCount: Int {
        (primaryRows + recoveryRows).filter { $0.currentStreak > 0 }.count
    }
    public var atRiskCount: Int { recoveryRows.count }
    public var isVisible: Bool { totalCount > 0 }
}
