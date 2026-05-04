import Foundation

private final class ReconcileErrorRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedError: Error?

    func record(_ error: Error) {
        lock.lock()
        if storedError == nil {
            storedError = error
        }
        lock.unlock()
    }

    func firstError() -> Error? {
        lock.lock()
        let error = storedError
        lock.unlock()
        return error
    }
}

private final class ReconcileCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    func count() -> Int {
        lock.lock()
        let value = value
        lock.unlock()
        return value
    }
}

private final class ReconcileTwoWayState: @unchecked Sendable {
    private let lock = NSLock()
    private var summary = ReconcileExternalRemindersUseCase.ReconcileSummary()
    private var taskByID: [UUID: TaskDefinition]
    private var mappingByLocalID: [UUID: ExternalItemMapDefinition]
    private var mappingByExternalID: [String: ExternalItemMapDefinition]
    private var seenLocalIDs = Set<UUID>()

    init(tasks: [TaskDefinition], itemMappings: [ExternalItemMapDefinition]) {
        self.taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        self.mappingByLocalID = Dictionary(uniqueKeysWithValues: itemMappings.map { ($0.localEntityID, $0) })
        self.mappingByExternalID = Dictionary(uniqueKeysWithValues: itemMappings.map { ($0.externalItemID, $0) })
    }

    func mapping(externalID: String) -> ExternalItemMapDefinition? {
        lock.withLock { mappingByExternalID[externalID] }
    }

    func task(id: UUID) -> TaskDefinition? {
        lock.withLock { taskByID[id] }
    }

    func taskSnapshot() -> [TaskDefinition] {
        lock.withLock { Array(taskByID.values) }
    }

    func localMappingSnapshot() -> [ExternalItemMapDefinition] {
        lock.withLock { Array(mappingByLocalID.values) }
    }

    func unmappedTaskSnapshot() -> [TaskDefinition] {
        lock.withLock {
            taskByID.values.filter { task in
                mappingByLocalID[task.id] == nil && seenLocalIDs.contains(task.id) == false
            }
        }
    }

    func markSeen(_ id: UUID) {
        lock.withLock { _ = seenLocalIDs.insert(id) }
    }

    func recordTask(_ task: TaskDefinition) {
        lock.withLock { taskByID[task.id] = task }
    }

    func removeTask(id: UUID) {
        lock.withLock { _ = taskByID.removeValue(forKey: id) }
    }

    func recordMapping(_ mapping: ExternalItemMapDefinition, localID: UUID? = nil) {
        lock.withLock {
            mappingByLocalID[localID ?? mapping.localEntityID] = mapping
            mappingByExternalID[mapping.externalItemID] = mapping
        }
    }

    func incrementPulledFromExternal() {
        lock.withLock { summary.pulledFromExternal += 1 }
    }

    func incrementPushedToExternal() {
        lock.withLock { summary.pushedToExternal += 1 }
    }

    func incrementMappedExisting() {
        lock.withLock { summary.mappedExisting += 1 }
    }

    func incrementImportedNew() {
        lock.withLock { summary.importedNew += 1 }
    }

    func summarySnapshot() -> ReconcileExternalRemindersUseCase.ReconcileSummary {
        lock.withLock { summary }
    }
}

public final class ReconcileExternalRemindersUseCase: @unchecked Sendable {
    public struct ExternalReminderSnapshot: Sendable {
        public let provider: String
        public let localEntityType: String
        public let localEntityID: UUID
        public let externalItemID: String
        public let externalPersistentID: String?
        public let externalModifiedAt: Date?
        public let externalPayloadData: Data?

        /// Initializes a new instance.
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

    public struct ReconcileSummary: Equatable, Sendable {
        public var pulledFromExternal: Int
        public var pushedToExternal: Int
        public var mappedExisting: Int
        public var importedNew: Int

        /// Initializes a new instance.
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
    private let nodeID: String
    private let mergeEngine: ReminderMergeEngine

