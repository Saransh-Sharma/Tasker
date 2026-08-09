@preconcurrency import CoreData
import CryptoKit
import Foundation

public enum HealthPrivacyMigrationAccess {
    public enum AccessError: LocalizedError {
        case writeClosed

        public var errorDescription: String? {
            "Health and wellness records are temporarily read-only while their private local copy is validated."
        }
    }

    public static func requireValidated(in context: NSManagedObjectContext) throws {
        guard V2FeatureFlags.healthIntegrationsV1Enabled else { return }
        guard let local = context.persistentStoreCoordinator?.persistentStores.first(where: {
            $0.configurationName == "LocalOnly"
        }) else {
            throw AccessError.writeClosed
        }
        // A model without the checkpoint entity predates the health privacy
        // migration. `NSFetchRequest` raises an ObjC exception for an unknown
        // entity name — uncatchable from Swift — so an older store would crash
        // the app here rather than degrade. Refusing the write is the same
        // answer this gate gives whenever it cannot confirm the private copy.
        guard context.persistentStoreCoordinator?
            .managedObjectModel
            .entitiesByName["HealthMigrationCheckpoint"] != nil else {
            throw AccessError.writeClosed
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: "HealthMigrationCheckpoint")
        request.affectedStores = [local]
        request.predicate = NSPredicate(format: "id == %@ AND phaseRaw == %@", "overall", "validated")
        request.fetchLimit = 1
        guard try context.fetch(request).isEmpty == false else {
            throw AccessError.writeClosed
        }
    }
}

