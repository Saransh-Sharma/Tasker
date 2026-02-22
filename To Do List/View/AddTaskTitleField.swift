//
//  AddTaskTitleField.swift
//  Tasker
//
//  Primary task name input — auto-focus, keyboard-first, submit on Done.
//

import SwiftUI

// MARK: - Add Task Title Field

struct AddTaskTitleField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    private var interaction: TaskerInteractionTokens { TaskerThemeManager.shared.currentTheme.tokens.interaction }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            TextField("What do you want to do?", text: $text)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textPrimary)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .padding(.horizontal, spacing.s16)
                .frame(minHeight: max(spacing.buttonHeight, interaction.minInteractiveSize))
                .background(Color.tasker.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2)
                        .stroke(
                            isFocused ? Color.tasker.accentRing : Color.tasker.strokeHairline,
                            lineWidth: isFocused ? interaction.focusRingWidth : 1
                        )
                        .padding(isFocused ? -interaction.focusRingOffset : 0)
                )
                .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                .animation(TaskerAnimation.quick, value: isFocused)
                .accessibilityIdentifier("addTask.titleField")

            Text("Keep it short. You can add details after capture.")
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textQuaternary)
                .padding(.horizontal, spacing.s4)
        }
    }
}
