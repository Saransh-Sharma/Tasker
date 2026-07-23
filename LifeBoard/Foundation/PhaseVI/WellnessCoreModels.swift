import Foundation

public enum WellnessCaptureSource: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case healthKit
    case watch
    case imported
}

public enum WellnessDisplayUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case kilograms
    case pounds
    case percent
    case centimeters
    case inches
    case beatsPerMinute
    case meters
    case kilometers
    case miles
    case kilocalories

    public var symbol: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lb"
        case .percent: "%"
        case .centimeters: "cm"
        case .inches: "in"
        case .beatsPerMinute: "bpm"
        case .meters: "m"
        case .kilometers: "km"
        case .miles: "mi"
        case .kilocalories: "kcal"
        }
    }
}

public enum BodyMetricKind: String, Codable, CaseIterable, Hashable, Sendable {
    case bodyMass
    case bodyFatPercentage
    case waistCircumference
    case restingHeartRate

    public var title: String {
        switch self {
        case .bodyMass: "Weight"
        case .bodyFatPercentage: "Body fat"
        case .waistCircumference: "Waist"
        case .restingHeartRate: "Resting heart rate"
        }
    }

    public var canonicalUnit: WellnessDisplayUnit {
        switch self {
        case .bodyMass: .kilograms
        case .bodyFatPercentage: .percent
        case .waistCircumference: .centimeters
        case .restingHeartRate: .beatsPerMinute
        }
    }
}

public protocol MeasurementSampleValue: Codable, Hashable, Identifiable, Sendable {
    var id: UUID { get }
    var normalizedValue: Double { get }
    var displayUnit: WellnessDisplayUnit { get }
    var observedAt: Date { get }
    var capturedTimeZoneIdentifier: String { get }
    var source: WellnessCaptureSource { get }
    var sourceIdentifier: String? { get }
    var note: String? { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

public protocol MeasurementRepository: Sendable {
    associatedtype Sample: MeasurementSampleValue
    func samples() async throws -> [Sample]
    func save(_ sample: Sample) async throws
    func delete(id: UUID) async throws
}

public struct BodyMetricSample: MeasurementSampleValue {
    public let id: UUID
    public var kind: BodyMetricKind
    /// Kilograms, percentage points, centimeters, or beats/minute according to `kind`.
    public var normalizedValue: Double
    public var displayUnit: WellnessDisplayUnit
    public var observedAt: Date
    public var capturedTimeZoneIdentifier: String
    public var source: WellnessCaptureSource
    public var sourceIdentifier: String?
    public var note: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: BodyMetricKind,
        value: Double,
        unit: WellnessDisplayUnit,
        observedAt: Date = Date(),
        capturedTimeZone: TimeZone = .autoupdatingCurrent,
        source: WellnessCaptureSource = .manual,
        sourceIdentifier: String? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard value.isFinite, value > 0 else { throw WellnessRepositoryError.invalidValue }
        self.id = id
        self.kind = kind
        normalizedValue = try Self.normalize(value, from: unit, kind: kind)
        displayUnit = unit
        self.observedAt = observedAt
        capturedTimeZoneIdentifier = capturedTimeZone.identifier
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.note = note?.trimmedNilIfEmpty
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }

    public var capturedTimeZone: TimeZone {
        TimeZone(identifier: capturedTimeZoneIdentifier) ?? .autoupdatingCurrent
    }

    public func value(in unit: WellnessDisplayUnit) throws -> Double {
        switch (kind, unit) {
        case (.bodyMass, .kilograms): normalizedValue
        case (.bodyMass, .pounds): normalizedValue * 2.204_622_621_8
        case (.bodyFatPercentage, .percent): normalizedValue
        case (.waistCircumference, .centimeters): normalizedValue
        case (.waistCircumference, .inches): normalizedValue / 2.54
        case (.restingHeartRate, .beatsPerMinute): normalizedValue
        default: throw WellnessRepositoryError.incompatibleUnit
        }
    }

    public mutating func correct(
        value: Double,
        unit: WellnessDisplayUnit,
        at date: Date = Date()
    ) throws {
        guard value.isFinite, value > 0 else { throw WellnessRepositoryError.invalidValue }
        normalizedValue = try Self.normalize(value, from: unit, kind: kind)
        displayUnit = unit
        updatedAt = max(date, createdAt)
    }

    private static func normalize(
        _ value: Double,
        from unit: WellnessDisplayUnit,
        kind: BodyMetricKind
    ) throws -> Double {
        switch (kind, unit) {
        case (.bodyMass, .kilograms): value
        case (.bodyMass, .pounds): value / 2.204_622_621_8
        case (.bodyFatPercentage, .percent): value
        case (.waistCircumference, .centimeters): value
        case (.waistCircumference, .inches): value * 2.54
        case (.restingHeartRate, .beatsPerMinute): value
        default: throw WellnessRepositoryError.incompatibleUnit
        }
    }
}

public struct WorkoutRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var activityKind: String
    public var startedAt: Date
    public var endedAt: Date
    public var energyKilocalories: Double?
    public var distanceMeters: Double?
    public var source: WellnessCaptureSource
    public var sourceIdentifier: String?
    public var note: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        activityKind: String,
        startedAt: Date,
        endedAt: Date,
        energyKilocalories: Double? = nil,
        distanceMeters: Double? = nil,
        source: WellnessCaptureSource = .manual,
        sourceIdentifier: String? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard let activityKind = activityKind.trimmedNilIfEmpty, endedAt >= startedAt else {
            throw WellnessRepositoryError.invalidInterval
        }
        guard Self.isValidOptionalMeasure(energyKilocalories), Self.isValidOptionalMeasure(distanceMeters) else {
            throw WellnessRepositoryError.invalidValue
        }
        self.id = id
        self.activityKind = activityKind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.energyKilocalories = energyKilocalories
        self.distanceMeters = distanceMeters
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.note = note?.trimmedNilIfEmpty
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }

    public var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    private static func isValidOptionalMeasure(_ value: Double?) -> Bool {
        value.map { $0.isFinite && $0 >= 0 } ?? true
    }
}

