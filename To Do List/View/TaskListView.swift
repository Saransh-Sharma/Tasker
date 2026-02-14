//
//  TaskListView.swift
//  Tasker
//
//  Top-level task list with project-grouped collapsible sections.
//  Groups tasks by projectID, sorts Overdue > Inbox > alphabetical.
//  Part of the "Obsidian & Gems" design system.
//

import SwiftUI

// MARK: - Task List View

private struct TaskListScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TaskListView: View {
    private static let defaultBottomContentInset: CGFloat = 80

    let morningTasks: [DomainTask]
    let eveningTasks: [DomainTask]
    let overdueTasks: [DomainTask]
    let inlineCompletedTasks: [DomainTask]
    let projects: [Project]
    let doneTimelineTasks: [DomainTask]
    let activeQuickView: HomeQuickView?
    let projectGroupingMode: HomeProjectGroupingMode
    let customProjectOrderIDs: [UUID]
    let emptyStateMessage: String?
    let emptyStateActionTitle: String?
    let isTaskDragEnabled: Bool
    var onTaskTap: ((DomainTask) -> Void)? = nil
    var onToggleComplete: ((DomainTask) -> Void)? = nil
    var onDeleteTask: ((DomainTask) -> Void)? = nil
    var onRescheduleTask: ((DomainTask) -> Void)? = nil
    var onReorderCustomProjects: (([UUID]) -> Void)? = nil
    var onCompletedSectionToggle: ((UUID, Bool, Int) -> Void)? = nil
    var onEmptyStateAction: (() -> Void)? = nil
    var onTaskDragStarted: ((DomainTask) -> Void)? = nil
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil
    let bottomContentInset: CGFloat
    @State private var draggingCustomProjectID: UUID?
    @State private var isCompletedCollapsedBySection: [UUID: Bool] = [:]
    private let scrollCoordinateSpace = "home.taskList.scrollSpace"

