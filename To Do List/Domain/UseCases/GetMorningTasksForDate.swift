import Foundation

// MARK: - Use Case
protocol GetMorningTasksForDateUseCase {
    func execute(date: Date, completion: @escaping ([TaskData]) -> Void)
}

// MARK: - Implementation
struct GetMorningTasksForDateUseCaseImpl: GetMorningTasksForDateUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func execute(date: Date, completion: @escaping ([TaskData]) -> Void) {
        repository.getMorningTasks(for: date, completion: completion)
    }
}
