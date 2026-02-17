//
//  AppDelegate.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import CoreData
import CloudKit
import Firebase
import BackgroundTasks

enum PersistentBootstrapState {
    case ready(NSPersistentCloudKitContainer)
    case failed(String)
}

struct PersistentStoreLoadReport {
    let loadedConfigurations: Set<String>
    let errors: [NSError]
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    private let occurrenceRefreshTaskIdentifier = "com.tasker.refresh.occurrences"
    private let expectedStoreConfigurations: Set<String> = ["CloudSync", "LocalOnly"]
    private let v2StoreEpoch = 1

    private(set) static var persistentBootstrapFailureMessage: String?
    static var isPersistentStoreReady: Bool {
        persistentBootstrapFailureMessage == nil
    }

    private(set) var persistentBootstrapState: PersistentBootstrapState = .failed("Persistent store bootstrap has not run")
    private(set) var persistentContainer: NSPersistentCloudKitContainer?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

//        HomeViewController.setDateForViewValue(dateToSetForView: Date.today())
        let launchArguments = ProcessInfo.processInfo.arguments

        // MARK: - UI Testing Mode
        // Handle launch arguments for UI testing
        if launchArguments.contains("-UI_TESTING") {

            // Disable animations for faster, more stable tests
            if launchArguments.contains("-DISABLE_ANIMATIONS") {
                UIView.setAnimationsEnabled(false)
            }

            // Reset app state for clean test runs
            if launchArguments.contains("-RESET_APP_STATE") {
                resetAppState()
            }
        }

        // DEBUG defaults to Firebase off to avoid noisy simulator Network.framework QUIC logs.
        let shouldConfigureFirebase: Bool = {
            #if DEBUG
            return launchArguments.contains("-TASKER_ENABLE_FIREBASE_DEBUG")
            #else
            return true
            #endif
        }()

        if shouldConfigureFirebase {
            FirebaseApp.configure()
            FirebaseConfiguration.shared.setLoggerLevel(.error)

            #if !DEBUG
            Analytics.setAnalyticsCollectionEnabled(true)
            #endif

            #if DEBUG
            let firebaseStartupSource = "debug_launch_argument"
            #else
            let firebaseStartupSource = "release_default_enabled"
            #endif

            logWarning(
                event: "firebase_startup_mode",
                message: "Firebase configured for this run",
                fields: [
                    "enabled": "true",
                    "source": firebaseStartupSource
                ]
            )
        } else {
            logWarning(
                event: "firebase_startup_mode",
                message: "Firebase skipped in DEBUG (opt in with launch arg)",
                fields: [
                    "enabled": "false",
                    "source": "debug_default_disabled",
                    "launch_arg": "-TASKER_ENABLE_FIREBASE_DEBUG"
                ]
            )
        }
        
        // Configure UIAppearance to make ShyHeaderController's dummy table view transparent
        UITableView.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().isOpaque = false
        
        // Fix UITableView header footer view background color warning
        UITableView.appearance().sectionHeaderTopPadding = 0.0

        // Configure UIScrollView appearance for transparent backgrounds in SwiftUI ScrollViews
        UIScrollView.appearance().backgroundColor = UIColor.clear
        UIScrollView.appearance().isOpaque = false
        
        // Register for CloudKit silent pushes
        application.registerForRemoteNotifications()

        // Hard-reset cutover to V2 model/container.
        performV2BootstrapCutoverIfNeeded()

