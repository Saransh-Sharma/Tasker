import Foundation
import MLXLMCommon

private func uniqueDictionary<Key: Hashable, Value>(
    _ pairs: [(Key, Value)],
    source: String,
    context: String,
    sampleLimit: Int = 8
) -> [Key: Value] {
    var dictionary: [Key: Value] = [:]
    var duplicateKeys: [Key] = []
    var duplicateSet: Set<Key> = []
    var duplicateCount = 0

    for (key, value) in pairs {
        if dictionary[key] == nil {
            dictionary[key] = value
            continue
        }
        duplicateCount += 1
        if duplicateSet.insert(key).inserted {
            duplicateKeys.append(key)
        }
    }

    if duplicateCount > 0 {
        let sampleKeys = duplicateKeys
            .prefix(sampleLimit)
            .map(String.init(describing:))
            .joined(separator: ", ")
        logWarning(
            event: "llm_context_projection_duplicate_keys",
            message: "Detected duplicate keys while building dictionary for \(context)",
            fields: [
                "source": source,
                "duplicate_count": String(duplicateCount),
                "total_count": String(pairs.count),
                "sample_keys": LoggingService.previewText(sampleKeys)
            ]
        )
    }

    return dictionary
}

enum LLMContextRepositoryProvider {
    private static var taskReadModelRepositoryStorage: TaskReadModelRepositoryProtocol?
    private static var projectRepositoryStorage: ProjectRepositoryProtocol?
    private static var lifeAreaRepositoryStorage: LifeAreaRepositoryProtocol?
    private static var tagRepositoryStorage: TagRepositoryProtocol?

    static var taskReadModelRepository: TaskReadModelRepositoryProtocol? { taskReadModelRepositoryStorage }
    static var projectRepository: ProjectRepositoryProtocol? { projectRepositoryStorage }
    static var lifeAreaRepository: LifeAreaRepositoryProtocol? { lifeAreaRepositoryStorage }
    static var tagRepository: TagRepositoryProtocol? { tagRepositoryStorage }

    /// Executes configure.
    static func configure(
        taskReadModelRepository: TaskReadModelRepositoryProtocol?,
        projectRepository: ProjectRepositoryProtocol?,
        lifeAreaRepository: LifeAreaRepositoryProtocol? = nil,
        tagRepository: TagRepositoryProtocol? = nil
    ) {
        self.taskReadModelRepositoryStorage = taskReadModelRepository
        self.projectRepositoryStorage = projectRepository
        self.lifeAreaRepositoryStorage = lifeAreaRepository
        self.tagRepositoryStorage = tagRepository
    }

    /// Executes makeService.
    static func makeService(
        maxTasksPerSlice: Int = LLMChatBudgets.active.maxProjectionTasksPerSlice,
        compactTaskPayload: Bool = (V2FeatureFlags.llmChatContextStrategy == .bounded)
    ) -> LLMContextProjectionService? {
        guard let taskReadModelRepository = taskReadModelRepositoryStorage,
              let projectRepository = projectRepositoryStorage else {
            return nil
        }
        return LLMContextProjectionService(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository,
            lifeAreaRepository: lifeAreaRepositoryStorage,
            tagRepository: tagRepositoryStorage,
            maxTasksPerSlice: maxTasksPerSlice,
            compactTaskPayload: compactTaskPayload
        )
    }

    /// Executes findProjectName.
    static func findProjectName(matching query: String) async -> String? {
        guard let projectRepository = projectRepositoryStorage else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let projects = await withCheckedContinuation { continuation in
            projectRepository.fetchAllProjects { result in
                let resolved = (try? result.get()) ?? []
                continuation.resume(returning: resolved)
            }
        }
        return resolveProjectName(in: projects, query: trimmed)
    }

    /// Executes findProjectNameSync.
    static func findProjectNameSync(matching query: String, timeoutSeconds: TimeInterval = 3) -> String? {
        guard let projectRepository = projectRepositoryStorage else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let semaphore = DispatchSemaphore(value: 0)
        var projects: [Project] = []
        projectRepository.fetchAllProjects { result in
            projects = (try? result.get()) ?? []
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + .milliseconds(Int(timeoutSeconds * 1_000)))
        return resolveProjectName(in: projects, query: trimmed)
    }

    /// Executes projectNameLookup.
    static func projectNameLookup() async -> [UUID: String] {
        guard let projectRepository = projectRepositoryStorage else { return [:] }
        let projects = await withCheckedContinuation { continuation in
            projectRepository.fetchAllProjects { result in
                let resolved = (try? result.get()) ?? []
                continuation.resume(returning: resolved)
            }
        }
        return uniqueDictionary(
            projects.map { ($0.id, $0.name) },
            source: "projects",
            context: "projectNameLookup"
        )
    }

    private static func resolveProjectName(in projects: [Project], query: String) -> String? {
        let normalized = query.lowercased()

        let exactMatches = projects.filter { $0.name.lowercased() == normalized }
        if exactMatches.count == 1 {
            return exactMatches[0].name
        }

        let prefixMatches = projects.filter { $0.name.lowercased().hasPrefix(normalized) }
        if prefixMatches.count == 1 {
            return prefixMatches[0].name
        }

        let containsMatches = projects.filter { $0.name.lowercased().contains(normalized) }
        if containsMatches.count == 1 {
            return containsMatches[0].name
        }

        return nil
    }
}

struct LLMContextProjectionService {
    let taskReadModelRepository: TaskReadModelRepositoryProtocol
    let projectRepository: ProjectRepositoryProtocol
    let lifeAreaRepository: LifeAreaRepositoryProtocol?
    let tagRepository: TagRepositoryProtocol?
    let maxTasksPerSlice: Int
    let compactTaskPayload: Bool

    init(
        taskReadModelRepository: TaskReadModelRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        lifeAreaRepository: LifeAreaRepositoryProtocol? = nil,
        tagRepository: TagRepositoryProtocol?,
        maxTasksPerSlice: Int = 1_000,
        compactTaskPayload: Bool = false
    ) {
        self.taskReadModelRepository = taskReadModelRepository
        self.projectRepository = projectRepository
        self.lifeAreaRepository = lifeAreaRepository
        self.tagRepository = tagRepository
        self.maxTasksPerSlice = max(1, maxTasksPerSlice)
        self.compactTaskPayload = compactTaskPayload
    }

    func withProjectionBudget(maxTasksPerSlice: Int, compactTaskPayload: Bool) -> LLMContextProjectionService {
        LLMContextProjectionService(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository,
            lifeAreaRepository: lifeAreaRepository,
            tagRepository: tagRepository,
            maxTasksPerSlice: maxTasksPerSlice,
            compactTaskPayload: compactTaskPayload
        )
    }

