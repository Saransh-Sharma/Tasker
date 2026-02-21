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
    static func makeService() -> LLMContextProjectionService? {
        guard let taskReadModelRepository = taskReadModelRepositoryStorage,
              let projectRepository = projectRepositoryStorage else {
            return nil
        }
        return LLMContextProjectionService(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository,
            tagRepository: tagRepositoryStorage
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
        let normalized = trimmed.lowercased()
        return projects.first(where: { $0.name.lowercased().contains(normalized) })?.name
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
}

struct LLMContextProjectionService {
    let taskReadModelRepository: TaskReadModelRepositoryProtocol
    let projectRepository: ProjectRepositoryProtocol
    let tagRepository: TagRepositoryProtocol?

    /// Executes buildTodayJSON.
    func buildTodayJSON() async -> String {
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
                limit: 1_000,
                offset: 0
            )
        )
        let tagNameLookup = await buildTagNameLookup()
        return Self.encode(
            tasks: tasks,
            contextType: "today",
            metadata: defaultMetadata(),
            tagNameLookup: tagNameLookup
        )
    }

    /// Executes buildUpcomingJSON.
    func buildUpcomingJSON() async -> String {
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())

        let tasks = await fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateStart: tomorrow,
                sortBy: .dueDateAscending,
                limit: 1_000,
                offset: 0
            )
        )
        let tagNameLookup = await buildTagNameLookup()
        return Self.encode(
            tasks: tasks,
            contextType: "upcoming",
            metadata: defaultMetadata(),
            tagNameLookup: tagNameLookup
        )
    }

    /// Executes buildProjectJSON.
    func buildProjectJSON(projectID: UUID) async -> String {
        let projectName = await fetchProjectName(id: projectID) ?? ""
        let tasks = await fetchTasks(
            query: TaskReadQuery(
                projectID: projectID,
                includeCompleted: true,
                sortBy: .dueDateAscending,
                limit: 1_000,
                offset: 0
            )
        )
        var metadata = defaultMetadata()
        metadata["project_id"] = projectID.uuidString
        metadata["project_name"] = projectName
        return Self.encode(
            tasks: tasks,
            contextType: "project",
            metadata: metadata,
            tagNameLookup: await buildTagNameLookup()
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

    /// Executes buildProjectJSON.
    func buildProjectJSON(projectID: UUID, completion: @escaping (String) -> Void) {
        Task {
            completion(await buildProjectJSON(projectID: projectID))
        }
    }

    /// Executes fetchTasks.
    private func fetchTasks(query: TaskReadQuery) async -> [TaskDefinition] {
        await withCheckedContinuation { continuation in
            taskReadModelRepository.fetchTasks(query: query) { result in
                let tasks = (try? result.get().tasks) ?? []
                continuation.resume(returning: tasks)
            }
        }
    }

    /// Executes fetchProjectName.
    private func fetchProjectName(id: UUID) async -> String? {
        await withCheckedContinuation { continuation in
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
        tagNameLookup: [UUID: String] = [:]
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

                return [
                    "id": task.id.uuidString,
                    "title": task.title,
                    "is_completed": task.isComplete,
                    "project": projectName,
                    "project_id": task.projectID.uuidString,
                    "priority": task.priority.rawValue,
                    "energy": task.energy.rawValue,
                    "context": task.context.rawValue,
                    "type": task.type.rawValue,
                    "estimated_duration_minutes": task.estimatedDuration.map { Int($0 / 60) } ?? NSNull(),
                    "has_dependencies": !task.dependencies.isEmpty,
                    "dependency_count": task.dependencies.count,
                    "tag_ids": tagIDs,
                    "tag_names": tagNames,
                    "due_date": task.dueDate?.ISO8601Format() ?? NSNull()
                ]
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
