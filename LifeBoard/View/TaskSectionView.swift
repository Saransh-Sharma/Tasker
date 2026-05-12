//
//  TaskSectionView.swift
//  LifeBoard
//
//  Collapsible project section with refined header, accent threading,
//  and spring-physics collapse animation. Obsidian & Gems design system.
//

import SwiftUI

// MARK: - Task Section View

struct HomeTaskRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.lifeboard.strokeHairline.opacity(0.55))
            .frame(height: 1)
    }
}

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
        HStack(spacing: LifeBoardTheme.Spacing.md) {
            Button(action: onToggle) {
                HStack(spacing: LifeBoardTheme.Spacing.md) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 4, height: 4)

                    Image(systemName: iconSystemName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 20, alignment: .center)

                    Text(title)
                        .font(.lifeboard(.headline))
                        .foregroundColor(Color.lifeboard.textPrimary)

                    Text("\(taskCount)")
                        .font(.lifeboard(.caption2))
                        .fontWeight(.medium)
                        .foregroundColor(Color.lifeboard.textTertiary)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.lifeboard.surfaceSecondary)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.lifeboard.textQuaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .scaleEffect(isExpanded ? 1.0 : 0.9)
                        .animation(LifeBoardAnimation.snappy, value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let headerActionTitle, let onHeaderAction {
                Button(action: onHeaderAction) {
                    Text(headerActionTitle)
                        .font(.lifeboard(.caption1))
                        .foregroundColor(Color.lifeboard.accentPrimary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .hoverEffect(.highlight)
                .accessibilityIdentifier(headerActionAccessibilityID ?? "home.section.headerAction")
            }
        }
        .padding(.vertical, LifeBoardTheme.Spacing.sm)
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
    let layoutStyle: TaskListLayoutStyle
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
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var themeColors: LifeBoardColorTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).color
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
        layoutStyle: TaskListLayoutStyle = .inset,
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
        self.layoutStyle = layoutStyle
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
                    .padding(.top, layoutStyle == .inset ? LifeBoardTheme.Spacing.xs : 0)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity
                    ))
            }
        }
        .animation(LifeBoardAnimation.snappy, value: isExpanded)
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
                withAnimation(LifeBoardAnimation.snappy) {
                    isExpanded.toggle()
                }
                LifeBoardFeedback.selection()
            },
            headerActionTitle: headerActionTitle,
            onHeaderAction: onHeaderAction,
            headerActionAccessibilityID: headerActionAccessibilityID ?? "home.section.headerAction.\(project.id.uuidString)"
        )
        .padding(.horizontal, layoutStyle.headerHorizontalPadding)
    }

    // MARK: - Task List

    private var taskList: some View {
        VStack(spacing: layoutStyle.rowSpacing) {
            ForEach(Array(derivedState.openRenderItems.enumerated()), id: \.element.task.id) { index, item in
                TaskRowView(
                    task: item.task,
                    fallbackIconSymbolName: project.icon.systemImageName,
                    accentHex: project.color.hexString,
                    showTypeBadge: derivedState.hasMixedTypes,
                    isInOverdueSection: isOverdueSection,
                    tagNameByID: tagNameByID,
                    todayXPSoFar: todayXPSoFar,
                    isGamificationV2Enabled: isGamificationV2Enabled,
                    isTaskDragEnabled: isTaskDragEnabled,
                    highlightedTaskID: highlightedTaskID,
                    metadataPolicy: layoutStyle.taskMetadataPolicy,
                    chromeStyle: layoutStyle.taskChromeStyle,
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

                if layoutStyle.showsRowDividers && index < derivedState.openRenderItems.count - 1 {
                    HomeTaskRowDivider()
                }
            }

            if derivedState.completedCount > 0 {
                if layoutStyle.showsRowDividers && !derivedState.openRenderItems.isEmpty {
                    HomeTaskRowDivider()
                }

                completedToggleRow
                    .padding(.top, layoutStyle == .inset ? 2 : 0)

                if !isCompletedCollapsed {
                    ForEach(Array(derivedState.completedRenderItems.enumerated()), id: \.element.task.id) { index, item in
                        TaskRowView(
                            task: item.task,
                            fallbackIconSymbolName: project.icon.systemImageName,
                            accentHex: project.color.hexString,
                            showTypeBadge: derivedState.hasMixedTypes,
                            isInOverdueSection: isOverdueSection,
                            tagNameByID: tagNameByID,
                            todayXPSoFar: todayXPSoFar,
                            isGamificationV2Enabled: isGamificationV2Enabled,
                            isTaskDragEnabled: false,
                            highlightedTaskID: highlightedTaskID,
                            metadataPolicy: layoutStyle.taskMetadataPolicy,
                            chromeStyle: layoutStyle.taskChromeStyle,
                            onTap: { onTaskTap?(item.task) },
                            onToggleComplete: { onToggleComplete?(item.task) },
                            onDelete: { onDeleteTask?(item.task) },
                            onReschedule: { onRescheduleTask?(item.task) },
                            onPromoteToFocus: nil
                        )
                        .equatable()

                        if layoutStyle.showsRowDividers && index < derivedState.completedRenderItems.count - 1 {
                            HomeTaskRowDivider()
                        }
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
            LifeBoardFeedback.selection()
        } label: {
            HStack(spacing: LifeBoardTheme.Spacing.sm) {
                Text("Completed")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)

                Text("\(derivedState.completedCount)")
                    .font(.lifeboard(.caption2))
                    .foregroundColor(Color.lifeboard.textQuaternary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.lifeboard.surfaceSecondary)
                    .clipShape(Capsule())

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.lifeboard.textQuaternary)
                    .rotationEffect(.degrees(isCompletedCollapsed ? 0 : 90))
                    .animation(LifeBoardAnimation.snappy, value: isCompletedCollapsed)
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
        return Color.lifeboard.accentPrimary
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
    let accentHex: String?
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool
    let isTaskDragEnabled: Bool
    let highlightedTaskID: UUID?
    let taskChromeStyle: TaskRowChromeStyle
    let taskMetadataPolicy: TaskRowMetadataPolicy
    var onTaskTap: ((TaskDefinition) -> Void)?
    var onToggleComplete: ((TaskDefinition) -> Void)?
    var onDeleteTask: ((TaskDefinition) -> Void)?
    var onRescheduleTask: ((TaskDefinition) -> Void)?
    var onPromoteTaskToFocus: ((TaskDefinition) -> Void)? = nil
    var onTaskDragStarted: ((TaskDefinition) -> Void)?
    var onCompleteHabit: ((HomeHabitRow) -> Void)?
    var onSkipHabit: ((HomeHabitRow) -> Void)?
    var onLapseHabit: ((HomeHabitRow) -> Void)?
    var onCycleHabit: ((HomeHabitRow) -> Void)?
    var onOpenHabit: ((HomeHabitRow) -> Void)?

    init(
        row: HomeTodayRow,
        tagNameByID: [UUID: String],
        accentHex: String? = nil,
        todayXPSoFar: Int?,
        isGamificationV2Enabled: Bool,
        isTaskDragEnabled: Bool,
        highlightedTaskID: UUID?,
        taskChromeStyle: TaskRowChromeStyle = .card,
        taskMetadataPolicy: TaskRowMetadataPolicy = .default,
        onTaskTap: ((TaskDefinition) -> Void)? = nil,
        onToggleComplete: ((TaskDefinition) -> Void)? = nil,
        onDeleteTask: ((TaskDefinition) -> Void)? = nil,
        onRescheduleTask: ((TaskDefinition) -> Void)? = nil,
        onPromoteTaskToFocus: ((TaskDefinition) -> Void)? = nil,
        onTaskDragStarted: ((TaskDefinition) -> Void)? = nil,
        onCompleteHabit: ((HomeHabitRow) -> Void)? = nil,
        onSkipHabit: ((HomeHabitRow) -> Void)? = nil,
        onLapseHabit: ((HomeHabitRow) -> Void)? = nil,
        onCycleHabit: ((HomeHabitRow) -> Void)? = nil,
        onOpenHabit: ((HomeHabitRow) -> Void)? = nil
    ) {
        self.row = row
        self.tagNameByID = tagNameByID
        self.accentHex = accentHex
        self.todayXPSoFar = todayXPSoFar
        self.isGamificationV2Enabled = isGamificationV2Enabled
        self.isTaskDragEnabled = isTaskDragEnabled
        self.highlightedTaskID = highlightedTaskID
        self.taskChromeStyle = taskChromeStyle
        self.taskMetadataPolicy = taskMetadataPolicy
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onDeleteTask = onDeleteTask
        self.onRescheduleTask = onRescheduleTask
        self.onPromoteTaskToFocus = onPromoteTaskToFocus
        self.onTaskDragStarted = onTaskDragStarted
        self.onCompleteHabit = onCompleteHabit
        self.onSkipHabit = onSkipHabit
        self.onLapseHabit = onLapseHabit
        self.onCycleHabit = onCycleHabit
        self.onOpenHabit = onOpenHabit
    }

    var body: some View {
        switch row {
        case .task(let task):
            TaskRowView(
                task: task,
                accentHex: accentHex,
                showTypeBadge: false,
                isInOverdueSection: row.isOverdueLike,
                tagNameByID: tagNameByID,
                todayXPSoFar: todayXPSoFar,
                isGamificationV2Enabled: isGamificationV2Enabled,
                isTaskDragEnabled: isTaskDragEnabled && !task.isComplete,
                highlightedTaskID: highlightedTaskID,
                metadataPolicy: taskMetadataPolicy,
                chromeStyle: taskChromeStyle,
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
                },
                onRowAction: {
                    if let onCycleHabit {
                        onCycleHabit(habit)
                    } else {
                        onOpenHabit?(habit)
                    }
                },
                onOpenDetail: {
                    onOpenHabit?(habit)
                }
            )
        }
    }
}

struct HomeListSectionView: View {
    let section: HomeListSection
    let tagNameByID: [UUID: String]
    let projectsByID: [UUID: Project]
    let lifeAreasByID: [UUID: LifeArea]
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool
    let isTaskDragEnabled: Bool
    let highlightedTaskID: UUID?
    let completedCollapsed: Bool?
    let layoutStyle: TaskListLayoutStyle
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
    var onCycleHabit: ((HomeHabitRow) -> Void)?
    var onOpenHabit: ((HomeHabitRow) -> Void)?
    var headerActionTitle: String? = nil
    var onHeaderAction: (() -> Void)? = nil
    var headerActionAccessibilityID: String? = nil

    @State private var isExpanded: Bool = true

    init(
        section: HomeListSection,
        tagNameByID: [UUID: String],
        projectsByID: [UUID: Project] = [:],
        lifeAreasByID: [UUID: LifeArea] = [:],
        todayXPSoFar: Int?,
        isGamificationV2Enabled: Bool,
        isTaskDragEnabled: Bool,
        highlightedTaskID: UUID?,
        completedCollapsed: Bool?,
        layoutStyle: TaskListLayoutStyle = .inset,
        onTaskTap: ((TaskDefinition) -> Void)? = nil,
        onToggleComplete: ((TaskDefinition) -> Void)? = nil,
        onDeleteTask: ((TaskDefinition) -> Void)? = nil,
        onRescheduleTask: ((TaskDefinition) -> Void)? = nil,
        onPromoteTaskToFocus: ((TaskDefinition) -> Void)? = nil,
        onCompletedCollapsedChange: ((Bool, Int) -> Void)? = nil,
        onTaskDragStarted: ((TaskDefinition) -> Void)? = nil,
        onCompleteHabit: ((HomeHabitRow) -> Void)? = nil,
        onSkipHabit: ((HomeHabitRow) -> Void)? = nil,
        onLapseHabit: ((HomeHabitRow) -> Void)? = nil,
        onCycleHabit: ((HomeHabitRow) -> Void)? = nil,
        onOpenHabit: ((HomeHabitRow) -> Void)? = nil,
        headerActionTitle: String? = nil,
        onHeaderAction: (() -> Void)? = nil,
        headerActionAccessibilityID: String? = nil
    ) {
        self.section = section
        self.tagNameByID = tagNameByID
        self.projectsByID = projectsByID
        self.lifeAreasByID = lifeAreasByID
        self.todayXPSoFar = todayXPSoFar
        self.isGamificationV2Enabled = isGamificationV2Enabled
        self.isTaskDragEnabled = isTaskDragEnabled
        self.highlightedTaskID = highlightedTaskID
        self.completedCollapsed = completedCollapsed
        self.layoutStyle = layoutStyle
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onDeleteTask = onDeleteTask
        self.onRescheduleTask = onRescheduleTask
        self.onPromoteTaskToFocus = onPromoteTaskToFocus
        self.onCompletedCollapsedChange = onCompletedCollapsedChange
        self.onTaskDragStarted = onTaskDragStarted
        self.onCompleteHabit = onCompleteHabit
        self.onSkipHabit = onSkipHabit
        self.onLapseHabit = onLapseHabit
        self.onCycleHabit = onCycleHabit
        self.onOpenHabit = onOpenHabit
        self.headerActionTitle = headerActionTitle
        self.onHeaderAction = onHeaderAction
        self.headerActionAccessibilityID = headerActionAccessibilityID
    }

    private var openRows: [HomeTodayRow] {
        section.rows.filter { !$0.isResolved }
    }

    private var resolvedRows: [HomeTodayRow] {
        section.rows.filter(\.isResolved)
    }

    private var resolvedCount: Int { resolvedRows.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if section.showsHeader {
                TaskSectionHeaderRow(
                    accentColor: accentColor,
                    iconSystemName: section.anchor.iconSystemName,
                    title: section.title,
                    taskCount: section.rows.count,
                    isExpanded: isExpanded,
                    onToggle: {
                        withAnimation(LifeBoardAnimation.snappy) {
                            isExpanded.toggle()
                        }
                        LifeBoardFeedback.selection()
                    },
                    headerActionTitle: headerActionTitle,
                    onHeaderAction: onHeaderAction,
                    headerActionAccessibilityID: headerActionAccessibilityID ?? "home.mixedSection.headerAction.\(section.id)"
                )
                .padding(.horizontal, layoutStyle.headerHorizontalPadding)
            }

            if section.showsHeader == false || isExpanded {
                rowsContent
            }
        }
        .animation(LifeBoardAnimation.snappy, value: isExpanded)
    }

    private var rowsContent: some View {
        VStack(spacing: layoutStyle.rowSpacing) {
            ForEach(Array(openRows.enumerated()), id: \.element.id) { index, row in
                HomeListRowView(
                    row: row,
                    tagNameByID: tagNameByID,
                    accentHex: rowAccentHex(for: row),
                    todayXPSoFar: todayXPSoFar,
                    isGamificationV2Enabled: isGamificationV2Enabled,
                    isTaskDragEnabled: isTaskDragEnabled,
                    highlightedTaskID: highlightedTaskID,
                    taskChromeStyle: layoutStyle.taskChromeStyle,
                    taskMetadataPolicy: layoutStyle.taskMetadataPolicy,
                    onTaskTap: onTaskTap,
                    onToggleComplete: onToggleComplete,
                    onDeleteTask: onDeleteTask,
                    onRescheduleTask: onRescheduleTask,
                    onPromoteTaskToFocus: onPromoteTaskToFocus,
                    onTaskDragStarted: onTaskDragStarted,
                    onCompleteHabit: onCompleteHabit,
                    onSkipHabit: onSkipHabit,
                    onLapseHabit: onLapseHabit,
                    onCycleHabit: onCycleHabit,
                    onOpenHabit: onOpenHabit
                )

                if layoutStyle.showsRowDividers && index < openRows.count - 1 {
                    HomeTaskRowDivider()
                }
            }

            if resolvedCount > 0 {
                if layoutStyle.showsRowDividers && !openRows.isEmpty {
                    HomeTaskRowDivider()
                }

                resolvedToggleRow
                    .padding(.top, layoutStyle == .inset ? 2 : 0)

                if !isResolvedCollapsed {
                    ForEach(Array(resolvedRows.enumerated()), id: \.element.id) { index, row in
                        HomeListRowView(
                            row: row,
                            tagNameByID: tagNameByID,
                            accentHex: rowAccentHex(for: row),
                            todayXPSoFar: todayXPSoFar,
                            isGamificationV2Enabled: isGamificationV2Enabled,
                            isTaskDragEnabled: false,
                            highlightedTaskID: highlightedTaskID,
                            taskChromeStyle: layoutStyle.taskChromeStyle,
                            taskMetadataPolicy: layoutStyle.taskMetadataPolicy,
                            onTaskTap: onTaskTap,
                            onToggleComplete: onToggleComplete,
                            onDeleteTask: onDeleteTask,
                            onRescheduleTask: onRescheduleTask,
                            onPromoteTaskToFocus: nil,
                            onCompleteHabit: onCompleteHabit,
                            onSkipHabit: onSkipHabit,
                            onLapseHabit: onLapseHabit,
                            onCycleHabit: onCycleHabit,
                            onOpenHabit: onOpenHabit
                        )

                        if layoutStyle.showsRowDividers && index < resolvedRows.count - 1 {
                            HomeTaskRowDivider()
                        }
                    }
                }
            }
        }
        .padding(.top, section.showsHeader ? (layoutStyle == .inset ? LifeBoardTheme.Spacing.xs : 0) : 0)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .opacity
        ))
    }

    private var accentColor: Color {
        if section.isOverdueSection {
            return Color.lifeboard.statusDanger
        }

        guard let accentHex = section.accentHex else {
            return Color.lifeboard.accentPrimary
        }
        return LifeBoardHexColor.color(accentHex, fallback: Color.lifeboard.accentPrimary)
    }

    private func rowAccentHex(for row: HomeTodayRow) -> String? {
        if section.showsHeader, let sectionAccentHex = section.accentHex {
            return sectionAccentHex
        }
        return HomeTaskTintResolver.rowAccentHex(
            for: row,
            projectsByID: projectsByID,
            lifeAreasByID: lifeAreasByID
        )
    }

    private var isResolvedCollapsed: Bool {
        guard resolvedCount > 2 else { return false }
        return completedCollapsed ?? true
    }

    private var resolvedToggleRow: some View {
        Button {
            let nextCollapsed = !isResolvedCollapsed
            onCompletedCollapsedChange?(nextCollapsed, resolvedCount)
            LifeBoardFeedback.selection()
        } label: {
            HStack(spacing: LifeBoardTheme.Spacing.sm) {
                Text("Resolved")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)

                Text("\(resolvedCount)")
                    .font(.lifeboard(.caption2))
                    .foregroundColor(Color.lifeboard.textQuaternary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.lifeboard.surfaceSecondary)
                    .clipShape(Capsule())

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.lifeboard.textQuaternary)
                    .rotationEffect(.degrees(isResolvedCollapsed ? 0 : 90))
                    .animation(LifeBoardAnimation.snappy, value: isResolvedCollapsed)
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
        .background(Color.lifeboard.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
