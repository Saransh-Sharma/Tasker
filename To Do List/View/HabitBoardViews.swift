import SwiftUI
import UIKit

struct HabitBoardLayoutMetrics: Equatable {
    let leadingRailWidth: CGFloat
    let railTrailingPadding: CGFloat
    let iconSlotWidth: CGFloat
    let iconToTextSpacing: CGFloat
    let dayColumnWidth: CGFloat
    let cellHeight: CGFloat
    let rowHeight: CGFloat
    let headerHeight: CGFloat
    let boardPadding: CGFloat
    let cellGap: CGFloat
    let cellCornerRadius: CGFloat
    let visibleColumns: Int
    let historySpan: Int
    let showsFullWeekday: Bool
    let usesCompressedWeekday: Bool

    var pinnedRailWidth: CGFloat {
        leadingRailWidth + railTrailingPadding
    }

    var titleLeadingInset: CGFloat {
        iconSlotWidth + iconToTextSpacing
    }

    var gridViewportWidth: CGFloat {
        contentWidth(dayCount: visibleColumns)
    }

    func contentWidth(dayCount: Int) -> CGFloat {
        guard dayCount > 0 else { return 0 }
        return (CGFloat(dayCount) * dayColumnWidth) + (CGFloat(max(0, dayCount - 1)) * cellGap)
    }

    static func forContainerWidth(_ width: CGFloat, dynamicTypeSize: DynamicTypeSize) -> HabitBoardLayoutMetrics {
        let expandedType = dynamicTypeSize >= .accessibility1

        if width < 390 {
            return HabitBoardLayoutMetrics(
                leadingRailWidth: expandedType ? 146 : 140,
                railTrailingPadding: 10,
                iconSlotWidth: 22,
                iconToTextSpacing: 10,
                dayColumnWidth: expandedType ? 34 : 32,
                cellHeight: expandedType ? 60 : 56,
                rowHeight: expandedType ? 60 : 56,
                headerHeight: expandedType ? 74 : 70,
                boardPadding: 16,
                cellGap: 0,
                cellCornerRadius: 2,
                visibleColumns: 7,
                historySpan: 28,
                showsFullWeekday: false,
                usesCompressedWeekday: true
            )
        }

        if width < 600 {
            return HabitBoardLayoutMetrics(
                leadingRailWidth: expandedType ? 148 : 144,
                railTrailingPadding: 10,
                iconSlotWidth: 22,
                iconToTextSpacing: 10,
                dayColumnWidth: expandedType ? 36 : 34,
                cellHeight: expandedType ? 60 : 56,
                rowHeight: expandedType ? 60 : 56,
                headerHeight: expandedType ? 76 : 72,
                boardPadding: 16,
                cellGap: 0,
                cellCornerRadius: 2,
                visibleColumns: 8,
                historySpan: 28,
                showsFullWeekday: false,
                usesCompressedWeekday: true
            )
        }

        let fullRegularWidth = width >= 900
        return HabitBoardLayoutMetrics(
            leadingRailWidth: expandedType ? 152 : 148,
            railTrailingPadding: 12,
            iconSlotWidth: 22,
            iconToTextSpacing: 10,
            dayColumnWidth: expandedType ? 38 : 36,
            cellHeight: expandedType ? 40 : 38,
            rowHeight: expandedType ? 62 : 58,
            headerHeight: expandedType ? 80 : 74,
            boardPadding: 18,
            cellGap: 0,
            cellCornerRadius: 2,
            visibleColumns: fullRegularWidth ? 12 : 10,
            historySpan: 42,
            showsFullWeekday: fullRegularWidth,
            usesCompressedWeekday: !fullRegularWidth
        )
    }
}

private enum HabitBoardAccessibilityID {
    static let view = "habitBoard.view"
    static let rangeTitle = "habitBoard.rangeTitle"
    static let previousWindow = "habitBoard.window.previous"
    static let nextWindow = "habitBoard.window.next"
    static let pinnedHeader = "habitBoard.pinned.header"
    static let homeOpenBoard = "home.habits.openBoard"
    static func row(_ habitID: UUID) -> String { "habitBoard.row.\(habitID.uuidString)" }
    static func pinnedTitle(_ habitID: UUID) -> String { "habitBoard.pinnedTitle.\(habitID.uuidString)" }
    static func dayHeader(_ date: Date) -> String { "habitBoard.dayHeader.\(date.habitBoardAccessibilityStamp)" }
    static func dayCell(_ habitID: UUID, date: Date) -> String {
        "habitBoard.cell.\(habitID.uuidString).\(date.habitBoardAccessibilityStamp)"
    }
}

