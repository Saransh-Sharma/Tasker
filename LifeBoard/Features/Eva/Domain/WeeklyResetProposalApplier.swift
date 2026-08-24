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

    init(repository: TaskDefinitionRepositoryProtocol) {
        self.repository = repository
    }

    func apply(_ lines: [WeeklyResetProposalLine]) async throws -> WeeklyResetApplyReceipt {
        var originals: [TaskDefinition] = []
        var changed: [UUID] = []
        var skipped: [UUID] = []

        for line in lines {
            guard let current = try await fetchTask(id: line.task.id),
                  current.isComplete == false,
                  current.updatedAt == line.task.updatedAt else {
                skipped.append(line.task.id)
                continue
            }

            originals.append(current)
            do {
                _ = try await update(
                    UpdateTaskDefinitionRequest(
                        id: current.id,
                        planningBucket: line.destination,
                        clearWeeklyOutcomeLink: true,
                        deferredFromWeekStart: line.disposition == .carry ? current.deferredFromWeekStart : nil,
                        clearDeferredFromWeekStart: line.disposition != .carry,
                        replanCount: current.replanCount + 1,
                        updatedAt: Date()
                    )
                )
                changed.append(current.id)
            } catch {
                skipped.append(current.id)
            }
        }

        return WeeklyResetApplyReceipt(
            id: UUID(),
            appliedAt: Date(),
            originals: originals.filter { changed.contains($0.id) },
            changedTaskIDs: changed,
            skippedTaskIDs: skipped
        )
    }

    func undo(_ receipt: WeeklyResetApplyReceipt) async throws {
        var firstError: Error?
        for original in receipt.originals {
            do { _ = try await update(original) }
            catch { firstError = firstError ?? error }
        }
        if let firstError { throw firstError }
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
}
