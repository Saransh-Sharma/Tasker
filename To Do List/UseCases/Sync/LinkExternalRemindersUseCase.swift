import Foundation

public final class LinkExternalRemindersUseCase {
    public struct ImportedReminderItem {
        public let localEntityType: String
        public let localEntityID: UUID
        public let externalItemID: String
        public let externalPersistentID: String?
        public let externalModifiedAt: Date?
        public let externalPayloadData: Data?

        public init(
            localEntityType: String,
            localEntityID: UUID,
            externalItemID: String,
            externalPersistentID: String? = nil,
            externalModifiedAt: Date? = nil,
            externalPayloadData: Data? = nil
        ) {
            self.localEntityType = localEntityType
            self.localEntityID = localEntityID
            self.externalItemID = externalItemID
            self.externalPersistentID = externalPersistentID
            self.externalModifiedAt = externalModifiedAt
            self.externalPayloadData = externalPayloadData
        }
    }

    private let externalRepository: ExternalSyncRepositoryProtocol
    private let remindersProvider: AppleRemindersProviderProtocol?
    private let taskRepository: TaskDefinitionRepositoryProtocol?

    public init(
        externalRepository: ExternalSyncRepositoryProtocol,
        remindersProvider: AppleRemindersProviderProtocol? = nil,
        taskRepository: TaskDefinitionRepositoryProtocol? = nil
    ) {
        self.externalRepository = externalRepository
        self.remindersProvider = remindersProvider
        self.taskRepository = taskRepository
    }

