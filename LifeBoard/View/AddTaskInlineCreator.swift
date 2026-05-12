//
//  AddTaskInlineCreator.swift
//  LifeBoard
//
//  Inline project creator that appears when "Add Project" is tapped.
//

import SwiftUI

// MARK: - Add Task Inline Creator

struct AddTaskInlineCreator: View {
    @Binding var projectName: String
    let onCreate: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        HStack(spacing: spacing.s8) {
            // Text field
            TextField("Project name", text: $projectName)
                .font(.lifeboard(.callout))
                .foregroundColor(Color.lifeboard.textPrimary)
                .focused($isFocused)
                .padding(.horizontal, spacing.s12)
                .frame(height: 36)
                .background(Color.lifeboard.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r1)
                        .stroke(isFocused ? Color.lifeboard.accentRing : Color.lifeboard.strokeHairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: corner.r1))

            // Create button
            Button {
                guard !projectName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                LifeBoardFeedback.success()
                onCreate()
            } label: {
                Text("Create")
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundColor(Color.lifeboard.accentOnPrimary)
                    .padding(.horizontal, spacing.s12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.lifeboard.accentPrimary)
                    )
            }
            .buttonStyle(.plain)
            .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)

            // Cancel button
            Button {
                LifeBoardFeedback.light()
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.lifeboard.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskInlineCreator_Previews: PreviewProvider {
    @State static var projectName = ""

    static var previews: some View {
        VStack(spacing: 16) {
            AddTaskInlineCreator(
                projectName: $projectName,
                onCreate: { print("Create: \(projectName)") },
                onCancel: { print("Cancel") }
            )

            AddTaskInlineCreator(
                projectName: .constant("My Project"),
                onCreate: {},
                onCancel: {}
            )
        }
        .padding()
        .background(Color.lifeboard.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
