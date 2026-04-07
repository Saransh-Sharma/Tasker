import SwiftUI
import UIKit

private enum HabitBoardLayout {
    static let railWidth: CGFloat = 106
    static let rowSpacing: CGFloat = 10

    static func contentWidth(dayCount: Int) -> CGFloat {
        (railWidth * 2) + (rowSpacing * 2) + (CGFloat(dayCount) * HabitBoardStripMode.board.columnWidth)
    }
}

enum HabitBoardStripMode {
    case compact
    case expanded
    case board

    var cellSize: CGFloat {
        switch self {
        case .compact: return 14
        case .expanded: return 15
        case .board: return 16
        }
    }

    var spacing: CGFloat {
        switch self {
        case .compact: return 0
        case .expanded: return 0
        case .board: return 0
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 2
        case .expanded: return 1
        case .board: return 1
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

    var body: some View {
        HStack(spacing: mode.spacing) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                HabitBoardCellView(
                    cell: cell,
                    family: family,
                    mode: mode
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

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.tasker.strokeHairline.opacity(0.55), lineWidth: 1)
                        )
                        .buttonStyle(.plain)
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

            VStack(spacing: spacing.s8) {
                ForEach(rows) { row in
                    HomeHabitRowView(
                        row: row,
                        onPrimaryAction: { onPrimaryAction(row) },
                        onSecondaryAction: { onSecondaryAction(row) }
                    )
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var preferredDayCount: Int {
        layoutClass == .padRegular || layoutClass == .padExpanded ? 28 : 14
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    boardToolbarCard
                        .enhancedStaggeredAppearance(index: 0)

                    if viewModel.boardRows.isEmpty, !viewModel.isLoading {
                        ContentUnavailableView(
                            "No habits yet",
                            systemImage: "square.grid.3x3.topleft.filled",
                            description: Text("Create a habit to start building a board.")
                        )
                        .padding(.top, spacing.s16)
                    } else {
                        boardCard
                            .enhancedStaggeredAppearance(index: 1)
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s24)
            }
            .background(Color.tasker.bgCanvas)
            .navigationTitle("Habit Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                viewModel.setVisibleDayCount(preferredDayCount)
                viewModel.loadIfNeeded()
            }
            .onChange(of: preferredDayCount) { _, newValue in
                viewModel.setVisibleDayCount(newValue)
            }
            .sheet(item: $selectedHabitRow) { row in
                HabitDetailSheetView(
                    viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                    onMutation: { viewModel.refresh() }
                )
            }
        }
    }

    private var boardToolbarCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(spacing: 10) {
                boardPagerButton(systemName: "chevron.left") {
                    viewModel.moveWindow(byDays: -viewModel.visibleDayCount)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Habit board")
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Text(rangeTitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    boardModeButton(title: "Streaks", mode: .streaks)
                    boardModeButton(title: "Counts", mode: .counts)
                }

                boardPagerButton(systemName: "chevron.right") {
                    viewModel.moveWindow(byDays: viewModel.visibleDayCount)
                }
            }

            HStack(spacing: 10) {
                Text("Visible days")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)

                Slider(
                    value: Binding(
                        get: { Double(viewModel.visibleDayCount) },
                        set: { viewModel.setVisibleDayCount(Int($0.rounded())) }
                    ),
                    in: 14...28,
                    step: 1
                )
                .tint(Color.tasker.textSecondary.opacity(0.72))

                Text("\(viewModel.visibleDayCount)")
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .frame(minWidth: 24, alignment: .trailing)
            }
        }
        .padding(14)
        .background(HabitBoardSurfaceBackground(cornerRadius: 20))
    }