public struct SleepNote: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var quality: Int?
    public var note: String?
    public var source: WellnessCaptureSource
    public var sourceIdentifier: String?
    public var capturedTimeZoneIdentifier: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        quality: Int? = nil,
        note: String? = nil,
        source: WellnessCaptureSource = .manual,
        sourceIdentifier: String? = nil,
        capturedTimeZone: TimeZone = .autoupdatingCurrent,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard endedAt >= startedAt else { throw WellnessRepositoryError.invalidInterval }
        guard quality.map({ (1 ... 5).contains($0) }) ?? true else {
            throw WellnessRepositoryError.invalidValue
        }
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.quality = quality
        self.note = note?.trimmedNilIfEmpty
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        capturedTimeZoneIdentifier = capturedTimeZone.identifier
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }

    public var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}

public struct MovementContextRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var steps: Int?
    public var distanceMeters: Double?
    public var activeEnergyKilocalories: Double?
    public var source: WellnessCaptureSource
    public var sourceIdentifier: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        steps: Int? = nil,
        distanceMeters: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        source: WellnessCaptureSource,
        sourceIdentifier: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard endedAt >= startedAt else { throw WellnessRepositoryError.invalidInterval }
        guard steps.map({ $0 >= 0 }) ?? true,
              distanceMeters.map({ $0.isFinite && $0 >= 0 }) ?? true,
              activeEnergyKilocalories.map({ $0.isFinite && $0 >= 0 }) ?? true else {
            throw WellnessRepositoryError.invalidValue
        }
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }
}

public enum WellnessRecordKind: String, Codable, CaseIterable, Hashable, Sendable {
    case bodyMetric
    case workout
    case sleep
    case movement
}

