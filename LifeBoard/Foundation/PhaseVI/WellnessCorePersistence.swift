import CoreData
import Foundation

public final class CoreDataWellnessRepository: WellnessRepository, @unchecked Sendable {
    private let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    public func bodyMetricSamples(kind: BodyMetricKind?) async throws -> [BodyMetricSample] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "BodyMetricSample")
            if let kind { request.predicate = NSPredicate(format: "kindRaw == %@", kind.rawValue) }
            request.sortDescriptors = [
                NSSortDescriptor(key: "observedAt", ascending: false),
                NSSortDescriptor(key: "id", ascending: true)
            ]
            return try context.fetch(request).compactMap(Self.bodyMetric)
        }
    }

    public func workoutRecords() async throws -> [WorkoutRecord] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutRecord")
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.workout)
        }
    }

    public func sleepNotes() async throws -> [SleepNote] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "SleepNote")
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.sleep)
        }
    }

    public func movementRecords() async throws -> [MovementContextRecord] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "MovementContextRecord")
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.movement)
        }
    }

    public func save(_ value: BodyMetricSample) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "BodyMetricSample", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.kind.rawValue, forKey: "kindRaw")
            object.setValue(value.normalizedValue, forKey: "normalizedValue")
            object.setValue(value.displayUnit.rawValue, forKey: "displayUnitRaw")
            object.setValue(value.observedAt, forKey: "observedAt")
            object.setValue(value.capturedTimeZoneIdentifier, forKey: "capturedTimeZoneIdentifier")
            object.setValue(value.source.rawValue, forKey: "sourceRaw")
            object.setValue(value.sourceIdentifier, forKey: "sourceIdentifier")
            object.setValue(value.note, forKey: "note")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func save(_ value: WorkoutRecord) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "WorkoutRecord", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.activityKind, forKey: "activityKindRaw")
            object.setValue(value.startedAt, forKey: "startedAt")
            object.setValue(value.endedAt, forKey: "endedAt")
            object.setValue(value.energyKilocalories, forKey: "energyKilocalories")
            object.setValue(value.distanceMeters, forKey: "distanceMeters")
            object.setValue(value.source.rawValue, forKey: "sourceRaw")
            object.setValue(value.sourceIdentifier, forKey: "sourceIdentifier")
            object.setValue(value.note, forKey: "note")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func save(_ value: SleepNote) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "SleepNote", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.startedAt, forKey: "startedAt")
            object.setValue(value.endedAt, forKey: "endedAt")
            object.setValue(value.quality, forKey: "quality")
            object.setValue(value.note, forKey: "note")
            object.setValue(value.source.rawValue, forKey: "sourceRaw")
            object.setValue(value.sourceIdentifier, forKey: "sourceIdentifier")
            object.setValue(value.capturedTimeZoneIdentifier, forKey: "capturedTimeZoneIdentifier")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func save(_ value: MovementContextRecord) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "MovementContextRecord", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.startedAt, forKey: "startedAt")
            object.setValue(value.endedAt, forKey: "endedAt")
            object.setValue(value.steps, forKey: "steps")
            object.setValue(value.distanceMeters, forKey: "distanceMeters")
            object.setValue(value.activeEnergyKilocalories, forKey: "activeEnergyKilocalories")
            object.setValue(value.source.rawValue, forKey: "sourceRaw")
            object.setValue(value.sourceIdentifier, forKey: "sourceIdentifier")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func delete(kind: WellnessRecordKind, id: UUID) async throws {
        try await write { context in
            let entity = switch kind {
            case .bodyMetric: "BodyMetricSample"
            case .workout: "WorkoutRecord"
            case .sleep: "SleepNote"
            case .movement: "MovementContextRecord"
            }
            guard let object = try Self.fetchOne(entity: entity, id: id, in: context) else {
                throw WellnessRepositoryError.recordNotFound
            }
            context.delete(object)
        }
    }

    private func read<T: Sendable>(
        _ operation: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return try await context.perform { try operation(context) }
    }

    private func write(
        _ operation: @escaping @Sendable (NSManagedObjectContext) throws -> Void
    ) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        try await context.perform {
            try operation(context)
            if context.hasChanges { try context.save() }
        }
    }

    private static func fetchOne(
        entity: String,
        id: UUID,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func upsert(
        entity: String,
        id: UUID,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        if let value = try fetchOne(entity: entity, id: id, in: context) { return value }
        return NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    private static func bodyMetric(_ object: NSManagedObject) -> BodyMetricSample? {
        guard let id = object.value(forKey: "id") as? UUID,
              let kindRaw = object.value(forKey: "kindRaw") as? String,
              let kind = BodyMetricKind(rawValue: kindRaw),
              let normalized = (object.value(forKey: "normalizedValue") as? NSNumber)?.doubleValue,
              let observedAt = object.value(forKey: "observedAt") as? Date else { return nil }
        let displayUnit = (object.value(forKey: "displayUnitRaw") as? String)
            .flatMap(WellnessDisplayUnit.init(rawValue:)) ?? kind.canonicalUnit
        let displayValue: Double
        switch (kind, displayUnit) {
        case (.bodyMass, .pounds): displayValue = normalized * 2.204_622_621_8
        case (.waistCircumference, .inches): displayValue = normalized / 2.54
        default: displayValue = normalized
        }
        return try? BodyMetricSample(
            id: id,
            kind: kind,
            value: displayValue,
            unit: displayUnit,
            observedAt: observedAt,
            capturedTimeZone: Self.timeZone(object.value(forKey: "capturedTimeZoneIdentifier") as? String),
            source: (object.value(forKey: "sourceRaw") as? String).flatMap(WellnessCaptureSource.init(rawValue:)) ?? .manual,
            sourceIdentifier: object.value(forKey: "sourceIdentifier") as? String,
            note: object.value(forKey: "note") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? observedAt,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? observedAt
        )
    }

    private static func workout(_ object: NSManagedObject) -> WorkoutRecord? {
        guard let id = object.value(forKey: "id") as? UUID,
              let activity = object.value(forKey: "activityKindRaw") as? String,
              let startedAt = object.value(forKey: "startedAt") as? Date,
              let endedAt = object.value(forKey: "endedAt") as? Date else { return nil }
        return try? WorkoutRecord(
            id: id,
            activityKind: activity,
            startedAt: startedAt,
            endedAt: endedAt,
            energyKilocalories: (object.value(forKey: "energyKilocalories") as? NSNumber)?.doubleValue,
            distanceMeters: (object.value(forKey: "distanceMeters") as? NSNumber)?.doubleValue,
            source: (object.value(forKey: "sourceRaw") as? String).flatMap(WellnessCaptureSource.init(rawValue:)) ?? .manual,
            sourceIdentifier: object.value(forKey: "sourceIdentifier") as? String,
            note: object.value(forKey: "note") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? startedAt,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? endedAt
        )
    }

    private static func sleep(_ object: NSManagedObject) -> SleepNote? {
        guard let id = object.value(forKey: "id") as? UUID,
              let startedAt = object.value(forKey: "startedAt") as? Date,
              let endedAt = object.value(forKey: "endedAt") as? Date else { return nil }
        return try? SleepNote(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            quality: (object.value(forKey: "quality") as? NSNumber)?.intValue,
            note: object.value(forKey: "note") as? String,
            source: (object.value(forKey: "sourceRaw") as? String).flatMap(WellnessCaptureSource.init(rawValue:)) ?? .manual,
            sourceIdentifier: object.value(forKey: "sourceIdentifier") as? String,
            capturedTimeZone: Self.timeZone(object.value(forKey: "capturedTimeZoneIdentifier") as? String),
            createdAt: object.value(forKey: "createdAt") as? Date ?? startedAt,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? endedAt
        )
    }

    private static func movement(_ object: NSManagedObject) -> MovementContextRecord? {
        guard let id = object.value(forKey: "id") as? UUID,
              let startedAt = object.value(forKey: "startedAt") as? Date,
              let endedAt = object.value(forKey: "endedAt") as? Date else { return nil }
        return try? MovementContextRecord(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            steps: (object.value(forKey: "steps") as? NSNumber)?.intValue,
            distanceMeters: (object.value(forKey: "distanceMeters") as? NSNumber)?.doubleValue,
            activeEnergyKilocalories: (object.value(forKey: "activeEnergyKilocalories") as? NSNumber)?.doubleValue,
            source: (object.value(forKey: "sourceRaw") as? String).flatMap(WellnessCaptureSource.init(rawValue:)) ?? .manual,
            sourceIdentifier: object.value(forKey: "sourceIdentifier") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? startedAt,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? endedAt
        )
    }

    private static func timeZone(_ identifier: String?) -> TimeZone {
        identifier.flatMap(TimeZone.init(identifier:)) ?? .autoupdatingCurrent
    }
}
