//
//  AddTaskTitleField.swift
//  Tasker
//
//  Primary name input — auto-focus, keyboard-first, submit on Done.
//

import SwiftUI

struct AddTaskTitleField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let placeholder: LocalizedStringKey
    let helperText: LocalizedStringKey
    let onSubmit: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            TextField(placeholder, text: $text)
                .font(.tasker(.body))
                .foregroundStyle(Color.tasker.textPrimary)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .padding(.horizontal, spacing.s16)
                .frame(height: spacing.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .fill(isFocused ? Color.tasker.surfacePrimary : Color.tasker.surfaceSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2)
                        .stroke(
                            isFocused ? Color.tasker.accentRing : Color.tasker.strokeHairline,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                .shadow(
                    color: isFocused ? Color.tasker.accentPrimary.opacity(0.12) : .clear,
                    radius: isFocused ? 10 : 0,
                    y: isFocused ? 6 : 0
                )
                .animation(TaskerAnimation.quick, value: isFocused)
                .accessibilityIdentifier("addTask.titleField")

            Text(helperText)
                .font(.tasker(.caption2))
                .foregroundStyle(isFocused ? Color.tasker.textSecondary : Color.tasker.textQuaternary)
                .padding(.horizontal, spacing.s4)
                .animation(TaskerAnimation.quick, value: isFocused)
        }
    }
}
