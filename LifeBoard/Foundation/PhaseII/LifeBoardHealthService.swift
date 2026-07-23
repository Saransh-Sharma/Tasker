import Foundation
import HealthKit
import Observation

public protocol LifeBoardHealthReading: Sendable {
    func requestAndReadToday() async -> LifeBoardHealthSnapshot
}

public final class LifeBoardHealthService: LifeBoardHealthReading, @unchecked Sendable {
    private let healthStore: HKHealthStore
    private let calendar: Calendar

    public init(healthStore: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.healthStore = healthStore
        self.calendar = calendar
    }

    public func requestAndReadToday() async -> LifeBoardHealthSnapshot {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let calorieType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return .init(availability: .unavailable, steps: nil, activeCalories: nil, measuredAt: nil)
        }

        do {
            var requestedTypes: Set<HKObjectType> = [stepType, calorieType]
            let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
            let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass)
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
            if V2FeatureFlags.healthIntegrationsV1Enabled {
                if let distanceType { requestedTypes.insert(distanceType) }
                if let bodyMassType { requestedTypes.insert(bodyMassType) }
                if let sleepType { requestedTypes.insert(sleepType) }
                requestedTypes.insert(HKObjectType.workoutType())
            }
            try await requestAuthorization(reading: requestedTypes)
            async let steps = cumulativeSum(for: stepType, unit: .count())
            async let calories = cumulativeSum(for: calorieType, unit: .kilocalorie())
            async let distance = enabledCumulativeSum(
                for: distanceType,
                unit: .meter(),
                enabled: V2FeatureFlags.healthIntegrationsV1Enabled
            )
            async let bodyMass = enabledLatestQuantity(
                for: bodyMassType,
                unit: .gramUnit(with: .kilo),
                enabled: V2FeatureFlags.healthIntegrationsV1Enabled
            )
            async let workouts = V2FeatureFlags.healthIntegrationsV1Enabled ? workoutRecordsForToday() : []
            async let sleep = V2FeatureFlags.healthIntegrationsV1Enabled ? recentSleepNotes() : []
            return await .init(
                availability: .available,
                steps: steps,
                activeCalories: calories,
                bodyMassKilograms: bodyMass,
                distanceMeters: distance,
                workouts: workouts,
                sleepNotes: sleep,
                measuredAt: Date()
            )
        } catch {
            // HealthKit deliberately does not reveal whether read access was denied.
            // Denied access and no samples therefore share the same neutral surface.
            return .init(availability: .unavailable, steps: nil, activeCalories: nil, measuredAt: nil)
        }
    }

    private func requestAuthorization(reading types: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            healthStore.requestAuthorization(toShare: [], read: types) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: LifeBoardHealthError.authorizationUnavailable)
                }
            }
        }
    }

    private func cumulativeSum(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func enabledCumulativeSum(
        for type: HKQuantityType?,
        unit: HKUnit,
        enabled: Bool
    ) async -> Double? {
        guard enabled, let type else { return nil }
        return await cumulativeSum(for: type, unit: unit)
    }

    private func enabledLatestQuantity(
        for type: HKQuantityType?,
        unit: HKUnit,
        enabled: Bool
    ) async -> Double? {
        guard enabled, let type else { return nil }
        return await latestQuantity(for: type, unit: unit)
    }

    private func latestQuantity(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func workoutRecordsForToday() async -> [WorkoutRecord] {
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let records = (samples as? [HKWorkout] ?? []).compactMap { workout in
                    try? WorkoutRecord(
                        id: workout.uuid,
                        activityKind: Self.activityTitle(workout.workoutActivityType),
                        startedAt: workout.startDate,
                        endedAt: workout.endDate,
                        energyKilocalories: Self.workoutQuantity(
                            workout,
                            identifier: .activeEnergyBurned,
                            unit: .kilocalorie()
                        ),
                        distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
                        source: .healthKit,
                        sourceIdentifier: workout.uuid.uuidString,
                        createdAt: workout.startDate,
                        updatedAt: workout.endDate
                    )
                }
                continuation.resume(returning: records)
            }
            healthStore.execute(query)
        }
    }

    private func recentSleepNotes() async -> [SleepNote] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) ?? Date.distantPast
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let notes = (samples as? [HKCategorySample] ?? [])
                    .filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                            || sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                            || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                            || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }
                    .compactMap { sample in
                        try? SleepNote(
                            id: sample.uuid,
                            startedAt: sample.startDate,
                            endedAt: sample.endDate,
                            source: .healthKit,
                            sourceIdentifier: sample.uuid.uuidString,
                            capturedTimeZone: Self.timeZone(from: sample.metadata),
                            createdAt: sample.startDate,
                            updatedAt: sample.endDate
                        )
                    }
                continuation.resume(returning: notes)
            }
            healthStore.execute(query)
        }
    }

    private static func activityTitle(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Strength training"
        case .yoga: "Yoga"
        case .hiking: "Hiking"
        case .dance: "Dance"
        default: "Workout"
        }
    }

    private static func workoutQuantity(
        _ workout: HKWorkout,
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return workout.statistics(for: type)?.sumQuantity()?.doubleValue(for: unit)
    }

    private static func timeZone(from metadata: [String: Any]?) -> TimeZone {
        guard let identifier = metadata?[HKMetadataKeyTimeZone] as? String,
              let timeZone = TimeZone(identifier: identifier) else {
            return .autoupdatingCurrent
        }
        return timeZone
    }
}

private enum LifeBoardHealthError: Error {
    case authorizationUnavailable
}

@MainActor
@Observable
public final class LifeBoardHealthStore {
    public private(set) var snapshot: LifeBoardHealthSnapshot = .notRequested
    public private(set) var isLoading = false

    private let service: any LifeBoardHealthReading

    public init(service: any LifeBoardHealthReading = LifeBoardHealthService()) {
        self.service = service
    }

    public func requestAccessAndRefresh() async {
        guard !isLoading else { return }
        isLoading = true
        snapshot = await service.requestAndReadToday()
        isLoading = false
    }
}
