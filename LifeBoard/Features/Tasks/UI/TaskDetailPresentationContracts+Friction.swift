import Foundation

/// Capabilities used by the friction workflow embedded in task detail.
///
/// The workflow lives with the presentation contracts so the view never needs
/// to reach back into the process-wide composition root to undo a mutation.
struct TaskDetailFrictionDependencies {
    let taskRepository: any TaskDefinitionRepositoryProtocol
    let reflectionNoteRepository: any ReflectionNoteRepositoryProtocol
    let frictionFindingRepository: (any FrictionFindingRepositoryProtocol)?

    @MainActor
    func undo(
        _ receipt: FrictionInterventionReceipt,
        onTaskRestored: @escaping @MainActor @Sendable () -> Void,
        completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void
    ) {
        let finishTaskRestore: @MainActor @Sendable (Result<Void, Error>) -> Void = { result in
            switch result {
            case .failure:
                completion(result)
            case .success:
                deleteReceiptRecords(receipt, completion: completion)
            }
        }

        if let childID = receipt.createdChildTaskID {
            taskRepository.delete(id: childID) { result in
                Task { @MainActor in
                    if case .success = result { onTaskRestored() }
                    finishTaskRestore(result)
                }
            }
        } else {
            taskRepository.update(receipt.originalTask) { result in
                Task { @MainActor in
                    if case .success = result { onTaskRestored() }
                    finishTaskRestore(result.map { _ in () })
                }
            }
        }
    }

    @MainActor
    private func deleteReceiptRecords(
        _ receipt: FrictionInterventionReceipt,
        completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void
    ) {
        let deleteNote: @MainActor @Sendable () -> Void = {
            guard let noteID = receipt.reflectionNoteID else {
                completion(.success(()))
                return
            }
            reflectionNoteRepository.deleteNote(id: noteID) { result in
                Task { @MainActor in completion(result) }
            }
        }

        guard let findingID = receipt.findingID,
              let frictionFindingRepository else {
            deleteNote()
            return
        }
        frictionFindingRepository.deleteFinding(id: findingID) { result in
            Task { @MainActor in
                switch result {
                case .success: deleteNote()
                case .failure: completion(result)
                }
            }
        }
    }
}
