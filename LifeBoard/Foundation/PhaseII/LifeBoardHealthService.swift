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
            try await requestAuthorization(reading: [stepType, calorieType])
            async let steps = cumulativeSum(for: stepType, unit: .count())
            async let calories = cumulativeSum(for: calorieType, unit: .kilocalorie())
            return await .init(
                availability: .available,
                steps: steps,
                activeCalories: calories,
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
