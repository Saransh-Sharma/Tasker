import Foundation
import CoreData

// MARK: - Use Case
protocol ToggleTaskCompletionUseCase {
    func execute(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?)
}

// MARK: - Implementation
struct ToggleTaskCompletionUseCaseImpl: ToggleTaskCompletionUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func execute(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?) {
        repository.toggleComplete(taskID: taskID, completion: completion)
    }
}
