//
//  NextActionModule.swift
//  Tasker
//
//  Ultra-compact contextual guidance row.
//

import SwiftUI

struct NextActionModule: View {
    let openTaskCount: Int
    let focusPinnedCount: Int
    let onAddTask: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        Group {
            switch openTaskCount {
            case 0:
                zeroTasksState
            case 1...2:
                actionRow(icon: "timer", title: "Plan next 15 min")
                    .accessibilityElement(children: .combine)
            default:
                actionRow(icon: "hand.point.up.left", title: "Drag tasks to focus")
                    .accessibilityElement(children: .combine)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("home.nextActionModule")
    }

    private func actionRow(icon: String, title: String, showChevron: Bool = false) -> some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.tasker.accentPrimary)

            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)

            Spacer(minLength: 0)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.tasker.textQuaternary)
            }
        }
        .padding(.horizontal, spacing.s4)
        .padding(.vertical, spacing.s4)
        .frame(maxWidth: .infinity, minHeight: 32)
        .contentShape(Rectangle())
    }

    private var zeroTasksState: some View {
        Button(action: onAddTask) {
            actionRow(icon: "plus.circle.fill", title: "Add your first task", showChevron: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add your first task for today")
        .accessibilityHint("Opens the task creation screen")
    }
}
