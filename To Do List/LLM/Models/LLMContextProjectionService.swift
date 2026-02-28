import Foundation

enum LLMContextRepositoryProvider {
    private static var taskReadModelRepositoryStorage: TaskReadModelRepositoryProtocol?
    private static var projectRepositoryStorage: ProjectRepositoryProtocol?
    private static var tagRepositoryStorage: TagRepositoryProtocol?

    static var taskReadModelRepository: TaskReadModelRepositoryProtocol? { taskReadModelRepositoryStorage }
    static var projectRepository: ProjectRepositoryProtocol? { projectRepositoryStorage }
    static var tagRepository: TagRepositoryProtocol? { tagRepositoryStorage }

    /// Executes configure.
    static func configure(
        taskReadModelRepository: TaskReadModelRepositoryProtocol?,
        projectRepository: ProjectRepositoryProtocol?,
        tagRepository: TagRepositoryProtocol? = nil
    ) {
        self.taskReadModelRepositoryStorage = taskReadModelRepository
        self.projectRepositoryStorage = projectRepository
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
        return Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })
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
    let tagRepository: TagRepositoryProtocol?
    let maxTasksPerSlice: Int
    let compactTaskPayload: Bool

    init(
        taskReadModelRepository: TaskReadModelRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        tagRepository: TagRepositoryProtocol?,
        maxTasksPerSlice: Int = 1_000,
        compactTaskPayload: Bool = false
    ) {
        self.taskReadModelRepository = taskReadModelRepository
        self.projectRepository = projectRepository
        self.tagRepository = tagRepository
        self.maxTasksPerSlice = max(1, maxTasksPerSlice)
        self.compactTaskPayload = compactTaskPayload
    }

    func withProjectionBudget(maxTasksPerSlice: Int, compactTaskPayload: Bool) -> LLMContextProjectionService {
        LLMContextProjectionService(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository,
            tagRepository: tagRepository,
            maxTasksPerSlice: maxTasksPerSlice,
            compactTaskPayload: compactTaskPayload
        )
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
                continuation.resume(returning: Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) }))
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
