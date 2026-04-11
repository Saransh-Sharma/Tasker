import Foundation

struct QuietTrackingRailCardPresentation: Equatable, Identifiable {
    let id: String
    let title: String
    let iconSymbolName: String
    let colorFamily: HabitColorFamily
    let historyCells: [HabitBoardCell]
    let currentStreak: Int
    let accessibilityLabel: String

    init(row: HomeHabitRow) {
        let resolvedColorFamily = HabitColorFamily.family(
            for: row.accentHex,
            fallback: row.kind == .positive ? .green : .coral
        )

        self.id = row.id
        self.title = row.title
        self.iconSymbolName = row.iconSymbolName
        self.colorFamily = resolvedColorFamily
        self.historyCells = Self.resolveHistoryCells(for: row)
        self.currentStreak = row.currentStreak
        self.accessibilityLabel = row.title
    }

    func visibleCells(dayCount: Int) -> [HabitBoardCell] {
        guard dayCount > 0 else { return [] }
        return Array(historyCells.suffix(dayCount))
    }

    func accessibilityValue(visibleDayCount: Int) -> String {
        "Current streak \(currentStreak) days. Last \(visibleDayCount) days shown."
    }

    private static func resolveHistoryCells(for row: HomeHabitRow) -> [HabitBoardCell] {
        if row.boardCellsExpanded.count >= 30 {
            return row.boardCellsExpanded
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
            dayCount: 30
        )
    }
}

struct QuietTrackingRailLayoutSpec: Equatable {
    let visibleColumnCount: Int
    let slotWidth: CGFloat
    let visibleDayCount: Int
    let shouldScroll: Bool

    static func resolve(
        viewportWidth: CGFloat,
        totalCardCount: Int,
        historyCellCount: Int,
        compactColumnWidth: CGFloat = HabitBoardStripMode.compact.columnWidth,
        compactSpacing: CGFloat = HabitBoardStripMode.compact.spacing,
        interItemSpacing: CGFloat,
        maxVisibleColumns: Int = 3
    ) -> QuietTrackingRailLayoutSpec {
        let resolvedCardCount = max(totalCardCount, 1)
        let visibleColumnCount = min(resolvedCardCount, maxVisibleColumns)
        let totalInterItemSpacing = interItemSpacing * CGFloat(max(0, visibleColumnCount - 1))
        let measuredSlotWidth = floor(max(viewportWidth - totalInterItemSpacing, 0) / CGFloat(visibleColumnCount))

        let fallbackDayCount = max(1, min(historyCellCount, 7))
        let fallbackSlotWidth =
            (CGFloat(fallbackDayCount) * compactColumnWidth)
            + (CGFloat(max(0, fallbackDayCount - 1)) * compactSpacing)
        let slotWidth = measuredSlotWidth > 0 ? measuredSlotWidth : fallbackSlotWidth

        let visibleDayCapacity: Int
        if historyCellCount > 0 {
            let widthPerCell = max(compactColumnWidth + compactSpacing, 1)
            visibleDayCapacity = max(1, Int(floor((slotWidth + compactSpacing) / widthPerCell)))
        } else {
            visibleDayCapacity = 0
        }

        return QuietTrackingRailLayoutSpec(
            visibleColumnCount: visibleColumnCount,
            slotWidth: slotWidth,
            visibleDayCount: historyCellCount > 0 ? min(historyCellCount, visibleDayCapacity) : 0,
            shouldScroll: totalCardCount > visibleColumnCount
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

public enum RescueTailMode: Equatable {
    case compact
    case expanded
}

public struct RescueTailState: Equatable {
    public let rows: [HomeTodayRow]
    public let mode: RescueTailMode
    public let isInlineExpanded: Bool
    public let subtitle: String

    public init(
        rows: [HomeTodayRow],
        mode: RescueTailMode,
        isInlineExpanded: Bool,
        subtitle: String
    ) {
        self.rows = rows
        self.mode = mode
        self.isInlineExpanded = isInlineExpanded
        self.subtitle = subtitle
    }

    public var totalCount: Int { rows.count }
    public var previewRows: [HomeTodayRow] { rows }
    public var isCompact: Bool { mode == .compact }
}

public enum HomeAgendaTailItem: Equatable, Identifiable {
    case rescue(RescueTailState)

    public var id: String {
        switch self {
        case .rescue:
            return "rescue"
        }
    }
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
