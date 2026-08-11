//
//  AddTaskInlineCreator.swift
//  LifeBoard
//
//  Inline project creator that appears when "Add Project" is tapped.
//

import SwiftUI

// MARK: - Add Task Inline Creator

struct AddTaskInlineCreator: View {
    @Environment(\.lifeboardTokens) private var tokens
    @Binding var projectName: String
    let onCreate: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    private var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }
    private var corner: CornerTokens { ThemeStore.shared.currentTheme.tokens.corner }

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
                HapticFeedback.success()
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
                HapticFeedback.light()
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .lifeboardFont(.sectionTitle)
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
                onCreate: {},
                onCancel: {}
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
