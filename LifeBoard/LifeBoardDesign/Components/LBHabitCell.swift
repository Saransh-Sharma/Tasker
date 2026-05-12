import SwiftUI

struct LBHabitCell: View {
    struct CellState: Equatable {
        let isFilled: Bool
        let isToday: Bool
        let isWeekend: Bool

        init(isFilled: Bool, isToday: Bool = false, isWeekend: Bool = false) {
            self.isFilled = isFilled
            self.isToday = isToday
            self.isWeekend = isWeekend
        }

        init(_ cell: HabitBoardCell) {
            if case .done = cell.state {
                isFilled = true
            } else if case .bridge = cell.state {
                isFilled = true
            } else {
                isFilled = false
            }
            isToday = cell.isToday
            isWeekend = cell.isWeekend
        }
    }

    struct Model: Identifiable, Equatable {
        let id: String
        let title: String
        let systemImage: String
        let color: Color
        let completionRatio: Double
        let dayLabels: [String]
        let cells: [CellState]
        let allowsTwoLineTitle: Bool
    }

    let model: Model

    var body: some View {
        HStack(alignment: .center, spacing: LBSpacingTokens.sm) {
            Image(systemName: model.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(model.color)
                .frame(width: 26)
            Text(model.title)
                .font(LBTypographyTokens.bodyStrong)
                .foregroundStyle(LBColorTokens.navy)
                .lineLimit(model.allowsTwoLineTitle ? 2 : 1)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            HStack(spacing: 4) {
                ForEach(Array(resolvedCells.enumerated()), id: \.offset) { index, cell in
                    VStack(spacing: 3) {
                        if index < model.dayLabels.count {
                            Text(model.dayLabels[index])
                                .font(LBTypographyTokens.habitDayLabel)
                                .foregroundStyle(cell.isToday ? model.color : LBColorTokens.textTertiary)
                                .frame(width: 16)
                        }
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(cell.isFilled ? model.color : model.color.opacity(cell.isWeekend ? 0.12 : 0.16))
                            .frame(width: 16, height: 18)
                            .overlay {
                                if cell.isToday {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(model.color.opacity(0.72), lineWidth: 1)
                                }
                            }
                    }
                }
            }
        }
        .padding(.horizontal, LBSpacingTokens.xs)
        .frame(minHeight: 48)
    }

    private var resolvedCells: [CellState] {
        if model.cells.isEmpty {
            let filledCount = Int((model.completionRatio * 7).rounded())
            return (0..<7).map { CellState(isFilled: $0 < filledCount) }
        }
        return Array(model.cells.prefix(7))
    }
}
