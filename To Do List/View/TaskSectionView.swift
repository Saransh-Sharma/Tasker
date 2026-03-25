//
//  TaskSectionView.swift
//  Tasker
//
//  Collapsible project section with refined header, accent threading,
//  and spring-physics collapse animation. Obsidian & Gems design system.
//

import SwiftUI

// MARK: - Task Section View

struct TaskSectionHeaderRow: View {
    let accentColor: Color
    let iconSystemName: String
    let title: String
    let taskCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    var headerActionTitle: String? = nil
    var onHeaderAction: (() -> Void)? = nil
    var headerActionAccessibilityID: String? = nil

    var body: some View {
        HStack(spacing: TaskerTheme.Spacing.md) {
            Button(action: onToggle) {
                HStack(spacing: TaskerTheme.Spacing.md) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 4, height: 4)

                    Image(systemName: iconSystemName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 20, alignment: .center)

                    Text(title)
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)

                    Text("\(taskCount)")
                        .font(.tasker(.caption2))
                        .fontWeight(.medium)
                        .foregroundColor(Color.tasker.textTertiary)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.tasker.surfaceSecondary)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.tasker.textQuaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .scaleEffect(isExpanded ? 1.0 : 0.9)
                        .animation(TaskerAnimation.snappy, value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let headerActionTitle, let onHeaderAction {
                Button(action: onHeaderAction) {
                    Text(headerActionTitle)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.accentPrimary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .hoverEffect(.highlight)
                .accessibilityIdentifier(headerActionAccessibilityID ?? "home.section.headerAction")
            }
        }
        .padding(.vertical, TaskerTheme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

private struct TaskSectionRenderItem: Equatable {
    let index: Int
    let task: TaskDefinition
}

private struct TaskSectionDerivedState: Equatable {
    let openTasks: [TaskDefinition]
    let completedTasks: [TaskDefinition]
    let openRenderItems: [TaskSectionRenderItem]
    let completedRenderItems: [TaskSectionRenderItem]
    let hasMixedTypes: Bool
    let completedCount: Int

    init(tasks: [TaskDefinition]) {
        let openTasks = tasks.filter { !$0.isComplete }
        let completedTasks = tasks
            .filter(\.isComplete)
            .sorted { lhs, rhs in
                let lhsCompleted = lhs.dateCompleted ?? Date.distantPast
                let rhsCompleted = rhs.dateCompleted ?? Date.distantPast
                if lhsCompleted != rhsCompleted {
                    return lhsCompleted > rhsCompleted
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        self.openTasks = openTasks
        self.completedTasks = completedTasks
        self.openRenderItems = openTasks.enumerated().map { index, task in
            TaskSectionRenderItem(index: index, task: task)
        }
        self.completedRenderItems = completedTasks.enumerated().map { index, task in
            TaskSectionRenderItem(index: index, task: task)
        }
        let types = Set(tasks.map(\.type))
        self.hasMixedTypes = types.contains(.morning) && types.contains(.evening)
        self.completedCount = completedTasks.count
    }
}

struct TaskSectionView: View {
    let project: Project
    let tasks: [TaskDefinition]
    let isOverdueSection: Bool
    let tagNameByID: [UUID: String]
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool
    let completedCollapsed: Bool?
    let isTaskDragEnabled: Bool
    let highlightedTaskID: UUID?
    private let derivedState: TaskSectionDerivedState
    var onTaskTap: ((TaskDefinition) -> Void)?
    var onToggleComplete: ((TaskDefinition) -> Void)?
    var onDeleteTask: ((TaskDefinition) -> Void)?
    var onRescheduleTask: ((TaskDefinition) -> Void)?
    var onPromoteTaskToFocus: ((TaskDefinition) -> Void)?
    var onCompletedCollapsedChange: ((Bool, Int) -> Void)?
    var onTaskDragStarted: ((TaskDefinition) -> Void)?
    var headerActionTitle: String?
    var onHeaderAction: (() -> Void)?
    var headerActionAccessibilityID: String?

    @State private var isExpanded: Bool = true
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).color
    }

    /// Initializes a new instance.
    init(
        project: Project,
        tasks: [TaskDefinition],
        isOverdueSection: Bool = false,
        tagNameByID: [UUID: String] = [:],
        todayXPSoFar: Int? = nil,
        isGamificationV2Enabled: Bool = V2FeatureFlags.gamificationV2Enabled,
        completedCollapsed: Bool? = nil,
        isTaskDragEnabled: Bool = false,
        highlightedTaskID: UUID? = nil,
        onTaskTap: ((TaskDefinition) -> Void)? = nil,
        onToggleComplete: ((TaskDefinition) -> Void)? = nil,
        onDeleteTask: ((TaskDefinition) -> Void)? = nil,
        onRescheduleTask: ((TaskDefinition) -> Void)? = nil,
        onPromoteTaskToFocus: ((TaskDefinition) -> Void)? = nil,
        onCompletedCollapsedChange: ((Bool, Int) -> Void)? = nil,
        onTaskDragStarted: ((TaskDefinition) -> Void)? = nil,
        headerActionTitle: String? = nil,
        onHeaderAction: (() -> Void)? = nil,
        headerActionAccessibilityID: String? = nil
    ) {
        self.project = project
        self.tasks = tasks
        self.isOverdueSection = isOverdueSection
        self.tagNameByID = tagNameByID
        self.todayXPSoFar = todayXPSoFar
        self.isGamificationV2Enabled = isGamificationV2Enabled
        self.completedCollapsed = completedCollapsed
        self.isTaskDragEnabled = isTaskDragEnabled
        self.highlightedTaskID = highlightedTaskID
        self.derivedState = TaskSectionDerivedState(tasks: tasks)
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onDeleteTask = onDeleteTask
        self.onRescheduleTask = onRescheduleTask
        self.onPromoteTaskToFocus = onPromoteTaskToFocus
        self.onCompletedCollapsedChange = onCompletedCollapsedChange
        self.onTaskDragStarted = onTaskDragStarted
        self.headerActionTitle = headerActionTitle
        self.onHeaderAction = onHeaderAction
        self.headerActionAccessibilityID = headerActionAccessibilityID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if isExpanded {
                taskList
                    .padding(.top, TaskerTheme.Spacing.xs)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity
                    ))
            }
        }
        .animation(TaskerAnimation.snappy, value: isExpanded)
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        TaskSectionHeaderRow(
            accentColor: accentColor,
            iconSystemName: sectionIcon,
            title: sectionTitle,
            taskCount: tasks.count,
            isExpanded: isExpanded,
            onToggle: {
                withAnimation(TaskerAnimation.snappy) {
                    isExpanded.toggle()
                }
                TaskerFeedback.selection()
            },
            headerActionTitle: headerActionTitle,
            onHeaderAction: onHeaderAction,
            headerActionAccessibilityID: headerActionAccessibilityID ?? "home.section.headerAction.\(project.id.uuidString)"
        )
    }

