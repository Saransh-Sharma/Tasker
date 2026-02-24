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
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.tasker.surfaceSecondary)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.tasker.textQuaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
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
                .accessibilityIdentifier(headerActionAccessibilityID ?? "home.section.headerAction")
            }
        }
        .padding(.vertical, TaskerTheme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

struct TaskSectionView: View {
    let project: Project
    let tasks: [TaskDefinition]
    let isOverdueSection: Bool
    let completedCollapsed: Bool?
    let isTaskDragEnabled: Bool
    var onTaskTap: ((TaskDefinition) -> Void)?
    var onToggleComplete: ((TaskDefinition) -> Void)?
    var onDeleteTask: ((TaskDefinition) -> Void)?
    var onRescheduleTask: ((TaskDefinition) -> Void)?
    var onCompletedCollapsedChange: ((Bool, Int) -> Void)?
    var onTaskDragStarted: ((TaskDefinition) -> Void)?
    var headerActionTitle: String?
    var onHeaderAction: (() -> Void)?
    var headerActionAccessibilityID: String?

    @State private var isExpanded: Bool = true

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }

    /// Initializes a new instance.
    init(
        project: Project,
        tasks: [TaskDefinition],
        isOverdueSection: Bool = false,
        completedCollapsed: Bool? = nil,
        isTaskDragEnabled: Bool = false,
        onTaskTap: ((TaskDefinition) -> Void)? = nil,
        onToggleComplete: ((TaskDefinition) -> Void)? = nil,
        onDeleteTask: ((TaskDefinition) -> Void)? = nil,
        onRescheduleTask: ((TaskDefinition) -> Void)? = nil,
        onCompletedCollapsedChange: ((Bool, Int) -> Void)? = nil,
        onTaskDragStarted: ((TaskDefinition) -> Void)? = nil,
        headerActionTitle: String? = nil,
        onHeaderAction: (() -> Void)? = nil,
        headerActionAccessibilityID: String? = nil
    ) {
        self.project = project
        self.tasks = tasks
        self.isOverdueSection = isOverdueSection
        self.completedCollapsed = completedCollapsed
        self.isTaskDragEnabled = isTaskDragEnabled
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onDeleteTask = onDeleteTask
        self.onRescheduleTask = onRescheduleTask
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
        VStack(spacing: 6) {
            ForEach(openRenderItems, id: \.renderKey) { item in
                TaskRowView(
                    task: item.task,
                    showTypeBadge: hasMixedTypes,
                    isTaskDragEnabled: isTaskDragEnabled,
                    onTap: { onTaskTap?(item.task) },
                    onToggleComplete: { onToggleComplete?(item.task) },
                    onDelete: { onDeleteTask?(item.task) },
                    onReschedule: { onRescheduleTask?(item.task) },
                    onTaskDragStarted: onTaskDragStarted
                )
                .staggeredAppearance(index: item.index)
            }

            if !completedTasks.isEmpty {
                completedToggleRow
                    .padding(.top, 2)
                    .staggeredAppearance(index: openRenderItems.count)

                if !isCompletedCollapsed {
                    ForEach(completedRenderItems, id: \.renderKey) { item in
                        TaskRowView(
                            task: item.task,
                            showTypeBadge: hasMixedTypes,
                            isTaskDragEnabled: false,
                            onTap: { onTaskTap?(item.task) },
                            onToggleComplete: { onToggleComplete?(item.task) },
                            onDelete: { onDeleteTask?(item.task) },
                            onReschedule: { onRescheduleTask?(item.task) }
                        )
                        .staggeredAppearance(index: item.index + openRenderItems.count + 1)
                    }
                }
            }
        }
    }

    private struct TaskRowRenderItem {
        let index: Int
        let task: TaskDefinition
        let renderKey: String
    }

    private var openRenderItems: [TaskRowRenderItem] {
        openTasks.enumerated().map { index, task in
            TaskRowRenderItem(
                index: index,
                task: task,
                renderKey: taskRenderKey(for: task)
            )
        }
    }

    private var completedRenderItems: [TaskRowRenderItem] {
        completedTasks.enumerated().map { index, task in
            TaskRowRenderItem(
                index: index,
                task: task,
                renderKey: taskRenderKey(for: task)
            )
        }
    }

    private var openTasks: [TaskDefinition] {
        tasks.filter { !$0.isComplete }
    }

    private var completedTasks: [TaskDefinition] {
        tasks
            .filter(\.isComplete)
            .sorted { lhs, rhs in
                let lhsCompleted = lhs.dateCompleted ?? Date.distantPast
                let rhsCompleted = rhs.dateCompleted ?? Date.distantPast
                if lhsCompleted != rhsCompleted {
                    return lhsCompleted > rhsCompleted
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private var isCompletedCollapsed: Bool {
        guard completedTasks.count > 2 else { return false }
        return completedCollapsed ?? true
    }

    private var completedToggleRow: some View {
        Button {
            let nextCollapsed = !isCompletedCollapsed
            onCompletedCollapsedChange?(nextCollapsed, completedTasks.count)
            TaskerFeedback.selection()
        } label: {
            HStack(spacing: TaskerTheme.Spacing.sm) {
                Text("Completed")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text("\(completedTasks.count)")
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

    /// Executes taskRenderKey.
    private func taskRenderKey(for task: TaskDefinition) -> String {
        let completedAt = task.dateCompleted?.timeIntervalSince1970 ?? 0
        return "\(task.id.uuidString)-\(task.isComplete)-\(completedAt)"
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

    /// Whether this section contains both morning and evening tasks
    private var hasMixedTypes: Bool {
        let types = Set(tasks.map(\.type))
        return types.contains(.morning) && types.contains(.evening)
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
