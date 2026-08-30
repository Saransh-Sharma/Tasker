import Foundation

enum MakeItFitApplyResult: Equatable, Sendable {
    case applied(changedCount: Int)
    case noChanges
    case stale(CommitmentRealismSnapshot)
    case failed(String)
}

extension PlanStore {
    /// Applies a reviewed Make It Fit Today diff as one planning receipt.
    /// `planningDay` changes intent; `dueDate` is deliberately untouched.
    @discardableResult
    func applyMakeItFit(
        choices: [UUID: MakeItFitDestination],
        expectedSnapshot: CommitmentRealismSnapshot
    ) async -> MakeItFitApplyResult {
        guard choices.contains(where: { $0.value != .keepToday }) else { return .noChanges }

        // Refetch canonical task, capacity, and calendar state immediately before
        // applying. A changed fact gets a new preview instead of a best-effort write.
        await load()
        guard let current = daySnapshot.map(CommitmentRealismEngine.snapshot) else {
            return .failed(errorMessage ?? "Today could not be rechecked. Nothing was changed.")
        }
        guard current == expectedSnapshot else { return .stale(current) }

        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let calendar = Calendar.current
        let today = expectedSnapshot.day

        let mutations: [PlanMutation] = choices.compactMap { taskID, destination in
            guard destination != .keepToday, let task = byID[taskID] else { return nil }
            var after = task.metadata
            switch destination {
            case .keepToday:
                return nil
            case .tomorrow:
                after.planningDay = shiftedDay(today, by: 1, calendar: calendar)
                after.unscheduledDisposition = .inbox
            case .later:
                after.planningDay = shiftedDay(today, by: 14, calendar: calendar)
                after.unscheduledDisposition = .inbox
            case .someday:
                after.planningDay = nil
                after.pinOrder = nil
                after.unscheduledDisposition = .someday
            case .inbox:
                after.planningDay = nil
                after.pinOrder = nil
                after.unscheduledDisposition = .inbox
            }
            after.updatedAt = Date()
            return .saveTaskMetadata(before: task.metadata, after: after)
        }
        guard mutations.isEmpty == false else { return .noChanges }

        do {
            _ = try await workspaceCommit(
                .batch(mutations),
                source: "eva.make_it_fit_today",
                summary: mutations.count == 1
                    ? "Made room in today"
                    : "Made room in today · \(mutations.count) changes"
            )
            await load()
            return .applied(changedCount: mutations.count)
        } catch {
            errorMessage = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func updateTaskEstimate(taskID: UUID, minutes: Int) async -> Bool {
        guard (5...1_440).contains(minutes), let taskDefinitionRepository = workspaceTaskRepository else {
            errorMessage = "Enter an estimate between 5 minutes and 24 hours."
            return false
        }
        do {
            guard var task = try await withCheckedThrowingContinuation({
                (continuation: CheckedContinuation<TaskDefinition?, any Error>) in
                taskDefinitionRepository.fetchTaskDefinition(id: taskID) {
                    continuation.resume(with: $0)
                }
            }) else {
                errorMessage = "The task changed before its estimate could be updated."
                return false
            }
            task.estimatedDuration = TimeInterval(minutes * 60)
            task.updatedAt = Date()
            _ = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<TaskDefinition, any Error>) in
                taskDefinitionRepository.update(task) {
                    continuation.resume(with: $0)
                }
            }
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func shiftedDay(_ day: PlanningDay, by offset: Int, calendar: Calendar) -> PlanningDay? {
        guard let start = day.startDate(calendar: calendar),
              let shifted = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
        return PlanningDay(date: shifted, timeZone: calendar.timeZone, calendar: calendar)
    }
}
