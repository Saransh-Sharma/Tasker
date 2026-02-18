import Foundation
import CoreData

public final class CoreDataLifeAreaRepository: LifeAreaRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: LifeAreaMapper.entityName,
                    sort: [
                        NSSortDescriptor(key: "sortOrder", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                completion(.success(objects.map(LifeAreaMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(area.id, field: "lifeArea.id")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(area.name, field: "lifeArea.name")
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: LifeAreaMapper.entityName,
                    id: area.id
                )
                _ = LifeAreaMapper.apply(area, to: object)
                try self.backgroundContext.save()
                completion(.success(area))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        create(area, completion: completion)
    }

    public func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "lifeArea.id")
                if let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: LifeAreaMapper.entityName,
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
