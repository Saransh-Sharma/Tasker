import Foundation
import CoreData

public final class CoreDataSectionRepository: SectionRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchSections(projectID: UUID, completion: @escaping (Result<[TaskerProjectSection], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: SectionMapper.entityName,
                    predicate: NSPredicate(format: "projectID == %@", projectID as CVarArg),
                    sort: [NSSortDescriptor(key: "sortOrder", ascending: true)]
                )
                completion(.success(objects.map(SectionMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func create(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) {
        backgroundContext.perform {
            do {
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

    public func update(_ section: TaskerProjectSection, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) {
        create(section, completion: completion)
    }

    public func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
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