enum HabitBoardStripMode: Equatable {
    case compact
    case expanded
    case board
    case homeList

    var isMatrixLike: Bool {
        switch self {
        case .board, .homeList:
            return true
        case .compact, .expanded:
            return false
        }
    }

    var cellSize: CGFloat {
        switch self {
        case .compact: return 14
        case .expanded: return 15
        case .board: return 16
        case .homeList: return 15
        }
    }

    var spacing: CGFloat {
        switch self {
        case .compact: return 0
        case .expanded: return 0
        case .board: return 0
        case .homeList: return 0
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 2
        case .expanded: return 1
        case .board: return 3
        case .homeList: return 1
        }
    }

    var columnWidth: CGFloat {
        cellSize
    }
}

struct HabitBoardStripView: View {
    let cells: [HabitBoardCell]
    let family: HabitColorFamily
    let mode: HabitBoardStripMode
    var cellSizeOverride: CGFloat? = nil
    var cellWidthOverride: CGFloat? = nil
    var cellHeightOverride: CGFloat? = nil

    private var resolvedCellSize: CGFloat {
        cellSizeOverride ?? mode.cellSize
    }

    var body: some View {
        HStack(spacing: mode.spacing) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                HabitBoardCellView(
                    cell: cell,
                    family: family,
                    mode: mode,
                    cellSizeOverride: resolvedCellSize,
                    cellWidthOverride: cellWidthOverride,
                    cellHeightOverride: cellHeightOverride
                )
            }
        }
        .accessibilityHidden(true)
    }
}

struct HabitHistoryStripView: View {
    let marks: [HabitDayMark]
    let cadence: HabitCadenceDraft
    let family: HabitColorFamily

    private var boardCells: [HabitBoardCell] {
        HabitBoardPresentationBuilder.buildCells(
            marks: marks,
            cadence: cadence,
            referenceDate: marks.last?.date ?? Date(),
            dayCount: max(marks.count, 14)
        )
    }

    var body: some View {
        HabitBoardStripView(
            cells: boardCells,
            family: family,
            mode: .compact
        )
    }
}

struct HabitHomeSectionCard: View {
    let title: String
    let subtitle: String
    let rows: [HomeHabitRow]
    let countValue: String
    let secondaryValue: String
    let tertiaryValue: String
    let onOpenBoard: (() -> Void)?
    let onPrimaryAction: (HomeHabitRow) -> Void
    let onSecondaryAction: (HomeHabitRow) -> Void
    let onLastCellAction: (HomeHabitRow) -> Void
    let onOpenHabit: ((HomeHabitRow) -> Void)?

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    init(
        title: String,
        subtitle: String,
        rows: [HomeHabitRow],
        countValue: String,
        secondaryValue: String,
        tertiaryValue: String,
        onOpenBoard: (() -> Void)?,
        onPrimaryAction: @escaping (HomeHabitRow) -> Void,
        onSecondaryAction: @escaping (HomeHabitRow) -> Void,
        onLastCellAction: @escaping (HomeHabitRow) -> Void,
        onOpenHabit: ((HomeHabitRow) -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.rows = rows
        self.countValue = countValue
        self.secondaryValue = secondaryValue
        self.tertiaryValue = tertiaryValue
        self.onOpenBoard = onOpenBoard
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
        self.onLastCellAction = onLastCellAction
        self.onOpenHabit = onOpenHabit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)

                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)

