import CoreData
import Foundation

struct TaskerPersistentStoreLocation: Equatable {
    let canonicalDirectoryURL: URL
    let legacyDirectoryURL: URL

    var cloudStoreURL: URL {
        canonicalDirectoryURL.appendingPathComponent(TaskerPersistentStoreLocationService.cloudStoreFileName)
    }

    var localStoreURL: URL {
        canonicalDirectoryURL.appendingPathComponent(TaskerPersistentStoreLocationService.localStoreFileName)
    }

    var usesSharedAppGroupStore: Bool {
        canonicalDirectoryURL.standardizedFileURL != legacyDirectoryURL.standardizedFileURL
    }
}

struct TaskerPersistentStoreMigrationResult: Equatable {
    let didMigrateLegacyStore: Bool
    let detectedStoreConflict: Bool
    let migratedFileNames: [String]
}

final class TaskerPersistentStoreLocationService {
    static let cloudStoreFileName = "TaskModelV3-cloud.sqlite"
    static let localStoreFileName = "TaskModelV3-local.sqlite"

    private let fileManager: FileManager
    private let appGroupContainerURLProvider: () -> URL?
    private let legacyStoreDirectoryURLProvider: () -> URL

    init(
        fileManager: FileManager = .default,
        appGroupContainerURLProvider: @escaping () -> URL? = { AppGroupConstants.containerURL },
        legacyStoreDirectoryURLProvider: @escaping () -> URL = { NSPersistentContainer.defaultDirectoryURL() }
    ) {
        self.fileManager = fileManager
        self.appGroupContainerURLProvider = appGroupContainerURLProvider
        self.legacyStoreDirectoryURLProvider = legacyStoreDirectoryURLProvider
    }

    func resolvedV3StoreLocation() -> TaskerPersistentStoreLocation {
        let legacyDirectoryURL = legacyStoreDirectoryURLProvider().standardizedFileURL
        let canonicalDirectoryURL = appGroupContainerURLProvider()?.standardizedFileURL ?? legacyDirectoryURL
        return TaskerPersistentStoreLocation(
            canonicalDirectoryURL: canonicalDirectoryURL,
            legacyDirectoryURL: legacyDirectoryURL
        )
    }

