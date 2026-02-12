//
//  HomeTaskSectionBuilder.swift
//  Tasker
//
//  Pure layout builder for Home Today grouping modes.
//

import Foundation

struct HomeTaskProjectSection: Equatable {
    let project: Project
    let tasks: [DomainTask]

    var id: UUID { project.id }
}

struct HomeTaskOverdueGroup: Equatable {
    let project: Project
    let tasks: [DomainTask]

    var id: UUID { project.id }
}

struct HomeTaskTodayLayout: Equatable {
    let inboxSection: HomeTaskProjectSection?
    let overdueGroups: [HomeTaskOverdueGroup]
    let customSections: [HomeTaskProjectSection]
}

enum HomeTaskSectionBuilder {
    static func buildTodayLayout(
        mode: HomeProjectGroupingMode,
        nonOverdueTasks: [DomainTask],
        overdueTasks: [DomainTask],
        projects: [Project],
        customProjectOrderIDs: [UUID]
    ) -> HomeTaskTodayLayout {
        switch mode {
        case .prioritizeOverdue:
            return buildPrioritizeOverdueLayout(
                nonOverdueTasks: nonOverdueTasks,
                overdueTasks: overdueTasks,
                projects: projects,
                customProjectOrderIDs: customProjectOrderIDs
            )
        case .groupByProjects:
            return buildGroupByProjectsLayout(
                nonOverdueTasks: nonOverdueTasks,
                overdueTasks: overdueTasks,
                projects: projects,
                customProjectOrderIDs: customProjectOrderIDs
            )
        }
    }

    private static func buildPrioritizeOverdueLayout(
        nonOverdueTasks: [DomainTask],
        overdueTasks: [DomainTask],
        projects: [Project],
        customProjectOrderIDs: [UUID]
    ) -> HomeTaskTodayLayout {
        let nonOverdueSections = buildProjectSections(
            from: nonOverdueTasks,
            projects: projects,
            customProjectOrderIDs: customProjectOrderIDs,
            includeOverdueInSectionSort: false
        )

        let overdueSections = buildProjectSections(
            from: overdueTasks,
            projects: projects,
            customProjectOrderIDs: customProjectOrderIDs,
            includeOverdueInSectionSort: false
        )

        let inboxSection = nonOverdueSections.first(where: { isInboxProject($0.project) })
        let overdueGroups = overdueSections
            .map { HomeTaskOverdueGroup(project: $0.project, tasks: sortByPriorityThenDue($0.tasks)) }

        let customSections = nonOverdueSections
            .filter { !isInboxProject($0.project) }
            .map { HomeTaskProjectSection(project: $0.project, tasks: sortByPriorityThenDue($0.tasks)) }

        return HomeTaskTodayLayout(
            inboxSection: inboxSection.map { HomeTaskProjectSection(project: $0.project, tasks: sortByPriorityThenDue($0.tasks)) },
            overdueGroups: overdueGroups,
            customSections: customSections
        )
    }

    private static func buildGroupByProjectsLayout(
        nonOverdueTasks: [DomainTask],
        overdueTasks: [DomainTask],
        projects: [Project],
        customProjectOrderIDs: [UUID]
    ) -> HomeTaskTodayLayout {
        let combined = nonOverdueTasks + overdueTasks
        let sections = buildProjectSections(
            from: combined,
            projects: projects,
            customProjectOrderIDs: customProjectOrderIDs,
            includeOverdueInSectionSort: true
        )

        let inboxSection = sections.first(where: { isInboxProject($0.project) })
        let customSections = sections.filter { !isInboxProject($0.project) }

        return HomeTaskTodayLayout(
            inboxSection: inboxSection,
            overdueGroups: [],
            customSections: customSections
        )
    }

    private static func buildProjectSections(
        from tasks: [DomainTask],
        projects: [Project],
        customProjectOrderIDs: [UUID],
        includeOverdueInSectionSort: Bool
    ) -> [HomeTaskProjectSection] {
        guard !tasks.isEmpty else { return [] }

        let grouped = Dictionary(grouping: tasks, by: \.projectID)
        var sections = grouped.map { projectID, groupedTasks -> HomeTaskProjectSection in
            let project = resolveProject(
                projectID: projectID,
                tasks: groupedTasks,
                projects: projects
            )
            let sortedTasks: [DomainTask]
            if includeOverdueInSectionSort {
                sortedTasks = sortWithNonOverdueFirst(groupedTasks)
            } else {
                sortedTasks = sortByPriorityThenDue(groupedTasks)
            }
            return HomeTaskProjectSection(project: project, tasks: sortedTasks)
        }

        sections.sort {
            compareSections(
                lhs: $0,
                rhs: $1,
                customProjectOrderIDs: customProjectOrderIDs
            )
        }

        return sections
    }

    private static func compareSections(
        lhs: HomeTaskProjectSection,
        rhs: HomeTaskProjectSection,
        customProjectOrderIDs: [UUID]
    ) -> Bool {
        let lhsInbox = isInboxProject(lhs.project)
        let rhsInbox = isInboxProject(rhs.project)
        if lhsInbox != rhsInbox {
            return lhsInbox
        }

        if !lhsInbox {
            let lhsRank = customProjectOrderIDs.firstIndex(of: lhs.project.id)
            let rhsRank = customProjectOrderIDs.firstIndex(of: rhs.project.id)
            if let lhsRank, let rhsRank, lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            if lhsRank != nil, rhsRank == nil { return true }
            if lhsRank == nil, rhsRank != nil { return false }
        }

        return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
    }

    private static func resolveProject(
        projectID: UUID,
        tasks: [DomainTask],
        projects: [Project]
    ) -> Project {
        if let project = projects.first(where: { $0.id == projectID }) {
            return project
        }

        let inferredName = tasks
            .compactMap { $0.project?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        if let inferredName {
            if inferredName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame {
                return Project.createInbox()
            }
            return Project(id: projectID, name: inferredName, icon: .folder)
        }

        if projectID == ProjectConstants.inboxProjectID {
            return Project.createInbox()
        }

        return Project(id: projectID, name: "Uncategorized", icon: .folder)
    }

    private static func isInboxProject(_ project: Project) -> Bool {
        project.isInbox || project.id == ProjectConstants.inboxProjectID || project.name.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
    }

    private static func sortByPriorityThenDue(_ tasks: [DomainTask]) -> [DomainTask] {
        tasks.sorted { lhs, rhs in
            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }
            let lhsDate = lhs.dueDate ?? Date.distantFuture
            let rhsDate = rhs.dueDate ?? Date.distantFuture
            return lhsDate < rhsDate
        }
    }

    private static func sortWithNonOverdueFirst(_ tasks: [DomainTask]) -> [DomainTask] {
        tasks.sorted { lhs, rhs in
            if lhs.isOverdue != rhs.isOverdue {
                return !lhs.isOverdue && rhs.isOverdue
            }
            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }
            let lhsDate = lhs.dueDate ?? Date.distantFuture
            let rhsDate = rhs.dueDate ?? Date.distantFuture
            return lhsDate < rhsDate
        }
    }
}
