import SwiftUI
import UIKit

enum HabitBoardStripMode {
    case compact
    case expanded
    case board

    var cellSize: CGFloat {
        switch self {
        case .compact: return 12
        case .expanded: return 16
        case .board: return 22
        }
    }

    var spacing: CGFloat {
        switch self {
        case .compact: return 2
        case .expanded: return 3
        case .board: return 1
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 3
        case .expanded: return 4
        case .board: return 2
        }
    }
}

struct HabitBoardStripView: View {
    let cells: [HabitBoardCell]
    let accentHex: String?
    let fallbackColor: Color
    let mode: HabitBoardStripMode

    var body: some View {
        HStack(spacing: mode.spacing) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                HabitBoardCellView(
                    cell: cell,
                    accentHex: accentHex,
                    fallbackColor: fallbackColor,
                    mode: mode
                )
            }
        }
        .accessibilityHidden(true)
    }
}

struct HabitHistoryStripView: View {
    let marks: [HabitDayMark]
    var accentHex: String? = nil
    var fallbackColor: Color = Color.tasker.accentPrimary

    private var boardCells: [HabitBoardCell] {
        HabitBoardPresentationBuilder.buildCells(
            marks: marks,
            cadence: .daily(),
            referenceDate: marks.last?.date ?? Date(),
            dayCount: max(marks.count, 14)
        )
    }

    var body: some View {
        HabitBoardStripView(
            cells: boardCells,
            accentHex: accentHex,
            fallbackColor: fallbackColor,
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
                    Button("Board") {
                        onOpenBoard()
                    }
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker.accentPrimary)
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: spacing.s8) {
                HabitBoardStripView(
                    cells: aggregatePreviewCells,
                    accentHex: nil,
                    fallbackColor: Color.tasker.accentPrimary,
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
        .background(Color.tasker.surfaceSecondary.opacity(0.32))
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card)
                .stroke(Color.tasker.strokeHairline.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card))
    }

    private var aggregatePreviewCells: [HabitBoardCell] {
        let presentations = rows.map { row in
            HabitBoardRowPresentation(
                habitID: row.habitID,
                title: row.title,
                iconSymbolName: row.iconSymbolName,
                accentHex: row.accentHex,
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
                state: day.completedCount > 0 ? .success(runDepth: min(day.completedCount, 5)) : .none,
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
                    onMutation: {
                        viewModel.refresh()
                    }
                )
            }
        }
    }

    private var boardToolbarCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(spacing: spacing.s8) {
                Button {
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange) {
                        viewModel.moveWindow(byDays: -viewModel.visibleDayCount)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.tasker.surfaceSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rangeTitle)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Text("Momentum board")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange) {
                        viewModel.moveWindow(byDays: viewModel.visibleDayCount)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.tasker.surfaceSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Picker("Summary", selection: $viewModel.summaryMode) {
                Text("Streaks").tag(HabitBoardSummaryMode.streaks)
                Text("Counts").tag(HabitBoardSummaryMode.counts)
            }
            .pickerStyle(.segmented)
        }
        .padding(spacing.s16)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary
        )
    }

    private var boardCard: some View {
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
                        .overlay(Color.tasker.strokeHairline.opacity(0.5))
                }

                HabitBoardTotalsFooterView(days: viewModel.aggregateDays)
            }
        }
        .padding(spacing.s16)
        .background(Color(uiColor: UIColor(taskerHex: "#FFFDF9")))
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card)
                .stroke(Color.tasker.strokeHairline.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card))
    }

    private var boardHeader: some View {
        HStack(alignment: .bottom, spacing: spacing.s12) {
            Text("Habits")
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: 116, alignment: .leading)

            HStack(spacing: 1) {
                ForEach(viewModel.aggregateDays, id: \.date) { day in
                    HabitBoardHeaderDayCell(day: day)
                }
            }

            summaryHeader
                .frame(width: 118, alignment: .leading)
        }
    }

    @ViewBuilder
    private var summaryHeader: some View {
        switch viewModel.summaryMode {
        case .streaks:
            HStack(spacing: spacing.s8) {
                Text("current")
                Text("best")
                Text("total")
            }
            .font(.tasker(.caption1))
            .foregroundStyle(Color.tasker.textSecondary)
        case .counts:
            HStack(spacing: spacing.s8) {
                Text("week")
                Text("month")
                Text("year")
            }
            .font(.tasker(.caption1))
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
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(HabitBoardAccentPalette.baseColor(accentHex: row.accentHex, fallbackColor: Color.tasker.accentPrimary))
                    .frame(width: 8, height: 8)

                Image(systemName: row.iconSymbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HabitBoardAccentPalette.baseColor(accentHex: row.accentHex, fallbackColor: Color.tasker.accentPrimary))

                Text(row.title)
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .lineLimit(2)
            }
            .frame(width: 116, alignment: .leading)

            HabitBoardStripView(
                cells: row.cells,
                accentHex: row.accentHex,
                fallbackColor: Color.tasker.accentPrimary,
                mode: .board
            )

            HabitBoardSummaryRailView(row: row, summaryMode: summaryMode)
                .frame(width: 118, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

struct HabitBoardSummaryRailView: View {
    let row: HabitBoardRowPresentation
    let summaryMode: HabitBoardSummaryMode

    var body: some View {
        HStack(spacing: 8) {
            switch summaryMode {
            case .streaks:
                metric("\(row.metrics.currentStreak)", emphasized: row.metrics.currentStreak > 0, accentHex: row.accentHex)
                metric("\(row.metrics.bestStreak)", emphasized: row.metrics.bestStreak > 0, accentHex: row.accentHex)
                metric("\(row.metrics.totalCount)", emphasized: false, accentHex: row.accentHex)
            case .counts:
                metric("\(row.metrics.weekCount)", emphasized: row.metrics.weekCount > 0, accentHex: row.accentHex)
                metric("\(row.metrics.monthCount)", emphasized: row.metrics.monthCount > 0, accentHex: row.accentHex)
                metric("\(row.metrics.yearCount)", emphasized: false, accentHex: row.accentHex)
            }
        }
    }

    private func metric(
        _ value: String,
        emphasized: Bool,
        accentHex: String?
    ) -> some View {
        Text(value)
            .font(.tasker(.caption1).weight(emphasized ? .semibold : .regular))
            .foregroundStyle(
                emphasized
                    ? HabitBoardAccentPalette.baseColor(accentHex: accentHex, fallbackColor: Color.tasker.accentPrimary)
                    : Color.tasker.textSecondary
            )
            .frame(minWidth: 28, alignment: .leading)
    }
}

struct HabitBoardTotalsFooterView: View {
    let days: [HabitBoardAggregateDay]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Totals")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: 116, alignment: .leading)

            HStack(spacing: 1) {
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
        VStack(spacing: 2) {
            Text(day.date.formatted(.dateTime.weekday(.short)))
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)

            if day.isToday {
                Text(day.date.formatted(.dateTime.day()))
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.white)
                    .frame(width: 34, height: 34)
                    .background(Color.tasker.accentPrimary)
                    .clipShape(Circle())
            } else {
                Text(day.date.formatted(.dateTime.day()))
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)
            }
        }
        .frame(width: HabitBoardStripMode.board.cellSize, alignment: .center)
    }
}