                if let onOpenBoard {
                    Button("Board") { onOpenBoard() }
                        .font(.tasker(.caption1).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .frame(minWidth: 56, minHeight: 44)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.tasker.strokeHairline.opacity(0.55), lineWidth: 1)
                        )
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(HabitBoardAccessibilityID.homeOpenBoard)
                        .accessibilityLabel("Open Habit Board")
                }
            }

            HStack(spacing: spacing.s8) {
                HabitBoardStripView(
                    cells: aggregatePreviewCells,
                    family: .gray,
                    mode: .compact
                )

                Spacer(minLength: 0)

                Text(countValue)
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker.textPrimary)

                Text(secondaryValue)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)

                Text(tertiaryValue)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HomeHabitRowView(
                        row: row,
                        onPrimaryAction: { onPrimaryAction(row) },
                        onSecondaryAction: { onSecondaryAction(row) },
                        onOpenDetail: {
                            onOpenHabit?(row)
                        },
                        onLastCellAction: { onLastCellAction(row) }
                    )

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, spacing.s12)
                    }
                }
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s12)
        .background(HabitBoardSurfaceBackground(cornerRadius: TaskerTheme.CornerRadius.card))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous))
    }

    private var aggregatePreviewCells: [HabitBoardCell] {
        let presentations = rows.map { row in
            HabitBoardRowPresentation(
                habitID: row.habitID,
                title: row.title,
                iconSymbolName: row.iconSymbolName,
                accentHex: row.accentHex,
                colorFamily: HabitColorFamily.family(for: row.accentHex),
                currentStreak: row.currentStreak,
                bestStreak: row.bestStreak,
                cells: row.boardCellsCompact,
                metrics: HabitBoardRowMetrics(
                    currentStreak: row.currentStreak,
                    bestStreak: row.bestStreak,
                    totalCount: row.boardCellsCompact.filter(\.isSuccess).count,
                    weekCount: row.boardCellsCompact.filter(\.isSuccess).count,
                    monthCount: row.boardCellsCompact.filter(\.isSuccess).count,
                    yearCount: row.boardCellsCompact.filter(\.isSuccess).count
                )
            )
        }
        let aggregateDays = HabitBoardPresentationBuilder.aggregateDays(
            from: presentations,
            dayCount: min(7, rows.first?.boardCellsCompact.count ?? 0)
        )
        return aggregateDays.map { day in
            HabitBoardCell(
                date: day.date,
                state: day.completedCount > 0 ? .done(depth: min(day.completedCount, 8)) : .missed,
                isToday: day.isToday,
                isWeekend: Calendar.current.isDateInWeekend(day.date)
            )
        }
    }
}

