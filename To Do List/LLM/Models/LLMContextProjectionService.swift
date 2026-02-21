import Foundation

enum LLMContextRepositoryProvider {
    private static var taskReadModelRepositoryStorage: TaskReadModelRepositoryProtocol?
    private static var projectRepositoryStorage: ProjectRepositoryProtocol?

    static var taskReadModelRepository: TaskReadModelRepositoryProtocol? { taskReadModelRepositoryStorage }
    static var projectRepository: ProjectRepositoryProtocol? { projectRepositoryStorage }

    /// Executes configure.
    static func configure(
        taskReadModelRepository: TaskReadModelRepositoryProtocol?,
        projectRepository: ProjectRepositoryProtocol?
    ) {
        self.taskReadModelRepositoryStorage = taskReadModelRepository
        self.projectRepositoryStorage = projectRepository
    }

    /// Executes makeService.
    static func makeService() -> LLMContextProjectionService? {
        guard let taskReadModelRepository = taskReadModelRepositoryStorage,
              let projectRepository = projectRepositoryStorage else {
            return nil
        }
        return LLMContextProjectionService(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository
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
}

struct LLMContextProjectionService {
    let taskReadModelRepository: TaskReadModelRepositoryProtocol
    let projectRepository: ProjectRepositoryProtocol

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
            completion(Self.encode(tasks: tasks, contextType: "today"))
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
            completion(Self.encode(tasks: tasks, contextType: "upcoming"))
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
                completion(
                    Self.encode(
                        tasks: tasks,
                        contextType: "project",
                        metadata: [
                            "project_id": projectID.uuidString,
                            "project_name": projectName
                        ]
                    )
                )
            }
        }
    }

    /// Executes encode.
    private static func encode(tasks: [TaskDefinition], contextType: String, metadata: [String: Any] = [:]) -> String {
        var payload: [String: Any] = [
            "context_type": contextType,
            "count": tasks.count,
            "tasks": tasks.map { task in
                [
                    "id": task.id.uuidString,
                    "title": task.title,
                    "is_completed": task.isComplete,
                    "project": task.projectName ?? "",
                    "priority": task.priority.rawValue,
                    "due_date": task.dueDate?.ISO8601Format() as Any
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
