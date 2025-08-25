import Foundation

// MARK: - Use Case
protocol GetInboxTasksForDateUseCase {
    func execute(date: Date, completion: @escaping ([TaskData]) -> Void)
}

// MARK: - Implementation
struct GetInboxTasksForDateUseCaseImpl: GetInboxTasksForDateUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func execute(date: Date, completion: @escaping ([TaskData]) -> Void) {
        repository.getTasksForInbox(date: date, completion: completion)
    }
}
