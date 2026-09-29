import SwiftUI
import UIKit

struct HabitBoardLayoutMetrics: Equatable {
    private static let fixedVisibleColumns = 7

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
            let leadingRailWidth: CGFloat = expandedType ? 146 : 140
            let railTrailingPadding: CGFloat = 10
            let boardPadding: CGFloat = 16
            return HabitBoardLayoutMetrics(
                leadingRailWidth: leadingRailWidth,
                railTrailingPadding: railTrailingPadding,
                iconSlotWidth: 22,
                iconToTextSpacing: 10,
                dayColumnWidth: resolvedDayColumnWidth(
                    containerWidth: width,
                    leadingRailWidth: leadingRailWidth,
                    railTrailingPadding: railTrailingPadding,
                    boardPadding: boardPadding,
                    minimum: expandedType ? 34 : 32,
                    maximum: expandedType ? 40 : 36
                ),
                cellHeight: expandedType ? 60 : 56,
                rowHeight: expandedType ? 60 : 56,
                headerHeight: expandedType ? 74 : 70,
                boardPadding: boardPadding,
                cellGap: 0,
                cellCornerRadius: 2,
                visibleColumns: fixedVisibleColumns,
                historySpan: 28,
                showsFullWeekday: false,
                usesCompressedWeekday: true
            )
        }

        if width < 600 {
            let leadingRailWidth: CGFloat = expandedType ? 148 : 144
            let railTrailingPadding: CGFloat = 10
            let boardPadding: CGFloat = 16
            return HabitBoardLayoutMetrics(
                leadingRailWidth: leadingRailWidth,
                railTrailingPadding: railTrailingPadding,
                iconSlotWidth: 22,
                iconToTextSpacing: 10,
                dayColumnWidth: resolvedDayColumnWidth(
                    containerWidth: width,
                    leadingRailWidth: leadingRailWidth,
                    railTrailingPadding: railTrailingPadding,
                    boardPadding: boardPadding,
                    minimum: expandedType ? 36 : 34,
                    maximum: expandedType ? 44 : 40
                ),
                cellHeight: expandedType ? 60 : 56,
                rowHeight: expandedType ? 60 : 56,
                headerHeight: expandedType ? 76 : 72,
                boardPadding: boardPadding,
                cellGap: 0,
                cellCornerRadius: 2,
                visibleColumns: fixedVisibleColumns,
                historySpan: 28,
                showsFullWeekday: false,
                usesCompressedWeekday: true
            )
        }

        let fullRegularWidth = width >= 900
        let leadingRailWidth: CGFloat = expandedType ? 152 : 148
        let railTrailingPadding: CGFloat = 12
        let boardPadding: CGFloat = 18
        return HabitBoardLayoutMetrics(
            leadingRailWidth: leadingRailWidth,
            railTrailingPadding: railTrailingPadding,
            iconSlotWidth: 22,
            iconToTextSpacing: 10,
            dayColumnWidth: resolvedDayColumnWidth(
                containerWidth: width,
                leadingRailWidth: leadingRailWidth,
                railTrailingPadding: railTrailingPadding,
                boardPadding: boardPadding,
                minimum: expandedType ? 40 : 38,
                // Seven days is the board's grammar at every width, but at
                // 900+ points the cells may grow: capped at 52, a 1366-point
                // board stopped at ~560 points and left the rest of the row
                // empty.
                maximum: fullRegularWidth ? 110 : (expandedType ? 56 : 52)
            ),
            cellHeight: expandedType ? 62 : 58,
            rowHeight: expandedType ? 62 : 58,
            headerHeight: expandedType ? 80 : 74,
            boardPadding: boardPadding,
            cellGap: 0,
            cellCornerRadius: 2,
            visibleColumns: fixedVisibleColumns,
            historySpan: 42,
            showsFullWeekday: fullRegularWidth,
            usesCompressedWeekday: false
        )
    }

    private static func resolvedDayColumnWidth(
        containerWidth: CGFloat,
        leadingRailWidth: CGFloat,
        railTrailingPadding: CGFloat,
        boardPadding: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        let horizontalInsets = boardPadding * 2
        let availableGridWidth = containerWidth - horizontalInsets - leadingRailWidth - railTrailingPadding
        let projectedCellWidth = floor(availableGridWidth / CGFloat(fixedVisibleColumns))
        return min(maximum, max(minimum, projectedCellWidth))
    }
}

