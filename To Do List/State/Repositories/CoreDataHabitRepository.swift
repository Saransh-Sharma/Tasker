import Foundation
import CoreData

public final class CoreDataHabitRepository: HabitRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchAll(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: HabitDefinitionMapper.entityName,
                    sort: [
                        NSSortDescriptor(key: "createdAt", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                completion(.success(objects.map(HabitDefinitionMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func create(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(habit.id, field: "habit.id")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(habit.title, field: "habit.title")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(habit.habitType, field: "habit.habitType")
                if let lifeAreaID = habit.lifeAreaID {
                    _ = try V2CoreDataRepositorySupport.requireID(lifeAreaID, field: "habit.lifeAreaID")
                }
                if let projectID = habit.projectID {
                    _ = try V2CoreDataRepositorySupport.requireID(projectID, field: "habit.projectID")
                }
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: HabitDefinitionMapper.entityName,
                    id: habit.id
                )
                _ = HabitDefinitionMapper.apply(habit, to: object)
                try self.backgroundContext.save()
                completion(.success(habit))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func update(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        create(habit, completion: completion)
    }

    public func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "habit.id")
                if let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: HabitDefinitionMapper.entityName,
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
