import Foundation
import CoreData

struct V2CoreDataRepositorySupport {
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

    static func fetchObject(
        in context: NSManagedObjectContext,
        entityName: String,
        predicate: NSPredicate
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = 1
        request.predicate = predicate
        return try context.fetch(request).first
    }

    static func upsertByID(
        in context: NSManagedObjectContext,
        entityName: String,
        id: UUID
    ) throws -> NSManagedObject {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let existing = try fetchObject(in: context, entityName: entityName, predicate: predicate) {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }
}
