//
//  AddTaskCreateButton.swift
//  Tasker
//
//  Full-width create task button with loading state and haptic feedback.
//

import SwiftUI

// MARK: - Add Task Create Button

struct AddTaskCreateButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        Button {
            if isEnabled && !isLoading {
                TaskerFeedback.light()
                action()
            }
        } label: {
            HStack(spacing: spacing.s8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.tasker.accentOnPrimary))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                }

                Text(isLoading ? "Creating..." : "Create Task")
                    .font(.tasker(.button))
            }
            .foregroundColor(isEnabled ? Color.tasker.accentOnPrimary : Color.tasker.textQuaternary)
            .frame(maxWidth: .infinity)
            .frame(height: spacing.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(isEnabled ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .disabled(!isEnabled || isLoading)
        .animation(TaskerAnimation.quick, value: isEnabled)
        .animation(TaskerAnimation.quick, value: isLoading)
        .accessibilityIdentifier("addTask.createButton")
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskCreateButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            AddTaskCreateButton(isEnabled: false, isLoading: false, action: {})

            AddTaskCreateButton(isEnabled: true, isLoading: false, action: {})

            AddTaskCreateButton(isEnabled: true, isLoading: true, action: {})
        }
        .padding()
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
