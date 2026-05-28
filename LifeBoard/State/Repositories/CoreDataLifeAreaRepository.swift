import Foundation
import CoreData

public final class CoreDataLifeAreaRepository: LifeAreaRepositoryProtocol, @unchecked Sendable {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchAll.
    public func fetchAll(completion: @escaping @Sendable (Result<[LifeArea], Error>) -> Void) {
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
                completion(.success(try objects.map(LifeAreaMapper.validatedDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes create.
    public func create(_ area: LifeArea, completion: @escaping @Sendable (Result<LifeArea, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(area.id, field: "lifeArea.id")
                let normalizedName = try V2CoreDataRepositorySupport.requireNonEmpty(area.name, field: "lifeArea.name")
                if area.isArchived == false {
                    let normalizedIdentity = V2CoreDataRepositorySupport.normalizedIdentityString(normalizedName)
                    let duplicatePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "name =[c] %@", normalizedName),
                        NSPredicate(format: "isArchived == NO"),
                        NSPredicate(format: "id != %@", area.id as CVarArg)
                    ])
                    let exactDuplicate = try V2CoreDataRepositorySupport.fetchObject(
                        in: self.backgroundContext,
                        entityName: LifeAreaMapper.entityName,
                        predicate: duplicatePredicate
                    )
                    let normalizedDuplicate = try exactDuplicate ?? V2CoreDataRepositorySupport.fetchObjects(
                        in: self.backgroundContext,
                        entityName: LifeAreaMapper.entityName,
                        predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                            NSPredicate(format: "isArchived == NO"),
                            NSPredicate(format: "id != %@", area.id as CVarArg)
                        ]),
                        sort: [NSSortDescriptor(key: "id", ascending: true)]
                    ).first { object in
                        V2CoreDataRepositorySupport.normalizedIdentityString(object.value(forKey: "name")) == normalizedIdentity
                    }
                    if normalizedDuplicate != nil {
                        throw NSError(
                            domain: "CoreDataLifeAreaRepository",
                            code: 409,
                            userInfo: [NSLocalizedDescriptionKey: "Active life area names must be unique"]
                        )
                    }
                }
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: LifeAreaMapper.entityName,
                    id: area.id
                )
                var normalizedArea = area
                normalizedArea.name = normalizedName
                _ = LifeAreaMapper.apply(normalizedArea, to: object)
                try self.backgroundContext.save()
                completion(.success(normalizedArea))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes update.
    public func update(_ area: LifeArea, completion: @escaping @Sendable (Result<LifeArea, Error>) -> Void) {
        create(area, completion: completion)
    }

    /// Executes delete.
    public func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
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
