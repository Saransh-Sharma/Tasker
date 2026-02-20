//
//  AddTaskPriorityPill.swift
//  Tasker
//
//  Individual priority pill with jewel-tone color indicator.
//

import SwiftUI

// MARK: - Add Task Priority Pill

struct AddTaskPriorityPill: View {
    let priority: TaskPriority
    let isSelected: Bool
    let action: () -> Void

    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private var priorityColor: Color {
        switch priority {
        case .max: return Color.tasker.priorityMax
        case .high: return Color.tasker.priorityHigh
        case .low: return Color.tasker.priorityLow
        case .none: return Color.tasker.priorityNone
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
            TaskerFeedback.selection()
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
                    .font(.tasker(.callout))
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(isSelected ? priorityColor : Color.tasker.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(isSelected ? priorityColor.opacity(0.12) : Color.tasker.surfaceTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .stroke(
                        isSelected ? priorityColor : Color.tasker.strokeHairline,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(TaskerAnimation.quick, value: isSelected)
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
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