    // MARK: - Task List

    private var taskList: some View {
        VStack(spacing: TaskerTheme.Spacing.xs) {
            ForEach(derivedState.openRenderItems, id: \.task.id) { item in
                TaskRowView(
                    task: item.task,
                    showTypeBadge: derivedState.hasMixedTypes,
                    isInOverdueSection: isOverdueSection,
                    tagNameByID: tagNameByID,
                    todayXPSoFar: todayXPSoFar,
                    isGamificationV2Enabled: isGamificationV2Enabled,
                    isTaskDragEnabled: isTaskDragEnabled,
                    highlightedTaskID: highlightedTaskID,
                    onTap: { onTaskTap?(item.task) },
                    onToggleComplete: { onToggleComplete?(item.task) },
                    onDelete: { onDeleteTask?(item.task) },
                    onReschedule: { onRescheduleTask?(item.task) },
                    onPromoteToFocus: onPromoteTaskToFocus.map { handler in
                        { handler(item.task) }
                    },
                    onTaskDragStarted: onTaskDragStarted
                )
                .equatable()
            }

            if derivedState.completedCount > 0 {
                completedToggleRow
                    .padding(.top, 2)

                if !isCompletedCollapsed {
                    ForEach(derivedState.completedRenderItems, id: \.task.id) { item in
                        TaskRowView(
                            task: item.task,
                            showTypeBadge: derivedState.hasMixedTypes,
                            isInOverdueSection: isOverdueSection,
                            tagNameByID: tagNameByID,
                            todayXPSoFar: todayXPSoFar,
                            isGamificationV2Enabled: isGamificationV2Enabled,
                            isTaskDragEnabled: false,
                            highlightedTaskID: highlightedTaskID,
                            onTap: { onTaskTap?(item.task) },
                            onToggleComplete: { onToggleComplete?(item.task) },
                            onDelete: { onDeleteTask?(item.task) },
                            onReschedule: { onRescheduleTask?(item.task) },
                            onPromoteToFocus: nil
                        )
                        .equatable()
                    }
                }
            }
        }
    }

