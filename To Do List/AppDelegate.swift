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

struct PersistentStoreLoadReport {
    let loadedConfigurations: Set<String>
    let errors: [NSError]
}

extension Notification.Name {
    static let assistantOpenChatRequested = Notification.Name("assistantOpenChatRequested")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private let occurrenceRefreshTaskIdentifier = "com.tasker.refresh.occurrences"
    private let remindersRefreshTaskIdentifier = "com.tasker.refresh.reminders"
    private let dailyBriefRefreshTaskIdentifier = "com.tasker.refresh.daily_brief"
    private let expectedStoreConfigurations: Set<String> = ["CloudSync", "LocalOnly"]
    private let v3StoreEpoch = 4
    private var semanticIndexObserver: NSObjectProtocol?
    private let pendingChatPromptKey = "assistant.pending_prompt"
    private let pendingChatAssistantMessageKey = "assistant.pending_assistant_message"
    private let pendingChatModeKey = "assistant.pending_chat_mode"

    private(set) static var persistentBootstrapFailureMessage: String?
    static var isPersistentStoreReady: Bool {
        persistentBootstrapFailureMessage == nil
    }

    private(set) var persistentBootstrapState: PersistentBootstrapState = .failed("Persistent store bootstrap has not run")
    private(set) var persistentContainer: NSPersistentCloudKitContainer?

    private enum FirebaseBundleConfigState {
        case missing
        case stub
        case ready
    }

    /// Executes application.
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

            if launchArguments.contains("-DISABLE_AI_FOR_UI_TESTS") {
                applyUITestAssistantOverrides()
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
            switch firebaseBundleConfigStatus() {
            case .ready:
                if FirebaseApp.app() == nil {
                    FirebaseApp.configure()
                }
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
            case .stub:
                logWarning(
                    event: "firebase_startup_mode",
                    message: "Firebase skipped because stub config is active",
                    fields: [
                        "enabled": "false",
                        "source": "stub_config_detected"
                    ]
                )
            case .missing:
                logWarning(
                    event: "firebase_startup_mode",
                    message: "Firebase skipped because GoogleService-Info.plist is unavailable",
                    fields: [
                        "enabled": "false",
                        "source": "missing_config_plist"
                    ]
                )
            }
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
        UNUserNotificationCenter.current().delegate = self

        // Hard-reset cutover to V3 model/container.
        performV3BootstrapCutoverIfNeeded()

        persistentBootstrapState = bootstrapV3PersistentContainer()
        switch persistentBootstrapState {
        case .ready(let container):
            persistentContainer = container
            AppDelegate.persistentBootstrapFailureMessage = nil

            let didConfigureRuntime = setupCleanArchitecture()
            guard didConfigureRuntime else {
                break
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                Task { @MainActor in
                    LLMPrewarmCoordinator.shared.prewarmCurrentModelIfNeeded(reason: "app_launch")
                }
            }

            registerBackgroundTasks()
            scheduleOccurrenceRefresh()
            if V2FeatureFlags.remindersBackgroundRefreshEnabled {
                scheduleRemindersRefresh()
            }
            if V2FeatureFlags.assistantBriefEnabled {
                scheduleDailyBriefRefresh()
            }
            configureSemanticRetrievalIndexingIfNeeded()

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
            logError(
                event: "persistent_store_bootstrap_failed",
                message: "Persistent store bootstrap failed; running without initialized persistence",
                fields: [
                    "reason": message,
                    "retry_attempted": "true"
                ]
            )
            persistentContainer = nil
        }
        
        return true
    }

