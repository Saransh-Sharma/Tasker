import Foundation
import CoreData

public final class CoreDataLifeAreaRepository: LifeAreaRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchAll.
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

    /// Executes create.
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

    /// Executes update.
    public func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        create(area, completion: completion)
    }

    /// Executes delete.
    public func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "lifeArea.id")
                let habitObjects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.backgroundContext,
                    entityName: "HabitDefinition",
                    predicate: NSPredicate(format: "lifeAreaID == %@", id as CVarArg)
                )
                for habit in habitObjects {
                    habit.setValue(nil, forKey: "lifeAreaID")
                    habit.setValue(nil, forKey: "projectID")
                    habit.setValue(nil, forKey: "lifeAreaRef")
                    habit.setValue(nil, forKey: "projectRef")
                }
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
