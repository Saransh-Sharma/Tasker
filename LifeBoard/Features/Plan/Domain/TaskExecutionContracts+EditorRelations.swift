import Foundation

extension TaskEditorStore {
    func dependencyWouldCreateCycle(_ candidateID: UUID) -> Bool {
        dependencyGraphContainsCycle(
            proposed: Set(draft.task.dependencies.map(\.dependsOnTaskID) + [candidateID])
        )
    }

    func dependencyGraphContainsCycle(proposed: Set<UUID>) -> Bool {
        var dependenciesByTask = Dictionary(
            uniqueKeysWithValues: taskCandidates.map {
                ($0.id, Set($0.dependencies.map(\.dependsOnTaskID)))
            }
        )
        dependenciesByTask[taskID] = proposed
        var visited: Set<UUID> = []
        var stack = Array(proposed)
        while let next = stack.popLast() {
            if next == taskID { return true }
            guard visited.insert(next).inserted else { continue }
            stack.append(contentsOf: dependenciesByTask[next] ?? [])
        }
        return false
    }

    func relatedTaskChanges(
        before: TaskDefinition,
        after: TaskDefinition
    ) throws -> (before: [TaskDefinition], after: [TaskDefinition]) {
        let relatedIDs = Set(before.subtasks).union(after.subtasks)
        let candidateByID = Dictionary(
            uniqueKeysWithValues: taskCandidates.map { ($0.id, $0) }
        )
        let beforeRelated = relatedIDs
            .compactMap { candidateByID[$0] }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        guard beforeRelated.count == relatedIDs.count else {
            throw TaskEditorValidationError.duplicateSubtask
        }

        var afterRelated: [TaskDefinition] = []
        for var candidate in beforeRelated {
            if after.subtasks.contains(candidate.id) {
                if let parent = candidate.parentTaskID, parent != taskID {
                    throw TaskEditorValidationError.subtaskAlreadyHasParent
                }
                if subtaskWouldCreateCycle(candidate.id, candidates: candidateByID) {
                    throw TaskEditorValidationError.circularSubtask
                }
                candidate.parentTaskID = taskID
            } else if before.subtasks.contains(candidate.id),
                      candidate.parentTaskID == taskID {
                candidate.parentTaskID = nil
            }
            candidate.updatedAt = Date()
            afterRelated.append(candidate)
        }
        return (beforeRelated, afterRelated)
    }

    private func subtaskWouldCreateCycle(
        _ candidateID: UUID,
        candidates: [UUID: TaskDefinition]
    ) -> Bool {
        var cursor: UUID? = taskID
        var visited: Set<UUID> = []
        while let current = cursor, visited.insert(current).inserted {
            if current == candidateID { return true }
            cursor = current == taskID
                ? persistedTask?.parentTaskID
                : candidates[current]?.parentTaskID
        }
        return false
    }
}
