import Foundation

// MARK: - Implementation
struct GetTasksUseCaseImpl: GetTasksUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func getMorningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void) {
        repository.getMorningTasks(for: date, completion: completion)
    }

    func getEveningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void) {
        repository.getEveningTasks(for: date, completion: completion)
    }

    func getUpcomingTasks(completion: @escaping ([TaskData]) -> Void) {
        repository.getUpcomingTasks(completion: completion)
    }

    func getTasksForInbox(on date: Date, completion: @escaping ([TaskData]) -> Void) {
        repository.getTasksForInbox(date: date, completion: completion)
    }

    func getTasksForProject(_ projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void) {
        repository.getTasksForProject(projectName: projectName, date: date, completion: completion)
    }

    func getOpenTasksForProject(_ projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void) {
        repository.getTasksForProjectOpen(projectName: projectName, date: date, completion: completion)
    }

    func getOpenTasksForAllCustomProjects(on date: Date, completion: @escaping ([TaskData]) -> Void) {
        repository.getTasksForAllCustomProjectsOpen(date: date, completion: completion)
    }
}