public enum WellnessRepositoryError: LocalizedError, Equatable, Sendable {
    case invalidValue
    case invalidInterval
    case incompatibleUnit
    case recordNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidValue: "Check the value and try again."
        case .invalidInterval: "The end time must be after the start time."
        case .incompatibleUnit: "That unit is not available for this measurement."
        case .recordNotFound: "That wellness entry is no longer available."
        }
    }
}

public enum WellnessValueReview: Equatable, Sendable {
    case accepted
    case requiresConfirmation(message: String)
}

public struct WellnessOutlierPolicy: Sendable {
    public init() {}

    public func review(kind: BodyMetricKind, normalizedValue: Double) -> WellnessValueReview {
        let expected: ClosedRange<Double> = switch kind {
        case .bodyMass: 20 ... 350
        case .bodyFatPercentage: 1 ... 75
        case .waistCircumference: 30 ... 250
        case .restingHeartRate: 25 ... 240
        }
        guard expected.contains(normalizedValue) else {
            return .requiresConfirmation(message: "This value is outside the usual entry range. Confirm the number and unit before saving.")
        }
        return .accepted
    }
}

public protocol WellnessRepository: Sendable {
    func bodyMetricSamples(kind: BodyMetricKind?) async throws -> [BodyMetricSample]
    func workoutRecords() async throws -> [WorkoutRecord]
    func sleepNotes() async throws -> [SleepNote]
    func movementRecords() async throws -> [MovementContextRecord]
    func save(_ value: BodyMetricSample) async throws
    func save(_ value: WorkoutRecord) async throws
    func save(_ value: SleepNote) async throws
    func save(_ value: MovementContextRecord) async throws
    func delete(kind: WellnessRecordKind, id: UUID) async throws
}

/// Deterministic repository used by fixtures and by the domain layer before a
/// persistent adapter is injected. Upsert preserves stable record identities.
public actor InMemoryWellnessRepository: WellnessRepository {
    private var bodyMetrics: [UUID: BodyMetricSample]
    private var workouts: [UUID: WorkoutRecord]
    private var sleeps: [UUID: SleepNote]
    private var movements: [UUID: MovementContextRecord]

    public init(
        bodyMetrics: [BodyMetricSample] = [],
        workouts: [WorkoutRecord] = [],
        sleeps: [SleepNote] = [],
        movements: [MovementContextRecord] = []
    ) {
        self.bodyMetrics = Dictionary(uniqueKeysWithValues: bodyMetrics.map { ($0.id, $0) })
        self.workouts = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0) })
        self.sleeps = Dictionary(uniqueKeysWithValues: sleeps.map { ($0.id, $0) })
        self.movements = Dictionary(uniqueKeysWithValues: movements.map { ($0.id, $0) })
    }

    public func bodyMetricSamples(kind: BodyMetricKind? = nil) -> [BodyMetricSample] {
        bodyMetrics.values
            .filter { kind == nil || $0.kind == kind }
            .sorted { ($0.observedAt, $0.id.uuidString) > ($1.observedAt, $1.id.uuidString) }
    }

    public func workoutRecords() -> [WorkoutRecord] {
        workouts.values.sorted { ($0.startedAt, $0.id.uuidString) > ($1.startedAt, $1.id.uuidString) }
    }

    public func sleepNotes() -> [SleepNote] {
        sleeps.values.sorted { ($0.startedAt, $0.id.uuidString) > ($1.startedAt, $1.id.uuidString) }
    }

    public func movementRecords() -> [MovementContextRecord] {
        movements.values.sorted { ($0.startedAt, $0.id.uuidString) > ($1.startedAt, $1.id.uuidString) }
    }

    public func save(_ value: BodyMetricSample) { bodyMetrics[value.id] = value }
    public func save(_ value: WorkoutRecord) { workouts[value.id] = value }
    public func save(_ value: SleepNote) { sleeps[value.id] = value }
    public func save(_ value: MovementContextRecord) { movements[value.id] = value }

    public func delete(kind: WellnessRecordKind, id: UUID) throws {
        let removed: Bool = switch kind {
        case .bodyMetric: bodyMetrics.removeValue(forKey: id) != nil
        case .workout: workouts.removeValue(forKey: id) != nil
        case .sleep: sleeps.removeValue(forKey: id) != nil
        case .movement: movements.removeValue(forKey: id) != nil
        }
        guard removed else { throw WellnessRepositoryError.recordNotFound }
    }
}

