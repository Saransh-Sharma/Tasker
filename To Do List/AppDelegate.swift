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
import UserNotifications

enum PersistentBootstrapState {
    case ready(NSPersistentCloudKitContainer)
    case failed(String)
}

enum LaunchRootMode: Equatable {
    case home
    case bootstrapFailure(message: String)
}

enum PersistentSyncMode: Equatable {
    case fullSync
    case writeClosed(reason: String)

    var modeName: String {
        switch self {
        case .fullSync:
            return "full_sync"
        case .writeClosed:
            return "write_closed"
        }
    }

    var reason: String {
        switch self {
        case .fullSync:
            return "healthy_split_store"
        case .writeClosed(let reason):
            return reason
        }
    }
}

struct PersistentStoreLoadReport {
    let loadedConfigurations: Set<String>
    let errors: [NSError]
}

enum CloudKitMirroringMode: Equatable {
    case enabled
    case disabled(reason: String)

    var reason: String {
        switch self {
        case .enabled:
            return "enabled"
        case .disabled(let reason):
            return reason
        }
    }
}

struct CloudKitRuntimeContext {
    let environment: [String: String]
    let arguments: [String]
    let isSimulator: Bool

    static func current(processInfo: ProcessInfo = .processInfo) -> Self {
#if targetEnvironment(simulator)
        let isSimulator = true
#else
        let isSimulator = false
#endif
        return Self(
            environment: processInfo.environment,
            arguments: processInfo.arguments,
            isSimulator: isSimulator
        )
    }
}

extension Notification.Name {
    static let taskerPersistentSyncModeDidChange = Notification.Name("TaskerPersistentSyncModeDidChange")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private let occurrenceRefreshTaskIdentifier = "com.tasker.refresh.occurrences"
    private let remindersRefreshTaskIdentifier = "com.tasker.refresh.reminders"
    private let expectedStoreConfigurations: Set<String> = ["CloudSync", "LocalOnly"]
    private let localOnlyConfiguration: Set<String> = ["LocalOnly"]
    private let cloudKitContainerIdentifier = "iCloud.TaskerCloudKitV3"
    private let v3StoreEpoch = 4
    private let orientationPolicyResolver = DeviceOrientationPolicyResolver()
    private var notificationOrchestrator: TaskNotificationOrchestrator?
    private var notificationActionHandler: TaskerNotificationActionHandler?
    private var gamificationRemoteChangeCoordinator: GamificationRemoteChangeCoordinator?
    private var cloudKitEventObserver: NSObjectProtocol?

    private(set) static var persistentBootstrapFailureMessage: String?
    private(set) static var persistentSyncMode: PersistentSyncMode = .fullSync
    static var isPersistentStoreReady: Bool {
        persistentBootstrapFailureMessage == nil
    }
    static var isWriteClosed: Bool {
        if case .writeClosed = persistentSyncMode {
            return true
        }
        return false
    }

    private(set) var persistentBootstrapState: PersistentBootstrapState = .failed("Persistent store bootstrap has not run")
    private(set) var persistentContainer: NSPersistentCloudKitContainer?
    private var didScheduleDeferredLaunchServices = false
    private let deferredLaunchWarmupQueue = DispatchQueue(
        label: "tasker.app.launchWarmup",
        qos: .utility
    )


    /// Executes application.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let launchInterval = TaskerPerformanceTrace.begin("AppLaunchCriticalPath")
        defer { TaskerPerformanceTrace.end(launchInterval) }

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

        // Configure UIAppearance to make ShyHeaderController's dummy table view transparent
        UITableView.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().isOpaque = false
        
        // Fix UITableView header footer view background color warning
        UITableView.appearance().sectionHeaderTopPadding = 0.0

        // Configure UIScrollView appearance for transparent backgrounds in SwiftUI ScrollViews
        UIScrollView.appearance().backgroundColor = UIColor.clear
        UIScrollView.appearance().isOpaque = false
        
        // Hard-reset cutover to V3 model/container.
        let bootstrapInterval = TaskerPerformanceTrace.begin("PersistentBootstrap")
        performV3BootstrapCutoverIfNeeded()
        _ = applyBootstrapState(bootstrapV3PersistentContainer(), trigger: "launch")
        TaskerPerformanceTrace.end(bootstrapInterval)
        scheduleDeferredLaunchServices(
            application: application,
            shouldConfigureFirebase: shouldConfigureFirebase
        )
        
