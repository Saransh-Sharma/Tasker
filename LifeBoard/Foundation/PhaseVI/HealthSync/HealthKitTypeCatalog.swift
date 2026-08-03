import Foundation
import HealthKit

/// A single LifeBoard-facing health metric. Each case maps to exactly one
/// HealthKit sample type and its canonical unit. This enum is the vocabulary the
/// rest of the sync stack speaks; the concrete `HKObjectType`/`HKUnit` details
/// live only in `HealthKitTypeCatalog`.
public enum HealthMetric: String, CaseIterable, Codable, Sendable {
    case steps
    case walkingRunningDistance
    case activeEnergy
    case restingEnergy
    case water
    case dietaryEnergy
    case dietaryProtein
    case dietaryCarbohydrates
    case dietaryFat
    case bodyMass
    case bodyFatPercentage
    case waistCircumference
    case restingHeartRate
    case workout
    case sleep

    /// The user-facing grouping this metric belongs to. Domains are what a person
    /// grants, toggles, and sees a summary card for — metrics are the plumbing.
    public var domain: HealthDomain {
        switch self {
        case .steps, .walkingRunningDistance: .activity
        case .activeEnergy, .restingEnergy: .energy
        case .water: .hydration
        case .dietaryEnergy, .dietaryProtein, .dietaryCarbohydrates, .dietaryFat: .nutrition
        case .bodyMass, .bodyFatPercentage, .waistCircumference, .restingHeartRate: .body
        case .workout: .workouts
        case .sleep: .sleep
        }
    }
}

/// The permission- and UI-level grouping of metrics. `fasting` has no HealthKit
/// type of its own; it is *read-informed* by nutrition (last dietary-energy entry)
/// and always stays local-canonical.
public enum HealthDomain: String, CaseIterable, Codable, Sendable, Identifiable {
    case activity
    case energy
    case hydration
    case nutrition
    case body
    case workouts
    case sleep
    case fasting

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .activity: "Activity"
        case .energy: "Energy"
        case .hydration: "Hydration"
        case .nutrition: "Nutrition"
        case .body: "Body"
        case .workouts: "Workouts"
        case .sleep: "Sleep"
        case .fasting: "Fasting"
        }
    }

    /// SF Symbol only — never an emoji (design contract).
    public var symbolName: String {
        switch self {
        case .activity: "figure.walk.motion"
        case .energy: "flame"
        case .hydration: "drop"
        case .nutrition: "fork.knife"
        case .body: "figure.stand"
        case .workouts: "dumbbell"
        case .sleep: "bed.double"
        case .fasting: "hourglass"
        }
    }

    /// One honest sentence describing what LifeBoard does with this domain, shown
    /// on the connect/settings surfaces so consent is specific.
    public var shareBlurb: String {
        switch self {
        case .activity: "Reads your steps and walking distance from Apple Health."
        case .energy: "Reads the active and resting energy your devices record."
        case .hydration: "Water you log flows to Apple Health, and water logged elsewhere flows back."
        case .nutrition: "Meals you log sync their calories and macros with Apple Health."
        case .body: "Weight and body measurements stay in sync both ways."
        case .workouts: "Workouts you log appear in Apple Health, and Health workouts appear here."
        case .sleep: "Reads sleep recorded by your devices to show rest context."
        case .fasting: "Uses your last meal time to suggest when a fast began. Fasting is never written to Health."
        }
    }

    /// Whether LifeBoard can write this domain back to HealthKit. Activity, energy
    /// and sleep are device-owned and read-only; fasting has no HK type.
    public var supportsWriteBack: Bool {
        switch self {
        case .hydration, .nutrition, .body, .workouts: true
        case .activity, .energy, .sleep, .fasting: false
        }
    }

    public var metrics: [HealthMetric] {
        HealthMetric.allCases.filter { $0.domain == self }
    }
}

/// The single source of truth translating `HealthMetric` values into HealthKit
/// object types, sample types, units, and read/share authorization sets. Nothing
/// else in the codebase should construct an `HKObjectType` for sync.
public enum HealthKitTypeCatalog {
    /// Metrics LifeBoard reads from HealthKit (everything except fasting).
    public static let readableMetrics: [HealthMetric] = HealthMetric.allCases

    /// Metrics LifeBoard writes to HealthKit. Steps/energy/sleep are device-owned;
    /// workouts and the nutrition/hydration/body values are user-authored.
    public static let writableMetrics: [HealthMetric] = HealthMetric.allCases.filter { $0.domain.supportsWriteBack }

