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
import MetricKit
import UserNotifications

enum PersistentBootstrapState {
    case loading
    case ready(NSPersistentCloudKitContainer)
    case failed(String)
}

enum LaunchRootMode: Equatable {
    case loading
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
    static let taskerPersistentBootstrapStateDidChange = Notification.Name("TaskerPersistentBootstrapStateDidChange")
}

private final class TaskerMetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    private let isoFormatter = ISO8601DateFormatter()

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            var fields: [String: String] = [
                "time_start": isoFormatter.string(from: payload.timeStampBegin),
                "time_end": isoFormatter.string(from: payload.timeStampEnd),
                "includes_multiple_versions": payload.includesMultipleApplicationVersions ? "true" : "false",
                "latest_application_version": payload.latestApplicationVersion
            ]

            if let animationMetrics = payload.animationMetrics {
                fields["scroll_hitch_time_ratio"] = Self.format(animationMetrics.scrollHitchTimeRatio)
                if #available(iOS 26.0, *) {
                    fields["hitch_time_ratio"] = Self.format(animationMetrics.hitchTimeRatio)
                }
            }

            logInfo(
                event: "performance_metrickit_payload_received",
                message: "Received MetricKit performance payload",
                component: "performance",
                fields: fields
            )
        }
    }

    private static func format(_ measurement: Measurement<Unit>) -> String {
        String(format: "%.4f", measurement.value)
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private let occurrenceRefreshTaskIdentifier = "com.tasker.refresh.occurrences"
    private let remindersRefreshTaskIdentifier = "com.tasker.refresh.reminders"
    private let persistentStoreLocationService = TaskerPersistentStoreLocationService()
    private let persistentRuntimeInitializer = TaskerPersistentRuntimeInitializer()
    private lazy var persistentStoreBootstrapService = TaskerPersistentStoreBootstrapService(
        storeLocationService: persistentStoreLocationService
    )
    private let expectedStoreConfigurations: Set<String> = ["CloudSync", "LocalOnly"]
    private let localOnlyConfiguration: Set<String> = ["LocalOnly"]
    private let cloudKitContainerIdentifier = TaskerPersistentStoreBootstrapService.defaultCloudKitContainerIdentifier
    private let v3StoreEpoch = 4
    private let orientationPolicyResolver = DeviceOrientationPolicyResolver()
    private var notificationOrchestrator: TaskNotificationOrchestrator?
    private var notificationActionHandler: TaskerNotificationActionHandler?
    private var gamificationRemoteChangeCoordinator: GamificationRemoteChangeCoordinator?
    private var cloudKitEventObserver: NSObjectProtocol?
    private var semanticTaskObservers: [NSObjectProtocol] = []
    private var lastHabitRuntimeMaintenanceAt: Date?
    private var inFlightHabitRuntimeMaintenanceTask: Task<Void, Never>?

    private(set) static var persistentBootstrapFailureMessage: String?
    private(set) static var persistentSyncMode: PersistentSyncMode = .fullSync
    static var isPersistentStoreReady: Bool {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return false
        }
        if case .ready = appDelegate.persistentBootstrapState {
            return true
        }
        return false
    }
    static var isWriteClosed: Bool {
        if case .writeClosed = persistentSyncMode {
            return true
        }
        return false
    }

    private(set) var persistentBootstrapState: PersistentBootstrapState = .loading
    private(set) var persistentContainer: NSPersistentCloudKitContainer?
    private var didScheduleDeferredLaunchServices = false
    private let persistentBootstrapQueue = DispatchQueue(
        label: "tasker.app.persistentBootstrap",
        qos: .userInitiated
    )
    private let deferredLaunchWarmupQueue = DispatchQueue(
        label: "tasker.app.launchWarmup",
        qos: .utility
    )
    private let metricKitSubscriber = TaskerMetricKitSubscriber()


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
        beginPersistentStoreBootstrap(trigger: "launch")
        TaskerPerformanceTrace.end(bootstrapInterval)
        registerPerformanceTelemetryIfNeeded()
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
#if DEBUG
        Task { @MainActor in
            LLMDebugSmokeRunner.scheduleIfEnabled()
        }
