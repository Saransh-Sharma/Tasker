import Foundation

// MARK: - Use Case
protocol GetEveningTasksForDateUseCase {
    func execute(date: Date, completion: @escaping ([TaskData]) -> Void)
}

// MARK: - Implementation
struct GetEveningTasksForDateUseCaseImpl: GetEveningTasksForDateUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func execute(date: Date, completion: @escaping ([TaskData]) -> Void) {
        repository.getEveningTasks(for: date, completion: completion)
    }
}
