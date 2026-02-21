import Foundation

public final class CompleteTaskDefinitionUseCase {
    private let repository: TaskDefinitionRepositoryProtocol
    private let gamification: RecordXPUseCase?

    /// Initializes a new instance.
    public init(repository: TaskDefinitionRepositoryProtocol, gamification: RecordXPUseCase? = nil) {
        self.repository = repository
        self.gamification = gamification
    }

    /// Executes execute.
    public func execute(taskID: UUID, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        setCompletion(taskID: taskID, to: true, completion: completion)
    }

    /// Executes setCompletion.
    public func setCompletion(
        taskID: UUID,
        to isComplete: Bool,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        repository.fetchTaskDefinition(id: taskID) { result in
            switch result {
            case .success(let task):
                guard var task else {
                    completion(.failure(NSError(domain: "CompleteTaskDefinitionUseCase", code: 404)))
                    return
                }

                task.isComplete = isComplete
                task.dateCompleted = isComplete ? Date() : nil
                task.updatedAt = Date()

                self.repository.update(task) { updateResult in
                    if case .success(let updatedTask) = updateResult {
                        if isComplete {
                            self.gamification?.recordTaskCompletion(taskID: taskID) { _ in }
                        }
                        TaskNotificationDispatcher.postOnMain(
                            name: NSNotification.Name("TaskCompletionChanged"),
                            object: updatedTask
                        )
                        TaskNotificationDispatcher.postOnMain(
                            name: .homeTaskMutation,
                            userInfo: [
                                "reason": "completionChanged",
                                "source": "completeTaskDefinitionUseCase",
                                "taskID": updatedTask.id.uuidString,
                                "isComplete": updatedTask.isComplete
                            ]
                        )
                    }
                    completion(updateResult)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes complete.
    public func complete(taskID: UUID, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        setCompletion(taskID: taskID, to: true, completion: completion)
    }

    /// Executes uncomplete.
    public func uncomplete(taskID: UUID, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        setCompletion(taskID: taskID, to: false, completion: completion)
    }
}
