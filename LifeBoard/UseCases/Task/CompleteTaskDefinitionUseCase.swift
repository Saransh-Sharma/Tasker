import Foundation

public final class CompleteTaskDefinitionUseCase {
    private let repository: TaskDefinitionRepositoryProtocol
    private let gamification: RecordXPUseCase?
    private let gamificationEngine: GamificationEngine?

    /// Initializes a new instance.
    public init(
        repository: TaskDefinitionRepositoryProtocol,
        gamification: RecordXPUseCase? = nil,
        gamificationEngine: GamificationEngine? = nil
    ) {
        self.repository = repository
        self.gamification = gamification
        self.gamificationEngine = gamificationEngine
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
                            if V2FeatureFlags.gamificationV2Enabled, let engine = self.gamificationEngine {
                                let context = XPEventContext(
                                    category: .complete,
                                    source: .manual,
                                    taskID: taskID,
                                    dueDate: task.dueDate,
                                    completedAt: Date(),
                                    priority: max(0, Int(task.priority.rawValue) - 1),
                                    estimatedDuration: task.estimatedDuration
                                )
                                engine.recordEvent(context: context) { result in
                                    if case .failure(let error) = result {
                                        logError(
                                            event: "gamification_task_completion_record_failed",
                                            message: "Failed to record gamification XP event for task completion",
                                            fields: [
                                                "task_id": taskID.uuidString,
                                                "error": error.localizedDescription
                                            ]
                                        )
                                    }
                                }
                            } else {
                                self.gamification?.recordTaskCompletion(taskID: taskID) { _ in }
                            }
                        }
                        TaskNotificationDispatcher.postOnMain(
                            name: NSNotification.Name("TaskCompletionChanged"),
                            object: updatedTask
                        )
                        let payload = HomeTaskMutationPayload(
                            reason: updatedTask.isComplete ? .completed : .reopened,
                            source: "completeTaskDefinitionUseCase",
                            taskID: updatedTask.id,
                            previousIsComplete: task.isComplete,
                            newIsComplete: updatedTask.isComplete,
                            previousDueDate: task.dueDate,
                            newDueDate: updatedTask.dueDate,
                            previousCompletionDate: task.dateCompleted,
                            newCompletionDate: updatedTask.dateCompleted,
                            previousProjectID: task.projectID,
                            newProjectID: updatedTask.projectID,
                            previousPriorityRawValue: task.priority.rawValue,
                            newPriorityRawValue: updatedTask.priority.rawValue
                        )
                        TaskNotificationDispatcher.postOnMain(
                            name: .homeTaskMutation,
                            userInfo: payload.userInfo
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
