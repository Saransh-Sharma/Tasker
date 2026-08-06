import Foundation

public enum HealthReadRequestState: String, Codable, Sendable {
    case neverRequested
    case requestCompleted
    case receivingData
}

public enum HealthWriteAuthorization: String, Codable, Sendable {
    case notDetermined
    case denied
    case authorized
    case unavailable
}

public enum HealthSignalState: String, Codable, Sendable {
    case loading
    case setupRequired
    case noRecord
    case stale
    case partial
    case unavailable
    case explicitZero
    case recorded
    case writeDenied
    case protectedDataLocked
    case offline
}

public enum HealthHistoryRange: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sevenDays: "7D"
        case .thirtyDays: "30D"
        case .ninetyDays: "90D"
        case .all: "All"
        }
    }

    public func startDate(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Date {
        let today = calendar.startOfDay(for: now)
        let days: Int = switch self {
        case .sevenDays: 6
        case .thirtyDays: 29
        case .ninetyDays: 89
        case .all: 36_500
        }
        return calendar.date(byAdding: .day, value: -days, to: today) ?? today
    }
}

public enum HealthInsightDomain: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case activity
    case energy
    case hydration
    case nutrition
    case body
    case workouts
    case sleep

    public var id: String { rawValue }
    public var healthDomain: HealthDomain { HealthDomain(rawValue: rawValue) ?? .activity }
    public var title: String { healthDomain.title }
    public var symbolName: String { healthDomain.symbolName }
    public var metrics: [HealthMetric] { healthDomain.metrics }
}

public enum HealthSyncTrigger: Hashable, Sendable {
    case authorization
    case observer(Set<HealthMetric>)
    case foreground
    case manual
    case outbox(Set<HealthMetric>)
    case historyBackfill(Set<HealthMetric>, HealthHistoryRange)

    public var metrics: Set<HealthMetric> {
        switch self {
        case .observer(let metrics), .outbox(let metrics), .historyBackfill(let metrics, _): metrics
        case .authorization, .foreground, .manual: Set(HealthKitTypeCatalog.readableMetrics)
        }
    }

    public var name: String {
        switch self {
        case .authorization: "authorization"
        case .observer: "observer"
        case .foreground: "foreground"
        case .manual: "manual"
        case .outbox: "outbox"
        case .historyBackfill: "history_backfill"
        }
    }
}

public struct HealthSyncOutcome: Sendable {
    public let trigger: HealthSyncTrigger
    public let refreshedMetrics: Set<HealthMetric>
    public let aggregates: [HealthMetric: HealthAggregateValue]
    public let failures: [HealthMetric: String]
    public let completedAt: Date
    public let skipped: Bool

    public init(
        trigger: HealthSyncTrigger,
        refreshedMetrics: Set<HealthMetric> = [],
        aggregates: [HealthMetric: HealthAggregateValue] = [:],
        failures: [HealthMetric: String] = [:],
        completedAt: Date = Date(),
        skipped: Bool = false
    ) {
        self.trigger = trigger
        self.refreshedMetrics = refreshedMetrics
        self.aggregates = aggregates
        self.failures = failures
        self.completedAt = completedAt
        self.skipped = skipped
    }

    public var isPartial: Bool { refreshedMetrics.isEmpty == false && failures.isEmpty == false }
    public var succeeded: Bool { skipped == false && failures.isEmpty }
}

public struct HealthSyncEvent: Sendable {
    public let trigger: HealthSyncTrigger
    public let metrics: Set<HealthMetric>
    public let completedAt: Date
    public let isPartial: Bool
}

