import Foundation
import CoreData

public final class CoreDataTagRepository: TagRepositoryProtocol, @unchecked Sendable {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchAll.
    public func fetchAll(completion: @escaping @Sendable (Result<[TagDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "Tag",
                    sort: [
                        NSSortDescriptor(key: "sortOrder", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                let mapped = objects.map { object in
                    TagDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        name: object.value(forKey: "name") as? String ?? "Tag",
                        color: object.value(forKey: "color") as? String,
                        icon: object.value(forKey: "icon") as? String,
                        sortOrder: Int(object.value(forKey: "sortOrder") as? Int32 ?? 0),
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                    )
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes create.
    public func create(_ tag: TagDefinition, completion: @escaping @Sendable (Result<TagDefinition, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(tag.id, field: "tag.id")
                let normalized = try V2CoreDataRepositorySupport.requireNonEmpty(tag.name, field: "tag.name")
                let existing = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "Tag",
                    predicate: NSPredicate(format: "name =[c] %@", normalized),
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                if let existing {
                    if (existing.value(forKey: "color") as? String)?.isEmpty != false {
                        existing.setValue(tag.color, forKey: "color")
                    }
                    if (existing.value(forKey: "icon") as? String)?.isEmpty != false {
                        existing.setValue(tag.icon, forKey: "icon")
                    }
                    if (existing.value(forKey: "sortOrder") as? Int32 ?? 0) == 0 {
                        existing.setValue(Int32(tag.sortOrder), forKey: "sortOrder")
                    }
                    if existing.value(forKey: "createdAt") == nil {
                        existing.setValue(tag.createdAt, forKey: "createdAt")
                    }
                    try self.backgroundContext.save()
                    let mapped = TagDefinition(
                        id: existing.value(forKey: "id") as? UUID ?? tag.id,
                        name: existing.value(forKey: "name") as? String ?? normalized,
                        color: existing.value(forKey: "color") as? String,
                        icon: existing.value(forKey: "icon") as? String,
                        sortOrder: Int(existing.value(forKey: "sortOrder") as? Int32 ?? 0),
                        createdAt: existing.value(forKey: "createdAt") as? Date ?? tag.createdAt
                    )
                    completion(.success(mapped))
                } else {
                    let object = try V2CoreDataRepositorySupport.upsertByID(
                        in: self.backgroundContext,
                        entityName: "Tag",
                        id: tag.id
                    )
                    object.setValue(tag.id, forKey: "id")
                    object.setValue(normalized, forKey: "name")
                    object.setValue(tag.color, forKey: "color")
                    object.setValue(tag.icon, forKey: "icon")
                    object.setValue(Int32(tag.sortOrder), forKey: "sortOrder")
                    object.setValue(tag.createdAt, forKey: "createdAt")
                    try self.backgroundContext.save()
                    completion(.success(TagDefinition(
                        id: tag.id,
                        name: normalized,
                        color: tag.color,
                        icon: tag.icon,
                        sortOrder: tag.sortOrder,
                        createdAt: tag.createdAt
                    )))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes delete.
    public func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "tag.id")
                if let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: "Tag",
                    predicate: NSPredicate(format: "id == %@", id as CVarArg)
                ) {
                    self.backgroundContext.delete(object)
                    try self.backgroundContext.save()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
