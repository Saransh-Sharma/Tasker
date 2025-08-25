import Foundation
import CoreData

// MARK: - Use Case
protocol RescheduleTaskUseCase {
    func execute(taskID: NSManagedObjectID, to newDate: Date, completion: ((Result<Void, Error>) -> Void)?)
}

// MARK: - Implementation
struct RescheduleTaskUseCaseImpl: RescheduleTaskUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func execute(taskID: NSManagedObjectID, to newDate: Date, completion: ((Result<Void, Error>) -> Void)?) {
        repository.reschedule(taskID: taskID, to: newDate, completion: completion)
    }
}