struct HabitBoardScreen: View {
    @ObservedObject var viewModel: HabitBoardViewModel
    @State private var selectedHabitRow: HabitLibraryRow?
    @State private var measuredBoardWidth: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var layoutMetrics: HabitBoardLayoutMetrics {
        HabitBoardLayoutMetrics.forContainerWidth(resolvedBoardWidth, dynamicTypeSize: dynamicTypeSize)
    }
    private var resolvedBoardWidth: CGFloat {
        let fallback = max(UIScreen.main.bounds.width - (spacing.s16 * 2), 320)
        return measuredBoardWidth > 1 ? measuredBoardWidth : fallback
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                boardSurface
                    .enhancedStaggeredAppearance(index: 0)
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s24)
            }
            .background(Color.tasker.bgCanvas)
            .accessibilityIdentifier(HabitBoardAccessibilityID.view)
            .navigationTitle("Habit Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: layoutMetrics) {
                viewModel.configureViewport(columnCount: layoutMetrics.visibleColumns, historySpan: layoutMetrics.historySpan)
                viewModel.loadIfNeeded()
            }
            .sheet(item: $selectedHabitRow) { row in
                HabitDetailSheetView(
                    viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                    onMutation: { viewModel.refresh() }
                )
            }
        }
    }

    private var boardSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            boardHeader

            Rectangle()
                .fill(Color.tasker.strokeHairline.opacity(0.16))
                .frame(height: 1)

            if viewModel.boardRows.isEmpty, !viewModel.isLoading {
                ContentUnavailableView(
                    "No habits yet",
                    systemImage: "square.grid.3x3.topleft.filled",
                    description: Text("Create a habit to start building a board.")
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, spacing.s16)
                .padding(.vertical, spacing.s24)
            } else {
                boardMatrix
            }
        }
        .background(HabitBoardFlatSurfaceBackground(cornerRadius: 24))
        .background(HabitBoardWidthReader())
        .onPreferenceChange(HabitBoardWidthPreferenceKey.self) { width in
            guard width > 1 else { return }
            measuredBoardWidth = width
        }
    }

    private func boardPagerButton(
        systemName: String,
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.tasker.textPrimary)
                .frame(width: 44, height: 44)
                .background(Color.tasker.surfacePrimary.opacity(0.98))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.tasker.strokeHairline.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(accessibilityLabel)
    }

    private var boardHeader: some View {
        HStack(alignment: .center, spacing: spacing.s12) {
            boardPagerButton(
                systemName: "chevron.left",
                accessibilityIdentifier: HabitBoardAccessibilityID.previousWindow,
                accessibilityLabel: "Show previous \(viewModel.viewportColumnCount) days"
            ) {
                viewModel.moveWindow(byDays: -viewModel.viewportColumnCount)
            }

            HStack(alignment: .center, spacing: spacing.s8) {
                Text(rangeTitle)
                    .font(.tasker(.bodyStrong))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .accessibilityIdentifier(HabitBoardAccessibilityID.rangeTitle)

                boardWindowBadge
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            boardPagerButton(
                systemName: "chevron.right",
                accessibilityIdentifier: HabitBoardAccessibilityID.nextWindow,
                accessibilityLabel: "Show next \(viewModel.viewportColumnCount) days"
            ) {
                viewModel.moveWindow(byDays: viewModel.viewportColumnCount)
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s12)
    }

    private var boardWindowBadge: some View {
        Text("\(viewModel.viewportColumnCount) DAYS")
            .font(.system(size: 11, weight: .semibold, design: .default))
            .foregroundStyle(Color.tasker.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.tasker.surfaceSecondary.opacity(0.9))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.22), lineWidth: 1)
            )
            .fixedSize()
    }

    private var boardMatrix: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HabitBoardPinnedColumnHeader(layoutMetrics: layoutMetrics)

                Divider()
                    .overlay(Color.tasker.strokeHairline.opacity(0.12))

                LazyVStack(spacing: 0) {
                    ForEach(viewModel.boardRows) { row in
                        HabitBoardPinnedRowView(
                            row: row,
                            layoutMetrics: layoutMetrics,
                            onSelect: {
                                if let libraryRow = viewModel.row(for: row.habitID) {
                                    selectedHabitRow = libraryRow
                                }
                            }
                        )

                        Divider()
                            .overlay(Color.tasker.strokeHairline.opacity(0.1))
                    }
                }
            }
            .background(Color.tasker.surfaceSecondary.opacity(0.26))
            .frame(width: layoutMetrics.pinnedRailWidth, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HabitBoardDayHeaderRow(days: viewModel.aggregateDays, layoutMetrics: layoutMetrics)

                    Divider()
                        .overlay(Color.tasker.strokeHairline.opacity(0.12))

                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.boardRows) { row in
                            HabitBoardMatrixRowView(
                                row: row,
                                layoutMetrics: layoutMetrics
                            )

                            Divider()
                                .overlay(Color.tasker.strokeHairline.opacity(0.1))
                        }
                    }
                }
                .frame(
                    minWidth: max(layoutMetrics.gridViewportWidth, layoutMetrics.contentWidth(dayCount: viewModel.aggregateDays.count)),
                    alignment: .leading
                )
            }
            .frame(width: layoutMetrics.gridViewportWidth, alignment: .leading)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .padding(layoutMetrics.boardPadding)
    }

    private var rangeTitle: String {
        guard let start = viewModel.aggregateDays.first?.date,
              let end = viewModel.aggregateDays.last?.date else {
            return "Last \(viewModel.viewportColumnCount) days"
        }
        return "\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct HabitBoardPinnedRowView: View {
    let row: HabitBoardRowPresentation
    let layoutMetrics: HabitBoardLayoutMetrics
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: layoutMetrics.iconToTextSpacing) {
            Image(systemName: row.iconSymbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HabitEverydayPalette.familyPreview(row.colorFamily))
                .frame(width: layoutMetrics.iconSlotWidth, height: layoutMetrics.rowHeight, alignment: .center)

            Text(row.title)
                .font(.tasker(.caption1).weight(.medium))
                .foregroundStyle(Color.tasker.textPrimary)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(HabitBoardAccessibilityID.pinnedTitle(row.habitID))
        }
        .frame(width: layoutMetrics.leadingRailWidth, alignment: .leading)
        .frame(minHeight: layoutMetrics.rowHeight, alignment: .center)
        .padding(.leading, 2)
        .padding(.trailing, layoutMetrics.railTrailingPadding)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.tasker.strokeHairline.opacity(0.16))
                .frame(width: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .accessibilityIdentifier(HabitBoardAccessibilityID.row(row.habitID))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(row.title)
        .accessibilityHint("Opens habit details")
        .accessibilityAction(named: Text("Open habit")) {
            onSelect()
        }
    }
}

private struct HabitBoardMatrixRowView: View {
    let row: HabitBoardRowPresentation
    let layoutMetrics: HabitBoardLayoutMetrics

