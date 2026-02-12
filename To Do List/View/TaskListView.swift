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
    var onTaskTap: ((DomainTask) -> Void)? = nil
    var onToggleComplete: ((DomainTask) -> Void)? = nil
    var onDeleteTask: ((DomainTask) -> Void)? = nil
    var onRescheduleTask: ((DomainTask) -> Void)? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: TaskerTheme.Spacing.sectionGap) {
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
    }

    // MARK: - Grouping Logic

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
                print("HOME_PROJECT_MAP match=id projectID=\(projectID.uuidString) taskProject=\(taskProjectName ?? "nil")")
                project = projectByID
            } else if let taskProjectName,
                      let projectByName = projects.first(where: { $0.name.caseInsensitiveCompare(taskProjectName) == .orderedSame }) {
                print("HOME_PROJECT_MAP match=name projectID=\(projectID.uuidString) taskProject=\(taskProjectName)")
                project = projectByName
            } else if let taskProjectName {
                print("HOME_PROJECT_MAP match=synthetic projectID=\(projectID.uuidString) taskProject=\(taskProjectName)")
                project = Project(
                    id: projectID,
                    name: taskProjectName,
                    icon: taskProjectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame ? .inbox : .folder
                )
            } else {
                print("HOME_PROJECT_MAP match=uncategorized projectID=\(projectID.uuidString) taskProject=nil")
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

    private var allTasksEmpty: Bool {
        morningTasks.isEmpty && eveningTasks.isEmpty && overdueTasks.isEmpty
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

            Text("No tasks for today")
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textQuaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TaskerTheme.Spacing.xxxl)
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
