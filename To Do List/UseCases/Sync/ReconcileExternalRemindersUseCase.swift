import Foundation

public final class ReconcileExternalRemindersUseCase {
    public struct ExternalReminderSnapshot {
        public let provider: String
        public let localEntityType: String
        public let localEntityID: UUID
        public let externalItemID: String
        public let externalPersistentID: String?
        public let externalModifiedAt: Date?
        public let externalPayloadData: Data?

        public init(
            provider: String = "apple_reminders",
            localEntityType: String,
            localEntityID: UUID,
            externalItemID: String,
            externalPersistentID: String? = nil,
            externalModifiedAt: Date? = nil,
            externalPayloadData: Data? = nil
        ) {
            self.provider = provider
            self.localEntityType = localEntityType
            self.localEntityID = localEntityID
            self.externalItemID = externalItemID
            self.externalPersistentID = externalPersistentID
            self.externalModifiedAt = externalModifiedAt
            self.externalPayloadData = externalPayloadData
        }
    }

    public struct ReconcileSummary: Equatable {
        public var pulledFromExternal: Int
        public var pushedToExternal: Int
        public var mappedExisting: Int
        public var importedNew: Int

        public init(
            pulledFromExternal: Int = 0,
            pushedToExternal: Int = 0,
            mappedExisting: Int = 0,
            importedNew: Int = 0
        ) {
            self.pulledFromExternal = pulledFromExternal
            self.pushedToExternal = pushedToExternal
            self.mappedExisting = mappedExisting
            self.importedNew = importedNew
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

    public func execute(completion: @escaping (Result<Int, Error>) -> Void) {
        guard V2FeatureFlags.v2Enabled, V2FeatureFlags.remindersSyncEnabled else {
            completion(.failure(syncDisabledError()))
            return
        }
        externalRepository.fetchItemMappings { result in
            switch result {
            case .success(let mappings):
                completion(.success(mappings.count))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func reconcile(
        snapshots: [ExternalReminderSnapshot],
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        guard V2FeatureFlags.v2Enabled, V2FeatureFlags.remindersSyncEnabled else {
            completion(.failure(syncDisabledError()))
            return
        }

        logWarning(
            event: "reminders_mapping_reconcile_started",
            message: "Reconciling reminder mapping snapshots",
            fields: ["snapshot_count": String(snapshots.count)]
        )

        let group = DispatchGroup()
        let lock = NSLock()
        var merged = 0
        var firstError: Error?

        for snapshot in snapshots {
            group.enter()
            externalRepository.fetchItemMapping(
                provider: snapshot.provider,
                localEntityType: snapshot.localEntityType,
                localEntityID: snapshot.localEntityID
            ) { result in
                switch result {
                case .failure(let error):
                    lock.lock()
                    firstError = firstError ?? error
                    lock.unlock()
                    group.leave()
                case .success(let existing):
                    let shouldReplace: Bool = {
                        guard let existing else { return true }
                        let localDate = existing.lastSeenExternalModAt ?? .distantPast
                        let remoteDate = snapshot.externalModifiedAt ?? .distantPast
                        return remoteDate >= localDate
                    }()

                    guard shouldReplace else {
                        group.leave()
                        return
                    }

                    let next = ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: snapshot.provider,
                        localEntityType: snapshot.localEntityType,
                        localEntityID: snapshot.localEntityID,
                        externalItemID: snapshot.externalItemID,
                        externalPersistentID: snapshot.externalPersistentID,
                        lastSeenExternalModAt: snapshot.externalModifiedAt,
                        externalPayloadData: snapshot.externalPayloadData ?? existing?.externalPayloadData,
                        createdAt: existing?.createdAt ?? Date()
                    )

                    self.externalRepository.saveItemMapping(next) { saveResult in
                        lock.lock()
                        if case .failure(let error) = saveResult {
                            firstError = firstError ?? error
                        } else {
                            merged += 1
                        }
                        lock.unlock()
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                logWarning(
                    event: "reminders_mapping_reconcile_completed",
                    message: "Reminder mapping snapshots reconciled",
                    fields: ["merged_count": String(merged)]
                )
                completion(.success(merged))
            }
        }
    }

    public func reconcileProject(
        projectID: UUID,
        completion: @escaping (Result<ReconcileSummary, Error>) -> Void
    ) {
        guard V2FeatureFlags.v2Enabled, V2FeatureFlags.remindersSyncEnabled else {
            completion(.failure(syncDisabledError()))
            return
        }

        guard let remindersProvider, let taskRepository else {
            completion(.failure(NSError(
                domain: "ReconcileExternalRemindersUseCase",
                code: 501,
                userInfo: [NSLocalizedDescriptionKey: "Reminders provider or task repository is not configured"]
            )))
            return
        }

        externalRepository.fetchContainerMappings { mappingsResult in
            switch mappingsResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let containerMappings):
                guard let containerMap = containerMappings.first(where: {
                    $0.provider == "apple_reminders" &&
                    $0.projectID == projectID &&
                    $0.syncEnabled
                }) else {
                    completion(.failure(NSError(
                        domain: "ReconcileExternalRemindersUseCase",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "No synced Apple Reminders container for project"]
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
                                domain: "ReconcileExternalRemindersUseCase",
                                code: 403,
                                userInfo: [NSLocalizedDescriptionKey: "Reminders access denied"]
                            )))
                            return
                        }

                        remindersProvider.fetchReminders(listID: containerMap.externalContainerID) { remindersResult in
                            switch remindersResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success(let externalReminders):
                                self.externalRepository.fetchItemMappings { itemMappingsResult in
                                    switch itemMappingsResult {
                                    case .failure(let error):
                                        completion(.failure(error))
                                    case .success(let itemMappings):
                                        taskRepository.fetchAll { tasksResult in
                                            switch tasksResult {
                                            case .failure(let error):
                                                completion(.failure(error))
                                            case .success(let allTasks):
                                                self.reconcileTwoWay(
                                                    projectID: projectID,
                                                    listID: containerMap.externalContainerID,
                                                    externalReminders: externalReminders,
                                                    itemMappings: itemMappings.filter { $0.provider == "apple_reminders" },
                                                    tasks: allTasks.filter { $0.projectID == projectID },
                                                    remindersProvider: remindersProvider,
                                                    taskRepository: taskRepository,
                                                    completion: completion
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func reconcileTwoWay(
        projectID: UUID,
        listID: String,
        externalReminders: [AppleReminderItemSnapshot],
        itemMappings: [ExternalItemMapDefinition],
        tasks: [TaskDefinition],
        remindersProvider: AppleRemindersProviderProtocol,
        taskRepository: TaskDefinitionRepositoryProtocol,
        completion: @escaping (Result<ReconcileSummary, Error>) -> Void
    ) {
        var summary = ReconcileSummary()
        var taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var mappingByLocalID = Dictionary(uniqueKeysWithValues: itemMappings.map { ($0.localEntityID, $0) })
        var mappingByExternalID = Dictionary(uniqueKeysWithValues: itemMappings.map { ($0.externalItemID, $0) })
        var seenLocalIDs = Set<UUID>()

        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for external in externalReminders {
            if let mapping = mappingByExternalID[external.itemID] {
                seenLocalIDs.insert(mapping.localEntityID)
                guard var localTask = taskByID[mapping.localEntityID], mapping.localEntityType == "task" else {
                    continue
                }

                let remoteModified = external.lastModifiedAt ?? .distantPast
                let mappedModified = mapping.lastSeenExternalModAt ?? .distantPast
                let localModified = localModificationDate(task: localTask)

                if remoteModified > max(mappedModified, localModified) {
                    localTask.name = external.title
                    localTask.details = external.notes
                    localTask.dueDate = external.dueDate
                    localTask.isComplete = external.isCompleted
                    localTask.dateCompleted = external.completionDate
                    localTask.priority = priorityFromEventKit(external.priority)
                    localTask.updatedAt = Date()

                    group.enter()
                    taskRepository.update(localTask) { updateResult in
                        switch updateResult {
                        case .failure(let error):
                            lock.lock()
                            firstError = firstError ?? error
                            lock.unlock()
                            group.leave()
                        case .success(let updated):
                            taskByID[updated.id] = updated
                            var updatedMap = mapping
                            updatedMap.lastSeenExternalModAt = external.lastModifiedAt
                            updatedMap.externalPayloadData = external.payloadData
                            self.externalRepository.saveItemMapping(updatedMap) { saveResult in
                                lock.lock()
                                if case .failure(let error) = saveResult {
                                    firstError = firstError ?? error
                                } else {
                                    summary.pulledFromExternal += 1
                                    mappingByLocalID[updated.id] = updatedMap
                                    mappingByExternalID[updatedMap.externalItemID] = updatedMap
                                }
                                lock.unlock()
                                group.leave()
                            }
                        }
                    }
                } else if localModified > max(remoteModified, mappedModified) {
                    group.enter()
                    let localSnapshot = snapshot(from: localTask, listID: listID, existingExternalID: external.itemID)
                    remindersProvider.upsertReminder(listID: listID, snapshot: localSnapshot) { upsertResult in
                        switch upsertResult {
                        case .failure(let error):
                            lock.lock()
                            firstError = firstError ?? error
                            lock.unlock()
                            group.leave()
                        case .success(let persistedRemote):
                            var updatedMap = mapping
                            updatedMap.externalItemID = persistedRemote.itemID
                            updatedMap.lastSeenExternalModAt = persistedRemote.lastModifiedAt
                            updatedMap.externalPayloadData = persistedRemote.payloadData
                            self.externalRepository.saveItemMapping(updatedMap) { saveResult in
                                lock.lock()
                                if case .failure(let error) = saveResult {
                                    firstError = firstError ?? error
                                } else {
                                    summary.pushedToExternal += 1
                                    mappingByLocalID[localTask.id] = updatedMap
                                    mappingByExternalID[updatedMap.externalItemID] = updatedMap
                                }
                                lock.unlock()
                                group.leave()
                            }
                        }
                    }
                }
            } else {
                // Remote item has no mapping: map to existing local task or import as new.
                if let matched = matchTask(external: external, tasks: Array(taskByID.values)) {
                    seenLocalIDs.insert(matched.id)
                    let newMap = ExternalItemMapDefinition(
                        id: UUID(),
                        provider: "apple_reminders",
                        localEntityType: "task",
                        localEntityID: matched.id,
                        externalItemID: external.itemID,
                        externalPersistentID: nil,
                        lastSeenExternalModAt: external.lastModifiedAt,
                        externalPayloadData: external.payloadData,
                        createdAt: Date()
                    )
                    group.enter()
                    self.externalRepository.saveItemMapping(newMap) { saveResult in
                        lock.lock()
                        if case .failure(let error) = saveResult {
                            firstError = firstError ?? error
                        } else {
                            summary.mappedExisting += 1
                            mappingByLocalID[matched.id] = newMap
                            mappingByExternalID[newMap.externalItemID] = newMap
                        }
                        lock.unlock()
                        group.leave()
                    }
                } else {
                    group.enter()
                    let task = TaskDefinition(
                        projectID: projectID,
                        projectName: ProjectConstants.inboxProjectName,
                        title: external.title,
                        details: external.notes,
                        priority: priorityFromEventKit(external.priority),
                        dueDate: external.dueDate,
                        isComplete: external.isCompleted,
                        dateAdded: Date(),
                        dateCompleted: external.completionDate
                    )
                    taskRepository.create(task) { createResult in
                        switch createResult {
                        case .failure(let error):
                            lock.lock()
                            firstError = firstError ?? error
                            lock.unlock()
                            group.leave()
                        case .success(let created):
                            seenLocalIDs.insert(created.id)
                            taskByID[created.id] = created
                            let newMap = ExternalItemMapDefinition(
                                id: UUID(),
                                provider: "apple_reminders",
                                localEntityType: "task",
                                localEntityID: created.id,
                                externalItemID: external.itemID,
                                externalPersistentID: nil,
                                lastSeenExternalModAt: external.lastModifiedAt,
                                externalPayloadData: external.payloadData,
                                createdAt: Date()
                            )
                            self.externalRepository.saveItemMapping(newMap) { saveResult in
                                lock.lock()
                                if case .failure(let error) = saveResult {
                                    firstError = firstError ?? error
                                } else {
                                    summary.importedNew += 1
                                    mappingByLocalID[created.id] = newMap
                                    mappingByExternalID[newMap.externalItemID] = newMap
                                }
                                lock.unlock()
                                group.leave()
                            }
                        }
                    }
                }
            }
        }

        // Push local tasks that are still unmapped.
        for task in taskByID.values where mappingByLocalID[task.id] == nil && !seenLocalIDs.contains(task.id) {
            group.enter()
            let localSnapshot = snapshot(from: task, listID: listID, existingExternalID: "")
            remindersProvider.upsertReminder(listID: listID, snapshot: localSnapshot) { upsertResult in
                switch upsertResult {
                case .failure(let error):
                    lock.lock()
                    firstError = firstError ?? error
                    lock.unlock()
                    group.leave()
                case .success(let remote):
                    let mapping = ExternalItemMapDefinition(
                        id: UUID(),
                        provider: "apple_reminders",
                        localEntityType: "task",
                        localEntityID: task.id,
                        externalItemID: remote.itemID,
                        externalPersistentID: nil,
                        lastSeenExternalModAt: remote.lastModifiedAt,
                        externalPayloadData: remote.payloadData,
                        createdAt: Date()
                    )
                    self.externalRepository.saveItemMapping(mapping) { saveResult in
                        lock.lock()
                        if case .failure(let error) = saveResult {
                            firstError = firstError ?? error
                        } else {
                            summary.pushedToExternal += 1
                        }
                        lock.unlock()
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                logError(
                    event: "reminders_reconcile_failed",
                    message: "Two-way Apple Reminders reconciliation failed",
                    fields: [
                        "project_id": projectID.uuidString,
                        "error": firstError.localizedDescription
                    ]
                )
                completion(.failure(firstError))
            } else {
                logWarning(
                    event: "reminders_reconcile_completed",
                    message: "Two-way Apple Reminders reconciliation completed",
                    fields: [
                        "project_id": projectID.uuidString,
                        "pulled": String(summary.pulledFromExternal),
                        "pushed": String(summary.pushedToExternal),
                        "mapped": String(summary.mappedExisting),
                        "imported": String(summary.importedNew)
                    ]
                )
                completion(.success(summary))
            }
        }
    }

    private func matchTask(external: AppleReminderItemSnapshot, tasks: [TaskDefinition]) -> TaskDefinition? {
        let normalized = normalize(external.title)
        return tasks.first { task in
            guard normalize(task.name) == normalized else { return false }
            switch (task.dueDate, external.dueDate) {
            case (nil, nil):
                return true
            case let (lhs?, rhs?):
                return abs(lhs.timeIntervalSince(rhs)) < 60 * 60
            default:
                return false
            }
        }
    }

    private func localModificationDate(task: TaskDefinition) -> Date {
        [task.updatedAt, task.dateCompleted, task.dueDate, task.dateAdded]
            .compactMap { $0 }
            .max() ?? task.updatedAt
    }

    private func snapshot(from task: TaskDefinition, listID: String, existingExternalID: String) -> AppleReminderItemSnapshot {
        AppleReminderItemSnapshot(
            itemID: existingExternalID,
            calendarID: listID,
            title: task.name,
            notes: task.details,
            dueDate: task.dueDate,
            completionDate: task.dateCompleted,
            isCompleted: task.isComplete,
            priority: eventKitPriority(from: task.priority),
            urlString: nil,
            alarmDates: [],
            lastModifiedAt: nil,
            payloadData: nil
        )
    }

    private func priorityFromEventKit(_ raw: Int) -> TaskPriority {
        switch raw {
        case 1:
            return .max
        case 5:
            return .high
        case 9:
            return .low
        default:
            return .none
        }
    }

    private func eventKitPriority(from priority: TaskPriority) -> Int {
        switch priority {
        case .max:
            return 1
        case .high:
            return 5
        case .low:
            return 9
        case .none:
            return 0
        }
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func syncDisabledError() -> Error {
        NSError(
            domain: "ReconcileExternalRemindersUseCase",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "Apple Reminders sync is disabled by feature flag"]
        )
    }
}