    func buildChatPlanningContext(query: String, maxChars: Int) async -> String {
        let normalizedQuery = Self.searchTerms(from: query)
        async let activeProjectsTask = fetchActiveProjects()
        async let activeLifeAreasTask = fetchActiveLifeAreas()
        let activeProjects = await activeProjectsTask
        let activeLifeAreas = await activeLifeAreasTask
        let projectNameByID = uniqueDictionary(
            activeProjects.map { ($0.id, $0.name) },
            source: "projects",
            context: "buildChatPlanningContext"
        )
        let lifeAreaNameByID = uniqueDictionary(
            activeLifeAreas.map { ($0.id, $0.name) },
            source: "life_areas",
            context: "buildChatPlanningContext"
        )

        let buckets = await buildChatTaskBuckets(
            queryTerms: normalizedQuery,
            projectNameByID: projectNameByID,
            lifeAreaNameByID: lifeAreaNameByID
        )

        let orderedProjects = Self.orderProjectNames(
            projects: activeProjects,
            attachedTasks: buckets.allTasks,
            queryTerms: normalizedQuery
        )
        let orderedLifeAreas = Self.orderLifeAreaNames(
            lifeAreas: activeLifeAreas,
            attachedTasks: buckets.allTasks,
            queryTerms: normalizedQuery
        )
        let retrospectiveSection = await buildRetrospectiveSection(
            query: query,
            overdueRemaining: buckets.overdue.count,
            projectNameByID: projectNameByID
        )

        let focusTasks = Self.prioritizedFocusTasks(
            buckets: buckets,
            queryTerms: normalizedQuery,
            projectNameByID: projectNameByID,
            lifeAreaNameByID: lifeAreaNameByID,
            maxItems: 6
        )
        let focusProjectNames = Self.uniqueNames(
            focusTasks.compactMap { task in
                let name = Self.projectName(for: task, projectNameByID: projectNameByID)
                return name.isEmpty ? nil : name
            }
        )
        let focusLifeAreaNames = Self.uniqueNames(
            focusTasks.compactMap { task in
                guard let lifeAreaID = task.lifeAreaID else { return nil }
                let name = lifeAreaNameByID[lifeAreaID] ?? ""
                return name.isEmpty ? nil : name
            }
        )

        let projectSectionItems = Array((focusProjectNames + orderedProjects).prefix(4))
        let lifeAreaSectionItems = Array((focusLifeAreaNames + orderedLifeAreas).prefix(4))
        let clampedMaxChars = max(320, maxChars)
        var accumulator = PlanningContextAccumulator(maxChars: clampedMaxChars)

        _ = accumulator.append("Planning context:")
        _ = accumulator.append(
            "Summary: \(buckets.overdue.count) overdue, \(buckets.today.count) today, \(buckets.tomorrow.count) tomorrow, \(buckets.thisWeek.count) this week"
        )

        _ = accumulator.append("Focus:")
        if focusTasks.isEmpty {
            _ = accumulator.append("- none")
        } else {
            for task in focusTasks {
                let line = Self.compactTaskLine(task: task, projectNameByID: projectNameByID)
                if accumulator.append("- \(line)") == false {
                    return accumulator.rendered
                }
            }
        }

        if let projectsSection = Self.buildListSection(
            title: "Projects",
            items: projectSectionItems,
            maxChars: min(220, max(100, clampedMaxChars / 4))
        ) {
            _ = accumulator.append("")
            for line in projectsSection.components(separatedBy: .newlines) {
                if accumulator.append(line) == false {
                    return accumulator.rendered
                }
            }
        }

        if let lifeAreasSection = Self.buildListSection(
            title: "Life areas",
            items: lifeAreaSectionItems,
            maxChars: min(220, max(100, clampedMaxChars / 4))
        ) {
            _ = accumulator.append("")
            for line in lifeAreasSection.components(separatedBy: .newlines) {
                if accumulator.append(line) == false {
                    return accumulator.rendered
                }
            }
        }

        if let retrospectiveSection,
           let historySection = Self.buildListSection(
            title: "History",
            items: retrospectiveSection,
            maxChars: min(240, max(120, clampedMaxChars / 3))
           ) {
            _ = accumulator.append("")
            for line in historySection.components(separatedBy: .newlines) {
                if accumulator.append(line) == false {
                    return accumulator.rendered
                }
            }
        }

        return accumulator.rendered
    }