    var body: some View {
        HStack(spacing: layoutMetrics.cellGap) {
            ForEach(Array(row.cells.enumerated()), id: \.element.date) { index, cell in
                HabitBoardCellView(
                    cell: cell,
                    family: row.colorFamily,
                    mode: .board,
                    cellWidthOverride: layoutMetrics.dayColumnWidth,
                    cellHeightOverride: layoutMetrics.cellHeight,
                    bridgeDepthHint: bridgeDepthHint(at: index)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(HabitBoardAccessibilityID.dayCell(row.habitID, date: cell.date))
                .accessibilityLabel(cellAccessibilityLabel(for: cell))
                .accessibilityValue(cellAccessibilityValue(for: cell))
            }
        }
        .frame(height: layoutMetrics.rowHeight, alignment: .center)
    }

    private func bridgeDepthHint(at index: Int) -> Int? {
        guard case .bridge = row.cells[index].state else { return nil }
        let previousDepth = nearestDoneDepth(before: index)
        let nextDepth = nearestDoneDepth(after: index)
        let resolvedDepth = max(previousDepth ?? 0, nextDepth ?? 0)
        return resolvedDepth > 0 ? resolvedDepth : nil
    }

    private func nearestDoneDepth(before index: Int) -> Int? {
        guard index > 0 else { return nil }
        for cursor in stride(from: index - 1, through: 0, by: -1) {
            switch row.cells[cursor].state {
            case .done(let depth):
                return depth
            case .bridge, .todayPending:
                continue
            case .missed, .future:
                return nil
            }
        }
        return nil
    }

    private func nearestDoneDepth(after index: Int) -> Int? {
        guard index < row.cells.count - 1 else { return nil }
        for cursor in (index + 1)..<row.cells.count {
            switch row.cells[cursor].state {
            case .done(let depth):
                return depth
            case .bridge, .todayPending:
                continue
            case .missed, .future:
                return nil
            }
        }
        return nil
    }

    private func cellAccessibilityLabel(for cell: HabitBoardCell) -> String {
        "\(row.title), \(cell.date.formatted(date: .complete, time: .omitted))"
    }

    private func cellAccessibilityValue(for cell: HabitBoardCell) -> String {
        switch cell.state {
        case .done:
            return "Completed"
        case .missed:
            return "Missed"
        case .todayPending:
            return "Due today"
        case .future:
            return "Future day"
        case .bridge(let kind, let source):
            let sourceLabel = source == .skipped ? "Skipped" : "Not scheduled"
            return "\(sourceLabel), transition \(kind.accessibilityLabel)"
        }
    }
}

private struct HabitBoardPinnedColumnHeader: View {
    let layoutMetrics: HabitBoardLayoutMetrics

    var body: some View {
        ZStack {
            Text("Habits")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(Color.tasker.textSecondary)
                .tracking(0.1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: layoutMetrics.leadingRailWidth, height: layoutMetrics.headerHeight, alignment: .center)
        .padding(.trailing, layoutMetrics.railTrailingPadding)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.tasker.strokeHairline.opacity(0.16))
                .frame(width: 1)
        }
        .accessibilityIdentifier(HabitBoardAccessibilityID.pinnedHeader)
    }
}

private struct HabitBoardDayHeaderRow: View {
    let days: [HabitBoardAggregateDay]
    let layoutMetrics: HabitBoardLayoutMetrics

    var body: some View {
        HStack(spacing: layoutMetrics.cellGap) {
            ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                HabitBoardHeaderDayCell(
                    day: day,
                    showsMonthMarker: index == 0 || !Calendar.current.isDate(day.date, equalTo: days[index - 1].date, toGranularity: .month),
                    layoutMetrics: layoutMetrics
                )
            }
        }
        .frame(height: layoutMetrics.headerHeight, alignment: .bottom)
    }
}

private struct HabitBoardHeaderDayCell: View {
    let day: HabitBoardAggregateDay
    let showsMonthMarker: Bool
    let layoutMetrics: HabitBoardLayoutMetrics
    @Environment(\.colorScheme) private var colorScheme

    private var weekdayLabel: String {
        let symbol = day.date.formatted(.dateTime.weekday(layoutMetrics.showsFullWeekday ? .abbreviated : .wide))
        if layoutMetrics.usesCompressedWeekday {
            return String(symbol.prefix(1)).uppercased()
        }
        return layoutMetrics.showsFullWeekday ? symbol.uppercased() : String(symbol.prefix(3)).uppercased()
    }

