import Foundation
import CoreData

public final class CoreDataSectionRepository: SectionRepositoryProtocol, @unchecked Sendable {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchSections.
    public func fetchSections(projectID: UUID, completion: @escaping @Sendable (Result<[TaskerProjectSection], Error>) -> Void) {
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
                completion(.success(try objects.map(SectionMapper.validatedDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes create.
    public func create(_ section: TaskerProjectSection, completion: @escaping @Sendable (Result<TaskerProjectSection, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(section.id, field: "section.id")
                _ = try V2CoreDataRepositorySupport.requireID(section.projectID, field: "section.projectID")
                let normalizedName = try V2CoreDataRepositorySupport.requireNonEmpty(section.name, field: "section.name")
                let normalizedIdentity = V2CoreDataRepositorySupport.normalizedIdentityString(normalizedName)
                let duplicatePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "projectID == %@", section.projectID as CVarArg),
                    NSPredicate(format: "name =[c] %@", normalizedName),
                    NSPredicate(format: "id != %@", section.id as CVarArg)
                ])
                let exactDuplicate = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: SectionMapper.entityName,
                    predicate: duplicatePredicate
                )
                let normalizedDuplicate = try exactDuplicate ?? V2CoreDataRepositorySupport.fetchObjects(
                    in: self.backgroundContext,
                    entityName: SectionMapper.entityName,
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "projectID == %@", section.projectID as CVarArg),
                        NSPredicate(format: "id != %@", section.id as CVarArg)
                    ]),
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                ).first { object in
                    V2CoreDataRepositorySupport.normalizedIdentityString(object.value(forKey: "name")) == normalizedIdentity
                }
                if normalizedDuplicate != nil {
                    throw NSError(
                        domain: "CoreDataSectionRepository",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Section names must be unique within a project"]
                    )
                }
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: SectionMapper.entityName,
                    id: section.id
                )
                var normalizedSection = section
                normalizedSection.name = normalizedName
                _ = SectionMapper.apply(normalizedSection, to: object)
                try self.backgroundContext.save()
                completion(.success(normalizedSection))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes update.
    public func update(_ section: TaskerProjectSection, completion: @escaping @Sendable (Result<TaskerProjectSection, Error>) -> Void) {
        create(section, completion: completion)
    }

    /// Executes delete.
    public func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
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
