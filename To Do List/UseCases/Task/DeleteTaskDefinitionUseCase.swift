import Foundation

public final class DeleteTaskDefinitionUseCase {
    private let repository: TaskDefinitionRepositoryProtocol
    private let tombstoneRepository: TombstoneRepositoryProtocol?

    public init(
        repository: TaskDefinitionRepositoryProtocol,
        tombstoneRepository: TombstoneRepositoryProtocol? = nil
    ) {
        self.repository = repository
        self.tombstoneRepository = tombstoneRepository
    }

    public func execute(taskID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        repository.fetchTaskDefinition(id: taskID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let task):
                self.repository.delete(id: taskID) { deleteResult in
                    switch deleteResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        self.createTombstoneIfNeeded(taskID: taskID)
                        TaskNotificationDispatcher.postOnMain(
                            name: NSNotification.Name("TaskDeleted"),
                            object: task
                        )
                        TaskNotificationDispatcher.postOnMain(
                            name: .homeTaskMutation,
                            userInfo: [
                                "reason": "deleted",
                                "source": "deleteTaskDefinitionUseCase",
                                "taskID": taskID.uuidString
                            ]
                        )
                        completion(.success(()))
                    }
                }
            }
        }
    }

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
