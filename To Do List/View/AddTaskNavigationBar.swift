//
//  AddTaskNavigationBar.swift
//  Tasker
//
//  Navigation bar for Add Task sheet with Cancel/Title/Done buttons.
//

import SwiftUI

// MARK: - Add Task Navigation Bar

struct AddTaskNavigationBar: View {
    let title: String
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack {
            // Cancel button
            Button {
                TaskerFeedback.light()
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Title
            Text(title)
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)

            Spacer()

            // Done button
            Button {
                if canSave {
                    TaskerFeedback.success()
                    onSave()
                }
            } label: {
                Text("Done")
                    .font(.tasker(.callout).weight(.semibold))
                    .foregroundColor(canSave ? Color.tasker.accentPrimary : Color.tasker.textQuaternary)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.vertical, spacing.s8)
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskNavigationBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AddTaskNavigationBar(
                title: "New Task",
                canSave: false,
                onCancel: {},
                onSave: {}
            )

            AddTaskNavigationBar(
                title: "New Task",
                canSave: true,
                onCancel: {},
                onSave: {}
            )
        }
        .padding()
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