public actor HealthSyncInvalidationHub {
    public static let shared = HealthSyncInvalidationHub()

    private var continuations: [UUID: AsyncStream<HealthSyncEvent>.Continuation] = [:]

    public func updates() -> AsyncStream<HealthSyncEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(id) }
            }
        }
    }

    public func publish(_ event: HealthSyncEvent) {
        continuations.values.forEach { $0.yield(event) }
    }

    private func remove(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

public struct HealthDomainStatus: Codable, Hashable, Sendable, Identifiable {
    public var id: HealthDomain { domain }
    public let domain: HealthDomain
    public var readRequestState: HealthReadRequestState
    public var writeAuthorizations: [HealthMetric: HealthWriteAuthorization]
    public var writeEnabled: Bool
    public var signal: HealthSignalState
    public var lastSuccessfulSync: Date?

    public init(
        domain: HealthDomain,
        readRequestState: HealthReadRequestState = .neverRequested,
        writeAuthorizations: [HealthMetric: HealthWriteAuthorization] = [:],
        writeEnabled: Bool = false,
        signal: HealthSignalState = .setupRequired,
        lastSuccessfulSync: Date? = nil
    ) {
        self.domain = domain
        self.readRequestState = readRequestState
        self.writeAuthorizations = writeAuthorizations
        self.writeEnabled = writeEnabled
        self.signal = signal
        self.lastSuccessfulSync = lastSuccessfulSync
    }

    public var hasPartialWriteAuthorization: Bool {
        let values = domain.metrics.compactMap { writeAuthorizations[$0] }
        return values.contains(.authorized) && values.contains { $0 != .authorized }
    }
}

public struct HealthAggregateValue: Codable, Hashable, Sendable, Identifiable {
    public var id: String { "\(metric.rawValue):\(start.timeIntervalSinceReferenceDate)" }
    public let metric: HealthMetric
    public let value: Double
    public let start: Date
    public let end: Date
    public let lastSampleAt: Date?
    public let sourceLabel: String

    public init(
        metric: HealthMetric,
        value: Double,
        start: Date,
        end: Date,
        lastSampleAt: Date? = nil,
        sourceLabel: String = "Apple Health"
    ) {
        self.metric = metric
        self.value = value
        self.start = start
        self.end = end
        self.lastSampleAt = lastSampleAt
        self.sourceLabel = sourceLabel
    }
}

public enum HealthGoalCelebrationGate {
    /// Returns true only for the first threshold crossing for a metric on a
    /// local calendar day. The stored marker contains no health value.
    public static func claim(
        metric: HealthMetric,
        day: Date,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let key = "healthGoalCelebration.\(metric.rawValue).\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        guard defaults.bool(forKey: key) == false else { return false }
        defaults.set(true, forKey: key)
        return true
    }
}

public enum HealthSleepPresentation {
    public struct NightSummary: Identifiable, Hashable, Sendable {
        public let night: Date
        public let startedAt: Date
        public let endedAt: Date
        public let totalDuration: TimeInterval
        public let samples: [SleepNote]

        public var id: Date { night }
    }

    /// Computes the union of raw sleep intervals clipped to a requested night.
    /// The source segments are never rewritten or merged in storage.
    public static func overlapSafeTotal(
        samples: [HealthSampleEnvelope],
        from start: Date,
        to end: Date
    ) -> TimeInterval {
        let intervals = samples.compactMap { sample -> DateInterval? in
            guard sample.metric == .sleep,
                  case .category = sample.value else {
                return nil
            }
            let clippedStart = max(start, sample.startDate)
            let clippedEnd = min(end, sample.endDate)
            guard clippedEnd > clippedStart else { return nil }
            return DateInterval(start: clippedStart, end: clippedEnd)
        }.sorted { $0.start < $1.start }

        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in intervals {
            guard let active = current else {
                current = interval
                continue
            }
            if interval.start <= active.end {
                current = DateInterval(start: active.start, end: max(active.end, interval.end))
            } else {
                total += active.duration
                current = interval
            }
        }
        return total + (current?.duration ?? 0)
    }

    public static func nightlySummaries(
        notes: [SleepNote],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [NightSummary] {
        let grouped = Dictionary(grouping: notes) { note in
            // Noon-to-noon keeps sleep crossing midnight in one human night.
            let shifted = note.endedAt.addingTimeInterval(-12 * 60 * 60)
            return calendar.startOfDay(for: shifted)
        }
        return grouped.compactMap { night, values in
            let sorted = values.sorted { $0.startedAt < $1.startedAt }
            guard let first = sorted.first else { return nil }
            var total: TimeInterval = 0
            var active = DateInterval(start: first.startedAt, end: first.endedAt)
            for note in sorted.dropFirst() {
                let interval = DateInterval(start: note.startedAt, end: note.endedAt)
                if interval.start <= active.end {
                    active = DateInterval(start: active.start, end: max(active.end, interval.end))
                } else {
                    total += active.duration
                    active = interval
                }
            }
            total += active.duration
            return NightSummary(
                night: night,
                startedAt: sorted.map(\.startedAt).min() ?? first.startedAt,
                endedAt: sorted.map(\.endedAt).max() ?? first.endedAt,
                totalDuration: total,
                samples: sorted
            )
        }.sorted { $0.night > $1.night }
    }
}

public enum HealthFastingSuggestion {
    public static func latestStart(localMealAt: Date?, externalDietaryEnergyAt: Date?) -> Date? {
        [localMealAt, externalDietaryEnergyAt].compactMap { $0 }.max()
    }
}

public enum HealthNutritionProjection {
    /// Produces external-only sums without reconstructing inferred meal records.
    public static func aggregate(
        samples: [HealthSampleEnvelope],
        metric: HealthMetric,
        lifeBoardIdentifierPrefix: String = "com.lifeboard."
    ) -> HealthAggregateValue? {
        let matching = samples.filter {
            $0.metric == metric && ($0.syncIdentifier?.hasPrefix(lifeBoardIdentifierPrefix) != true)
        }
        guard matching.isEmpty == false else { return nil }
        let value = matching.reduce(0.0) { partial, sample in
            guard case .quantity(let amount) = sample.value else { return partial }
            return partial + amount
        }
        return .init(
            metric: metric,
            value: value,
            start: matching.map(\.startDate).min() ?? Date(),
            end: matching.map(\.endDate).max() ?? Date(),
            lastSampleAt: matching.map(\.endDate).max()
        )
    }
}

public struct HealthSampleEnvelope: Codable, Hashable, Sendable, Identifiable {
    public enum Value: Codable, Hashable, Sendable {
        case quantity(Double)
        case category(Int)
        case workout(HealthWorkoutPayload)
    }

    public let id: UUID
    public let metric: HealthMetric
    public let value: Value
    public let startDate: Date
    public let endDate: Date
    public let sourceBundleIdentifier: String?
    public let syncIdentifier: String?
    public let syncVersion: Int64?
    public let metadata: [String: String]

    public init(
        id: UUID,
        metric: HealthMetric,
        value: Value,
        startDate: Date,
        endDate: Date,
        sourceBundleIdentifier: String? = nil,
        syncIdentifier: String? = nil,
        syncVersion: Int64? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.metric = metric
        self.value = value
        self.startDate = startDate
        self.endDate = endDate
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.metadata = metadata
    }
}

public struct HealthWorkoutPayload: Codable, Hashable, Sendable {
    public let activityName: String
    public let duration: TimeInterval
    public let energyKilocalories: Double?
    public let distanceMeters: Double?

    public init(
        activityName: String,
        duration: TimeInterval,
        energyKilocalories: Double? = nil,
        distanceMeters: Double? = nil
    ) {
        self.activityName = activityName
        self.duration = duration
        self.energyKilocalories = energyKilocalories
        self.distanceMeters = distanceMeters
    }
}

public struct HealthAnchoredChanges: Sendable {
    public let samples: [HealthSampleEnvelope]
    public let deletedObjectIDs: [UUID]
    public let newAnchorData: Data?

    public init(
        samples: [HealthSampleEnvelope],
        deletedObjectIDs: [UUID],
        newAnchorData: Data?
    ) {
        self.samples = samples
        self.deletedObjectIDs = deletedObjectIDs
        self.newAnchorData = newAnchorData
    }
}

public struct HealthWritePayload: Codable, Hashable, Sendable {
    public let localID: UUID
    public let metric: HealthMetric
    public let role: String
    public let value: Double?
    public let startDate: Date
    public let endDate: Date
    public let workout: HealthWorkoutPayload?
    public let metadata: [String: String]

    public init(
        localID: UUID,
        metric: HealthMetric,
        role: String = "primary",
        value: Double? = nil,
        startDate: Date,
        endDate: Date? = nil,
        workout: HealthWorkoutPayload? = nil,
        metadata: [String: String] = [:]
    ) {
        self.localID = localID
        self.metric = metric
        self.role = role
        self.value = value
        self.startDate = startDate
        self.endDate = endDate ?? startDate
        self.workout = workout
        self.metadata = metadata
    }

    public var syncIdentifier: String {
        "com.lifeboard.\(metric.rawValue).\(localID.uuidString.lowercased()).\(role)"
    }
}

public enum HealthSyncOperationKind: String, Codable, Sendable {
    case write
    case update
    case delete
}

public enum HealthSyncOperationState: String, Codable, Sendable {
    case pending
    case processing
    case retryScheduled
    case pausedPermission
    case completed
}

public struct HealthSyncOperation: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let localID: UUID
    public let metric: HealthMetric
    public let role: String
    public var kind: HealthSyncOperationKind
    public var state: HealthSyncOperationState
    public var payload: HealthWritePayload?
    public var syncVersion: Int64
    public var attemptCount: Int
    public var nextAttemptAt: Date?
    public var lastErrorCode: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        localID: UUID,
        metric: HealthMetric,
        role: String = "primary",
        kind: HealthSyncOperationKind,
        state: HealthSyncOperationState = .pending,
        payload: HealthWritePayload? = nil,
        syncVersion: Int64 = 1,
        attemptCount: Int = 0,
        nextAttemptAt: Date? = nil,
        lastErrorCode: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.localID = localID
        self.metric = metric
        self.role = role
        self.kind = kind
        self.state = state
        self.payload = payload
        self.syncVersion = max(1, syncVersion)
        self.attemptCount = attemptCount
        self.nextAttemptAt = nextAttemptAt
        self.lastErrorCode = lastErrorCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
