//
//  AddTaskDescriptionField.swift
//  LifeBoard
//
//  Optional description text editor with placeholder and focus state.
//

import SwiftUI

// MARK: - Add Task Description Field

struct AddTaskDescriptionField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text("Description (optional)")
                    .font(.lifeboard(.body))
                    .foregroundColor(Color.lifeboard.textTertiary)
                    .padding(spacing.s12)
            }

            // Text editor
            TextEditor(text: $text)
                .font(.lifeboard(.body))
                .foregroundColor(Color.lifeboard.textPrimary)
                .focused($isFocused)
                .padding(spacing.s4)
                .frame(minHeight: 80, maxHeight: 120)
                .scrollContentBackground(.hidden)
        }
        .background(Color.lifeboard.surfaceSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: corner.r2)
                .stroke(
                    isFocused ? Color.lifeboard.accentRing : Color.lifeboard.strokeHairline,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: corner.r2))
        .animation(LifeBoardAnimation.quick, value: isFocused)
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
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textTertiary)
        }
        .padding()
        .background(Color.lifeboard.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
