import Foundation

public final class UpdateTaskDefinitionUseCase {
    private let repository: TaskDefinitionRepositoryProtocol
    private let taskTagLinkRepository: TaskTagLinkRepositoryProtocol?
    private let taskDependencyRepository: TaskDependencyRepositoryProtocol?

    /// Initializes a new instance.
    public init(
        repository: TaskDefinitionRepositoryProtocol,
        taskTagLinkRepository: TaskTagLinkRepositoryProtocol? = nil,
        taskDependencyRepository: TaskDependencyRepositoryProtocol? = nil
    ) {
        self.repository = repository
        self.taskTagLinkRepository = taskTagLinkRepository
        self.taskDependencyRepository = taskDependencyRepository
    }

    /// Executes execute.
    public func execute(
        request: UpdateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        repository.update(request: request) { result in
            switch result {
            case .success(let updatedTask):
                self.persistLinks(taskID: updatedTask.id, request: request) { linkResult in
                    switch linkResult {
                    case .success:
                        TaskNotificationDispatcher.postOnMain(
                            name: NSNotification.Name("TaskUpdated"),
                            object: updatedTask
                        )
                        TaskNotificationDispatcher.postOnMain(
                            name: .homeTaskMutation,
                            userInfo: [
                                "reason": "updated",
                                "source": "updateTaskDefinitionUseCase",
                                "taskID": updatedTask.id.uuidString
                            ]
                        )
                        completion(.success(updatedTask))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes persistLinks.
    private func persistLinks(
        taskID: UUID,
        request: UpdateTaskDefinitionRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let group = DispatchGroup()
        var firstError: Error?
        let lock = NSLock()

        /// Executes capture.
        func capture(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        if let tagIDs = request.tagIDs, let taskTagLinkRepository {
            group.enter()
            taskTagLinkRepository.replaceTagLinks(taskID: taskID, tagIDs: tagIDs) { result in
                if case .failure(let error) = result {
                    capture(error)
                }
                group.leave()
            }
        }

        if let dependencies = request.dependencies, let taskDependencyRepository {
            group.enter()
            let normalizedDependencies = dependencies.map { dependency in
                TaskDependencyLinkDefinition(
                    id: dependency.id,
                    taskID: taskID,
                    dependsOnTaskID: dependency.dependsOnTaskID,
                    kind: dependency.kind,
                    createdAt: dependency.createdAt
                )
            }
            taskDependencyRepository.replaceDependencies(taskID: taskID, dependencies: normalizedDependencies) { result in
                if case .failure(let error) = result {
                    capture(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(()))
            }
        }
    }
}
