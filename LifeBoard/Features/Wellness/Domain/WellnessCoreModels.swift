import Foundation

public enum WellnessCaptureSource: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case healthKit
    case watch
    case imported

    /// Only records authored in LifeBoard can be corrected from Wellness.
    /// Imported identities belong to their source and remain provenance-safe.
    public var permitsManualCorrection: Bool {
        switch self {
        case .manual: true
        case .healthKit, .watch, .imported: false
        }
    }
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

public enum BodyMetricKind: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case bodyMass
    case bodyFatPercentage
    case waistCircumference
    case restingHeartRate

    /// `Identifiable` so the metric row can use `LensPicker`, the house
    /// replacement for `.pickerStyle(.segmented)`.
    public var id: String { rawValue }

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

public enum WellnessDataState: Equatable, Sendable {
    case notRequested
    case denied
    case loading
    case noSamples
    case fresh(lastSyncAt: Date)
    case stale(lastSyncAt: Date)
    case offlineCached(lastSyncAt: Date)
    case failed(message: String)
}

public struct WellnessDisplayPreferences: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var enabledMetrics: [BodyMetricKind]
    public var preferredUnits: [BodyMetricKind: WellnessDisplayUnit]
    public var preferredSampleIDsByConflict: [String: UUID]
    public var updatedAt: Date

    public init(
        schemaVersion: Int = currentSchemaVersion,
        enabledMetrics: [BodyMetricKind] = BodyMetricKind.allCases,
        preferredUnits: [BodyMetricKind: WellnessDisplayUnit] = [:],
        preferredSampleIDsByConflict: [String: UUID] = [:],
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        var seen = Set<BodyMetricKind>()
        self.enabledMetrics = enabledMetrics.filter { seen.insert($0).inserted }
        self.preferredUnits = preferredUnits.filter { entry in
            Self.units(for: entry.key).contains(entry.value)
        }
        self.preferredSampleIDsByConflict = preferredSampleIDsByConflict
        self.updatedAt = updatedAt
    }

    public func preferredUnit(for kind: BodyMetricKind) -> WellnessDisplayUnit {
        preferredUnits[kind] ?? kind.canonicalUnit
    }

    public static func units(for kind: BodyMetricKind) -> [WellnessDisplayUnit] {
        switch kind {
        case .bodyMass: [.kilograms, .pounds]
        case .bodyFatPercentage: [.percent]
        case .waistCircumference: [.centimeters, .inches]
        case .restingHeartRate: [.beatsPerMinute]
        }
    }
}

public protocol WellnessPreferenceStore: Sendable {
    func load() -> WellnessDisplayPreferences
    func save(_ preferences: WellnessDisplayPreferences)
}

public final class UserDefaultsWellnessPreferenceStore: WellnessPreferenceStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "lifeboard.wellness.display-preferences.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> WellnessDisplayPreferences {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(WellnessDisplayPreferences.self, from: data),
              value.schemaVersion <= WellnessDisplayPreferences.currentSchemaVersion else {
            return WellnessDisplayPreferences()
        }
        return value
    }

    public func save(_ preferences: WellnessDisplayPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
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

public struct WellnessSourceConflict: Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: BodyMetricKind
    public var samples: [BodyMetricSample]

    public init(kind: BodyMetricKind, samples: [BodyMetricSample]) {
        self.kind = kind
        self.samples = samples.sorted {
            ($0.observedAt, $0.id.uuidString) < ($1.observedAt, $1.id.uuidString)
        }
        id = Self.identifier(kind: kind, sampleIDs: self.samples.map(\.id))
    }

    public func preferredSample(using preferences: WellnessDisplayPreferences) -> BodyMetricSample? {
        if let preferredID = preferences.preferredSampleIDsByConflict[id],
           let preferred = samples.first(where: { $0.id == preferredID }) {
            return preferred
        }
        return samples.sorted {
            ($0.updatedAt, $0.id.uuidString) > ($1.updatedAt, $1.id.uuidString)
        }.first
    }

    private static func identifier(kind: BodyMetricKind, sampleIDs: [UUID]) -> String {
        "\(kind.rawValue):\(sampleIDs.map(\.uuidString).sorted().joined(separator: ":"))"
    }
}

public struct WellnessSourceConflictDetector: Sendable {
    public var proximity: TimeInterval

    public init(proximity: TimeInterval = 15 * 60) {
        self.proximity = max(0, proximity)
    }

