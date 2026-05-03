import Foundation
import CoreData

public final class CoreDataExternalSyncRepository: ExternalSyncRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchContainerMappings.
    public func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "ExternalContainerMap",
                    sort: [
                        NSSortDescriptor(key: "provider", ascending: true),
                        NSSortDescriptor(key: "projectID", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                completion(.success(objects.map(Self.mapContainer)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchContainerMapping.
    public func fetchContainerMapping(
        provider: String,
        projectID: UUID,
        completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void
    ) {
        viewContext.perform {
            do {
                let normalizedProvider = try V2CoreDataRepositorySupport.requireNonEmpty(provider, field: "provider")
                _ = try V2CoreDataRepositorySupport.requireID(projectID, field: "projectID")
                let predicate = NSPredicate(format: "provider == %@ AND projectID == %@", normalizedProvider, projectID as CVarArg)
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "ExternalContainerMap",
                    predicate: predicate,
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                completion(.success(object.map(Self.mapContainer)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes saveContainerMapping.
    public func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        upsertContainerMapping(provider: mapping.provider, projectID: mapping.projectID, mutate: { _ in
            mapping
        }) { result in
            completion(result.map { _ in () })
        }
    }

    /// Executes upsertContainerMapping.
    public func upsertContainerMapping(
        provider: String,
        projectID: UUID,
        mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition,
        completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                let normalizedProvider = try V2CoreDataRepositorySupport.requireNonEmpty(provider, field: "provider")
                _ = try V2CoreDataRepositorySupport.requireID(projectID, field: "projectID")
                let predicate = NSPredicate(format: "provider == %@ AND projectID == %@", normalizedProvider, projectID as CVarArg)
                let existingObject = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "ExternalContainerMap",
                    predicate: predicate,
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )

                let existing = existingObject.map(Self.mapContainer)
                var next = mutate(existing)
                if let existing {
                    next = ExternalContainerMapDefinition(
                        id: existing.id,
                        provider: normalizedProvider,
                        projectID: existing.projectID,
                        externalContainerID: next.externalContainerID,
                        syncEnabled: next.syncEnabled,
                        lastSyncAt: next.lastSyncAt,
                        createdAt: existing.createdAt
                    )
                } else {
                    next.provider = normalizedProvider
                    next.projectID = projectID
                }

                let object = existingObject ?? NSEntityDescription.insertNewObject(forEntityName: "ExternalContainerMap", into: self.backgroundContext)
                self.applyContainer(next, to: object)
                try self.backgroundContext.save()
                completion(.success(next))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchItemMappings.
    public func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "ExternalItemMap",
                    sort: [
                        NSSortDescriptor(key: "provider", ascending: true),
                        NSSortDescriptor(key: "localEntityType", ascending: true),
                        NSSortDescriptor(key: "localEntityID", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                completion(.success(objects.map(Self.mapItem)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes saveItemMapping.
    public func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        upsertItemMappingByLocalKey(
            provider: mapping.provider,
            localEntityType: mapping.localEntityType,
            localEntityID: mapping.localEntityID,
            mutate: { _ in mapping },
            completion: { result in
                completion(result.map { _ in () })
            }
        )
    }

    /// Executes upsertItemMappingByLocalKey.
    public func upsertItemMappingByLocalKey(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                let normalizedProvider = try V2CoreDataRepositorySupport.requireNonEmpty(provider, field: "provider")
                let normalizedLocalEntityType = try V2CoreDataRepositorySupport.requireNonEmpty(localEntityType, field: "localEntityType")
                _ = try V2CoreDataRepositorySupport.requireID(localEntityID, field: "localEntityID")

                let localPredicate = NSPredicate(
                    format: "provider == %@ AND localEntityType == %@ AND localEntityID == %@",
                    normalizedProvider,
                    normalizedLocalEntityType,
                    localEntityID as CVarArg
                )
                let existingByLocal = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "ExternalItemMap",
                    predicate: localPredicate,
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )

                let existing = existingByLocal.map(Self.mapItem)
                let proposed = mutate(existing)

                if proposed.externalItemID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw NSError(
                        domain: "CoreDataExternalSyncRepository",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "externalItemID cannot be empty"]
                    )
                }

                let normalizedExternalItemID = try V2CoreDataRepositorySupport.requireNonEmpty(
                    proposed.externalItemID,
                    field: "externalItemID"
                )
                let externalPredicate = NSPredicate(
                    format: "provider == %@ AND externalItemID == %@",
                    normalizedProvider,
                    normalizedExternalItemID
                )
                let existingByExternal = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "ExternalItemMap",
                    predicate: externalPredicate,
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )

                let resolvedID =
                    existing?.id ??
                    (existingByExternal?.value(forKey: "id") as? UUID) ??
                    proposed.id
                let resolvedCreatedAt =
                    existing?.createdAt ??
                    (existingByExternal?.value(forKey: "createdAt") as? Date) ??
                    proposed.createdAt
                let next = ExternalItemMapDefinition(
                    id: resolvedID,
                    provider: normalizedProvider,
                    localEntityType: normalizedLocalEntityType,
                    localEntityID: localEntityID,
                    externalItemID: normalizedExternalItemID,
                    externalPersistentID: proposed.externalPersistentID,
                    lastSeenExternalModAt: proposed.lastSeenExternalModAt,
                    externalPayloadData: proposed.externalPayloadData,
                    syncStateData: proposed.syncStateData,
                    createdAt: resolvedCreatedAt
                )

                let targetObject: NSManagedObject
                if let existingByLocal {
                    targetObject = existingByLocal
                    if let existingByExternal, existingByExternal != existingByLocal {
                        self.backgroundContext.delete(existingByExternal)
                    }
                } else if let existingByExternal {
                    targetObject = existingByExternal
                } else {
                    targetObject = NSEntityDescription.insertNewObject(forEntityName: "ExternalItemMap", into: self.backgroundContext)
                }

                self.applyItem(next, to: targetObject)
                try self.backgroundContext.save()
                completion(.success(next))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes upsertItemMappingByExternalKey.
    public func upsertItemMappingByExternalKey(
        provider: String,
        externalItemID: String,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                let normalizedProvider = try V2CoreDataRepositorySupport.requireNonEmpty(provider, field: "provider")
                let normalizedExternalItemID = try V2CoreDataRepositorySupport.requireNonEmpty(externalItemID, field: "externalItemID")

                let predicate = NSPredicate(
                    format: "provider == %@ AND externalItemID == %@",
                    normalizedProvider,
                    normalizedExternalItemID
                )
                let existingObject = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "ExternalItemMap",
                    predicate: predicate,
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                let existing = existingObject.map(Self.mapItem)

                let proposed = mutate(existing)
                let localEntityType = try V2CoreDataRepositorySupport.requireNonEmpty(proposed.localEntityType, field: "localEntityType")
                _ = try V2CoreDataRepositorySupport.requireID(proposed.localEntityID, field: "localEntityID")

                let localPredicate = NSPredicate(
                    format: "provider == %@ AND localEntityType == %@ AND localEntityID == %@",
                    normalizedProvider,
                    localEntityType,
                    proposed.localEntityID as CVarArg
                )
                let existingByLocal = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "ExternalItemMap",
                    predicate: localPredicate,
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )

                let resolvedID =
                    existing?.id ??
                    (existingByLocal?.value(forKey: "id") as? UUID) ??
                    proposed.id
                let resolvedCreatedAt =
                    existing?.createdAt ??
                    (existingByLocal?.value(forKey: "createdAt") as? Date) ??
                    proposed.createdAt
                let next = ExternalItemMapDefinition(
                    id: resolvedID,
                    provider: normalizedProvider,
                    localEntityType: localEntityType,
                    localEntityID: proposed.localEntityID,
                    externalItemID: normalizedExternalItemID,
                    externalPersistentID: proposed.externalPersistentID,
                    lastSeenExternalModAt: proposed.lastSeenExternalModAt,
                    externalPayloadData: proposed.externalPayloadData,
                    syncStateData: proposed.syncStateData,
                    createdAt: resolvedCreatedAt
                )

                let targetObject: NSManagedObject
                if let existingObject {
                    targetObject = existingObject
                    if let existingByLocal, existingByLocal != existingObject {
                        self.backgroundContext.delete(existingByLocal)
                    }
                } else if let existingByLocal {
                    targetObject = existingByLocal
                } else {
                    targetObject = NSEntityDescription.insertNewObject(forEntityName: "ExternalItemMap", into: self.backgroundContext)
                }

                self.applyItem(next, to: targetObject)
                try self.backgroundContext.save()
                completion(.success(next))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchItemMapping.
    public func fetchItemMapping(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void
    ) {
        viewContext.perform {
            do {
                let normalizedProvider = try V2CoreDataRepositorySupport.requireNonEmpty(provider, field: "provider")
                let normalizedLocalEntityType = try V2CoreDataRepositorySupport.requireNonEmpty(localEntityType, field: "localEntityType")
                _ = try V2CoreDataRepositorySupport.requireID(localEntityID, field: "localEntityID")
                let predicate = NSPredicate(
                    format: "provider == %@ AND localEntityType == %@ AND localEntityID == %@",
                    normalizedProvider,
                    normalizedLocalEntityType,
                    localEntityID as CVarArg
                )
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "ExternalItemMap",
                    predicate: predicate,
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                completion(.success(object.map(Self.mapItem)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchItemMapping.
    public func fetchItemMapping(
        provider: String,
        externalItemID: String,
        completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void
    ) {
        viewContext.perform {
            do {
                let normalizedProvider = try V2CoreDataRepositorySupport.requireNonEmpty(provider, field: "provider")
                let normalizedExternalItemID = try V2CoreDataRepositorySupport.requireNonEmpty(externalItemID, field: "externalItemID")
                let predicate = NSPredicate(
                    format: "provider == %@ AND externalItemID == %@",
                    normalizedProvider,
                    normalizedExternalItemID
                )
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "ExternalItemMap",
                    predicate: predicate,
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                completion(.success(object.map(Self.mapItem)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes mapContainer.
    private static func mapContainer(_ object: NSManagedObject) -> ExternalContainerMapDefinition {
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

    /// Executes mapItem.
    private static func mapItem(_ object: NSManagedObject) -> ExternalItemMapDefinition {
        ExternalItemMapDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            provider: object.value(forKey: "provider") as? String ?? "apple_reminders",
            localEntityType: object.value(forKey: "localEntityType") as? String ?? "task",
            localEntityID: object.value(forKey: "localEntityID") as? UUID ?? UUID(),
            externalItemID: object.value(forKey: "externalItemID") as? String ?? "",
            externalPersistentID: object.value(forKey: "externalPersistentID") as? String,
            lastSeenExternalModAt: object.value(forKey: "lastSeenExternalModAt") as? Date,
            externalPayloadData: object.value(forKey: "externalPayloadData") as? Data,
            syncStateData: (object.value(forKey: "syncStateData") as? Data) ?? ReminderMergeState().encodedData(),
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
        )
    }

    /// Executes applyContainer.
    private func applyContainer(_ mapping: ExternalContainerMapDefinition, to object: NSManagedObject) {
        object.setValue(mapping.id, forKey: "id")
        object.setValue(mapping.provider, forKey: "provider")
        object.setValue(mapping.projectID, forKey: "projectID")
        object.setValue(mapping.externalContainerID, forKey: "externalContainerID")
        object.setValue(mapping.syncEnabled, forKey: "syncEnabled")
        object.setValue(mapping.lastSyncAt, forKey: "lastSyncAt")
        object.setValue(mapping.createdAt, forKey: "createdAt")
    }

    /// Executes applyItem.
    private func applyItem(_ mapping: ExternalItemMapDefinition, to object: NSManagedObject) {
        object.setValue(mapping.id, forKey: "id")
        object.setValue(mapping.provider, forKey: "provider")
        object.setValue(mapping.localEntityType, forKey: "localEntityType")
        object.setValue(mapping.localEntityID, forKey: "localEntityID")
        object.setValue(mapping.externalItemID, forKey: "externalItemID")
        object.setValue(mapping.externalPersistentID, forKey: "externalPersistentID")
        object.setValue(mapping.lastSeenExternalModAt, forKey: "lastSeenExternalModAt")
        object.setValue(mapping.externalPayloadData, forKey: "externalPayloadData")
        object.setValue(mapping.syncStateData ?? ReminderMergeState().encodedData(), forKey: "syncStateData")
        object.setValue(mapping.createdAt, forKey: "createdAt")
    }
}