enum HabitBoardAccessibilityID {
    static let view = "habitBoard.view"
    static let rangeTitle = "habitBoard.rangeTitle"
    static let rangeSubtitle = "habitBoard.rangeSubtitle"
    static let previousWindow = "habitBoard.window.previous"
    static let nextWindow = "habitBoard.window.next"
    static let pinnedHeader = "habitBoard.pinned.header"
    static let loadingState = "habitBoard.state.loading"
    static let emptyState = "habitBoard.state.empty"
    static let errorState = "habitBoard.state.error"
    static let retryButton = "habitBoard.state.retry"
    static let createButton = "habitBoard.state.create"
    static let homeOpenBoard = "home.habits.openBoard"
    static let homeAddHabit = "home.habits.addHabit"
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
            ForEach(cells, id: \.date) { cell in
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
    let summaryLine: String
    let rows: [HomeHabitRow]
    let onOpenBoard: (() -> Void)?
    let onPrimaryAction: (HomeHabitRow) -> Void
    let onSecondaryAction: (HomeHabitRow) -> Void
    let onRowAction: (HomeHabitRow) -> Void
    let onLastCellAction: (HomeHabitRow) -> Void
    let onOpenHabit: ((HomeHabitRow) -> Void)?
    let onAddHabit: (() -> Void)?

    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    init(
        title: String,
        summaryLine: String,
        rows: [HomeHabitRow],
        onOpenBoard: (() -> Void)?,
        onPrimaryAction: @escaping (HomeHabitRow) -> Void,
        onSecondaryAction: @escaping (HomeHabitRow) -> Void,
        onRowAction: @escaping (HomeHabitRow) -> Void,
        onLastCellAction: @escaping (HomeHabitRow) -> Void,
        onOpenHabit: ((HomeHabitRow) -> Void)? = nil,
        onAddHabit: (() -> Void)? = nil
    ) {
        self.title = title
        self.summaryLine = summaryLine
        self.rows = rows
        self.onOpenBoard = onOpenBoard
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
        self.onRowAction = onRowAction
        self.onLastCellAction = onLastCellAction
        self.onOpenHabit = onOpenHabit
        self.onAddHabit = onAddHabit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(alignment: .center, spacing: spacing.s8) {
                Text(title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)

                Text(summaryLine)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: spacing.s4)

                HabitBoardStripView(
                    cells: aggregatePreviewCells,
                    family: .gray,
                    mode: .compact
                )
                .layoutPriority(1)

                if let onOpenBoard {
                    Button { onOpenBoard() } label: {
                        Label("Board", systemImage: "square.grid.3x3")
                            .labelStyle(.iconOnly)
                            .lifeboardFont(.buttonSmall)
                    }
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.compact, style: .continuous)
                                .fill(ClayColorTokens.whiteStroke.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.compact, style: .continuous)
                                .stroke(Color.lifeboard.strokeHairline.opacity(0.55), lineWidth: 1)
                        )
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(HabitBoardAccessibilityID.homeOpenBoard)
                        .accessibilityLabel("Open habits")
                }
            }
            .padding(.horizontal, spacing.s16)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HomeHabitRowView(
                        row: row,
                        onPrimaryAction: { onPrimaryAction(row) },
                        onSecondaryAction: { onSecondaryAction(row) },
                        onRowAction: { onRowAction(row) },
                        onOpenDetail: {
                            onOpenHabit?(row)
                        },
                        onLastCellAction: { onLastCellAction(row) }
                    )

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, spacing.s16)
                    }
                }

                if let onAddHabit {
                    if rows.isEmpty == false {
                        Divider()
                            .padding(.leading, spacing.s16)
                    }

                    Button {
                        onAddHabit()
                    } label: {
                        HStack(spacing: spacing.s8) {
                            Image(systemName: "plus.circle.fill")
                                .lifeboardFont(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.lifeboard.accentPrimary)

                            Text("Add habit")
                                .font(.lifeboard(.bodyStrong))
                                .foregroundStyle(Color.lifeboard.textPrimary)

                            Spacer(minLength: spacing.s8)

                            Image(systemName: "chevron.right")
                                .lifeboardFont(.eyebrow)
                                .foregroundStyle(Color.lifeboard.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, spacing.s16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .background(Color.lifeboard.surfaceSecondary.opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 0, style: .continuous)
                            .stroke(Color.lifeboard.strokeHairline.opacity(0.28), lineWidth: 1)
                    )
                    .accessibilityIdentifier(HabitBoardAccessibilityID.homeAddHabit)
                    .accessibilityLabel("Add habit")
                }
            }
        }
        .padding(.vertical, spacing.s12)
        .background(HabitBoardSurfaceBackground(cornerRadius: 0))
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
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
            dayCount: min(5, rows.first?.boardCellsCompact.count ?? 0)
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
    @Environment(\.habitViewModelFactory) private var habitViewModelFactory
    enum PresentationStyle { case modal, pushed }

    @ObservedObject var viewModel: HabitBoardViewModel
    let presentationStyle: PresentationStyle
    let onManageHabits: () -> Void
    @State private var selectedHabitRow: HabitLibraryRow?
    @State private var amountEntry: HabitAmountEntryContext?
    @State private var measuredBoardWidth: CGFloat = 0
    @State private var mode: HabitBoardMode = .week
    @State private var grouping: HabitBoardGrouping = .timeOfDay
    @Namespace private var modeNamespace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeboardTokens) private var tokens

    var spacing: SemanticSpacingTokens { tokens.spacing }
    private var layoutMetrics: HabitBoardLayoutMetrics {
        HabitBoardLayoutMetrics.forContainerWidth(resolvedBoardWidth, dynamicTypeSize: dynamicTypeSize)
    }
    private var resolvedBoardWidth: CGFloat {
        measuredBoardWidth > 1 ? measuredBoardWidth : 320
    }

    init(
        viewModel: HabitBoardViewModel,
        presentationStyle: PresentationStyle = .modal,
        onManageHabits: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.presentationStyle = presentationStyle
        self.onManageHabits = onManageHabits
    }

    @ViewBuilder
    var body: some View {
        if presentationStyle == .modal {
            NavigationStack { content.toolbar { closeToolbar } }
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.s16) {
                lensBar
                    .enhancedStaggeredAppearance(index: 0)

                if viewModel.boardRows.isEmpty == false {
                    HabitBoardScoreHeader(days: viewModel.aggregateDays)
                        .enhancedStaggeredAppearance(index: 1)
                }

                // A failed log on a board that has rows used to say nothing:
                // the error state only replaced an empty board.
                if viewModel.errorMessage != nil, viewModel.boardRows.isEmpty == false {
                    HabitBoardInlineError(
                        onRetry: { viewModel.clearError(); viewModel.refresh() },
                        onDismiss: { viewModel.clearError() }
                    )
                }

                modeContent
                    .enhancedStaggeredAppearance(index: 2)
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s24)
        }
        .background(Color.lifeboard.bgCanvas)
        .accessibilityIdentifier(HabitBoardAccessibilityID.view)
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: layoutMetrics) {
            viewModel.configureViewport(columnCount: layoutMetrics.visibleColumns, historySpan: layoutMetrics.historySpan)
            viewModel.loadIfNeeded()
        }
        .onChange(of: mode) { _, newValue in
            if newValue == .graph { viewModel.loadGraphIfNeeded() }
        }
        .sheet(item: $selectedHabitRow) { row in
            HabitDetailScreen(
                viewModel: habitViewModelFactory.makeHabitDetailViewModel(row: row),
                onMutation: { viewModel.refresh() }
            )
        }
        .sheet(item: $amountEntry) { context in
            HabitAmountEntrySheet(context: context) { value in
                await viewModel.logAmount(habitID: context.habitID, change: .set(value))
            }
        }
    }

    /// Day / Week / Graph lens picker plus the Group-by menu — the parity control
    /// row. Regular-glass chrome per DESIGN.md; group-by only applies to Day/Graph.
    private var lensBar: some View {
        HStack(spacing: spacing.s12) {
            HabitBoardModeSelector(mode: $mode, namespace: modeNamespace, reduceMotion: reduceMotion)
                .frame(maxWidth: .infinity, alignment: .leading)

            if mode != .week {
                HabitBoardGroupMenu(grouping: $grouping)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .lifeBoardMotion(.selection, value: mode)
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .week:
            boardSurface
        case .day:
            HabitBoardDayLens(
                sections: groupedSections(from: viewModel.boardRows),
                onSelect: selectHabit(_:),
                logAction: { habitID in
                    guard viewModel.canLogFromBoard else { return nil }
                    return HabitBoardLogAction(
                        title: viewModel.todayAction(for: habitID) == .abstained ? String(localized: "Stayed clean") : String(localized: "Done"),
                        isLogging: viewModel.loggingHabitIDs.contains(habitID),
                        perform: {
                            Task {
                                // Feedback follows the save, never the tap.
                                if await viewModel.logToday(habitID: habitID) {
                                    Haptic.commit.play()
                                } else {
                                    Haptic.fail.play()
                                }
                            }
                        },
                        amount: viewModel.amountTarget(for: habitID).flatMap { target in
                            HabitAmountRule.target(for: target).map { goal in
                                HabitBoardAmount(
                                    value: viewModel.todayAmounts[habitID] ?? 0,
                                    target: goal,
                                    step: HabitAmountRule.step(for: target),
                                    unit: {
                                        if case let .quantitative(_, unit) = target { return unit }
                                        return ""
                                    }(),
                                    isTimed: { if case .timed = target { return true }; return false }(),
                                    onChange: { change in await viewModel.logAmount(habitID: habitID, change: change) }
                                )
                            }
                        },
                        enterAmount: viewModel.amountTarget(for: habitID).map { target in
                            {
                                amountEntry = HabitAmountEntryContext(
                                    habitID: habitID,
                                    title: viewModel.libraryRow(for: habitID)?.title ?? String(localized: "Habit"),
                                    target: target,
                                    current: viewModel.todayAmounts[habitID] ?? 0
                                )
                            }
                        },
                        reset: { Task { await viewModel.resetToday(habitID: habitID) } }
                    )
                }
            )
        case .graph:
            HabitBoardGraphLens(
                sections: groupedSections(from: viewModel.graphRows),
                isLoading: viewModel.graphRows.isEmpty && viewModel.boardRows.isEmpty == false,
                onSelect: selectHabit(_:)
            )
        }
    }

    private func selectHabit(_ habitID: UUID) {
        if let libraryRow = viewModel.row(for: habitID) {
            PerformanceTrace.event("HabitDetailTapReceived")
            selectedHabitRow = libraryRow
        }
    }

    /// Partitions presentation rows into the active group-by buckets, preserving
    /// the view model's streak ordering inside each bucket.
    private func groupedSections(from rows: [HabitBoardRowPresentation]) -> [HabitBoardGroupedSection] {
        HabitBoardGroupedSection.build(
            rows: rows,
            grouping: grouping,
            libraryRow: { viewModel.libraryRow(for: $0) }
        )
    }

    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var boardSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            boardHeader

            Rectangle()
                .fill(Color.lifeboard.strokeHairline.opacity(0.16))
                .frame(height: 1)

            if viewModel.isLoading && viewModel.boardRows.isEmpty {
                boardLoadingState
            } else if let errorMessage = viewModel.errorMessage, viewModel.boardRows.isEmpty {
                boardErrorState(message: errorMessage)
            } else if viewModel.boardRows.isEmpty {
                boardEmptyState
            } else {
                boardMatrix

                Rectangle()
                    .fill(Color.lifeboard.strokeHairline.opacity(0.16))
                    .frame(height: 1)

                HabitBoardLegend()
                    .padding(.horizontal, spacing.s16)
                    .padding(.vertical, spacing.s12)
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
            withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard.textPrimary)
                .frame(width: 44, height: 44)
                .background(Color.lifeboard.surfacePrimary.opacity(0.98))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.lifeboard.strokeHairline.opacity(0.55), lineWidth: 1))
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
                accessibilityLabel: String(localized: "Previous \(viewModel.viewportColumnCount) days")
            ) {
                viewModel.moveWindow(byDays: -viewModel.viewportColumnCount)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rangeTitle)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .accessibilityIdentifier(HabitBoardAccessibilityID.rangeTitle)

                Text("\(viewModel.viewportColumnCount) days")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .accessibilityIdentifier(HabitBoardAccessibilityID.rangeSubtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            boardPagerButton(
                systemName: "chevron.right",
                accessibilityIdentifier: HabitBoardAccessibilityID.nextWindow,
                accessibilityLabel: String(localized: "Next \(viewModel.viewportColumnCount) days")
            ) {
                viewModel.moveWindow(byDays: viewModel.viewportColumnCount)
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s12)
    }
}

