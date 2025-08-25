import Foundation
import CoreData

// MARK: - Use Case
protocol AddTaskUseCase {
    func execute(data: TaskData, completion: ((Result<NTask, Error>) -> Void)?)
}

// MARK: - Implementation
struct AddTaskUseCaseImpl: AddTaskUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func execute(data: TaskData, completion: ((Result<NTask, Error>) -> Void)?) {
        repository.addTask(data: data, completion: completion)
    }
}