    /// `HKQuantityTypeIdentifier` for quantity-backed metrics. `sleep` is a
    /// category type and `workout` is the workout type — both handled separately.
    public static func quantityIdentifier(for metric: HealthMetric) -> HKQuantityTypeIdentifier? {
        switch metric {
        case .steps: .stepCount
        case .walkingRunningDistance: .distanceWalkingRunning
        case .activeEnergy: .activeEnergyBurned
        case .restingEnergy: .basalEnergyBurned
        case .water: .dietaryWater
        case .dietaryEnergy: .dietaryEnergyConsumed
        case .dietaryProtein: .dietaryProtein
        case .dietaryCarbohydrates: .dietaryCarbohydrates
        case .dietaryFat: .dietaryFatTotal
        case .bodyMass: .bodyMass
        case .bodyFatPercentage: .bodyFatPercentage
        case .waistCircumference: .waistCircumference
        case .restingHeartRate: .restingHeartRate
        case .workout, .sleep: nil
        }
    }

    public static func objectType(for metric: HealthMetric) -> HKObjectType? {
        switch metric {
        case .workout:
            return HKObjectType.workoutType()
        case .sleep:
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        default:
            guard let identifier = quantityIdentifier(for: metric) else { return nil }
            return HKObjectType.quantityType(forIdentifier: identifier)
        }
    }

    public static func sampleType(for metric: HealthMetric) -> HKSampleType? {
        objectType(for: metric) as? HKSampleType
    }

    /// The canonical unit LifeBoard uses when reading or writing this metric.
    public static func unit(for metric: HealthMetric) -> HKUnit? {
        switch metric {
        case .steps: .count()
        case .walkingRunningDistance: .meter()
        case .activeEnergy, .restingEnergy, .dietaryEnergy: .kilocalorie()
        case .water: .literUnit(with: .milli)
        case .dietaryProtein, .dietaryCarbohydrates, .dietaryFat: .gram()
        case .bodyMass: .gramUnit(with: .kilo)
        case .bodyFatPercentage: .percent()
        case .waistCircumference: .meterUnit(with: .centi)
        case .restingHeartRate: HKUnit.count().unitDivided(by: .minute())
        case .workout, .sleep: nil
        }
    }

    /// The set LifeBoard requests read access to. HealthKit intentionally hides
    /// read-denial, so this set is only used for the authorization request.
    public static func readTypes() -> Set<HKObjectType> {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        return Set(readableMetrics.compactMap(objectType(for:)))
    }

    /// The share (write) set. Share authorization *is* observable, so this drives
    /// the per-domain connection status the UI shows.
    public static func shareTypes() -> Set<HKSampleType> {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        return Set(writableMetrics.compactMap(sampleType(for:))).union(workoutAssociatedShareTypes)
    }

    public static func shareTypes(for domain: HealthDomain) -> Set<HKSampleType> {
        guard domain.supportsWriteBack, HKHealthStore.isHealthDataAvailable() else { return [] }
        var result = Set(domain.metrics.compactMap(sampleType(for:)))
        if domain == .workouts {
            result.formUnion(workoutAssociatedShareTypes)
        }
        return result
    }

    public static func writeAuthorizationMetrics(for domain: HealthDomain) -> [HealthMetric] {
        if domain == .workouts {
            return [.workout, .activeEnergy, .walkingRunningDistance]
        }
        return domain.supportsWriteBack ? domain.metrics : []
    }

    private static var workoutAssociatedShareTypes: Set<HKSampleType> {
        Set([
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        ].compactMap { $0 })
    }

    /// LifeBoard stores body fat as percentage points (for example `18.5`).
    /// HealthKit's percent unit stores a fraction (`0.185`).
    public static func healthKitValue(_ lifeBoardValue: Double, for metric: HealthMetric) -> Double {
        metric == .bodyFatPercentage ? lifeBoardValue / 100 : lifeBoardValue
    }

    public static func lifeBoardValue(_ healthKitValue: Double, for metric: HealthMetric) -> Double {
        metric == .bodyFatPercentage ? healthKitValue * 100 : healthKitValue
    }
}

public enum HealthWorkoutActivityMapper {
    public static func activityType(for name: String) -> HKWorkoutActivityType {
        switch name.lowercased() {
        case "run", "running": .running
        case "walk", "walking": .walking
        case "cycle", "cycling": .cycling
        case "swim", "swimming": .swimming
        case "hike", "hiking": .hiking
        case "yoga": .yoga
        case "dance": .dance
        case "strength", "strength training": .traditionalStrengthTraining
        default: .other
        }
    }

    public static func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .yoga: "Yoga"
        case .dance: "Dance"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Strength training"
        default: "Other"
        }
    }
}
