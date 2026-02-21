import Foundation

public final class GenerateOccurrencesUseCase {
    private let engine: SchedulingEngineProtocol

    /// Initializes a new instance.
    public init(engine: SchedulingEngineProtocol) {
        self.engine = engine
    }

    /// Executes execute.
    public func execute(daysAhead: Int = 14, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: daysAhead, to: start) ?? start
        engine.generateOccurrences(windowStart: start, windowEnd: end, sourceFilter: nil, completion: completion)
    }
}
