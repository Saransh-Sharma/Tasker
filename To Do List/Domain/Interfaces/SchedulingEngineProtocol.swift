import Foundation

public protocol SchedulingEngineProtocol {
    /// Executes generateOccurrences.
    func generateOccurrences(
        windowStart: Date,
        windowEnd: Date,
        sourceFilter: ScheduleSourceType?,
        completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void
    )

    /// Executes resolveOccurrence.
    func resolveOccurrence(
        id: UUID,
        resolution: OccurrenceResolutionType,
        actor: OccurrenceActor,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    /// Executes rebuildFutureOccurrences.
    func rebuildFutureOccurrences(
        templateID: UUID,
        effectiveFrom: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    /// Executes applyScheduleException.
    func applyScheduleException(
        templateID: UUID,
        occurrenceKey: String,
        action: ScheduleExceptionAction,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}