    init(
        morningTasks: [DomainTask],
        eveningTasks: [DomainTask],
        overdueTasks: [DomainTask],
        inlineCompletedTasks: [DomainTask] = [],
        projects: [Project],
        doneTimelineTasks: [DomainTask] = [],
        activeQuickView: HomeQuickView? = nil,
        projectGroupingMode: HomeProjectGroupingMode = .defaultMode,
        customProjectOrderIDs: [UUID] = [],
        emptyStateMessage: String? = nil,
        emptyStateActionTitle: String? = nil,
        isTaskDragEnabled: Bool = false,
        onTaskTap: ((DomainTask) -> Void)? = nil,
        onToggleComplete: ((DomainTask) -> Void)? = nil,
        onDeleteTask: ((DomainTask) -> Void)? = nil,
        onRescheduleTask: ((DomainTask) -> Void)? = nil,
        onReorderCustomProjects: (([UUID]) -> Void)? = nil,
        onCompletedSectionToggle: ((UUID, Bool, Int) -> Void)? = nil,
        onEmptyStateAction: (() -> Void)? = nil,
        onTaskDragStarted: ((DomainTask) -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        bottomContentInset: CGFloat = TaskListView.defaultBottomContentInset
    ) {
        self.morningTasks = morningTasks
        self.eveningTasks = eveningTasks
        self.overdueTasks = overdueTasks
        self.inlineCompletedTasks = inlineCompletedTasks
        self.projects = projects
        self.doneTimelineTasks = doneTimelineTasks
        self.activeQuickView = activeQuickView
        self.projectGroupingMode = projectGroupingMode
        self.customProjectOrderIDs = customProjectOrderIDs
        self.emptyStateMessage = emptyStateMessage
        self.emptyStateActionTitle = emptyStateActionTitle
        self.isTaskDragEnabled = isTaskDragEnabled
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onDeleteTask = onDeleteTask
        self.onRescheduleTask = onRescheduleTask
        self.onReorderCustomProjects = onReorderCustomProjects
        self.onCompletedSectionToggle = onCompletedSectionToggle
        self.onEmptyStateAction = onEmptyStateAction
        self.onTaskDragStarted = onTaskDragStarted
        self.onScrollOffsetChange = onScrollOffsetChange
        self.bottomContentInset = bottomContentInset
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: TaskerTheme.Spacing.lg) {
                Color.clear
                    .frame(height: 0)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TaskListScrollOffsetPreferenceKey.self,
                                value: max(0, -proxy.frame(in: .named(scrollCoordinateSpace)).minY)
                            )
                        }
                    )

                if activeQuickView == .done {
                    doneTimelineContent
                } else {
                    regularTaskContent
                }

                // Empty state
                if allTasksEmpty {
                    emptyStateView
                        .staggeredAppearance(index: 0)
                }

                // Bottom spacer for tab bar
                Spacer()
                    .frame(height: bottomContentInset)
            }
            .padding(.horizontal, TaskerTheme.Spacing.lg)
        }
        .coordinateSpace(name: scrollCoordinateSpace)
        .onPreferenceChange(TaskListScrollOffsetPreferenceKey.self) { offset in
            onScrollOffsetChange?(offset)
        }
        .accessibilityIdentifier("home.taskList.scrollView")
    }

    // MARK: - Regular Grouping Logic

    @ViewBuilder
    private var regularTaskContent: some View {
        if activeQuickView == .today {
            todayRegularTaskContent
        } else {
            legacyRegularTaskContent
        }
    }

    @ViewBuilder
    private var todayRegularTaskContent: some View {
        let completedByID = inlineCompletedTasks.reduce(into: [UUID: DomainTask]()) { partialResult, task in
            partialResult[task.id] = task
        }
        let reconciledMorning = morningTasks.map { completedByID[$0.id] ?? $0 }
        let reconciledEvening = eveningTasks.map { completedByID[$0.id] ?? $0 }
        let reconciledOverdue = overdueTasks.map { completedByID[$0.id] ?? $0 }

        let baseNonOverdue = reconciledMorning + reconciledEvening
        let baseIDs = Set((baseNonOverdue + reconciledOverdue).map(\.id))
        let additionalCompleted = inlineCompletedTasks.filter { !baseIDs.contains($0.id) }
        let mergedNonOverdue = baseNonOverdue + additionalCompleted.filter { !$0.isOverdue }
        let mergedOverdue = reconciledOverdue + additionalCompleted.filter(\.isOverdue)

        let layout = HomeTaskSectionBuilder.buildTodayLayout(
            mode: projectGroupingMode,
            nonOverdueTasks: mergedNonOverdue,
            overdueTasks: mergedOverdue,
            projects: projects,
            customProjectOrderIDs: customProjectOrderIDs
        )
        let hasInboxSection = layout.inboxSection?.tasks.isEmpty == false
        let hasOverdueSection = projectGroupingMode == .prioritizeOverdue && !layout.overdueGroups.isEmpty

        if let inboxSection = layout.inboxSection, !inboxSection.tasks.isEmpty {
            TaskSectionView(
                project: inboxSection.project,
                tasks: inboxSection.tasks,
                completedCollapsed: isCompletedCollapsedBySection[inboxSection.project.id],
                isTaskDragEnabled: isTaskDragEnabled,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[inboxSection.project.id] = collapsed
                    onCompletedSectionToggle?(inboxSection.project.id, collapsed, count)
                },
                onTaskDragStarted: onTaskDragStarted
            )
            .id(sectionRenderKey(projectID: inboxSection.project.id, tasks: inboxSection.tasks))
            .staggeredAppearance(index: 0)
        }

        if projectGroupingMode == .prioritizeOverdue, !layout.overdueGroups.isEmpty {
            OverdueGroupedSectionView(
                groups: layout.overdueGroups,
                isTaskDragEnabled: isTaskDragEnabled,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onTaskDragStarted: onTaskDragStarted
            )
            .id(overdueGroupsRenderKey(layout.overdueGroups))
            .staggeredAppearance(index: hasInboxSection ? 1 : 0)
        }

        let currentCustomOrder = layout.customSections.map(\.project.id)
        let customStartIndex = (hasInboxSection ? 1 : 0) + (hasOverdueSection ? 1 : 0)
        ForEach(Array(layout.customSections.enumerated()), id: \.element.id) { index, section in
            TaskSectionView(
                project: section.project,
                tasks: section.tasks,
                completedCollapsed: isCompletedCollapsedBySection[section.project.id],
                isTaskDragEnabled: isTaskDragEnabled,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[section.project.id] = collapsed
                    onCompletedSectionToggle?(section.project.id, collapsed, count)
                },
                onTaskDragStarted: onTaskDragStarted
            )
            .id(sectionRenderKey(projectID: section.project.id, tasks: section.tasks))
            .staggeredAppearance(index: customStartIndex + index)
            .onDrag {
                draggingCustomProjectID = section.project.id
                return NSItemProvider(object: section.project.id.uuidString as NSString)
            }
            .onDrop(
                of: ["public.text"],
                delegate: CustomProjectSectionDropDelegate(
                    targetProjectID: section.project.id,
                    draggedProjectID: $draggingCustomProjectID,
                    currentCustomOrder: currentCustomOrder,
                    onReorder: { reordered in
                        onReorderCustomProjects?(reordered)
                    }
                )
            )
        }
    }

    @ViewBuilder
    private var legacyRegularTaskContent: some View {
        if !overdueTasks.isEmpty {
            TaskSectionView(
                project: overdueProject,
                tasks: overdueTasks,
                isOverdueSection: true,
                completedCollapsed: isCompletedCollapsedBySection[overdueProject.id],
                isTaskDragEnabled: isTaskDragEnabled,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[overdueProject.id] = collapsed
                    onCompletedSectionToggle?(overdueProject.id, collapsed, count)
                },
                onTaskDragStarted: onTaskDragStarted
            )
            .id(sectionRenderKey(projectID: overdueProject.id, tasks: overdueTasks))
            .staggeredAppearance(index: 0)
        }

        ForEach(Array(legacySortedProjectSections.enumerated()), id: \.element.id) { index, section in
            TaskSectionView(
                project: section.project,
                tasks: section.tasks,
                completedCollapsed: isCompletedCollapsedBySection[section.project.id],
                isTaskDragEnabled: isTaskDragEnabled,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[section.project.id] = collapsed
                    onCompletedSectionToggle?(section.project.id, collapsed, count)
                },
                onTaskDragStarted: onTaskDragStarted
            )
            .id(sectionRenderKey(projectID: section.project.id, tasks: section.tasks))
            .staggeredAppearance(index: index + (overdueTasks.isEmpty ? 0 : 1))
        }
    }

    @ViewBuilder
    private var doneTimelineContent: some View {
        let grouped = groupedDoneTimeline

        ForEach(Array(grouped.enumerated()), id: \.element.id) { index, group in
            TaskSectionView(
                project: group.project,
                tasks: group.tasks,
                isOverdueSection: false,
                completedCollapsed: isCompletedCollapsedBySection[group.project.id],
                isTaskDragEnabled: false,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[group.project.id] = collapsed
                    onCompletedSectionToggle?(group.project.id, collapsed, count)
                }
            )
            .id(sectionRenderKey(projectID: group.project.id, tasks: group.tasks))
            .staggeredAppearance(index: index)
        }
    }

    private var legacySortedProjectSections: [ProjectSection] {
        let allTasks = morningTasks + eveningTasks

        guard !allTasks.isEmpty else { return [] }

        // Group by projectID
        let grouped = Dictionary(grouping: allTasks, by: \.projectID)

        // Map to sections with project metadata
        var sections: [ProjectSection] = grouped.map { projectID, tasks in
            let taskProjectName = normalizedTaskProjectName(from: tasks)
            let project: Project

            if let projectByID = projects.first(where: { $0.id == projectID }) {
                project = projectByID
            } else if let taskProjectName,
                      let projectByName = projects.first(where: { $0.name.caseInsensitiveCompare(taskProjectName) == .orderedSame }) {
                project = projectByName
            } else if let taskProjectName {
                project = Project(
                    id: projectID,
                    name: taskProjectName,
                    icon: taskProjectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame ? .inbox : .folder
                )
            } else {
                project = Project(id: projectID, name: "Uncategorized", icon: .folder)
            }
            return ProjectSection(project: project, tasks: tasks)
        }

        // Sort: Inbox first, then alphabetical by name
        sections.sort { s1, s2 in
            let s1Inbox = isInboxSection(s1.project)
            let s2Inbox = isInboxSection(s2.project)
            if s1Inbox { return true }
            if s2Inbox { return false }
            return s1.project.name.localizedCaseInsensitiveCompare(s2.project.name) == .orderedAscending
        }

        return sections
    }

    private var groupedDoneTimeline: [ProjectSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: doneTimelineTasks) { task -> Date in
            let completionDate = task.dateCompleted ?? Date.distantPast
            return calendar.startOfDay(for: completionDate)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return grouped.keys.sorted(by: >).map { day in
            let dayTasks = (grouped[day] ?? []).sorted { lhs, rhs in
                if lhs.priority.scorePoints != rhs.priority.scorePoints {
                    return lhs.priority.scorePoints > rhs.priority.scorePoints
                }
                let lhsCompletion = lhs.dateCompleted ?? Date.distantPast
                let rhsCompletion = rhs.dateCompleted ?? Date.distantPast
                return lhsCompletion > rhsCompletion
            }

            let project = Project(
                id: UUID(),
                name: formatter.string(from: day),
                icon: .folder
            )
            return ProjectSection(project: project, tasks: dayTasks)
        }
    }

    private var allTasksEmpty: Bool {
        if activeQuickView == .done {
            return doneTimelineTasks.isEmpty
        }

        return morningTasks.isEmpty && eveningTasks.isEmpty && overdueTasks.isEmpty
    }

    private func sectionRenderKey(projectID: UUID, tasks: [DomainTask]) -> String {
        let rows = tasks.map(taskRenderKey(for:)).joined(separator: ",")
        return "\(projectID.uuidString)|\(rows)"
    }

    private func overdueGroupsRenderKey(_ groups: [HomeTaskOverdueGroup]) -> String {
        groups
            .map { group in
                sectionRenderKey(projectID: group.project.id, tasks: group.tasks)
            }
            .joined(separator: ";")
    }

    private func taskRenderKey(for task: DomainTask) -> String {
        let completedAt = task.dateCompleted?.timeIntervalSince1970 ?? 0
        return "\(task.id.uuidString)-\(task.isComplete)-\(completedAt)"
    }

    private func normalizedTaskProjectName(from tasks: [DomainTask]) -> String? {
        tasks
            .compactMap { $0.project?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private func isInboxSection(_ project: Project) -> Bool {
        project.isInbox || project.name.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
    }

    /// Synthetic project for the overdue section header
    private var overdueProject: Project {
        Project(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            name: "Overdue",
            icon: .flag
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: TaskerTheme.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Color.tasker.accentPrimary.opacity(0.5))

            Text("All clear")
                .font(.tasker(.title3))
                .foregroundColor(Color.tasker.textTertiary)

            Text(resolvedEmptyStateMessage)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textQuaternary)

            if let title = emptyStateActionTitle {
                Button(title) {
                    onEmptyStateAction?()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.tasker.accentPrimary)
                .padding(.top, TaskerTheme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TaskerTheme.Spacing.xxxl)
    }

    private var resolvedEmptyStateMessage: String {
        if let emptyStateMessage {
            return emptyStateMessage
        }

        switch activeQuickView {
        case .upcoming:
            return "No upcoming tasks in 14 days"
        case .done:
            return "No completed tasks in last 30 days"
        case .morning:
            return "No morning tasks. Add one to start strong."
        case .evening:
            return "No evening tasks. Plan your wind-down."
        case .today, .none:
            return "No tasks for today"
        }
    }
}

// MARK: - Project Section Model

private struct ProjectSection: Identifiable {
    let project: Project
    let tasks: [DomainTask]
    var id: UUID { project.id }
}

private struct OverdueGroupedSectionView: View {
    let groups: [HomeTaskOverdueGroup]
    let isTaskDragEnabled: Bool
    var onTaskTap: ((DomainTask) -> Void)?
    var onToggleComplete: ((DomainTask) -> Void)?
    var onDeleteTask: ((DomainTask) -> Void)?
    var onRescheduleTask: ((DomainTask) -> Void)?
    var onTaskDragStarted: ((DomainTask) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
            HStack(spacing: TaskerTheme.Spacing.md) {
                Circle()
                    .fill(Color.tasker(.taskOverdue))
                    .frame(width: 4, height: 4)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.tasker(.taskOverdue))
                    .frame(width: 20, alignment: .center)
                Text("Overdue")
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.textPrimary)
                Text("\(groups.reduce(0) { $0 + $1.tasks.count })")
                    .font(.tasker(.caption2))
                    .fontWeight(.medium)
                    .foregroundColor(Color.tasker.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(Capsule())
            }
            .padding(.vertical, TaskerTheme.Spacing.md)

            ForEach(Array(groups.enumerated()), id: \.element.project.id) { index, group in
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                    Text(group.project.name)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .padding(.top, index == 0 ? 0 : TaskerTheme.Spacing.sm)

                    ForEach(Array(group.tasks.enumerated()), id: \.element.id) { taskIndex, task in
                        TaskRowView(
                            task: task,
                            showTypeBadge: false,
                            isTaskDragEnabled: isTaskDragEnabled,
                            onTap: { onTaskTap?(task) },
                            onToggleComplete: { onToggleComplete?(task) },
                            onDelete: { onDeleteTask?(task) },
                            onReschedule: { onRescheduleTask?(task) },
                            onTaskDragStarted: onTaskDragStarted
                        )
                        .id(taskRenderKey(for: task))
                        .staggeredAppearance(index: taskIndex)
                    }
                }
            }
        }
    }

    private func taskRenderKey(for task: DomainTask) -> String {
        let completedAt = task.dateCompleted?.timeIntervalSince1970 ?? 0
        return "\(task.id.uuidString)-\(task.isComplete)-\(completedAt)"
    }

}

