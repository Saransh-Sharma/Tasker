import Foundation

public final class RescheduleTaskDefinitionUseCase {
    private let updateTaskDefinition: UpdateTaskDefinitionUseCase
    private let repository: TaskDefinitionRepositoryProtocol

    /// Initializes a new instance.
    public init(
        updateTaskDefinition: UpdateTaskDefinitionUseCase,
        repository: TaskDefinitionRepositoryProtocol
    ) {
        self.updateTaskDefinition = updateTaskDefinition
        self.repository = repository
    }

    /// Initializes a new instance.
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
            ),
            repository: repository
        )
    }

    /// Executes execute.
    public func execute(
        taskID: UUID,
        newDate: Date?,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        repository.fetchTaskDefinition(id: taskID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let task):
                let schedule = TaskScheduleNormalizer.normalize(
                    deadlineDate: newDate,
                    existingScheduledStartAt: task?.scheduledStartAt,
                    existingScheduledEndAt: task?.scheduledEndAt,
                    estimatedDuration: task?.estimatedDuration,
                    preserveExistingDuration: true
                )
                let request = UpdateTaskDefinitionRequest(
                    id: taskID,
                    dueDate: schedule.dueDate,
                    clearDueDate: schedule.dueDate == nil,
                    scheduledStartAt: schedule.scheduledStartAt,
                    clearScheduledStartAt: schedule.clearScheduledStartAt,
                    scheduledEndAt: schedule.scheduledEndAt,
                    clearScheduledEndAt: schedule.clearScheduledEndAt,
                    isAllDay: schedule.isAllDay,
                    updatedAt: Date()
                )
                self.updateTaskDefinition.execute(request: request, completion: completion)
            }
        }
    }
}