#endif
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
        LiquidMetalCTARemoteConfigService.shared.refreshIfAvailable(reason: "app_launch")
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
        deferredLaunchWarmupQueue.async {
            TaskSemanticRetrievalService.shared.persistIndex()
        }
    }

    /// Executes applicationWillEnterForeground.
    func applicationWillEnterForeground(_ application: UIApplication) {
        reconcileNotifications(reason: "app_will_enter_foreground")
    }

    /// Executes applicationDidBecomeActive.
    func applicationDidBecomeActive(_ application: UIApplication) {
        reconcileNotifications(reason: "app_did_become_active")
        guard case .ready = persistentBootstrapState else { return }
        if FirebaseApp.app() != nil {
            GamificationRemoteKillSwitchService.shared.refreshIfAvailable(reason: "app_did_become_active")
            LiquidMetalCTARemoteConfigService.shared.refreshIfAvailable(reason: "app_did_become_active")
        }
        TaskListWidgetSnapshotService.shared.scheduleRefresh(reason: "app_did_become_active")
        maintainHabitRuntimeIfNeeded(reason: "app_did_become_active")
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
        case .loading:
            return .loading
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
        case .loading:
            AppDelegate.persistentBootstrapFailureMessage = nil
            persistentContainer = nil
            postPersistentBootstrapStateDidChange()
            return .loading

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
            postPersistentBootstrapStateDidChange()
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
            postPersistentBootstrapStateDidChange()
            return .bootstrapFailure(message: message)
        }
    }

    private func beginPersistentStoreBootstrap(trigger: String) {
        _ = applyBootstrapState(.loading, trigger: trigger)
        let interval = TaskerPerformanceTrace.begin("PersistentBootstrapAsync")
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let state = await self.bootstrapV3PersistentContainer()
            await MainActor.run {
                TaskerPerformanceTrace.end(interval)
                _ = self.applyBootstrapState(state, trigger: trigger)
            }
        }
    }

    private func postPersistentBootstrapStateDidChange() {
        NotificationCenter.default.post(
            name: .taskerPersistentBootstrapStateDidChange,
            object: self
        )
    }

    private func registerPerformanceTelemetryIfNeeded() {
        guard #available(iOS 13.0, *) else { return }
        MXMetricManager.shared.add(self.metricKitSubscriber)
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
            case .loading:
                logWarning(
                    event: "persistent_store_recovery_rebootstrap_started",
                    message: "Cloud-authoritative recovery started async persistent store rebootstrap",
                    fields: [
                        "quarantine_dir": quarantineURL?.path ?? "none"
                    ]
                )
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
        beginPersistentStoreBootstrap(trigger: trigger)
        return .loading
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
        persistentStoreBootstrapService.makeV3PersistentContainer()
    }

    /// Executes makeV3LocalOnlyWriteClosedContainer.
    /// Creates a local-only runtime topology used for write-closed operation.
    private func makeV3LocalOnlyWriteClosedContainer() -> NSPersistentCloudKitContainer {
        persistentStoreBootstrapService.makeV3LocalOnlyWriteClosedContainer()
    }

    /// Executes cloudKitMirroringMode.
    ///
    /// Keep CloudKit mirroring off in simulator/XCTest runs to avoid startup crashes in
    /// unsigned test hosts where runtime entitlements are unavailable.
    func cloudKitMirroringMode(
        context: CloudKitRuntimeContext = .current()
    ) -> CloudKitMirroringMode {
        persistentStoreBootstrapService.cloudKitMirroringMode(context: context)
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
    private func bootstrapV3PersistentContainer() async -> PersistentBootstrapState {
        let result = await persistentStoreBootstrapService.bootstrapV3PersistentContainer()
        updatePersistentSyncMode(result.syncMode, source: result.syncModeSource)
        if result.shouldMarkStoreEpoch {
            markV3BootstrapEpochApplied()
        }
        return result.state
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
        persistentStoreLocationService.wipeKnownCutoverStoreFiles()
    }

    private func allKnownCutoverStoreFileNames() -> [String] {
        persistentStoreLocationService.allKnownCutoverStoreFileNames()
    }

    private func v3SplitStoreFileNames() -> [String] {
        persistentStoreLocationService.v3SplitStoreFileNames()
    }

    private func quarantineV3StoreFiles(reason: String) throws -> URL? {
        try persistentStoreLocationService.quarantineActiveV3StoreFiles(reason: reason)
    }

    private func clearActiveV3SplitStoreFiles() {
        persistentStoreLocationService.clearActiveV3StoreFiles()
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
        guard let container = persistentContainer else {
            return
        }
        persistentRuntimeInitializer.initialize(container: container)
    }

    private var shouldRunStartupMutationWorkflows: Bool {
        AppDelegate.isWriteClosed == false
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

        if shouldRunStartupMutationWorkflows {
            ensureV3Defaults()
            repairProjectIdentityIfNeeded()
            maintainHabitRuntimeIfNeeded(reason: "clean_architecture_setup")
        } else {
            logWarning(
                event: "write_closed_startup_mutations_skipped",
                message: "Skipping startup mutation workflows while app is in write-closed sync mode",
                fields: [
                    "reason": AppDelegate.persistentSyncMode.reason
                ]
            )
        }

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
            tagRepository: stateContainer.tagRepository,
            habitRuntimeReadRepository: stateContainer.habitRuntimeReadRepository
        )
        configureSemanticRetrievalLifecycle(stateContainer: stateContainer)
        return true
    }

    private func configureSemanticRetrievalLifecycle(stateContainer: EnhancedDependencyContainer) {
        TaskSemanticRetrievalService.shared.loadPersistedIndex()
        Task { [weak self] in
            await self?.rebuildSemanticIndexIfPossible(stateContainer: stateContainer)
        }

        semanticTaskObservers.forEach(NotificationCenter.default.removeObserver)
        semanticTaskObservers.removeAll()

        let center = NotificationCenter.default
        let upsertNames: [Notification.Name] = [
            NSNotification.Name("TaskCreated"),
            NSNotification.Name("TaskUpdated"),
            NSNotification.Name("TaskCompletionChanged")
        ]
        for name in upsertNames {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { notification in
                guard let task = notification.object as? TaskDefinition else { return }
                Task { [weak self] in
                    let tagLookup = await self?.semanticTagNameLookup(stateContainer: stateContainer) ?? [:]
                    TaskSemanticRetrievalService.shared.index(tasks: [task], tagNameLookup: tagLookup)
                }
            }
            semanticTaskObservers.append(observer)
        }

        let deleteObserver = center.addObserver(forName: NSNotification.Name("TaskDeleted"), object: nil, queue: .main) { [weak self] notification in
            let deletedTaskIDs = self?.deletedSemanticTaskIDs(from: notification) ?? []
            guard deletedTaskIDs.isEmpty == false else { return }
            deletedTaskIDs.forEach { TaskSemanticRetrievalService.shared.remove(taskID: $0) }
        }
        semanticTaskObservers.append(deleteObserver)
    }

    private func maintainHabitRuntimeIfNeeded(reason: String) {
        guard shouldRunStartupMutationWorkflows else {
            return
        }

        guard PresentationDependencyContainer.shared.isConfiguredForRuntime else {
            return
        }

        if let inFlightHabitRuntimeMaintenanceTask {
            if inFlightHabitRuntimeMaintenanceTask.isCancelled == false {
                return
            }
            self.inFlightHabitRuntimeMaintenanceTask = nil
        }

        let now = Date()
        let shouldForceRepair = TaskerPersistentRuntimeInitializer.shouldRunRepair()
        if shouldForceRepair == false,
           let lastHabitRuntimeMaintenanceAt,
           now.timeIntervalSince(lastHabitRuntimeMaintenanceAt) < 45 {
            return
        }

        let coordinator = PresentationDependencyContainer.shared.coordinator
        inFlightHabitRuntimeMaintenanceTask = Task { [weak self] in
            await withCheckedContinuation { continuation in
                coordinator.maintainHabitRuntime.execute(anchorDate: now) { result in
                    switch result {
                    case .failure(let error):
                        logWarning(
                            event: "habit_runtime_maintenance_failed",
                            message: "Habit runtime maintenance failed",
                            fields: [
                                "reason": reason,
                                "error": error.localizedDescription
                            ]
                        )
                        continuation.resume()
                    case .success:
                        guard shouldForceRepair else {
                            continuation.resume()
                            return
                        }
                        coordinator.recomputeHabitStreaks.execute(referenceDate: now) { recomputeResult in
                            switch recomputeResult {
                            case .failure(let error):
                                logWarning(
                                    event: "habit_runtime_repair_failed",
                                    message: "Habit streak repair failed after maintenance",
                                    fields: [
                                        "reason": reason,
                                        "error": error.localizedDescription
                                    ]
                                )
                            case .success:
                                TaskerPersistentRuntimeInitializer.markRepairCompleted()
                            }
                            continuation.resume()
                        }
                    }
                }
            }
            await MainActor.run {
                self?.lastHabitRuntimeMaintenanceAt = now
                self?.inFlightHabitRuntimeMaintenanceTask = nil
            }
        }
    }

    private func rebuildSemanticIndexIfPossible(stateContainer: EnhancedDependencyContainer) async {
        guard let repository = stateContainer.taskDefinitionRepository else { return }
        let tasks = await withCheckedContinuation { continuation in
            repository.fetchAll { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }

        let tagLookup = await semanticTagNameLookup(stateContainer: stateContainer)

        TaskSemanticRetrievalService.shared.rebuildIndex(tasks: tasks, tagNameLookup: tagLookup)
    }

    private func semanticTagNameLookup(stateContainer: EnhancedDependencyContainer) async -> [UUID: String] {
        guard let tagRepository = stateContainer.tagRepository else { return [:] }
        return await withCheckedContinuation { continuation in
            tagRepository.fetchAll { result in
                let tags = (try? result.get()) ?? []
                continuation.resume(returning: Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) }))
            }
        }
    }

    private func deletedSemanticTaskIDs(from notification: Notification) -> [UUID] {
        if let rawIDs = notification.userInfo?["deletedTaskIDs"] as? [String] {
            let uuids = rawIDs.compactMap(UUID.init(uuidString:))
            if uuids.isEmpty == false {
                return uuids
            }
        }
        if let task = notification.object as? TaskDefinition {
            return [task.id]
        }
        return []
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
