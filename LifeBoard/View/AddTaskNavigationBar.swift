//
//  AddTaskNavigationBar.swift
//  LifeBoard
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

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack {
            Button {
                onCancel()
            } label: {
                Text(containerMode == .inspector ? "Close" : "Cancel")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addTask.cancelButton")

            Spacer()

            Text(title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)

            Spacer()

            Button {
                if canSave {
                    LifeBoardFeedback.success()
                    onSave()
                }
            } label: {
                Text("Done")
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(canSave ? Color.lifeboard.accentPrimary : Color.lifeboard.textQuaternary)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .accessibilityIdentifier("addTask.saveButton")
        }
        .padding(.vertical, spacing.s8)
    }
}
