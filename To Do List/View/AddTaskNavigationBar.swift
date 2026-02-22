//
//  AddTaskNavigationBar.swift
//  Tasker
//
//  Navigation bar: Cancel | New Task | Done (Done disabled until valid).
//

import SwiftUI

// MARK: - Add Task Navigation Bar

struct AddTaskNavigationBar: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack {
            Button {
                onCancel()
            } label: {
                Text(TaskerCopy.Actions.cancel)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(minHeight: TaskerTheme.Interaction.minInteractiveSize)

            Spacer()

            Text("New Task")
                .font(.tasker(.title3))
                .foregroundColor(Color.tasker.textPrimary)

            Spacer()

            Button {
                if canSave {
                    TaskerFeedback.success()
                    onSave()
                }
            } label: {
                Text(TaskerCopy.Actions.done)
                    .font(.tasker(.callout).weight(.semibold))
                    .foregroundColor(canSave ? Color.tasker.accentPrimary : Color.tasker.textQuaternary)
            }
            .buttonStyle(.plain)
            .frame(minHeight: TaskerTheme.Interaction.minInteractiveSize)
            .disabled(!canSave)
        }
        .padding(.vertical, spacing.s8)
    }
}
