//
//  AddTaskNavigationBar.swift
//  Tasker
//
//  Navigation bar: Cancel | Title | Done (Done disabled until valid).
//

import SwiftUI

struct AddTaskNavigationBar: View {
    let containerMode: AddTaskContainerMode
    let title: LocalizedStringKey
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack {
            Button {
                onCancel()
            } label: {
                Text(containerMode == .inspector ? "Close" : "Cancel")
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addTask.cancelButton")

            Spacer()

            Text(title)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)

            Spacer()

            Button {
                if canSave {
                    TaskerFeedback.success()
                    onSave()
                }
            } label: {
                Text("Done")
                    .font(.tasker(.callout).weight(.semibold))
                    .foregroundStyle(canSave ? Color.tasker.accentPrimary : Color.tasker.textQuaternary)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .accessibilityIdentifier("addTask.saveButton")
        }
        .padding(.vertical, spacing.s8)
    }
}
