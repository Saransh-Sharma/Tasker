import Foundation

public final class CompleteTaskDefinitionUseCase {
    private let repository: TaskDefinitionRepositoryProtocol
    private let gamification: RecordXPUseCase?

    public init(repository: TaskDefinitionRepositoryProtocol, gamification: RecordXPUseCase? = nil) {
        self.repository = repository
        self.gamification = gamification
    }

    public func execute(taskID: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        repository.fetchAll { result in
            switch result {
            case .success(let tasks):
                guard var task = tasks.first(where: { $0.id == taskID }) else {
                    completion(.failure(NSError(domain: "CompleteTaskDefinitionUseCase", code: 404)))
                    return
                }
                task.isComplete = true
                task.dateCompleted = Date()
                self.repository.update(task) { updateResult in
                    if case .success = updateResult {
                        self.gamification?.recordTaskCompletion(taskID: taskID) { _ in }
                    }
                    completion(updateResult)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
