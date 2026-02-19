import Foundation

public final class ResolveOccurrenceUseCase {
    private let engine: SchedulingEngineProtocol

    public init(engine: SchedulingEngineProtocol) {
        self.engine = engine
    }

    public func execute(
        id: UUID,
        resolution: OccurrenceResolutionType,
        actor: OccurrenceActor = .user,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        engine.resolveOccurrence(id: id, resolution: resolution, actor: actor, completion: completion)
    }
}