    /// Executes buildTodayJSON.
    func buildTodayJSON() async -> String {
        guard !Task.isCancelled else { return "{}" }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        let endOfDay = startOfTomorrow.addingTimeInterval(-1)

        let tasks = await fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateStart: startOfDay,
                dueDateEnd: endOfDay,
                sortBy: .dueDateAscending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )
        guard !Task.isCancelled else { return "{}" }
        let scopedTasks = tasks.filter { task in
            guard task.isComplete else { return true }
            guard let completedAt = task.dateCompleted else { return false }
            return calendar.isDateInToday(completedAt)
        }
        let tagNameLookup = await buildTagNameLookup()
        return Self.encode(
            tasks: scopedTasks,
            contextType: "today",
            metadata: defaultMetadata(),
            tagNameLookup: tagNameLookup,
            compactTaskPayload: compactTaskPayload
        )
    }

    /// Executes buildOverdueJSON.
    func buildOverdueJSON() async -> String {
        guard !Task.isCancelled else { return "{}" }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let tasks = await fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateEnd: startOfToday,
                sortBy: .dueDateAscending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )
        guard !Task.isCancelled else { return "{}" }
        let overdueTasks = tasks.filter { task in
            guard task.isComplete == false, let dueDate = task.dueDate else { return false }
            return dueDate < startOfToday
        }
        let tagNameLookup = await buildTagNameLookup()
        return Self.encode(
            tasks: overdueTasks,
            contextType: "overdue",
            metadata: defaultMetadata(),
            tagNameLookup: tagNameLookup,
            compactTaskPayload: compactTaskPayload
        )
    }

    /// Executes buildUpcomingJSON.
    func buildUpcomingJSON() async -> String {
        guard !Task.isCancelled else { return "{}" }
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())

        let tasks = await fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateStart: tomorrow,
                sortBy: .dueDateAscending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )
        guard !Task.isCancelled else { return "{}" }
        let tagNameLookup = await buildTagNameLookup()
        return Self.encode(
            tasks: tasks,
            contextType: "upcoming",
            metadata: defaultMetadata(),
            tagNameLookup: tagNameLookup,
            compactTaskPayload: compactTaskPayload
        )
    }

    /// Executes buildProjectJSON.
    func buildProjectJSON(projectID: UUID) async -> String {
        guard !Task.isCancelled else { return "{}" }
        let projectName = await fetchProjectName(id: projectID) ?? ""
        let tasks = await fetchTasks(
            query: TaskReadQuery(
                projectID: projectID,
                includeCompleted: true,
                sortBy: .dueDateAscending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )
        guard !Task.isCancelled else { return "{}" }
        var metadata = defaultMetadata()
        metadata["project_id"] = projectID.uuidString
        metadata["project_name"] = projectName
        return Self.encode(
            tasks: tasks,
            contextType: "project",
            metadata: metadata,
            tagNameLookup: await buildTagNameLookup(),
            compactTaskPayload: compactTaskPayload
        )
    }

    /// Executes buildTodayJSON.
    func buildTodayJSON(completion: @escaping (String) -> Void) {
        Task {
            completion(await buildTodayJSON())
        }
    }

    /// Executes buildUpcomingJSON.
    func buildUpcomingJSON(completion: @escaping (String) -> Void) {
        Task {
            completion(await buildUpcomingJSON())
        }
    }

    /// Executes buildOverdueJSON.
    func buildOverdueJSON(completion: @escaping (String) -> Void) {
        Task {
            completion(await buildOverdueJSON())
        }
    }

    /// Executes buildProjectJSON.
    func buildProjectJSON(projectID: UUID, completion: @escaping (String) -> Void) {
        Task {
            completion(await buildProjectJSON(projectID: projectID))
        }
    }

    /// Executes fetchTasks.
    private func fetchTasks(query: TaskReadQuery) async -> [TaskDefinition] {
        guard !Task.isCancelled else { return [] }
        return await withCheckedContinuation { continuation in
            taskReadModelRepository.fetchTasks(query: query) { result in
                if Task.isCancelled {
                    continuation.resume(returning: [])
                    return
                }
                let tasks = (try? result.get().tasks) ?? []
                continuation.resume(returning: tasks)
            }
        }
    }

    private func fetchActiveProjects() async -> [Project] {
        guard !Task.isCancelled else { return [] }
        return await withCheckedContinuation { continuation in
            projectRepository.fetchAllProjects { result in
                let activeProjects = ((try? result.get()) ?? []).filter { !$0.isArchived }
                let inboxProjectCount = activeProjects.filter { $0.id == ProjectConstants.inboxProjectID }.count
                if inboxProjectCount > 1 {
                    logWarning(
                        event: "llm_context_projection_active_projects",
                        message: "Found duplicate active inbox project IDs while preparing chat context",
                        fields: [
                            "source": "projects",
                            "total_count": String(activeProjects.count),
                            "duplicate_count": String(max(0, inboxProjectCount - 1)),
                            "inbox_duplicate_count": String(max(0, inboxProjectCount - 1)),
                            "sample_keys": LoggingService.previewText(
                                [ProjectConstants.inboxProjectID]
                                    .map(String.init)
                                    .joined(separator: ", "),
                                maxLength: LoggingService.defaultLogPreviewLength
                            )
                        ]
                    )
                }
                continuation.resume(returning: activeProjects)
            }
        }
    }

    private func fetchActiveLifeAreas() async -> [LifeArea] {
        guard let lifeAreaRepository else { return [] }
        guard !Task.isCancelled else { return [] }
        return await withCheckedContinuation { continuation in
            lifeAreaRepository.fetchAll { result in
                let lifeAreas = ((try? result.get()) ?? []).filter { !$0.isArchived }
                continuation.resume(returning: lifeAreas)
            }
        }
    }

    private func buildChatTaskBuckets(
        queryTerms: [String],
        projectNameByID: [UUID: String],
        lifeAreaNameByID: [UUID: String]
    ) async -> LLMChatPlanningTaskBuckets {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let endOfToday = startOfTomorrow.addingTimeInterval(-1)
        let startOfDayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? startOfTomorrow
        let endOfTomorrow = startOfDayAfterTomorrow.addingTimeInterval(-1)
        let endOfWeekWindow = calendar.date(
            byAdding: DateComponents(day: 7, second: -1),
            to: startOfTomorrow
        ) ?? endOfTomorrow

        async let overdueFetch = fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateEnd: startOfToday,
                sortBy: .dueDateAscending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )
        async let todayFetch = fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateStart: startOfToday,
                dueDateEnd: endOfToday,
                sortBy: .dueDateAscending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )
        async let tomorrowFetch = fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateStart: startOfTomorrow,
                dueDateEnd: endOfTomorrow,
                sortBy: .dueDateAscending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )
        async let thisWeekFetch = fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateStart: startOfDayAfterTomorrow,
                dueDateEnd: endOfWeekWindow,
                sortBy: .dueDateAscending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )
        async let unscheduledFetch = fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                sortBy: .updatedAtDescending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )

        let overdueTasks = await overdueFetch
        let filteredOverdueTasks = overdueTasks.filter {
            guard let dueDate = $0.dueDate else { return false }
            return dueDate < startOfToday
        }
        let todayTasks = await todayFetch
        let tomorrowTasks = await tomorrowFetch
        let thisWeekTasks = await thisWeekFetch
        let unscheduledCandidates = (await unscheduledFetch).filter { $0.dueDate == nil }

        let orderedOverdue = Self.rankTasks(
            filteredOverdueTasks,
            query: queryTerms.joined(separator: " "),
            queryTerms: queryTerms,
            projectNameByID: projectNameByID,
            lifeAreaNameByID: lifeAreaNameByID
        )
        let orderedToday = Self.rankTasks(
            todayTasks,
            query: queryTerms.joined(separator: " "),
            queryTerms: queryTerms,
            projectNameByID: projectNameByID,
            lifeAreaNameByID: lifeAreaNameByID
        )
        let orderedTomorrow = Self.rankTasks(
            tomorrowTasks,
            query: queryTerms.joined(separator: " "),
            queryTerms: queryTerms,
            projectNameByID: projectNameByID,
            lifeAreaNameByID: lifeAreaNameByID
        )
        let orderedThisWeek = Self.rankTasks(
            thisWeekTasks,
            query: queryTerms.joined(separator: " "),
            queryTerms: queryTerms,
            projectNameByID: projectNameByID,
            lifeAreaNameByID: lifeAreaNameByID
        )

        let rankedUnscheduled = Self.rankTasks(
            unscheduledCandidates,
            query: queryTerms.joined(separator: " "),
            queryTerms: queryTerms,
            projectNameByID: projectNameByID,
            lifeAreaNameByID: lifeAreaNameByID
        )
        var seenProjectKeys = Set<String>()
        let unscheduled = rankedUnscheduled.filter { task in
            let projectName = Self.projectName(for: task, projectNameByID: projectNameByID)
            let projectKey = projectName.isEmpty ? task.projectID.uuidString : projectName.lowercased()
            return seenProjectKeys.insert(projectKey).inserted
        }

        return LLMChatPlanningTaskBuckets(
            overdue: orderedOverdue,
            today: orderedToday,
            tomorrow: orderedTomorrow,
            thisWeek: orderedThisWeek,
            unscheduled: unscheduled
        )
    }

    private func buildRetrospectiveSection(
        query: String,
        overdueRemaining: Int,
        projectNameByID: [UUID: String]
    ) async -> [String]? {
        guard let window = Self.retrospectiveWindow(for: query) else { return nil }

        let completedCandidates = await fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                updatedAfter: window.start,
                sortBy: .updatedAtDescending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )

        let dueCandidates = await fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateStart: window.start,
                dueDateEnd: window.end,
                sortBy: .dueDateAscending,
                limit: maxTasksPerSlice,
                offset: 0
            )
        )

        let completedCount = completedCandidates.filter { task in
            guard task.isComplete, let completedAt = task.dateCompleted else { return false }
            return completedAt >= window.start && completedAt <= window.end
        }.count

        let openDueCount = dueCandidates.filter { task in
            guard task.isComplete == false, let dueDate = task.dueDate else { return false }
            return dueDate >= window.start && dueDate <= window.end
        }.count

        let touchedProjects = Set(
            (completedCandidates + dueCandidates).compactMap { task -> String? in
                let projectName = Self.projectName(for: task, projectNameByID: projectNameByID)
                return projectName.isEmpty ? nil : projectName
            }
        )

        return [
            "Period: \(window.label)",
            "Completed tasks: \(completedCount)",
            "Open due tasks in period: \(openDueCount)",
            "Overdue remaining: \(overdueRemaining)",
            "Projects touched: \(touchedProjects.count)"
        ]
    }

    /// Executes fetchProjectName.
    private func fetchProjectName(id: UUID) async -> String? {
        guard !Task.isCancelled else { return nil }
        return await withCheckedContinuation { continuation in
            projectRepository.fetchProject(withId: id) { result in
                switch result {
                case .success(let project):
                    continuation.resume(returning: project?.name)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Executes defaultMetadata.
    private func defaultMetadata() -> [String: Any] {
        [
            "timezone": TimeZone.current.identifier,
            "generated_at_iso": Date().ISO8601Format(),
            "context_version": 3
        ]
    }

    /// Executes buildTagNameLookup.
    private func buildTagNameLookup() async -> [UUID: String] {
        guard let tagRepository else { return [:] }
        guard !Task.isCancelled else { return [:] }
        return await withCheckedContinuation { continuation in
            tagRepository.fetchAll { result in
                guard case .success(let tags) = result else {
                    continuation.resume(returning: [:])
                    return
                }
                continuation.resume(returning: uniqueDictionary(
                    tags.map { ($0.id, $0.name) },
                    source: "tags",
                    context: "buildTagNameLookup"
                ))
            }
        }
    }

    /// Executes encode.
    private static func encode(
        tasks: [TaskDefinition],
        contextType: String,
        metadata: [String: Any] = [:],
        tagNameLookup: [UUID: String] = [:],
        compactTaskPayload: Bool = false
    ) -> String {
        var payload: [String: Any] = [
            "context_type": contextType,
            "count": tasks.count,
            "tasks": tasks.map { task in
                let tagIDs = task.tagIDs
                    .map(\.uuidString)
                    .sorted()
                let tagNames = task.tagIDs
                    .compactMap { tagNameLookup[$0] }
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                let projectName = task.projectName ?? ""
                var projected: [String: Any] = [
                    "id": task.id.uuidString,
                    "title": task.title,
                    "is_completed": task.isComplete,
                    "project": projectName,
                    "project_id": task.projectID.uuidString,
                    "priority": task.priority.rawValue,
                    "type": task.type.rawValue,
                    "tag_names": tagNames,
                    "due_date": task.dueDate?.ISO8601Format() ?? NSNull()
                ]

                if compactTaskPayload == false {
                    projected["energy"] = task.energy.rawValue
                    projected["context"] = task.context.rawValue
                    projected["estimated_duration_minutes"] = task.estimatedDuration.map { Int($0 / 60) } ?? NSNull()
                    projected["has_dependencies"] = !task.dependencies.isEmpty
                    projected["dependency_count"] = task.dependencies.count
                    projected["tag_ids"] = tagIDs
                }

                return projected
            }
        ]
        for (key, value) in metadata {
            payload[key] = value
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func buildListSection(
        title: String,
        items: [String],
        maxChars: Int
    ) -> String? {
        let nonEmptyItems = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard nonEmptyItems.isEmpty == false else { return nil }

        var accumulator = PlanningContextAccumulator(maxChars: maxChars)
        guard accumulator.append("\(title):") else { return nil }
        for item in nonEmptyItems {
            if accumulator.append("- \(item)") == false {
                break
            }
        }
        return accumulator.rendered
    }

    private static func buildTasksSection(
        buckets: LLMChatPlanningTaskBuckets,
        projectNameByID: [UUID: String],
        lifeAreaNameByID: [UUID: String],
        maxChars: Int
    ) -> String {
        var accumulator = PlanningContextAccumulator(maxChars: maxChars)
        _ = accumulator.append("Tasks:")

        var appendedAnyTask = false
        for (title, tasks) in [
            ("Overdue", buckets.overdue),
            ("Today", buckets.today),
            ("Tomorrow", buckets.tomorrow),
            ("This week", buckets.thisWeek),
            ("Unscheduled", buckets.unscheduled)
        ] {
            let lines = tasks.map {
                formatTaskLine(
                    task: $0,
                    projectNameByID: projectNameByID,
                    lifeAreaNameByID: lifeAreaNameByID
                )
            }
            guard lines.isEmpty == false else { continue }
            guard accumulator.append("\(title):") else { break }
            var appendedSectionLine = false
            for line in lines {
                if accumulator.append("- \(line)") == false {
                    return accumulator.rendered
                }
                appendedAnyTask = true
                appendedSectionLine = true
            }
            if appendedSectionLine == false {
                break
            }
        }

        if appendedAnyTask == false {
            _ = accumulator.append("- none")
        }
        return accumulator.rendered
    }

    private static func formatTaskLine(
        task: TaskDefinition,
        projectNameByID: [UUID: String],
        lifeAreaNameByID: [UUID: String]
    ) -> String {
        var parts: [String] = [
            task.title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueLabel(for: task.dueDate)
        ]

        let projectName = projectName(for: task, projectNameByID: projectNameByID)
        if projectName.isEmpty == false {
            parts.append(projectName)
        }

        if let lifeAreaID = task.lifeAreaID,
           let lifeAreaName = lifeAreaNameByID[lifeAreaID],
           lifeAreaName.isEmpty == false {
            parts.append(lifeAreaName)
        }

        return parts.joined(separator: " | ")
    }

    private static func compactTaskLine(
        task: TaskDefinition,
        projectNameByID: [UUID: String]
    ) -> String {
        var parts: [String] = [
            task.title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueLabel(for: task.dueDate)
        ]
        let projectName = projectName(for: task, projectNameByID: projectNameByID)
        if projectName.isEmpty == false {
            parts.append(projectName)
        }
        return parts.joined(separator: " | ")
    }

    private static func projectName(
        for task: TaskDefinition,
        projectNameByID: [UUID: String]
    ) -> String {
        let directName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if directName.isEmpty == false {
            return directName
        }
        return projectNameByID[task.projectID] ?? ""
    }

    private static func dueLabel(for dueDate: Date?) -> String {
        guard let dueDate else { return "unscheduled" }
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "today"
        }
        if calendar.isDateInTomorrow(dueDate) {
            return "tomorrow"
        }
        let startOfToday = calendar.startOfDay(for: Date())
        if dueDate < startOfToday {
            return "overdue"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter.string(from: dueDate)
    }

    private static func searchTerms(from query: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        return query
            .lowercased()
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
    }

    private static func retrospectiveWindow(for query: String) -> (label: String, start: Date, end: Date)? {
        let normalized = query.lowercased()
        let retrospectiveHints = [
            "last week", "this week", "last month", "this month",
            "yesterday", "productivity", "productive", "completed",
            "complete", "finished", "finish", "progress", "how was"
        ]
        guard retrospectiveHints.contains(where: normalized.contains) else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        if normalized.contains("last week") {
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)
            let end = currentWeek?.start.addingTimeInterval(-1) ?? startOfToday.addingTimeInterval(-1)
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek?.start ?? startOfToday) ?? startOfToday
            return ("Last week", start, end)
        }

        if normalized.contains("this week") {
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
            return ("This week", start, now)
        }

        if normalized.contains("last month") {
            let currentMonth = calendar.dateInterval(of: .month, for: now)
            let end = currentMonth?.start.addingTimeInterval(-1) ?? startOfToday.addingTimeInterval(-1)
            let start = calendar.date(byAdding: .month, value: -1, to: currentMonth?.start ?? startOfToday) ?? startOfToday
            return ("Last month", start, end)
        }

        if normalized.contains("this month") {
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            return ("This month", start, now)
        }

        if normalized.contains("yesterday") {
            let start = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
            let end = startOfToday.addingTimeInterval(-1)
            return ("Yesterday", start, end)
        }

        let start = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        return ("Last 7 days", start, now)
    }

    private static func prioritizedFocusTasks(
        buckets: LLMChatPlanningTaskBuckets,
        queryTerms: [String],
        projectNameByID: [UUID: String],
        lifeAreaNameByID: [UUID: String],
        maxItems: Int
    ) -> [TaskDefinition] {
        guard maxItems > 0 else { return [] }

        let queryMatches = Self.uniqueTasks(
            tasks: buckets.allTasks.filter {
                taskMatchScore(
                    $0,
                    queryTerms: queryTerms,
                    projectNameByID: projectNameByID,
                    lifeAreaNameByID: lifeAreaNameByID
                ) > 0
            }
        )

        let orderedGroups: [[TaskDefinition]] = [
            buckets.overdue,
            buckets.today,
            buckets.tomorrow,
            queryMatches,
            buckets.thisWeek,
            buckets.unscheduled
        ]

        var selected: [TaskDefinition] = []
        var seen = Set<UUID>()

        for group in orderedGroups {
            for task in group where seen.insert(task.id).inserted {
                selected.append(task)
                if selected.count >= maxItems {
                    return selected
                }
            }
        }

        return selected
    }

    private static func uniqueTasks(tasks: [TaskDefinition]) -> [TaskDefinition] {
        var seen = Set<UUID>()
        return tasks.filter { seen.insert($0.id).inserted }
    }

    private static func uniqueNames(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { item in
            let cleaned = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.isEmpty == false else { return false }
            return seen.insert(cleaned.lowercased()).inserted
        }
    }

    private static func rankTasks(
        _ tasks: [TaskDefinition],
        query: String,
        queryTerms: [String],
        projectNameByID: [UUID: String],
        lifeAreaNameByID: [UUID: String]
    ) -> [TaskDefinition] {
        let lexicallyRanked = tasks.sorted { lhs, rhs in
            let lhsScore = taskMatchScore(
                lhs,
                queryTerms: queryTerms,
                projectNameByID: projectNameByID,
                lifeAreaNameByID: lifeAreaNameByID
            )
            let rhsScore = taskMatchScore(
                rhs,
                queryTerms: queryTerms,
                projectNameByID: projectNameByID,
                lifeAreaNameByID: lifeAreaNameByID
            )
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            if lhs.dueDate != rhs.dueDate {
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        guard queryTerms.isEmpty == false else { return lexicallyRanked }

        let semanticIDs = TaskSemanticRetrievalService.shared.rerank(
            taskIDs: lexicallyRanked.map(\.id),
            query: query
        )
        let rankedLookup = uniqueDictionary(
            lexicallyRanked.map { ($0.id, $0) },
            source: "tasks",
            context: "rankTasks"
        )
        return semanticIDs.compactMap { rankedLookup[$0] }
    }

    private static func taskMatchScore(
        _ task: TaskDefinition,
        queryTerms: [String],
        projectNameByID: [UUID: String],
        lifeAreaNameByID: [UUID: String]
    ) -> Int {
        guard queryTerms.isEmpty == false else { return 0 }
        let title = task.title.lowercased()
        let projectName = projectName(for: task, projectNameByID: projectNameByID).lowercased()
        let lifeAreaName = task.lifeAreaID.flatMap { lifeAreaNameByID[$0] }?.lowercased() ?? ""

        var score = 0
        for term in queryTerms {
            if title.contains(term) {
                score += 4
            }
            if projectName.contains(term) {
                score += 2
            }
            if lifeAreaName.contains(term) {
                score += 1
            }
        }
        return score
    }

    private static func orderProjectNames(
        projects: [Project],
        attachedTasks: [TaskDefinition],
        queryTerms: [String]
    ) -> [String] {
        let attachedIDs = Set(attachedTasks.map(\.projectID))

        return projects
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { lhs, rhs in
                let lhsAttached = attachedIDs.contains(lhs.id)
                let rhsAttached = attachedIDs.contains(rhs.id)
                if lhsAttached != rhsAttached {
                    return lhsAttached && !rhsAttached
                }
                let lhsScore = textMatchScore(lhs.name, queryTerms: queryTerms)
                let rhsScore = textMatchScore(rhs.name, queryTerms: queryTerms)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map(\.name)
    }

    private static func orderLifeAreaNames(
        lifeAreas: [LifeArea],
        attachedTasks: [TaskDefinition],
        queryTerms: [String]
    ) -> [String] {
        let attachedIDs = Set(attachedTasks.compactMap(\.lifeAreaID))
        return lifeAreas
            .sorted { lhs, rhs in
                let lhsAttached = attachedIDs.contains(lhs.id)
                let rhsAttached = attachedIDs.contains(rhs.id)
                if lhsAttached != rhsAttached {
                    return lhsAttached && !rhsAttached
                }
                let lhsScore = textMatchScore(lhs.name, queryTerms: queryTerms)
                let rhsScore = textMatchScore(rhs.name, queryTerms: queryTerms)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map(\.name)
    }

    private static func textMatchScore(_ text: String, queryTerms: [String]) -> Int {
        guard queryTerms.isEmpty == false else { return 0 }
        let normalizedText = text.lowercased()
        return queryTerms.reduce(into: 0) { score, term in
            if normalizedText.contains(term) {
                score += 1
            }
        }
    }
}

private struct LLMChatPlanningTaskBuckets {
    let overdue: [TaskDefinition]
    let today: [TaskDefinition]
    let tomorrow: [TaskDefinition]
    let thisWeek: [TaskDefinition]
    let unscheduled: [TaskDefinition]

    var allTasks: [TaskDefinition] {
        overdue + today + tomorrow + thisWeek + unscheduled
    }
}

private struct PlanningContextAccumulator {
    private(set) var lines: [String] = []
    private(set) var currentChars = 0
    let maxChars: Int

    mutating func append(_ line: String) -> Bool {
        let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanLine.isEmpty == false else { return true }
        let extraChars = lines.isEmpty ? cleanLine.count : cleanLine.count + 1
        guard currentChars + extraChars <= maxChars else { return false }
        lines.append(cleanLine)
        currentChars += extraChars
        return true
    }

    var rendered: String {
        lines.joined(separator: "\n")
    }
}

struct LLMChatPlanningContextBuildResult {
    let payload: String
    let usedTimeoutFallback: Bool
}

enum LLMChatPlanningContextBuilder {
    static func build(
        timeoutMs: UInt64,
        service: LLMContextProjectionService?,
        query: String,
        budgets: LLMChatBudgets = .active,
        model: ModelConfiguration = .defaultModel,
        contextCharBudgetOverride: Int? = nil
    ) async -> LLMChatPlanningContextBuildResult {
        guard let service else {
            return LLMChatPlanningContextBuildResult(
                payload: fallbackPayload,
                usedTimeoutFallback: true
            )
        }

        let contextCharBudget = contextCharBudgetOverride ?? budgets.resolved(for: model).maxContextChars
        let result = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) {
            await service.buildChatPlanningContext(query: query, maxChars: contextCharBudget)
        }

        if result.timedOut {
            return LLMChatPlanningContextBuildResult(
                payload: fallbackPayload,
                usedTimeoutFallback: true
            )
        }

        return LLMChatPlanningContextBuildResult(
            payload: result.payload,
            usedTimeoutFallback: false
        )
    }

    private static let fallbackPayload = """
    Planning context:
    Status: partial
    """
}

struct LLMChatContextPartialFlags {
    let missingService: Bool
    let todayTimedOut: Bool
    let overdueTimedOut: Bool
    let upcomingTimedOut: Bool

    var contextPartial: Bool {
        missingService || todayTimedOut || overdueTimedOut || upcomingTimedOut
    }

    var partialReasons: [String] {
        var reasons: [String] = []
        if missingService { reasons.append("missing_service") }
        if todayTimedOut { reasons.append("today_timeout") }
        if overdueTimedOut { reasons.append("overdue_timeout") }
        if upcomingTimedOut { reasons.append("upcoming_timeout") }
        return reasons
    }

    func asDictionary() -> [String: Any] {
        [
            "missing_service": missingService,
            "today_timed_out": todayTimedOut,
            "overdue_timed_out": overdueTimedOut,
            "upcoming_timed_out": upcomingTimedOut,
            "context_partial": contextPartial
        ]
    }
}

struct LLMChatContextMetadata {
    let timezone: String
    let generatedAtISO: String
    let contextVersion: Int
    let contextPartial: Bool
    let partialReasons: [String]
    let injectionPolicy: String

    func asDictionary() -> [String: Any] {
        [
            "timezone": timezone,
            "generated_at_iso": generatedAtISO,
            "context_version": contextVersion,
            "context_partial": contextPartial,
            "partial_reasons": partialReasons,
            "injection_policy": injectionPolicy
        ]
    }
}

struct LLMChatContextEnvelope {
    let todayJSON: String
    let overdueJSON: String
    let upcomingJSON: String
    let metadata: LLMChatContextMetadata
    let partialFlags: LLMChatContextPartialFlags

    func toJSONString() -> String {
        let payload: [String: Any] = [
            "today": Self.decodeJSONObject(from: todayJSON),
            "overdue": Self.decodeJSONObject(from: overdueJSON),
            "upcoming": Self.decodeJSONObject(from: upcomingJSON),
            "metadata": metadata.asDictionary(),
            "partial_flags": partialFlags.asDictionary()
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }

    var promptBlock: String {
        """
        Context JSON:
        \(toJSONString())
        """
    }

    /// Executes decodeJSONObject.
    private static func decodeJSONObject(from raw: String) -> Any {
        guard let data = raw.data(using: .utf8) else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []) else { return [:] }
        if let dictionary = object as? [String: Any] {
            return dictionary
        }
        if let array = object as? [Any] {
            return array
        }
        return [:]
    }
}

struct LLMChatContextBuildResult {
    let payload: String
    let usedTimeoutFallback: Bool
    let envelope: LLMChatContextEnvelope
}

enum LLMChatContextEnvelopeBuilder {
    /// Executes build.
    static func build(
        timeoutMs: UInt64,
        service: LLMContextProjectionService?,
        injectionPolicy: String = "per_turn",
        budgets: LLMChatBudgets = .active,
        contextStrategy: LLMChatContextStrategy = V2FeatureFlags.llmChatContextStrategy
    ) async -> LLMChatContextBuildResult {
        guard let service else {
            let partialFlags = LLMChatContextPartialFlags(
                missingService: true,
                todayTimedOut: false,
                overdueTimedOut: false,
                upcomingTimedOut: false
            )
            let metadata = LLMChatContextMetadata(
                timezone: TimeZone.current.identifier,
                generatedAtISO: Date().ISO8601Format(),
                contextVersion: 3,
                contextPartial: partialFlags.contextPartial,
                partialReasons: partialFlags.partialReasons,
                injectionPolicy: injectionPolicy
            )
            let envelope = LLMChatContextEnvelope(
                todayJSON: "{}",
                overdueJSON: "{}",
                upcomingJSON: "{}",
                metadata: metadata,
                partialFlags: partialFlags
            )
            return LLMChatContextBuildResult(
                payload: envelope.promptBlock,
                usedTimeoutFallback: true,
                envelope: envelope
            )
        }

        let scopedService = service.withProjectionBudget(
            maxTasksPerSlice: budgets.maxProjectionTasksPerSlice,
            compactTaskPayload: contextStrategy == .bounded
        )

        let todayValue = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) {
            await scopedService.buildTodayJSON()
        }

        var overdueValue: (payload: String, timedOut: Bool) = ("{}", false)
        var upcomingValue: (payload: String, timedOut: Bool) = ("{}", false)

        if Task.isCancelled {
            overdueValue = ("{}", true)
            upcomingValue = ("{}", true)
        } else if todayValue.timedOut {
            // Under pressure, avoid launching additional projection work this turn.
            overdueValue = ("{}", true)
            upcomingValue = ("{}", true)
            logWarning(
                event: "chat_context_slice_short_circuit",
                message: "Skipped overdue/upcoming context slices after today slice timeout",
                fields: ["slice": "today"]
            )
        } else {
            overdueValue = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) {
                await scopedService.buildOverdueJSON()
            }
            if Task.isCancelled {
                upcomingValue = ("{}", true)
            } else if overdueValue.timedOut {
                upcomingValue = ("{}", true)
                logWarning(
                    event: "chat_context_slice_short_circuit",
                    message: "Skipped upcoming context slice after overdue timeout",
                    fields: ["slice": "overdue"]
                )
            } else {
                upcomingValue = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) {
                    await scopedService.buildUpcomingJSON()
                }
            }
        }

        let partialFlags = LLMChatContextPartialFlags(
            missingService: false,
            todayTimedOut: todayValue.timedOut,
            overdueTimedOut: overdueValue.timedOut,
            upcomingTimedOut: upcomingValue.timedOut
        )
        let metadata = LLMChatContextMetadata(
            timezone: TimeZone.current.identifier,
            generatedAtISO: Date().ISO8601Format(),
            contextVersion: 3,
            contextPartial: partialFlags.contextPartial,
            partialReasons: partialFlags.partialReasons,
            injectionPolicy: injectionPolicy
        )
        let envelope = LLMChatContextEnvelope(
            todayJSON: todayValue.payload,
            overdueJSON: overdueValue.payload,
            upcomingJSON: upcomingValue.payload,
            metadata: metadata,
            partialFlags: partialFlags
        )
        return LLMChatContextBuildResult(
            payload: envelope.promptBlock,
            usedTimeoutFallback: partialFlags.contextPartial,
            envelope: envelope
        )
    }
}

struct EvaExecutiveContextSnapshot: Equatable {
    let promptBlock: String
    let generatedAt: Date
    let completedCount: Int
    let overdueRemainingCount: Int
    let dueSoonCount: Int
    let workloadMode: String
}

private actor EvaExecutiveContextCache {
    struct Key: Hashable {
        let repositorySignature: String
        let dayStamp: String
        let maxChars: Int
    }

    private var snapshots: [Key: EvaExecutiveContextSnapshot] = [:]

    func snapshot(for key: Key) -> EvaExecutiveContextSnapshot? {
        snapshots[key]
    }

    func store(_ snapshot: EvaExecutiveContextSnapshot, for key: Key) {
        snapshots[key] = snapshot
    }

    func clear() {
        snapshots.removeAll()
    }
}

struct EvaExecutiveContextService {
    let taskReadModelRepository: TaskReadModelRepositoryProtocol
    let projectRepository: ProjectRepositoryProtocol
    let lifeAreaRepository: LifeAreaRepositoryProtocol?

    private static let cache = EvaExecutiveContextCache()

    static func makeDefault() -> EvaExecutiveContextService? {
        guard let taskReadModelRepository = LLMContextRepositoryProvider.taskReadModelRepository,
              let projectRepository = LLMContextRepositoryProvider.projectRepository else {
            return nil
        }
        return EvaExecutiveContextService(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository,
            lifeAreaRepository: LLMContextRepositoryProvider.lifeAreaRepository
        )
    }

    static func invalidateCache() async {
        await cache.clear()
    }

    func buildSnapshot(
        maxChars: Int,
        now: Date = Date()
    ) async -> EvaExecutiveContextSnapshot {
        guard V2FeatureFlags.llmExecutiveContextEnabled else {
            return EvaExecutiveContextSnapshot(
                promptBlock: "",
                generatedAt: now,
                completedCount: 0,
                overdueRemainingCount: 0,
                dueSoonCount: 0,
                workloadMode: "disabled"
            )
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let dayStamp = ISO8601DateFormatter().string(from: startOfToday)
        let repositorySignature = [
            String(ObjectIdentifier(taskReadModelRepository as AnyObject).hashValue),
            String(ObjectIdentifier(projectRepository as AnyObject).hashValue),
            lifeAreaRepository.map { String(ObjectIdentifier($0 as AnyObject).hashValue) } ?? "nil"
        ].joined(separator: "|")
        let cacheKey = EvaExecutiveContextCache.Key(
            repositorySignature: repositorySignature,
            dayStamp: dayStamp,
            maxChars: maxChars
        )
        if let cached = await Self.cache.snapshot(for: cacheKey) {
            return cached
        }
        let windowStart = calendar.date(byAdding: .day, value: -14, to: startOfToday) ?? startOfToday
        let dueSoonEnd = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday

        async let recentTasksTask = fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                updatedAfter: windowStart,
                sortBy: .updatedAtDescending,
                limit: 512,
                offset: 0
            )
        )
        async let overdueTasksTask = fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateEnd: startOfToday,
                sortBy: .dueDateAscending,
                limit: 256,
                offset: 0
            )
        )
        async let dueSoonTasksTask = fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateStart: startOfToday,
                dueDateEnd: dueSoonEnd,
                sortBy: .dueDateAscending,
                limit: 256,
                offset: 0
            )
        )
        async let projectsTask = fetchProjects()
        async let lifeAreasTask = fetchLifeAreas()

        let recentTasks = await recentTasksTask
        let overdueTasks = await overdueTasksTask
        let dueSoonTasks = await dueSoonTasksTask
        let projects = await projectsTask
        let lifeAreas = await lifeAreasTask
        let filteredOverdueTasks = overdueTasks.filter { task in
            guard task.isComplete == false, let dueDate = task.dueDate else { return false }
            return dueDate < startOfToday
        }

        let projectNameByID = uniqueDictionary(
            projects.map { ($0.id, $0.name) },
            source: "projects",
            context: "EvaExecutiveContextService"
        )
        let lifeAreaNameByID = uniqueDictionary(
            lifeAreas.map { ($0.id, $0.name) },
            source: "life_areas",
            context: "EvaExecutiveContextService"
        )

        let completedCount = recentTasks.filter { task in
            guard task.isComplete, let completedAt = task.dateCompleted else { return false }
            return completedAt >= windowStart && completedAt <= now
        }.count
        let overdueRemainingCount = filteredOverdueTasks.count
        let dueSoonCount = dueSoonTasks.count

        let topProjects = rankedLabels(
            scores: aggregateProjectScores(
                touchedTasks: recentTasks,
                overdueTasks: filteredOverdueTasks,
                dueSoonTasks: dueSoonTasks,
                projectNameByID: projectNameByID
            ),
            limit: 3
        )
        let topLifeAreas = rankedLabels(
            scores: aggregateLifeAreaScores(
                touchedTasks: recentTasks,
                overdueTasks: filteredOverdueTasks,
                dueSoonTasks: dueSoonTasks,
                lifeAreaNameByID: lifeAreaNameByID
            ),
            limit: 3
        )
        let pressurePoints = buildPressurePoints(
            now: now,
            overdueTasks: filteredOverdueTasks,
            dueSoonTasks: dueSoonTasks,
            projectNameByID: projectNameByID,
            lifeAreaNameByID: lifeAreaNameByID,
            limit: 2
        )
        let workloadMode = workloadMode(
            completedCount: completedCount,
            overdueRemainingCount: overdueRemainingCount,
            dueSoonCount: dueSoonCount
        )

        var accumulator = PlanningContextAccumulator(maxChars: max(240, maxChars))
        _ = accumulator.append("14-day operating summary:")
        _ = accumulator.append("Completed: \(completedCount); overdue remaining: \(overdueRemainingCount); due soon: \(dueSoonCount).")
        _ = accumulator.append("Projects in motion: \(topProjects.isEmpty ? "none" : topProjects.joined(separator: ", ")).")
        _ = accumulator.append("Life areas in motion: \(topLifeAreas.isEmpty ? "none" : topLifeAreas.joined(separator: ", ")).")
        _ = accumulator.append("Pressure points: \(pressurePoints.isEmpty ? "none" : pressurePoints.joined(separator: "; ")).")
        _ = accumulator.append("Mode: \(workloadMode).")

        let snapshot = EvaExecutiveContextSnapshot(
            promptBlock: accumulator.rendered,
            generatedAt: now,
            completedCount: completedCount,
            overdueRemainingCount: overdueRemainingCount,
            dueSoonCount: dueSoonCount,
            workloadMode: workloadMode
        )
        await Self.cache.store(snapshot, for: cacheKey)
        return snapshot
    }

    private func fetchTasks(query: TaskReadQuery) async -> [TaskDefinition] {
        await withCheckedContinuation { continuation in
            taskReadModelRepository.fetchTasks(query: query) { result in
                let slice = (try? result.get())?.tasks ?? []
                continuation.resume(returning: slice)
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

    private func aggregateProjectScores(
        touchedTasks: [TaskDefinition],
        overdueTasks: [TaskDefinition],
        dueSoonTasks: [TaskDefinition],
        projectNameByID: [UUID: String]
    ) -> [String: Int] {
        var scores: [String: Int] = [:]
        for task in touchedTasks {
            let label = projectLabel(for: task, projectNameByID: projectNameByID)
            scores[label, default: 0] += 1
        }
        for task in overdueTasks {
            let label = projectLabel(for: task, projectNameByID: projectNameByID)
            scores[label, default: 0] += 3
        }
        for task in dueSoonTasks {
            let label = projectLabel(for: task, projectNameByID: projectNameByID)
            scores[label, default: 0] += 2
        }
        return scores
    }

    private func aggregateLifeAreaScores(
        touchedTasks: [TaskDefinition],
        overdueTasks: [TaskDefinition],
        dueSoonTasks: [TaskDefinition],
        lifeAreaNameByID: [UUID: String]
    ) -> [String: Int] {
        var scores: [String: Int] = [:]
        for task in touchedTasks {
            let label = lifeAreaLabel(for: task, lifeAreaNameByID: lifeAreaNameByID)
            scores[label, default: 0] += 1
        }
        for task in overdueTasks {
            let label = lifeAreaLabel(for: task, lifeAreaNameByID: lifeAreaNameByID)
            scores[label, default: 0] += 3
        }
        for task in dueSoonTasks {
            let label = lifeAreaLabel(for: task, lifeAreaNameByID: lifeAreaNameByID)
            scores[label, default: 0] += 2
        }
        return scores
    }

    private func buildPressurePoints(
        now: Date,
        overdueTasks: [TaskDefinition],
        dueSoonTasks: [TaskDefinition],
        projectNameByID: [UUID: String],
        lifeAreaNameByID: [UUID: String],
        limit: Int
    ) -> [String] {
        let calendar = Calendar.current
        var scores: [String: Int] = [:]
        for task in overdueTasks {
            scores[projectLabel(for: task, projectNameByID: projectNameByID), default: 0] += 1
            scores[lifeAreaLabel(for: task, lifeAreaNameByID: lifeAreaNameByID), default: 0] += 1
        }
        for task in dueSoonTasks {
            guard let dueDate = task.dueDate,
                  let days = calendar.dateComponents([.day], from: now, to: dueDate).day,
                  days <= 2 else { continue }
            scores[projectLabel(for: task, projectNameByID: projectNameByID), default: 0] += 1
        }

        return scores
            .filter { $0.key != "none" && $0.value > 1 }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }
            .prefix(limit)
            .map { "\($0.key) (\($0.value) pressure)" }
    }

    private func rankedLabels(scores: [String: Int], limit: Int) -> [String] {
        scores
            .filter { $0.key != "none" && $0.value > 0 }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }
            .prefix(limit)
            .map(\.key)
    }

    private func workloadMode(
        completedCount: Int,
        overdueRemainingCount: Int,
        dueSoonCount: Int
    ) -> String {
        let reactivePressure = overdueRemainingCount * 2 + dueSoonCount
        if reactivePressure > max(4, completedCount) {
            return "mostly reactive"
        }
        if completedCount >= max(3, overdueRemainingCount + 1) {
            return "mostly planned"
        }
        return "mixed"
    }

    private func projectLabel(
        for task: TaskDefinition,
        projectNameByID: [UUID: String]
    ) -> String {
        let projectName = (projectNameByID[task.projectID] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if projectName.isEmpty == false {
            return projectName
        }
        let fallback = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fallback.isEmpty ? ProjectConstants.inboxProjectName : fallback
    }

    private func lifeAreaLabel(
        for task: TaskDefinition,
        lifeAreaNameByID: [UUID: String]
    ) -> String {
        guard let lifeAreaID = task.lifeAreaID,
              let lifeAreaName = lifeAreaNameByID[lifeAreaID],
              lifeAreaName.isEmpty == false else {
            return "none"
        }
        return lifeAreaName
    }
}
