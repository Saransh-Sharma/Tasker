import Foundation

/// What the ritual needs from persistence.
///
/// Narrower than `CoreDataPlanningRepository` on purpose: everything below is a
/// read plus one batch write, so the store's tests can drive it with plain fakes
/// and no Core Data stack. `CoreDataPlanningRepository` already satisfies it.
public protocol DayCloseReading: Sendable {
    func fetchOpenPlanningTasks() async throws -> [PlanningTaskSummary]
    func fetchTimeBlocks(from: Date, to: Date) async throws -> [InternalTimeBlock]
    func sessions(since: Date?) async throws -> [FocusSessionV2]
    func hasAppliedReceipt(source: String) async throws -> Bool
    func fetchMutationReceipts(since: Date?) async throws -> [PlanningReceiptRecord]
    func undo(receiptID: UUID) async throws
}

/// The shipping repository already implements every one of these; this states
/// the conformance so the ritual can depend on the narrow protocol rather than
/// on the 900-line concrete type.
extension CoreDataPlanningRepository: DayCloseReading {}

/// Completed-task lookup, kept separate because completion lives on the task
/// definition rather than on `PlanningTaskSummary` — `fetchOpenPlanningTasks`
/// filters incomplete rows by definition, so the ribbon's ticks can never come
/// from there.
public protocol DayCloseCompletionReading: Sendable {
    func completions(on day: DateInterval) async throws -> [DayCloseCompletionMark]
}
