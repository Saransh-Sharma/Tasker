import Foundation
import CoreData

public final class CoreDataTombstoneRepository: TombstoneRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
    }

    /// Executes create.
    public func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(tombstone.id, field: "tombstone.id")
                _ = try V2CoreDataRepositorySupport.requireID(tombstone.entityID, field: "tombstone.entityID")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(tombstone.entityType, field: "tombstone.entityType")
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: TombstoneMapper.entityName,
                    id: tombstone.id
                )
                _ = TombstoneMapper.apply(tombstone, to: object)
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchExpired.
    public func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: TombstoneMapper.entityName,
                    predicate: NSPredicate(format: "purgeAfter <= %@", date as NSDate),
                    sort: [
                        NSSortDescriptor(key: "purgeAfter", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                completion(.success(objects.map(TombstoneMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes delete.
    public func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                for id in ids {
                    _ = try V2CoreDataRepositorySupport.requireID(id, field: "tombstone.id")
                    if let object = try V2CoreDataRepositorySupport.fetchObject(
                        in: self.backgroundContext,
                        entityName: TombstoneMapper.entityName,
                        predicate: NSPredicate(format: "id == %@", id as CVarArg),
                        sort: [NSSortDescriptor(key: "id", ascending: true)]
                    ) {
                        self.backgroundContext.delete(object)
                    }
                }
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
