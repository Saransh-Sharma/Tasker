//
//  AddTaskNavigationBar.swift
//  LifeBoard
//
//  Navigation bar: Cancel | Title | Done (Done disabled until valid).
//

import SwiftUI

struct AddTaskNavigationBar: View {
    @Environment(\.lifeboardTokens) private var tokens
    let containerMode: AddTaskContainerMode
    let title: LocalizedStringKey
    let canSave: Bool
    /// False when the sheet's primary action lives elsewhere (Add Task's bottom
    /// "Add task"): one sheet, one primary.
    var showsSave: Bool = true
    let onCancel: () -> Void
    let onSave: () -> Void

    private var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }

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
            // Esc from a hardware keyboard or the Mac. This bar is a plain
            // HStack rather than a toolbar, so it got none of the toolbar
            // shortcuts the rest of the app's composers have.
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("addTask.cancelButton")

            Spacer()

            Text(title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)

            Spacer()

            if showsSave {
                Button {
                    if canSave {
                        // A press, not a commit: the success haptic plays when
                        // the save lands.
                        Haptic.pick.play()
                        onSave()
                    }
                } label: {
                    Text("Done")
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(canSave ? Color.lifeboard.accentPrimary : Color.lifeboard.textQuaternary)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                // ⌘Return, not Return: Return belongs to the title field.
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityIdentifier("addTask.saveButton")
            } else {
                // Balances Cancel so the title stays centred.
                Text(containerMode == .inspector ? "Close" : "Cancel")
                    .font(.lifeboard(.callout))
                    .hidden()
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, spacing.s8)
    }
}
