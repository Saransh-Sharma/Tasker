import Foundation

enum LLMContextRepositoryProvider {
    private static var taskRepositoryStorage: TaskRepositoryProtocol?
    private static var projectRepositoryStorage: ProjectRepositoryProtocol?

    static var taskRepository: TaskRepositoryProtocol? { taskRepositoryStorage }
    static var projectRepository: ProjectRepositoryProtocol? { projectRepositoryStorage }

    static func configure(
        taskRepository: TaskRepositoryProtocol?,
        projectRepository: ProjectRepositoryProtocol?
    ) {
        self.taskRepositoryStorage = taskRepository
        self.projectRepositoryStorage = projectRepository
    }

    static func makeService() -> LLMContextProjectionService? {
        guard let taskRepository = taskRepositoryStorage,
              let projectRepository = projectRepositoryStorage else {
            return nil
        }
        return LLMContextProjectionService(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
    }

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
    let taskRepository: TaskRepositoryProtocol
    let projectRepository: ProjectRepositoryProtocol

    func buildTodayJSON(completion: @escaping (String) -> Void) {
        taskRepository.fetchTodayTasks { result in
            let tasks: [Task]
            switch result {
            case .success(let fetched): tasks = fetched
            case .failure: tasks = []
            }
            completion(Self.encode(tasks: tasks, contextType: "today"))
        }
    }

    func buildUpcomingJSON(completion: @escaping (String) -> Void) {
        taskRepository.fetchUpcomingTasks { result in
            let tasks: [Task]
            switch result {
            case .success(let fetched): tasks = fetched
            case .failure: tasks = []
            }
            completion(Self.encode(tasks: tasks, contextType: "upcoming"))
        }
    }

    func buildProjectJSON(projectID: UUID, completion: @escaping (String) -> Void) {
        projectRepository.fetchProject(withId: projectID) { projectResult in
            let projectName: String
            switch projectResult {
            case .success(let project):
                projectName = project?.name ?? ""
            case .failure:
                projectName = ""
            }
            taskRepository.fetchTasks(forProjectID: projectID) { result in
                let tasks: [Task]
                switch result {
                case .success(let fetched): tasks = fetched
                case .failure: tasks = []
                }
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

    private static func encode(tasks: [Task], contextType: String, metadata: [String: Any] = [:]) -> String {
        var payload: [String: Any] = [
            "context_type": contextType,
            "count": tasks.count,
            "tasks": tasks.map { task in
                [
                    "id": task.id.uuidString,
                    "title": task.name,
                    "is_completed": task.isComplete,
                    "project": task.project ?? "",
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
