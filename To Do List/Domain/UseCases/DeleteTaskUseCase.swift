import Foundation
import CoreData

// MARK: - Use Case
protocol DeleteTaskUseCase {
    func execute(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?)
}

// MARK: - Implementation
struct DeleteTaskUseCaseImpl: DeleteTaskUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func execute(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?) {
        repository.deleteTask(taskID: taskID, completion: completion)
    }
}
