//
//  AddTaskDescriptionField.swift
//  Tasker
//
//  Optional description text editor with placeholder and focus state.
//

import SwiftUI

// MARK: - Add Task Description Field

struct AddTaskDescriptionField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text("Description (optional)")
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textTertiary)
                    .padding(spacing.s12)
            }

            // Text editor
            TextEditor(text: $text)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textPrimary)
                .focused($isFocused)
                .padding(spacing.s4)
                .frame(minHeight: 80, maxHeight: 120)
                .scrollContentBackground(.hidden)
        }
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
        .accessibilityIdentifier("addTask.descriptionField")
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskDescriptionField_Previews: PreviewProvider {
    @State static var text = ""
    @FocusState static var isFocused: Bool

    static var previews: some View {
        VStack(spacing: 16) {
            AddTaskDescriptionField(text: $text, isFocused: $isFocused)

            Text("Character count: \(text.count)")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)
        }
        .padding()
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
