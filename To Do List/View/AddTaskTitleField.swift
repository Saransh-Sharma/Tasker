//
//  AddTaskTitleField.swift
//  Tasker
//
//  Primary task name input field with focus state and token styling.
//

import SwiftUI

// MARK: - Add Task Title Field

struct AddTaskTitleField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        TextField("Task name", text: $text)
            .font(.tasker(.body))
            .foregroundColor(Color.tasker.textPrimary)
            .focused($isFocused)
            .submitLabel(.done)
            .onSubmit(onSubmit)
            .padding(.horizontal, spacing.s16)
            .frame(height: spacing.buttonHeight)
            .background(Color.tasker.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2)
                    .stroke(
                        isFocused ? Color.tasker.accentRing : Color.tasker.strokeHairline,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: corner.r2))
            .animation(TaskerAnimation.quick, value: isFocused)
            .accessibilityIdentifier("addTask.titleField")
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskTitleField_Previews: PreviewProvider {
    @State static var text = ""
    @FocusState static var isFocused: Bool

    static var previews: some View {
        VStack(spacing: 16) {
            AddTaskTitleField(text: $text, isFocused: $isFocused, onSubmit: {})

            Text("Preview text: \(text)")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)
        }
        .padding()
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