    var body: some View {
        VStack(spacing: 3) {
            monthMarker
                .frame(maxWidth: .infinity, alignment: .center)

            Text(day.date.formatted(.dateTime.day()))
                .font(.system(size: 22, weight: .semibold, design: .default))
                .monospacedDigit()
                .foregroundStyle(day.isToday ? HabitEverydayPalette.todayStroke(colorScheme: colorScheme) : Color.tasker.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(todayBackground)

            Text(weekdayLabel)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(day.isToday ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: layoutMetrics.dayColumnWidth, height: layoutMetrics.headerHeight, alignment: .bottom)
        .padding(.vertical, 10)
        .background(headerBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(HabitBoardAccessibilityID.dayHeader(day.date))
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(day.isToday ? "Today" : "")
    }

    @ViewBuilder
    private var todayBackground: some View {
        if day.isToday {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.tasker.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(HabitEverydayPalette.todayStroke(colorScheme: colorScheme), lineWidth: 1.4)
                )
                .shadow(color: HabitEverydayPalette.todayStroke(colorScheme: colorScheme).opacity(0.12), radius: 8, y: 2)
                .padding(.horizontal, 1)
        } else {
            Color.clear
        }
    }

    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: layoutMetrics.cellCornerRadius, style: .continuous)
            .fill(day.isToday ? Color.tasker.surfaceSecondary.opacity(0.42) : (Calendar.current.isDateInWeekend(day.date) ? Color.tasker.surfaceSecondary.opacity(0.3) : Color.clear))
    }

    @ViewBuilder
    private var monthMarker: some View {
        if showsMonthMarker {
            Text(day.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(Color.tasker.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        } else {
            Color.clear
                .frame(height: 13)
        }
    }
}

struct HabitStatBadgeView: View {
    let value: String
    let family: HabitColorFamily
    let highlighted: Bool

    var body: some View {
        Group {
            if highlighted {
                Text(value)
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(HabitEverydayPalette.familyPreview(family))
                    .frame(width: 28, height: 28)
                    .background(Color.tasker.surfacePrimary.opacity(0.94))
                    .overlay(
                        Circle()
                            .stroke(HabitEverydayPalette.familyPreview(family), lineWidth: 2)
                    )
                    .clipShape(Circle())
            } else {
                Text(value)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .frame(minWidth: 28, alignment: .leading)
            }
        }
    }
}

private struct HabitBoardFlatSurfaceBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.tasker.surfacePrimary.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 14, y: 8)
    }
}

private struct HabitBoardSurfaceBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.tasker.surfacePrimary.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.58), lineWidth: 1)
            )
            .overlay(
                PaperGrainOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
    }
}

private struct HabitBoardWidthReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: HabitBoardWidthPreferenceKey.self, value: proxy.size.width)
        }
    }
}

private struct HabitBoardWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PaperGrainOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let columns = max(8, Int(size.width / 28))
                let rows = max(6, Int(size.height / 22))
                for row in 0..<rows {
                    for column in 0..<columns {
                        var path = Path()
                        let seed = CGFloat(((row * 17) + (column * 29)) % 11)
                        let x = (CGFloat(column) + 0.35) * (size.width / CGFloat(columns))
                        let y = (CGFloat(row) + 0.4) * (size.height / CGFloat(rows))
                        let dot = CGRect(x: x, y: y, width: 0.7 + (seed * 0.02), height: 0.7 + (seed * 0.02))
                        path.addEllipse(in: dot)
                        context.fill(path, with: .color(Color.black.opacity(0.035)))
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }
}

private struct HabitBoardCellView: View {
    let cell: HabitBoardCell
    let family: HabitColorFamily
    let mode: HabitBoardStripMode
    let cellSizeOverride: CGFloat?
    let cellWidthOverride: CGFloat?
    let cellHeightOverride: CGFloat?
    let bridgeDepthHint: Int?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    init(
        cell: HabitBoardCell,
        family: HabitColorFamily,
        mode: HabitBoardStripMode,
        cellSizeOverride: CGFloat? = nil,
        cellWidthOverride: CGFloat? = nil,
        cellHeightOverride: CGFloat? = nil,
        bridgeDepthHint: Int? = nil
    ) {
        self.cell = cell
        self.family = family
        self.mode = mode
        self.cellSizeOverride = cellSizeOverride
        self.cellWidthOverride = cellWidthOverride
        self.cellHeightOverride = cellHeightOverride
        self.bridgeDepthHint = bridgeDepthHint
    }

    private var resolvedCellWidth: CGFloat {
        cellWidthOverride ?? cellSizeOverride ?? mode.cellSize
    }

    private var resolvedCellHeight: CGFloat {
        cellHeightOverride ?? cellSizeOverride ?? mode.cellSize
    }

