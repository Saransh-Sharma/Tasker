//
//  AddTaskXPPreview.swift
//  Tasker
//
//  Dynamic XP preview badge that shows points based on selected priority.
//

import SwiftUI

// MARK: - Add Task XP Preview

struct AddTaskXPPreview: View {
    let priority: TaskPriority

    private var xpValue: Int {
        priority.scorePoints
    }

    private var isHighValue: Bool {
        priority == .max || priority == .high
    }

    private var priorityColor: Color {
        switch priority {
        case .max: return Color.tasker.priorityMax
        case .high: return Color.tasker.priorityHigh
        case .low: return Color.tasker.priorityLow
        case .none: return Color.tasker.priorityNone
        }
    }

    var body: some View {
        HStack {
            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isHighValue ? Color.tasker.accentSecondary : Color.tasker.textTertiary)

                Text("+\(xpValue) XP")
                    .font(.tasker(.callout))
                    .fontWeight(.medium)
                    .foregroundColor(isHighValue ? Color.tasker.textSecondary : Color.tasker.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isHighValue ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
            )
            .overlay(
                Capsule()
                    .stroke(isHighValue ? priorityColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .animation(TaskerAnimation.quick, value: priority)
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskXPPreview_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            AddTaskXPPreview(priority: .max)
            AddTaskXPPreview(priority: .high)
            AddTaskXPPreview(priority: .low)
            AddTaskXPPreview(priority: .none)
        }
        .padding()
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
