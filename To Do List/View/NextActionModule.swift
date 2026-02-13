//
//  NextActionModule.swift
//  Tasker
//
//  Contextual guidance card that adapts based on today's task count.
//  Fills the "empty feeling" when users have few or no tasks.
//

import SwiftUI

struct NextActionModule: View {
    let openTaskCount: Int
    let focusPinnedCount: Int
    let onAddTask: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        Group {
            switch openTaskCount {
            case 0:
                zeroTasksState
            case 1...2:
                lowTasksState
            default:
                manyTasksState
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: corner.input, style: .continuous)
                .fill(Color.tasker.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner.input, style: .continuous)
                .stroke(Color.tasker.strokeHairline, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.nextActionModule")
    }

    // MARK: - 0 tasks: "Add your first task"

    private var zeroTasksState: some View {
        Button(action: onAddTask) {
            HStack(spacing: spacing.s12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color.tasker.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add your first task")
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)

                    Text("Tap to create a task for today")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.tasker.textQuaternary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add your first task for today")
        .accessibilityHint("Opens the task creation screen")
    }

    // MARK: - 1-2 tasks: "Plan next 15 minutes"

    private var lowTasksState: some View {
        HStack(spacing: spacing.s12) {
            Image(systemName: "timer")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Color.tasker.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Plan next 15 minutes")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                Text("Start a focus session or pick your next task")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 3+ tasks: "Choose 3 to focus"

    private var manyTasksState: some View {
        HStack(spacing: spacing.s12) {
            Image(systemName: "hand.point.up.left")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Color.tasker.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Choose 3 to focus")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                Text("Long-press and drag tasks to Focus Now")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
