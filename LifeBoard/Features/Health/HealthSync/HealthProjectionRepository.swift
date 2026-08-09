@preconcurrency import CoreData
import Foundation
import HealthKit

public protocol HealthProjectionRepository: Sendable {
    func reconcileImportedSample(
        _ sample: HealthSampleEnvelope,
        existing: HealthSyncCorrespondence?
    ) async throws -> UUID?
    func deleteImportedProjection(localID: UUID, metric: HealthMetric) async throws
}

public actor CoreDataHealthProjectionRepository: HealthProjectionRepository {
    private let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    public func reconcileImportedSample(
        _ sample: HealthSampleEnvelope,
        existing: HealthSyncCorrespondence?
    ) async throws -> UUID? {
        let context = container.newBackgroundContext()
        context.transactionAuthor = "HealthKitImport"
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return try await context.perform {
            let localID = existing?.localID ?? UUID()
            switch (sample.metric, sample.value) {
            case (.water, .quantity(let milliliters)):
                let object = try Self.upsert(entity: "HydrationLog", id: localID, in: context)
                object.setValue(localID, forKey: "id")
                object.setValue(max(0, milliliters), forKey: "amount")
                object.setValue(HydrationUnit.milliliters.rawValue, forKey: "unitRaw")
                object.setValue(sample.endDate, forKey: "timestamp")
                object.setValue(WellnessCaptureSource.healthKit.rawValue, forKey: "sourceRaw")
                object.setValue(sample.id.uuidString, forKey: "sourceIdentifier")
                object.setValue(Self.timeZoneIdentifier(from: sample), forKey: "capturedTimeZoneIdentifier")
                object.setValue(existing?.recordedAt ?? Date(), forKey: "createdAt")
                object.setValue(Date(), forKey: "updatedAt")

            case (.bodyMass, .quantity(let value)),
                 (.bodyFatPercentage, .quantity(let value)),
                 (.waistCircumference, .quantity(let value)),
                 (.restingHeartRate, .quantity(let value)):
                let object = try Self.upsert(entity: "BodyMetricSample", id: localID, in: context)
                object.setValue(localID, forKey: "id")
                object.setValue(Self.bodyKind(for: sample.metric)?.rawValue, forKey: "kindRaw")
                object.setValue(value, forKey: "normalizedValue")
                object.setValue(Self.bodyKind(for: sample.metric)?.canonicalUnit.rawValue, forKey: "displayUnitRaw")
                object.setValue(sample.endDate, forKey: "observedAt")
                object.setValue(Self.timeZoneIdentifier(from: sample), forKey: "capturedTimeZoneIdentifier")
                object.setValue(WellnessCaptureSource.healthKit.rawValue, forKey: "sourceRaw")
                object.setValue(sample.id.uuidString, forKey: "sourceIdentifier")
                object.setValue(existing?.recordedAt ?? Date(), forKey: "createdAt")
                object.setValue(Date(), forKey: "updatedAt")

            case (.workout, .workout(let workout)):
                let object = try Self.upsert(entity: "WorkoutRecord", id: localID, in: context)
                object.setValue(localID, forKey: "id")
                object.setValue(workout.activityName, forKey: "activityKindRaw")
                object.setValue(sample.startDate, forKey: "startedAt")
                object.setValue(sample.endDate, forKey: "endedAt")
                object.setValue(workout.energyKilocalories, forKey: "energyKilocalories")
                object.setValue(workout.distanceMeters, forKey: "distanceMeters")
                object.setValue(Self.timeZoneIdentifier(from: sample), forKey: "capturedTimeZoneIdentifier")
                object.setValue(WellnessCaptureSource.healthKit.rawValue, forKey: "sourceRaw")
                object.setValue(sample.id.uuidString, forKey: "sourceIdentifier")
                object.setValue(existing?.recordedAt ?? Date(), forKey: "createdAt")
                object.setValue(Date(), forKey: "updatedAt")

            case (.sleep, .category(let stage)):
                let object = try Self.upsert(entity: "SleepNote", id: localID, in: context)
                object.setValue(localID, forKey: "id")
                object.setValue(sample.startDate, forKey: "startedAt")
                object.setValue(sample.endDate, forKey: "endedAt")
                object.setValue(WellnessCaptureSource.healthKit.rawValue, forKey: "sourceRaw")
                object.setValue(sample.id.uuidString, forKey: "sourceIdentifier")
                object.setValue(stage, forKey: "healthStageValue")
                object.setValue(try JSONEncoder().encode(sample.metadata), forKey: "healthMetadataData")
                object.setValue(Self.timeZoneIdentifier(from: sample), forKey: "capturedTimeZoneIdentifier")
                object.setValue(existing?.recordedAt ?? Date(), forKey: "createdAt")
                object.setValue(Date(), forKey: "updatedAt")

            default:
                return nil
            }
            if context.hasChanges {
                try context.save()
            }
            return localID
        }
    }

    public func deleteImportedProjection(localID: UUID, metric: HealthMetric) async throws {
        guard let entity = Self.entity(for: metric) else { return }
        let context = container.newBackgroundContext()
        context.transactionAuthor = "HealthKitImport"
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "id == %@", localID as CVarArg),
                NSPredicate(format: "sourceRaw == %@", WellnessCaptureSource.healthKit.rawValue)
            ])
            request.affectedStores = Self.localStores(in: self.container)
            try context.fetch(request).forEach(context.delete)
            if context.hasChanges {
                try context.save()
            }
        }
    }

    private static func upsert(
        entity: String,
        id: UUID,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        request.affectedStores = localStores(in: context.persistentStoreCoordinator)
        if let existing = try context.fetch(request).first {
            return existing
        }
        let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
        if let store = localStores(in: context.persistentStoreCoordinator).first {
            context.assign(object, to: store)
        }
        return object
    }

    private static func localStores(in container: NSPersistentContainer) -> [NSPersistentStore] {
        localStores(in: container.persistentStoreCoordinator)
    }

    private static func localStores(in coordinator: NSPersistentStoreCoordinator?) -> [NSPersistentStore] {
        coordinator?.persistentStores.filter { $0.configurationName == "LocalOnly" } ?? []
    }

    private static func entity(for metric: HealthMetric) -> String? {
        switch metric {
        case .water: "HydrationLog"
        case .bodyMass, .bodyFatPercentage, .waistCircumference, .restingHeartRate: "BodyMetricSample"
        case .workout: "WorkoutRecord"
        case .sleep: "SleepNote"
        default: nil
        }
    }

    private static func bodyKind(for metric: HealthMetric) -> BodyMetricKind? {
        switch metric {
        case .bodyMass: .bodyMass
        case .bodyFatPercentage: .bodyFatPercentage
        case .waistCircumference: .waistCircumference
        case .restingHeartRate: .restingHeartRate
        default: nil
        }
    }

    private static func timeZoneIdentifier(from sample: HealthSampleEnvelope) -> String {
        sample.metadata[HKMetadataKeyTimeZone] ?? TimeZone.autoupdatingCurrent.identifier
    }
}
