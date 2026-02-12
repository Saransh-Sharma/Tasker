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

struct TaskListView: View {
    let morningTasks: [DomainTask]
    let eveningTasks: [DomainTask]
    let overdueTasks: [DomainTask]
    let projects: [Project]
    let doneTimelineTasks: [DomainTask]
    let activeQuickView: HomeQuickView?
    let emptyStateMessage: String?
    let emptyStateActionTitle: String?
    var onTaskTap: ((DomainTask) -> Void)? = nil
    var onToggleComplete: ((DomainTask) -> Void)? = nil
    var onDeleteTask: ((DomainTask) -> Void)? = nil
    var onRescheduleTask: ((DomainTask) -> Void)? = nil
    var onEmptyStateAction: (() -> Void)? = nil

    init(
        morningTasks: [DomainTask],
        eveningTasks: [DomainTask],
        overdueTasks: [DomainTask],
        projects: [Project],
        doneTimelineTasks: [DomainTask] = [],
        activeQuickView: HomeQuickView? = nil,
        emptyStateMessage: String? = nil,
        emptyStateActionTitle: String? = nil,
        onTaskTap: ((DomainTask) -> Void)? = nil,
        onToggleComplete: ((DomainTask) -> Void)? = nil,
        onDeleteTask: ((DomainTask) -> Void)? = nil,
        onRescheduleTask: ((DomainTask) -> Void)? = nil,
        onEmptyStateAction: (() -> Void)? = nil
    ) {
        self.morningTasks = morningTasks
        self.eveningTasks = eveningTasks
        self.overdueTasks = overdueTasks
        self.projects = projects
        self.doneTimelineTasks = doneTimelineTasks
        self.activeQuickView = activeQuickView
        self.emptyStateMessage = emptyStateMessage
        self.emptyStateActionTitle = emptyStateActionTitle
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onDeleteTask = onDeleteTask
        self.onRescheduleTask = onRescheduleTask
        self.onEmptyStateAction = onEmptyStateAction
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: TaskerTheme.Spacing.sectionGap) {
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
                    .frame(height: TaskerTheme.Spacing.tabBarHeight)
            }
            .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        }
        .accessibilityIdentifier("home.taskList.scrollView")
    }

    // MARK: - Regular Grouping Logic

    @ViewBuilder
    private var regularTaskContent: some View {
        // Overdue section (always first when present)
        if !overdueTasks.isEmpty {
            TaskSectionView(
                project: overdueProject,
                tasks: overdueTasks,
                isOverdueSection: true,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask
            )
            .staggeredAppearance(index: 0)
        }

        // Project sections (Inbox first, then alphabetical)
        ForEach(Array(sortedProjectSections.enumerated()), id: \.element.id) { index, section in
            TaskSectionView(
                project: section.project,
                tasks: section.tasks,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask
            )
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
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask
            )
            .staggeredAppearance(index: index)
        }
    }

    private var sortedProjectSections: [ProjectSection] {
        // Combine morning + evening (overdue is handled separately)
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
