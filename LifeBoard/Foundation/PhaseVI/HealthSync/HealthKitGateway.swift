import Foundation
import HealthKit

public struct HealthSavedObject: Hashable, Sendable {
    public let role: String
    public let uuid: UUID

    public init(role: String, uuid: UUID) {
        self.role = role
        self.uuid = uuid
    }
}

public protocol HealthKitGatewayProtocol: Sendable {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization(writeDomains: Set<HealthDomain>) async throws
    func writeAuthorization(for metric: HealthMetric) async -> HealthWriteAuthorization
    func anchoredChanges(metric: HealthMetric, anchorData: Data?) async throws -> HealthAnchoredChanges
    func aggregate(metric: HealthMetric, from start: Date, to end: Date) async throws -> HealthAggregateValue
    func dailyAggregates(metric: HealthMetric, from start: Date, to end: Date) async throws -> [HealthAggregateValue]
    func save(_ payload: HealthWritePayload, syncVersion: Int64) async throws -> [HealthSavedObject]
    func deleteObject(uuid: UUID, metric: HealthMetric) async throws
    func installObserver(
        metric: HealthMetric,
        update: @escaping @Sendable (_ completion: @escaping () -> Void) -> Void
    )
    func enableBackgroundDelivery(for metric: HealthMetric) async throws
}

public extension HealthKitGatewayProtocol {
    func dailyAggregates(
        metric: HealthMetric,
        from start: Date,
        to end: Date
    ) async throws -> [HealthAggregateValue] {
        guard end > start else { return [] }
        let calendar = Calendar.autoupdatingCurrent
        var day = calendar.startOfDay(for: start)
        var result: [HealthAggregateValue] = []
        while day < end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            result.append(try await aggregate(metric: metric, from: max(day, start), to: min(next, end)))
            day = next
        }
        return result
    }
}

public enum HealthKitGatewayError: Error, Sendable {
    case unavailable
    case unsupportedMetric
    case invalidPayload
    case authorizationNotGranted
    case objectNotFound
}

public final class HealthKitGateway: HealthKitGatewayProtocol, @unchecked Sendable {
    private let store: HKHealthStore
    private let calendar: Calendar
    private let lock = NSLock()
    private var observerQueries: [HealthMetric: HKObserverQuery] = [:]

    public init(store: HKHealthStore = HKHealthStore(), calendar: Calendar = .autoupdatingCurrent) {
        self.store = store
        self.calendar = calendar
    }

