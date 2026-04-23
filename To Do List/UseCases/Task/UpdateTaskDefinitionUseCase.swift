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
        repository.fetchTaskDefinition(id: request.id) { existingResult in
            let previousTask = try? existingResult.get().flatMap { $0 }
            let normalizedRequest = self.normalizedRequest(request, existingTask: previousTask)

            self.repository.update(request: normalizedRequest) { result in
                switch result {
                case .success(let updatedTask):
                    self.persistLinks(taskID: updatedTask.id, request: normalizedRequest) { linkResult in
                        switch linkResult {
                        case .success:
                            TaskNotificationDispatcher.postOnMain(
                                name: NSNotification.Name("TaskUpdated"),
                                object: updatedTask
                            )
                            let payload = HomeTaskMutationPayload(
                                reason: HomeTaskMutationReasonResolver.reason(for: request),
                                source: "updateTaskDefinitionUseCase",
                                taskID: updatedTask.id,
                                previousIsComplete: previousTask?.isComplete,
                                newIsComplete: updatedTask.isComplete,
                                previousDueDate: previousTask?.dueDate,
                                newDueDate: updatedTask.dueDate,
                                previousCompletionDate: previousTask?.dateCompleted,
                                newCompletionDate: updatedTask.dateCompleted,
                                previousProjectID: previousTask?.projectID,
                                newProjectID: updatedTask.projectID,
                                previousPriorityRawValue: previousTask?.priority.rawValue,
                                newPriorityRawValue: updatedTask.priority.rawValue
                            )
                            TaskNotificationDispatcher.postOnMain(
                                name: .homeTaskMutation,
                                userInfo: payload.userInfo
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

    private func normalizedRequest(
        _ request: UpdateTaskDefinitionRequest,
        existingTask: TaskDefinition?
    ) -> UpdateTaskDefinitionRequest {
        let touchesScheduleSemantics =
            request.dueDate != nil
            || request.clearDueDate
        let hasExplicitScheduleMutation =
            request.scheduledStartAt != nil
            || request.clearScheduledStartAt
            || request.scheduledEndAt != nil
            || request.clearScheduledEndAt
            || request.isAllDay != nil

        guard touchesScheduleSemantics, hasExplicitScheduleMutation == false else {
            return request
        }

        let schedule = TaskScheduleNormalizer.normalize(
            deadlineDate: request.clearDueDate ? nil : request.dueDate,
            existingScheduledStartAt: existingTask?.scheduledStartAt,
            existingScheduledEndAt: existingTask?.scheduledEndAt,
            estimatedDuration: request.estimatedDuration ?? existingTask?.estimatedDuration,
            preserveExistingDuration: true,
            allDayIntent: request.isAllDay
        )

        var normalized = request
        normalized.dueDate = schedule.dueDate
        normalized.clearDueDate = schedule.dueDate == nil
        normalized.scheduledStartAt = schedule.scheduledStartAt
        normalized.clearScheduledStartAt = schedule.clearScheduledStartAt
        normalized.scheduledEndAt = schedule.scheduledEndAt
        normalized.clearScheduledEndAt = schedule.clearScheduledEndAt
        normalized.isAllDay = schedule.isAllDay
        return normalized
    }
}
