//
//  TaskCard.swift
//  To Do List
//
//  Task card variants for non-list contexts (dashboard, detail views).
//  Migrated from Core Data entity rows to domain Task model.
//

import SwiftUI

// MARK: - Task Card Component
struct TaskCard: View {
    let task: TaskDefinition
    let onTap: (() -> Void)?
    let onToggleComplete: (() -> Void)?

    @State private var isPressed = false
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    /// Initializes a new instance.
    init(
        task: TaskDefinition,
        onTap: (() -> Void)? = nil,
        onToggleComplete: (() -> Void)? = nil
    ) {
        self.task = task
        self.onTap = onTap
        self.onToggleComplete = onToggleComplete
    }

    var body: some View {
        cardBody
    }

    private var completionButton: some View {
        Button(action: {
            onToggleComplete?()
        }) {
            let iconName = task.isComplete ? "checkmark.circle.fill" : "circle"
            let iconColor = task.isComplete ? Color(uiColor: themeColors.accentPrimary) : Color(uiColor: themeColors.textSecondary)

            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .animation(.easeInOut(duration: 0.2), value: task.isComplete)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var taskContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: spacing.titleSubtitleGap) {
                // Task title
                Text(task.title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(task.isComplete ? .secondary : .primary)
                    .strikethrough(task.isComplete)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Task details
                if let details = task.details, !details.isEmpty {
                    Text(details)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .lineLimit(1)
                }

                // Due date and priority
                HStack(spacing: spacing.s8) {
                    if let dueDate = task.dueDate {
                        Label {
                            Text(DateUtils.formatDate(dueDate))
                                .font(.tasker(.caption2))
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.tasker(.caption2))
                        }
                        .foregroundColor(dueDateColor)
                    }

                    if task.priority != .none {
                        Label {
                            Text(task.priority.displayName)
                                .font(.tasker(.caption2))
                        } icon: {
                            Image(systemName: task.priority.indicator.symbolName)
                                .font(.tasker(.caption2))
                        }
                        .foregroundColor(priorityColor)
                    }

                    Spacer()
                }
            }

            Spacer()

            // Chevron indicator
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.tasker.textSecondary)
            }
        }
    }

    var cardBody: some View {
        HStack(spacing: spacing.cardStackVertical) {
            completionButton
            taskContent
        }
        .padding(spacing.cardPadding)
        .themedMediumCard()
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            onTap?()
        }
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {}
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Computed Properties

    private var dueDateColor: Color {
        guard let dueDate = task.dueDate else { return .secondary }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(dueDate) {
            return Color(uiColor: themeColors.statusWarning)
        } else if dueDate < now {
            return Color(uiColor: themeColors.statusDanger)
        } else if calendar.isDateInTomorrow(dueDate) {
            return Color(uiColor: themeColors.accentPrimary)
        } else {
            return Color(uiColor: themeColors.textSecondary)
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .max:
            return Color(uiColor: themeColors.statusDanger)
        case .high:
            return Color(uiColor: themeColors.statusWarning)
        case .low:
            return Color(uiColor: themeColors.accentPrimary)
        case .none:
            return Color(uiColor: themeColors.accentMuted)
        }
    }

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }

    private var accessibilityLabel: String {
        var label = "Task: \(task.title)"

        if task.isComplete {
            label += ", completed"
        }

        if let dueDate = task.dueDate {
            label += ", due \(DateUtils.formatDate(dueDate))"
        }

        if task.priority != .none {
            label += ", \(task.priority.displayName) priority"
        }

        return label
    }

    private var accessibilityHint: String {
        var hints: [String] = []

        if onToggleComplete != nil {
            hints.append("Double tap to toggle completion")
        }

        if onTap != nil {
            hints.append("Tap to view details")
        }

        return hints.joined(separator: ", ")
    }
}

// MARK: - Task Card Variants

/// Compact version of TaskCard for list views
struct CompactTaskCard: View {
    let task: TaskDefinition
    let onTap: (() -> Void)?
    let onToggleComplete: (() -> Void)?