    func prepareSharedStoreLocationForBootstrap() throws -> TaskerPersistentStoreMigrationResult {
        let location = resolvedV3StoreLocation()
        try fileManager.createDirectory(
            at: location.canonicalDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return try migrateLegacySplitStoresIfNeeded(location: location)
    }

    func allKnownCutoverStoreFileNames() -> [String] {
        [
            "TaskModelV2-cloud.sqlite",
            "TaskModelV2-cloud.sqlite-wal",
            "TaskModelV2-cloud.sqlite-shm",
            "TaskModelV2-local.sqlite",
            "TaskModelV2-local.sqlite-wal",
            "TaskModelV2-local.sqlite-shm"
        ] + v3SplitStoreFileNames() + [
            "TaskModelV3-unified.sqlite",
            "TaskModelV3-unified.sqlite-wal",
            "TaskModelV3-unified.sqlite-shm"
        ]
    }

    func v3SplitStoreFileNames() -> [String] {
        [
            Self.cloudStoreFileName,
            "\(Self.cloudStoreFileName)-wal",
            "\(Self.cloudStoreFileName)-shm",
            Self.localStoreFileName,
            "\(Self.localStoreFileName)-wal",
            "\(Self.localStoreFileName)-shm"
        ]
    }

    func allKnownCutoverStoreURLs() -> [URL] {
        let location = resolvedV3StoreLocation()
        return uniqueURLs(
            for: allKnownCutoverStoreFileNames(),
            directories: [
                location.canonicalDirectoryURL,
                location.legacyDirectoryURL
            ]
        )
    }

    func activeV3StoreURLs() -> [URL] {
        let location = resolvedV3StoreLocation()
        return v3SplitStoreFileNames().map { location.canonicalDirectoryURL.appendingPathComponent($0) }
    }

    func quarantineActiveV3StoreFiles(reason: String) throws -> URL? {
        let existingURLs = activeV3StoreURLs().filter { fileManager.fileExists(atPath: $0.path) }
        guard existingURLs.isEmpty == false else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let timestamp = formatter.string(from: Date())

        let location = resolvedV3StoreLocation()
        let backupRoot = location.canonicalDirectoryURL.appendingPathComponent(
            "TaskerStoreQuarantine",
            isDirectory: true
        )
        let backupDirectory = backupRoot.appendingPathComponent(
            "\(timestamp)-\(sanitizePathComponent(reason))",
            isDirectory: true
        )

        try fileManager.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        for sourceURL in existingURLs {
            let destinationURL = backupDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }

        return backupDirectory
    }

    func clearActiveV3StoreFiles() {
        for fileURL in activeV3StoreURLs() where fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                logWarning(
                    event: "v3_store_clear_after_quarantine_failed",
                    message: "Failed to clear active V3 split store file after quarantine",
                    fields: [
                        "file": fileURL.lastPathComponent,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    func wipeKnownCutoverStoreFiles() {
        for fileURL in allKnownCutoverStoreURLs() where fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                logWarning(
                    event: "v3_store_file_delete_failed",
                    message: "Failed to delete V3 cutover persistent store file",
                    fields: [
                        "file": fileURL.lastPathComponent,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    private func migrateLegacySplitStoresIfNeeded(
        location: TaskerPersistentStoreLocation
    ) throws -> TaskerPersistentStoreMigrationResult {
        guard location.usesSharedAppGroupStore else {
            return TaskerPersistentStoreMigrationResult(
                didMigrateLegacyStore: false,
                detectedStoreConflict: false,
                migratedFileNames: []
            )
        }

        let canonicalURLs = v3SplitStoreFileNames().map {
            location.canonicalDirectoryURL.appendingPathComponent($0)
        }
        let legacyURLs = v3SplitStoreFileNames().map {
            location.legacyDirectoryURL.appendingPathComponent($0)
        }

        let existingCanonicalURLs = canonicalURLs.filter { fileManager.fileExists(atPath: $0.path) }
        let existingLegacyURLs = legacyURLs.filter { fileManager.fileExists(atPath: $0.path) }

        guard existingLegacyURLs.isEmpty == false else {
            return TaskerPersistentStoreMigrationResult(
                didMigrateLegacyStore: false,
                detectedStoreConflict: false,
                migratedFileNames: []
            )
        }

        if existingCanonicalURLs.isEmpty == false {
            logWarning(
                event: "persistent_store_migration_conflict",
                message: "Detected legacy V3 split stores alongside shared app-group stores; keeping app-group copy",
                fields: [
                    "canonical_dir": location.canonicalDirectoryURL.path,
                    "legacy_dir": location.legacyDirectoryURL.path,
                    "canonical_files": existingCanonicalURLs.map(\.lastPathComponent).sorted().joined(separator: ","),
                    "legacy_files": existingLegacyURLs.map(\.lastPathComponent).sorted().joined(separator: ",")
                ]
            )
            return TaskerPersistentStoreMigrationResult(
                didMigrateLegacyStore: false,
                detectedStoreConflict: true,
                migratedFileNames: []
            )
        }

        var migratedFileNames: [String] = []
        for sourceURL in existingLegacyURLs {
            let destinationURL = location.canonicalDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            migratedFileNames.append(sourceURL.lastPathComponent)
        }

        return TaskerPersistentStoreMigrationResult(
            didMigrateLegacyStore: migratedFileNames.isEmpty == false,
            detectedStoreConflict: false,
            migratedFileNames: migratedFileNames.sorted()
        )
    }

    private func uniqueURLs(for fileNames: [String], directories: [URL]) -> [URL] {
        var seen: Set<URL> = []
        var urls: [URL] = []
        for directoryURL in directories {
            for fileName in fileNames {
                let fileURL = directoryURL.appendingPathComponent(fileName).standardizedFileURL
                guard seen.insert(fileURL).inserted else { continue }
                urls.append(fileURL)
            }
        }
        return urls
    }

    private func sanitizePathComponent(_ rawValue: String) -> String {
        let result = rawValue.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        return result.isEmpty ? "reason" : result
    }
}

struct TaskerPersistentRuntimeInitializer {
    func initialize(container: NSPersistentCloudKitContainer) {
        let context = container.viewContext
        context.performAndWait {
            do {
                let repairReport = try LifeAreaIdentityRepair.repair(in: context)
                if repairReport.merged > 0 || repairReport.normalized > 0 {
                    logWarning(
                        event: "life_area_identity_repair_applied",
                        message: "Repaired duplicate or malformed life area rows during startup defaults",
                        fields: [
                            "scanned": String(repairReport.scanned),
                            "normalized": String(repairReport.normalized),
                            "merged": String(repairReport.merged),
                            "duplicate_groups": String(repairReport.duplicateGroups),
                            "repointed_projects": String(repairReport.repointedProjects),
                            "repointed_tasks": String(repairReport.repointedTasks),
                            "repointed_habits": String(repairReport.repointedHabits)
                        ]
                    )
                }

                let lifeArea: NSManagedObject
                let normalizedGeneralKey = LifeAreaIdentityRepair.normalizedNameKey("General")
                if let canonicalGeneralID = repairReport.canonicalIDsByNormalizedName[normalizedGeneralKey],
                   let existing = try fetchLifeArea(id: canonicalGeneralID, in: context) {
                    lifeArea = existing
                } else if let existing = try fetchGeneralLifeArea(in: context) {
                    lifeArea = existing
                } else {
                    let created = NSEntityDescription.insertNewObject(forEntityName: "LifeArea", into: context)
                    created.setValue(UUID(), forKey: "id")
                    created.setValue("General", forKey: "name")
                    created.setValue(LifeAreaConstants.generalSeedColor, forKey: "color")
                    created.setValue("square.grid.2x2", forKey: "icon")
                    created.setValue(Int32(0), forKey: "sortOrder")
                    created.setValue(false, forKey: "isArchived")
                    created.setValue(Date(), forKey: "createdAt")
                    created.setValue(Date(), forKey: "updatedAt")
                    created.setValue(Int32(1), forKey: "version")
                    lifeArea = created
                }

                let inboxRequest = NSFetchRequest<NSManagedObject>(entityName: "Project")
                inboxRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "id == %@", ProjectConstants.inboxProjectID as CVarArg),
                    NSPredicate(format: "isInbox == YES"),
                    NSPredicate(format: "isDefault == YES"),
                    NSPredicate(format: "name ==[c] %@", ProjectConstants.inboxProjectName)
                ])
                inboxRequest.fetchLimit = 1
                let inbox = try context.fetch(inboxRequest).first
                    ?? NSEntityDescription.insertNewObject(forEntityName: "Project", into: context)
                inbox.setValue(ProjectConstants.inboxProjectID, forKey: "id")
                inbox.setValue(lifeArea.value(forKey: "id") as? UUID, forKey: "lifeAreaID")
                inbox.setValue(ProjectConstants.inboxProjectName, forKey: "name")
                inbox.setValue(ProjectConstants.inboxProjectDescription, forKey: "projectDescription")
                inbox.setValue(true, forKey: "isInbox")
                inbox.setValue(true, forKey: "isDefault")
                inbox.setValue(false, forKey: "isArchived")
                inbox.setValue(false, forKey: "isFavorite")
                inbox.setValue("gray", forKey: "color")
                inbox.setValue("inbox", forKey: "icon")
                inbox.setValue("active", forKey: "status")
                inbox.setValue(Int32(1), forKey: "priority")
                if inbox.value(forKey: "createdDate") == nil {
                    inbox.setValue(Date(), forKey: "createdDate")
                }
                inbox.setValue(Date(), forKey: "modifiedDate")
                inbox.setValue(Date(), forKey: "updatedAt")

                try backfillTaskLifeAreaIDsIfNeeded(in: context)

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                logError(
                    event: "v3_default_seed_failed",
                    message: "Failed to seed V3 default life area/inbox",
                    fields: ["error": error.localizedDescription]
                )
            }
        }
    }

    private func fetchGeneralLifeArea(in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
        request.predicate = NSPredicate(format: "name ==[c] %@", "General")
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchLifeArea(id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func backfillTaskLifeAreaIDsIfNeeded(in context: NSManagedObjectContext) throws {
        guard
            let taskEntity = NSEntityDescription.entity(forEntityName: "TaskDefinition", in: context),
            taskEntity.attributesByName["lifeAreaID"] != nil
        else {
            return
        }

        let projectRequest = NSFetchRequest<NSManagedObject>(entityName: "Project")
        let projects = try context.fetch(projectRequest)
        var lifeAreaByProjectID: [UUID: UUID] = [:]
        for project in projects {
            let projectID = project.value(forKey: "id") as? UUID
            let lifeAreaID = project.value(forKey: "lifeAreaID") as? UUID
            if let projectID, let lifeAreaID {
                lifeAreaByProjectID[projectID] = lifeAreaID
            }
        }

        guard lifeAreaByProjectID.isEmpty == false else {
            return
        }

        let taskRequest = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
        taskRequest.predicate = NSPredicate(format: "lifeAreaID == nil")
        let tasks = try context.fetch(taskRequest)

        var updated = 0
        for task in tasks {
            guard
                let projectID = task.value(forKey: "projectID") as? UUID,
                let lifeAreaID = lifeAreaByProjectID[projectID]
            else {
                continue
            }
            task.setValue(lifeAreaID, forKey: "lifeAreaID")
            updated += 1
        }

        if updated > 0 {
            logWarning(
                event: "task_life_area_backfill_applied",
                message: "Backfilled TaskDefinition.lifeAreaID from project linkage",
                fields: ["updated_count": String(updated)]
            )
        }
    }
}

struct TaskerPersistentStoreBootstrapResult {
    let state: PersistentBootstrapState
    let syncMode: PersistentSyncMode
    let syncModeSource: String
    let shouldMarkStoreEpoch: Bool
}

final class TaskerPersistentStoreBootstrapService {
    static let defaultCloudKitContainerIdentifier = "iCloud.TaskerCloudKitV3"

    private let expectedStoreConfigurations: Set<String>
    private let localOnlyConfiguration: Set<String>
    let storeLocationService: TaskerPersistentStoreLocationService
    let cloudKitContainerIdentifier: String

    init(
        expectedStoreConfigurations: Set<String> = ["CloudSync", "LocalOnly"],
        localOnlyConfiguration: Set<String> = ["LocalOnly"],
        storeLocationService: TaskerPersistentStoreLocationService = TaskerPersistentStoreLocationService(),
        cloudKitContainerIdentifier: String = TaskerPersistentStoreBootstrapService.defaultCloudKitContainerIdentifier
    ) {
        self.expectedStoreConfigurations = expectedStoreConfigurations
        self.localOnlyConfiguration = localOnlyConfiguration
        self.storeLocationService = storeLocationService
        self.cloudKitContainerIdentifier = cloudKitContainerIdentifier
    }

    func makeV3PersistentContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "TaskModelV3")
        let cloudKitMode = cloudKitMirroringMode()

        let location = storeLocationService.resolvedV3StoreLocation()
        let cloudURL = location.cloudStoreURL
        let localURL = location.localStoreURL

        let cloudDescription = NSPersistentStoreDescription(url: cloudURL)
        cloudDescription.configuration = "CloudSync"
        if case .enabled = cloudKitMode {
            cloudDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudKitContainerIdentifier
            )
        } else {
            logWarning(
                event: "cloudkit_mirroring_disabled",
                message: "CloudKit entitlement unavailable at runtime; using local Core Data store for CloudSync configuration",
                fields: [
                    "reason": cloudKitMode.reason,
                    "configuration": "CloudSync"
                ]
            )
        }
        cloudDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        cloudDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        cloudDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        cloudDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        let localDescription = NSPersistentStoreDescription(url: localURL)
        localDescription.configuration = "LocalOnly"
        localDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        localDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        localDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        localDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container.persistentStoreDescriptions = [cloudDescription, localDescription]
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    func makeV3LocalOnlyWriteClosedContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "TaskModelV3")

        let location = storeLocationService.resolvedV3StoreLocation()
        let localURL = location.localStoreURL
        let localDescription = NSPersistentStoreDescription(url: localURL)
        localDescription.configuration = "LocalOnly"
        localDescription.cloudKitContainerOptions = nil
        localDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        localDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        localDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        localDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container.persistentStoreDescriptions = [localDescription]
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    func cloudKitMirroringMode(
        context: CloudKitRuntimeContext = .current()
    ) -> CloudKitMirroringMode {
        if context.environment["XCTestConfigurationFilePath"] != nil ||
            context.environment["XCInjectBundleInto"] != nil {
            return .disabled(reason: "xctest_runtime")
        }

        if context.isSimulator {
            return .disabled(reason: "simulator_runtime")
        }

        #if DEBUG
            if context.arguments.contains("-TASKER_DISABLE_CLOUDKIT") {
                return .disabled(reason: "launch_arg_disable_cloudkit")
            }
        #endif

        return .enabled
    }

    func bootstrapV3PersistentContainer() -> TaskerPersistentStoreBootstrapResult {
        do {
            let migrationResult = try storeLocationService.prepareSharedStoreLocationForBootstrap()
            if migrationResult.didMigrateLegacyStore {
                let location = storeLocationService.resolvedV3StoreLocation()
                logWarning(
                    event: "persistent_store_migrated_to_app_group",
                    message: "Moved legacy V3 Core Data stores into the shared app-group container",
                    fields: [
                        "destination_dir": location.canonicalDirectoryURL.path,
                        "legacy_dir": location.legacyDirectoryURL.path,
                        "files": migrationResult.migratedFileNames.joined(separator: ",")
                    ]
                )
            }
        } catch {
            logError(
                event: "persistent_store_prepare_failed",
                message: "Could not prepare the shared V3 persistent store location",
                fields: [
                    "error": error.localizedDescription
                ]
            )
            return TaskerPersistentStoreBootstrapResult(
                state: .failed("Tasker could not prepare local storage. Please relaunch the app."),
                syncMode: .writeClosed(reason: "persistent_store_prepare_failed"),
                syncModeSource: "bootstrap_prepare_failed",
                shouldMarkStoreEpoch: false
            )
        }

        let initialContainer = makeV3PersistentContainer()
        let initialReport = loadPersistentStoresAndReport(container: initialContainer, phase: "initial")
        let initialHealthy = initialReport.errors.isEmpty && hasExpectedConfigurations(initialReport)

        if initialHealthy {
            return TaskerPersistentStoreBootstrapResult(
                state: .ready(initialContainer),
                syncMode: .fullSync,
                syncModeSource: "bootstrap_initial",
                shouldMarkStoreEpoch: true
            )
        }

        let missingConfigurations = expectedStoreConfigurations.subtracting(initialReport.loadedConfigurations)
        logError(
            event: "persistent_store_bootstrap_split_failed",
            message: "Split CloudSync/LocalOnly bootstrap failed; entering write-closed fallback attempt",
            fields: [
                "loaded_configurations": initialReport.loadedConfigurations.sorted().joined(separator: ","),
                "missing_configurations": missingConfigurations.sorted().joined(separator: ","),
                "error_count": String(initialReport.errors.count),
                "errors": initialReport.errors.map { "\($0.domain):\($0.code)" }.joined(separator: ", ")
            ]
        )

        unloadPersistentStores(initialContainer)
        let writeClosedContainer = makeV3LocalOnlyWriteClosedContainer()
        let writeClosedReport = loadPersistentStoresAndReport(
            container: writeClosedContainer,
            phase: "write_closed_fallback"
        )
        let writeClosedHealthy = writeClosedReport.errors.isEmpty && hasLocalOnlyConfiguration(writeClosedReport)
        if writeClosedHealthy {
            let fallbackReason = makeWriteClosedReason(
                initialReport: initialReport,
                missingConfigurations: missingConfigurations
            )
            logWarning(
                event: "persistent_sync_write_closed_enabled",
                message: "CloudSync store unavailable; app launched in write-closed local-read mode",
                fields: [
                    "reason": fallbackReason,
                    "loaded_configurations": writeClosedReport.loadedConfigurations.sorted().joined(separator: ",")
                ]
            )
            return TaskerPersistentStoreBootstrapResult(
                state: .ready(writeClosedContainer),
                syncMode: .writeClosed(reason: fallbackReason),
                syncModeSource: "bootstrap_write_closed",
                shouldMarkStoreEpoch: true
            )
        }

        let failureMessage = "Tasker could not initialize local storage. Please relaunch the app or recover from iCloud."
        logError(
            event: "persistent_store_bootstrap_failed_unreadable",
            message: "Persistent store bootstrap failed for split and write-closed fallback topologies",
            fields: [
                "initial_loaded_configurations": initialReport.loadedConfigurations.sorted().joined(separator: ","),
                "initial_error_count": String(initialReport.errors.count),
                "initial_errors": initialReport.errors.map { "\($0.domain):\($0.code)" }.joined(separator: ", "),
                "fallback_loaded_configurations": writeClosedReport.loadedConfigurations.sorted().joined(separator: ","),
                "fallback_error_count": String(writeClosedReport.errors.count),
                "fallback_errors": writeClosedReport.errors.map { "\($0.domain):\($0.code)" }.joined(separator: ", ")
            ]
        )
        return TaskerPersistentStoreBootstrapResult(
            state: .failed(failureMessage),
            syncMode: .writeClosed(reason: "persistent_store_unreadable"),
            syncModeSource: "bootstrap_failed",
            shouldMarkStoreEpoch: false
        )
    }

    private func makeWriteClosedReason(
        initialReport: PersistentStoreLoadReport,
        missingConfigurations: Set<String>
    ) -> String {
        if let compatibilityError = initialReport.errors.first(where: isIncompatibleStoreError) {
            return "cloudsync_model_compatibility_\(compatibilityError.code)"
        }
        if let firstError = initialReport.errors.first {
            return "cloudsync_store_load_error_\(firstError.code)"
        }
        if missingConfigurations.isEmpty == false {
            return "missing_configurations_\(missingConfigurations.sorted().joined(separator: "_"))"
        }
        return "unknown_cloudsync_bootstrap_failure"
    }

    private func loadPersistentStoresAndReport(
        container: NSPersistentCloudKitContainer,
        phase: String
    ) -> PersistentStoreLoadReport {
        let descriptions = container.persistentStoreDescriptions
        guard descriptions.isEmpty == false else {
            return PersistentStoreLoadReport(loadedConfigurations: [], errors: [])
        }
        let expectedConfigurations = Set(descriptions.compactMap(\.configuration))

        let group = DispatchGroup()
        let lock = NSLock()
        var loadedConfigurations = Set<String>()
        var loadErrors: [NSError] = []

        descriptions.forEach { _ in group.enter() }
        container.loadPersistentStores { storeDescription, error in
            defer { group.leave() }

            lock.lock()
            defer { lock.unlock() }

            if let error = error as NSError? {
                loadErrors.append(error)

                let configuration = storeDescription.configuration ?? "unknown"
                let missingConfigurations = expectedConfigurations.subtracting(loadedConfigurations)
                let underlyingSummary = self.underlyingCoreDataErrorSummary(error)
                let detailedSummary = self.detailedCoreDataErrorsSummary(error)
                let metadataSummary = self.persistentStoreMetadataSnippet(at: storeDescription.url)
                logError(
                    event: "persistent_store_load_failed",
                    message: "V3 persistent store failed to load",
                    fields: [
                        "phase": phase,
                        "url": storeDescription.url?.absoluteString ?? "unknown",
                        "configuration": configuration,
                        "domain": error.domain,
                        "code": String(error.code),
                        "error": error.localizedDescription,
                        "underlying_error": underlyingSummary,
                        "detailed_errors": detailedSummary,
                        "metadata": metadataSummary,
                        "loaded_configurations": loadedConfigurations.sorted().joined(separator: ","),
                        "missing_configurations": missingConfigurations.sorted().joined(separator: ",")
                    ]
                )
                return
            }

            if let configuration = storeDescription.configuration {
                loadedConfigurations.insert(configuration)
            }
        }
        group.wait()

        return PersistentStoreLoadReport(
            loadedConfigurations: loadedConfigurations,
            errors: loadErrors
        )
    }

    private func persistentStoreMetadataSnippet(at url: URL?) -> String {
        guard let url else { return "metadata_unavailable_no_url" }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return "metadata_unavailable_missing_file"
        }

        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url,
                options: nil
            )
            let storeUUID = metadata[NSStoreUUIDKey] as? String ?? "unknown"
            let modelVersionIdentifiers = (metadata[NSStoreModelVersionIdentifiersKey] as? [String]) ?? []
            let hashCount = (metadata[NSStoreModelVersionHashesKey] as? [String: Data])?.count ?? 0
            return "uuid=\(storeUUID);model_versions=\(modelVersionIdentifiers.joined(separator: "|"));hash_count=\(hashCount)"
        } catch {
            return "metadata_unavailable_\(error.localizedDescription)"
        }
    }