    public func conflicts(in samples: [BodyMetricSample]) -> [WellnessSourceConflict] {
        let sorted = samples.sorted {
            ($0.observedAt, $0.id.uuidString) < ($1.observedAt, $1.id.uuidString)
        }
        var rows: [WellnessSourceConflict] = []
        for leftIndex in sorted.indices {
            for rightIndex in sorted.indices where rightIndex > leftIndex {
                let left = sorted[leftIndex]
                let right = sorted[rightIndex]
                guard left.kind == right.kind else { continue }
                let distance = right.observedAt.timeIntervalSince(left.observedAt)
                if distance > proximity { break }
                guard left.source != right.source else { continue }
                rows.append(.init(kind: left.kind, samples: [left, right]))
            }
        }
        return rows
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
    public var healthStageValue: Int?
    public var healthMetadata: [String: String]?
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
        healthStageValue: Int? = nil,
        healthMetadata: [String: String]? = nil,
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
        self.healthStageValue = healthStageValue
        self.healthMetadata = healthMetadata
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
            domain: "body",
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
            domain: "workout",
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
            domain: "sleep",
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
            domain: "movement",
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
        domain: String,
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
            domain: domain,
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

public enum WellnessHomeCardFocus: Codable, Hashable, Sendable {
    case bodyMetric(BodyMetricKind)
    case workouts
    case sleep
    case movement
}

public enum MovementSummarySource: String, Codable, Hashable, Sendable {
    case appleHealth
    case lifeBoard
}

public struct MovementSummaryProjection: Equatable, Sendable {
    public var steps: Int?
    public var distanceMeters: Double?
    public var activeEnergyKilocalories: Double?
    public var source: MovementSummarySource
    public var updatedAt: Date?

    public init(
        steps: Int?,
        distanceMeters: Double?,
        activeEnergyKilocalories: Double?,
        source: MovementSummarySource,
        updatedAt: Date?
    ) {
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.source = source
        self.updatedAt = updatedAt
    }
}

/// Apple Health owns the daily activity total when it has a usable cached
/// value. Manual movement remains a separate custom record and is used only as
/// a fallback; it is never added to the Health total.
public enum HealthFirstMovementSummaryResolver {
    public static func resolve(
        health snapshot: HealthMetricsSnapshot?,
        manual records: [MovementContextRecord],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> MovementSummaryProjection {
        if let snapshot,
           healthCanLead(snapshot.statuses[.activity]) || healthCanLead(snapshot.statuses[.energy]),
           [.steps, .walkingRunningDistance, .activeEnergy].contains(where: { snapshot.aggregates[$0] != nil }) {
            let aggregates = snapshot.aggregates
            return MovementSummaryProjection(
                steps: aggregates[.steps].map { Int($0.value.rounded()) },
                distanceMeters: aggregates[.walkingRunningDistance]?.value,
                activeEnergyKilocalories: aggregates[.activeEnergy]?.value,
                source: .appleHealth,
                updatedAt: [.steps, .walkingRunningDistance, .activeEnergy]
                    .compactMap { aggregates[$0]?.end }
                    .max()
            )
        }

        let today = records.filter {
            $0.source.permitsManualCorrection
                && calendar.isDate($0.startedAt, inSameDayAs: now)
        }
        let steps = today.compactMap(\.steps)
        let distance = today.compactMap(\.distanceMeters)
        let energy = today.compactMap(\.activeEnergyKilocalories)
        return MovementSummaryProjection(
            steps: steps.isEmpty ? nil : steps.reduce(0, +),
            distanceMeters: distance.isEmpty ? nil : distance.reduce(0, +),
            activeEnergyKilocalories: energy.isEmpty ? nil : energy.reduce(0, +),
            source: .lifeBoard,
            updatedAt: today.map(\.updatedAt).max()
        )
    }

    private static func healthCanLead(_ status: HealthDomainStatus?) -> Bool {
        guard let status else { return false }
        return switch status.signal {
        case .recorded, .explicitZero, .partial, .stale, .offline,
             .unavailable, .protectedDataLocked, .writeDenied:
            true
        case .loading, .setupRequired, .noRecord:
            false
        }
    }
}

public struct WellnessHomeCardSource: HomeCardSource {
    public let definition: HomeCardDefinition
    public let primaryDestination = Destination.track
    public let privacyClassification = DataSensitivity.privateSensitive

    private let repository: any WellnessRepository
    private let focus: WellnessHomeCardFocus
    private let healthMetrics: (any HealthMetricsReading)?

    public init(
        definition: HomeCardDefinition,
        focus: WellnessHomeCardFocus,
        repository: any WellnessRepository,
        healthMetrics: (any HealthMetricsReading)? = nil
    ) {
        self.definition = definition
        self.focus = focus
        self.repository = repository
        self.healthMetrics = healthMetrics
    }

    public func snapshot(
        configuration: HomeCardConfiguration,
        size: HomeCardSize,
        at date: Date
    ) async -> HomeCardSnapshot {
        do {
            switch focus {
            case .bodyMetric(let kind):
                let samples = try await repository.bodyMetricSamples(kind: kind)
                guard let sample = samples.first else {
                    let snapshot = await healthMetrics?.currentSnapshot(now: date)
                    return empty(date, Self.emptyHealthDetail(
                        status: snapshot?.statuses[.body],
                        fallback: "Log a value when it is useful to you."
                    ))
                }
                let value = try sample.value(in: sample.displayUnit)
                // Oldest-first so the chart reads left to right; bounded so a
                // long history cannot make Home do unbounded work.
                let series = samples
                    .prefix(60)
                    .compactMap { entry -> HomeSeriesPoint? in
                        guard let converted = try? entry.value(in: sample.displayUnit) else { return nil }
                        return HomeSeriesPoint(date: entry.observedAt, value: converted)
                    }
                    .sorted { $0.date < $1.date }
                return ready(
                    value: Self.formatted(value, unit: sample.displayUnit),
                    detail: densityDetail(
                        size: size,
                        compact: sample.source.permitsManualCorrection
                            ? "LifeBoard · \(sample.observedAt.formatted(date: .abbreviated, time: .omitted))"
                            : "Apple Health · \(sample.observedAt.formatted(date: .abbreviated, time: .omitted))",
                        story: sample.source.permitsManualCorrection
                            ? "A LifeBoard measurement you can review or correct in Track."
                            : "An imported Apple Health measurement. Imported records are read-only in LifeBoard."
                    ),
                    date: sample.updatedAt,
                    payload: series.count > 1 ? .series(series) : .none
                )
            case .workouts:
                let workouts = try await repository.workoutRecords()
                guard let workout = workouts.first else {
                    let snapshot = await healthMetrics?.currentSnapshot(now: date)
                    return empty(date, Self.emptyHealthDetail(
                        status: snapshot?.statuses[.workouts],
                        fallback: "Add a workout manually or connect Apple Health."
                    ))
                }
                let minutes = max(0, workout.duration / 60)
                return ready(
                    value: workout.activityKind,
                    detail: densityDetail(
                        size: size,
                        compact: Self.duration(workout.duration),
                        story: "\(Self.duration(workout.duration)) on \(workout.startedAt.formatted(date: .abbreviated, time: .omitted)) · \(workout.source.permitsManualCorrection ? "LifeBoard" : "Apple Health")."
                    ),
                    date: workout.updatedAt,
                    payload: .metric(
                        .init(
                            amount: minutes,
                            unit: "min",
                            history: workouts
                                .prefix(30)
                                .map { HomeSeriesPoint(date: $0.startedAt, value: max(0, $0.duration / 60)) }
                                .sorted { $0.date < $1.date }
                        )
                    )
                )
            case .sleep:
                let notes = try await repository.sleepNotes()
                let nights = HealthSleepPresentation.nightlySummaries(notes: notes)
                guard let night = nights.first else {
                    let snapshot = await healthMetrics?.currentSnapshot(now: date)
                    return empty(date, Self.emptyHealthDetail(
                        status: snapshot?.statuses[.sleep],
                        fallback: "Add a sleep note when reflection would help."
                    ))
                }
                let series = nights
                    .prefix(30)
                    .map { HomeSeriesPoint(date: $0.night, value: max(0, $0.totalDuration / 3_600)) }
                    .sorted { $0.date < $1.date }
                let quality = night.samples.compactMap(\.quality).first
                let containsHealth = night.samples.contains { $0.source.permitsManualCorrection == false }
                return ready(
                    value: Self.duration(night.totalDuration),
                    detail: densityDetail(
                        size: size,
                        compact: quality.map { "Quality \($0)/5" }
                            ?? (containsHealth ? "Apple Health" : "No rating needed"),
                        story: containsHealth
                            ? "Nightly total consolidated from Apple Health intervals. LifeBoard notes remain separate."
                            : "Your note stays descriptive and is never treated as a diagnosis."
                    ),
                    date: night.samples.map(\.updatedAt).max() ?? night.endedAt,
                    payload: series.count > 1 ? .series(series) : .none
                )
            case .movement:
                let records = try await repository.movementRecords()
                let healthSnapshot = await healthMetrics?.currentSnapshot(now: date)
                let summary = HealthFirstMovementSummaryResolver.resolve(
                    health: healthSnapshot,
                    manual: records,
                    now: date
                )
                guard summary.steps != nil
                        || summary.distanceMeters != nil
                        || summary.activeEnergyKilocalories != nil else {
                    return empty(date, Self.emptyHealthDetail(
                        status: healthSnapshot?.statuses[.activity],
                        fallback: "Movement appears here when available."
                    ))
                }
                let stepHistory: [HomeSeriesPoint]
                if summary.source == .appleHealth, let healthMetrics {
                    let history = await healthMetrics.cachedHistory(
                        domain: .activity,
                        range: .thirtyDays,
                        now: date
                    )
                    stepHistory = (history[.steps] ?? []).map {
                        HomeSeriesPoint(date: $0.start, value: $0.value)
                    }
                } else {
                    stepHistory = records.prefix(30).compactMap { record in
                        record.steps.map { HomeSeriesPoint(date: record.startedAt, value: Double($0)) }
                    }.sorted { $0.date < $1.date }
                }

                var movementPayload = HomeCardPayload.none
                if let steps = summary.steps {
                    movementPayload = .metric(
                        HomeMetricValue(
                            amount: Double(steps),
                            unit: "steps",
                            history: stepHistory
                        )
                    )
                }

                return ready(
                    value: summary.steps.map { "\($0.formatted()) steps" }
                        ?? summary.distanceMeters.map { String(format: "%.1f km", $0 / 1_000) }
                        ?? "Movement",
                    detail: densityDetail(
                        size: size,
                        compact: [
                            summary.source == .appleHealth ? "Apple Health" : "LifeBoard",
                            summary.distanceMeters.map { String(format: "%.1f km", $0 / 1_000) },
                            summary.source == .appleHealth
                                ? Self.healthStatusSuffix(healthSnapshot?.statuses[.activity])
                                : nil
                        ].compactMap { $0 }.joined(separator: " · "),
                        story: [
                            summary.source == .appleHealth
                                ? "Today’s Apple Health total. Custom LifeBoard records stay separate."
                                : "Today’s custom LifeBoard movement. Connect Apple Health for device totals.",
                            summary.source == .appleHealth
                                ? Self.healthStatusSuffix(healthSnapshot?.statuses[.activity])
                                : nil
                        ].compactMap { $0 }.joined(separator: " ")
                    ),
                    date: summary.updatedAt ?? date,
                    payload: movementPayload
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

    private func ready(
        value: String,
        detail: String?,
        date: Date,
        payload: HomeCardPayload = .none
    ) -> HomeCardSnapshot {
        HomeCardSnapshot(
            availability: .ready,
            title: definition.title,
            value: value,
            detail: detail,
            payload: payload,
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

    private static func emptyHealthDetail(
        status: HealthDomainStatus?,
        fallback: String
    ) -> String {
        guard let status else { return fallback }
        switch status.signal {
        case .setupRequired:
            return "Connect Apple Health to import available records, or add one in LifeBoard."
        case .loading:
            return "Apple Health is refreshing automatically. You can still add a LifeBoard record."
        case .stale, .partial, .offline, .protectedDataLocked:
            return "No cached record is available yet. Apple Health will refresh automatically."
        case .unavailable:
            return "Apple Health is unavailable. You can still add a LifeBoard record."
        case .writeDenied, .noRecord, .explicitZero, .recorded:
            return fallback
        }
    }

    private static func healthStatusSuffix(_ status: HealthDomainStatus?) -> String? {
        guard let status else { return nil }
        return switch status.signal {
        case .stale: "May be out of date; refreshes automatically."
        case .partial, .offline: "Some values are unavailable; refreshes automatically."
        case .protectedDataLocked: "Unlock the device to refresh."
        case .unavailable: "Showing the last available Apple Health data."
        case .writeDenied: "Apple Health write access is off."
        case .loading, .setupRequired, .noRecord, .explicitZero, .recorded: nil
        }
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
