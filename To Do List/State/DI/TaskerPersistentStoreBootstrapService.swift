import CoreData
import Foundation

fileprivate enum TaskerSplitPersistentStore: CaseIterable {
    case cloudSync
    case localOnly

    var configurationName: String {
        switch self {
        case .cloudSync:
            return "CloudSync"
        case .localOnly:
            return "LocalOnly"
        }
    }

    var fileName: String {
        switch self {
        case .cloudSync:
            return TaskerPersistentStoreLocationService.cloudStoreFileName
        case .localOnly:
            return TaskerPersistentStoreLocationService.localStoreFileName
        }
    }

    var label: String {
        switch self {
        case .cloudSync:
            return "cloudsync"
        case .localOnly:
            return "localonly"
        }
    }
}

private final class TaskerPersistentStoreBootstrapServiceBundleLocator {}

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

    fileprivate func activeV3StoreURLs(for store: TaskerSplitPersistentStore) -> [URL] {
        let location = resolvedV3StoreLocation()
        return storeFileURLs(
            forFileName: store.fileName,
            in: location.canonicalDirectoryURL
        )
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

    fileprivate func quarantineActiveV3StoreFiles(
        for store: TaskerSplitPersistentStore,
        reason: String
    ) throws -> URL? {
        let existingURLs = activeV3StoreURLs(for: store).filter { fileManager.fileExists(atPath: $0.path) }
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
            "\(timestamp)-\(store.label)-\(sanitizePathComponent(reason))",
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

    fileprivate func clearActiveV3StoreFiles(for store: TaskerSplitPersistentStore) {
        for fileURL in activeV3StoreURLs(for: store) where fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                logWarning(
                    event: "v3_store_clear_after_quarantine_failed",
                    message: "Failed to clear targeted V3 split store file after quarantine",
                    fields: [
                        "store": store.label,
                        "file": fileURL.lastPathComponent,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    fileprivate func replaceStoreFiles(
        for store: TaskerSplitPersistentStore,
        withMigratedBaseURL migratedBaseURL: URL
    ) throws {
        let targetURLs = activeV3StoreURLs(for: store)
        let migratedURLs = storeFileURLs(
            forFileName: migratedBaseURL.lastPathComponent,
            in: migratedBaseURL.deletingLastPathComponent()
        )

        for targetURL in targetURLs where fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }

        for (sourceURL, destinationURL) in zip(migratedURLs, targetURLs) where fileManager.fileExists(atPath: sourceURL.path) {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
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

    private func storeFileURLs(forFileName fileName: String, in directoryURL: URL) -> [URL] {
        [
            fileName,
            "\(fileName)-wal",
            "\(fileName)-shm"
        ].map { directoryURL.appendingPathComponent($0).standardizedFileURL }
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
    private enum HabitRuntimeMigration {
        static let fieldBackfillKey = "tasker.habit.runtime.field_backfill.v1"
        static let repairRequiredKey = "tasker.habit.runtime.repair_required.v1"
        static let repairCompletedKey = "tasker.habit.runtime.repair_completed.v1"
    }

    private enum OccurrenceKeyMigration {
        static let backfillKey = "tasker.occurrence.key_backfill.v1"
    }

    static func shouldRunRepair(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: HabitRuntimeMigration.repairRequiredKey)
            && defaults.bool(forKey: HabitRuntimeMigration.repairCompletedKey) == false
    }

    static func markRepairCompleted(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: HabitRuntimeMigration.repairRequiredKey)
        defaults.set(true, forKey: HabitRuntimeMigration.repairCompletedKey)
    }

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
                try backfillHabitRuntimeFieldsIfNeeded(in: context)
                try backfillOccurrenceKeysIfNeeded(in: context)
                try backfillWeeklyPlanningBucketsIfNeeded(in: context)

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

    private func backfillHabitRuntimeFieldsIfNeeded(in context: NSManagedObjectContext) throws {
        let defaults = UserDefaults.standard
        guard
            let habitEntity = NSEntityDescription.entity(forEntityName: "HabitDefinition", in: context),
            habitEntity.attributesByName["kindRaw"] != nil,
            habitEntity.attributesByName["trackingModeRaw"] != nil,
            habitEntity.attributesByName["lastHistoryRollDate"] != nil
        else {
            return
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: "HabitDefinition")
        let habits = try context.fetch(request)
        let fieldBackfillAlreadyMarked = defaults.bool(forKey: HabitRuntimeMigration.fieldBackfillKey)

        let templateRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleTemplate")
        templateRequest.predicate = NSPredicate(format: "sourceType == %@", ScheduleSourceType.habit.rawValue)
        let templates = try context.fetch(templateRequest)

        let ruleRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleRule")
        let rules = try context.fetch(ruleRequest)
        let rulesByTemplateID = Dictionary(grouping: rules) { $0.value(forKey: "scheduleTemplateID") as? UUID }

        if fieldBackfillAlreadyMarked {
            let hasRepairableHabit = habits.contains { habit in
                let kindMissing = (habit.value(forKey: "kindRaw") as? String)?.isEmpty != false
                let trackingModeMissing = (habit.value(forKey: "trackingModeRaw") as? String)?.isEmpty != false
                let historyRollMissing = habit.value(forKey: "lastHistoryRollDate") == nil

                guard
                    let habitID = habit.value(forKey: "id") as? UUID
                else {
                    return kindMissing || trackingModeMissing || historyRollMissing
                }

                let template = templates.first { template in
                    (template.value(forKey: "sourceID") as? UUID) == habitID
                }
                let templateID = template?.value(forKey: "id") as? UUID
                let linkedRules = templateID.flatMap { rulesByTemplateID[$0] } ?? []
                let hasSupportedRule = linkedRules.allSatisfy { rule in
                    guard let ruleType = (rule.value(forKey: "ruleType") as? String)?.lowercased() else {
                        return false
                    }
                    return ruleType == "daily" || ruleType == "weekly"
                }
                let needsPauseRepair = template == nil || linkedRules.isEmpty || hasSupportedRule == false
                let pauseMissing = needsPauseRepair && (habit.value(forKey: "isPaused") as? Bool) != true

                return kindMissing || trackingModeMissing || historyRollMissing || pauseMissing
            }

            guard hasRepairableHabit else {
                defaults.set(false, forKey: HabitRuntimeMigration.repairRequiredKey)
                return
            }
        }

        var updatedCount = 0
        let today = Calendar.current.startOfDay(for: Date())

        for habit in habits {
            guard let habitID = habit.value(forKey: "id") as? UUID else { continue }
            let habitType = (habit.value(forKey: "habitType") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            let kindRaw: String
            let trackingModeRaw: String
            switch habitType {
            case "quit":
                kindRaw = HabitKind.negative.rawValue
                trackingModeRaw = HabitTrackingMode.dailyCheckIn.rawValue
            case "quit_lapse_only":
                kindRaw = HabitKind.negative.rawValue
                trackingModeRaw = HabitTrackingMode.lapseOnly.rawValue
            default:
                kindRaw = HabitKind.positive.rawValue
                trackingModeRaw = HabitTrackingMode.dailyCheckIn.rawValue
            }

            if (habit.value(forKey: "kindRaw") as? String)?.isEmpty != false {
                habit.setValue(kindRaw, forKey: "kindRaw")
                updatedCount += 1
            }
            if (habit.value(forKey: "trackingModeRaw") as? String)?.isEmpty != false {
                habit.setValue(trackingModeRaw, forKey: "trackingModeRaw")
                updatedCount += 1
            }
            if habit.value(forKey: "lastHistoryRollDate") == nil {
                habit.setValue(today, forKey: "lastHistoryRollDate")
                updatedCount += 1
            }

            let template = templates.first { template in
                (template.value(forKey: "sourceID") as? UUID) == habitID
            }
            let templateID = template?.value(forKey: "id") as? UUID
            let linkedRules = templateID.flatMap { rulesByTemplateID[$0] } ?? []
            let hasSupportedRule = linkedRules.allSatisfy { rule in
                guard let ruleType = (rule.value(forKey: "ruleType") as? String)?.lowercased() else {
                    return false
                }
                return ruleType == "daily" || ruleType == "weekly"
            }

            if template == nil || linkedRules.isEmpty || hasSupportedRule == false {
                if (habit.value(forKey: "isPaused") as? Bool) != true {
                    habit.setValue(true, forKey: "isPaused")
                    updatedCount += 1
                }
            }
        }

        if updatedCount > 0 {
            logWarning(
                event: "habit_runtime_backfill_applied",
                message: "Backfilled legacy habit runtime fields and paused unsupported schedule linkages",
                fields: ["updated_count": String(updatedCount)]
            )
        }

        defaults.set(true, forKey: HabitRuntimeMigration.fieldBackfillKey)
        if updatedCount > 0 {
            defaults.set(true, forKey: HabitRuntimeMigration.repairRequiredKey)
            defaults.set(false, forKey: HabitRuntimeMigration.repairCompletedKey)
        } else {
            defaults.set(false, forKey: HabitRuntimeMigration.repairRequiredKey)
        }
    }

    private func backfillOccurrenceKeysIfNeeded(in context: NSManagedObjectContext) throws {
        let defaults = UserDefaults.standard
        guard
            let occurrenceEntity = NSEntityDescription.entity(forEntityName: "Occurrence", in: context),
            occurrenceEntity.attributesByName["occurrenceKey"] != nil
        else {
            return
        }

        let templateRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleTemplate")
        let templates: [NSManagedObject] = try context.fetch(templateRequest)
        let templatesByID: [UUID: NSManagedObject] = Dictionary(
            uniqueKeysWithValues: templates.compactMap { template in
                guard let id = template.value(forKey: "id") as? UUID else { return nil }
                return (id, template)
            }
        )

        let occurrenceRequest = NSFetchRequest<NSManagedObject>(entityName: "Occurrence")
        occurrenceRequest.sortDescriptors = [
            NSSortDescriptor(key: "scheduledAt", ascending: true),
            NSSortDescriptor(key: "updatedAt", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        let occurrences = try context.fetch(occurrenceRequest)

        let exceptionRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleException")
        exceptionRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let exceptions = try context.fetch(exceptionRequest)

        let alreadyMarked = defaults.bool(forKey: OccurrenceKeyMigration.backfillKey)
        if alreadyMarked {
            let hasRepairableOccurrence = occurrences.contains { occurrence in
                resolvedOccurrenceKey(for: occurrence, templatesByID: templatesByID) == nil
            }
            let hasRepairableException = exceptions.contains { exception in
                resolvedScheduleExceptionKey(for: exception, templatesByID: templatesByID) == nil
            }
            guard hasRepairableOccurrence || hasRepairableException else {
                return
            }
        }

        var updatedOccurrences = 0
        var deletedOccurrences = 0
        var mergedOccurrences = 0
        var updatedExceptions = 0
        var deletedExceptions = 0
        var keptOccurrenceByKey: [String: NSManagedObject] = [:]

        for occurrence in occurrences {
            guard let canonicalKey = resolvedOccurrenceKey(for: occurrence, templatesByID: templatesByID) else {
                context.delete(occurrence)
                deletedOccurrences += 1
                continue
            }

            let existingKey = (occurrence.value(forKey: "occurrenceKey") as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if existingKey != canonicalKey {
                occurrence.setValue(canonicalKey, forKey: "occurrenceKey")
                updatedOccurrences += 1
            }

            if let kept = keptOccurrenceByKey[canonicalKey] {
                let preferred = preferredOccurrence(between: kept, and: occurrence)
                let other = preferred == kept ? occurrence : kept
                mergeOccurrence(other, into: preferred)
                context.delete(other)
                keptOccurrenceByKey[canonicalKey] = preferred
                deletedOccurrences += 1
                mergedOccurrences += 1
                updatedOccurrences += 1
            } else {
                keptOccurrenceByKey[canonicalKey] = occurrence
            }
        }

        var keptExceptionByKey: [String: NSManagedObject] = [:]
        for exception in exceptions {
            guard let canonicalKey = resolvedScheduleExceptionKey(for: exception, templatesByID: templatesByID) else {
                context.delete(exception)
                deletedExceptions += 1
                continue
            }

            let existingKey = (exception.value(forKey: "occurrenceKey") as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if existingKey != canonicalKey {
                exception.setValue(canonicalKey, forKey: "occurrenceKey")
                updatedExceptions += 1
            }

            let dedupeKey = [
                (exception.value(forKey: "scheduleTemplateID") as? UUID)?.uuidString ?? "missing-template",
                canonicalKey
            ].joined(separator: "|")
            if let kept = keptExceptionByKey[dedupeKey] {
                let preferred = preferredScheduleException(between: kept, and: exception)
                let other = preferred == kept ? exception : kept
                context.delete(other)
                keptExceptionByKey[dedupeKey] = preferred
                deletedExceptions += 1
            } else {
                keptExceptionByKey[dedupeKey] = exception
            }
        }

        if updatedOccurrences > 0 || deletedOccurrences > 0 || updatedExceptions > 0 || deletedExceptions > 0 {
            logWarning(
                event: "occurrence_key_backfill_applied",
                message: "Canonicalized occurrence keys and removed invalid duplicate runtime rows during startup",
                fields: [
                    "occurrences_updated": String(updatedOccurrences),
                    "occurrences_deleted": String(deletedOccurrences),
                    "occurrences_merged": String(mergedOccurrences),
                    "exceptions_updated": String(updatedExceptions),
                    "exceptions_deleted": String(deletedExceptions)
                ]
            )
        }

        defaults.set(true, forKey: OccurrenceKeyMigration.backfillKey)
    }

    private func resolvedOccurrenceKey(
        for occurrence: NSManagedObject,
        templatesByID: [UUID: NSManagedObject]
    ) -> String? {
        let templateID = occurrence.value(forKey: "scheduleTemplateID") as? UUID
            ?? (occurrence.value(forKey: "templateRef") as? NSManagedObject)?.value(forKey: "id") as? UUID
        let sourceID = occurrence.value(forKey: "sourceID") as? UUID
            ?? templateID.flatMap { templatesByID[$0]?.value(forKey: "sourceID") as? UUID }
            ?? (occurrence.value(forKey: "templateRef") as? NSManagedObject)?.value(forKey: "sourceID") as? UUID
        let scheduledAt = occurrence.value(forKey: "scheduledAt") as? Date
        let rawKey = (occurrence.value(forKey: "occurrenceKey") as? String) ?? ""

        if let canonical = OccurrenceKeyCodec.canonicalize(
            rawKey,
            fallbackTemplateID: templateID,
            fallbackSourceID: sourceID
        ) {
            return canonical
        }

        guard let templateID, let sourceID, let scheduledAt else { return nil }
        return OccurrenceKeyCodec.encode(
            scheduleTemplateID: templateID,
            scheduledAt: scheduledAt,
            sourceID: sourceID
        )
    }

    private func resolvedScheduleExceptionKey(
        for exception: NSManagedObject,
        templatesByID: [UUID: NSManagedObject]
    ) -> String? {
        let templateID = exception.value(forKey: "scheduleTemplateID") as? UUID
            ?? (exception.value(forKey: "templateRef") as? NSManagedObject)?.value(forKey: "id") as? UUID
        let sourceID = templateID.flatMap { templatesByID[$0]?.value(forKey: "sourceID") as? UUID }
            ?? (exception.value(forKey: "templateRef") as? NSManagedObject)?.value(forKey: "sourceID") as? UUID
        let rawKey = (exception.value(forKey: "occurrenceKey") as? String) ?? ""
        return OccurrenceKeyCodec.canonicalize(
            rawKey,
            fallbackTemplateID: templateID,
            fallbackSourceID: sourceID
        )
    }

    private func preferredOccurrence(
        between lhs: NSManagedObject,
        and rhs: NSManagedObject
    ) -> NSManagedObject {
        let lhsRank = occurrenceStateRank(lhs.value(forKey: "state") as? String)
        let rhsRank = occurrenceStateRank(rhs.value(forKey: "state") as? String)
        if lhsRank != rhsRank {
            return lhsRank >= rhsRank ? lhs : rhs
        }

        let lhsUpdatedAt = lhs.value(forKey: "updatedAt") as? Date ?? .distantPast
        let rhsUpdatedAt = rhs.value(forKey: "updatedAt") as? Date ?? .distantPast
        if lhsUpdatedAt != rhsUpdatedAt {
            return lhsUpdatedAt >= rhsUpdatedAt ? lhs : rhs
        }

        let lhsCreatedAt = lhs.value(forKey: "createdAt") as? Date ?? .distantFuture
        let rhsCreatedAt = rhs.value(forKey: "createdAt") as? Date ?? .distantFuture
        return lhsCreatedAt <= rhsCreatedAt ? lhs : rhs
    }

    private func preferredScheduleException(
        between lhs: NSManagedObject,
        and rhs: NSManagedObject
    ) -> NSManagedObject {
        let lhsCreatedAt = lhs.value(forKey: "createdAt") as? Date ?? .distantPast
        let rhsCreatedAt = rhs.value(forKey: "createdAt") as? Date ?? .distantPast
        return lhsCreatedAt >= rhsCreatedAt ? lhs : rhs
    }

    private func mergeOccurrence(_ source: NSManagedObject, into destination: NSManagedObject) {
        let sourceUpdatedAt = source.value(forKey: "updatedAt") as? Date ?? .distantPast
        let destinationUpdatedAt = destination.value(forKey: "updatedAt") as? Date ?? .distantPast
        if sourceUpdatedAt > destinationUpdatedAt {
            destination.setValue(source.value(forKey: "state"), forKey: "state")
            destination.setValue(source.value(forKey: "dueAt"), forKey: "dueAt")
            destination.setValue(sourceUpdatedAt, forKey: "updatedAt")
            destination.setValue(source.value(forKey: "generationWindow"), forKey: "generationWindow")
            destination.setValue(source.value(forKey: "isGenerated"), forKey: "isGenerated")
        }

        if let resolutions = source.value(forKey: "resolutions") as? NSSet {
            for case let resolution as NSManagedObject in resolutions {
                resolution.setValue(destination, forKey: "occurrenceRef")
                resolution.setValue(destination.value(forKey: "id") as? UUID, forKey: "occurrenceID")
            }
        }

        if let reminders = source.value(forKey: "reminders") as? NSSet {
            for case let reminder as NSManagedObject in reminders {
                reminder.setValue(destination, forKey: "occurrenceRef")
                reminder.setValue(destination.value(forKey: "id") as? UUID, forKey: "occurrenceID")
            }
        }
    }

    private func backfillWeeklyPlanningBucketsIfNeeded(in context: NSManagedObjectContext) throws {
        guard
            let taskEntity = NSEntityDescription.entity(forEntityName: "TaskDefinition", in: context),
            taskEntity.attributesByName["planningBucketRaw"] != nil
        else {
            return
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "planningBucketRaw == nil"),
            NSPredicate(format: "planningBucketRaw == ''")
        ])

        let tasks = try context.fetch(request)
        guard tasks.isEmpty == false else {
            return
        }

        for task in tasks {
            task.setValue(TaskPlanningBucket.thisWeek.rawValue, forKey: "planningBucketRaw")
        }

        logWarning(
            event: "weekly_planning_bucket_backfill_applied",
            message: "Backfilled TaskDefinition.planningBucketRaw for legacy rows",
            fields: ["updated_count": String(tasks.count)]
        )
    }

    private func occurrenceStateRank(_ rawValue: String?) -> Int {
        switch rawValue {
        case OccurrenceState.completed.rawValue:
            return 4
        case OccurrenceState.failed.rawValue:
            return 3
        case OccurrenceState.missed.rawValue:
            return 2
        case OccurrenceState.skipped.rawValue:
            return 1
        default:
            return 0
        }
    }
}

struct TaskerPersistentStoreBootstrapResult {
    let state: PersistentBootstrapState
    let syncMode: PersistentSyncMode
    let syncModeSource: String
    let shouldMarkStoreEpoch: Bool
}

private struct TaskerStoreCompatibilityReport {
    let store: TaskerSplitPersistentStore
    let storeURL: URL
    let metadataSummary: String
    let destinationCompatible: Bool
    let sourceCompatible: Bool
    let fileExists: Bool
}

final class TaskerPersistentStoreBootstrapService {
    static let defaultCloudKitContainerIdentifier = "iCloud.TaskerCloudKitV3"

    private let expectedStoreConfigurations: Set<String>
    private let localOnlyConfiguration: Set<String>
    private let cloudKitRuntimeContextProvider: () -> CloudKitRuntimeContext
    private let enableCloudKitContainerOptions: Bool
    let storeLocationService: TaskerPersistentStoreLocationService
    let cloudKitContainerIdentifier: String

    init(
        expectedStoreConfigurations: Set<String> = ["CloudSync", "LocalOnly"],
        localOnlyConfiguration: Set<String> = ["LocalOnly"],
        storeLocationService: TaskerPersistentStoreLocationService = TaskerPersistentStoreLocationService(),
        cloudKitContainerIdentifier: String = TaskerPersistentStoreBootstrapService.defaultCloudKitContainerIdentifier,
        cloudKitRuntimeContextProvider: @escaping () -> CloudKitRuntimeContext = { .current() },
        enableCloudKitContainerOptions: Bool = true
    ) {
        self.expectedStoreConfigurations = expectedStoreConfigurations
        self.localOnlyConfiguration = localOnlyConfiguration
        self.storeLocationService = storeLocationService
        self.cloudKitContainerIdentifier = cloudKitContainerIdentifier
        self.cloudKitRuntimeContextProvider = cloudKitRuntimeContextProvider
        self.enableCloudKitContainerOptions = enableCloudKitContainerOptions
    }

    func makeV3PersistentContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "TaskModelV3")
        let cloudKitMode = currentCloudKitMirroringMode()

        let location = storeLocationService.resolvedV3StoreLocation()
        let cloudURL = location.cloudStoreURL
        let localURL = location.localStoreURL

        let cloudDescription = NSPersistentStoreDescription(url: cloudURL)
        cloudDescription.configuration = TaskerSplitPersistentStore.cloudSync.configurationName
        if case .enabled = cloudKitMode {
            if enableCloudKitContainerOptions {
                cloudDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: cloudKitContainerIdentifier
                )
            }
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
        localDescription.configuration = TaskerSplitPersistentStore.localOnly.configurationName
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
        localDescription.configuration = TaskerSplitPersistentStore.localOnly.configurationName
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

    private func currentCloudKitMirroringMode() -> CloudKitMirroringMode {
        cloudKitMirroringMode(context: cloudKitRuntimeContextProvider())
    }

    func bootstrapV3PersistentContainer() async -> TaskerPersistentStoreBootstrapResult {
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

        do {
            try migrateSplitStoresIfNeeded()
        } catch {
            logError(
                event: "persistent_store_preflight_migration_failed",
                message: "Split-store schema preflight migration failed before bootstrap",
                fields: [
                    "error": error.localizedDescription
                ]
            )
        }

        let initialContainer = makeV3PersistentContainer()
        let initialReport = await loadPersistentStoresAndReport(container: initialContainer, phase: "initial")
        let initialHealthy = initialReport.errors.isEmpty && hasExpectedConfigurations(initialReport)

        if initialHealthy {
            if Self.validateRuntimeSchema(in: initialContainer.managedObjectModel) != nil {
                unloadPersistentStores(initialContainer)
                return TaskerPersistentStoreBootstrapResult(
                    state: .failed("Tasker's data model is out of date. Please reinstall or update the app."),
                    syncMode: .writeClosed(reason: "persistent_store_schema_invalid"),
                    syncModeSource: "bootstrap_initial_schema_invalid",
                    shouldMarkStoreEpoch: false
                )
            }
            return TaskerPersistentStoreBootstrapResult(
                state: .ready(initialContainer),
                syncMode: .fullSync,
                syncModeSource: "bootstrap_initial",
                shouldMarkStoreEpoch: true
            )
        }

        let missingConfigurations = expectedStoreConfigurations.subtracting(initialReport.loadedConfigurations)
        let cloudKitMode = currentCloudKitMirroringMode()

        if shouldAttemptCloudSyncStoreRebuild(
            initialReport: initialReport,
            cloudKitMode: cloudKitMode
        ) {
            unloadPersistentStores(initialContainer)
            if let rebuiltResult = await attemptCloudSyncStoreRebuild() {
                return rebuiltResult
            }
        } else {
            unloadPersistentStores(initialContainer)
        }

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

        let writeClosedContainer = makeV3LocalOnlyWriteClosedContainer()
        let writeClosedReport = await loadPersistentStoresAndReport(
            container: writeClosedContainer,
            phase: "write_closed_fallback"
        )
        let writeClosedHealthy = writeClosedReport.errors.isEmpty && hasLocalOnlyConfiguration(writeClosedReport)
        if writeClosedHealthy {
            if Self.validateRuntimeSchema(in: writeClosedContainer.managedObjectModel) != nil {
                unloadPersistentStores(writeClosedContainer)
                return TaskerPersistentStoreBootstrapResult(
                    state: .failed("Tasker's data model is out of date. Please reinstall or update the app."),
                    syncMode: .writeClosed(reason: "persistent_store_schema_invalid"),
                    syncModeSource: "bootstrap_write_closed_schema_invalid",
                    shouldMarkStoreEpoch: false
                )
            }
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

    private func shouldAttemptCloudSyncStoreRebuild(
        initialReport: PersistentStoreLoadReport,
        cloudKitMode: CloudKitMirroringMode
    ) -> Bool {
        guard case .enabled = cloudKitMode else {
            return false
        }
        guard hasLocalOnlyConfiguration(initialReport) else {
            return false
        }
        return initialReport.errors.contains(where: isIncompatibleStoreError)
    }

    private func attemptCloudSyncStoreRebuild() async -> TaskerPersistentStoreBootstrapResult? {
        do {
            let quarantineURL = try storeLocationService.quarantineActiveV3StoreFiles(
                for: .cloudSync,
                reason: "cloudsync_auto_rebuild"
            )
            storeLocationService.clearActiveV3StoreFiles(for: .cloudSync)
            logWarning(
                event: "persistent_store_cloudsync_auto_rebuild_started",
                message: "Quarantined incompatible CloudSync store and is retrying split bootstrap",
                fields: [
                    "quarantine_dir": quarantineURL?.path ?? "none"
                ]
            )

            let rebuiltContainer = makeV3PersistentContainer()
            let rebuiltReport = await loadPersistentStoresAndReport(
                container: rebuiltContainer,
                phase: "cloudsync_auto_rebuild"
            )
            let rebuiltHealthy = rebuiltReport.errors.isEmpty && hasExpectedConfigurations(rebuiltReport)
            guard rebuiltHealthy else {
                unloadPersistentStores(rebuiltContainer)
                logError(
                    event: "persistent_store_cloudsync_auto_rebuild_failed",
                    message: "CloudSync-only store rebuild did not restore split-store bootstrap",
                    fields: [
                        "loaded_configurations": rebuiltReport.loadedConfigurations.sorted().joined(separator: ","),
                        "error_count": String(rebuiltReport.errors.count),
                        "errors": rebuiltReport.errors.map { "\($0.domain):\($0.code)" }.joined(separator: ", ")
                    ]
                )
                return nil
            }

            if Self.validateRuntimeSchema(in: rebuiltContainer.managedObjectModel) != nil {
                unloadPersistentStores(rebuiltContainer)
                return TaskerPersistentStoreBootstrapResult(
                    state: .failed("Tasker's data model is out of date. Please reinstall or update the app."),
                    syncMode: .writeClosed(reason: "persistent_store_schema_invalid"),
                    syncModeSource: "bootstrap_cloudsync_auto_rebuild_schema_invalid",
                    shouldMarkStoreEpoch: false
                )
            }

            logWarning(
                event: "persistent_store_cloudsync_auto_rebuild_succeeded",
                message: "CloudSync-only store rebuild restored split-store bootstrap",
                fields: [
                    "loaded_configurations": rebuiltReport.loadedConfigurations.sorted().joined(separator: ",")
                ]
            )
            return TaskerPersistentStoreBootstrapResult(
                state: .ready(rebuiltContainer),
                syncMode: .fullSync,
                syncModeSource: "bootstrap_cloudsync_auto_rebuild",
                shouldMarkStoreEpoch: true
            )
        } catch {
            logError(
                event: "persistent_store_cloudsync_auto_rebuild_quarantine_failed",
                message: "Could not quarantine the incompatible CloudSync store before retry",
                fields: [
                    "error": error.localizedDescription
                ]
            )
            return nil
        }
    }

    private func migrateSplitStoresIfNeeded() throws {
        let modelBundleURL = try taskModelBundleURL()
        let sourceModel = try compiledTaskModel(
            named: "TaskModelV3_Habits.mom",
            bundleURL: modelBundleURL
        )
        let destinationModel = try compiledTaskModel(
            named: "TaskModelV3_WeeklyPlanning.mom",
            bundleURL: modelBundleURL
        )

        for store in TaskerSplitPersistentStore.allCases {
            let compatibility = compatibilityReport(
                for: store,
                sourceModel: sourceModel,
                destinationModel: destinationModel
            )

            if compatibility.fileExists, compatibility.destinationCompatible || compatibility.sourceCompatible {
                logWarning(
                    event: "persistent_store_preflight_inspected",
                    message: "Inspected split-store compatibility before bootstrap",
                    fields: [
                        "store": store.label,
                        "configuration": store.configurationName,
                        "url": compatibility.storeURL.absoluteString,
                        "file_exists": String(compatibility.fileExists),
                        "destination_compatible": String(compatibility.destinationCompatible),
                        "source_compatible": String(compatibility.sourceCompatible),
                        "metadata": compatibility.metadataSummary
                    ]
                )
            }

            guard compatibility.fileExists else { continue }
            guard compatibility.destinationCompatible == false else { continue }
            guard compatibility.sourceCompatible else { continue }

            logWarning(
                event: "persistent_store_preflight_migration_started",
                message: "Migrating split store to the current TaskModelV3_WeeklyPlanning schema before bootstrap",
                fields: [
                    "store": store.label,
                    "configuration": store.configurationName,
                    "url": compatibility.storeURL.absoluteString
                ]
            )

            let tempURL = compatibility.storeURL.deletingLastPathComponent()
                .appendingPathComponent("\(compatibility.storeURL.lastPathComponent).migrating")
            removeStoreArtifacts(at: tempURL)

            let mappingModel = try NSMappingModel.inferredMappingModel(
                forSourceModel: sourceModel,
                destinationModel: destinationModel
            )
            let migrationManager = NSMigrationManager(
                sourceModel: sourceModel,
                destinationModel: destinationModel
            )

            do {
                try migrationManager.migrateStore(
                    from: compatibility.storeURL,
                    sourceType: NSSQLiteStoreType,
                    options: nil,
                    with: mappingModel,
                    toDestinationURL: tempURL,
                    destinationType: NSSQLiteStoreType,
                    destinationOptions: nil
                )
                try storeLocationService.replaceStoreFiles(for: store, withMigratedBaseURL: tempURL)
                logWarning(
                    event: "persistent_store_preflight_migration_succeeded",
                    message: "Migrated split store to the current TaskModelV3_WeeklyPlanning schema before bootstrap",
                    fields: [
                        "store": store.label,
                        "configuration": store.configurationName,
                        "url": compatibility.storeURL.absoluteString
                    ]
                )
            } catch {
                removeStoreArtifacts(at: tempURL)
                throw error
            }
        }
    }

    private func compatibilityReport(
        for store: TaskerSplitPersistentStore,
        sourceModel: NSManagedObjectModel,
        destinationModel: NSManagedObjectModel
    ) -> TaskerStoreCompatibilityReport {
        let storeURL = storeLocationService.resolvedV3StoreLocation().canonicalDirectoryURL
            .appendingPathComponent(store.fileName)
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return TaskerStoreCompatibilityReport(
                store: store,
                storeURL: storeURL,
                metadataSummary: "metadata_unavailable_missing_file",
                destinationCompatible: false,
                sourceCompatible: false,
                fileExists: false
            )
        }

        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            let destinationCompatible = destinationModel.isConfiguration(
                withName: store.configurationName,
                compatibleWithStoreMetadata: metadata
            )
            let sourceCompatible = sourceModel.isConfiguration(
                withName: store.configurationName,
                compatibleWithStoreMetadata: metadata
            )
            return TaskerStoreCompatibilityReport(
                store: store,
                storeURL: storeURL,
                metadataSummary: persistentStoreMetadataSnippet(at: storeURL),
                destinationCompatible: destinationCompatible,
                sourceCompatible: sourceCompatible,
                fileExists: true
            )
        } catch {
            return TaskerStoreCompatibilityReport(
                store: store,
                storeURL: storeURL,
                metadataSummary: "metadata_unavailable_\(error.localizedDescription)",
                destinationCompatible: false,
                sourceCompatible: false,
                fileExists: true
            )
        }
    }

    private func taskModelBundleURL() throws -> URL {
        let bundles = [Bundle.main, Bundle(for: TaskerPersistentStoreBootstrapServiceBundleLocator.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: "TaskModelV3", withExtension: "momd") {
                return url
            }
        }

        throw NSError(
            domain: "TaskerPersistentStoreBootstrapService.Model",
            code: 2,
            userInfo: [
                NSLocalizedDescriptionKey: "Unable to locate TaskModelV3.momd"
            ]
        )
    }

    private func compiledTaskModel(
        named fileName: String,
        bundleURL: URL
    ) throws -> NSManagedObjectModel {
        let modelURL = bundleURL.appendingPathComponent(fileName)
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw NSError(
                domain: "TaskerPersistentStoreBootstrapService.Model",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unable to load compiled model \(fileName)"
                ]
            )
        }
        return model
    }

    private func removeStoreArtifacts(at baseURL: URL) {
        let fileManager = FileManager.default
        let candidates = [
            baseURL,
            URL(fileURLWithPath: baseURL.path + "-wal"),
            URL(fileURLWithPath: baseURL.path + "-shm")
        ]

        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            try? fileManager.removeItem(at: candidate)
        }
    }

    private func loadPersistentStoresAndReport(
        container: NSPersistentCloudKitContainer,
        phase: String
    ) async -> PersistentStoreLoadReport {
        let descriptions = container.persistentStoreDescriptions
        guard descriptions.isEmpty == false else {
            return PersistentStoreLoadReport(loadedConfigurations: [], errors: [])
        }
        let expectedConfigurations = Set(descriptions.compactMap(\.configuration))

        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var loadedConfigurations = Set<String>()
            var loadErrors: [NSError] = []
            var remainingCallbacks = descriptions.count

            container.loadPersistentStores { storeDescription, error in
                var completedReport: PersistentStoreLoadReport?

                lock.lock()
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
                } else if let configuration = storeDescription.configuration {
                    loadedConfigurations.insert(configuration)
                }

                remainingCallbacks -= 1
                if remainingCallbacks == 0 {
                    completedReport = PersistentStoreLoadReport(
                        loadedConfigurations: loadedConfigurations,
                        errors: loadErrors
                    )
                }
                lock.unlock()

                if let completedReport {
                    continuation.resume(returning: completedReport)
                }
            }
        }
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

    static func validateRuntimeSchema(in model: NSManagedObjectModel) -> NSError? {
        if let weeklyPlanningSchemaError = weeklyPlanningSchemaValidationError(in: model) {
            logError(
                event: "persistent_store_weekly_planning_schema_invalid",
                message: "Loaded Core Data model is missing required weekly planning fields",
                fields: [
                    "error": weeklyPlanningSchemaError.localizedDescription,
                    "missing_requirements": weeklyPlanningSchemaError.userInfo["missingRequirements"] as? String ?? "unknown"
                ]
            )
            return weeklyPlanningSchemaError
        }

        if let habitSchemaError = CoreDataHabitRepository.schemaValidationError(in: model) {
            logError(
                event: "persistent_store_habit_schema_invalid",
                message: "Loaded Core Data model is missing required habit runtime fields",
                fields: [
                    "error": habitSchemaError.localizedDescription,
                    "missing_requirements": habitSchemaError.userInfo["missingRequirements"] as? String ?? "unknown"
                ]
            )
            return habitSchemaError
        }

        if let gamificationSchemaError = CoreDataGamificationRepository.schemaValidationError(in: model) {
            logError(
                event: "persistent_store_gamification_schema_invalid",
                message: "Loaded Core Data model is missing required gamification fields",
                fields: [
                    "error": gamificationSchemaError.localizedDescription,
                    "missing_requirements": gamificationSchemaError.userInfo["missingRequirements"] as? String ?? "unknown"
                ]
            )
            return gamificationSchemaError
        }

        return nil
    }

    private static func weeklyPlanningSchemaValidationError(in model: NSManagedObjectModel) -> NSError? {
        var missingRequirements: [String] = []

        func requireAttributes(entityName: String, attributes: [String]) {
            guard let entity = model.entitiesByName[entityName] else {
                missingRequirements.append("entity:\(entityName)")
                return
            }

            for attribute in attributes where entity.attributesByName[attribute] == nil {
                missingRequirements.append("\(entityName).\(attribute)")
            }
        }

        requireAttributes(
            entityName: "TaskDefinition",
            attributes: [
                "planningBucketRaw",
                "weeklyOutcomeID",
                "deferredFromWeekStart",
                "deferredCount"
            ]
        )
        requireAttributes(
            entityName: "Project",
            attributes: [
                "motivationWhy",
                "motivationSuccessLooksLike",
                "motivationCostOfNeglect"
            ]
        )
        requireAttributes(
            entityName: "WeeklyPlan",
            attributes: [
                "id",
                "weekStartDate",
                "reviewStatus"
            ]
        )
        requireAttributes(
            entityName: "WeeklyOutcome",
            attributes: [
                "id",
                "weeklyPlanID",
                "title",
                "status",
                "orderIndex"
            ]
        )
        requireAttributes(
            entityName: "WeeklyReview",
            attributes: [
                "id",
                "weeklyPlanID",
                "completedAt"
            ]
        )
        requireAttributes(
            entityName: "ReflectionNote",
            attributes: [
                "id",
                "kind",
                "noteText",
                "createdAt"
            ]
        )

        guard missingRequirements.isEmpty == false else {
            return nil
        }

        return NSError(
            domain: "TaskerPersistentStoreBootstrapService",
            code: 301,
            userInfo: [
                NSLocalizedDescriptionKey: "The loaded Core Data model is missing required weekly planning schema.",
                "missingRequirements": missingRequirements.sorted().joined(separator: ",")
            ]
        )
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