    private func underlyingCoreDataErrorSummary(_ error: NSError) -> String {
        guard let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError else {
            return "none"
        }
        return "\(underlying.domain):\(underlying.code):\(underlying.localizedDescription)"
    }

    private func detailedCoreDataErrorsSummary(_ error: NSError) -> String {
        guard let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError],
              detailedErrors.isEmpty == false else {
            return "none"
        }
        return detailedErrors
            .map { "\($0.domain):\($0.code):\($0.localizedDescription)" }
            .joined(separator: " | ")
    }

    private func hasExpectedConfigurations(_ report: PersistentStoreLoadReport) -> Bool {
        expectedStoreConfigurations.isSubset(of: report.loadedConfigurations)
    }

    private func hasLocalOnlyConfiguration(_ report: PersistentStoreLoadReport) -> Bool {
        localOnlyConfiguration.isSubset(of: report.loadedConfigurations)
    }

    private func unloadPersistentStores(_ container: NSPersistentCloudKitContainer) {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                let nsError = error as NSError
                logWarning(
                    event: "persistent_store_unload_failed",
                    message: "Failed to unload persistent store before rebootstrap/recovery",
                    fields: [
                        "domain": nsError.domain,
                        "code": String(nsError.code),
                        "error": nsError.localizedDescription,
                        "url": store.url?.absoluteString ?? "unknown",
                        "configuration": store.configurationName
                    ]
                )
            }
        }
    }

    private func isIncompatibleStoreError(_ error: NSError) -> Bool {
        let code = error.code
        let incompatibleCodes: Set<Int> = [
            NSPersistentStoreInvalidTypeError,
            NSPersistentStoreTypeMismatchError,
            NSPersistentStoreIncompatibleSchemaError,
            NSPersistentStoreOpenError,
            NSPersistentStoreIncompatibleVersionHashError,
            134000,
            134010,
            134020,
            134060,
            134080,
            134081,
            134100
        ]

        if error.domain == NSCocoaErrorDomain, incompatibleCodes.contains(code) {
            return true
        }

        if error.localizedDescription.localizedCaseInsensitiveContains("model configuration used to open the store is incompatible") {
            return true
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isIncompatibleStoreError(underlying)
        }

        if let detailed = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
            return detailed.contains(where: isIncompatibleStoreError)
        }

        return false
    }
}