    var body: some View {
        ZStack {
            switch cell.state {
            case .bridge(let kind, let source):
                HabitBridgeTileView(
                    kind: kind,
                    source: source,
                    family: family,
                    mode: mode,
                    colorScheme: colorScheme,
                    depthHint: bridgeDepthHint
                )
            default:
                baseFill
            }

            if differentiateWithoutColor {
                differentiateOverlay
            }
        }
        .frame(width: resolvedCellWidth, height: resolvedCellHeight)
        .overlay {
            todayOverlay
        }
    }

    @ViewBuilder
    private var differentiateOverlay: some View {
        switch cell.state {
        case .missed:
            Rectangle()
                .fill(Color.tasker.textSecondary.opacity(0.22))
                .frame(width: resolvedCellWidth * 0.45, height: 1)
        case .bridge:
            Circle()
                .fill(Color.tasker.textSecondary)
                .frame(width: mode.isMatrixLike ? 5 : 4, height: mode.isMatrixLike ? 5 : 4)
        case .done, .todayPending, .future:
            EmptyView()
        }
    }

    private var baseFill: some View {
        RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
            .fill(fillColor)
            .overlay(doneGrainOverlay)
    }

    @ViewBuilder
    private var todayOverlay: some View {
        if cell.isToday {
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .stroke(HabitEverydayPalette.todayStroke(colorScheme: colorScheme), lineWidth: mode.isMatrixLike ? 1.35 : 1.2)
                .padding(mode.isMatrixLike ? 0.5 : 0)
        }
    }

    private var fillColor: Color {
        switch cell.state {
        case .done(let depth):
            return HabitEverydayPalette.depthColor(for: family, depth: depth, colorScheme: colorScheme)
        case .missed:
            return HabitEverydayPalette.missedFill(colorScheme: colorScheme)
        case .todayPending:
            return HabitEverydayPalette.paperFill(colorScheme: colorScheme)
        case .future:
            return HabitEverydayPalette.futureFill(colorScheme: colorScheme)
        case .bridge:
            return .clear
        }
    }

    @ViewBuilder
    private var doneGrainOverlay: some View {
        switch cell.state {
        case .done:
            if mode.isMatrixLike {
                EmptyView()
            } else {
                Canvas { context, size in
                    for index in 0..<6 {
                        var path = Path()
                        let x = CGFloat((index * 7) % 11) / 11 * size.width
                        let y = CGFloat((index * 11) % 13) / 13 * size.height
                        path.addEllipse(in: CGRect(x: x, y: y, width: 0.6, height: 0.6))
                        context.fill(path, with: .color(Color.white.opacity(0.12)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous))
            }
        default:
            EmptyView()
        }
    }
}

private struct HabitBridgeTileView: View {
    let kind: HabitBridgeKind
    let source: HabitBridgeSource
    let family: HabitColorFamily
    let mode: HabitBoardStripMode
    let colorScheme: ColorScheme
    let depthHint: Int?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .fill(HabitEverydayPalette.paperFill(colorScheme: colorScheme))

            switch kind {
            case .single:
                DualCornerBridgeFill()
                    .fill(HabitEverydayPalette.bridgeTint(for: family, depth: depthHint, colorScheme: colorScheme))
            case .start:
                LeadingBridgeFill()
                    .fill(HabitEverydayPalette.bridgeTint(for: family, depth: depthHint, colorScheme: colorScheme))
            case .middle:
                DiagonalBridgeBand()
                    .fill(HabitEverydayPalette.bridgeTint(for: family, depth: depthHint, colorScheme: colorScheme))
            case .end:
                TrailingBridgeFill()
                    .fill(HabitEverydayPalette.bridgeTint(for: family, depth: depthHint, colorScheme: colorScheme))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .stroke(
                    mode.isMatrixLike ? .clear : (
                        source == .skipped
                            ? HabitEverydayPalette.bridgeTint(for: family, depth: depthHint, colorScheme: colorScheme).opacity(0.18)
                            : .clear
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

private struct LeadingBridgeFill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TrailingBridgeFill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct DualCornerBridgeFill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.56, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.56))
        path.closeSubpath()

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.44, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.44))
        path.closeSubpath()
        return path
    }
}

private struct DiagonalBridgeBand: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.72))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

enum HabitEverydayPalette {
    static func depthColor(for family: HabitColorFamily, depth: Int, colorScheme: ColorScheme) -> Color {
        let index = max(0, min(depth - 1, 7))
        let hex = (colorScheme == .dark ? darkRamps : lightRamps)[family]?[index] ?? family.canonicalHex
        return Color(uiColor: UIColor(taskerHex: hex))
    }