extension HabitBoardScreen {
    private var boardMatrix: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HabitBoardPinnedColumnHeader(layoutMetrics: layoutMetrics)

                Divider()
                    .overlay(Color.lifeboard.strokeHairline.opacity(0.12))

                LazyVStack(spacing: 0) {
                    ForEach(viewModel.boardRows) { row in
                        HabitBoardPinnedRowView(
                            row: row,
                            layoutMetrics: layoutMetrics,
                            onSelect: {
                                if let libraryRow = viewModel.row(for: row.habitID) {
                                    PerformanceTrace.event("HabitDetailTapReceived")
                                    selectedHabitRow = libraryRow
                                }
                            }
                        )

                        Divider()
                            .overlay(Color.lifeboard.strokeHairline.opacity(0.1))
                    }
                }
            }
            .background(Color.lifeboard.surfaceSecondary.opacity(0.16))
            .frame(width: layoutMetrics.pinnedRailWidth, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HabitBoardDayHeaderRow(days: viewModel.aggregateDays, layoutMetrics: layoutMetrics)

                    Divider()
                        .overlay(Color.lifeboard.strokeHairline.opacity(0.12))

                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.boardRows) { row in
                            HabitBoardMatrixRowView(
                                row: row,
                                layoutMetrics: layoutMetrics
                            )

                            Divider()
                                .overlay(Color.lifeboard.strokeHairline.opacity(0.1))
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
            return String(localized: "Last \(viewModel.viewportColumnCount) days")
        }
        return "\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct HabitBoardPinnedRowView: View {
    let row: HabitBoardRowPresentation
    let layoutMetrics: HabitBoardLayoutMetrics
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: layoutMetrics.iconToTextSpacing) {
                Image(systemName: row.iconSymbolName)
                    .lifeboardFont(.buttonSmall)
                    .foregroundStyle(HabitEverydayPalette.familyPreview(row.colorFamily))
                    .frame(width: layoutMetrics.iconSlotWidth, height: layoutMetrics.rowHeight, alignment: .center)

                Text(row.title)
                    .font(.lifeboard(.caption1).weight(.medium))
                    .foregroundStyle(Color.lifeboard.textPrimary)
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
                    .fill(Color.lifeboard.strokeHairline.opacity(0.16))
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Button(action: onSelect) {
                Text(row.title)
            }
            .accessibilityIdentifier(HabitBoardAccessibilityID.row(row.habitID))
            .accessibilityLabel(row.title)
            .accessibilityHint("Opens habit")
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
        case .done(let depth):
            return depth > 1 ? String(localized: "Done, streak level \(min(depth, 8)) of 8") : String(localized: "Done")
        case .missed:
            return String(localized: "Not done")
        case .todayPending:
            return String(localized: "Due today")
        case .future:
            return String(localized: "Future day")
        case .bridge(_, let source):
            return source == .skipped ? String(localized: "Skipped") : String(localized: "Not scheduled")
        }
    }
}