public actor HealthPrivacyMigrationCoordinator {
    public enum State: Equatable, Sendable {
        case notNeeded
        case copying(entity: String)
        case validated
        case deferred
    }

    public static let affectedEntities = [
        "MoodEnergyCheckIn",
        "MedicationDefinition",
        "MedicationSchedule",
        "MedicationEvent",
        "FastingSession",
        "BodyMetricSample",
        "WorkoutRecord",
        "SleepNote",
        "MovementContextRecord",
        "FoodItem",
        "NutritionLogEntry",
        "NutritionGoal",
        "HydrationLog",
        "HydrationTarget",
        "SleepContextRecord"
    ]

    private let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    /// Release A copy: additive, idempotent, and checkpointed per entity. No
    /// personal values are logged or included in the digest; validation uses
    /// stable identifiers only.
    public func migrate() async throws -> State {
        guard let cloud = store(configuration: "CloudSync"),
              let local = store(configuration: "LocalOnly") else {
            return .deferred
        }

        let context = container.newBackgroundContext()
        context.transactionAuthor = "HealthPrivacyMigration"
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        for entity in Self.affectedEntities {
            let result = try await context.perform {
                try Self.copyAndValidate(entity: entity, cloud: cloud, local: local, context: context)
            }
            guard result else { return .copying(entity: entity) }
        }

        let relationshipsValid = try await context.perform {
            try Self.copyRelationships(cloud: cloud, local: local, context: context)
            return try Self.validateRelationships(cloud: cloud, local: local, context: context)
        }
        guard relationshipsValid else { return .copying(entity: "relationships") }

        try await context.perform {
            try Self.writeOverallCheckpoint(in: context)
            if context.hasChanges {
                try context.save()
            }
        }
        return .validated
    }

    /// Release A cleanup entry point. Call only after the upgrade window and
    /// after every entity checkpoint still validates. Deleting from the cloud
    /// store lets NSPersistentCloudKitContainer export the tombstones.
    public func purgeLegacyCloudRowsIfEligible(
        now: Date = Date(),
        upgradeWindow: TimeInterval = 30 * 24 * 60 * 60
    ) async throws -> Bool {
        guard let cloud = store(configuration: "CloudSync"),
              let local = store(configuration: "LocalOnly") else {
            return false
        }
        let context = container.newBackgroundContext()
        context.transactionAuthor = "HealthPrivacyCloudPurge"
        return try await context.perform {
            guard let checkpoint = try Self.checkpoint(id: "overall", store: local, context: context),
                  let completedAt = checkpoint.value(forKey: "completedAt") as? Date,
                  now.timeIntervalSince(completedAt) >= upgradeWindow else {
                return false
            }
            for entity in Self.affectedEntities {
                guard try Self.identifiers(entity: entity, store: cloud, context: context)
                    == Self.identifiers(entity: entity, store: local, context: context) else {
                    return false
                }
            }
            for entity in Self.affectedEntities {
                let request = NSFetchRequest<NSManagedObject>(entityName: entity)
                request.affectedStores = [cloud]
                try context.fetch(request).forEach(context.delete)
            }
            try context.save()
            return true
        }
    }

    private func store(configuration: String) -> NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores.first {
            $0.configurationName == configuration
        }
    }

    private static func copyAndValidate(
        entity: String,
        cloud: NSPersistentStore,
        local: NSPersistentStore,
        context: NSManagedObjectContext
    ) throws -> Bool {
        let sourceIDs = try identifiers(entity: entity, store: cloud, context: context)
        let existingIDs = try identifiers(entity: entity, store: local, context: context)
        if sourceIDs.isSubset(of: existingIDs) == false {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.affectedStores = [cloud]
            request.fetchBatchSize = 100
            for source in try context.fetch(request) {
                guard let stableID = stableIdentifier(for: source) else { continue }
                let destination = try fetch(
                    entity: entity,
                    stableID: stableID,
                    store: local,
                    context: context
                ) ?? NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
                if destination.objectID.isTemporaryID {
                    context.assign(destination, to: local)
                }
                for attributeName in source.entity.attributesByName.keys {
                    destination.setValue(source.value(forKey: attributeName), forKey: attributeName)
                }
            }
            if context.hasChanges {
                try context.save()
            }
        }

        let destinationIDs = try identifiers(entity: entity, store: local, context: context)
        let valid = sourceIDs.isSubset(of: destinationIDs)
        let checkpoint = try upsertCheckpoint(id: "copy.\(entity)", store: local, context: context)
        checkpoint.setValue(valid ? "validated" : "copying", forKey: "phaseRaw")
        checkpoint.setValue(Int64(sourceIDs.count), forKey: "sourceCount")
        checkpoint.setValue(Int64(destinationIDs.count), forKey: "destinationCount")
        checkpoint.setValue(digest(sourceIDs), forKey: "sourceDigest")
        checkpoint.setValue(digest(destinationIDs.intersection(sourceIDs)), forKey: "destinationDigest")
        checkpoint.setValue(valid ? Date() : nil, forKey: "completedAt")
        checkpoint.setValue(Date(), forKey: "updatedAt")
        try context.save()
        return valid
    }

    private static func identifiers(
        entity: String,
        store: NSPersistentStore,
        context: NSManagedObjectContext
    ) throws -> Set<String> {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.affectedStores = [store]
        request.includesPropertyValues = true
        return Set(try context.fetch(request).compactMap(stableIdentifier(for:)))
    }

    private static func copyRelationships(
        cloud: NSPersistentStore,
        local: NSPersistentStore,
        context: NSManagedObjectContext
    ) throws {
        for entityName in affectedEntities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.affectedStores = [cloud]
            for source in try context.fetch(request) {
                guard let sourceID = stableIdentifier(for: source),
                      let destination = try fetch(
                        entity: entityName,
                        stableID: sourceID,
                        store: local,
                        context: context
                      ) else {
                    continue
                }
                for (name, relationship) in source.entity.relationshipsByName {
                    guard let targetEntity = relationship.destinationEntity?.name,
                          affectedEntities.contains(targetEntity) else {
                        continue
                    }
                    if relationship.isToMany {
                        let sourceObjects: [NSManagedObject]
                        if relationship.isOrdered {
                            sourceObjects = (source.value(forKey: name) as? NSOrderedSet)?
                                .array.compactMap { $0 as? NSManagedObject } ?? []
                        } else {
                            sourceObjects = (source.value(forKey: name) as? Set<NSManagedObject>).map(Array.init)
                                ?? (source.value(forKey: name) as? NSSet)?.allObjects.compactMap { $0 as? NSManagedObject }
                                ?? []
                        }
                        let localObjects = try sourceObjects.compactMap { related -> NSManagedObject? in
                            guard let relatedID = stableIdentifier(for: related) else { return nil }
                            return try fetch(
                                entity: targetEntity,
                                stableID: relatedID,
                                store: local,
                                context: context
                            )
                        }
                        destination.setValue(
                            relationship.isOrdered ? NSOrderedSet(array: localObjects) : NSSet(array: localObjects),
                            forKey: name
                        )
                    } else if let related = source.value(forKey: name) as? NSManagedObject,
                              let relatedID = stableIdentifier(for: related) {
                        destination.setValue(
                            try fetch(
                                entity: targetEntity,
                                stableID: relatedID,
                                store: local,
                                context: context
                            ),
                            forKey: name
                        )
                    } else {
                        destination.setValue(nil, forKey: name)
                    }
                }
            }
        }
        if context.hasChanges {
            try context.save()
        }
    }

    private static func validateRelationships(
        cloud: NSPersistentStore,
        local: NSPersistentStore,
        context: NSManagedObjectContext
    ) throws -> Bool {
        for entity in affectedEntities {
            let source = try relationshipSignatures(entity: entity, store: cloud, context: context)
            let destination = try relationshipSignatures(entity: entity, store: local, context: context)
            guard source.isSubset(of: destination) else { return false }
        }
        return true
    }

    private static func relationshipSignatures(
        entity: String,
        store: NSPersistentStore,
        context: NSManagedObjectContext
    ) throws -> Set<String> {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.affectedStores = [store]
        var signatures = Set<String>()
        for object in try context.fetch(request) {
            guard let sourceID = stableIdentifier(for: object) else { continue }
            for (name, relationship) in object.entity.relationshipsByName {
                guard let targetEntity = relationship.destinationEntity?.name,
                      affectedEntities.contains(targetEntity) else {
                    continue
                }
                let targetIDs: [String]
                if relationship.isToMany {
                    let related = relationship.isOrdered
                        ? (object.value(forKey: name) as? NSOrderedSet)?.array ?? []
                        : (object.value(forKey: name) as? NSSet)?.allObjects ?? []
                    targetIDs = related.compactMap { ($0 as? NSManagedObject).flatMap(stableIdentifier(for:)) }
                } else {
                    targetIDs = (object.value(forKey: name) as? NSManagedObject)
                        .flatMap(stableIdentifier(for:))
                        .map { [$0] } ?? []
                }
                signatures.insert("\(sourceID)|\(name)|\(targetIDs.sorted().joined(separator: ","))")
            }
        }
        return signatures
    }

    private static func stableIdentifier(for object: NSManagedObject) -> String? {
        if let id = object.value(forKey: "id") as? UUID {
            return id.uuidString.lowercased()
        }
        if let id = object.value(forKey: "id") as? String {
            return id
        }
        return nil
    }

    private static func fetch(
        entity: String,
        stableID: String,
        store: NSPersistentStore,
        context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.affectedStores = [store]
        if let uuid = UUID(uuidString: stableID) {
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "id == %@", stableID)
        }
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func digest(_ values: Set<String>) -> String {
        SHA256.hash(data: Data(values.sorted().joined(separator: "\n").utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func checkpoint(
        id: String,
        store: NSPersistentStore,
        context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HealthMigrationCheckpoint")
        request.affectedStores = [store]
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func upsertCheckpoint(
        id: String,
        store: NSPersistentStore,
        context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        if let value = try checkpoint(id: id, store: store, context: context) {
            return value
        }
        let object = NSEntityDescription.insertNewObject(
            forEntityName: "HealthMigrationCheckpoint",
            into: context
        )
        context.assign(object, to: store)
        object.setValue(id, forKey: "id")
        return object
    }

    private static func writeOverallCheckpoint(in context: NSManagedObjectContext) throws {
        guard let local = context.persistentStoreCoordinator?.persistentStores.first(where: {
            $0.configurationName == "LocalOnly"
        }) else { return }
        let checkpoint = try upsertCheckpoint(id: "overall", store: local, context: context)
        checkpoint.setValue("validated", forKey: "phaseRaw")
        checkpoint.setValue(Date(), forKey: "completedAt")
        checkpoint.setValue(Date(), forKey: "updatedAt")
    }
}
