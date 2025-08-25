import Foundation
import CoreData

// MARK: - Use Case
protocol UpdateTaskUseCase {
    func execute(taskID: NSManagedObjectID, data: TaskData, completion: ((Result<Void, Error>) -> Void)?)
}

// MARK: - Implementation
struct UpdateTaskUseCaseImpl: UpdateTaskUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func execute(taskID: NSManagedObjectID, data: TaskData, completion: ((Result<Void, Error>) -> Void)?) {
        repository.updateTask(taskID: taskID, data: data, completion: completion)
    }
}
