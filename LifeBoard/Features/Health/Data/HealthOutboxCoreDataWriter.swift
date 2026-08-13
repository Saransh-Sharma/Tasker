import CoreData
import Foundation

enum HealthOutboxCoreDataWriter {
    static func enqueue(
        payloads: [HealthWritePayload],
        kind: HealthSyncOperationKind,
        in context: NSManagedObjectContext
    ) throws {
        guard V2FeatureFlags.healthIntegrationsV1Enabled,
              V2FeatureFlags.healthWriteBackV1Enabled,
              context.transactionAuthor != "HealthKitImport" else {
            return
        }
        for payload in payloads {
            guard try writeEnabled(for: payload.metric.domain, in: context) else { continue }
            let version = try nextVersion(for: payload, in: context)
            let operation = HealthSyncOperation(
                localID: payload.localID,
                metric: payload.metric,
                role: payload.role,
                kind: kind,
                payload: kind == .delete ? nil : payload,
                syncVersion: version
            )
            try insert(operation, in: context)
        }
    }

    private static func writeEnabled(
        for domain: HealthDomain,
        in context: NSManagedObjectContext
    ) throws -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HealthSyncPreference")
        request.affectedStores = localStores(in: context)
        request.predicate = NSPredicate(format: "domainRaw == %@", domain.rawValue)
        request.fetchLimit = 1
        return try context.fetch(request).first?.value(forKey: "writeEnabled") as? Bool ?? false
    }

    private static func nextVersion(
        for payload: HealthWritePayload,
        in context: NSManagedObjectContext
    ) throws -> Int64 {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HealthSyncVersion")
        request.affectedStores = localStores(in: context)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "localID == %@", payload.localID as CVarArg),
            NSPredicate(format: "metricRaw == %@", payload.metric.rawValue),
            NSPredicate(format: "roleRaw == %@", payload.role)
        ])
        request.fetchLimit = 1
        let object = try context.fetch(request).first ?? inserted(
            entity: "HealthSyncVersion",
            in: context
        )
        let current = (object.value(forKey: "version") as? NSNumber)?.int64Value ?? 0
        let next = current == Int64.max ? Int64.max : current + 1
        object.setValue(payload.localID, forKey: "localID")
        object.setValue(payload.metric.rawValue, forKey: "metricRaw")
        object.setValue(payload.role, forKey: "roleRaw")
        object.setValue(next, forKey: "version")
        object.setValue(Date(), forKey: "updatedAt")
        return next
    }

    private static func insert(
        _ operation: HealthSyncOperation,
        in context: NSManagedObjectContext
    ) throws {
        let object = inserted(entity: "HealthSyncOperation", in: context)
        object.setValue(operation.id, forKey: "id")
        object.setValue(operation.localID, forKey: "localID")
        object.setValue(operation.metric.rawValue, forKey: "metricRaw")
        object.setValue(operation.role, forKey: "roleRaw")
        object.setValue(operation.kind.rawValue, forKey: "kindRaw")
        object.setValue(operation.state.rawValue, forKey: "stateRaw")
        object.setValue(try operation.payload.map { try JSONEncoder().encode($0) }, forKey: "payloadData")
        object.setValue(operation.syncVersion, forKey: "syncVersion")
        object.setValue(operation.attemptCount, forKey: "attemptCount")
        object.setValue(operation.nextAttemptAt, forKey: "nextAttemptAt")
        object.setValue(operation.lastErrorCode, forKey: "lastErrorCode")
        object.setValue(operation.createdAt, forKey: "createdAt")
        object.setValue(operation.updatedAt, forKey: "updatedAt")
    }

    private static func inserted(
        entity: String,
        in context: NSManagedObjectContext
    ) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
        if let store = localStores(in: context).first {
            context.assign(object, to: store)
        }
        return object
    }

    private static func localStores(in context: NSManagedObjectContext) -> [NSPersistentStore] {
        context.persistentStoreCoordinator?.persistentStores.filter {
            $0.configurationName == "LocalOnly"
        } ?? []
    }
}
