import Foundation

struct WeeklyResetProposalLine: Identifiable, Equatable, Sendable {
    let task: TaskDefinition
    let disposition: WeeklyReviewTaskDisposition

    var id: UUID { task.id }

    var destination: TaskPlanningBucket {
        switch disposition {
        case .carry: .nextWeek
        case .later: .later
        case .drop: .someday
        }
    }
}

struct WeeklyResetApplyReceipt: Equatable, Sendable {
    let id: UUID
    let appliedAt: Date
    let originals: [TaskDefinition]
    let changedTaskIDs: [UUID]
    let skippedTaskIDs: [UUID]
    let actionRunID: UUID?

    var summary: String {
        if skippedTaskIDs.isEmpty {
            return "Updated \(changedTaskIDs.count) task\(changedTaskIDs.count == 1 ? "" : "s")."
        }
        return "Updated \(changedTaskIDs.count); skipped \(skippedTaskIDs.count) because the plan changed."
    }
}

/// Applies the reset's planning commit independently from the persisted review.
/// Each task is refetched immediately before writing so a stale ritual cannot
/// silently overwrite work changed elsewhere in the app.
@MainActor
final class WeeklyResetProposalApplier {
    private let repository: TaskDefinitionRepositoryProtocol
    private let actionPipeline: AssistantActionPipelineUseCase?

    init(
        repository: TaskDefinitionRepositoryProtocol,
        actionPipeline: AssistantActionPipelineUseCase? = nil
    ) {
        self.repository = repository
        self.actionPipeline = actionPipeline
    }

    func apply(
        _ lines: [WeeklyResetProposalLine],
        onRunCreated: ((UUID) -> Void)? = nil
    ) async throws -> WeeklyResetApplyReceipt {
        var originals: [TaskDefinition] = []
        var changed: [UUID] = []
        var skipped: [UUID] = []
        var commands: [AssistantCommand] = []

        for line in lines {
            guard let current = try await fetchTask(id: line.task.id),
                  current.isComplete == false,
                  current.updatedAt == line.task.updatedAt else {
                skipped.append(line.task.id)
                continue
            }

            var updated = current
            updated.planningBucket = line.destination
            updated.weeklyOutcomeID = nil
            if line.disposition != .carry { updated.deferredFromWeekStart = nil }
            updated.replanCount += 1
            updated.updatedAt = Date()
            originals.append(current)
            changed.append(current.id)
            commands.append(.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: updated)))
        }

        if let actionPipeline, commands.isEmpty == false {
            do {
                let envelope = AssistantCommandEnvelope(
                    schemaVersion: 3,
                    commands: commands,
                    rationaleText: "Weekly Reset planning proposal confirmed by the user"
                )
                let proposed = try await propose(envelope, using: actionPipeline)
                // Persist the run identity before confirmation/application so a
                // process interruption can recover the authoritative run state.
                onRunCreated?(proposed.id)
                _ = try await confirm(proposed.id, using: actionPipeline)
                let applied = try await apply(proposed.id, using: actionPipeline)
                return WeeklyResetApplyReceipt(
                    id: applied.id,
                    appliedAt: applied.appliedAt ?? Date(),
                    originals: [],
                    changedTaskIDs: changed,
                    skippedTaskIDs: skipped,
                    actionRunID: applied.id
                )
            } catch {
                throw error
            }
        }

        // Compatibility fallback for isolated previews/tests that do not inject
        // the durable action pipeline.
        var fallbackChanged: [UUID] = []
        var fallbackSkipped = skipped
        for (original, command) in zip(originals, commands) {
            guard case .restoreTaskSnapshot(let snapshot) = command else { continue }
            do {
                _ = try await update(snapshot.toTaskDefinition())
                fallbackChanged.append(original.id)
            } catch {
                fallbackSkipped.append(original.id)
            }
        }

        return WeeklyResetApplyReceipt(
            id: UUID(),
            appliedAt: Date(),
            originals: originals.filter { fallbackChanged.contains($0.id) },
            changedTaskIDs: fallbackChanged,
            skippedTaskIDs: fallbackSkipped,
            actionRunID: nil
        )
    }

    func undo(_ receipt: WeeklyResetApplyReceipt) async throws {
        if let runID = receipt.actionRunID, let actionPipeline {
            _ = try await undo(runID, using: actionPipeline)
            return
        }
        var firstError: Error?
        for original in receipt.originals {
            do { _ = try await update(original) }
            catch { firstError = firstError ?? error }
        }
        if let firstError { throw firstError }
    }

    func restoreReceipt(id: UUID) async throws -> WeeklyResetApplyReceipt? {
        guard let actionPipeline else { return nil }
        guard let run = try await fetchRun(id, using: actionPipeline),
              run.status == .applied,
              let data = run.proposalData,
              let envelope = try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: data) else {
            return nil
        }
        let taskIDs = envelope.commands.compactMap { command -> UUID? in
            guard case .restoreTaskSnapshot(let snapshot) = command else { return nil }
            return snapshot.id
        }
        return WeeklyResetApplyReceipt(
            id: run.id,
            appliedAt: run.appliedAt ?? run.createdAt,
            originals: [],
            changedTaskIDs: taskIDs,
            skippedTaskIDs: [],
            actionRunID: run.id
        )
    }

    private func fetchTask(id: UUID) async throws -> TaskDefinition? {
        try await withCheckedThrowingContinuation { continuation in
            repository.fetchTaskDefinition(id: id) { continuation.resume(with: $0) }
        }
    }

    private func update(_ request: UpdateTaskDefinitionRequest) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            repository.update(request: request) { continuation.resume(with: $0) }
        }
    }

    private func update(_ task: TaskDefinition) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            repository.update(task) { continuation.resume(with: $0) }
        }
    }

    private func propose(
        _ envelope: AssistantCommandEnvelope,
        using pipeline: AssistantActionPipelineUseCase
    ) async throws -> AssistantActionRunDefinition {
        try await withCheckedThrowingContinuation { continuation in
            pipeline.propose(threadID: "eva.weekly_reset", envelope: envelope) {
                continuation.resume(with: $0)
            }
        }
    }

    private func confirm(
        _ id: UUID,
        using pipeline: AssistantActionPipelineUseCase
    ) async throws -> AssistantActionRunDefinition {
        try await withCheckedThrowingContinuation { continuation in
            pipeline.confirm(runID: id) { continuation.resume(with: $0) }
        }
    }

    private func apply(
        _ id: UUID,
        using pipeline: AssistantActionPipelineUseCase
    ) async throws -> AssistantActionRunDefinition {
        try await withCheckedThrowingContinuation { continuation in
            pipeline.applyConfirmedRun(id: id) { continuation.resume(with: $0) }
        }
    }

    private func undo(
        _ id: UUID,
        using pipeline: AssistantActionPipelineUseCase
    ) async throws -> AssistantActionRunDefinition {
        try await withCheckedThrowingContinuation { continuation in
            pipeline.undoAppliedRun(id: id) { continuation.resume(with: $0) }
        }
    }

    private func fetchRun(
        _ id: UUID,
        using pipeline: AssistantActionPipelineUseCase
    ) async throws -> AssistantActionRunDefinition? {
        try await withCheckedThrowingContinuation { continuation in
            pipeline.fetchRun(id: id) { continuation.resume(with: $0) }
        }
    }
}
