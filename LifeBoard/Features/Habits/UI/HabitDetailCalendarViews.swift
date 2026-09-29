import SwiftUI

private enum HabitCalendarMetrics {
    static let columnCount = 7
    static let cellSpacing: CGFloat = 3
    static let minimumCellSide: CGFloat = 44
    static let maximumCellSide: CGFloat = 52

    static func cellSide(for availableWidth: CGFloat) -> CGFloat {
        let requiredSpacing = CGFloat(columnCount - 1) * cellSpacing
        let cellWidth = (availableWidth - requiredSpacing) / CGFloat(columnCount)
        return min(maximumCellSide, max(minimumCellSide, floor(cellWidth)))
    }

    static func requiredWidth(for availableWidth: CGFloat) -> CGFloat {
        let side = cellSide(for: availableWidth)
        return (side * CGFloat(columnCount)) + (CGFloat(columnCount - 1) * cellSpacing)
    }
}

enum HabitDetailCalendarLayoutMetrics {
    static let columnCount = HabitCalendarMetrics.columnCount
    static let cellSpacing = HabitCalendarMetrics.cellSpacing
    static let minimumCellSide = HabitCalendarMetrics.minimumCellSide
    static let maximumCellSide = HabitCalendarMetrics.maximumCellSide

    static func cellSide(for availableWidth: CGFloat) -> CGFloat {
        HabitCalendarMetrics.cellSide(for: availableWidth)
    }

    static func requiredWidth(for availableWidth: CGFloat) -> CGFloat {
        HabitCalendarMetrics.requiredWidth(for: availableWidth)
    }
}

struct HabitCalendarSection: View {
    let row: HabitLibraryRow
    let viewState: HabitDetailCalendarViewState
    let helperText: String
    let isLoading: Bool
    let isSaving: Bool
    let onTapDay: (HabitDetailDayCell) -> Void

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens
    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text(helperText)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(HabitDetailAccessibilityID.helperText)

            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width, HabitCalendarMetrics.requiredWidth(for: 0))
                let gridWidth = HabitCalendarMetrics.requiredWidth(for: availableWidth)
                let cellSide = HabitCalendarMetrics.cellSide(for: availableWidth)

                VStack(alignment: .leading, spacing: spacing.s8) {
                    weekdayHeader(cellSide: cellSide)

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            ForEach(viewState.weeks) { week in
                                VStack(alignment: .leading, spacing: spacing.s4) {
                                    if let monthLabel = week.monthLabel {
                                        Text(monthLabel)
                                            .font(.lifeboard(.callout).weight(.semibold))
                                            .foregroundStyle(Color.lifeboard.textSecondary)
                                    }

                                    HStack(spacing: HabitCalendarMetrics.cellSpacing) {
                                        ForEach(week.cells) { cell in
                                            HabitCalendarDayCell(row: row, cell: cell, side: cellSide, isSaving: isSaving) {
                                                onTapDay(cell.cell)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: gridWidth, alignment: .leading)
                    }
                    .accessibilityIdentifier(HabitDetailAccessibilityID.grid)
                }
            }
            .frame(height: gridHeight)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading…")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                }
            }
        }
        .padding(2)
    }

    private var gridHeight: CGFloat {
        let weekCount = max(viewState.weeks.count, 1)
        let monthLabelCount = viewState.weeks.reduce(0) { $0 + ($1.monthLabel == nil ? 0 : 1) }
        return 20 + spacing.s8 + (CGFloat(weekCount) * HabitCalendarMetrics.maximumCellSide) + (CGFloat(max(weekCount - 1, 0)) * spacing.s8) + (CGFloat(monthLabelCount) * (22 + spacing.s4))
    }

    private func weekdayHeader(cellSide: CGFloat) -> some View {
        HStack(spacing: HabitCalendarMetrics.cellSpacing) {
            ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.lifeboard(.meta).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: cellSide, alignment: .center)
            }
        }
    }
}

private struct HabitCalendarDayCell: View {
    let row: HabitLibraryRow
    let cell: HabitDetailCalendarCellViewState
    let side: CGFloat
    let isSaving: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
            ZStack {
                shape.fill(fillColor)
                shape.strokeBorder(borderColor, style: strokeStyle)
                if cell.cell.isToday {
                    shape
                        .strokeBorder(Color.lifeboard.accentPrimary, lineWidth: 1.6)
                        .padding(1)
                }
                differentiateOverlay
                Text(cell.dayNumber)
                    .font(.lifeboard(.callout).weight(textWeight))
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!cell.cell.isInteractive || isSaving)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(cell.accessibilityIdentifier)
        .accessibilityLabel("\(row.title), \(cell.accessibilityLabel)")
        .accessibilityValue(cell.accessibilityValue)
        .accessibilityHint(cell.accessibilityHint)
        .accessibilityAddTraits(cell.cell.isInteractive ? .isButton : .isStaticText)
    }

    @ViewBuilder
    private var differentiateOverlay: some View {
        if differentiateWithoutColor {
            switch cell.cell.state {
            case .lapsed, .empty:
                Rectangle()
                    .fill(Color.lifeboard.textSecondary.opacity(0.22))
                    .frame(width: side * 0.42, height: 1)
            case .skipped, .notScheduled:
                Circle()
                    .fill(Color.lifeboard.textSecondary.opacity(0.55))
                    .frame(width: 5, height: 5)
            case .success, .future:
                EmptyView()
            }
        }
    }

    private var colorFamily: HabitColorFamily {
        HabitColorFamily.family(for: row.colorHex, fallback: row.kind == .positive ? .green : .coral)
    }

    private var fillColor: Color {
        switch cell.cell.state {
        case .success:
            return HabitEverydayPalette.depthColor(for: colorFamily, depth: max(1, min(cell.streakDepth ?? 1, 8)), colorScheme: colorScheme)
        case .future:
            return HabitEverydayPalette.futureFill(colorScheme: colorScheme)
        case .skipped, .notScheduled:
            return HabitEverydayPalette.paperFill(colorScheme: colorScheme)
        case .lapsed, .empty:
            return HabitEverydayPalette.missedFill(colorScheme: colorScheme).opacity(cell.cell.state == .lapsed ? 0.58 : 0.34)
        }
    }

    private var borderColor: Color {
        switch cell.cell.state {
        case .lapsed:
            return HabitEverydayPalette.gridStroke(colorScheme: colorScheme).opacity(0.96)
        default:
            return HabitEverydayPalette.gridStroke(colorScheme: colorScheme).opacity(0.78)
        }
    }

    private var strokeStyle: StrokeStyle {
        switch cell.cell.state {
        case .skipped, .notScheduled:
            return StrokeStyle(lineWidth: 1, dash: [4, 3])
        default:
            return StrokeStyle(lineWidth: 1)
        }
    }

    private var textColor: Color {
        switch cell.cell.state {
        case .success:
            return (cell.streakDepth ?? 1) >= 4 ? Color.lifeboard(.textInverse).opacity(0.98) : Color.lifeboard.textPrimary
        case .lapsed:
            return Color.lifeboard.textSecondary
        case .future, .notScheduled:
            return Color.lifeboard.textTertiary
        default:
            return Color.lifeboard.textPrimary
        }
    }

    private var textWeight: Font.Weight {
        switch cell.cell.state {
        case .success, .lapsed: return .semibold
        default: return .medium
        }
    }
}