private struct HabitBoardPinnedColumnHeader: View {
    let layoutMetrics: HabitBoardLayoutMetrics

    var body: some View {
        ZStack {
            Text("Habits")
                .font(.lifeboard(.support).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: layoutMetrics.leadingRailWidth, height: layoutMetrics.headerHeight, alignment: .center)
        .padding(.trailing, layoutMetrics.railTrailingPadding)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.lifeboard.strokeHairline.opacity(0.16))
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
        // The formatter already returns the locale's own casing. Forcing upper
        // case was hierarchy-by-shouting, and in several locales it is simply
        // wrong.
        if layoutMetrics.usesCompressedWeekday {
            return String(symbol.prefix(1))
        }
        return layoutMetrics.showsFullWeekday ? symbol : String(symbol.prefix(3))
    }

    var body: some View {
        VStack(spacing: 3) {
            monthMarker
                .frame(maxWidth: .infinity, alignment: .center)

            Text(day.date.formatted(.dateTime.day()))
                .font(.lifeboard(.title3).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(day.isToday ? HabitEverydayPalette.todayStroke(colorScheme: colorScheme) : Color.lifeboard.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(todayBackground)

            Text(weekdayLabel)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(day.isToday ? Color.lifeboard.textPrimary : Color.lifeboard.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: layoutMetrics.dayColumnWidth, height: layoutMetrics.headerHeight, alignment: .bottom)
        .padding(.vertical, 12)
        .background(headerBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(HabitBoardAccessibilityID.dayHeader(day.date))
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(day.isToday ? "Today" : "")
    }

    @ViewBuilder
    private var todayBackground: some View {
        if day.isToday {
            RoundedRectangle(cornerRadius: Radius.compact, style: .continuous)
                .fill(HabitEverydayPalette.todayHalo(colorScheme: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.compact, style: .continuous)
                        .stroke(HabitEverydayPalette.todayStroke(colorScheme: colorScheme), lineWidth: 1.4)
                )
                .padding(.horizontal, 1)
        } else {
            Color.clear
        }
    }

    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: layoutMetrics.cellCornerRadius, style: .continuous)
            .fill(day.isToday ? Color.lifeboard.surfaceSecondary.opacity(0.42) : (Calendar.current.isDateInWeekend(day.date) ? Color.lifeboard.surfaceSecondary.opacity(0.3) : Color.clear))
    }

    @ViewBuilder
    private var monthMarker: some View {
        if showsMonthMarker {
            Text(day.date.formatted(.dateTime.month(.abbreviated)))
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
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
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(HabitEverydayPalette.familyPreview(family))
                    .frame(width: 28, height: 28)
                    .background(Color.lifeboard.surfacePrimary.opacity(0.94))
                    .overlay(
                        Circle()
                            .stroke(HabitEverydayPalette.familyPreview(family), lineWidth: 2)
                    )
                    .clipShape(Circle())
            } else {
                Text(value)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(minWidth: 28, alignment: .leading)
            }
        }
    }
}

/// Streak-strength and cell-state legend shown beneath the full board so the
/// heatmap reads without instruction (design doc §12.2 / §16.5).
private struct HabitBoardLegend: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                Text("Streak")
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)

                Spacer(minLength: spacing.s8)

                HStack(spacing: 2) {
                    ForEach([2, 3, 4, 6, 8], id: \.self) { depth in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(HabitEverydayPalette.depthColor(for: .green, depth: depth, colorScheme: colorScheme))
                            .frame(width: 15, height: 12)
                    }
                }

                Text("Short → long")
                    .font(.lifeboard(.caption2))
                    .foregroundStyle(Color.lifeboard.textSecondary) // tertiary measured 4.4:1 in dark at caption size
                    .lineLimit(1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.s12) {
                    legendSwatch(fill: HabitEverydayPalette.paperFill(colorScheme: colorScheme),
                                 ring: HabitEverydayPalette.todayStroke(colorScheme: colorScheme),
                                 label: String(localized: "Today"))
                    legendSwatch(fill: HabitEverydayPalette.missedFill(colorScheme: colorScheme),
                                 ring: nil,
                                 label: String(localized: "Not done"))
                    legendSwatch(fill: HabitEverydayPalette.bridgeTint(for: .gray, depth: nil, colorScheme: colorScheme),
                                 ring: nil,
                                 label: String(localized: "Skipped"))
                    legendSwatch(fill: HabitEverydayPalette.futureFill(colorScheme: colorScheme),
                                 ring: nil,
                                 label: String(localized: "Future"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend. Darker means a longer streak.")
    }

    private func legendSwatch(fill: Color, ring: Color?, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(fill)
                .frame(width: 14, height: 14)
                .overlay {
                    if let ring {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(ring, lineWidth: 1.4)
                    } else {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.lifeboard.strokeHairline.opacity(0.4), lineWidth: 1)
                    }
                }
            Text(label)
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .lineLimit(1)
        }
    }
}

struct HabitBoardFlatSurfaceBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.lifeboard.surfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct HabitBoardSurfaceBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.lifeboard.surfacePrimary.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.58), lineWidth: 1)
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
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct HabitBoardCellView: View {
    let cell: HabitBoardCell
    let family: HabitColorFamily
    let mode: HabitBoardStripMode
    let cellSizeOverride: CGFloat?
    let cellWidthOverride: CGFloat?
    let cellHeightOverride: CGFloat?
    let bridgeDepthHint: Int?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        // Check-ins settle in: the family color deepens rather than snapping.
        .lifeBoardMotion(.localState, value: cell.state)
    }

    @ViewBuilder
    private var differentiateOverlay: some View {
        switch cell.state {
        case .missed:
            Rectangle()
                .fill(Color.lifeboard.textSecondary.opacity(0.22))
                .frame(width: resolvedCellWidth * 0.45, height: 1)
        case .bridge:
            Circle()
                .fill(Color.lifeboard.textSecondary)
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
        if cell.isToday, mode != .homeList {
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
            if mode.isMatrixLike || mode == .homeList {
                EmptyView()
            } else {
                Canvas { context, size in
                    for index in 0..<6 {
                        var path = Path()
                        let x = CGFloat((index * 7) % 11) / 11 * size.width
                        let y = CGFloat((index * 11) % 13) / 13 * size.height
                        path.addEllipse(in: CGRect(x: x, y: y, width: 0.6, height: 0.6))
                        context.fill(path, with: .color(ClayColorTokens.whiteStroke.opacity(0.12)))
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
        return Color(uiColor: UIColor(lifeboardHex: hex))
    }

    static func familyPreview(_ family: HabitColorFamily) -> Color {
        Color(uiColor: UIColor(lifeboardHex: lightRamps[family]?[4] ?? family.canonicalHex))
    }

    static func bridgeTint(for family: HabitColorFamily, depth: Int?, colorScheme: ColorScheme) -> Color {
        guard let depth else {
            let ramp = colorScheme == .dark ? darkRamps : lightRamps
            return Color(uiColor: UIColor(lifeboardHex: ramp[family]?[2] ?? family.canonicalHex))
        }

        let bridgeDepth = max(1, min(depth - 1, 7))
        return depthColor(for: family, depth: bridgeDepth, colorScheme: colorScheme)
    }

    static func gridStroke(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? ClayColorTokens.whiteStroke.opacity(0.07)
            : ClayColorTokens.elevationShadow.opacity(0.4)
    }

    // The neutral cells were cool slate hexes from an older palette and sat
    // grey-blue on the warm paper. They resolve from the surface roles now, so
    // they follow the appearance and the daypart like every other surface.
    // `colorScheme` stays in the signatures for the callers that pass it.

    static func paperFill(colorScheme _: ColorScheme) -> Color {
        Color.lifeboard(.surfacePrimary)
    }

    static func missedFill(colorScheme _: ColorScheme) -> Color {
        Color.lifeboard(.surfaceSecondary)
    }

    static func futureFill(colorScheme _: ColorScheme) -> Color {
        Color.lifeboard(.bgCanvasSecondary)
    }

    /// Today is marked with the focus ring — the app's "this one" color —
    /// rather than Eva's violet; green stays reserved for completion.
    static func todayStroke(colorScheme _: ColorScheme) -> Color {
        Color(SemanticColorTokens.foundationFocusRing)
    }

    static func todayHalo(colorScheme: ColorScheme) -> Color {
        todayStroke(colorScheme: colorScheme).opacity(colorScheme == .dark ? 0.28 : 0.18)
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

// MARK: - Lens bar controls

/// Segmented Day / Week / Graph selector with a matched-geometry selection pill.
private struct HabitBoardModeSelector: View {
    @Binding var mode: HabitBoardMode
    let namespace: Namespace.ID
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HabitBoardMode.allCases) { candidate in
                let isSelected = candidate == mode
                Button {
                    guard candidate != mode else { return }
                    HabitBoardHaptics.selection()
                    mode = candidate
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: candidate.symbolName)
                            .font(.lifeboard(.caption1).weight(.semibold))
                        Text(candidate.title)
                            .font(.lifeboard(.caption1).weight(.semibold))
                    }
                    .foregroundStyle(isSelected ? Color.lifeboard.textPrimary : Color.lifeboard.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            Capsule(style: .continuous)
                                .fill(Color.lifeboard.surfacePrimary)
                                .overlay(Capsule(style: .continuous).stroke(Color.lifeboard.strokeHairline.opacity(0.55), lineWidth: 1))
                                .matchedGeometryEffect(id: "habitModePill", in: namespace)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(candidate.title)
                .accessibilityValue(isSelected ? "Selected" : "")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("habitBoard.lens.\(candidate.rawValue)")
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(Color.lifeboard.surfaceSecondary.opacity(0.35))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View")
    }
}

/// Group-by menu (regular-glass chrome) for the Day and Graph lenses.
private struct HabitBoardGroupMenu: View {
    @Binding var grouping: HabitBoardGrouping

    var body: some View {
        Menu {
            Picker("Group by", selection: $grouping) {
                ForEach(HabitBoardGrouping.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.lifeboard(.caption1).weight(.semibold))
                Text(grouping.title)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.lifeboard.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.lifeboard.surfacePrimary)
                    .overlay(Capsule(style: .continuous).stroke(Color.lifeboard.strokeHairline.opacity(0.55), lineWidth: 1))
            )
        }
        .accessibilityLabel("Group habits by")
        .accessibilityValue(grouping.title)
    }
}

// MARK: - Rolling score header

/// A calm "this week" completion ring built strictly from recorded aggregate
/// days — honest empty state when nothing is scheduled, never a faked score.
private struct HabitBoardScoreHeader: View {
    let days: [HabitBoardAggregateDay]
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    private var completed: Int { days.suffix(7).reduce(0) { $0 + $1.completedCount } }
    private var scheduled: Int { days.suffix(7).reduce(0) { $0 + $1.habitCount } }
    private var fraction: Double {
        guard scheduled > 0 else { return 0 }
        return min(1, Double(completed) / Double(scheduled))
    }
    private var hasSignal: Bool { scheduled > 0 }

    var body: some View {
        HStack(spacing: spacing.s16) {
            ZStack {
                Circle()
                    .stroke(Color.lifeboard.surfaceSecondary.opacity(0.5), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: hasSignal ? fraction : 0)
                    .stroke(
                        hasSignal ? ClayColorTokens.role(.routine).deep : Color.lifeboard.textTertiary,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(hasSignal ? "\(Int((fraction * 100).rounded()))%" : "–")
                    .font(.lifeboard(.caption1).weight(.bold))
                    .foregroundStyle(Color.lifeboard.textPrimary)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("This week")
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text(hasSignal ? "\(completed) of \(scheduled) done" : "Nothing scheduled yet")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(spacing.s16)
        .background(HabitBoardFlatSurfaceBackground(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            hasSignal
                ? String(localized: "This week, \(completed) of \(scheduled) done, \(Int((fraction * 100).rounded())) percent.")
                : String(localized: "This week. Nothing scheduled yet.")
        )
    }
}

/// Says a log did not save, on a board that still has rows to show.
private struct HabitBoardInlineError: View {
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Color.lifeboard.statusDanger)
                .accessibilityHidden(true)
            Text("Couldn’t save. Try again.")
                .font(.lifeboard(.support))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Try again", action: onRetry)
                .font(.lifeboard(.buttonSmall))
                .minimumHitTarget()
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .minimumHitTarget()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("habitBoard.inlineError")
    }
}

// MARK: - Day lens

/// Grouped "today" cards — quick status for every habit, tap to open detail.
/// The one logging action a Day card offers for today.
private struct HabitBoardLogAction {
    let title: String
    let isLogging: Bool
    let perform: () -> Void
    /// Present for habits with an amount target: they log on a ring instead of
    /// a single check.
    var amount: HabitBoardAmount?
    /// Opens "Enter amount" for amount habits.
    var enterAmount: (() -> Void)? = nil
    /// Takes today back to not done.
    var reset: (() -> Void)? = nil
}

private struct HabitBoardAmount {
    let value: Double
    let target: Double
    let step: Double
    let unit: String
    let isTimed: Bool
    let onChange: (HabitAmountChange) async -> Bool
}

private struct HabitBoardDayLens: View {
    @State private var firstLightTrigger = 0
    let sections: [HabitBoardGroupedSection]
    let onSelect: (UUID) -> Void
    var logAction: (UUID) -> HabitBoardLogAction? = { _ in nil }
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: spacing.s8) {
                    HabitBoardSectionHeader(section: section)
                    HabitBoardLensRows(isGrid: layoutClass.isPad, rowSpacing: spacing.s8) {
                        ForEach(section.rows) { row in
                            HabitBoardDayCard(
                                row: row,
                                onSelect: { onSelect(row.habitID) },
                                logAction: logAction(row.habitID)
                            )
                        }
                    }
                }
            }
        }
        .lifeboardFirstLight(trigger: firstLightTrigger, tint: Color(SemanticColorTokens.foundationSunAccent))
        .onReceive(NotificationCenter.default.publisher(for: .lifeboardFirstLightFired)) { notification in
            guard FirstLightCommitment.source(of: notification) == .habit else { return }
            firstLightTrigger &+= 1
        }
    }
}

/// Lays a lens's cards out as one column on phone and as an adaptive grid on
/// iPad/Mac. A single full-width column on a 1000pt canvas strands the status
/// pill a screen-width away from the habit name; ~340pt tiles keep each card's
/// name and status within one glance. Plain containers only — no gestures here,
/// so scrolling behaves exactly as it does in the single column.
struct HabitBoardLensRows<Content: View>: View {
    let isGrid: Bool
    let rowSpacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        if isGrid {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)],
                alignment: .leading,
                spacing: 16
            ) {
                content
            }
        } else {
            VStack(alignment: .leading, spacing: rowSpacing) {
                content
            }
        }
    }
}

