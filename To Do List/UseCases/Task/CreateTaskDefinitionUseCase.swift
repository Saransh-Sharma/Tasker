import Foundation

public final class CreateTaskDefinitionUseCase {
    private let repository: TaskDefinitionRepositoryProtocol

    public init(repository: TaskDefinitionRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        title: String,
        projectID: UUID,
        dueDate: Date?,
        details: String?,
        completion: @escaping (Result<Task, Error>) -> Void
    ) {
        let task = Task(
            projectID: projectID,
            name: title,
            details: details,
            dueDate: dueDate,
            project: ProjectConstants.inboxProjectName,
            isComplete: false,
            dateAdded: Date()
        )
        repository.create(task) { result in
            switch result {
            case .success(let createdTask):
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
    }
}