    public var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization(writeDomains: Set<HealthDomain>) async throws {
        guard isHealthDataAvailable else { throw HealthKitGatewayError.unavailable }
        let share = Set(writeDomains.flatMap { HealthKitTypeCatalog.shareTypes(for: $0) })
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            store.requestAuthorization(toShare: share, read: HealthKitTypeCatalog.readTypes()) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitGatewayError.authorizationNotGranted)
                }
            }
        }
    }

    public func writeAuthorization(for metric: HealthMetric) async -> HealthWriteAuthorization {
        guard isHealthDataAvailable,
              let type = HealthKitTypeCatalog.sampleType(for: metric),
              metric.domain.supportsWriteBack
                || metric == .activeEnergy
                || metric == .walkingRunningDistance else {
            return .unavailable
        }
        switch store.authorizationStatus(for: type) {
        case .notDetermined: return .notDetermined
        case .sharingDenied: return .denied
        case .sharingAuthorized: return .authorized
        @unknown default: return .unavailable
        }
    }

    public func anchoredChanges(
        metric: HealthMetric,
        anchorData: Data?
    ) async throws -> HealthAnchoredChanges {
        guard let type = HealthKitTypeCatalog.sampleType(for: metric) else {
            throw HealthKitGatewayError.unsupportedMetric
        }
        let anchor = try anchorData.flatMap {
            try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
        }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, deleted, newAnchor, error in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                do {
                    let encodedAnchor = try newAnchor.map {
                        try NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
                    }
                    continuation.resume(returning: .init(
                        samples: (samples ?? []).compactMap { self.envelope(for: $0, metric: metric) },
                        deletedObjectIDs: (deleted ?? []).map(\.uuid),
                        newAnchorData: encodedAnchor
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            store.execute(query)
        }
    }

    public func aggregate(
        metric: HealthMetric,
        from start: Date,
        to end: Date
    ) async throws -> HealthAggregateValue {
        guard let type = HealthKitTypeCatalog.sampleType(for: metric) else {
            throw HealthKitGatewayError.unsupportedMetric
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        if metric.domain == .nutrition {
            return try await externalNutritionAggregate(
                metric: metric,
                type: type,
                predicate: predicate,
                start: start,
                end: end
            )
        }
        guard let quantityType = type as? HKQuantityType else {
            throw HealthKitGatewayError.unsupportedMetric
        }
        let option: HKStatisticsOptions = [.steps, .walkingRunningDistance, .activeEnergy, .restingEnergy,
                                           .water, .dietaryEnergy, .dietaryProtein,
                                           .dietaryCarbohydrates, .dietaryFat].contains(metric)
            ? .cumulativeSum
            : .discreteAverage
        let lastSampleAt = try? await latestSampleDate(type: type, predicate: predicate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: option
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let unit = HealthKitTypeCatalog.unit(for: metric) else {
                    continuation.resume(throwing: HealthKitGatewayError.unsupportedMetric)
                    return
                }
                let quantity = option == .cumulativeSum
                    ? statistics?.sumQuantity()
                    : statistics?.averageQuantity()
                let raw = quantity?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: .init(
                    metric: metric,
                    value: HealthKitTypeCatalog.lifeBoardValue(raw, for: metric),
                    start: start,
                    end: end,
                    lastSampleAt: lastSampleAt
                ))
            }
            store.execute(query)
        }
    }

    public func dailyAggregates(
        metric: HealthMetric,
        from start: Date,
        to end: Date
    ) async throws -> [HealthAggregateValue] {
        guard end > start,
              let type = HealthKitTypeCatalog.sampleType(for: metric) else {
            return []
        }
        if metric.domain == .nutrition {
            return try await externalNutritionDailyAggregates(
                metric: metric,
                type: type,
                start: start,
                end: end
            )
        }
        guard let quantityType = type as? HKQuantityType,
              let unit = HealthKitTypeCatalog.unit(for: metric) else {
            return []
        }
        let cumulative: Set<HealthMetric> = [
            .steps, .walkingRunningDistance, .activeEnergy, .restingEnergy, .water
        ]
        let option: HKStatisticsOptions = cumulative.contains(metric) ? .cumulativeSum : .discreteAverage
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        var interval = DateComponents()
        interval.day = 1
        let anchor = calendar.startOfDay(for: start)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: option,
                anchorDate: anchor,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var values: [HealthAggregateValue] = []
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let quantity = option == .cumulativeSum
                        ? statistics.sumQuantity()
                        : statistics.averageQuantity()
                    guard let quantity else { return }
                    let raw = quantity.doubleValue(for: unit)
                    values.append(.init(
                        metric: metric,
                        value: HealthKitTypeCatalog.lifeBoardValue(raw, for: metric),
                        start: statistics.startDate,
                        end: statistics.endDate
                    ))
                }
                continuation.resume(returning: values)
            }
            store.execute(query)
        }
    }

    public func save(_ payload: HealthWritePayload, syncVersion: Int64) async throws -> [HealthSavedObject] {
        guard await writeAuthorization(for: payload.metric) == .authorized else {
            throw HealthKitGatewayError.authorizationNotGranted
        }
        if payload.metric == .workout {
            return try await saveWorkout(payload, syncVersion: syncVersion)
        }
        guard let type = HealthKitTypeCatalog.sampleType(for: payload.metric) as? HKQuantityType,
              let unit = HealthKitTypeCatalog.unit(for: payload.metric),
              let value = payload.value else {
            throw HealthKitGatewayError.invalidPayload
        }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(
                unit: unit,
                doubleValue: HealthKitTypeCatalog.healthKitValue(value, for: payload.metric)
            ),
            start: payload.startDate,
            end: payload.endDate,
            metadata: metadata(for: payload, syncVersion: syncVersion)
        )
        try await saveObjects([sample])
        return [.init(role: payload.role, uuid: sample.uuid)]
    }

    public func deleteObject(uuid: UUID, metric: HealthMetric) async throws {
        let object = try await object(uuid: uuid, metric: metric)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            store.delete(object) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitGatewayError.objectNotFound)
                }
            }
        }
    }

    public func installObserver(
        metric: HealthMetric,
        update: @escaping @Sendable (_ completion: @escaping () -> Void) -> Void
    ) {
        guard let type = HealthKitTypeCatalog.sampleType(for: metric) else { return }
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
            update(completion)
        }
        lock.lock()
        if let previous = observerQueries.updateValue(query, forKey: metric) {
            store.stop(previous)
        }
        lock.unlock()
        store.execute(query)
    }

    public func enableBackgroundDelivery(for metric: HealthMetric) async throws {
        guard let type = HealthKitTypeCatalog.sampleType(for: metric) else {
            throw HealthKitGatewayError.unsupportedMetric
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitGatewayError.unavailable)
                }
            }
        }
    }

    private func saveWorkout(
        _ payload: HealthWritePayload,
        syncVersion: Int64
    ) async throws -> [HealthSavedObject] {
        guard let workout = payload.workout else { throw HealthKitGatewayError.invalidPayload }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = HealthWorkoutActivityMapper.activityType(for: workout.activityName)
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await beginCollection(builder, start: payload.startDate)

        var associated: [(String, HKSample)] = []
        if let energy = workout.energyKilocalories,
           let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            associated.append(("energy", HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: energy),
                start: payload.startDate,
                end: payload.endDate,
                metadata: metadata(for: payload, syncVersion: syncVersion, role: "energy")
            )))
        }
        if let distance = workout.distanceMeters,
           let type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            associated.append(("distance", HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: .meter(), doubleValue: distance),
                start: payload.startDate,
                end: payload.endDate,
                metadata: metadata(for: payload, syncVersion: syncVersion, role: "distance")
            )))
        }
        if associated.isEmpty == false {
            try await add(associated.map(\.1), to: builder)
        }
        try await endCollection(builder, end: payload.endDate)
        let savedWorkout = try await finish(builder)
        var result = [HealthSavedObject(role: payload.role, uuid: savedWorkout.uuid)]
        result.append(contentsOf: associated.map { HealthSavedObject(role: $0.0, uuid: $0.1.uuid) })
        return result
    }

    private func envelope(for sample: HKSample, metric: HealthMetric) -> HealthSampleEnvelope? {
        let value: HealthSampleEnvelope.Value
        if let quantity = sample as? HKQuantitySample,
           let unit = HealthKitTypeCatalog.unit(for: metric) {
            value = .quantity(HealthKitTypeCatalog.lifeBoardValue(
                quantity.quantity.doubleValue(for: unit),
                for: metric
            ))
        } else if let category = sample as? HKCategorySample {
            value = .category(category.value)
        } else if let workout = sample as? HKWorkout {
            value = .workout(.init(
                activityName: HealthWorkoutActivityMapper.activityName(for: workout.workoutActivityType),
                duration: workout.duration,
                energyKilocalories: workout.statistics(
                    for: HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
                )?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                distanceMeters: workout.totalDistance?.doubleValue(for: .meter())
            ))
        } else {
            return nil
        }
        let metadata = sample.metadata?.reduce(into: [String: String]()) { result, pair in
            if let string = pair.value as? String {
                result[pair.key] = string
            }
        } ?? [:]
        return .init(
            id: sample.uuid,
            metric: metric,
            value: value,
            startDate: sample.startDate,
            endDate: sample.endDate,
            sourceBundleIdentifier: sample.sourceRevision.source.bundleIdentifier,
            syncIdentifier: sample.metadata?[HKMetadataKeySyncIdentifier] as? String,
            syncVersion: (sample.metadata?[HKMetadataKeySyncVersion] as? NSNumber)?.int64Value,
            metadata: metadata
        )
    }

    private func metadata(
        for payload: HealthWritePayload,
        syncVersion: Int64,
        role: String? = nil
    ) -> [String: Any] {
        var result: [String: Any] = payload.metadata
        let resolvedRole = role ?? payload.role
        result[HKMetadataKeySyncIdentifier] =
            "com.lifeboard.\(payload.metric.rawValue).\(payload.localID.uuidString.lowercased()).\(resolvedRole)"
        result[HKMetadataKeySyncVersion] = NSNumber(value: syncVersion)
        result[HKMetadataKeyTimeZone] = calendar.timeZone.identifier
        result["com.lifeboard.role"] = resolvedRole
        if payload.metric == .workout, let label = payload.workout?.activityName {
            result["com.lifeboard.workout.label"] = label
        }
        return result
    }

    private func saveObjects(_ objects: [HKObject]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            store.save(objects) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitGatewayError.invalidPayload)
                }
            }
        }
    }

    private func externalNutritionAggregate(
        metric: HealthMetric,
        type: HKSampleType,
        predicate: NSPredicate,
        start: Date,
        end: Date
    ) async throws -> HealthAggregateValue {
        guard let unit = HealthKitTypeCatalog.unit(for: metric) else {
            throw HealthKitGatewayError.unsupportedMetric
        }
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKQuantitySample })
                }
            }
            store.execute(query)
        }
        let external = samples.filter {
            guard let identifier = $0.metadata?[HKMetadataKeySyncIdentifier] as? String else {
                return true
            }
            return identifier.hasPrefix("com.lifeboard.") == false
        }
        let rawValue = external.reduce(0) { partial, sample in
            partial + sample.quantity.doubleValue(for: unit)
        }
        return .init(
            metric: metric,
            value: HealthKitTypeCatalog.lifeBoardValue(rawValue, for: metric),
            start: start,
            end: end,
            lastSampleAt: external.map(\.endDate).max()
        )
    }

    private func latestSampleDate(type: HKSampleType, predicate: NSPredicate) async throws -> Date? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples?.first?.endDate)
                }
            }
            store.execute(query)
        }
    }

    private func externalNutritionDailyAggregates(
        metric: HealthMetric,
        type: HKSampleType,
        start: Date,
        end: Date
    ) async throws -> [HealthAggregateValue] {
        guard let unit = HealthKitTypeCatalog.unit(for: metric) else {
            throw HealthKitGatewayError.unsupportedMetric
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKQuantitySample })
                }
            }
            store.execute(query)
        }
        let external = samples.filter {
            guard let identifier = $0.metadata?[HKMetadataKeySyncIdentifier] as? String else { return true }
            return identifier.hasPrefix("com.lifeboard.") == false
        }
        let grouped = Dictionary(grouping: external) { calendar.startOfDay(for: $0.startDate) }
        return grouped.keys.sorted().compactMap { day in
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day),
                  let values = grouped[day], values.isEmpty == false else {
                return nil
            }
            let raw = values.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
            return .init(
                metric: metric,
                value: HealthKitTypeCatalog.lifeBoardValue(raw, for: metric),
                start: day,
                end: dayEnd,
                lastSampleAt: values.map(\.endDate).max()
            )
        }
    }

    private func object(uuid: UUID, metric: HealthMetric) async throws -> HKObject {
        guard let primaryType = HealthKitTypeCatalog.sampleType(for: metric) else {
            throw HealthKitGatewayError.unsupportedMetric
        }
        var candidateTypes = [primaryType]
        if metric == .workout {
            candidateTypes.append(contentsOf: [
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
                HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
            ].compactMap { $0 })
        }
        for sampleType in candidateTypes {
            if let object = try await queriedObject(uuid: uuid, sampleType: sampleType) {
                return object
            }
        }
        throw HealthKitGatewayError.objectNotFound
    }

    private func queriedObject(uuid: UUID, sampleType: HKSampleType) async throws -> HKObject? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKObject?, any Error>) in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: HKQuery.predicateForObject(with: uuid),
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let sample = samples?.first {
                    continuation.resume(returning: sample)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            store.execute(query)
        }
    }

    private func beginCollection(_ builder: HKWorkoutBuilder, start: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            builder.beginCollection(withStart: start) { success, error in
                Self.resume(continuation, success: success, error: error)
            }
        }
    }

    private func add(_ samples: [HKSample], to builder: HKWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            builder.add(samples) { success, error in
                Self.resume(continuation, success: success, error: error)
            }
        }
    }

    private func endCollection(_ builder: HKWorkoutBuilder, end: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            builder.endCollection(withEnd: end) { success, error in
                Self.resume(continuation, success: success, error: error)
            }
        }
    }

    private func finish(_ builder: HKWorkoutBuilder) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, any Error>) in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: HealthKitGatewayError.invalidPayload)
                }
            }
        }
    }

    private static func resume(
        _ continuation: CheckedContinuation<Void, any Error>,
        success: Bool,
        error: (any Error)?
    ) {
        if let error {
            continuation.resume(throwing: error)
        } else if success {
            continuation.resume(returning: ())
        } else {
            continuation.resume(throwing: HealthKitGatewayError.invalidPayload)
        }
    }

}