private struct CustomProjectSectionDropDelegate: DropDelegate {
    let targetProjectID: UUID
    @Binding var draggedProjectID: UUID?
    let currentCustomOrder: [UUID]
    let onReorder: ([UUID]) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedProjectID, draggedProjectID != targetProjectID else { return }
        guard let fromIndex = currentCustomOrder.firstIndex(of: draggedProjectID),
              let toIndex = currentCustomOrder.firstIndex(of: targetProjectID),
              fromIndex != toIndex else { return }

        var reordered = currentCustomOrder
        let moved = reordered.remove(at: fromIndex)
        reordered.insert(moved, at: toIndex)
        onReorder(reordered)
        self.draggedProjectID = targetProjectID
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedProjectID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Preview

#if DEBUG
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        let inboxProject = Project.createInbox()
        let workProject = Project(name: "Work", icon: .work)
        let sideProject = Project(name: "Side Project", icon: .creative)

        TaskListView(
            morningTasks: [
                DomainTask(
                    name: "Morning standup call with the engineering team",
                    details: "Discuss sprint priorities and blockers",
                    type: .morning,
                    priority: .high,
                    dueDate: Date()
                ),
                DomainTask(
                    projectID: workProject.id,
                    name: "Review quarterly OKRs and prepare status updates for leadership review",
                    type: .morning,
                    priority: .max,
                    dueDate: Date()
                ),
                DomainTask(
                    projectID: sideProject.id,
                    name: "Design landing page wireframes",
                    details: "Focus on mobile-first layout with clear CTA hierarchy",
                    type: .morning,
                    priority: .low,
                    dueDate: Date().addingTimeInterval(86400)
                )
            ],
            eveningTasks: [
                DomainTask(
                    name: "Evening reading — Atomic Habits chapter 4",
                    type: .evening,
                    priority: .none
                ),
                DomainTask(
                    projectID: workProject.id,
                    name: "Write weekly retrospective notes",
                    details: "Include wins, challenges, and next week goals",
                    type: .evening,
                    priority: .low,
                    dueDate: Date()
                )
            ],
            overdueTasks: [
                DomainTask(
                    name: "Submit expense report for January travel",
                    type: .morning,
                    priority: .max,
                    dueDate: Date().addingTimeInterval(-172800)
                )
            ],
            projects: [inboxProject, workProject, sideProject]
        )
        .background(Color.tasker.bgCanvas)
    }
}
#endif