public struct WellnessExportEnvelope: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion = currentSchemaVersion
    public var exportedAt: Date
    public var bodyMetrics: [BodyMetricSample]
    public var workouts: [WorkoutRecord]
    public var sleepNotes: [SleepNote]
    public var movement: [MovementContextRecord]
}

public enum WellnessExportEncoder {
    public static func encode(
        repository: any WellnessRepository,
        at date: Date = Date()
    ) async throws -> Data {
        async let bodyMetrics = repository.bodyMetricSamples(kind: nil)
        async let workouts = repository.workoutRecords()
        async let sleepNotes = repository.sleepNotes()
        async let movement = repository.movementRecords()
        let envelope = try await WellnessExportEnvelope(
            exportedAt: date,
            bodyMetrics: bodyMetrics,
            workouts: workouts,
            sleepNotes: sleepNotes,
            movement: movement
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }
}

public struct WellnessNormalizedEventProjector: Sendable {
    public init() {}

    public func bodyMetric(_ sample: BodyMetricSample, now: Date = Date()) -> NormalizedLifeEvent {
        makeEvent(
            sourceID: sample.id,
            kind: sample.kind.rawValue,
            occurredAt: sample.observedAt,
            numericValue: sample.normalizedValue,
            timeZone: sample.capturedTimeZone,
            provenance: sample.source.rawValue,
            display: sample.kind.title,
            now: now
        )
    }

    public func workout(_ value: WorkoutRecord, timeZone: TimeZone, now: Date = Date()) -> NormalizedLifeEvent {
        makeEvent(
            sourceID: value.id,
            kind: value.activityKind,
            occurredAt: value.startedAt,
            numericValue: value.duration,
            timeZone: timeZone,
            provenance: value.source.rawValue,
            display: value.activityKind,
            now: now
        )
    }

    public func sleep(_ value: SleepNote, now: Date = Date()) -> NormalizedLifeEvent {
        makeEvent(
            sourceID: value.id,
            kind: "sleepNote",
            occurredAt: value.endedAt,
            numericValue: value.duration,
            timeZone: TimeZone(identifier: value.capturedTimeZoneIdentifier) ?? .autoupdatingCurrent,
            provenance: value.source.rawValue,
            display: "Sleep note",
            now: now
        )
    }

    public func movement(
        _ value: MovementContextRecord,
        timeZone: TimeZone,
        now: Date = Date()
    ) -> NormalizedLifeEvent {
        makeEvent(
            sourceID: value.id,
            kind: "movement",
            occurredAt: value.endedAt,
            numericValue: value.steps.map(Double.init),
            timeZone: timeZone,
            provenance: value.source.rawValue,
            display: "Movement",
            now: now
        )
    }

    private func makeEvent(
        sourceID: UUID,
        kind: String,
        occurredAt: Date,
        numericValue: Double?,
        timeZone: TimeZone,
        provenance: String,
        display: String,
        now: Date
    ) -> NormalizedLifeEvent {
        NormalizedLifeEventProjector(timeZone: timeZone).event(
            sourceID: sourceID,
            domain: "wellness",
            kind: kind,
            occurredAt: occurredAt,
            numericValue: numericValue,
            sensitivity: .privateSensitive,
            provenance: provenance,
            evidenceDisplay: display,
            evidenceRouteID: sourceID,
            now: now
        )
    }
}

public enum WellnessHomeCardFocus: Hashable, Sendable {
    case bodyMetric(BodyMetricKind)
    case workouts
    case sleep
    case movement
}

public struct WellnessHomeCardProvider: HomeCardProvider {
    public let definition: HomeCardDefinition
    public let primaryDestination = LifeBoardDestination.track
    public let privacyClassification = DataSensitivity.privateSensitive

