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
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)

            Spacer()

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