        persistentBootstrapState = bootstrapV2PersistentContainer()
        switch persistentBootstrapState {
        case .ready(let container):
            persistentContainer = container
            AppDelegate.persistentBootstrapFailureMessage = nil

            if V2FeatureFlags.v2Enabled {
                // Setup Clean Architecture - replaces all singleton initialization
                setupCleanArchitecture()
                registerBackgroundTasks()
                scheduleOccurrenceRefresh()
            } else {
                setupCleanArchitecture()
            }

            // 2) Observe remote-change notifications so your viewContext merges them
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePersistentStoreRemoteChange),
                name: .NSPersistentStoreRemoteChange,
                object: container.persistentStoreCoordinator
            )

            // 3) Monitor CloudKit container events for debugging
            NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: container,
                queue: .main
            ) { note in
                guard
                  let userInfo = note.userInfo,
                  let events = userInfo[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                                as? [NSPersistentCloudKitContainer.Event]
                else { return }

                for event in events where event.error != nil {
                    let errorDescription = event.error?.localizedDescription ?? "unknown"
                    logError(
                        event: "cloudkit_event_error",
                        message: "CloudKit container event reported error",
                        fields: [
                            "event_type": "\(event.type)",
                            "error": errorDescription
                        ]
                    )
                }
            }
        case .failed(let message):
            AppDelegate.persistentBootstrapFailureMessage = message
            logWarning(
                event: "persistent_store_bootstrap_fallback",
                message: "Using in-memory fallback container because persistent bootstrap failed",
                fields: ["reason": message]
            )
            let fallbackContainer = makeInMemoryFallbackPersistentContainer()
            persistentContainer = fallbackContainer
            setupCleanArchitecture()
        }
        
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        guard case .ready = persistentBootstrapState else {
            return
        }
        scheduleOccurrenceRefresh()
    }

    // MARK: - UI Testing Helpers

    /// Reset app state for UI testing
    /// This clears UserDefaults and Core Data to ensure clean test runs
    private func resetAppState() {

        // Clear UserDefaults
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        // Clear Core Data
        clearCoreData()
    }

    /// Clear all Core Data entities for testing
    private func clearCoreData() {
        guard let container = persistentContainer else {
            return
        }
        let context = container.viewContext

        // Get all entity names
        guard let entities = container.managedObjectModel.entities.map({ $0.name }) as? [String] else {
            return
        }

        // Delete all objects for each entity
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
            } catch {
                logError(
                    event: "coredata_clear_entity_failed",
                    message: "Failed to clear Core Data entity during UI test reset",
                    fields: [
                        "entity": entityName,
                        "error": error.localizedDescription
                    ]
                )
            }
        }

        // Save context
        do {
            try context.save()
        } catch {
            logError(
                event: "coredata_clear_save_failed",
                message: "Failed to save context after clearing entities",
                fields: [
                    "error": error.localizedDescription
                ]
            )
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data Saving support
    
    func saveContext () {
        guard let context = persistentContainer?.viewContext else {
            return
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                logError(
                    event: "save_context_failed",
                    message: "Failed to save Core Data context",
                    fields: [
                        "domain": nserror.domain,
                        "code": String(nserror.code),
                        "error": nserror.localizedDescription
                    ]
                )
            }
        }
    }
    
    // MARK: - Push Notification Handling
    
    @objc
    func handlePersistentStoreRemoteChange(_ notification: Notification) {
        guard let context = persistentContainer?.viewContext else {
            return
        }
        // Perform merging on the context's queue to avoid threading issues
        context.perform { // Changed from performAndWait to perform for potentially better responsiveness
            context.mergeChanges(fromContextDidSave: notification) // Correct method signature

            // **CRITICAL: Call consolidation logic after merging CloudKit changes**
            // Note: consolidateDataWithCleanArchitecture is private, call setupCleanArchitecture instead
            // or make the method internal in AppDelegate+Migration.swift
            
            // Notify repository system about potential data changes
            NotificationCenter.default.post(name: Notification.Name("DataDidChangeFromCloudSync"), object: nil)

            // Consider posting a custom notification if UI needs to react strongly to these background changes
            // NotificationCenter.default.post(name: Notification.Name("DataDidChangeFromCloudSync"), object: nil)
        }
    }
    
    // Remote notification registration success/failure callbacks
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logError(
            event: "apns_registration_failed",
            message: "APNs registration failed",
            fields: [
                "error": error.localizedDescription
            ]
        )
    }

    // MARK: - V2 Bootstrap

    private func performV2BootstrapCutoverIfNeeded() {
        let defaults = UserDefaults.standard
        let epochKey = "tasker.v2.store.epoch"
        let appliedEpoch = defaults.integer(forKey: epochKey)
        guard appliedEpoch != v2StoreEpoch else {
            return
        }

        let storeDir = NSPersistentContainer.defaultDirectoryURL()
        let fileManager = FileManager.default

        do {
            let files = try fileManager.contentsOfDirectory(at: storeDir, includingPropertiesForKeys: nil)
            let legacyFiles = files.filter { url in
                let name = url.lastPathComponent
                guard name.contains("TaskModel") else { return false }
                return name.contains("TaskModelV2") == false
            }

            for fileURL in legacyFiles {
                try? fileManager.removeItem(at: fileURL)
            }
        } catch {
            logWarning(
                event: "v2_cutover_cleanup_failed",
                message: "Failed to enumerate legacy Core Data stores",
                fields: ["error": error.localizedDescription]
            )
        }

        wipeV2StoreFiles()
    }

    private func markV2BootstrapEpochApplied() {
        UserDefaults.standard.set(v2StoreEpoch, forKey: "tasker.v2.store.epoch")
    }

    private func makeV2PersistentContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "TaskModelV2")

        let baseURL = NSPersistentContainer.defaultDirectoryURL()
        let cloudURL = baseURL.appendingPathComponent("TaskModelV2-cloud.sqlite")
        let localURL = baseURL.appendingPathComponent("TaskModelV2-local.sqlite")

        let cloudDescription = NSPersistentStoreDescription(url: cloudURL)
        cloudDescription.configuration = "CloudSync"
        cloudDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.TaskerCloudKitV2"
        )
        cloudDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        cloudDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let localDescription = NSPersistentStoreDescription(url: localURL)
        localDescription.configuration = "LocalOnly"
        localDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        localDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [cloudDescription, localDescription]
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    private func makeInMemoryFallbackPersistentContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "TaskModelV2")

        let cloudDescription = NSPersistentStoreDescription()
        cloudDescription.type = NSInMemoryStoreType
        cloudDescription.configuration = "CloudSync"
        cloudDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        cloudDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let localDescription = NSPersistentStoreDescription()
        localDescription.type = NSInMemoryStoreType
        localDescription.configuration = "LocalOnly"
        localDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        localDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [cloudDescription, localDescription]
        let report = loadPersistentStoresAndReport(container: container, phase: "fallback_inmemory")
        if report.errors.isEmpty == false || hasExpectedConfigurations(report) == false {
            logError(
                event: "persistent_store_fallback_failed",
                message: "In-memory fallback persistent store failed to load expected configurations",
                fields: [
                    "loaded_configurations": report.loadedConfigurations.sorted().joined(separator: ","),
                    "expected_configurations": expectedStoreConfigurations.sorted().joined(separator: ","),
                    "errors": report.errors.map { "\($0.domain):\($0.code)" }.joined(separator: ", ")
                ]
            )
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    private func bootstrapV2PersistentContainer() -> PersistentBootstrapState {
        let initialContainer = makeV2PersistentContainer()
        let initialReport = loadPersistentStoresAndReport(container: initialContainer, phase: "initial")
        let initialHealthy = initialReport.errors.isEmpty && hasExpectedConfigurations(initialReport)

        if initialHealthy {
            markV2BootstrapEpochApplied()
            return .ready(initialContainer)
        }

        let missingConfigurations = expectedStoreConfigurations.subtracting(initialReport.loadedConfigurations)
        let hasMissingConfigurations = missingConfigurations.isEmpty == false
        let hasCompatibilityError = initialReport.errors.contains(where: isIncompatibleStoreError)
        let shouldRetryWithWipe = hasCompatibilityError || hasMissingConfigurations

        if shouldRetryWithWipe {
            logWarning(
                event: "persistent_store_bootstrap_retry",
                message: "Retrying persistent store bootstrap after V2 store wipe",
                fields: [
                    "retry_attempted": "true",
                    "retry_reason": hasCompatibilityError ? "compatibility_error" : "missing_configuration",
                    "loaded_configurations": initialReport.loadedConfigurations.sorted().joined(separator: ","),
                    "missing_configurations": missingConfigurations.sorted().joined(separator: ","),
                    "error_count": String(initialReport.errors.count)
                ]
            )

            wipeV2StoreFiles()
            let recoveryContainer = makeV2PersistentContainer()
            let recoveryReport = loadPersistentStoresAndReport(container: recoveryContainer, phase: "recovery")
            let recoveryHealthy = recoveryReport.errors.isEmpty && hasExpectedConfigurations(recoveryReport)
            if recoveryHealthy {
                markV2BootstrapEpochApplied()
                return .ready(recoveryContainer)
            }

            let failureMessage = "Tasker could not initialize local storage after retry. Please relaunch or reinstall the app."
            logError(
                event: "persistent_store_bootstrap_failed_after_retry",
                message: "Persistent store bootstrap failed after wipe and retry",
                fields: [
                    "retry_attempted": "true",
                    "loaded_configurations": recoveryReport.loadedConfigurations.sorted().joined(separator: ","),
                    "expected_configurations": expectedStoreConfigurations.sorted().joined(separator: ","),
                    "error_count": String(recoveryReport.errors.count),
                    "errors": recoveryReport.errors.map { "\($0.domain):\($0.code)" }.joined(separator: ", ")
                ]
            )
            return .failed(failureMessage)
        }

        let failureMessage = "Tasker storage is unavailable. Please relaunch the app."
        logError(
            event: "persistent_store_bootstrap_failed_without_retry",
            message: "Persistent store bootstrap failed and was not eligible for wipe/retry",
            fields: [
                "retry_attempted": "false",
                "loaded_configurations": initialReport.loadedConfigurations.sorted().joined(separator: ","),
                "expected_configurations": expectedStoreConfigurations.sorted().joined(separator: ","),
                "error_count": String(initialReport.errors.count),
                "errors": initialReport.errors.map { "\($0.domain):\($0.code)" }.joined(separator: ", ")
            ]
        )
        return .failed(failureMessage)
    }

    private func loadPersistentStoresAndReport(
        container: NSPersistentCloudKitContainer,
        phase: String
    ) -> PersistentStoreLoadReport {
        let descriptions = container.persistentStoreDescriptions
        guard descriptions.isEmpty == false else {
            return PersistentStoreLoadReport(loadedConfigurations: [], errors: [])
        }

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
                let missingConfigurations = self.expectedStoreConfigurations.subtracting(loadedConfigurations)
                logError(
                    event: "persistent_store_load_failed",
                    message: "V2 persistent store failed to load",
                    fields: [
                        "phase": phase,
                        "url": storeDescription.url?.absoluteString ?? "unknown",
                        "configuration": configuration,
                        "domain": error.domain,
                        "code": String(error.code),
                        "error": error.localizedDescription,
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

    private func hasExpectedConfigurations(_ report: PersistentStoreLoadReport) -> Bool {
        expectedStoreConfigurations.isSubset(of: report.loadedConfigurations)
    }

    private func isIncompatibleStoreError(_ error: NSError) -> Bool {
        let code = error.code
        let incompatibleCodes: Set<Int> = [
            NSPersistentStoreInvalidTypeError,
            NSPersistentStoreTypeMismatchError,
            NSPersistentStoreIncompatibleSchemaError,
            NSPersistentStoreOpenError,
            NSPersistentStoreIncompatibleVersionHashError
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

    private func wipeV2StoreFiles() {
        let storeDir = NSPersistentContainer.defaultDirectoryURL()
        let fileManager = FileManager.default
        let v2StoreFileNames = [
            "TaskModelV2-cloud.sqlite",
            "TaskModelV2-cloud.sqlite-wal",
            "TaskModelV2-cloud.sqlite-shm",
            "TaskModelV2-local.sqlite",
            "TaskModelV2-local.sqlite-wal",
            "TaskModelV2-local.sqlite-shm"
        ]

        for fileName in v2StoreFileNames {
            let fileURL = storeDir.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                continue
            }

            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                logWarning(
                    event: "v2_store_file_delete_failed",
                    message: "Failed to delete V2 persistent store file",
                    fields: [
                        "file": fileName,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    private func ensureV2Defaults() {
        guard let context = persistentContainer?.viewContext else {
            return
        }
        context.performAndWait {
            do {
                let lifeAreaRequest = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
                lifeAreaRequest.predicate = NSPredicate(format: "name ==[c] %@", "General")
                lifeAreaRequest.fetchLimit = 1

                let lifeArea: NSManagedObject
                if let existing = try context.fetch(lifeAreaRequest).first {
                    lifeArea = existing
                } else {
                    let created = NSEntityDescription.insertNewObject(forEntityName: "LifeArea", into: context)
                    created.setValue(UUID(), forKey: "id")
                    created.setValue("General", forKey: "name")
                    created.setValue("#4A6FA5", forKey: "color")
                    created.setValue("square.grid.2x2", forKey: "icon")
                    created.setValue(Int32(0), forKey: "sortOrder")
                    created.setValue(false, forKey: "isArchived")
                    created.setValue(Date(), forKey: "createdAt")
                    created.setValue(Date(), forKey: "updatedAt")
                    created.setValue(Int32(1), forKey: "version")
                    lifeArea = created
                }

                let inboxRequest = NSFetchRequest<NSManagedObject>(entityName: "Project")
                inboxRequest.predicate = NSPredicate(format: "projectID == %@", ProjectConstants.inboxProjectID as CVarArg)
                inboxRequest.fetchLimit = 1
                let inbox = try context.fetch(inboxRequest).first ?? NSEntityDescription.insertNewObject(forEntityName: "Project", into: context)
                inbox.setValue(ProjectConstants.inboxProjectID, forKey: "id")
                inbox.setValue(ProjectConstants.inboxProjectID, forKey: "projectID")
                inbox.setValue(lifeArea.value(forKey: "id") as? UUID, forKey: "lifeAreaID")
                inbox.setValue(ProjectConstants.inboxProjectName, forKey: "name")
                inbox.setValue(ProjectConstants.inboxProjectName, forKey: "projectName")
                inbox.setValue(ProjectConstants.inboxProjectDescription, forKey: "projectDescription")
                inbox.setValue(ProjectConstants.inboxProjectDescription, forKey: "projecDescription")
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

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                logError(
                    event: "v2_default_seed_failed",
                    message: "Failed to seed V2 default life area/inbox",
                    fields: ["error": error.localizedDescription]
                )
            }
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: occurrenceRefreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleOccurrenceRefresh(task: refreshTask)
        }
    }

    private func scheduleOccurrenceRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: occurrenceRefreshTaskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date())
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logWarning(
                event: "bg_refresh_schedule_failed",
                message: "Failed to schedule V2 occurrence refresh task",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    private func handleOccurrenceRefresh(task: BGAppRefreshTask) {
        scheduleOccurrenceRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        guard
            let generateUseCase = EnhancedDependencyContainer.shared.useCaseCoordinator.generateOccurrences
        else {
            task.setTaskCompleted(success: true)
            return
        }

        generateUseCase.execute(daysAhead: 14) { result in
            switch result {
            case .success:
                if let maintain = EnhancedDependencyContainer.shared.useCaseCoordinator.maintainOccurrences {
                    maintain.execute { maintainResult in
                        switch maintainResult {
                        case .success:
                            task.setTaskCompleted(success: true)
                        case .failure(let error):
                            logWarning(
                                event: "bg_maintenance_failed",
                                message: "Occurrence maintenance failed in background refresh",
                                fields: ["error": error.localizedDescription]
                            )
                            task.setTaskCompleted(success: false)
                        }
                    }
                } else {
                    task.setTaskCompleted(success: true)
                }
            case .failure(let error):
                logWarning(
                    event: "bg_refresh_execute_failed",
                    message: "Occurrence generation failed in background refresh",
                    fields: ["error": error.localizedDescription]
                )
                task.setTaskCompleted(success: false)
            }
        }
    }

    // MARK: - Clean Architecture Setup

    /// Setup Clean Architecture with modern components only
    func setupCleanArchitecture() {
        guard let persistentContainer else {
            logError(
                event: "setup_clean_architecture_skipped",
                message: "Skipping dependency configuration because persistent container is unavailable",
                fields: ["reason": "persistent_container_nil"]
            )
            return
        }

        // Configure presentation container with typed API (no reflection).
        PresentationDependencyContainer.shared.configure(with: persistentContainer)

        // Seed clean-start V2 defaults.
        ensureV2Defaults()

        // Configure LLM access through repositories (no direct Core Data context pulls).
        LLMContextRepositoryProvider.configure(
            taskRepository: EnhancedDependencyContainer.shared.taskRepository,
            projectRepository: EnhancedDependencyContainer.shared.projectRepository
        )
    }
}
