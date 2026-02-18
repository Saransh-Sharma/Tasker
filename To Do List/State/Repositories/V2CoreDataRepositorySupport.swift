import Foundation
import CoreData

struct V2CoreDataRepositorySupport {
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

    static func compositeKey(_ components: [String]) -> String {
        components
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }

    static func ensureNoNilIDs(_ ids: [UUID?], context: String) throws {
        guard ids.allSatisfy({ $0 != nil }) else {
            throw NSError(
                domain: "V2CoreDataRepositorySupport",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Nil identifier provided for \(context)"]
            )
        }
    }

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

    /// Fetches matching rows in deterministic order and prunes duplicates,
    /// keeping the first row as canonical.
    @discardableResult
    static func canonicalObject(
        in context: NSManagedObjectContext,
        entityName: String,
        predicate: NSPredicate,
        sort: [NSSortDescriptor] = [NSSortDescriptor(key: "id", ascending: true)],
        createIfMissing: Bool = false
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sort
        let matches = try context.fetch(request)

        if let first = matches.first {
            for duplicate in matches.dropFirst() {
                context.delete(duplicate)
            }
            return first
        }

        if createIfMissing {
            return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        }
        return nil
    }

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

    static func upsertByPredicate(
        in context: NSManagedObjectContext,
        entityName: String,
        predicate: NSPredicate,
        sort: [NSSortDescriptor] = [NSSortDescriptor(key: "id", ascending: true)]
    ) throws -> NSManagedObject {
        if let existing = try canonicalObject(
            in: context,
            entityName: entityName,
            predicate: predicate,
            sort: sort
        ) {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }

    static func upsertByID(
        in context: NSManagedObjectContext,
        entityName: String,
        id: UUID
    ) throws -> NSManagedObject {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let existing = try canonicalObject(
            in: context,
            entityName: entityName,
            predicate: predicate,
            sort: [NSSortDescriptor(key: "id", ascending: true)]
        ) {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }
}
