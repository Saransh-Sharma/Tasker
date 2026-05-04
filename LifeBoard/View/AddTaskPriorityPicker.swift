//
//  AddTaskPriorityPicker.swift
//  Tasker
//
//  Priority picker row with P0/P1/P2/P3 jewel pills and XP indicators.
//

import SwiftUI

// MARK: - Add Task Priority Picker

struct AddTaskPriorityPicker: View {
    @Binding var selectedPriority: TaskPriority

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private let priorities: [TaskPriority] = TaskPriority.uiOrder  // [.none, .low, .high, .max]

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            // Label
            Text("Priority")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            // Priority pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    ForEach(priorities, id: \.self) { priority in
                        AddTaskPriorityPill(
                            priority: priority,
                            isSelected: selectedPriority == priority
                        ) {
                            withAnimation(TaskerAnimation.snappy) {
                                selectedPriority = priority
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskPriorityPicker_Previews: PreviewProvider {
    @State static var selectedPriority: TaskPriority = .low

    static var previews: some View {
        VStack(spacing: 20) {
            AddTaskPriorityPicker(selectedPriority: $selectedPriority)

            Text("Selected: \(selectedPriority.displayNameWithXP)")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)
        }
        .padding()
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}

// MARK: - TaskPriority Extension

private extension TaskPriority {
    var displayNameWithXP: String {
        "\(displayName) (\(scorePoints) XP)"
    }
}
#endif
