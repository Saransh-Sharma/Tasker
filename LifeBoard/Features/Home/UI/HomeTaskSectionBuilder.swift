//
//  HomeTaskSectionBuilder.swift
//  LifeBoard
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

/// Builds time-horizon sections (Overdue / Today / This week / Next week / Later / Someday)
/// for the Home "stream" lenses: the Upcoming lens and per-project lenses. Unlike
/// `HomeMixedSectionBuilder`, which groups by project/life-area for a single day, this groups
/// a forward-looking set of tasks by when they are due, keeping undated work visible in Someday.
enum HomeHorizonSectionBuilder {
    static func buildHorizonSections(
        taskRows: [TaskDefinition],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [HomeListSection] {
        guard taskRows.isEmpty == false else { return [] }

        let boundaries = HorizonBoundaries(referenceDate: referenceDate, calendar: calendar)
        let grouped = Dictionary(grouping: taskRows) { task in
            bucket(for: task, boundaries: boundaries)
        }

        return grouped
            .map { bucket, tasks -> HomeListSection in
                HomeListSection(
                    anchor: .horizon(bucket: bucket),
                    rows: sortByPriorityThenDue(tasks).map(HomeTodayRow.task),
                    accentHex: bucket.accentHex
                )
            }
            .sorted { $0.anchor.horizonSortIndex < $1.anchor.horizonSortIndex }
    }

    static func bucket(for task: TaskDefinition, boundaries: HorizonBoundaries) -> HomeHorizonBucket {
        guard let dueDate = task.dueDate else {
            return undatedBucket(for: task.planningBucket)
        }

        if dueDate < boundaries.startOfToday {
            return .overdue
        }
        if dueDate < boundaries.startOfTomorrow {
            return .today
        }
        if dueDate < boundaries.startOfNextWeek {
            return .thisWeek
        }
        if dueDate < boundaries.startOfWeekAfterNext {
            return .nextWeek
        }
        return .later
    }

    private static func undatedBucket(for planningBucket: TaskPlanningBucket) -> HomeHorizonBucket {
        switch planningBucket {
        case .thisWeek:
            return .thisWeek
        case .nextWeek:
            return .nextWeek
        case .later:
            return .later
        case .today, .someday:
            return .someday
        }
    }

    static func sortByPriorityThenDue(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.sorted { lhs, rhs in
            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }
            let lhsDate = lhs.dueDate ?? Date.distantFuture
            let rhsDate = rhs.dueDate ?? Date.distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    struct HorizonBoundaries {
        let startOfToday: Date
        let startOfTomorrow: Date
        let startOfNextWeek: Date
        let startOfWeekAfterNext: Date

        init(referenceDate: Date, calendar: Calendar) {
            let startOfToday = calendar.startOfDay(for: referenceDate)
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
            let startOfNextWeek = weekInterval?.end
                ?? calendar.date(byAdding: .day, value: 7, to: startOfToday)
                ?? startOfToday
            let startOfWeekAfterNext = calendar.date(byAdding: .day, value: 7, to: startOfNextWeek) ?? startOfNextWeek

            self.startOfToday = startOfToday
            self.startOfTomorrow = startOfTomorrow
            // Guard against today being the final day of the calendar week (next-week start
            // could otherwise fall on or before tomorrow, collapsing the "This week" bucket).
            self.startOfNextWeek = max(startOfNextWeek, startOfTomorrow)
            self.startOfWeekAfterNext = max(startOfWeekAfterNext, self.startOfNextWeek)
        }
    }
}

/// Life-area stream lens: horizon buckets subdivided by project within each bucket.
enum HomeLifeAreaStreamSectionBuilder {
    private struct GroupKey: Hashable {
        let bucket: HomeHorizonBucket
        let projectID: UUID
    }

    static func buildSections(
        taskRows: [TaskDefinition],
        projects: [Project],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [HomeListSection] {
        guard taskRows.isEmpty == false else { return [] }

        let boundaries = HomeHorizonSectionBuilder.HorizonBoundaries(
            referenceDate: referenceDate,
            calendar: calendar
        )
        let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        var grouped: [GroupKey: [TaskDefinition]] = [:]

        for task in taskRows {
            let bucket = HomeHorizonSectionBuilder.bucket(for: task, boundaries: boundaries)
            grouped[GroupKey(bucket: bucket, projectID: task.projectID), default: []].append(task)
        }

        return grouped.map { key, tasks in
            let project = projectsByID[key.projectID]
            let name = project?.name ?? tasks.first?.projectName ?? "Project"
            let icon = project?.icon.systemImageName ?? "folder"
            let accent = project?.color.hexString ?? key.bucket.accentHex
            return HomeListSection(
                anchor: .horizonProject(
                    horizon: key.bucket,
                    projectID: key.projectID,
                    name: name,
                    iconSystemName: icon
                ),
                rows: HomeHorizonSectionBuilder.sortByPriorityThenDue(tasks).map(HomeTodayRow.task),
                identifier: "horizon:\(key.bucket.rawValue):project:\(key.projectID.uuidString)",
                accentHex: accent
            )
        }
        .sorted { lhs, rhs in
            if lhs.anchor.horizonSortIndex != rhs.anchor.horizonSortIndex {
                return lhs.anchor.horizonSortIndex < rhs.anchor.horizonSortIndex
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private extension HomeSectionAnchor {
    var horizonSortIndex: Int {
        switch self {
        case .horizon(let bucket):
            return bucket.sortIndex
        case .horizonProject(let horizon, _, _, _):
            return horizon.sortIndex
        default:
            return Int.max
        }
    }
}

enum HomeMixedSectionBuilder {
    static func buildTodaySections(
        taskRows: [TaskDefinition],
        habitRows: [HomeHabitRow],
        projects: [Project],
        lifeAreas: [LifeArea],
        useAdaptiveDayGrouping: Bool = false
    ) -> [HomeListSection] {
        if useAdaptiveDayGrouping, habitRows.isEmpty {
            return buildAdaptiveDayTaskSections(
                taskRows: taskRows,
                projects: projects,
                lifeAreas: lifeAreas
            )
        }

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

    private static func buildAdaptiveDayTaskSections(
        taskRows: [TaskDefinition],
        projects: [Project],
        lifeAreas: [LifeArea]
    ) -> [HomeListSection] {
        guard taskRows.isEmpty == false else { return [] }

        var rowsByProjectID: [UUID: [HomeTodayRow]] = [:]
        var projectByID: [UUID: Project] = [:]
        let lifeAreasByID = Dictionary(lifeAreas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for task in taskRows {
            let project = resolveProject(
                projectID: task.projectID,
                projectName: task.projectName,
                projects: projects
            )
            projectByID[project.id] = project
            rowsByProjectID[project.id, default: []].append(.task(task))
        }

        let qualifyingProjectIDs = Set(
            rowsByProjectID.compactMap { projectID, rows in
                rows.count >= 4 ? projectID : nil
            }
        )

        guard qualifyingProjectIDs.isEmpty == false else {
            return [
                HomeListSection(
                    anchor: .plainList(id: "day_plain_0"),
                    rows: taskRows.map(HomeTodayRow.task),
                    displayStyle: .plain,
                    identifier: "day_plain_0"
                )
            ]
        }

        var sections: [HomeListSection] = []
        var emittedQualifiedProjectIDs = Set<UUID>()
        var pendingPlainRows: [HomeTodayRow] = []
        var plainIndex = 0

        func flushPlainRows() {
            guard pendingPlainRows.isEmpty == false else { return }
            let identifier = "day_plain_\(plainIndex)"
            sections.append(
                HomeListSection(
                    anchor: .plainList(id: identifier),
                    rows: pendingPlainRows,
                    displayStyle: .plain,
                    identifier: identifier
                )
            )
            plainIndex += 1
            pendingPlainRows.removeAll(keepingCapacity: true)
        }

        for task in taskRows {
            let project = resolveProject(
                projectID: task.projectID,
                projectName: task.projectName,
                projects: projects
            )

            guard qualifyingProjectIDs.contains(project.id) else {
                pendingPlainRows.append(.task(task))
                continue
            }

            guard emittedQualifiedProjectIDs.contains(project.id) == false else {
                continue
            }

            flushPlainRows()
            emittedQualifiedProjectIDs.insert(project.id)

            sections.append(
                HomeListSection(
                    anchor: .project(
                        id: project.id,
                        name: project.name,
                        iconSystemName: "tray.full.fill",
                        isInbox: isInboxProject(project)
                    ),
                    rows: rowsByProjectID[project.id] ?? [],
                    accentHex: HomeTaskTintResolver.sectionAccentHex(
                        for: .project(
                            id: project.id,
                            name: project.name,
                            iconSystemName: "tray.full.fill",
                            isInbox: isInboxProject(project)
                        ),
                        projectsByID: projectByID,
                        lifeAreasByID: lifeAreasByID
                    )
                )
            )
        }

        flushPlainRows()
        return sections
    }

    private static func buildSections(
        rows: [HomeTodayRow],
        projects: [Project],
        lifeAreas: [LifeArea],
        isOverdueSection: Bool
    ) -> [HomeListSection] {
        guard rows.isEmpty == false else { return [] }

        let projectsByID = Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let lifeAreasByID = Dictionary(lifeAreas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let grouped = Dictionary(grouping: rows, by: { anchor(for: $0, projects: projects, lifeAreas: lifeAreas) })
        var sections = grouped.map { anchor, groupedRows in
            HomeListSection(
                anchor: anchor,
                rows: sortRows(groupedRows),
                isOverdueSection: isOverdueSection,
                accentHex: HomeTaskTintResolver.sectionAccentHex(
                    for: anchor,
                    projectsByID: projectsByID,
                    lifeAreasByID: lifeAreasByID
                )
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
            let project = resolveProject(
                projectID: task.projectID,
                projectName: task.projectName,
                projects: projects
            )
            return .project(
                id: project.id,
                name: project.name,
                iconSystemName: "tray.full.fill",
                isInbox: project.isInbox || project.id == ProjectConstants.inboxProjectID
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

            if let canonicalLifeArea = lifeAreas.first(where: { $0.id == habit.lifeAreaID }) {
                return .lifeArea(
                    id: canonicalLifeArea.id,
                    name: canonicalLifeArea.name,
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
