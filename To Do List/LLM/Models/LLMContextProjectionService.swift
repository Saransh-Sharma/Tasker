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

    /// Executes findProjectNameSync.
    static func findProjectNameSync(matching query: String) -> String? {
        guard let projectRepository = projectRepositoryStorage else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let semaphore = DispatchSemaphore(value: 0)
        var matched: String?
        projectRepository.fetchAllProjects { result in
            defer { semaphore.signal() }
            guard case .success(let projects) = result else { return }
            let normalized = trimmed.lowercased()
            matched = projects.first(where: { $0.name.lowercased().contains(normalized) })?.name
        }
        _ = semaphore.wait(timeout: .now() + .seconds(3))
        return matched
    }

    /// Executes projectNameLookupSync.
    static func projectNameLookupSync() -> [UUID: String] {
        guard let projectRepository = projectRepositoryStorage else { return [:] }

        let semaphore = DispatchSemaphore(value: 0)
        var lookup: [UUID: String] = [:]
        projectRepository.fetchAllProjects { result in
            defer { semaphore.signal() }
            guard case .success(let projects) = result else { return }
            lookup = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })
        }
        _ = semaphore.wait(timeout: .now() + .seconds(3))
        return lookup
    }
}

struct LLMContextProjectionService {
    let taskReadModelRepository: TaskReadModelRepositoryProtocol
    let projectRepository: ProjectRepositoryProtocol
    let tagRepository: TagRepositoryProtocol?

    /// Executes buildTodayJSON.
    func buildTodayJSON(completion: @escaping (String) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        let endOfDay = startOfTomorrow.addingTimeInterval(-1)

        taskReadModelRepository.fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateStart: startOfDay,
                dueDateEnd: endOfDay,
                sortBy: .dueDateAscending,
                limit: 1_000,
                offset: 0
            )
        ) { result in
            let tasks = (try? result.get().tasks) ?? []
            let tagNameLookup = buildTagNameLookupSync()
            completion(Self.encode(
                tasks: tasks,
                contextType: "today",
                metadata: defaultMetadata(),
                tagNameLookup: tagNameLookup
            ))
        }
    }

    /// Executes buildUpcomingJSON.
    func buildUpcomingJSON(completion: @escaping (String) -> Void) {
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())

        taskReadModelRepository.fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateStart: tomorrow,
                sortBy: .dueDateAscending,
                limit: 1_000,
                offset: 0
            )
        ) { result in
            let tasks = (try? result.get().tasks) ?? []
            let tagNameLookup = buildTagNameLookupSync()
            completion(Self.encode(
                tasks: tasks,
                contextType: "upcoming",
                metadata: defaultMetadata(),
                tagNameLookup: tagNameLookup
            ))
        }
    }

    /// Executes buildProjectJSON.
    func buildProjectJSON(projectID: UUID, completion: @escaping (String) -> Void) {
        projectRepository.fetchProject(withId: projectID) { projectResult in
            let projectName: String
            switch projectResult {
            case .success(let project):
                projectName = project?.name ?? ""
            case .failure:
                projectName = ""
            }
            taskReadModelRepository.fetchTasks(
                query: TaskReadQuery(
                    projectID: projectID,
                    includeCompleted: true,
                    sortBy: .dueDateAscending,
                    limit: 1_000,
                    offset: 0
                )
            ) { result in
                let tasks = (try? result.get().tasks) ?? []
                var metadata = defaultMetadata()
                metadata["project_id"] = projectID.uuidString
                metadata["project_name"] = projectName
                completion(
                    Self.encode(
                        tasks: tasks,
                        contextType: "project",
                        metadata: metadata,
                        tagNameLookup: buildTagNameLookupSync()
                    )
                )
            }
        }
    }

    /// Executes defaultMetadata.
    private func defaultMetadata() -> [String: Any] {
        [
            "timezone": TimeZone.current.identifier,
            "generated_at_iso": Date().ISO8601Format(),
            "context_version": 2
        ]
    }

    /// Executes buildTagNameLookupSync.
    private func buildTagNameLookupSync() -> [UUID: String] {
        guard let tagRepository else { return [:] }
        let semaphore = DispatchSemaphore(value: 0)
        var lookup: [UUID: String] = [:]

        tagRepository.fetchAll { result in
            defer { semaphore.signal() }
            guard case .success(let tags) = result else { return }
            lookup = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        }

        _ = semaphore.wait(timeout: .now() + .seconds(3))
        return lookup
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