private struct HabitBoardCellView: View {
    let cell: HabitBoardCell
    let accentHex: String?
    let fallbackColor: Color
    let mode: HabitBoardStripMode
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ZStack {
            baseFill

            if case .scheduledOff = cell.state {
                ScheduledOffOverlay()
                    .fill(Color(uiColor: UIColor(taskerHex: "#FFFEFB")))
            }

            if case .skipped = cell.state {
                RoundedRectangle(cornerRadius: mode.cornerRadius)
                    .stroke(Color.tasker.textSecondary.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }

            if differentiateWithoutColor {
                differentiateOverlay
            }
        }
        .frame(width: mode.cellSize, height: mode.cellSize)
        .overlay {
            if cell.isToday {
                RoundedRectangle(cornerRadius: mode.cornerRadius)
                    .stroke(Color.tasker.accentPrimary.opacity(0.85), lineWidth: 1.2)
            }
        }
    }

    @ViewBuilder
    private var differentiateOverlay: some View {
        switch cell.state {
        case .failure:
            Image(systemName: "xmark")
                .font(.system(size: mode == .board ? 8 : 6, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
        case .skipped:
            Circle()
                .fill(Color.tasker.textSecondary)
                .frame(width: mode == .board ? 5 : 4, height: mode == .board ? 5 : 4)
        case .scheduledOff:
            EmptyView()
        case .success, .none, .future:
            EmptyView()
        }
    }

    private var baseFill: some View {
        RoundedRectangle(cornerRadius: mode.cornerRadius)
            .fill(fillColor)
    }

    private var fillColor: Color {
        switch cell.state {
        case .success(let runDepth):
            return HabitBoardAccentPalette.successColor(
                accentHex: accentHex,
                fallbackColor: fallbackColor,
                runDepth: runDepth
            )
        case .failure:
            return Color(uiColor: UIColor(taskerHex: "#D56B5C"))
        case .scheduledOff:
            return Color(uiColor: UIColor(taskerHex: "#E2E7DF"))
        case .skipped:
            return Color(uiColor: UIColor(taskerHex: "#D5DCD3"))
        case .none:
            return Color(uiColor: UIColor(taskerHex: "#F0F2EC"))
        case .future:
            return Color(uiColor: UIColor(taskerHex: "#F6F7F3"))
        }
    }
}

private struct ScheduledOffOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private enum HabitBoardAccentPalette {
    static func baseColor(
        accentHex: String?,
        fallbackColor: Color
    ) -> Color {
        guard let normalized = TaskerHexColor.normalized(accentHex) else {
            return fallbackColor
        }
        return Color(uiColor: UIColor(taskerHex: normalized))
    }

    static func successColor(
        accentHex: String?,
        fallbackColor: Color,
        runDepth: Int
    ) -> Color {
        let baseUIColor: UIColor
        if let normalized = TaskerHexColor.normalized(accentHex) {
            baseUIColor = UIColor(taskerHex: normalized)
        } else {
            baseUIColor = UIColor(fallbackColor)
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard baseUIColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return fallbackColor
        }

        let bucket = max(1, min(runDepth, 5))
        let adjusted = UIColor(
            hue: hue,
            saturation: min(1, saturation * (0.68 + CGFloat(bucket) * 0.08)),
            brightness: max(0, min(1, brightness * (1.18 - CGFloat(bucket) * 0.08))),
            alpha: min(1, 0.56 + CGFloat(bucket) * 0.08)
        )
        return Color(uiColor: adjusted)
    }
}

private extension HabitBoardCell {
    var isSuccess: Bool {
        if case .success = state {
            return true
        }
        return false
    }
}
