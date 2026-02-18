import Foundation

public final class CreateTaskDefinitionUseCase {
    private let repository: TaskDefinitionRepositoryProtocol
    private let taskTagLinkRepository: TaskTagLinkRepositoryProtocol?
    private let taskDependencyRepository: TaskDependencyRepositoryProtocol?

    public init(
        repository: TaskDefinitionRepositoryProtocol,
        taskTagLinkRepository: TaskTagLinkRepositoryProtocol? = nil,
        taskDependencyRepository: TaskDependencyRepositoryProtocol? = nil
    ) {
        self.repository = repository
        self.taskTagLinkRepository = taskTagLinkRepository
        self.taskDependencyRepository = taskDependencyRepository
    }

    public func execute(
        title: String,
        projectID: UUID,
        dueDate: Date?,
        details: String?,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        let request = CreateTaskDefinitionRequest(
            title: title,
            details: details,
            projectID: projectID,
            dueDate: dueDate,
            createdAt: Date()
        )
        execute(request: request, completion: completion)
    }

    public func execute(
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        repository.create(request: request) { result in
            switch result {
            case .success(let createdTask):
                self.persistLinks(taskID: createdTask.id, request: request) { linkResult in
                    switch linkResult {
                    case .success:
                        TaskNotificationDispatcher.postOnMain(
                            name: NSNotification.Name("TaskCreated"),
                            object: createdTask
                        )
                        TaskNotificationDispatcher.postOnMain(
                            name: .homeTaskMutation,
                            userInfo: [
                                "reason": "created",
                                "source": "createTaskDefinitionUseCase",
                                "taskID": createdTask.id.uuidString
                            ]
                        )
                        completion(.success(createdTask))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func persistLinks(
        taskID: UUID,
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let group = DispatchGroup()
        var firstError: Error?

        if let taskTagLinkRepository {
            group.enter()
            taskTagLinkRepository.replaceTagLinks(taskID: taskID, tagIDs: request.tagIDs) { result in
                if case .failure(let error) = result, firstError == nil {
                    firstError = error
                }
                group.leave()
            }
        }

        if let taskDependencyRepository {
            group.enter()
            let dependencies = request.dependencies.map { dependency in
                TaskDependencyLinkDefinition(
                    id: dependency.id,
                    taskID: taskID,
                    dependsOnTaskID: dependency.dependsOnTaskID,
                    kind: dependency.kind,
                    createdAt: dependency.createdAt
                )
            }
            taskDependencyRepository.replaceDependencies(taskID: taskID, dependencies: dependencies) { result in
                if case .failure(let error) = result, firstError == nil {
                    firstError = error
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

public final class GetTaskChildrenUseCase {
    private let repository: TaskDefinitionRepositoryProtocol

    public init(repository: TaskDefinitionRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        parentTaskID: UUID,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        repository.fetchChildren(parentTaskID: parentTaskID, completion: completion)
    }
}
