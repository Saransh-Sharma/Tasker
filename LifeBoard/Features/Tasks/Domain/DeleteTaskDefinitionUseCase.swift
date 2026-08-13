import Foundation

private final class DeleteTaskDefinitionErrorRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var firstError: Error?

    func record(_ error: Error) {
        lock.lock()
        if firstError == nil {
            firstError = error
        }
        lock.unlock()
    }

    func error() -> Error? {
        lock.lock()
        let firstError = firstError
        lock.unlock()
        return firstError
    }
}

public final class DeleteTaskDefinitionUseCase: @unchecked Sendable {
    private static let deletedTaskIDsUserInfoKey = "deletedTaskIDs"

    private let repository: TaskDefinitionRepositoryProtocol
    private let tombstoneRepository: TombstoneRepositoryProtocol?

    /// Initializes a new instance.
    public init(
        repository: TaskDefinitionRepositoryProtocol,
        tombstoneRepository: TombstoneRepositoryProtocol? = nil
    ) {
        self.repository = repository
        self.tombstoneRepository = tombstoneRepository
    }

    /// Executes execute.
    public func execute(
        taskID: UUID,
        scope: TaskDeleteScope = .single,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        repository.fetchTaskDefinition(id: taskID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let task):
                guard let task else {
                    completion(.success(()))
                    return
                }

                guard
                    scope == .series,
                    let recurrenceSeriesID = task.recurrenceSeriesID
                else {
                    self.deleteSingle(taskID: taskID, deletedTask: task, completion: completion)
                    return
                }

                self.repository.fetchAll(query: nil) { allResult in
                    switch allResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let allTasks):
                        let seriesTasks = allTasks.filter { $0.recurrenceSeriesID == recurrenceSeriesID }
                        let candidateIDs = Set(seriesTasks.map(\.id))
                        if candidateIDs.isEmpty || candidateIDs == Set([taskID]) {
                            self.deleteSingle(taskID: taskID, deletedTask: task, completion: completion)
                            return
                        }
                        self.deleteMany(
                            taskIDs: Array(candidateIDs),
                            deletedTask: task,
                            scope: .series,
                            recurrenceSeriesID: recurrenceSeriesID,
                            completion: completion
                        )
                    }
                }
            }
        }
    }

    /// Executes deleteSingle.
    private func deleteSingle(
        taskID: UUID,
        deletedTask: TaskDefinition?,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        deleteMany(
            taskIDs: [taskID],
            deletedTask: deletedTask,
            scope: .single,
            recurrenceSeriesID: nil,
            completion: completion
        )
    }

    /// Executes deleteMany.
    private func deleteMany(
        taskIDs: [UUID],
        deletedTask: TaskDefinition?,
        scope: TaskDeleteScope,
        recurrenceSeriesID: UUID?,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        let uniqueIDs = Array(Set(taskIDs))
        guard uniqueIDs.isEmpty == false else {
            completion(.success(()))
            return
        }

        let group = DispatchGroup()
        let errors = DeleteTaskDefinitionErrorRecorder()

        for taskID in uniqueIDs {
            group.enter()
            repository.delete(id: taskID) { deleteResult in
                switch deleteResult {
                case .failure(let error):
                    errors.record(error)
                case .success:
                    self.createTombstoneIfNeeded(taskID: taskID)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError = errors.error() {
                completion(.failure(firstError))
                return
            }
            let deletedTaskIDs = uniqueIDs.map(\.uuidString)
            TaskNotificationDispatcher.postOnMain(
                name: NSNotification.Name("TaskDeleted"),
                object: deletedTask,
                userInfo: [
                    Self.deletedTaskIDsUserInfoKey: deletedTaskIDs
                ]
            )
            var userInfo = HomeTaskMutationPayload(
                reason: .deleted,
                source: "deleteTaskDefinitionUseCase",
                taskID: uniqueIDs.first,
                previousIsComplete: deletedTask?.isComplete,
                previousDueDate: deletedTask?.dueDate,
                previousCompletionDate: deletedTask?.dateCompleted,
                previousProjectID: deletedTask?.projectID,
                newProjectID: deletedTask?.projectID,
                previousPriorityRawValue: deletedTask?.priority.rawValue
            ).userInfo
            userInfo[Self.deletedTaskIDsUserInfoKey] = deletedTaskIDs
            userInfo["deleteScope"] = scope.rawValue
            userInfo["deletedCount"] = uniqueIDs.count
            if let recurrenceSeriesID {
                userInfo["recurrenceSeriesID"] = recurrenceSeriesID.uuidString
            }
            TaskNotificationDispatcher.postOnMain(
                name: .homeTaskMutation,
                userInfo: userInfo
            )
            completion(.success(()))
        }
    }

    /// Executes createTombstoneIfNeeded.
    private func createTombstoneIfNeeded(taskID: UUID) {
        guard let tombstoneRepository else { return }
        let now = Date()
        let purgeAfter = Calendar.current.date(byAdding: .day, value: 90, to: now) ?? now
        let tombstone = TombstoneDefinition(
            entityType: "TaskDefinition",
            entityID: taskID,
            deletedAt: now,
            deletedBy: "user",
            purgeAfter: purgeAfter
        )
        tombstoneRepository.create(tombstone) { result in
            if case .failure(let error) = result {
                logError("Failed to write task tombstone for \(taskID.uuidString): \(error.localizedDescription)")
            }
        }
    }
}
