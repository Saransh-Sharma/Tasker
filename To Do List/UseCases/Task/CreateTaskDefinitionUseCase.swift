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
        repository.create(task, completion: completion)
    }
}