    var body: some View {
        HStack(spacing: spacing.cardStackVertical) {
            Button(action: {
                onToggleComplete?()
            }) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isComplete ? Color(uiColor: themeColors.accentPrimary) : Color(uiColor: themeColors.textSecondary))
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: spacing.s2) {
                Text(task.title)
                    .font(.tasker(.callout))
                    .foregroundColor(task.isComplete ? .secondary : .primary)
                    .strikethrough(task.isComplete)
                    .lineLimit(1)

                if let dueDate = task.dueDate {
                    Text(DateUtils.formatDate(dueDate))
                        .font(.tasker(.caption2))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if task.priority != .none {
                HStack(spacing: spacing.s4) {
                    Image(systemName: task.priority.indicator.symbolName)
                        .font(.system(size: TaskerSwiftUITokens.iconSize.small, weight: .semibold))
                    Text(task.priority.indicator.shortLabel)
                        .font(.tasker(.caption2))
                        .fontWeight(.medium)
                }
                .foregroundColor(priorityColor)
                .padding(.horizontal, spacing.s8)
                .padding(.vertical, spacing.s4)
                .background(priorityColor.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(spacing.listRowVerticalPadding)
        .themedSmallCard()
        .onTapGesture {
            onTap?()
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .max: return Color(uiColor: themeColors.priorityMax)
        case .high: return Color(uiColor: themeColors.priorityHigh)
        case .low: return Color(uiColor: themeColors.priorityLow)
        case .none: return Color(uiColor: themeColors.priorityNone)
        }
    }

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.currentTheme.tokens.spacing
    }
}

/// Featured version of TaskCard for dashboard/home views
struct FeaturedTaskCard: View {
    let task: TaskDefinition
    let onTap: (() -> Void)?
    let onToggleComplete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    onToggleComplete?()
                }) {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundColor(task.isComplete ? Color(uiColor: themeColors.accentPrimary) : Color(uiColor: themeColors.textSecondary))
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                if task.priority != .none {
                    HStack(spacing: 4) {
                        Image(systemName: task.priority.indicator.symbolName)
                        Text("\(task.priority.displayName) priority")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.2))
                    .foregroundColor(priorityColor)
                    .clipShape(Capsule())
                }
            }

            Text(task.title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(task.isComplete ? .secondary : .primary)
                .strikethrough(task.isComplete)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if let taskDetails = task.details, !taskDetails.isEmpty {
                Text(taskDetails)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if let dueDate = task.dueDate {
                HStack {
                    Image(systemName: "calendar")
                    Text("Due \(DateUtils.formatDate(dueDate))")
                }
                .font(.caption)
                .foregroundColor(dueDateColor)
            }
        }
        .padding(20)
        .themedLargeCard()
        .onTapGesture {
            onTap?()
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .max:
            return Color(uiColor: themeColors.statusDanger)
        case .high:
            return Color(uiColor: themeColors.statusWarning)
        case .low:
            return Color(uiColor: themeColors.accentPrimary)
        case .none:
            return Color(uiColor: themeColors.accentMuted)
        }
    }

    private var dueDateColor: Color {
        guard let dueDate = task.dueDate else { return .secondary }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(dueDate) {
            return Color(uiColor: themeColors.statusWarning)
        } else if dueDate < now {
            return Color(uiColor: themeColors.statusDanger)
        } else if calendar.isDateInTomorrow(dueDate) {
            return Color(uiColor: themeColors.accentPrimary)
        } else {
            return Color(uiColor: themeColors.textSecondary)
        }
    }

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }
}

// MARK: - Preview
#if DEBUG
struct TaskCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            TaskCard(
                task: sampleTask,
                onTap: { logDebug("Task tapped") },
                onToggleComplete: { logDebug("Toggle complete") }
            )

            CompactTaskCard(
                task: sampleTask,
                onTap: { logDebug("Compact task tapped") },
                onToggleComplete: { logDebug("Toggle complete") }
            )

            FeaturedTaskCard(
                task: sampleTask,
                onTap: { logDebug("Featured task tapped") },
                onToggleComplete: { logDebug("Toggle complete") }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }

    static var sampleTask: TaskDefinition {
        TaskDefinition(
            title: "Sample Task",
            details: "This is a sample task for preview",
            priority: .low,
            dueDate: Date().addingTimeInterval(86400)
        )
    }
}
#endif