    /// Detects whether the bundled Firebase config is usable or a non-secret stub.
    private func firebaseBundleConfigStatus() -> FirebaseBundleConfigState {
        guard
            let configPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let dictionary = NSDictionary(contentsOfFile: configPath) as? [String: Any]
        else {
            return .missing
        }

        let appID = (dictionary["GOOGLE_APP_ID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let projectID = (dictionary["PROJECT_ID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let apiKey = (dictionary["API_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalized = [appID, projectID, apiKey].joined(separator: "|").lowercased()

        guard appID.isEmpty == false, projectID.isEmpty == false, apiKey.isEmpty == false else {
            return .stub
        }

        if normalized.contains("stub") || normalized.contains("placeholder") {
            return .stub
        }

        return .ready
    }

    /// Executes applicationDidEnterBackground.
    func applicationDidEnterBackground(_ application: UIApplication) {
        guard case .ready = persistentBootstrapState else {
            return
        }
        scheduleOccurrenceRefresh()
        if V2FeatureFlags.remindersBackgroundRefreshEnabled {
            scheduleRemindersRefresh()
        }
        if V2FeatureFlags.assistantBriefEnabled {
            scheduleDailyBriefRefresh()
        }
        if V2FeatureFlags.assistantSemanticRetrievalEnabled {
            TaskSemanticRetrievalService.shared.persistIndex()
        }
    }

    /// Executes applicationDidBecomeActive.
    func applicationDidBecomeActive(_ application: UIApplication) {
        guard V2FeatureFlags.assistantBriefEnabled else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        guard (6...10).contains(hour) else { return }
        guard DailyBriefService.shared.cachedBrief(for: Date()) == nil else { return }
        generateAndCacheDailyBrief(sendNotification: false, completion: { _ in })
    }

    /// Executes userNotificationCenter.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier.hasPrefix("assistant.daily_brief.") {
            let cachedBrief = DailyBriefService.shared.cachedBrief(for: Date())
                ?? (response.notification.request.content.userInfo["brief"] as? String)
            if let cachedBrief {
                seedAssistantChat(
                    mode: .ask,
                    prompt: "Use this brief to plan my day.",
                    assistantMessage: cachedBrief
                )
            }
            logWarning(
                event: "assistant_daily_brief_opened",
                message: "User opened assistant daily brief notification",
                fields: [:]
            )
        }
        completionHandler()
    }

    /// Executes seedAssistantChat.
    private func seedAssistantChat(
        mode: AssistantChatMode,
        prompt: String?,
        assistantMessage: String?
    ) {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: pendingChatModeKey)
        if let prompt,
           prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            defaults.set(prompt, forKey: pendingChatPromptKey)
        }
        if let assistantMessage,
           assistantMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            defaults.set(assistantMessage, forKey: pendingChatAssistantMessageKey)
        }
        NotificationCenter.default.post(name: .assistantOpenChatRequested, object: nil)
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

    // MARK: - UI Testing Helpers

    /// Executes applyUITestAssistantOverrides.
    private func applyUITestAssistantOverrides() {
        V2FeatureFlags.assistantCopilotEnabled = false
        V2FeatureFlags.assistantPlanModeEnabled = false
        V2FeatureFlags.assistantSemanticRetrievalEnabled = false
        V2FeatureFlags.assistantBriefEnabled = false
        V2FeatureFlags.assistantBreakdownEnabled = false
        logWarning(
            event: "ui_testing_ai_overrides_enabled",
            message: "Disabled AI assistant features for this UI test run",
            fields: ["launch_argument": "-DISABLE_AI_FOR_UI_TESTS"]
        )
    }

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

        let baseURL = NSPersistentContainer.defaultDirectoryURL()
        let cloudURL = baseURL.appendingPathComponent("TaskModelV3-cloud.sqlite")
        let localURL = baseURL.appendingPathComponent("TaskModelV3-local.sqlite")

        let cloudDescription = NSPersistentStoreDescription(url: cloudURL)
        cloudDescription.configuration = "CloudSync"
        cloudDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.TaskerCloudKitV3"
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

