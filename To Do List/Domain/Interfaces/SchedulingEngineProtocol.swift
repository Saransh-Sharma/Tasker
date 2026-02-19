import Foundation

public protocol SchedulingEngineProtocol {
    func generateOccurrences(
        windowStart: Date,
        windowEnd: Date,
        sourceFilter: ScheduleSourceType?,
        completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void
    )

    func resolveOccurrence(
        id: UUID,
        resolution: OccurrenceResolutionType,
        actor: OccurrenceActor,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    func rebuildFutureOccurrences(
        templateID: UUID,
        effectiveFrom: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    func applyScheduleException(
        templateID: UUID,
        occurrenceKey: String,
        action: ScheduleExceptionAction,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}