    static func familyPreview(_ family: HabitColorFamily) -> Color {
        Color(uiColor: UIColor(taskerHex: lightRamps[family]?[4] ?? family.canonicalHex))
    }

    static func bridgeTint(for family: HabitColorFamily, depth: Int?, colorScheme: ColorScheme) -> Color {
        guard let depth else {
            let ramp = colorScheme == .dark ? darkRamps : lightRamps
            return Color(uiColor: UIColor(taskerHex: ramp[family]?[2] ?? family.canonicalHex))
        }

        let bridgeDepth = max(1, min(depth - 1, 7))
        return depthColor(for: family, depth: bridgeDepth, colorScheme: colorScheme)
    }

    static func gridStroke(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.black.opacity(0.04)
    }

    static func paperFill(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor(taskerHex: "#14181E"))
            : Color(uiColor: UIColor(taskerHex: "#F8FAFC"))
    }

    static func missedFill(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor(taskerHex: "#1B2027"))
            : Color(uiColor: UIColor(taskerHex: "#EEF2F6"))
    }

    static func futureFill(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor(taskerHex: "#101419"))
            : Color(uiColor: UIColor(taskerHex: "#F3F6F9"))
    }

    static func todayStroke(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor(taskerHex: "#7ABD52"))
            : Color(uiColor: UIColor(taskerHex: "#6FA242"))
    }

    private static let lightRamps: [HabitColorFamily: [String]] = [
        .green: ["#B6E59F", "#8EEA5D", "#63DF2E", "#43C618", "#30A511", "#247E0D", "#1A620A", "#124807"],
        .blue: ["#CBEAFF", "#95DAFF", "#62C3FF", "#3EA5FF", "#287FFF", "#1E5EEA", "#1641C7", "#102DA5"],
        .orange: ["#F7E8A5", "#F8D65B", "#F7BF2B", "#F4A70F", "#E98A08", "#D96A05", "#BC5304", "#984103"],
        .coral: ["#F7C9BE", "#F2A08D", "#EA7A66", "#DE6250", "#CA5342", "#B04638", "#973B2F", "#7C3027"],
        .purple: ["#E2C8EC", "#D09EE3", "#BB79D6", "#A250C2", "#892FAE", "#701E92", "#5A1377", "#450D5D"],
        .teal: ["#CFEDEC", "#9DDFDD", "#72CBCA", "#51B7B7", "#3A9EA0", "#2D8285", "#22686A", "#194F51"],
        .gray: ["#EDEDED", "#DADADA", "#C6C6C6", "#AEAEAE", "#939393", "#787878", "#616161", "#4D4D4D"]
    ]

    private static let darkRamps: [HabitColorFamily: [String]] = [
        .green: ["#89D962", "#76D64E", "#63C93F", "#52B530", "#429B24", "#347B1B", "#295F16", "#214B11"],
        .blue: ["#8ECFFF", "#6ABEFF", "#4DA7FF", "#3A8EFF", "#2C74F0", "#275DCE", "#2149AC", "#1A387F"],
        .orange: ["#F5CF74", "#F0B64B", "#E59E30", "#DA850F", "#C56E09", "#A95A07", "#8A4A07", "#703D06"],
        .coral: ["#F0A692", "#E2836D", "#D56E57", "#C35A48", "#AD493A", "#913B2F", "#763026", "#5F261E"],
        .purple: ["#CFAAE0", "#BB8AD2", "#A56BC1", "#8F4DAD", "#783696", "#60277A", "#4B1E5E", "#391747"],
        .teal: ["#9ED6D2", "#7DC8C4", "#62B7B2", "#4DA3A0", "#3B8E8A", "#2F7471", "#245957", "#1C4644"],
        .gray: ["#C2C2C2", "#AFAFAF", "#9A9A9A", "#868686", "#727272", "#626262", "#545454", "#474747"]
    ]
}

private extension HabitBoardCell {
    var isSuccess: Bool {
        if case .done = state {
            return true
        }
        return false
    }
}

private extension HabitBridgeKind {
    var accessibilityLabel: String {
        switch self {
        case .single:
            return "single"
        case .start:
            return "start"
        case .middle:
            return "middle"
        case .end:
            return "end"
        }
    }
}

private extension Date {
    var habitBoardAccessibilityStamp: String {
        HabitBoardDateFormatter.accessibilityStamp.string(from: self)
    }
}

private enum HabitBoardDateFormatter {
    static let accessibilityStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
