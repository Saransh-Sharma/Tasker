import Foundation
import CoreData

public final class CoreDataTombstoneRepository: TombstoneRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
    }

    public func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
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

    public func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: TombstoneMapper.entityName,
                    predicate: NSPredicate(format: "purgeAfter <= %@", date as NSDate)
                )
                completion(.success(objects.map(TombstoneMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
