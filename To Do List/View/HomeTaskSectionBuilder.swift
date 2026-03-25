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
        taskRows: [TaskDefinition],
        habitRows: [HomeHabitRow],
        projects: [Project],
        lifeAreas: [LifeArea]
    ) -> [HomeListSection] {
        let rows = taskRows.map(HomeTodayRow.task) + habitRows.map(HomeTodayRow.habit)
        guard rows.isEmpty == false else { return [] }

        return buildSections(
            rows: rows,
            projects: projects,
            lifeAreas: lifeAreas,
            isOverdueSection: false
        )
    }

    static func buildDueTodaySection(rows: [HomeTodayRow]) -> HomeListSection? {
        guard rows.isEmpty == false else { return nil }
        return HomeListSection(anchor: .dueTodaySummary, rows: rows, isOverdueSection: false)
    }

    private static func buildSections(
        rows: [HomeTodayRow],
        projects: [Project],
        lifeAreas: [LifeArea],
        isOverdueSection: Bool
    ) -> [HomeListSection] {
        guard rows.isEmpty == false else { return [] }

        let grouped = Dictionary(grouping: rows, by: { anchor(for: $0, projects: projects, lifeAreas: lifeAreas) })
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
                rhs: rhs
            )
        }
        return sections
    }

    private static func anchor(
        for row: HomeTodayRow,
        projects: [Project],
        lifeAreas: [LifeArea]
    ) -> HomeSectionAnchor {
        switch row {
        case .task(let task):
            if let lifeArea = resolveLifeArea(for: task, projects: projects, lifeAreas: lifeAreas) {
                return .lifeArea(
                    id: lifeArea.id,
                    name: lifeArea.name,
                    iconSystemName: "square.grid.2x2.fill"
                )
            }
            return .project(
                id: task.projectID,
                name: task.projectName ?? ProjectConstants.inboxProjectName,
                iconSystemName: "tray.full.fill",
                isInbox: task.projectID == ProjectConstants.inboxProjectID
            )
        case .habit(let habit):
            let resolvedLifeAreaName = habit.lifeAreaName.trimmingCharacters(in: .whitespacesAndNewlines)
            if resolvedLifeAreaName.isEmpty == false {
                return .lifeArea(
                    id: habit.lifeAreaID,
                    name: resolvedLifeAreaName,
                    iconSystemName: "square.grid.2x2.fill"
                )
            }

            return .lifeArea(
                id: habit.lifeAreaID,
                name: "Life Area",
                iconSystemName: "square.grid.2x2.fill"
            )
        }
    }

    private static func resolveLifeArea(
        for task: TaskDefinition,
        projects: [Project],
        lifeAreas: [LifeArea]
    ) -> LifeArea? {
        if let directID = task.lifeAreaID,
           let direct = lifeAreas.first(where: { $0.id == directID }) {
            return direct
        }

        if let project = projects.first(where: { $0.id == task.projectID }),
           let projectLifeAreaID = project.lifeAreaID,
           let lifeArea = lifeAreas.first(where: { $0.id == projectLifeAreaID }) {
            return lifeArea
        }

        return nil
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
        rhs: HomeListSection
    ) -> Bool {
        let lhsAnchor = lhs.anchor
        let rhsAnchor = rhs.anchor

        switch (lhsAnchor, rhsAnchor) {
        case let (.lifeArea(_, lhsName, _), .lifeArea(_, rhsName, _)):
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        case (.lifeArea, .project):
            return true
        case (.project, .lifeArea):
            return false
        case let (.project(_, lhsName, _, lhsInbox), .project(_, rhsName, _, rhsInbox)):
            if lhsInbox != rhsInbox {
                return !lhsInbox && rhsInbox
            }
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
            return 6
        }

        if row.isOverdueLike {
            return 0
        }

        switch row {
        case .task(let task):
            let isInbox = task.projectID == ProjectConstants.inboxProjectID
            if isInbox, task.dueDate != nil {
                return 2
            }
            return task.dueDate == nil ? 5 : 1
        case .habit(let habit):
            switch habit.state {
            case .due:
                return habit.kind == .negative ? 4 : 3
            case .tracking:
                return 5
            case .overdue:
                return 0
            case .completedToday, .lapsedToday, .skippedToday:
                return 6
            }
        }
    }

    private static func isInboxProject(_ project: Project) -> Bool {
        project.isInbox
            || project.id == ProjectConstants.inboxProjectID
            || project.name.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
    }
}