    private var isCompletedCollapsed: Bool {
        guard derivedState.completedCount > 2 else { return false }
        return completedCollapsed ?? true
    }

    private var completedToggleRow: some View {
        Button {
            let nextCollapsed = !isCompletedCollapsed
            onCompletedCollapsedChange?(nextCollapsed, derivedState.completedCount)
            TaskerFeedback.selection()
        } label: {
            HStack(spacing: TaskerTheme.Spacing.sm) {
                Text("Completed")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text("\(derivedState.completedCount)")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textQuaternary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(Capsule())

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.tasker.textQuaternary)
                    .rotationEffect(.degrees(isCompletedCollapsed ? 0 : 90))
                    .animation(TaskerAnimation.snappy, value: isCompletedCollapsed)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.completedToggle.\(project.id.uuidString)")
    }

    // MARK: - Computed Properties

    private var accentColor: Color {
        if isOverdueSection {
            return Color(uiColor: themeColors.taskOverdue)
        }
        return Color.tasker.accentPrimary
    }

    private var sectionIcon: String {
        if isOverdueSection {
            return "exclamationmark.triangle.fill"
        }
        return project.icon.systemImageName
    }

    private var sectionTitle: String {
        if isOverdueSection {
            return "Overdue"
        }
        return project.name
    }
}

struct HomeListRowView: View {
    let row: HomeTodayRow
    let tagNameByID: [UUID: String]
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool
    let isTaskDragEnabled: Bool
    let highlightedTaskID: UUID?
    var onTaskTap: ((TaskDefinition) -> Void)?
    var onToggleComplete: ((TaskDefinition) -> Void)?
    var onDeleteTask: ((TaskDefinition) -> Void)?
    var onRescheduleTask: ((TaskDefinition) -> Void)?
    var onPromoteTaskToFocus: ((TaskDefinition) -> Void)? = nil
    var onTaskDragStarted: ((TaskDefinition) -> Void)?
    var onCompleteHabit: ((HomeHabitRow) -> Void)?
    var onSkipHabit: ((HomeHabitRow) -> Void)?
    var onLapseHabit: ((HomeHabitRow) -> Void)?