        return true
    }

    private func scheduleDeferredLaunchServices(
        application: UIApplication,
        shouldConfigureFirebase: Bool
    ) {
        guard didScheduleDeferredLaunchServices == false else { return }
        didScheduleDeferredLaunchServices = true

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
            guard let self else { return }
            self.runDeferredLaunchPostFirstFrameMain(application: application)
            self.deferredLaunchWarmupQueue.async { [weak self] in
                self?.runDeferredLaunchBackgroundWarmup(shouldConfigureFirebase: shouldConfigureFirebase)
            }
        }
    }

    private func runDeferredLaunchPostFirstFrameMain(
        application: UIApplication
    ) {
        let interval = TaskerPerformanceTrace.begin("DeferredLaunchPostFirstFrameMain")
        defer { TaskerPerformanceTrace.end(interval) }
        application.registerForRemoteNotifications()
    }

    private func runDeferredLaunchBackgroundWarmup(
        shouldConfigureFirebase: Bool
    ) {
        let interval = TaskerPerformanceTrace.begin("DeferredLaunchBackgroundWarmup")
        defer { TaskerPerformanceTrace.end(interval) }

        configureFirebaseIfNeeded(shouldConfigureFirebase)
        logCloudKitPreflightTelemetry()
    }

    private func configureFirebaseIfNeeded(_ shouldConfigureFirebase: Bool) {
        guard shouldConfigureFirebase else {
            logWarning(
                event: "firebase_startup_mode",
                message: "Firebase skipped in DEBUG (opt in with launch arg)",
                fields: [
                    "enabled": "false",
                    "source": "debug_default_disabled",
                    "launch_arg": "-TASKER_ENABLE_FIREBASE_DEBUG"
                ]
            )
            return
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            FirebaseConfiguration.shared.setLoggerLevel(.error)

            #if !DEBUG
            Analytics.setAnalyticsCollectionEnabled(true)
            #endif
        }

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
        GamificationRemoteKillSwitchService.shared.refreshIfAvailable(reason: "app_launch")
    }

    /// Executes applicationDidEnterBackground.
    func applicationDidEnterBackground(_ application: UIApplication) {
        guard case .ready = persistentBootstrapState else {
            return
        }
        if AppDelegate.isWriteClosed == false {
            scheduleOccurrenceRefresh()
            if V2FeatureFlags.remindersBackgroundRefreshEnabled {
                scheduleRemindersRefresh()
            }
        }
        reconcileNotifications(reason: "app_did_enter_background")
    }

    /// Executes applicationWillEnterForeground.
    func applicationWillEnterForeground(_ application: UIApplication) {
        reconcileNotifications(reason: "app_will_enter_foreground")
    }

    /// Executes applicationDidBecomeActive.
    func applicationDidBecomeActive(_ application: UIApplication) {
        reconcileNotifications(reason: "app_did_become_active")
        if FirebaseApp.app() != nil {
            GamificationRemoteKillSwitchService.shared.refreshIfAvailable(reason: "app_did_become_active")
        }
        TaskListWidgetSnapshotService.shared.scheduleRefresh(reason: "app_did_become_active")
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        let idiom = window?.windowScene?.traitCollection.userInterfaceIdiom
            ?? window?.traitCollection.userInterfaceIdiom
            ?? UIDevice.current.userInterfaceIdiom
        return orientationPolicyResolver.supportedOrientations(for: idiom)
    }

    /// Executes makeLaunchRootMode.
    func makeLaunchRootMode(state overrideState: PersistentBootstrapState? = nil) -> LaunchRootMode {
        let state = overrideState ?? persistentBootstrapState
        switch state {
        case .ready:
            return .home
        case .failed(let message):
            return .bootstrapFailure(message: message)
        }
    }

    private func updatePersistentSyncMode(_ mode: PersistentSyncMode, source: String) {
        let previous = AppDelegate.persistentSyncMode
        AppDelegate.persistentSyncMode = mode

        guard previous != mode else { return }
        NotificationCenter.default.post(
            name: .taskerPersistentSyncModeDidChange,
            object: nil,
            userInfo: [
                "mode": mode.modeName,
                "reason": mode.reason,
                "source": source
            ]
        )
    }

    @discardableResult
    private func applyBootstrapState(_ state: PersistentBootstrapState, trigger: String) -> LaunchRootMode {
        persistentBootstrapState = state

        switch state {
        case .ready(let container):
            persistentContainer = container
            AppDelegate.persistentBootstrapFailureMessage = nil

            let didConfigureRuntime = setupCleanArchitecture()
            guard didConfigureRuntime else {
                return makeLaunchRootMode()
            }

            gamificationRemoteChangeCoordinator = GamificationRemoteChangeCoordinator(
                container: container,
                notificationCenter: .default,
                onQualifiedCloudImport: { reason in
                    guard V2FeatureFlags.gamificationV2Enabled else { return }
                    let engine = PresentationDependencyContainer.shared.coordinator.gamificationEngine
                    engine.fullReconciliation { result in
                        switch result {
                        case .success:
                            engine.writeWidgetSnapshot()
                        case .failure(let error):
                            logError(
                                event: "gamification_remote_reconciliation_failed",
                                message: "Gamification reconciliation failed after qualified CloudKit import transaction",
                                fields: [
                                    "reason": reason,
                                    "error": error.localizedDescription
                                ]
                            )
                        }
                    }
                }
            )

            registerBackgroundTasks()
            if AppDelegate.isWriteClosed {
                logWarning(
                    event: "write_closed_background_mutations_skipped",
                    message: "Skipping background write workflows while app is in write-closed sync mode",
                    fields: [
                        "trigger": trigger,
                        "reason": AppDelegate.persistentSyncMode.reason
                    ]
                )
            } else {
                scheduleOccurrenceRefresh()
                if V2FeatureFlags.remindersBackgroundRefreshEnabled {
                    scheduleRemindersRefresh()
                }
            }
            configureTaskerNotifications()
            installPersistentStoreObservers(container: container)
            TaskListWidgetSnapshotService.shared.scheduleRefresh(reason: "bootstrap_ready")

            logWarning(
                event: "persistent_sync_mode_activated",
                message: "Persistent sync mode activated",
                fields: [
                    "mode": AppDelegate.persistentSyncMode.modeName,
                    "reason": AppDelegate.persistentSyncMode.reason,
                    "trigger": trigger
                ]
            )
            return .home

        case .failed(let message):
            AppDelegate.persistentBootstrapFailureMessage = message
            persistentContainer = nil
            gamificationRemoteChangeCoordinator = nil
            NotificationCenter.default.removeObserver(
                self,
                name: .NSPersistentStoreRemoteChange,
                object: nil
            )
            if let cloudKitEventObserver {
                NotificationCenter.default.removeObserver(cloudKitEventObserver)
                self.cloudKitEventObserver = nil
            }
            logError(
                event: "persistent_store_bootstrap_failed",
                message: "Persistent store bootstrap failed; running without initialized persistence",
                fields: [
                    "reason": message,
                    "trigger": trigger,
                    "sync_mode": AppDelegate.persistentSyncMode.modeName,
                    "sync_reason": AppDelegate.persistentSyncMode.reason
                ]
            )
            return .bootstrapFailure(message: message)
        }
    }

    private func installPersistentStoreObservers(container: NSPersistentCloudKitContainer) {
        NotificationCenter.default.removeObserver(
            self,
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentStoreRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )

        if let cloudKitEventObserver {
            NotificationCenter.default.removeObserver(cloudKitEventObserver)
            self.cloudKitEventObserver = nil
        }

        cloudKitEventObserver = NotificationCenter.default.addObserver(
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
    }

    func retryPersistentStoreBootstrap() -> LaunchRootMode {
        logWarning(
            event: "persistent_store_manual_retry_started",
            message: "User requested persistent store retry"
        )
        return rebootstrapPersistentStore(trigger: "manual_retry")
    }

    func recoverFromCloudAuthoritativeReset() -> LaunchRootMode {
        logWarning(
            event: "persistent_store_recovery_started",
            message: "Starting cloud-authoritative persistent store recovery"
        )

        do {
            let quarantineURL = try quarantineV3StoreFiles(reason: "cloud_authoritative_reset")
            clearActiveV3SplitStoreFiles()
            let launchMode = rebootstrapPersistentStore(trigger: "cloud_authoritative_reset")
            switch launchMode {
            case .home:
                logWarning(
                    event: "persistent_store_recovery_completed",
                    message: "Cloud-authoritative recovery completed",
                    fields: [
                        "quarantine_dir": quarantineURL?.path ?? "none"
                    ]
                )
            case .bootstrapFailure(let message):
                logError(
                    event: "persistent_store_recovery_failed",
                    message: "Cloud-authoritative recovery completed quarantine but bootstrap still failed",
                    fields: [
                        "quarantine_dir": quarantineURL?.path ?? "none",
                        "reason": message
                    ]
                )
            }
            return launchMode
        } catch {
            let message = "Tasker could not prepare local stores for iCloud recovery."
            logError(
                event: "persistent_store_recovery_quarantine_failed",
                message: "Cloud-authoritative recovery could not quarantine local stores",
                fields: [
                    "error": error.localizedDescription
                ]
            )
            updatePersistentSyncMode(
                .writeClosed(reason: "recovery_preparation_failed"),
                source: "cloud_authoritative_reset"
            )
            return applyBootstrapState(.failed(message), trigger: "cloud_authoritative_reset")
        }
    }

    private func rebootstrapPersistentStore(trigger: String) -> LaunchRootMode {
        if let currentContainer = persistentContainer {
            unloadPersistentStores(currentContainer)
        }
        persistentContainer = nil
        gamificationRemoteChangeCoordinator = nil
        return applyBootstrapState(bootstrapV3PersistentContainer(), trigger: trigger)
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

    /// Executes application.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    /// Executes application.
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data Saving support
    
    /// Executes saveContext.
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
    
    /// Executes handlePersistentStoreRemoteChange.
    @objc
    func handlePersistentStoreRemoteChange(_ notification: Notification) {
        gamificationRemoteChangeCoordinator?.handleRemoteChange(notification)
    }
    
    // Remote notification registration success/failure callbacks
    /// Executes application.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    }
    
    /// Executes application.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logError(
            event: "apns_registration_failed",
            message: "APNs registration failed",
            fields: [
                "error": error.localizedDescription
            ]
        )
    }

    // MARK: - Local Notification Runtime

    private func configureTaskerNotifications() {
        guard let taskRepository = EnhancedDependencyContainer.shared.taskDefinitionRepository,
              let notificationService = EnhancedDependencyContainer.shared.notificationService
        else {
            return
        }

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: taskRepository,
            notificationService: notificationService,
            gamificationRepository: EnhancedDependencyContainer.shared.gamificationRepository,
            preferencesStore: .shared,
            reconcileDebounceInterval: 0.35
        )
        orchestrator.startObservingMutations()
        notificationOrchestrator = orchestrator
        TaskerNotificationRuntime.orchestrator = orchestrator

        let actionHandler = TaskerNotificationActionHandler(
            notificationService: notificationService,
            coordinatorProvider: {
                let container = PresentationDependencyContainer.shared
                guard container.isConfiguredForRuntime else { return nil }
                return container.coordinator
            }
        )
        notificationActionHandler = actionHandler
        TaskerNotificationRuntime.actionHandler = actionHandler

        notificationService.registerCategories(TaskerNotificationCategories.all())
        notificationService.setDelegate(self)

        notificationService.fetchAuthorizationStatus { status in
            switch status {
            case .notDetermined:
                notificationService.requestPermission { granted in
                    if granted {
                        orchestrator.reconcile(reason: "permission_granted")
                    }
                }
            case .authorized, .provisional, .ephemeral:
                orchestrator.reconcile(reason: "app_launch_authorized")
            case .denied:
                break
            }
        }
    }

    func reconcileNotifications(reason: String = "manual") {
        notificationOrchestrator?.reconcile(reason: reason)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logWarning(
            event: "notification_delivered",
            message: "Notification delivered while app is foreground",
            fields: [
                "id": notification.request.identifier
            ]
        )
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let notificationActionHandler else {
            completionHandler()
            return
        }
        notificationActionHandler.handleAction(
            identifier: response.actionIdentifier,
            request: response.notification.request,
            completion: completionHandler
        )
    }

    // MARK: - V3 Bootstrap

    /// Executes performV3BootstrapCutoverIfNeeded.
    private func performV3BootstrapCutoverIfNeeded() {
        let defaults = UserDefaults.standard
        let epochKey = "tasker.v3.store.epoch"
        let appliedEpoch = defaults.integer(forKey: epochKey)
        guard appliedEpoch != v3StoreEpoch else {
            return
        }

        wipeV3StoreFiles()
        clearLegacyV1PreferenceKeys(defaults: defaults)
    }

    /// Executes markV3BootstrapEpochApplied.
    private func markV3BootstrapEpochApplied() {
        UserDefaults.standard.set(v3StoreEpoch, forKey: "tasker.v3.store.epoch")
    }

    /// Executes makeV3PersistentContainer.
    private func makeV3PersistentContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "TaskModelV3")
        let cloudKitMode = cloudKitMirroringMode()

        let baseURL = NSPersistentContainer.defaultDirectoryURL()
        let cloudURL = baseURL.appendingPathComponent("TaskModelV3-cloud.sqlite")
        let localURL = baseURL.appendingPathComponent("TaskModelV3-local.sqlite")

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

    /// Executes makeV3LocalOnlyWriteClosedContainer.
    /// Creates a local-only runtime topology used for write-closed operation.
    private func makeV3LocalOnlyWriteClosedContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "TaskModelV3")

        let baseURL = NSPersistentContainer.defaultDirectoryURL()
        let localURL = baseURL.appendingPathComponent("TaskModelV3-local.sqlite")
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

    /// Executes cloudKitMirroringMode.
    ///
    /// Keep CloudKit mirroring off in simulator/XCTest runs to avoid startup crashes in
    /// unsigned test hosts where runtime entitlements are unavailable.
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

    private func logCloudKitPreflightTelemetry() {
        let entitlementPresent = runtimeHasCloudKitEntitlement(containerIdentifier: cloudKitContainerIdentifier)
        let mirroringMode = cloudKitMirroringMode()
        logWarning(
            event: "cloudkit_preflight",
            message: "CloudKit runtime preflight diagnostics",
            fields: [
                "container_id": cloudKitContainerIdentifier,
                "entitlement_present": String(entitlementPresent),
                "mirroring_mode": mirroringMode.reason
            ]
        )

        guard case .enabled = mirroringMode else {
            logWarning(
                event: "cloudkit_preflight_skipped",
                message: "Skipped CloudKit account status preflight because runtime disables CloudKit",
                fields: [
                    "container_id": cloudKitContainerIdentifier,
                    "entitlement_present": String(entitlementPresent),
                    "mirroring_mode": mirroringMode.reason
                ]
            )
            return
        }

        CKContainer(identifier: cloudKitContainerIdentifier).accountStatus { status, error in
            var fields: [String: String] = [
                "container_id": self.cloudKitContainerIdentifier,
                "account_status": self.cloudAccountStatusDescription(status)
            ]
            if let error {
                fields["error"] = error.localizedDescription
            }
            logWarning(
                event: "cloudkit_account_status",
                message: "CloudKit account status preflight completed",
                fields: fields
            )
        }
    }

    private func runtimeHasCloudKitEntitlement(containerIdentifier: String) -> Bool {
        // Diagnostic inference only: if the app cannot resolve the ubiquity container URL,
        // iCloud container entitlement/runtime availability is likely not valid for this process.
        return FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) != nil
    }

    private func cloudAccountStatusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "available"
        case .noAccount:
            return "no_account"
        case .restricted:
            return "restricted"
        case .couldNotDetermine:
            return "unknown"
        case .temporarilyUnavailable:
            return "temporarily_unavailable"
        @unknown default:
            return "unknown_future_case"
        }
    }

    /// Executes bootstrapV3PersistentContainer.
    private func bootstrapV3PersistentContainer() -> PersistentBootstrapState {
        let initialContainer = makeV3PersistentContainer()
        let initialReport = loadPersistentStoresAndReport(container: initialContainer, phase: "initial")
        let initialHealthy = initialReport.errors.isEmpty && hasExpectedConfigurations(initialReport)

        if initialHealthy {
            updatePersistentSyncMode(.fullSync, source: "bootstrap_initial")
            markV3BootstrapEpochApplied()
            return .ready(initialContainer)
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
            updatePersistentSyncMode(
                .writeClosed(reason: fallbackReason),
                source: "bootstrap_write_closed"
            )
            markV3BootstrapEpochApplied()
            logWarning(
                event: "persistent_sync_write_closed_enabled",
                message: "CloudSync store unavailable; app launched in write-closed local-read mode",
                fields: [
                    "reason": fallbackReason,
                    "loaded_configurations": writeClosedReport.loadedConfigurations.sorted().joined(separator: ",")
                ]
            )
            return .ready(writeClosedContainer)
        }

        let failureMessage = "Tasker could not initialize local storage. Please relaunch the app or recover from iCloud."
        updatePersistentSyncMode(
            .writeClosed(reason: "persistent_store_unreadable"),
            source: "bootstrap_failed"
        )
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
        return .failed(failureMessage)
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

    /// Executes loadPersistentStoresAndReport.
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

    /// Executes hasExpectedConfigurations.
    private func hasExpectedConfigurations(_ report: PersistentStoreLoadReport) -> Bool {
        expectedStoreConfigurations.isSubset(of: report.loadedConfigurations)
    }

    private func hasLocalOnlyConfiguration(_ report: PersistentStoreLoadReport) -> Bool {
        localOnlyConfiguration.isSubset(of: report.loadedConfigurations)
    }

    /// Executes unloadPersistentStores.
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

    /// Executes isIncompatibleStoreError.
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

    /// Executes wipeV3StoreFiles.
    private func wipeV3StoreFiles() {
        let storeDir = NSPersistentContainer.defaultDirectoryURL()
        let fileManager = FileManager.default
        for fileName in allKnownCutoverStoreFileNames() {
            let fileURL = storeDir.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                continue
            }

            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                logWarning(
                    event: "v3_store_file_delete_failed",
                    message: "Failed to delete V3 cutover persistent store file",
                    fields: [
                        "file": fileName,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    private func allKnownCutoverStoreFileNames() -> [String] {
        return [
            "TaskModelV2-cloud.sqlite",
            "TaskModelV2-cloud.sqlite-wal",
            "TaskModelV2-cloud.sqlite-shm",
            "TaskModelV2-local.sqlite",
            "TaskModelV2-local.sqlite-wal",
            "TaskModelV2-local.sqlite-shm"
        ] + v3SplitStoreFileNames() + [
            // Cleanup of a previously introduced fallback topology.
            "TaskModelV3-unified.sqlite",
            "TaskModelV3-unified.sqlite-wal",
            "TaskModelV3-unified.sqlite-shm"
        ]
    }

    private func v3SplitStoreFileNames() -> [String] {
        [
            "TaskModelV3-cloud.sqlite",
            "TaskModelV3-cloud.sqlite-wal",
            "TaskModelV3-cloud.sqlite-shm",
            "TaskModelV3-local.sqlite",
            "TaskModelV3-local.sqlite-wal",
            "TaskModelV3-local.sqlite-shm"
        ]
    }

    private func quarantineV3StoreFiles(reason: String) throws -> URL? {
        let fileManager = FileManager.default
        let storeDir = NSPersistentContainer.defaultDirectoryURL()
        let storeURLs = v3SplitStoreFileNames().map { storeDir.appendingPathComponent($0) }
        let existingURLs = storeURLs.filter { fileManager.fileExists(atPath: $0.path) }
        guard existingURLs.isEmpty == false else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let timestamp = formatter.string(from: Date())
        let backupRoot = storeDir.appendingPathComponent("TaskerStoreQuarantine", isDirectory: true)
        let reasonComponent = sanitizePathComponent(reason)
        let backupDirectory = backupRoot.appendingPathComponent("\(timestamp)-\(reasonComponent)", isDirectory: true)

        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        for sourceURL in existingURLs {
            let destinationURL = backupDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }

        return backupDirectory
    }

    private func clearActiveV3SplitStoreFiles() {
        let fileManager = FileManager.default
        let storeDir = NSPersistentContainer.defaultDirectoryURL()
        for fileName in v3SplitStoreFileNames() {
            let fileURL = storeDir.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                logWarning(
                    event: "v3_store_clear_after_quarantine_failed",
                    message: "Failed to clear active V3 split store file after quarantine",
                    fields: [
                        "file": fileName,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    private func sanitizePathComponent(_ rawValue: String) -> String {
        let result = rawValue.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        return result.isEmpty ? "reason" : result
    }

    /// Executes clearLegacyV1PreferenceKeys.
    private func clearLegacyV1PreferenceKeys(defaults: UserDefaults) {
        let legacyKeys = [
            "home.focus.lastFilterState.v1",
            "home.focus.pinnedTaskIDs.v1",
            "home.focus.savedViews.v1"
        ]
        for key in legacyKeys {
            defaults.removeObject(forKey: key)
        }
    }

    /// Executes ensureV3Defaults.
    private func ensureV3Defaults() {
        guard let context = persistentContainer?.viewContext else {
            return
        }
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
                inboxRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "id == %@", ProjectConstants.inboxProjectID as CVarArg),
                    NSPredicate(format: "isInbox == YES"),
                    NSPredicate(format: "isDefault == YES"),
                    NSPredicate(format: "name ==[c] %@", ProjectConstants.inboxProjectName)
                ])
                inboxRequest.fetchLimit = 1
                let inbox = try context.fetch(inboxRequest).first ?? NSEntityDescription.insertNewObject(forEntityName: "Project", into: context)
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

    /// Executes fetchGeneralLifeArea.
    private func fetchGeneralLifeArea(in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
        request.predicate = NSPredicate(format: "name ==[c] %@", "General")
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Executes fetchLifeArea.
    private func fetchLifeArea(id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Executes backfillTaskLifeAreaIDsIfNeeded.
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

    /// Executes registerBackgroundTasks.
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

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: remindersRefreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleRemindersRefresh(task: refreshTask)
        }
    }

    /// Executes scheduleOccurrenceRefresh.
    private func scheduleOccurrenceRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: occurrenceRefreshTaskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date())
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logWarning(
                event: "bg_refresh_schedule_failed",
                message: "Failed to schedule V3 occurrence refresh task",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    /// Executes scheduleRemindersRefresh.
    private func scheduleRemindersRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: remindersRefreshTaskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logWarning(
                event: "bg_reminders_schedule_failed",
                message: "Failed to schedule reminders background refresh task",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    /// Executes handleOccurrenceRefresh.
    private func handleOccurrenceRefresh(task: BGAppRefreshTask) {
        scheduleOccurrenceRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        let generateUseCase = PresentationDependencyContainer.shared.coordinator.generateOccurrences

        generateUseCase.execute(daysAhead: 14) { result in
            switch result {
            case .success:
                let maintain = PresentationDependencyContainer.shared.coordinator.maintainOccurrences
                let purge = PresentationDependencyContainer.shared.coordinator.purgeExpiredTombstones

                maintain.execute { maintainResult in
                    switch maintainResult {
                    case .success:
                        purge.execute { purgeResult in
                            switch purgeResult {
                            case .success:
                                task.setTaskCompleted(success: true)
                            case .failure(let error):
                                logWarning(
                                    event: "bg_tombstone_purge_failed",
                                    message: "Tombstone purge failed in background refresh",
                                    fields: ["error": error.localizedDescription]
                                )
                                task.setTaskCompleted(success: false)
                            }
                        }
                    case .failure(let error):
                        logWarning(
                            event: "bg_maintenance_failed",
                            message: "Occurrence maintenance failed in background refresh",
                            fields: ["error": error.localizedDescription]
                        )
                        task.setTaskCompleted(success: false)
                    }
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

    /// Executes handleRemindersRefresh.
    private func handleRemindersRefresh(task: BGAppRefreshTask) {
        scheduleRemindersRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        guard V2FeatureFlags.remindersSyncEnabled, V2FeatureFlags.remindersBackgroundRefreshEnabled else {
            task.setTaskCompleted(success: true)
            return
        }

        let reconcileUseCase = PresentationDependencyContainer.shared.coordinator.reconcileExternalReminders
        guard let externalRepository = EnhancedDependencyContainer.shared.externalSyncRepository else {
            logWarning(
                event: "bg_reminders_missing_dependencies",
                message: "Skipping reminders refresh because V3 sync dependencies are unavailable",
                fields: [:]
            )
            task.setTaskCompleted(success: false)
            return
        }

        externalRepository.fetchContainerMappings { result in
            switch result {
            case .failure(let error):
                logWarning(
                    event: "bg_reminders_fetch_mappings_failed",
                    message: "Failed to load external container mappings for reminders refresh",
                    fields: ["error": error.localizedDescription]
                )
                task.setTaskCompleted(success: false)
            case .success(let mappings):
                let syncedMappings = mappings.filter { $0.provider == "apple_reminders" && $0.syncEnabled }
                guard syncedMappings.isEmpty == false else {
                    task.setTaskCompleted(success: true)
                    return
                }

                self.processReminderReconcileQueue(
                    mappings: syncedMappings,
                    index: 0,
                    reconcileUseCase: reconcileUseCase,
                    externalRepository: externalRepository,
                    failureCount: 0
                ) { failureCount in
                    task.setTaskCompleted(success: failureCount == 0)
                }
            }
        }
    }

    /// Executes processReminderReconcileQueue.
    private func processReminderReconcileQueue(
        mappings: [ExternalContainerMapDefinition],
        index: Int,
        reconcileUseCase: ReconcileExternalRemindersUseCase,
        externalRepository: ExternalSyncRepositoryProtocol,
        failureCount: Int,
        completion: @escaping (Int) -> Void
    ) {
        guard index < mappings.count else {
            completion(failureCount)
            return
        }

        let mapping = mappings[index]
        var didFinish = false
        let timeoutItem = DispatchWorkItem { [weak self] in
            guard didFinish == false else { return }
            didFinish = true
            logWarning(
                event: "bg_reminders_project_timeout",
                message: "Project reconcile timed out in background reminders refresh",
                fields: [
                    "project_id": mapping.projectID.uuidString,
                    "external_container_id": mapping.externalContainerID
                ]
            )
            self?.processReminderReconcileQueue(
                mappings: mappings,
                index: index + 1,
                reconcileUseCase: reconcileUseCase,
                externalRepository: externalRepository,
                failureCount: failureCount + 1,
                completion: completion
            )
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 55, execute: timeoutItem)

        reconcileUseCase.reconcileProject(projectID: mapping.projectID) { [weak self] result in
            guard didFinish == false else { return }
            didFinish = true
            timeoutItem.cancel()

            switch result {
            case .success:
                externalRepository.upsertContainerMapping(
                    provider: mapping.provider,
                    projectID: mapping.projectID
                ) { existing in
                    var resolved = existing ?? mapping
                    resolved.lastSyncAt = Date()
                    resolved.syncEnabled = true
                    return resolved
                } completion: { _ in
                    self?.processReminderReconcileQueue(
                        mappings: mappings,
                        index: index + 1,
                        reconcileUseCase: reconcileUseCase,
                        externalRepository: externalRepository,
                        failureCount: failureCount,
                        completion: completion
                    )
                }
            case .failure(let error):
                logWarning(
                    event: "bg_reminders_project_failed",
                    message: "Project reconcile failed in background reminders refresh",
                    fields: [
                        "project_id": mapping.projectID.uuidString,
                        "external_container_id": mapping.externalContainerID,
                        "error": error.localizedDescription
                    ]
                )
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    self?.processReminderReconcileQueue(
                        mappings: mappings,
                        index: index + 1,
                        reconcileUseCase: reconcileUseCase,
                        externalRepository: externalRepository,
                        failureCount: failureCount + 1,
                        completion: completion
                    )
                }
            }
        }
    }

    // MARK: - Clean Architecture Setup

    /// Setup Clean Architecture with modern components only
    @discardableResult
    func setupCleanArchitecture() -> Bool {
        guard let persistentContainer else {
            logError(
                event: "setup_clean_architecture_skipped",
                message: "Skipping dependency configuration because persistent container is unavailable",
                fields: ["reason": "persistent_container_nil"]
            )
            return false
        }

        // Freeze runtime composition to AppDelegate -> PresentationDependencyContainer -> UseCaseCoordinator.
        let stateContainer = EnhancedDependencyContainer.shared
        stateContainer.configure(with: persistentContainer)

        do {
            try stateContainer.assertV3RuntimeReady()
        } catch {
            return failClosedV3Runtime(reason: error.localizedDescription)
        }

        PresentationDependencyContainer.shared.configure(
            taskReadModelRepository: stateContainer.taskReadModelRepository,
            projectRepository: stateContainer.projectRepository,
            useCaseCoordinator: stateContainer.useCaseCoordinator
        )

        do {
            try PresentationDependencyContainer.shared.assertV3RuntimeReady()
        } catch {
            return failClosedV3Runtime(reason: error.localizedDescription)
        }

        // Seed clean-start V3 defaults.
        ensureV3Defaults()
        repairProjectIdentityIfNeeded()

        // Reconcile gamification data on launch
        if V2FeatureFlags.gamificationV2Enabled {
            let engine = stateContainer.useCaseCoordinator.gamificationEngine
            engine.fullReconciliation { result in
                switch result {
                case .success:
                    engine.writeWidgetSnapshot()
                    engine.updateStreak { streakResult in
                        if case .failure(let error) = streakResult {
                            logError(
                                event: "gamification_startup_streak_update_failed",
                                message: "Gamification startup streak update failed after successful reconciliation",
                                fields: [
                                    "error": error.localizedDescription
                                ]
                            )
                        }
                    }
                case .failure(let error):
                    logError(
                        event: "gamification_startup_reconciliation_failed",
                        message: "Gamification startup reconciliation failed; skipping startup follow-up updates",
                        fields: [
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
        }

        // Configure LLM access through repositories (no direct Core Data context pulls).
        LLMContextRepositoryProvider.configure(
            taskReadModelRepository: stateContainer.taskReadModelRepository,
            projectRepository: stateContainer.projectRepository,
            lifeAreaRepository: stateContainer.lifeAreaRepository,
            tagRepository: stateContainer.tagRepository
        )
        return true
    }

    /// Executes failClosedV3Runtime.
    private func failClosedV3Runtime(reason: String) -> Bool {
        let failureMessage = "Tasker failed to initialize required V3 runtime dependencies."
        persistentBootstrapState = .failed(failureMessage)
        persistentContainer = nil
        AppDelegate.persistentBootstrapFailureMessage = failureMessage
        updatePersistentSyncMode(
            .writeClosed(reason: "runtime_dependency_initialization_failed"),
            source: "setup_clean_architecture"
        )
        logError(
            event: "v3_runtime_not_ready",
            message: "Failing closed because required V3 runtime dependencies are missing",
            fields: ["reason": reason]
        )
        return false
    }

    /// Executes repairProjectIdentityIfNeeded.
    private func repairProjectIdentityIfNeeded() {
        let manageProjects = PresentationDependencyContainer.shared.coordinator.manageProjects
        manageProjects.repairProjectIdentityCollisions { result in
            switch result {
            case .success(let report):
                logWarning(
                    event: "project_identity_repair",
                    message: "Project identity repair completed",
                    fields: [
                        "scanned": String(report.scanned),
                        "merged": String(report.merged),
                        "deleted": String(report.deleted),
                        "inbox_candidates": String(report.inboxCandidates),
                        "warnings_count": String(report.warnings.count)
                    ]
                )
            case .failure(let error):
                logError(
                    event: "project_identity_repair_failed",
                    message: "Project identity repair failed",
                    fields: ["error": error.localizedDescription]
                )
            }
        }
    }
}

enum GamificationRemoteChangeClassifier {
    static func isQualifiedCloudImport(author: String?, contextName: String?) -> Bool {
        let normalizedAuthor = (author ?? "").lowercased()
        let normalizedContext = (contextName ?? "").lowercased()

        // Prefer author-based classification to avoid false-positive loops from local writes.
        if normalizedAuthor.isEmpty == false {
            let hasCloudKitSignal = normalizedAuthor.contains("cloudkit") || normalizedAuthor.contains("mirroringdelegate")
            let hasImportSignal = normalizedAuthor.contains("import")
            return hasCloudKitSignal && hasImportSignal
        }

        // Fallback only for environments where author may be nil but context keeps CloudKit import naming.
        return normalizedContext.contains("nscloudkitmirroringdelegate.import")
            || normalizedContext.contains("cloudkit.import")
    }
}

final class GamificationRemoteChangeCoordinator {
    private enum Constants {
        static let historyTokenDefaultsKey = "gamification.remote_change.history_token"
        static let cloudSyncNotification = Notification.Name("DataDidChangeFromCloudSync")
    }

    private struct HistoryScanOutcome {
        let scannedTransactions: Int
        let qualifiedTransactions: Int
        let shouldReconcile: Bool
    }

    private let container: NSPersistentCloudKitContainer
    private let notificationCenter: NotificationCenter
    private let onQualifiedCloudImport: (_ reason: String) -> Void
    private let defaults: UserDefaults
    private let workQueue = DispatchQueue(label: "com.tasker.gamification.remote_change", qos: .utility)

    private var isProcessing = false
    private var pendingReplay = false
    private var historyToken: NSPersistentHistoryToken?

    init(
        container: NSPersistentCloudKitContainer,
        notificationCenter: NotificationCenter,
        defaults: UserDefaults = .standard,
        onQualifiedCloudImport: @escaping (_ reason: String) -> Void
    ) {
        self.container = container
        self.notificationCenter = notificationCenter
        self.defaults = defaults
        self.onQualifiedCloudImport = onQualifiedCloudImport
        self.historyToken = Self.loadPersistedToken(defaults: defaults)
    }

    func handleRemoteChange(_ notification: Notification) {
        _ = notification
        workQueue.async { [weak self] in
            guard let self else { return }
            self.pendingReplay = true
            self.processIfNeeded()
        }
    }

    private func processIfNeeded() {
        guard pendingReplay, isProcessing == false else { return }
        pendingReplay = false
        isProcessing = true

        let outcome = scanPersistentHistory()
        isProcessing = false

        if outcome.shouldReconcile {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.notificationCenter.post(name: Constants.cloudSyncNotification, object: nil)
                self.onQualifiedCloudImport("persistent_history_cloud_import")
            }
        }

        if pendingReplay {
            processIfNeeded()
        }
    }

    private func scanPersistentHistory() -> HistoryScanOutcome {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        var transactions: [NSPersistentHistoryTransaction] = []
        var fetchError: Error?

        context.performAndWait {
            do {
                let historyRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: historyToken)
                historyRequest.resultType = .transactionsOnly
                let historyResult = try context.execute(historyRequest) as? NSPersistentHistoryResult
                transactions = historyResult?.result as? [NSPersistentHistoryTransaction] ?? []
            } catch {
                fetchError = error
            }
        }

        if let fetchError {
            logError(
                event: "gamification_remote_history_fetch_failed",
                message: "Failed to fetch persistent history transactions for remote-change processing",
                fields: ["error": fetchError.localizedDescription]
            )
            return HistoryScanOutcome(
                scannedTransactions: 0,
                qualifiedTransactions: 0,
                shouldReconcile: false
            )
        }

        guard transactions.isEmpty == false else {
            return HistoryScanOutcome(
                scannedTransactions: 0,
                qualifiedTransactions: 0,
                shouldReconcile: false
            )
        }

        if let latestToken = transactions.last?.token {
            historyToken = latestToken
            Self.persist(token: latestToken, defaults: defaults)
        }

        let qualifiedCount = transactions.reduce(into: 0) { partialResult, transaction in
            if GamificationRemoteChangeClassifier.isQualifiedCloudImport(
                author: transaction.author,
                contextName: transaction.contextName
            ) {
                partialResult += 1
            }
        }

        logDebug(
            "gamification_remote_history_scan " +
                "scanned=\(transactions.count) qualified=\(qualifiedCount)"
        )

        return HistoryScanOutcome(
            scannedTransactions: transactions.count,
            qualifiedTransactions: qualifiedCount,
            shouldReconcile: qualifiedCount > 0
        )
    }

    private static func loadPersistedToken(defaults: UserDefaults) -> NSPersistentHistoryToken? {
        guard let tokenData = defaults.data(forKey: Constants.historyTokenDefaultsKey) else {
            return nil
        }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSPersistentHistoryToken.self,
                from: tokenData
            )
        } catch {
            logWarning(
                event: "gamification_remote_history_token_decode_failed",
                message: "Failed to decode persistent history token; starting scan from nil token",
                fields: ["error": error.localizedDescription]
            )
            defaults.removeObject(forKey: Constants.historyTokenDefaultsKey)
            return nil
        }
    }

    private static func persist(token: NSPersistentHistoryToken, defaults: UserDefaults) {
        do {
            let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            defaults.set(tokenData, forKey: Constants.historyTokenDefaultsKey)
        } catch {
            logWarning(
                event: "gamification_remote_history_token_encode_failed",
                message: "Failed to encode persistent history token; coordinator will keep in-memory token only",
                fields: ["error": error.localizedDescription]
            )
        }
    }
}
