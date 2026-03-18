import Foundation

struct SlashCommandTaskItem: Codable, Equatable {
    let taskID: UUID
    let title: String
    let projectName: String
    let dueDateISO: String?
    let dueLabel: String?
    let taskSnapshot: TaskDefinition
}

struct SlashCommandTaskSection: Codable, Equatable {
    let id: String
    let title: String
    let tasks: [SlashCommandTaskItem]
    let totalCount: Int
}

struct SlashCommandExecutionResult: Codable, Equatable {
    let commandID: SlashCommandID
    let commandLabel: String
    let summary: String
    let sections: [SlashCommandTaskSection]
    let totalTaskCount: Int
    let generatedAtISO: String
}

enum SlashCommandExecutionError: LocalizedError {
    case repositoriesUnavailable
    case missingArgument(commandID: SlashCommandID)
    case entityNotFound(commandID: SlashCommandID, query: String)
    case ambiguousArgument(commandID: SlashCommandID, query: String, matches: [String])

    var errorDescription: String? {
        switch self {
        case .repositoriesUnavailable:
            return "Task context is unavailable right now."
        case .missingArgument(let commandID):
            return "\(commandID.displayName) command needs a name."
        case .entityNotFound(let commandID, let query):
            return "Could not find a \(commandID.displayName.lowercased()) matching \"\(query)\"."
        case .ambiguousArgument(let commandID, let query, let matches):
            let preview = matches.prefix(3).joined(separator: ", ")
            let label = commandID.displayName.lowercased()
            if matches.count > 3 {
                return "More than one \(label) matches \"\(query)\" (\(preview), ...). Please be more specific."
            }
            return "More than one \(label) matches \"\(query)\" (\(preview)). Please be more specific."
        }
    }
}

struct SlashCommandExecutionService {
    let taskReadModelRepository: TaskReadModelRepositoryProtocol
    let projectRepository: ProjectRepositoryProtocol
    let lifeAreaRepository: LifeAreaRepositoryProtocol?

    private enum NameResolution {
        case resolved(String)
        case ambiguous([String])
        case none
    }

    static func makeDefault() -> SlashCommandExecutionService? {
        guard let taskReadModelRepository = LLMContextRepositoryProvider.taskReadModelRepository,
              let projectRepository = LLMContextRepositoryProvider.projectRepository else {
            return nil
        }
        return SlashCommandExecutionService(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository,
            lifeAreaRepository: LLMContextRepositoryProvider.lifeAreaRepository
        )
    }

    func resolveArgumentName(for commandID: SlashCommandID, matching raw: String) async -> String? {
        switch await resolveNameResult(for: commandID, matching: raw) {
        case .resolved(let name):
            return name
        case .ambiguous, .none:
            return nil
        }
    }

    private func resolveNameResult(
        for commandID: SlashCommandID,
        matching raw: String
    ) async -> NameResolution {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return .none }

        let names: [String]
        switch commandID {
        case .project:
            names = await fetchProjects().map(\.name)
        case .area:
            names = await fetchLifeAreas().map(\.name)
        default:
            return .none
        }
        let normalized = query.lowercased()

