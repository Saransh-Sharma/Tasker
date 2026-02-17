import Foundation
import CoreData

public final class CoreDataExternalSyncRepository: ExternalSyncRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
    }

    public func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(in: self.viewContext, entityName: "ExternalContainerMap")
                let mapped = objects.map { object in
                    ExternalContainerMapDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        provider: object.value(forKey: "provider") as? String ?? "apple_reminders",
                        projectID: object.value(forKey: "projectID") as? UUID ?? ProjectConstants.inboxProjectID,
                        externalContainerID: object.value(forKey: "externalContainerID") as? String ?? "",
                        syncEnabled: object.value(forKey: "syncEnabled") as? Bool ?? true,
                        lastSyncAt: object.value(forKey: "lastSyncAt") as? Date,
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                    )
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(in: self.viewContext, entityName: "ExternalItemMap")
                let mapped = objects.map { object in
                    ExternalItemMapDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        provider: object.value(forKey: "provider") as? String ?? "apple_reminders",
                        localEntityType: object.value(forKey: "localEntityType") as? String ?? "task",
                        localEntityID: object.value(forKey: "localEntityID") as? UUID ?? UUID(),
                        externalItemID: object.value(forKey: "externalItemID") as? String ?? "",
                        externalPersistentID: object.value(forKey: "externalPersistentID") as? String,
                        lastSeenExternalModAt: object.value(forKey: "lastSeenExternalModAt") as? Date,
                        externalPayloadData: object.value(forKey: "externalPayloadData") as? Data,
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                    )
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "ExternalContainerMap",
                    id: mapping.id
                )
                object.setValue(mapping.id, forKey: "id")
                object.setValue(mapping.provider, forKey: "provider")
                object.setValue(mapping.projectID, forKey: "projectID")
                object.setValue(mapping.externalContainerID, forKey: "externalContainerID")
                object.setValue(mapping.syncEnabled, forKey: "syncEnabled")
                object.setValue(mapping.lastSyncAt, forKey: "lastSyncAt")
                object.setValue(mapping.createdAt, forKey: "createdAt")
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "ExternalItemMap",
                    id: mapping.id
                )
                object.setValue(mapping.id, forKey: "id")
                object.setValue(mapping.provider, forKey: "provider")
                object.setValue(mapping.localEntityType, forKey: "localEntityType")
                object.setValue(mapping.localEntityID, forKey: "localEntityID")
                object.setValue(mapping.externalItemID, forKey: "externalItemID")
                object.setValue(mapping.externalPersistentID, forKey: "externalPersistentID")
                object.setValue(mapping.lastSeenExternalModAt, forKey: "lastSeenExternalModAt")
                object.setValue(mapping.externalPayloadData, forKey: "externalPayloadData")
                object.setValue(mapping.createdAt, forKey: "createdAt")
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchItemMapping(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void
    ) {
        viewContext.perform {
            do {
                guard let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "ExternalItemMap",
                    predicate: NSPredicate(
                        format: "provider == %@ AND localEntityType == %@ AND localEntityID == %@",
                        provider,
                        localEntityType,
                        localEntityID as CVarArg
                    )
                ) else {
                    completion(.success(nil))
                    return
                }
                let mapped = ExternalItemMapDefinition(
                    id: object.value(forKey: "id") as? UUID ?? UUID(),
                    provider: object.value(forKey: "provider") as? String ?? "apple_reminders",
                    localEntityType: object.value(forKey: "localEntityType") as? String ?? "task",
                    localEntityID: object.value(forKey: "localEntityID") as? UUID ?? UUID(),
                    externalItemID: object.value(forKey: "externalItemID") as? String ?? "",
                    externalPersistentID: object.value(forKey: "externalPersistentID") as? String,
                    lastSeenExternalModAt: object.value(forKey: "lastSeenExternalModAt") as? Date,
                    externalPayloadData: object.value(forKey: "externalPayloadData") as? Data,
                    createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                )
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchItemMapping(
        provider: String,
        externalItemID: String,
        completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void
    ) {
        viewContext.perform {
            do {
                guard let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "ExternalItemMap",
                    predicate: NSPredicate(
                        format: "provider == %@ AND externalItemID == %@",
                        provider,
                        externalItemID
                    )
                ) else {
                    completion(.success(nil))
                    return
                }
                let mapped = ExternalItemMapDefinition(
                    id: object.value(forKey: "id") as? UUID ?? UUID(),
                    provider: object.value(forKey: "provider") as? String ?? "apple_reminders",
                    localEntityType: object.value(forKey: "localEntityType") as? String ?? "task",
                    localEntityID: object.value(forKey: "localEntityID") as? UUID ?? UUID(),
                    externalItemID: object.value(forKey: "externalItemID") as? String ?? "",
                    externalPersistentID: object.value(forKey: "externalPersistentID") as? String,
                    lastSeenExternalModAt: object.value(forKey: "lastSeenExternalModAt") as? Date,
                    externalPayloadData: object.value(forKey: "externalPayloadData") as? Data,
                    createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                )
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