    private let repository: any WellnessRepository
    private let focus: WellnessHomeCardFocus

    public init(
        definition: HomeCardDefinition,
        focus: WellnessHomeCardFocus,
        repository: any WellnessRepository
    ) {
        self.definition = definition
        self.focus = focus
        self.repository = repository
    }

    public func snapshot(
        configuration: HomeCardConfiguration,
        size: HomeCardSize,
        at date: Date
    ) async -> HomeCardSnapshot {
        do {
            switch focus {
            case .bodyMetric(let kind):
                guard let sample = try await repository.bodyMetricSamples(kind: kind).first else {
                    return empty(date, "Log a value when it is useful to you.")
                }
                let value = try sample.value(in: sample.displayUnit)
                return ready(
                    value: Self.formatted(value, unit: sample.displayUnit),
                    detail: densityDetail(
                        size: size,
                        compact: "Updated \(sample.observedAt.formatted(date: .abbreviated, time: .omitted))",
                        story: "A private measurement you chose to keep on Home. Open Track to review or correct it."
                    ),
                    date: sample.updatedAt
                )
            case .workouts:
                guard let workout = try await repository.workoutRecords().first else {
                    return empty(date, "Add a workout manually or connect Health.")
                }
                return ready(
                    value: workout.activityKind,
                    detail: densityDetail(
                        size: size,
                        compact: Self.duration(workout.duration),
                        story: "\(Self.duration(workout.duration)) on \(workout.startedAt.formatted(date: .abbreviated, time: .omitted))."
                    ),
                    date: workout.updatedAt
                )
            case .sleep:
                guard let sleep = try await repository.sleepNotes().first else {
                    return empty(date, "Add a sleep note when reflection would help.")
                }
                return ready(
                    value: Self.duration(sleep.duration),
                    detail: densityDetail(
                        size: size,
                        compact: sleep.quality.map { "Quality \($0)/5" } ?? "No rating needed",
                        story: "Your note stays descriptive and is never treated as a diagnosis."
                    ),
                    date: sleep.updatedAt
                )
            case .movement:
                guard let movement = try await repository.movementRecords().first else {
                    return empty(date, "Movement appears here when available.")
                }
                return ready(
                    value: movement.steps.map { "\($0) steps" } ?? "Movement",
                    detail: densityDetail(
                        size: size,
                        compact: movement.distanceMeters.map { String(format: "%.1f km", $0 / 1_000) } ?? "Latest context",
                        story: "A factual summary from \(movement.source.rawValue); open Track for accessible history."
                    ),
                    date: movement.updatedAt
                )
            }
        } catch {
            return HomeCardSnapshot(
                availability: .degraded,
                title: definition.title,
                detail: "This measurement is unavailable right now. Your Home layout is unchanged.",
                updatedAt: date
            )
        }
    }

    private func ready(value: String, detail: String?, date: Date) -> HomeCardSnapshot {
        HomeCardSnapshot(
            availability: .ready,
            title: definition.title,
            value: value,
            detail: detail,
            actions: inlineActions,
            updatedAt: date
        )
    }

    private func empty(_ date: Date, _ detail: String) -> HomeCardSnapshot {
        HomeCardSnapshot(
            availability: .empty,
            title: definition.title,
            detail: detail,
            actions: inlineActions,
            updatedAt: date
        )
    }

    private func densityDetail(size: HomeCardSize, compact: String, story: String) -> String? {
        switch size {
        case .compact: nil
        case .standard, .wide: compact
        case .tall, .expanded: story
        }
    }

    private static func formatted(_ value: Double, unit: WellnessDisplayUnit) -> String {
        let decimals = value.rounded() == value ? 0 : 1
        return String(format: "%.*f %@", decimals, value, unit.symbol)
    }

    private static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(remainder)m"
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
