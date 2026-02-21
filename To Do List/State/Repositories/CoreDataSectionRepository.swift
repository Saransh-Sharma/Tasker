import Foundation
import CoreData

public final class CoreDataSectionRepository: SectionRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Executes fetchSections.
    public func fetchSections(projectID: UUID, completion: @escaping (Result<[TaskerProjectSection], Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(projectID, field: "section.projectID")
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: SectionMapper.entityName,
                    predicate: NSPredicate(format: "projectID == %@", projectID as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "sortOrder", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                completion(.success(objects.map(SectionMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes create.
    public func create(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(section.id, field: "section.id")
                _ = try V2CoreDataRepositorySupport.requireID(section.projectID, field: "section.projectID")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(section.name, field: "section.name")
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: SectionMapper.entityName,
                    id: section.id
                )
                _ = SectionMapper.apply(section, to: object)
                try self.backgroundContext.save()
                completion(.success(section))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes update.
    public func update(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) {
        create(section, completion: completion)
    }

    /// Executes delete.
    public func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "section.id")
                if let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: SectionMapper.entityName,
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