    private func boardPagerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.72))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.tasker.strokeHairline.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func boardModeButton(title: String, mode: HabitBoardSummaryMode) -> some View {
        Button(title) {
            withAnimation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.quick) {
                viewModel.summaryMode = mode
            }
        }
        .font(.tasker(.caption1).weight(viewModel.summaryMode == mode ? .semibold : .regular))
        .foregroundStyle(viewModel.summaryMode == mode ? Color.tasker.textPrimary : Color.tasker.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(viewModel.summaryMode == mode ? Color.white.opacity(0.84) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(viewModel.summaryMode == mode ? Color.tasker.strokeHairline.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .buttonStyle(.plain)
    }

    private var boardCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    boardHeader

                    VStack(spacing: 0) {
                        ForEach(viewModel.boardRows) { row in
                            Button {
                                if let libraryRow = viewModel.row(for: row.habitID) {
                                    selectedHabitRow = libraryRow
                                }
                            } label: {
                                HabitBoardGridRowView(
                                    row: row,
                                    summaryMode: viewModel.summaryMode
                                )
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .overlay(Color.tasker.strokeHairline.opacity(0.42))
                        }

                        HabitBoardTotalsFooterView(days: viewModel.aggregateDays)
                    }
                }
                .frame(
                    minWidth: HabitBoardLayout.contentWidth(dayCount: viewModel.aggregateDays.count),
                    alignment: .leading
                )
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .padding(14)
        .background(HabitBoardSurfaceBackground(cornerRadius: 24))
    }

    private var boardHeader: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Text("HABITS")
                .font(.tasker(.caption2).weight(.semibold))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: HabitBoardLayout.railWidth, alignment: .leading)

            HStack(spacing: HabitBoardStripMode.board.spacing) {
                ForEach(viewModel.aggregateDays, id: \.date) { day in
                    HabitBoardHeaderDayCell(day: day)
                }
            }

            summaryHeader
                .frame(width: HabitBoardLayout.railWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private var summaryHeader: some View {
        switch viewModel.summaryMode {
        case .streaks:
            HStack(spacing: 6) {
                Text("current")
                Text("longest")
                Text("total")
            }
            .font(.tasker(.caption2))
            .foregroundStyle(Color.tasker.textSecondary)
        case .counts:
            HStack(spacing: 6) {
                Text("week")
                Text("month")
                Text("year")
            }
            .font(.tasker(.caption2))
            .foregroundStyle(Color.tasker.textSecondary)
        }
    }

    private var rangeTitle: String {
        guard let start = viewModel.aggregateDays.first?.date,
              let end = viewModel.aggregateDays.last?.date else {
            return "Last \(viewModel.visibleDayCount) days"
        }
        return "\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct HabitBoardGridRowView: View {
    let row: HabitBoardRowPresentation
    let summaryMode: HabitBoardSummaryMode

    var body: some View {
        HStack(alignment: .center, spacing: HabitBoardLayout.rowSpacing) {
            HStack(spacing: 6) {
                Image(systemName: row.iconSymbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(HabitEverydayPalette.familyPreview(row.colorFamily))
                    .frame(width: 14, alignment: .center)

                Text(row.title)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: HabitBoardLayout.railWidth, alignment: .leading)

            HabitBoardStripView(
                cells: row.cells,
                family: row.colorFamily,
                mode: .board
            )

            HabitBoardSummaryRailView(row: row, summaryMode: summaryMode)
                .frame(width: HabitBoardLayout.railWidth, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}

struct HabitBoardSummaryRailView: View {
    let row: HabitBoardRowPresentation
    let summaryMode: HabitBoardSummaryMode

    var body: some View {
        HStack(spacing: 6) {
            switch summaryMode {
            case .streaks:
                HabitStatBadgeView(
                    value: "\(row.metrics.currentStreak)",
                    family: row.colorFamily,
                    highlighted: row.metrics.currentStreak > 0 && row.metrics.currentStreak == row.metrics.bestStreak
                )
                HabitStatBadgeView(
                    value: "\(row.metrics.bestStreak)",
                    family: row.colorFamily,
                    highlighted: row.metrics.bestStreak > 0 && row.metrics.currentStreak == row.metrics.bestStreak
                )
                plainMetric("\(row.metrics.totalCount)")
            case .counts:
                plainMetric("\(row.metrics.weekCount)")
                plainMetric("\(row.metrics.monthCount)")
                plainMetric("\(row.metrics.yearCount)")
            }
        }
    }

    private func plainMetric(_ value: String) -> some View {
        Text(value)
            .font(.tasker(.caption1))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(minWidth: 28, alignment: .leading)
    }
}

struct HabitBoardTotalsFooterView: View {
    let days: [HabitBoardAggregateDay]

    var body: some View {
        HStack(alignment: .top, spacing: HabitBoardLayout.rowSpacing) {
            Text("Totals")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: HabitBoardLayout.railWidth, alignment: .leading)

            HStack(spacing: HabitBoardStripMode.board.spacing) {
                ForEach(days, id: \.date) { day in
                    Text("\(day.completedCount)")
                        .font(.tasker(.caption1).weight(day.isToday ? .semibold : .regular))
                        .foregroundStyle(day.isToday ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                        .frame(width: HabitBoardStripMode.board.cellSize, alignment: .center)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }
}

private struct HabitBoardHeaderDayCell: View {
    let day: HabitBoardAggregateDay

    var body: some View {
        VStack(spacing: 1) {
            Text(day.date.formatted(.dateTime.month(.abbreviated)))
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)

            if day.isToday {
                VStack(spacing: 0) {
                    Text(day.date.formatted(.dateTime.day()))
                        .font(.tasker(.headline))
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.tasker(.caption2).weight(.semibold))
                }
                .foregroundStyle(Color.white)
                .frame(width: 40, height: 40)
                .background(Color(uiColor: UIColor(taskerHex: "#5CAA31")))
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                .clipShape(Circle())
            } else {
                Text(day.date.formatted(.dateTime.day()))
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)

                Text(day.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.tasker(.caption2).weight(.semibold))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
        }
        .frame(width: HabitBoardStripMode.board.columnWidth, alignment: .center)
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
                    .background(Color.white.opacity(0.94))
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

private struct HabitBoardSurfaceBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(uiColor: UIColor(taskerHex: "#FCFAF4")))
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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ZStack {
            switch cell.state {
            case .bridge(let kind, let source):
                HabitBridgeTileView(
                    kind: kind,
                    source: source,
                    family: family,
                    mode: mode,
                    colorScheme: colorScheme
                )
            default:
                baseFill
            }

            if differentiateWithoutColor {
                differentiateOverlay
            }
        }
        .frame(width: mode.cellSize, height: mode.cellSize)
        .overlay {
            if cell.isToday {
                RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                    .stroke(HabitEverydayPalette.todayStroke(colorScheme: colorScheme), lineWidth: 1.2)
            }
        }
    }

    @ViewBuilder
    private var differentiateOverlay: some View {
        switch cell.state {
        case .missed:
            Rectangle()
                .fill(Color.tasker.textSecondary.opacity(0.22))
                .frame(width: mode.cellSize * 0.45, height: 1)
        case .bridge:
            Circle()
                .fill(Color.tasker.textSecondary)
                .frame(width: mode == .board ? 5 : 4, height: mode == .board ? 5 : 4)
        case .done, .todayPending, .future:
            EmptyView()
        }
    }

    private var baseFill: some View {
        RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
            .fill(fillColor)
            .overlay(doneGrainOverlay)
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .fill(HabitEverydayPalette.paperFill(colorScheme: colorScheme))

            switch kind {
            case .single:
                DualCornerBridgeFill()
                    .fill(HabitEverydayPalette.bridgeTint(for: family, colorScheme: colorScheme))
            case .start:
                LeadingBridgeFill()
                    .fill(HabitEverydayPalette.bridgeTint(for: family, colorScheme: colorScheme))
            case .middle:
                DiagonalBridgeBand()
                    .fill(HabitEverydayPalette.bridgeTint(for: family, colorScheme: colorScheme))
            case .end:
                TrailingBridgeFill()
                    .fill(HabitEverydayPalette.bridgeTint(for: family, colorScheme: colorScheme))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .stroke(
                    source == .skipped ? HabitEverydayPalette.bridgeTint(for: family, colorScheme: colorScheme).opacity(0.18) : .clear,
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

    static func bridgeTint(for family: HabitColorFamily, colorScheme: ColorScheme) -> Color {
        let ramp = colorScheme == .dark ? darkRamps : lightRamps
        return Color(uiColor: UIColor(taskerHex: ramp[family]?[2] ?? family.canonicalHex))
    }

    static func paperFill(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor(taskerHex: "#221D18"))
            : Color(uiColor: UIColor(taskerHex: "#F7F3EB"))
    }

    static func missedFill(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor(taskerHex: "#2A241E"))
            : Color(uiColor: UIColor(taskerHex: "#ECE7DD"))
    }

    static func futureFill(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor(taskerHex: "#1C1713"))
            : Color(uiColor: UIColor(taskerHex: "#F1EEE8"))
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