    /// Executes bootstrapV3PersistentContainer.
    private func bootstrapV3PersistentContainer() -> PersistentBootstrapState {
        let initialContainer = makeV3PersistentContainer()
        let initialReport = loadPersistentStoresAndReport(container: initialContainer, phase: "initial")
        let initialHealthy = initialReport.errors.isEmpty && hasExpectedConfigurations(initialReport)

        if initialHealthy {
            markV3BootstrapEpochApplied()
            return .ready(initialContainer)
        }

        let missingConfigurations = expectedStoreConfigurations.subtracting(initialReport.loadedConfigurations)
        let hasMissingConfigurations = missingConfigurations.isEmpty == false
        let hasCompatibilityError = initialReport.errors.contains(where: isIncompatibleStoreError)
        let shouldRetryWithWipe = hasCompatibilityError || hasMissingConfigurations

        if shouldRetryWithWipe {
            logWarning(
                event: "persistent_store_bootstrap_retry",
                message: "Retrying persistent store bootstrap after V3 store wipe",
                fields: [
                    "retry_attempted": "true",
                    "retry_reason": hasCompatibilityError ? "compatibility_error" : "missing_configuration",
                    "loaded_configurations": initialReport.loadedConfigurations.sorted().joined(separator: ","),
                    "missing_configurations": missingConfigurations.sorted().joined(separator: ","),
                    "error_count": String(initialReport.errors.count)
                ]
            )

            unloadPersistentStores(initialContainer)
            wipeV3StoreFiles()
            let recoveryContainer = makeV3PersistentContainer()
            let recoveryReport = loadPersistentStoresAndReport(container: recoveryContainer, phase: "recovery")
            let recoveryHealthy = recoveryReport.errors.isEmpty && hasExpectedConfigurations(recoveryReport)
            if recoveryHealthy {
                markV3BootstrapEpochApplied()
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

    /// Executes loadPersistentStoresAndReport.
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
                    message: "V3 persistent store failed to load",
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

    /// Executes hasExpectedConfigurations.
    private func hasExpectedConfigurations(_ report: PersistentStoreLoadReport) -> Bool {
        expectedStoreConfigurations.isSubset(of: report.loadedConfigurations)
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
                    message: "Failed to unload persistent store before wipe",
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
        let storeFileNames = [
            "TaskModelV2-cloud.sqlite",
            "TaskModelV2-cloud.sqlite-wal",
            "TaskModelV2-cloud.sqlite-shm",
            "TaskModelV2-local.sqlite",
            "TaskModelV2-local.sqlite-wal",
            "TaskModelV2-local.sqlite-shm",
            "TaskModelV3-cloud.sqlite",
            "TaskModelV3-cloud.sqlite-wal",
            "TaskModelV3-cloud.sqlite-shm",
            "TaskModelV3-local.sqlite",
            "TaskModelV3-local.sqlite-wal",
            "TaskModelV3-local.sqlite-shm"
        ]

        for fileName in storeFileNames {
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

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dailyBriefRefreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleDailyBriefRefresh(task: refreshTask)
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

    /// Executes scheduleDailyBriefRefresh.
    private func scheduleDailyBriefRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: dailyBriefRefreshTaskIdentifier)
        var nextRun = Calendar.current.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Calendar.current.date(byAdding: .hour, value: 12, to: Date()) ?? Date()
        if nextRun <= Date() {
            nextRun = Calendar.current.date(byAdding: .day, value: 1, to: nextRun) ?? nextRun
        }
        request.earliestBeginDate = nextRun
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logWarning(
                event: "bg_daily_brief_schedule_failed",
                message: "Failed to schedule daily brief background refresh task",
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

    /// Executes handleDailyBriefRefresh.
    private func handleDailyBriefRefresh(task: BGAppRefreshTask) {
        scheduleDailyBriefRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        guard V2FeatureFlags.assistantBriefEnabled else {
            task.setTaskCompleted(success: true)
            return
        }

        if DailyBriefService.shared.cachedBrief(for: Date()) != nil {
            task.setTaskCompleted(success: true)
            return
        }
        generateAndCacheDailyBrief(sendNotification: true) { success in
            task.setTaskCompleted(success: success)
        }
    }

    /// Executes postDailyBriefNotification.
    private func postDailyBriefNotification(_ brief: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Tasker Daily Brief"
            content.body = brief
            content.sound = .default
            content.userInfo = ["brief": brief]

            let request = UNNotificationRequest(
                identifier: "assistant.daily_brief.\(Date().ISO8601Format())",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    /// Executes generateAndCacheDailyBrief.
    private func generateAndCacheDailyBrief(
        sendNotification: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        let coordinator = PresentationDependencyContainer.shared.coordinator
        coordinator.getDailyDashboard { result in
            switch result {
            case .failure(let error):
                logWarning(
                    event: "assistant_daily_brief_generation_failed",
                    message: "Failed generating daily brief from dashboard",
                    fields: ["error": error.localizedDescription]
                )
                completion(false)
            case .success(let dashboard):
                let todayOpen = dashboard.todayTasks.morningTasks.filter { !$0.isComplete }.count
                    + dashboard.todayTasks.eveningTasks.filter { !$0.isComplete }.count
                let overdueCount = dashboard.todayTasks.overdueTasks.filter { !$0.isComplete }.count
                let completedToday = dashboard.analytics.completedTasks
                let streak = dashboard.streak.currentStreak
                Task { @MainActor in
                    let output = await DailyBriefService.shared.generateBriefOutput(
                        todayOpenCount: todayOpen,
                        overdueCount: overdueCount,
                        completedTodayCount: completedToday,
                        streak: streak
                    )
                    DailyBriefService.shared.saveBrief(output.brief, for: Date())
                    if sendNotification {
                        self.postDailyBriefNotification(output.brief)
                    }
                    logWarning(
                        event: "assistant_daily_brief_generated",
                        message: "Generated daily brief",
                        fields: [
                            "model": output.modelName ?? "none",
                            "has_route_banner": output.routeBanner == nil ? "false" : "true"
                        ]
                    )
                    completion(true)
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

        // Configure LLM access through repositories (no direct Core Data context pulls).
        LLMContextRepositoryProvider.configure(
            taskReadModelRepository: stateContainer.taskReadModelRepository,
            projectRepository: stateContainer.projectRepository,
            tagRepository: stateContainer.tagRepository
        )
        LLMAssistantPipelineProvider.configure(
            pipeline: stateContainer.useCaseCoordinator.assistantActionPipeline
        )
        return true
    }

    /// Executes failClosedV3Runtime.
    private func failClosedV3Runtime(reason: String) -> Bool {
        let failureMessage = "Tasker failed to initialize required V3 runtime dependencies."
        persistentBootstrapState = .failed(failureMessage)
        AppDelegate.persistentBootstrapFailureMessage = failureMessage
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

    /// Executes configureSemanticRetrievalIndexingIfNeeded.
    private func configureSemanticRetrievalIndexingIfNeeded() {
        guard V2FeatureFlags.assistantSemanticRetrievalEnabled else { return }
        TaskSemanticRetrievalService.shared.loadPersistedIndex()
        rebuildSemanticIndexSnapshot()

        if semanticIndexObserver == nil {
            semanticIndexObserver = NotificationCenter.default.addObserver(
                forName: .homeTaskMutation,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleSemanticMutation(notification)
            }
        }
    }

    /// Executes handleSemanticMutation.
    private func handleSemanticMutation(_ notification: Notification) {
        guard V2FeatureFlags.assistantSemanticRetrievalEnabled else { return }
        guard let userInfo = notification.userInfo else {
            rebuildSemanticIndexSnapshot()
            return
        }

        let reason = (userInfo["reason"] as? String ?? "").lowercased()
        guard let taskIDRaw = userInfo["taskID"] as? String, let taskID = UUID(uuidString: taskIDRaw) else {
            rebuildSemanticIndexSnapshot()
            return
        }

        if reason == "deleted" {
            TaskSemanticRetrievalService.shared.remove(taskID: taskID)
            return
        }

        guard let taskRepository = EnhancedDependencyContainer.shared.taskDefinitionRepository else {
            rebuildSemanticIndexSnapshot()
            return
        }
        let tagLookup = buildTagLookupSync(from: EnhancedDependencyContainer.shared.tagRepository)

        DispatchQueue.global(qos: .utility).async {
            let task = self.fetchTaskDefinitionSync(id: taskID, from: taskRepository)
            if let task {
                TaskSemanticRetrievalService.shared.index(tasks: [task], tagNameLookup: tagLookup)
            } else {
                TaskSemanticRetrievalService.shared.remove(taskID: taskID)
            }
        }
    }

    /// Executes rebuildSemanticIndexSnapshot.
    private func rebuildSemanticIndexSnapshot() {
        guard V2FeatureFlags.assistantSemanticRetrievalEnabled else { return }
        guard let taskRepository = EnhancedDependencyContainer.shared.taskReadModelRepository else { return }
        let tagRepository = EnhancedDependencyContainer.shared.tagRepository

        DispatchQueue.global(qos: .utility).async {
            let tasks = self.loadAllTasksSync(from: taskRepository)
            let tagLookup = self.buildTagLookupSync(from: tagRepository)
            TaskSemanticRetrievalService.shared.rebuildIndex(tasks: tasks, tagNameLookup: tagLookup)
        }
    }

    /// Executes loadAllTasksSync.
    private func loadAllTasksSync(from repository: TaskReadModelRepositoryProtocol) -> [TaskDefinition] {
        let semaphore = DispatchSemaphore(value: 0)
        var fetched: [TaskDefinition] = []
        repository.fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .updatedAtDescending,
                limit: 5_000,
                offset: 0
            )
        ) { result in
            defer { semaphore.signal() }
            if case .success(let slice) = result {
                fetched = slice.tasks
            }
        }
        _ = semaphore.wait(timeout: .now() + .seconds(5))
        return fetched
    }

    /// Executes fetchTaskDefinitionSync.
    private func fetchTaskDefinitionSync(
        id: UUID,
        from repository: TaskDefinitionRepositoryProtocol
    ) -> TaskDefinition? {
        let semaphore = DispatchSemaphore(value: 0)
        var fetched: TaskDefinition?
        repository.fetchTaskDefinition(id: id) { result in
            defer { semaphore.signal() }
            if case .success(let task) = result {
                fetched = task
            }
        }
        _ = semaphore.wait(timeout: .now() + .seconds(5))
        return fetched
    }

    /// Executes buildTagLookupSync.
    private func buildTagLookupSync(from repository: TagRepositoryProtocol?) -> [UUID: String] {
        guard let repository else { return [:] }
        let semaphore = DispatchSemaphore(value: 0)
        var lookup: [UUID: String] = [:]
        repository.fetchAll { result in
            defer { semaphore.signal() }
            if case .success(let tags) = result {
                lookup = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
            }
        }
        _ = semaphore.wait(timeout: .now() + .seconds(5))
        return lookup
    }
}
