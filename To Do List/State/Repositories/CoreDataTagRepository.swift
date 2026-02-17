import Foundation
import CoreData

public final class CoreDataTagRepository: TagRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: TagMapper.entityName,
                    sort: [NSSortDescriptor(key: "sortOrder", ascending: true)]
                )
                completion(.success(objects.map(TagMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let normalized = tag.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let existing = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: TagMapper.entityName,
                    predicate: NSPredicate(format: "name =[c] %@", normalized)
                )
                let object: NSManagedObject
                if let existing {
                    object = existing
                } else {
                    object = try V2CoreDataRepositorySupport.upsertByID(
                        in: self.backgroundContext,
                        entityName: TagMapper.entityName,
                        id: tag.id
                    )
                }
                _ = TagMapper.apply(tag, to: object)
                try self.backgroundContext.save()
                completion(.success(TagMapper.toDomain(from: object)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                if let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: TagMapper.entityName,
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