        let exactMatches = names.filter { $0.lowercased() == normalized }
        if exactMatches.count == 1, let name = exactMatches.first {
            return .resolved(name)
        }
        if exactMatches.count > 1 {
            return .ambiguous(exactMatches.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }))
        }

        let prefixMatches = names.filter { $0.lowercased().hasPrefix(normalized) }
        if prefixMatches.count == 1, let name = prefixMatches.first {
            return .resolved(name)
        }
        if prefixMatches.count > 1 {
            return .ambiguous(prefixMatches.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }))
        }

        let containsMatches = names.filter { $0.lowercased().contains(normalized) }
        if containsMatches.count == 1, let name = containsMatches.first {
            return .resolved(name)
        }
        if containsMatches.count > 1 {
            return .ambiguous(containsMatches.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }))
        }

        return .none
    }

    func execute(invocation: SlashCommandInvocation) async throws -> SlashCommandExecutionResult {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        switch invocation.id {
        case .today:
            let tasks = await fetchOpenTasksWithDueDate()
            let overdue = tasks.filter {
                guard let dueDate = $0.dueDate else { return false }
                return dueDate < startOfToday
            }
            let dueToday = tasks.filter {
                guard let dueDate = $0.dueDate else { return false }
                return calendar.isDateInToday(dueDate)
            }

            let sections = [
                makeSection(id: "overdue", title: "Overdue", tasks: overdue, now: now),
                makeSection(id: "today", title: "Due Today", tasks: dueToday, now: now)
            ].filter { $0.totalCount > 0 }

            let total = sections.reduce(0) { $0 + $1.totalCount }
            let summary = total == 0
                ? "No overdue or due-today tasks."
                : "\(total) task\(total == 1 ? "" : "s") need attention."

            return SlashCommandExecutionResult(
                commandID: .today,
                commandLabel: SlashCommandID.today.displayName,
                summary: summary,
                sections: sections,
                totalTaskCount: total,
                generatedAtISO: now.ISO8601Format()
            )

        case .tomorrow:
            let tasks = await fetchOpenTasksWithDueDate().filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDateInTomorrow(dueDate)
            }
            return buildSingleSectionResult(
                commandID: .tomorrow,
                sectionTitle: "Due Tomorrow",
                sectionID: "tomorrow",
                tasks: tasks,
                now: now,
                emptySummary: "No tasks due tomorrow."
            )

        case .week:
            let tasks = await fetchOpenTasksWithDueDate().filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDate(dueDate, equalTo: now, toGranularity: .weekOfYear)
            }
            return buildSingleSectionResult(
                commandID: .week,
                sectionTitle: "Due This Week",
                sectionID: "week",
                tasks: tasks,
                now: now,
                emptySummary: "No tasks due this week."
            )

        case .month:
            let tasks = await fetchOpenTasksWithDueDate().filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDate(dueDate, equalTo: now, toGranularity: .month)
            }
            return buildSingleSectionResult(
                commandID: .month,
                sectionTitle: "Due This Month",
                sectionID: "month",
                tasks: tasks,
                now: now,
                emptySummary: "No tasks due this month."
            )

        case .overdue:
            let tasks = await fetchOpenTasksWithDueDate().filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < startOfToday
            }
            return buildSingleSectionResult(
                commandID: .overdue,
                sectionTitle: "Overdue",
                sectionID: "overdue",
                tasks: tasks,
                now: now,
                emptySummary: "No overdue tasks."
            )

        case .project:
            let query = invocation.resolvedArgument
                ?? invocation.argumentQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            guard query.isEmpty == false else {
                throw SlashCommandExecutionError.missingArgument(commandID: .project)
            }

            let resolution = await resolveNameResult(for: .project, matching: query)
            let resolvedProjectName: String
            switch resolution {
            case .resolved(let name):
                resolvedProjectName = name
            case .ambiguous(let matches):
                throw SlashCommandExecutionError.ambiguousArgument(
                    commandID: .project,
                    query: query,
                    matches: matches
                )
            case .none:
                throw SlashCommandExecutionError.entityNotFound(commandID: .project, query: query)
            }

            let tasks = await fetchOpenTasks().filter { task in
                let projectName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return projectName.caseInsensitiveCompare(resolvedProjectName) == .orderedSame
            }

            let section = makeSection(id: "project", title: resolvedProjectName, tasks: tasks, now: now)
            let summary = section.totalCount == 0
                ? "No open tasks found in \(resolvedProjectName)."
                : "\(section.totalCount) open task\(section.totalCount == 1 ? "" : "s") in \(resolvedProjectName)."
            let sections = section.totalCount == 0 ? [] : [section]

            return SlashCommandExecutionResult(
                commandID: .project,
                commandLabel: "Project: \(resolvedProjectName)",
                summary: summary,
                sections: sections,
                totalTaskCount: section.totalCount,
                generatedAtISO: now.ISO8601Format()
            )

        case .area:
            let query = invocation.resolvedArgument
                ?? invocation.argumentQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            guard query.isEmpty == false else {
                throw SlashCommandExecutionError.missingArgument(commandID: .area)
            }

            let resolution = await resolveNameResult(for: .area, matching: query)
            let resolvedAreaName: String
            switch resolution {
            case .resolved(let name):
                resolvedAreaName = name
            case .ambiguous(let matches):
                throw SlashCommandExecutionError.ambiguousArgument(
                    commandID: .area,
                    query: query,
                    matches: matches
                )
            case .none:
                throw SlashCommandExecutionError.entityNotFound(commandID: .area, query: query)
            }

            let lifeAreas = await fetchLifeAreas()
            let matchingArea = lifeAreas.first {
                $0.name.caseInsensitiveCompare(resolvedAreaName) == .orderedSame
            }
            let tasks = await fetchOpenTasks().filter { task in
                guard let areaID = matchingArea?.id else { return false }
                return task.lifeAreaID == areaID
            }

            let section = makeSection(id: "area", title: resolvedAreaName, tasks: tasks, now: now)
            let summary = section.totalCount == 0
                ? "No open tasks found in \(resolvedAreaName)."
                : "\(section.totalCount) open task\(section.totalCount == 1 ? "" : "s") in \(resolvedAreaName)."
            let sections = section.totalCount == 0 ? [] : [section]

            return SlashCommandExecutionResult(
                commandID: .area,
                commandLabel: "Life Area: \(resolvedAreaName)",
                summary: summary,
                sections: sections,
                totalTaskCount: section.totalCount,
                generatedAtISO: now.ISO8601Format()
            )

        case .recent:
            let summary = await EvaExecutiveContextService(
                taskReadModelRepository: taskReadModelRepository,
                projectRepository: projectRepository,
                lifeAreaRepository: lifeAreaRepository
            ).buildSnapshot(maxChars: 420, now: now)
            let recentTasks = await fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    updatedAfter: Calendar.current.date(byAdding: .day, value: -14, to: startOfToday),
                    sortBy: .updatedAtDescending,
                    limit: 12,
                    offset: 0
                )
            )
            let completed = recentTasks.filter { $0.isComplete }
            let active = recentTasks.filter { !$0.isComplete }
            let sections = [
                makeSection(id: "recent_completed", title: "Recently Completed", tasks: completed, now: now, maxTasks: 4),
                makeSection(id: "recent_active", title: "Recently Active", tasks: active, now: now, maxTasks: 4)
            ].filter { $0.totalCount > 0 }

            return SlashCommandExecutionResult(
                commandID: .recent,
                commandLabel: SlashCommandID.recent.displayName,
                summary: summary.promptBlock,
                sections: sections,
                totalTaskCount: sections.reduce(0) { $0 + $1.totalCount },
                generatedAtISO: now.ISO8601Format()
            )

        case .clear:
            return SlashCommandExecutionResult(
                commandID: .clear,
                commandLabel: SlashCommandID.clear.displayName,
                summary: "Chat cleared.",
                sections: [],
                totalTaskCount: 0,
                generatedAtISO: now.ISO8601Format()
            )
        }
    }

    private func buildSingleSectionResult(
        commandID: SlashCommandID,
        sectionTitle: String,
        sectionID: String,
        tasks: [TaskDefinition],
        now: Date,
        emptySummary: String
    ) -> SlashCommandExecutionResult {
        let section = makeSection(id: sectionID, title: sectionTitle, tasks: tasks, now: now)
        let sections = section.totalCount == 0 ? [] : [section]
        let summary = section.totalCount == 0
            ? emptySummary
            : "\(section.totalCount) task\(section.totalCount == 1 ? "" : "s") found."

        return SlashCommandExecutionResult(
            commandID: commandID,
            commandLabel: commandID.displayName,
            summary: summary,
            sections: sections,
            totalTaskCount: section.totalCount,
            generatedAtISO: now.ISO8601Format()
        )
    }

    private func makeSection(
        id: String,
        title: String,
        tasks: [TaskDefinition],
        now: Date,
        maxTasks: Int = 8
    ) -> SlashCommandTaskSection {
        let sorted = sortTasks(tasks)
        let items = sorted.prefix(maxTasks).map { task in
            SlashCommandTaskItem(
                taskID: task.id,
                title: task.title,
                projectName: task.projectName ?? ProjectConstants.inboxProjectName,
                dueDateISO: task.dueDate?.ISO8601Format(),
                dueLabel: dueLabel(for: task, now: now),
                taskSnapshot: task
            )
        }

        return SlashCommandTaskSection(
            id: id,
            title: title,
            tasks: Array(items),
            totalCount: sorted.count
        )
    }

    private func dueLabel(for task: TaskDefinition, now: Date) -> String? {
        guard let dueDate = task.dueDate else { return nil }
        if let lateLabel = OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) {
            return lateLabel
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Today"
        }
        if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }

    private func sortTasks(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.sorted {
            let lhsDue = $0.dueDate ?? .distantFuture
            let rhsDue = $1.dueDate ?? .distantFuture
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func fetchOpenTasksWithDueDate() async -> [TaskDefinition] {
        await fetchOpenTasks().filter { $0.dueDate != nil }
    }

    private func fetchOpenTasks() async -> [TaskDefinition] {
        await fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        )
    }

    private func fetchTasks(query: TaskReadQuery) async -> [TaskDefinition] {
        await withCheckedContinuation { continuation in
            taskReadModelRepository.fetchTasks(query: query) { result in
                let tasks = (try? result.get().tasks) ?? []
                continuation.resume(returning: tasks)
            }
        }
    }

    private func fetchProjects() async -> [Project] {
        await withCheckedContinuation { continuation in
            projectRepository.fetchAllProjects { result in
                let projects = ((try? result.get()) ?? []).filter { $0.isArchived == false }
                continuation.resume(returning: projects)
            }
        }
    }

    private func fetchLifeAreas() async -> [LifeArea] {
        guard let lifeAreaRepository else { return [] }
        return await withCheckedContinuation { continuation in
            lifeAreaRepository.fetchAll { result in
                let lifeAreas = ((try? result.get()) ?? []).filter { $0.isArchived == false }
                continuation.resume(returning: lifeAreas)
            }
        }
    }
}
