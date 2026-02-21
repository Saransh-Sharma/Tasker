import Foundation

public final class ResolveOccurrenceUseCase {
    private let engine: SchedulingEngineProtocol

    /// Initializes a new instance.
    public init(engine: SchedulingEngineProtocol) {
        self.engine = engine
    }

    /// Executes execute.
    public func execute(
        id: UUID,
        resolution: OccurrenceResolutionType,
        actor: OccurrenceActor = .user,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        engine.resolveOccurrence(id: id, resolution: resolution, actor: actor, completion: completion)
    }
}
