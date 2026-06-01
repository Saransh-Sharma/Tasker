import SwiftUI

struct HabitStreakMiniCard: View {
    let habit: ReflectionHabitMiniRow

    private var cells: [HabitBoardCell] {
        let referenceDate = habit.last7Days.last?.date ?? Date()
        return HabitBoardPresentationBuilder.buildCells(
            marks: habit.last7Days,
            cadence: .daily(),
            referenceDate: referenceDate,
            dayCount: max(7, habit.last7Days.count)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            HStack(alignment: .firstTextBaseline, spacing: LBSpacingTokens.xs) {
                Image(systemName: habitIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LBColorTokens.role(.routine).deep)
                    .accessibilityHidden(true)
                Text(shortTitle)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                Spacer(minLength: 4)
                Text("\(habit.currentStreak)d active")
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navyMuted)
            }

            HabitBoardStripView(
                cells: Array(cells.suffix(7)),
                family: habit.colorFamily,
                mode: .compact,
                cellSizeOverride: 9,
                cellWidthOverride: 9,
                cellHeightOverride: 9
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(ReflectPlanStyle.cream.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ReflectPlanStyle.peachBorder.opacity(0.62), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.title), \(habit.currentStreak) active days.")
    }

    private var shortTitle: String {
        let title = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count > 28 else { return title }
        let words = title.split(separator: " ")
        guard words.count > 2 else { return String(title.prefix(28)) }
        return words.prefix(3).joined(separator: " ")
    }

    private var habitIcon: String {
        switch habit.colorFamily {
        case .green, .teal:
            return "leaf.fill"
        case .orange, .coral:
            return "sun.max.fill"
        case .blue:
            return "checkmark.seal.fill"
        case .purple:
            return "sparkles"
        case .gray:
            return "circle.grid.2x2.fill"
        }
    }
}
