import Foundation

public final class RescheduleTaskDefinitionUseCase {
    private let updateTaskDefinition: UpdateTaskDefinitionUseCase

    public init(updateTaskDefinition: UpdateTaskDefinitionUseCase) {
        self.updateTaskDefinition = updateTaskDefinition
    }

    public convenience init(
        repository: TaskDefinitionRepositoryProtocol,
        taskTagLinkRepository: TaskTagLinkRepositoryProtocol? = nil,
        taskDependencyRepository: TaskDependencyRepositoryProtocol? = nil
    ) {
        self.init(
            updateTaskDefinition: UpdateTaskDefinitionUseCase(
                repository: repository,
                taskTagLinkRepository: taskTagLinkRepository,
                taskDependencyRepository: taskDependencyRepository
            )
        )
    }

    public func execute(
        taskID: UUID,
        newDate: Date?,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        let request = UpdateTaskDefinitionRequest(
            id: taskID,
            dueDate: newDate,
            updatedAt: Date()
        )
        updateTaskDefinition.execute(request: request, completion: completion)
    }
}
