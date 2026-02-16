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

    @State private var selectedEmptyStateTitle = NextActionModule.randomEmptyStateTitle()
    @State private var previousOpenTaskCount: Int?

    private static let emptyStateTitles: [String] = [
        "Start your day with one task",
        "Add your first task today",
        "Kick off today with a task",
        "Capture your first task for today",
        "What's your first task today?",
        "Pick your first priority",
        "Plan your first move for today",
        "Add your first win today",
        "Start small, add a task",
        "Begin today with intention",
        "Create your first to-do for the day",
        "Make your first move",
        "Queue up your first task",
        "Set your first focus task",
        "Start strong with one task"
    ]

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
        .onAppear {
            previousOpenTaskCount = openTaskCount
        }
        .onChange(of: openTaskCount) { newCount in
            defer { previousOpenTaskCount = newCount }
            guard let previousOpenTaskCount, previousOpenTaskCount > 0, newCount == 0 else { return }
            selectedEmptyStateTitle = Self.randomEmptyStateTitle()
        }
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
            actionRow(icon: "plus.circle.fill", title: selectedEmptyStateTitle, showChevron: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedEmptyStateTitle)
        .accessibilityHint("Opens the task creation screen")
    }

    private static func randomEmptyStateTitle() -> String {
        emptyStateTitles.randomElement() ?? "Add your first task today"
    }
}