    var body: some View {
        switch row {
        case .task(let task):
            TaskRowView(
                task: task,
                showTypeBadge: false,
                isInOverdueSection: row.isOverdueLike,
                tagNameByID: tagNameByID,
                todayXPSoFar: todayXPSoFar,
                isGamificationV2Enabled: isGamificationV2Enabled,
                isTaskDragEnabled: isTaskDragEnabled && !task.isComplete,
                highlightedTaskID: highlightedTaskID,
                onTap: { onTaskTap?(task) },
                onToggleComplete: { onToggleComplete?(task) },
                onDelete: { onDeleteTask?(task) },
                onReschedule: { onRescheduleTask?(task) },
                onPromoteToFocus: onPromoteTaskToFocus.map { handler in
                    { handler(task) }
                },
                onTaskDragStarted: onTaskDragStarted
            )
            .equatable()

        case .habit(let habit):
            HomeHabitRowView(
                row: habit,
                onPrimaryAction: {
                    switch (habit.kind, habit.trackingMode, habit.state) {
                    case (_, .lapseOnly, .tracking):
                        onLapseHabit?(habit)
                    case (.positive, _, _):
                        onCompleteHabit?(habit)
                    case (.negative, .dailyCheckIn, _):
                        onCompleteHabit?(habit)
                    case (.negative, .lapseOnly, _):
                        onLapseHabit?(habit)
                    }
                },
                onSecondaryAction: {
                    switch (habit.kind, habit.trackingMode) {
                    case (.positive, _):
                        onSkipHabit?(habit)
                    case (.negative, .dailyCheckIn):
                        onLapseHabit?(habit)
                    case (.negative, .lapseOnly):
                        break
                    }
                }
            )
        }
    }
}

struct HomeListSectionView: View {
    let section: HomeListSection
    let tagNameByID: [UUID: String]
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool
    let isTaskDragEnabled: Bool
    let highlightedTaskID: UUID?
    let completedCollapsed: Bool?
    var onTaskTap: ((TaskDefinition) -> Void)?
    var onToggleComplete: ((TaskDefinition) -> Void)?
    var onDeleteTask: ((TaskDefinition) -> Void)?
    var onRescheduleTask: ((TaskDefinition) -> Void)?
    var onPromoteTaskToFocus: ((TaskDefinition) -> Void)? = nil
    var onCompletedCollapsedChange: ((Bool, Int) -> Void)?
    var onTaskDragStarted: ((TaskDefinition) -> Void)?
    var onCompleteHabit: ((HomeHabitRow) -> Void)?
    var onSkipHabit: ((HomeHabitRow) -> Void)?
    var onLapseHabit: ((HomeHabitRow) -> Void)?
    var headerActionTitle: String? = nil
    var onHeaderAction: (() -> Void)? = nil
    var headerActionAccessibilityID: String? = nil

    @State private var isExpanded: Bool = true

    private var openRows: [HomeTodayRow] {
        section.rows.filter { !$0.isResolved }
    }

    private var resolvedRows: [HomeTodayRow] {
        section.rows.filter(\.isResolved)
    }

