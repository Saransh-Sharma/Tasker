import Foundation
import CoreData

struct V2CoreDataRepositorySupport {
    private enum DuplicateResolutionPolicy {
        case observeOnly
        case deleteDuplicates
    }

    private final class ObservedDuplicateLogLimiter: @unchecked Sendable {
        private var emittedKeys: Set<String> = []
        private let lock = NSLock()

        func shouldLog(key: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return emittedKeys.insert(key).inserted
        }
    }

    private static let observedDuplicateLogLimiter = ObservedDuplicateLogLimiter()

    /// Executes requireID.
    static func requireID(_ id: UUID, field: String) throws -> UUID {
        let invalid = UUID(uuidString: "00000000-0000-0000-0000-000000000000")
        guard id != invalid else {
            throw NSError(
                domain: "V2CoreDataRepositorySupport",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "\(field) cannot be nil/zero UUID"]
            )
        }
        return id
    }

    /// Executes requireStoredID.
    static func requireStoredID(_ value: Any?, field: String) throws -> UUID {
        guard let id = value as? UUID else {
            throw NSError(
                domain: "V2CoreDataRepositorySupport",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "\(field) cannot be nil/zero UUID"]
            )
        }
        return try requireID(id, field: field)
    }

    /// Executes requireNonEmpty.
    static func requireNonEmpty(_ value: String, field: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw NSError(
                domain: "V2CoreDataRepositorySupport",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "\(field) cannot be empty"]
            )
        }
        return trimmed
    }

    /// Executes requireStoredNonEmpty.
    static func requireStoredNonEmpty(_ value: Any?, field: String) throws -> String {
        guard let string = value as? String else {
            throw NSError(
                domain: "V2CoreDataRepositorySupport",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "\(field) cannot be empty"]
            )
        }
        return try requireNonEmpty(string, field: field)
    }

    static func normalizedIdentityString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Executes compositeKey.
    static func compositeKey(_ components: [String]) -> String {
        components
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }

    /// Executes ensureNoNilIDs.
    static func ensureNoNilIDs(_ ids: [UUID?], context: String) throws {
        guard ids.allSatisfy({ $0 != nil }) else {
            throw NSError(
                domain: "V2CoreDataRepositorySupport",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Nil identifier provided for \(context)"]
            )
        }
    }

    /// Executes fetchObjects.
    static func fetchObjects(
        in context: NSManagedObjectContext,
        entityName: String,
        predicate: NSPredicate? = nil,
        sort: [NSSortDescriptor] = []
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sort
        return try context.fetch(request)
    }

    /// Fetches matching rows in deterministic order without mutating duplicates.
    @discardableResult
    static func canonicalReadObject(
        in context: NSManagedObjectContext,
        entityName: String,
        predicate: NSPredicate,
        sort: [NSSortDescriptor] = [NSSortDescriptor(key: "id", ascending: true)],
        createIfMissing: Bool = false
    ) throws -> NSManagedObject? {
        try canonicalObject(
            in: context,
            entityName: entityName,
            predicate: predicate,
            sort: sort,
            createIfMissing: createIfMissing,
            duplicateResolutionPolicy: .observeOnly
        )
    }

    /// Fetches matching rows in deterministic order and deletes duplicate rows.
    @discardableResult
    static func canonicalWriteRepairObject(
        in context: NSManagedObjectContext,
        entityName: String,
        predicate: NSPredicate,
        sort: [NSSortDescriptor] = [NSSortDescriptor(key: "id", ascending: true)],
        createIfMissing: Bool = false
    ) throws -> NSManagedObject? {
        try canonicalObject(
            in: context,
            entityName: entityName,
            predicate: predicate,
            sort: sort,
            createIfMissing: createIfMissing,
            duplicateResolutionPolicy: .deleteDuplicates
        )
    }

    /// Fetches matching rows in deterministic order, keeping the first row as canonical.
    /// Duplicate deletion must be requested explicitly from write-boundary repair flows.
    @discardableResult
    private static func canonicalObject(
        in context: NSManagedObjectContext,
        entityName: String,
        predicate: NSPredicate,
        sort: [NSSortDescriptor] = [NSSortDescriptor(key: "id", ascending: true)],
        createIfMissing: Bool = false,
        duplicateResolutionPolicy: DuplicateResolutionPolicy = .observeOnly
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sort
        let matches = try context.fetch(request)

        if let first = matches.first {
            let duplicates = Array(matches.dropFirst())
            if duplicates.isEmpty == false {
                logDuplicateRows(
                    policy: duplicateResolutionPolicy,
                    entityName: entityName,
                    predicate: predicate,
                    canonicalObject: first,
                    duplicateCount: duplicates.count
                )
            }
            if duplicateResolutionPolicy == .deleteDuplicates {
                for duplicate in duplicates {
                    context.delete(duplicate)
                }
            }
            return first
        }

        if createIfMissing {
            return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        }
        return nil
    }

    private static func logDuplicateRows(
        policy: DuplicateResolutionPolicy,
        entityName: String,
        predicate: NSPredicate,
        canonicalObject: NSManagedObject,
        duplicateCount: Int
    ) {
        let canonicalObjectID = canonicalObject.objectID.uriRepresentation().absoluteString
        if policy == .observeOnly {
            let key = [
                entityName,
                predicate.description,
                canonicalObjectID,
                String(duplicateCount)
            ].joined(separator: "|")
            guard observedDuplicateLogLimiter.shouldLog(key: key) else { return }
        }

        logWarning(
            event: policy == .deleteDuplicates
                ? "core_data_duplicate_rows_repaired"
                : "core_data_duplicate_rows_observed",
            message: policy == .deleteDuplicates
                ? "Repaired duplicate Core Data rows during canonical object lookup"
                : "Observed duplicate Core Data rows during canonical object lookup",
            component: "V2CoreDataRepositorySupport",
            fields: [
                "entity": entityName,
                "canonical_object_id": canonicalObjectID,
                "duplicate_count": String(duplicateCount),
                "duplicate_resolution_policy": policy == .deleteDuplicates ? "delete" : "observe"
            ]
        )
    }

    /// Executes fetchObject.
    static func fetchObject(
        in context: NSManagedObjectContext,
        entityName: String,
        predicate: NSPredicate,
        sort: [NSSortDescriptor] = [NSSortDescriptor(key: "id", ascending: true)]
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = 1
        request.predicate = predicate
        request.sortDescriptors = sort
        return try context.fetch(request).first
    }

    /// Executes upsertByPredicate.
    static func upsertByPredicate(
        in context: NSManagedObjectContext,
        entityName: String,
        predicate: NSPredicate,
        sort: [NSSortDescriptor] = [NSSortDescriptor(key: "id", ascending: true)]
    ) throws -> NSManagedObject {
        if let existing = try canonicalWriteRepairObject(
            in: context,
            entityName: entityName,
            predicate: predicate,
            sort: sort
        ) {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }

    /// Executes upsertByID.
    static func upsertByID(
        in context: NSManagedObjectContext,
        entityName: String,
        id: UUID
    ) throws -> NSManagedObject {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let existing = try canonicalWriteRepairObject(
            in: context,
            entityName: entityName,
            predicate: predicate,
            sort: repairSortDescriptors(for: entityName, in: context)
        ) {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }

    private static func repairSortDescriptors(
        for entityName: String,
        in context: NSManagedObjectContext
    ) -> [NSSortDescriptor] {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            return [NSSortDescriptor(key: "id", ascending: true)]
        }

        var descriptors: [NSSortDescriptor] = []
        if entity.attributesByName["updatedAt"] != nil {
            descriptors.append(NSSortDescriptor(key: "updatedAt", ascending: false))
        }
        if entity.attributesByName["createdAt"] != nil {
            descriptors.append(NSSortDescriptor(key: "createdAt", ascending: true))
        }
        if entity.attributesByName["id"] != nil {
            descriptors.append(NSSortDescriptor(key: "id", ascending: true))
        }
        return descriptors
    }
}