    /// Initializes a new instance.
    public init(
        externalRepository: ExternalSyncRepositoryProtocol,
        remindersProvider: AppleRemindersProviderProtocol? = nil,
        taskRepository: TaskDefinitionRepositoryProtocol? = nil,
        nodeID: String = ReconcileExternalRemindersUseCase.defaultNodeID(),
        mergeEngine: ReminderMergeEngine = ReminderMergeEngine()
    ) {
        self.externalRepository = externalRepository
        self.remindersProvider = remindersProvider
        self.taskRepository = taskRepository
        let normalizedNodeID = nodeID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.nodeID = normalizedNodeID.isEmpty ? ReconcileExternalRemindersUseCase.defaultNodeID() : normalizedNodeID
        self.mergeEngine = mergeEngine
    }

    /// Executes execute.
    public func execute(completion: @escaping @Sendable (Result<Int, Error>) -> Void) {
        guard V2FeatureFlags.remindersSyncEnabled else {
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

    /// Executes reconcile.
    public func reconcile(
        snapshots: [ExternalReminderSnapshot],
        completion: @escaping @Sendable (Result<Int, Error>) -> Void
    ) {
        guard V2FeatureFlags.remindersSyncEnabled else {
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
        let merged = ReconcileCounter()
        let errors = ReconcileErrorRecorder()

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
                    errors.record(error)
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
                        syncStateData: existing?.syncStateData ?? ReminderMergeState().encodedData(),
                        createdAt: existing?.createdAt ?? Date()
                    )

                    self.externalRepository.saveItemMapping(next) { saveResult in
                        lock.lock()
                        if case .failure(let error) = saveResult {
                            errors.record(error)
                        } else {
                            merged.increment()
                        }
                        lock.unlock()
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if let firstError = errors.firstError() {
                completion(.failure(firstError))
            } else {
                logWarning(
                    event: "reminders_mapping_reconcile_completed",
                    message: "Reminder mapping snapshots reconciled",
                    fields: ["merged_count": String(merged.count())]
                )
                completion(.success(merged.count()))
            }
        }
    }

    /// Executes reconcileProject.
    public func reconcileProject(
        projectID: UUID,
        completion: @escaping @Sendable (Result<ReconcileSummary, Error>) -> Void
    ) {
        guard V2FeatureFlags.remindersSyncEnabled else {
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

    /// Executes reconcileTwoWay.
    private func reconcileTwoWay(
        projectID: UUID,
        listID: String,
        externalReminders: [AppleReminderItemSnapshot],
        itemMappings: [ExternalItemMapDefinition],
        tasks: [TaskDefinition],
        remindersProvider: AppleRemindersProviderProtocol,
        taskRepository: TaskDefinitionRepositoryProtocol,
        completion: @escaping @Sendable (Result<ReconcileSummary, Error>) -> Void
    ) {
        let reconciliationState = ReconcileTwoWayState(tasks: tasks, itemMappings: itemMappings)
        let externalByID = Dictionary(uniqueKeysWithValues: externalReminders.map { ($0.itemID, $0) })

        let group = DispatchGroup()
        let errors = ReconcileErrorRecorder()

        for external in externalReminders {
            if let mapping = reconciliationState.mapping(externalID: external.itemID) {
                reconciliationState.markSeen(mapping.localEntityID)
                guard mapping.localEntityType == "task" else {
                    continue
                }

                let existingEnvelope = mergeEngine.decodeEnvelope(data: mapping.externalPayloadData)
                let priorKnown = existingEnvelope?.known
                let remoteKnown = knownFields(from: external)
                let remoteClock = remoteSyncClock(for: external, provider: mapping.provider)

                guard let localTask = reconciliationState.task(id: mapping.localEntityID) else {
                    group.enter()
                    remindersProvider.deleteReminder(itemID: external.itemID) { deleteResult in
                        if case .failure(let error) = deleteResult {
                            errors.record(error)
                        }
                        var updated = mapping
                        var state = ReminderMergeState.decode(from: mapping.syncStateData)
                        state.tombstoneClock = self.maxClock(state.tombstoneClock, remoteClock)
                        state.lastWriteClock = self.maxClock(state.lastWriteClock, remoteClock)
                        updated.syncStateData = state.encodedData()
                        let updatedMapping = updated
                        self.externalRepository.saveItemMapping(updatedMapping) { saveResult in
                            if case .failure(let error) = saveResult {
                                errors.record(error)
                            } else {
                                reconciliationState.recordMapping(updatedMapping, localID: mapping.localEntityID)
                            }
                            group.leave()
                        }
                    }
                    continue
                }

                let localKnown = knownFields(
                    from: localTask,
                    fallbackURL: priorKnown?.urlString,
                    alarmDates: priorKnown?.alarmDates ?? []
                )
                let mergeResult = mergeEngine.merge(
                    input: ReminderMergeEngine.MergeInput(
                        nodeID: nodeID,
                        provider: mapping.provider,
                        localObservedAt: localModificationDate(task: localTask),
                        remoteClock: remoteClock,
                        state: ReminderMergeState.decode(from: mapping.syncStateData),
                        previousKnown: priorKnown,
                        localKnown: localKnown,
                        remoteKnown: remoteKnown,
                        hasRemoteItem: true,
                        lastSeenRemoteModification: external.lastModifiedAt
                    )
                )

                var updatedMapDraft = mapping
                updatedMapDraft.syncStateData = mergeResult.state.encodedData()
                updatedMapDraft.lastSeenExternalModAt = external.lastModifiedAt
                let updatedMap = updatedMapDraft

                switch mergeResult.tombstoneDecision {
                case .applyDelete:
                    group.enter()
                    taskRepository.delete(id: localTask.id) { deleteLocalResult in
                        if case .failure(let error) = deleteLocalResult {
                            errors.record(error)
                        }
                        remindersProvider.deleteReminder(itemID: external.itemID) { deleteRemoteResult in
                            if case .failure(let error) = deleteRemoteResult {
                                errors.record(error)
                            }
                            let mapToPersist = updatedMap
                            self.externalRepository.saveItemMapping(mapToPersist) { saveResult in
                                if case .failure(let error) = saveResult {
                                    errors.record(error)
                                }
                                reconciliationState.removeTask(id: localTask.id)
                                reconciliationState.recordMapping(mapToPersist, localID: localTask.id)
                                group.leave()
                            }
                        }
                    }

                case .keep, .resurrect:
                    var localMergedTask = localTask
                    applyKnownFields(mergeResult.known, to: &localMergedTask)
                    localMergedTask.updatedAt = Date()

                    let shouldUpdateLocal = localKnown != mergeResult.known
                    let shouldUpdateRemote = remoteKnown != mergeResult.known
                    let remoteEnvelope = mergeEngine.decodeEnvelope(data: external.payloadData)
                    let payloadData = mergeEngine.encodeEnvelope(
                        known: mergeResult.known,
                        preferredPassthroughData: remoteEnvelope?.passthroughData
                            ?? (remoteEnvelope == nil ? external.payloadData : nil),
                        fallbackPassthroughData: existingEnvelope?.passthroughData
                            ?? (existingEnvelope == nil ? mapping.externalPayloadData : nil)
                    )

                    group.enter()

                    let persistMapAfterUpdate: @Sendable (
                        _ taskForMap: TaskDefinition,
                        _ mapForPersist: ExternalItemMapDefinition,
                        _ remoteSnapshot: AppleReminderItemSnapshot?
                    ) -> Void = { taskForMap, mapForPersist, remoteSnapshot in
                        var persistedMap = mapForPersist
                        persistedMap.externalPayloadData = remoteSnapshot.map {
                            self.payloadDataForPersistedRemote(
                                remote: $0,
                                fallbackPayloadData: payloadData
                            )
                        } ?? payloadData
                        if let remoteSnapshot {
                            persistedMap.externalItemID = remoteSnapshot.itemID
                            persistedMap.lastSeenExternalModAt = remoteSnapshot.lastModifiedAt
                        }
                        let mapToPersist = persistedMap
                        self.externalRepository.saveItemMapping(mapToPersist) { saveResult in
                            if case .failure(let error) = saveResult {
                                errors.record(error)
                            } else {
                                reconciliationState.recordMapping(mapToPersist, localID: taskForMap.id)
                            }
                            group.leave()
                        }
                    }

                    let updateRemoteIfNeeded: @Sendable (_ taskForRemote: TaskDefinition, _ mapForPersist: ExternalItemMapDefinition) -> Void = { taskForRemote, mapForPersist in
                        guard shouldUpdateRemote else {
                            persistMapAfterUpdate(taskForRemote, mapForPersist, nil)
                            return
                        }
                        let mergedSnapshot = self.snapshot(
                            from: taskForRemote,
                            listID: listID,
                            existingExternalID: external.itemID,
                            payloadData: payloadData,
                            alarmDates: mergeResult.known.alarmDates,
                            overrideURL: mergeResult.known.urlString
                        )
                        remindersProvider.upsertReminder(listID: listID, snapshot: mergedSnapshot) { upsertResult in
                            switch upsertResult {
                            case .failure(let error):
                                errors.record(error)
                                persistMapAfterUpdate(taskForRemote, mapForPersist, nil)
                            case .success(let persistedRemote):
                                reconciliationState.incrementPushedToExternal()
                                persistMapAfterUpdate(taskForRemote, mapForPersist, persistedRemote)
                            }
                        }
                    }

                    if shouldUpdateLocal {
                        taskRepository.update(localMergedTask) { updateResult in
                            switch updateResult {
                            case .failure(let error):
                                errors.record(error)
                                group.leave()
                            case .success(let updated):
                                reconciliationState.recordTask(updated)
                                if remoteKnown != mergeResult.known {
                                    reconciliationState.incrementPulledFromExternal()
                                }
                                updateRemoteIfNeeded(updated, updatedMap)
                            }
                        }
                    } else {
                        updateRemoteIfNeeded(localMergedTask, updatedMap)
                    }
                }
            } else {
                // Remote item has no mapping: map to existing local task or import as new.
                if let matched = matchTask(external: external, tasks: reconciliationState.taskSnapshot()) {
                    reconciliationState.markSeen(matched.id)
                    let newMap = ExternalItemMapDefinition(
                        id: UUID(),
                        provider: "apple_reminders",
                        localEntityType: "task",
                        localEntityID: matched.id,
                        externalItemID: external.itemID,
                        externalPersistentID: nil,
                        lastSeenExternalModAt: external.lastModifiedAt,
                        externalPayloadData: payloadDataForPersistedRemote(remote: external, fallbackPayloadData: external.payloadData),
                        syncStateData: initialMergeStateForRemote(external).encodedData(),
                        createdAt: Date()
                    )
                    group.enter()
                    self.externalRepository.saveItemMapping(newMap) { saveResult in
                        if case .failure(let error) = saveResult {
                            errors.record(error)
                        } else {
                            reconciliationState.incrementMappedExisting()
                            reconciliationState.recordMapping(newMap, localID: matched.id)
                        }
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
                            errors.record(error)
                            group.leave()
                        case .success(let created):
                            reconciliationState.markSeen(created.id)
                            reconciliationState.recordTask(created)
                            let newMap = ExternalItemMapDefinition(
                                id: UUID(),
                                provider: "apple_reminders",
                                localEntityType: "task",
                                localEntityID: created.id,
                                externalItemID: external.itemID,
                                externalPersistentID: nil,
                                lastSeenExternalModAt: external.lastModifiedAt,
                                externalPayloadData: self.payloadDataForPersistedRemote(remote: external, fallbackPayloadData: external.payloadData),
                                syncStateData: self.initialMergeStateForRemote(external).encodedData(),
                                createdAt: Date()
                            )
                            self.externalRepository.saveItemMapping(newMap) { saveResult in
                                if case .failure(let error) = saveResult {
                                    errors.record(error)
                                } else {
                                    reconciliationState.incrementImportedNew()
                                    reconciliationState.recordMapping(newMap, localID: created.id)
                                }
                                group.leave()
                            }
                        }
                    }
                }
            }
        }

        // Remote delete/tombstone handling for mapped items that disappeared remotely.
        for mapping in reconciliationState.localMappingSnapshot() where externalByID[mapping.externalItemID] == nil {
            guard mapping.localEntityType == "task" else { continue }
            let existingEnvelope = mergeEngine.decodeEnvelope(data: mapping.externalPayloadData)
            let remoteClock = remoteSyncClock(for: mapping, provider: mapping.provider)
            let localTask = reconciliationState.task(id: mapping.localEntityID)
            let priorKnown = existingEnvelope?.known
            let localKnown: ReminderMergeEnvelope.KnownFields
            if let localTask {
                localKnown = knownFields(
                    from: localTask,
                    fallbackURL: existingEnvelope?.known.urlString,
                    alarmDates: existingEnvelope?.known.alarmDates ?? []
                )
            } else if let priorKnown {
                // Local deletion should not synthesize a new local write for every scalar field.
                localKnown = priorKnown
            } else {
                localKnown = knownFields(
                    from: nil,
                    fallbackURL: existingEnvelope?.known.urlString,
                    alarmDates: existingEnvelope?.known.alarmDates ?? []
                )
            }

            let mergeResult = mergeEngine.merge(
                input: ReminderMergeEngine.MergeInput(
                    nodeID: nodeID,
                    provider: mapping.provider,
                    localObservedAt: localTask.map { self.localModificationDate(task: $0) } ?? Date(),
                    remoteClock: remoteClock,
                    state: ReminderMergeState.decode(from: mapping.syncStateData),
                    previousKnown: priorKnown,
                    localKnown: localKnown,
                    remoteKnown: priorKnown ?? localKnown,
                    hasRemoteItem: false,
                    lastSeenRemoteModification: mapping.lastSeenExternalModAt
                )
            )

            var updatedMapDraft = mapping
            updatedMapDraft.syncStateData = mergeResult.state.encodedData()
            let updatedMap = updatedMapDraft

            switch mergeResult.tombstoneDecision {
            case .applyDelete:
                guard let localTask else {
                    group.enter()
                    self.externalRepository.saveItemMapping(updatedMap) { saveResult in
                        if case .failure(let error) = saveResult {
                            errors.record(error)
                        }
                        group.leave()
                    }
                    continue
                }
                group.enter()
                taskRepository.delete(id: localTask.id) { deleteResult in
                    if case .failure(let error) = deleteResult {
                        errors.record(error)
                    }
                    let mapToPersist = updatedMap
                    self.externalRepository.saveItemMapping(mapToPersist) { saveResult in
                        if case .failure(let error) = saveResult {
                            errors.record(error)
                        } else {
                            reconciliationState.removeTask(id: localTask.id)
                        }
                        group.leave()
                    }
                }

            case .resurrect:
                guard let localTask else {
                    group.enter()
                    self.externalRepository.saveItemMapping(updatedMap) { saveResult in
                        if case .failure(let error) = saveResult {
                            errors.record(error)
                        }
                        group.leave()
                    }
                    continue
                }
                group.enter()
                let payloadData = payloadDataForLocalTask(
                    task: localTask,
                    alarmDates: mergeResult.known.alarmDates,
                    existingPayloadData: mapping.externalPayloadData,
                    overrideURL: mergeResult.known.urlString
                )
                let localSnapshot = snapshot(
                    from: localTask,
                    listID: listID,
                    existingExternalID: "",
                    payloadData: payloadData,
                    alarmDates: mergeResult.known.alarmDates,
                    overrideURL: mergeResult.known.urlString
                )
                remindersProvider.upsertReminder(listID: listID, snapshot: localSnapshot) { upsertResult in
                    switch upsertResult {
                    case .failure(let error):
                        errors.record(error)
                        group.leave()
                    case .success(let remote):
                        var persistedMap = updatedMap
                        persistedMap.externalItemID = remote.itemID
                        persistedMap.lastSeenExternalModAt = remote.lastModifiedAt
                        persistedMap.externalPayloadData = self.payloadDataForPersistedRemote(
                            remote: remote,
                            fallbackPayloadData: localSnapshot.payloadData
                        )
                        let mapToPersist = persistedMap
                        self.externalRepository.saveItemMapping(mapToPersist) { saveResult in
                            if case .failure(let error) = saveResult {
                                errors.record(error)
                            } else {
                                reconciliationState.incrementPushedToExternal()
                                reconciliationState.recordMapping(mapToPersist)
                            }
                            group.leave()
                        }
                    }
                }

            case .keep:
                group.enter()
                self.externalRepository.saveItemMapping(updatedMap) { saveResult in
                    if case .failure(let error) = saveResult {
                        errors.record(error)
                    }
                    group.leave()
                }
            }
        }

        // Push local tasks that are still unmapped.
        for task in reconciliationState.unmappedTaskSnapshot() {
            group.enter()
            let payloadData = payloadDataForLocalTask(
                task: task,
                alarmDates: [],
                existingPayloadData: nil,
                overrideURL: nil
            )
            let localSnapshot = snapshot(
                from: task,
                listID: listID,
                existingExternalID: "",
                payloadData: payloadData,
                alarmDates: [],
                overrideURL: nil
            )
            remindersProvider.upsertReminder(listID: listID, snapshot: localSnapshot) { upsertResult in
                switch upsertResult {
                case .failure(let error):
                    errors.record(error)
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
                        externalPayloadData: self.payloadDataForPersistedRemote(remote: remote, fallbackPayloadData: localSnapshot.payloadData),
                        syncStateData: self.initialMergeStateForLocal(task).encodedData(),
                        createdAt: Date()
                    )
                    self.externalRepository.saveItemMapping(mapping) { saveResult in
                        if case .failure(let error) = saveResult {
                            errors.record(error)
                        } else {
                            reconciliationState.incrementPushedToExternal()
                            reconciliationState.recordMapping(mapping)
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if let firstError = errors.firstError() {
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
                let summary = reconciliationState.summarySnapshot()
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

    /// Executes matchTask.
    private func matchTask(external: AppleReminderItemSnapshot, tasks: [TaskDefinition]) -> TaskDefinition? {
        let normalized = normalize(external.title)
        return tasks.first { task in
            guard normalize(task.title) == normalized else { return false }
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

    /// Executes localModificationDate.
    private func localModificationDate(task: TaskDefinition) -> Date {
        [task.updatedAt, task.dateCompleted, task.dueDate, task.dateAdded]
            .compactMap { $0 }
            .max() ?? task.updatedAt
    }

    /// Executes localSyncClock.
    private func localSyncClock(task: TaskDefinition, base: SyncClock?) -> SyncClock {
        let observedMillis = Int64(localModificationDate(task: task).timeIntervalSince1970 * 1_000)
        return SyncClock.next(nodeID: nodeID, base: base, observedMillis: observedMillis)
    }

    /// Executes remoteSyncClock.
    private func remoteSyncClock(for reminder: AppleReminderItemSnapshot, provider: String) -> SyncClock {
        let modifiedAt = reminder.lastModifiedAt ?? Date()
        let millis = Int64(modifiedAt.timeIntervalSince1970 * 1_000)
        return SyncClock(
            physicalMillis: millis,
            logicalCounter: 0,
            nodeID: "remote.\(provider)"
        )
    }

    /// Executes remoteSyncClock.
    private func remoteSyncClock(for mapping: ExternalItemMapDefinition, provider: String) -> SyncClock {
        let modifiedAt = mapping.lastSeenExternalModAt ?? Date()
        let millis = Int64(modifiedAt.timeIntervalSince1970 * 1_000)
        return SyncClock(
            physicalMillis: millis,
            logicalCounter: 0,
            nodeID: "remote.\(provider)"
        )
    }

    /// Executes markAllScalarClocks.
    private func markAllScalarClocks(state: inout ReminderMergeState, clock: SyncClock) {
        for field in ReminderScalarField.allCases {
            state.fieldClocks[field] = clock
        }
    }

    /// Executes maxClock.
    private func maxClock(_ lhs: SyncClock?, _ rhs: SyncClock?) -> SyncClock {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return lhs > rhs ? lhs : rhs
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return SyncClock(physicalMillis: 0, logicalCounter: 0, nodeID: nodeID)
        }
    }

    /// Executes decodeMergeEnvelope.
    private func decodeMergeEnvelope(data: Data?) -> ReminderMergeEnvelope? {
        mergeEngine.decodeEnvelope(data: data)
    }

    /// Executes encodedMergeEnvelope.
    private func encodedMergeEnvelope(
        known: ReminderMergeEnvelope.KnownFields,
        preferredPassthroughData: Data?,
        fallbackPassthroughData: Data?
    ) -> Data? {
        mergeEngine.encodeEnvelope(
            known: known,
            preferredPassthroughData: preferredPassthroughData,
            fallbackPassthroughData: fallbackPassthroughData
        )
    }

    /// Executes payloadDataForLocalTask.
    private func payloadDataForLocalTask(
        task: TaskDefinition,
        alarmDates: [Date],
        existingPayloadData: Data?,
        overrideURL: String?
    ) -> Data? {
        let existingEnvelope = decodeMergeEnvelope(data: existingPayloadData)
        let known = ReminderMergeEnvelope.KnownFields(
            title: task.title,
            notes: task.details,
            dueDate: task.dueDate,
            completionDate: task.dateCompleted,
            isCompleted: task.isComplete,
            priority: eventKitPriority(from: task.priority),
            urlString: overrideURL ?? existingEnvelope?.known.urlString,
            alarmDates: alarmDates
        )
        return encodedMergeEnvelope(
            known: known,
            preferredPassthroughData: existingEnvelope?.passthroughData,
            fallbackPassthroughData: existingEnvelope == nil ? existingPayloadData : nil
        )
    }

    /// Executes payloadDataForPersistedRemote.
    private func payloadDataForPersistedRemote(
        remote: AppleReminderItemSnapshot,
        fallbackPayloadData: Data?
    ) -> Data? {
        let remoteEnvelope = decodeMergeEnvelope(data: remote.payloadData)
        let fallbackEnvelope = decodeMergeEnvelope(data: fallbackPayloadData)
        let known = ReminderMergeEnvelope.KnownFields(
            title: remote.title,
            notes: remote.notes,
            dueDate: remote.dueDate,
            completionDate: remote.completionDate,
            isCompleted: remote.isCompleted,
            priority: remote.priority,
            urlString: remote.urlString ?? remoteEnvelope?.known.urlString ?? fallbackEnvelope?.known.urlString,
            alarmDates: remote.alarmDates
        )
        return encodedMergeEnvelope(
            known: known,
            preferredPassthroughData: remoteEnvelope?.passthroughData
                ?? (remoteEnvelope == nil ? remote.payloadData : nil),
            fallbackPassthroughData: fallbackEnvelope?.passthroughData
                ?? (fallbackEnvelope == nil ? fallbackPayloadData : nil)
        )
    }

    /// Executes initialMergeStateForRemote.
    private func initialMergeStateForRemote(_ remote: AppleReminderItemSnapshot) -> ReminderMergeState {
        let clock = remoteSyncClock(for: remote, provider: "apple_reminders")
        var state = ReminderMergeState(lastWriteClock: clock)
        markAllScalarClocks(state: &state, clock: clock)
        for key in remote.alarmDates.map(ReminderMergeEngine.alarmDateKey) {
            state.alarmAddSet[key] = clock
        }
        return state
    }

    /// Executes initialMergeStateForLocal.
    private func initialMergeStateForLocal(_ task: TaskDefinition) -> ReminderMergeState {
        let clock = localSyncClock(task: task, base: nil)
        var state = ReminderMergeState(lastWriteClock: clock)
        markAllScalarClocks(state: &state, clock: clock)
        return state
    }

    /// Executes snapshot.
    private func snapshot(
        from task: TaskDefinition,
        listID: String,
        existingExternalID: String,
        payloadData: Data?,
        alarmDates: [Date],
        overrideURL: String?
    ) -> AppleReminderItemSnapshot {
        let payloadEnvelope = decodeMergeEnvelope(data: payloadData)
        return AppleReminderItemSnapshot(
            itemID: existingExternalID,
            calendarID: listID,
            title: task.title,
            notes: task.details,
            dueDate: task.dueDate,
            completionDate: task.dateCompleted,
            isCompleted: task.isComplete,
            priority: eventKitPriority(from: task.priority),
            urlString: overrideURL ?? payloadEnvelope?.known.urlString,
            alarmDates: alarmDates,
            lastModifiedAt: nil,
            payloadData: payloadData
        )
    }

    /// Executes knownFields.
    private func knownFields(
        from task: TaskDefinition?,
        fallbackURL: String?,
        alarmDates: [Date]
    ) -> ReminderMergeEnvelope.KnownFields {
        guard let task else {
            return ReminderMergeEnvelope.KnownFields(
                title: "",
                notes: nil,
                dueDate: nil,
                completionDate: nil,
                isCompleted: false,
                priority: 0,
                urlString: fallbackURL,
                alarmDates: alarmDates
            )
        }
        return ReminderMergeEnvelope.KnownFields(
            title: task.title,
            notes: task.details,
            dueDate: task.dueDate,
            completionDate: task.dateCompleted,
            isCompleted: task.isComplete,
            priority: eventKitPriority(from: task.priority),
            urlString: fallbackURL,
            alarmDates: alarmDates
        )
    }

    /// Executes knownFields.
    private func knownFields(from reminder: AppleReminderItemSnapshot) -> ReminderMergeEnvelope.KnownFields {
        ReminderMergeEnvelope.KnownFields(
            title: reminder.title,
            notes: reminder.notes,
            dueDate: reminder.dueDate,
            completionDate: reminder.completionDate,
            isCompleted: reminder.isCompleted,
            priority: reminder.priority,
            urlString: reminder.urlString,
            alarmDates: reminder.alarmDates
        )
    }

    /// Executes applyKnownFields.
    private func applyKnownFields(_ known: ReminderMergeEnvelope.KnownFields, to task: inout TaskDefinition) {
        task.title = known.title
        task.details = known.notes
        task.dueDate = known.dueDate
        task.isComplete = known.isCompleted
        task.dateCompleted = known.completionDate
        task.priority = priorityFromEventKit(known.priority)
    }

    /// Executes defaultNodeID.
    public static func defaultNodeID() -> String {
        let defaults = UserDefaults.standard
        let key = "lifeboard.sync.node_id"
        if let existing = defaults.string(forKey: key), existing.isEmpty == false {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: key)
        return generated
    }

    /// Executes priorityFromEventKit.
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

    /// Executes eventKitPriority.
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

    /// Executes normalize.
    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Executes syncDisabledError.
    private func syncDisabledError() -> Error {
        NSError(
            domain: "ReconcileExternalRemindersUseCase",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "Apple Reminders sync is disabled by feature flag"]
        )
    }
}
