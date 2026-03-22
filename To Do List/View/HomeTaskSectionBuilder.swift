//
//  HomeTaskSectionBuilder.swift
//  Tasker
//
//  Pure layout builder for Home Today grouping modes.
//

import Foundation

struct HomeTaskProjectSection: Equatable {
    let project: Project
    let tasks: [TaskDefinition]

    var id: UUID { project.id }
}

struct HomeTaskOverdueGroup: Equatable {
    let project: Project
    let tasks: [TaskDefinition]

    var id: UUID { project.id }
}

struct HomeTaskTodayLayout: Equatable {
    let inboxSection: HomeTaskProjectSection?
    let overdueGroups: [HomeTaskOverdueGroup]
    let customSections: [HomeTaskProjectSection]
}

enum HomeTaskSectionBuilder {
    /// Executes buildTodayLayout.
    static func buildTodayLayout(
        mode: HomeProjectGroupingMode,
        nonOverdueTasks: [TaskDefinition],
        overdueTasks: [TaskDefinition],
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

    /// Executes buildPrioritizeOverdueLayout.
    private static func buildPrioritizeOverdueLayout(
        nonOverdueTasks: [TaskDefinition],
        overdueTasks: [TaskDefinition],
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

    /// Executes buildGroupByProjectsLayout.
    private static func buildGroupByProjectsLayout(
        nonOverdueTasks: [TaskDefinition],
        overdueTasks: [TaskDefinition],
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

    /// Executes buildProjectSections.
    private static func buildProjectSections(
        from tasks: [TaskDefinition],
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
            let sortedTasks: [TaskDefinition]
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

    /// Executes compareSections.
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

    /// Executes resolveProject.
    private static func resolveProject(
        projectID: UUID,
        tasks: [TaskDefinition],
        projects: [Project]
    ) -> Project {
        if let project = projects.first(where: { $0.id == projectID }) {
            return project
        }

        let inferredName = tasks
            .compactMap { $0.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) }
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

    /// Executes isInboxProject.
    private static func isInboxProject(_ project: Project) -> Bool {
        project.isInbox || project.id == ProjectConstants.inboxProjectID || project.name.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
    }

    /// Executes sortByPriorityThenDue.
    private static func sortByPriorityThenDue(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.sorted { lhs, rhs in
            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }
            let lhsDate = lhs.dueDate ?? Date.distantFuture
            let rhsDate = rhs.dueDate ?? Date.distantFuture
            return lhsDate < rhsDate
        }
    }

    /// Executes sortWithNonOverdueFirst.
    private static func sortWithNonOverdueFirst(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
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

enum HomeMixedSectionBuilder {
    static func buildTodaySections(
        mode: HomeProjectGroupingMode,
        taskRows: [TaskDefinition],
        habitRows: [HomeHabitRow],
        projects: [Project],
        customProjectOrderIDs: [UUID]
    ) -> [HomeListSection] {
        let rows = taskRows.map(HomeTodayRow.task) + habitRows.map(HomeTodayRow.habit)
        guard rows.isEmpty == false else { return [] }

        switch mode {
        case .prioritizeOverdue:
            let overdueRows = rows.filter(\.isOverdueLike)
            let remainingRows = rows.filter { !$0.isOverdueLike }
            let overdueSections = buildSections(
                rows: overdueRows,
                projects: projects,
                customProjectOrderIDs: customProjectOrderIDs,
                isOverdueSection: true
            )
            let regularSections = buildSections(
                rows: remainingRows,
                projects: projects,
                customProjectOrderIDs: customProjectOrderIDs,
                isOverdueSection: false
            )
            return overdueSections + regularSections
        case .groupByProjects:
            return buildSections(
                rows: rows,
                projects: projects,
                customProjectOrderIDs: customProjectOrderIDs,
                isOverdueSection: false
            )
        }
    }

    static func buildDueTodaySection(rows: [HomeTodayRow]) -> HomeListSection? {
        guard rows.isEmpty == false else { return nil }
        return HomeListSection(anchor: .dueTodaySummary, rows: rows, isOverdueSection: false)
    }

    private static func buildSections(
        rows: [HomeTodayRow],
        projects: [Project],
        customProjectOrderIDs: [UUID],
        isOverdueSection: Bool
    ) -> [HomeListSection] {
        guard rows.isEmpty == false else { return [] }

        let grouped = Dictionary(grouping: rows, by: { anchor(for: $0, projects: projects) })
        var sections = grouped.map { anchor, groupedRows in
            HomeListSection(
                anchor: anchor,
                rows: sortRows(groupedRows),
                isOverdueSection: isOverdueSection
            )
        }

        sections.sort { lhs, rhs in
            compareSections(
                lhs: lhs,
                rhs: rhs,
                customProjectOrderIDs: customProjectOrderIDs
            )
        }
        return sections
    }

    private static func anchor(for row: HomeTodayRow, projects: [Project]) -> HomeSectionAnchor {
        switch row {
        case .task(let task):
            let project = resolveProject(
                projectID: task.projectID,
                projectName: task.projectName,
                projects: projects
            )
            return .project(
                id: project.id,
                name: project.name,
                iconSystemName: project.icon.systemImageName,
                isInbox: isInboxProject(project)
            )
        case .habit(let habit):
            if let projectID = habit.projectID {
                let project = resolveProject(
                    projectID: projectID,
                    projectName: habit.projectName,
                    projects: projects
                )
                return .project(
                    id: project.id,
                    name: project.name,
                    iconSystemName: project.icon.systemImageName,
                    isInbox: isInboxProject(project)
                )
            }

            let lifeAreaName = habit.lifeAreaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Life Area"
                : habit.lifeAreaName
            return .lifeArea(
                id: habit.lifeAreaID,
                name: lifeAreaName,
                iconSystemName: "square.grid.2x2.fill"
            )
        }
    }

    private static func resolveProject(
        projectID: UUID,
        projectName: String?,
        projects: [Project]
    ) -> Project {
        if let project = projects.first(where: { $0.id == projectID }) {
            return project
        }

        let inferredName = projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let inferredName, inferredName.isEmpty == false {
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

    private static func compareSections(
        lhs: HomeListSection,
        rhs: HomeListSection,
        customProjectOrderIDs: [UUID]
    ) -> Bool {
        let lhsAnchor = lhs.anchor
        let rhsAnchor = rhs.anchor

        if lhsAnchor.isInboxProject != rhsAnchor.isInboxProject {
            return lhsAnchor.isInboxProject
        }

        switch (lhsAnchor, rhsAnchor) {
        case let (.project(lhsID, lhsName, _, _), .project(rhsID, rhsName, _, _)):
            let lhsRank = customProjectOrderIDs.firstIndex(of: lhsID)
            let rhsRank = customProjectOrderIDs.firstIndex(of: rhsID)
            if let lhsRank, let rhsRank, lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            if lhsRank != nil, rhsRank == nil { return true }
            if lhsRank == nil, rhsRank != nil { return false }
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending

        case (.project, .lifeArea):
            return true
        case (.lifeArea, .project):
            return false
        case let (.lifeArea(_, lhsName, _), .lifeArea(_, rhsName, _)):
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        default:
            return lhs.id < rhs.id
        }
    }

    private static func sortRows(_ rows: [HomeTodayRow]) -> [HomeTodayRow] {
        rows.sorted { lhs, rhs in
            let lhsCategory = sortCategory(for: lhs)
            let rhsCategory = sortCategory(for: rhs)
            if lhsCategory != rhsCategory {
                return lhsCategory < rhsCategory
            }

            let lhsDue = lhs.dueDate ?? Date.distantFuture
            let rhsDue = rhs.dueDate ?? Date.distantFuture
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func sortCategory(for row: HomeTodayRow) -> Int {
        if row.isResolved {
            return 4
        }

        if row.isOverdueLike {
            return 0
        }

        switch row {
        case .task(let task):
            return task.dueDate == nil ? 3 : 1
        case .habit(let habit):
            switch habit.state {
            case .due:
                return 1
            case .tracking:
                return 2
            case .overdue:
                return 0
            case .completedToday, .lapsedToday, .skippedToday:
                return 4
            }
        }
    }

    private static func isInboxProject(_ project: Project) -> Bool {
        project.isInbox
            || project.id == ProjectConstants.inboxProjectID
            || project.name.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
    }
}