struct HabitBoardSectionHeader: View {
    let section: HabitBoardGroupedSection

    var body: some View {
        if section.symbolName != nil || section.title != "All habits" {
            // The shared header, rather than a caption-sized restyle with its
            // own count capsule. `DESIGN.md`: one type size and one spacing for
            // section headers across the product.
            SectionHeader(section.title, symbol: section.symbolName, count: section.rows.count)
                .padding(.top, 2)
        }
    }
}

private struct HabitBoardDayCard: View {
    let row: HabitBoardRowPresentation
    let onSelect: () -> Void
    var logAction: HabitBoardLogAction? = nil
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }
    private var accent: Color { HabitEverydayPalette.familyPreview(row.colorFamily) }
    private var status: HabitTodayStatus { HabitTodayStatus.status(for: row.cells.last?.state) }

    var body: some View {
        HStack(spacing: spacing.s8) {
            openButton
            // Logging sits beside the card, not inside it: one tap checks the
            // habit off where it is listed, and the card itself still opens detail.
            if let logAction, let amount = logAction.amount {
                // Amount habits stay loggable after the target: extra effort is
                // shown as a second lap, not refused.
                HabitProgressRing(
                    title: row.title,
                    value: amount.value,
                    target: amount.target,
                    step: amount.step,
                    unit: amount.unit,
                    isTimed: amount.isTimed,
                    size: .board,
                    onChange: amount.onChange
                )
                .accessibilityIdentifier("habitBoard.day.ring.\(row.habitID.uuidString)")
            } else if status == .pending, let logAction {
                Button(action: logAction.perform) {
                    Group {
                        if logAction.isLogging {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(.lifeboard(.body).weight(.bold))
                        }
                    }
                    .foregroundStyle(accent)
                    .frame(width: 48, height: 48)
                    .background(Circle().strokeBorder(accent.opacity(0.55), lineWidth: 2))
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(logAction.isLogging)
                .accessibilityLabel("\(logAction.title): \(row.title)")
                .accessibilityIdentifier("habitBoard.day.log.\(row.habitID.uuidString)")
            }
        }
    }

    private var openButton: some View {
        Button(action: onSelect) {
            HStack(spacing: spacing.s12) {
                Image(systemName: row.iconSymbolName)
                    .font(.lifeboard(.body).weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.compact, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.lifeboard(.body).weight(.medium))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(1)
                    if row.currentStreak > 0 {
                        Label("\(row.currentStreak)-day streak", systemImage: "flame.fill")
                            .font(.lifeboard(.caption2))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .labelStyle(.titleAndIcon)
                    }
                }

                Spacer(minLength: spacing.s8)

                Text(status.title)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(status.foreground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(status.background))
            }
            .padding(spacing.s12)
            .background(HabitBoardFlatSurfaceBackground(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        // Secondary actions live on the label, never on the ring: the ring's
        // hold is the commitment gesture and a menu would fight it.
        .contextMenu {
            Button("Open habit", systemImage: "arrow.up.right.square", action: onSelect)
            if let enterAmount = logAction?.enterAmount {
                Button("Enter amount…", systemImage: "number", action: enterAmount)
            }
            if status == .done, let reset = logAction?.reset {
                Button("Mark not done", systemImage: "arrow.uturn.backward", action: reset)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title). \(status.title)." + (row.currentStreak > 0 ? String(localized: " \(row.currentStreak)-day streak.") : ""))
        .accessibilityHint("Opens habit")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("habitBoard.day.card.\(row.habitID.uuidString)")
    }
}

/// Honest today-status taxonomy derived from the last board cell.
private enum HabitTodayStatus {
    case done, pending, missed, skipped, notDue, upcoming

    var title: String {
        switch self {
        case .done: return String(localized: "Done")
        case .pending: return String(localized: "To do")
        case .missed: return String(localized: "Not done")
        case .skipped: return String(localized: "Skipped")
        case .notDue: return String(localized: "Not due")
        case .upcoming: return String(localized: "Upcoming")
        }
    }

    @MainActor var foreground: Color {
        switch self {
        case .done: return ClayColorTokens.role(.routine).deep
        case .pending: return Color.lifeboard.textPrimary
        case .missed: return Color.lifeboard.statusWarning
        case .skipped, .notDue, .upcoming: return Color.lifeboard.textTertiary
        }
    }

    @MainActor var background: Color {
        switch self {
        case .done: return ClayColorTokens.role(.routine).softSurface
        case .pending: return Color.lifeboard.surfaceSecondary.opacity(0.5)
        case .missed: return Color.lifeboard.statusWarning.opacity(0.14)
        case .skipped, .notDue, .upcoming: return Color.lifeboard.surfaceSecondary.opacity(0.35)
        }
    }

    static func status(for state: HabitBoardCellState?) -> HabitTodayStatus {
        switch state {
        case .done: return .done
        case .todayPending: return .pending
        case .missed: return .missed
        case .bridge(_, .skipped): return .skipped
        case .bridge(_, .notScheduled): return .notDue
        case .future: return .upcoming
        case .none: return .pending
        }
    }
}

// MARK: - Haptics

private enum HabitBoardHaptics {
    @MainActor
    static func selection() {
        #if os(iOS)
        Haptic.pick.play()
        #endif
    }
}
