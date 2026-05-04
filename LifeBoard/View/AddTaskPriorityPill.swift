//
//  AddTaskPriorityPill.swift
//  LifeBoard
//
//  Individual priority pill with jewel-tone color indicator.
//

import SwiftUI

// MARK: - Add Task Priority Pill

struct AddTaskPriorityPill: View {
    let priority: TaskPriority
    let isSelected: Bool
    let action: () -> Void

    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    private var priorityColor: Color {
        switch priority {
        case .max: return Color.lifeboard.priorityMax
        case .high: return Color.lifeboard.priorityHigh
        case .low: return Color.lifeboard.priorityLow
        case .none: return Color.lifeboard.priorityNone
        }
    }

    private var priorityName: String {
        switch priority {
        case .max: return "Max"
        case .high: return "High"
        case .low: return "Low"
        case .none: return "None"
        }
    }

    var body: some View {
        Button {
            LifeBoardFeedback.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                // Jewel dot with glow
                Circle()
                    .fill(priorityColor)
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: isSelected ? priorityColor.opacity(0.5) : .clear,
                        radius: isSelected ? 4 : 0
                    )

                Text(priorityName)
                    .font(.lifeboard(.callout))
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(isSelected ? priorityColor : Color.lifeboard.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(isSelected ? priorityColor.opacity(0.12) : Color.lifeboard.surfaceTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .stroke(
                        isSelected ? priorityColor : Color.lifeboard.strokeHairline,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(LifeBoardAnimation.quick, value: isSelected)
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskPriorityPill_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            AddTaskPriorityPill(priority: .max, isSelected: true, action: {})
            AddTaskPriorityPill(priority: .high, isSelected: false, action: {})
            AddTaskPriorityPill(priority: .low, isSelected: false, action: {})
            AddTaskPriorityPill(priority: .none, isSelected: false, action: {})
        }
        .padding()
        .background(Color.lifeboard.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
