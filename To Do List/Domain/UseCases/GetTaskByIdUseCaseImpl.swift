import Foundation
import CoreData

// MARK: - Implementation
struct GetTaskByIdUseCaseImpl: GetTaskByIdUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func execute(taskID: NSManagedObjectID, completion: @escaping (Result<NTask, Error>) -> Void) {
        repository.fetchTask(by: taskID, completion: completion)
    }
}