    public func listContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) {
        guard V2FeatureFlags.v2Enabled, V2FeatureFlags.remindersSyncEnabled else {
            completion(.failure(syncDisabledError()))
            return
        }
        externalRepository.fetchContainerMappings(completion: completion)
    }

    public func linkProject(
        projectID: UUID,
        externalContainerID: String,
        importedItems: [ImportedReminderItem],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard V2FeatureFlags.v2Enabled, V2FeatureFlags.remindersSyncEnabled else {
            completion(.failure(syncDisabledError()))
            return
        }

        logWarning(
            event: "reminders_link_started",
            message: "Starting Apple Reminders project link",
            fields: [
                "project_id": projectID.uuidString,
                "external_container_id": externalContainerID,
                "import_count": String(importedItems.count)
            ]
        )

        let mapping = ExternalContainerMapDefinition(
            id: UUID(),
            provider: "apple_reminders",
            projectID: projectID,
            externalContainerID: externalContainerID,
            syncEnabled: true,
            lastSyncAt: Date(),
            createdAt: Date()
        )

        externalRepository.saveContainerMapping(mapping) { result in
            switch result {
            case .failure(let error):
                logError(
                    event: "reminders_link_container_failed",
                    message: "Failed to persist external container mapping",
                    fields: [
                        "project_id": projectID.uuidString,
                        "external_container_id": externalContainerID,
                        "error": error.localizedDescription
                    ]
                )
                completion(.failure(error))
            case .success:
                let group = DispatchGroup()
                var firstError: Error?
                for item in importedItems {
                    let map = ExternalItemMapDefinition(
                        id: UUID(),
                        provider: "apple_reminders",
                        localEntityType: item.localEntityType,
                        localEntityID: item.localEntityID,
                        externalItemID: item.externalItemID,
                        externalPersistentID: item.externalPersistentID,
                        lastSeenExternalModAt: item.externalModifiedAt,
                        externalPayloadData: item.externalPayloadData,
                        syncStateData: self.initialSyncStateData(for: item),
                        createdAt: Date()
                    )
                    group.enter()
                    self.externalRepository.saveItemMapping(map) { saveResult in
                        if case .failure(let error) = saveResult {
                            firstError = firstError ?? error
                        }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    if let firstError {
                        logError(
                            event: "reminders_link_items_failed",
                            message: "Failed to persist one or more imported reminder mappings",
                            fields: [
                                "project_id": projectID.uuidString,
                                "external_container_id": externalContainerID,
                                "import_count": String(importedItems.count),
                                "error": firstError.localizedDescription
                            ]
                        )
                        completion(.failure(firstError))
                    } else {
                        logWarning(
                            event: "reminders_link_completed",
                            message: "External reminders project link created",
                            fields: [
                                "project_id": projectID.uuidString,
                                "external_container_id": externalContainerID,
                                "import_count": String(importedItems.count)
                            ]
                        )
                        completion(.success(()))
                    }
                }
            }
        }
    }

    public func linkProjectWithBootstrapImport(
        projectID: UUID,
        externalContainerID: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard V2FeatureFlags.v2Enabled, V2FeatureFlags.remindersSyncEnabled else {
            completion(.failure(syncDisabledError()))
            return
        }

        guard let remindersProvider else {
            completion(.failure(NSError(
                domain: "LinkExternalRemindersUseCase",
                code: 501,
                userInfo: [NSLocalizedDescriptionKey: "Apple reminders provider not configured"]
            )))
            return
        }

        remindersProvider.requestAccess { accessResult in
            switch accessResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let granted):
                guard granted else {
                    completion(.failure(NSError(
                        domain: "LinkExternalRemindersUseCase",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "Reminders access denied"]
                    )))
                    return
                }
                remindersProvider.fetchReminders(listID: externalContainerID) { fetchResult in
                    switch fetchResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let snapshots):
                        self.bootstrapImportedItems(
                            projectID: projectID,
                            snapshots: snapshots
                        ) { itemsResult in
                            switch itemsResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success(let importedItems):
                                self.linkProject(
                                    projectID: projectID,
                                    externalContainerID: externalContainerID,
                                    importedItems: importedItems,
                                    completion: completion
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func bootstrapImportedItems(
        projectID: UUID,
        snapshots: [AppleReminderItemSnapshot],
        completion: @escaping (Result<[ImportedReminderItem], Error>) -> Void
    ) {
        guard let taskRepository else {
            completion(.failure(NSError(
                domain: "LinkExternalRemindersUseCase",
                code: 501,
                userInfo: [NSLocalizedDescriptionKey: "Task repository is not configured for bootstrap import"]
            )))
            return
        }

        taskRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let tasks):
                let projectTasks = tasks.filter { $0.projectID == projectID }
                let group = DispatchGroup()
                var imported: [ImportedReminderItem] = []
                var firstError: Error?
                let lock = NSLock()

                for snapshot in snapshots {
                    if let matchedTask = self.matchExistingTask(snapshot: snapshot, tasks: projectTasks) {
                        imported.append(
                            ImportedReminderItem(
                                localEntityType: "task",
                                localEntityID: matchedTask.id,
                                externalItemID: snapshot.itemID,
                                externalPersistentID: nil,
                                externalModifiedAt: snapshot.lastModifiedAt,
                                externalPayloadData: snapshot.payloadData
                            )
                        )
                        continue
                    }

                    group.enter()
                    let importedTask = TaskDefinition(
                        projectID: projectID,
                        projectName: ProjectConstants.inboxProjectName,
                        title: snapshot.title,
                        details: snapshot.notes,
                        dueDate: snapshot.dueDate,
                        isComplete: snapshot.isCompleted,
                        dateAdded: Date(),
                        dateCompleted: snapshot.completionDate
                    )
                    taskRepository.create(importedTask) { createResult in
                        lock.lock()
                        switch createResult {
                        case .failure(let error):
                            firstError = firstError ?? error
                        case .success(let created):
                            imported.append(
                                ImportedReminderItem(
                                    localEntityType: "task",
                                    localEntityID: created.id,
                                    externalItemID: snapshot.itemID,
                                    externalPersistentID: nil,
                                    externalModifiedAt: snapshot.lastModifiedAt,
                                    externalPayloadData: snapshot.payloadData
                                )
                            )
                        }
                        lock.unlock()
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    if let firstError {
                        completion(.failure(firstError))
                    } else {
                        completion(.success(imported))
                    }
                }
            }
        }
    }

    private func matchExistingTask(
        snapshot: AppleReminderItemSnapshot,
        tasks: [TaskDefinition]
    ) -> TaskDefinition? {
        let normalizedTitle = normalize(snapshot.title)
        let dueDate = snapshot.dueDate
        return tasks.first { task in
            guard normalize(task.name) == normalizedTitle else { return false }
            switch (task.dueDate, dueDate) {
            case (nil, nil):
                return true
            case let (lhs?, rhs?):
                return abs(lhs.timeIntervalSince(rhs)) < 60 * 60
            default:
                return false
            }
        }
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func syncDisabledError() -> Error {
        NSError(
            domain: "LinkExternalRemindersUseCase",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "Apple Reminders sync is disabled by feature flag"]
        )
    }

    private func initialSyncStateData(for item: ImportedReminderItem) -> Data? {
        let modifiedAt = item.externalModifiedAt ?? Date()
        let clock = SyncClock(
            physicalMillis: Int64(modifiedAt.timeIntervalSince1970 * 1_000),
            logicalCounter: 0,
            nodeID: "remote.apple_reminders"
        )
        var mergeState = ReminderMergeState(lastWriteClock: clock)
        for field in ReminderScalarField.allCases {
            mergeState.fieldClocks[field] = clock
        }
        return mergeState.encodedData()
    }
}