    private var resolvedCount: Int { resolvedRows.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TaskSectionHeaderRow(
                accentColor: accentColor,
                iconSystemName: section.anchor.iconSystemName,
                title: section.title,
                taskCount: section.rows.count,
                isExpanded: isExpanded,
                onToggle: {
                    withAnimation(TaskerAnimation.snappy) {
                        isExpanded.toggle()
                    }
                    TaskerFeedback.selection()
                },
                headerActionTitle: headerActionTitle,
                onHeaderAction: onHeaderAction,
                headerActionAccessibilityID: headerActionAccessibilityID ?? "home.mixedSection.headerAction.\(section.id)"
            )

            if isExpanded {
                VStack(spacing: TaskerTheme.Spacing.xs) {
                    ForEach(openRows) { row in
                        HomeListRowView(
                            row: row,
                            tagNameByID: tagNameByID,
                            todayXPSoFar: todayXPSoFar,
                            isGamificationV2Enabled: isGamificationV2Enabled,
                            isTaskDragEnabled: isTaskDragEnabled,
                            highlightedTaskID: highlightedTaskID,
                            onTaskTap: onTaskTap,
                            onToggleComplete: onToggleComplete,
                            onDeleteTask: onDeleteTask,
                            onRescheduleTask: onRescheduleTask,
                            onPromoteTaskToFocus: onPromoteTaskToFocus,
                            onTaskDragStarted: onTaskDragStarted,
                            onCompleteHabit: onCompleteHabit,
                            onSkipHabit: onSkipHabit,
                            onLapseHabit: onLapseHabit
                        )
                    }

                    if resolvedCount > 0 {
                        resolvedToggleRow
                            .padding(.top, 2)

                        if !isResolvedCollapsed {
                            ForEach(resolvedRows) { row in
                                HomeListRowView(
                                    row: row,
                                    tagNameByID: tagNameByID,
                                    todayXPSoFar: todayXPSoFar,
                                    isGamificationV2Enabled: isGamificationV2Enabled,
                                    isTaskDragEnabled: false,
                                    highlightedTaskID: highlightedTaskID,
                                    onTaskTap: onTaskTap,
                                    onToggleComplete: onToggleComplete,
                                    onDeleteTask: onDeleteTask,
                                    onRescheduleTask: onRescheduleTask,
                                    onPromoteTaskToFocus: nil,
                                    onCompleteHabit: onCompleteHabit,
                                    onSkipHabit: onSkipHabit,
                                    onLapseHabit: onLapseHabit
                                )
                            }
                        }
                    }
                }
                .padding(.top, TaskerTheme.Spacing.xs)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .animation(TaskerAnimation.snappy, value: isExpanded)
    }

    private var accentColor: Color {
        section.isOverdueSection ? Color.tasker.statusDanger : Color.tasker.accentPrimary
    }

    private var isResolvedCollapsed: Bool {
        guard resolvedCount > 2 else { return false }
        return completedCollapsed ?? true
    }

    private var resolvedToggleRow: some View {
        Button {
            let nextCollapsed = !isResolvedCollapsed
            onCompletedCollapsedChange?(nextCollapsed, resolvedCount)
            TaskerFeedback.selection()
        } label: {
            HStack(spacing: TaskerTheme.Spacing.sm) {
                Text("Resolved")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text("\(resolvedCount)")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textQuaternary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(Capsule())

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.tasker.textQuaternary)
                    .rotationEffect(.degrees(isResolvedCollapsed ? 0 : 90))
                    .animation(TaskerAnimation.snappy, value: isResolvedCollapsed)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.resolvedToggle.\(section.id)")
    }
}

// MARK: - Preview

#if DEBUG
struct TaskSectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 28) {
            // Overdue section
            TaskSectionView(
                project: Project.createInbox(),
                tasks: [
                    TaskDefinition(
                         title: "Overdue report",
                        priority: .max,
                        type: .morning,
                        dueDate: Date().addingTimeInterval(-172800)
                    ),
                    TaskDefinition(
                         title: "Fix critical bug in checkout flow",
                        details: "Users are seeing a blank screen after payment",
                        priority: .high,
                        type: .morning,
                        dueDate: Date().addingTimeInterval(-86400)
                    )
                ],
                isOverdueSection: true
            )

            // Inbox section
            TaskSectionView(
                project: Project.createInbox(),
                tasks: [
                    TaskDefinition(
                         title: "Morning meditation and journaling",
                        priority: .low,
                        type: .morning,
                        dueDate: Date()
                    ),
                    TaskDefinition(
                         title: "Review pull requests",
                        details: "Check the API refactor PR from the team",
                        priority: .high,
                        type: .morning,
                        dueDate: Date()
                    ),
                    TaskDefinition(
                         title: "Evening reading",
                        priority: .none,
                        type: .evening
                    )
                ],
                isTaskDragEnabled: true
            )

            // Custom project
            TaskSectionView(
                project: Project(name: "Side Project", icon: .creative),
                tasks: [
                    TaskDefinition(
                         title: "Design landing page wireframes",
                        details: "Focus on mobile-first layout with clear CTA hierarchy",
                        priority: .high,
                        type: .morning,
                        dueDate: Date().addingTimeInterval(86400)
                    )
                ],
                isTaskDragEnabled: true
            )
        }
        .padding(.horizontal, 20)
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
