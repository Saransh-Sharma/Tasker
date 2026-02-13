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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

//        HomeViewController.setDateForViewValue(dateToSetForView: Date.today())

        // MARK: - UI Testing Mode
        // Handle launch arguments for UI testing
        if ProcessInfo.processInfo.arguments.contains("-UI_TESTING") {

            // Disable animations for faster, more stable tests
            if ProcessInfo.processInfo.arguments.contains("-DISABLE_ANIMATIONS") {
                UIView.setAnimationsEnabled(false)
            }

            // Reset app state for clean test runs
            if ProcessInfo.processInfo.arguments.contains("-RESET_APP_STATE") {
                resetAppState()
            }
        }

        // Configure Firebase and suppress non-critical SDK logs.
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.error)
        
        #if !DEBUG
        Analytics.setAnalyticsCollectionEnabled(true)
        #endif
        
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

        // 1) Force the container to load now (so CloudKit subscriptions are registered)
        _ = persistentContainer

        // 2) Run UUID migration if needed (CRITICAL: Must run before Clean Architecture setup)
        performStartupMigration()

        // Setup Clean Architecture - replaces all singleton initialization
        setupCleanArchitecture()
        
        // 2) Observe remote-change notifications so your viewContext merges them
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentStoreRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator)
            
        // 3) Monitor CloudKit container events for debugging
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: persistentContainer,
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
        
        return true
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
        let context = persistentContainer.viewContext

        // Get all entity names
        guard let entities = persistentContainer.managedObjectModel.entities.map({ $0.name }) as? [String] else {
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

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentCloudKitContainer(name: "TaskModel")
        
        // Get the default persistent store description created by the container.
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("### AppDelegate ### Failed to retrieve a persistent store description.")
        }
        
        // Set the CloudKit container options.
        // This is the crucial step to enable CloudKit synchronization.
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.TaskerCloudKit")
        
        // Enable history tracking and remote change notifications for robust sync.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Handle CloudKit-specific errors gracefully
                if error.domain == NSCocoaErrorDomain && error.code == 134400 {
                    // iCloud account not available - continue without CloudKit
                    // Disable CloudKit for this session
                    storeDescription.cloudKitContainerOptions = nil
                    logWarning(
                        event: "cloudkit_unavailable_local_mode",
                        message: "CloudKit unavailable; using local persistent store",
                        fields: [
                            "domain": error.domain,
                            "code": String(error.code)
                        ]
                    )
                } else {
                    // Handle other errors
                    logError(
                        event: "persistent_store_load_failed",
                        message: "Persistent store failed to load",
                        fields: [
                            "domain": error.domain,
                            "code": String(error.code),
                            "error": error.localizedDescription
                        ]
                    )
                    // Don't crash the app, continue with available functionality
                }
            }
        })
        
        // Configure the view context to automatically merge changes from the parent (persistent store coordinator).
        container.viewContext.automaticallyMergesChangesFromParent = true
        // Set a merge policy for handling conflicts
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Push Notification Handling
    
    @objc
    func handlePersistentStoreRemoteChange(_ notification: Notification) {
        let context = persistentContainer.viewContext
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

    // MARK: - UUID Migration

    /// Perform startup migration to ensure all entities have UUIDs
    /// This is critical for transitioning from legacy string-based to UUID-based project references
    private func performStartupMigration() {

        let migrationManager = MigrationManager()
        let migrationService = DataMigrationService(persistentContainer: persistentContainer, migrationManager: migrationManager)

        // 🔥 EMERGENCY: Add direct legacy data check and force migration if needed
        let inboxInitializer = InboxProjectInitializer(
            viewContext: persistentContainer.viewContext,
            backgroundContext: persistentContainer.newBackgroundContext()
        )

        // Force emergency migration
        let semaphore = DispatchSemaphore(value: 0)

        // Step 1: Force UUID assignment to all projects
        inboxInitializer.forceAssignUUIDsToAllProjects { result in
            switch result {
            case .success(let count):
                // Step 2: Fix task references
                inboxInitializer.forceUpdateTaskProjectReferences { taskResult in
                    switch taskResult {
                    case .success(let taskCount):
                        // Step 3: Reset migration state to trigger proper migration
                        migrationManager.forceResetMigration()

                        // Step 4: Run normal migration to complete the process
                        migrationService.migrateToUUIDs { migrationResult in
                            switch migrationResult {
                            case .success(let report):

                                // Step 5: Verify results
                                self.verifyMigrationResults()

                                // Step 6: Verify new project creation works correctly
                                migrationService.verifyNewProjectCreation { verificationResult in
                                    switch verificationResult {
                                    case .success(let worksCorrectly):
                                        if !worksCorrectly {
                                            logError(
                                                event: "project_uuid_verification_failed",
                                                message: "New project UUID verification failed",
                                                fields: [
                                                    "projects_assigned": String(count),
                                                    "tasks_updated": String(taskCount)
                                                ]
                                            )
                                        }
                                    case .failure(let error):
                                        logError(
                                            event: "project_uuid_verification_error",
                                            message: "New project UUID verification errored",
                                            fields: [
                                                "error": error.localizedDescription
                                            ]
                                        )
                                    }
                                }

                            case .failure(let error):
                                logError(
                                    event: "emergency_migration_failed",
                                    message: "Emergency migration failed",
                                    fields: [
                                        "projects_assigned": String(count),
                                        "tasks_updated": String(taskCount),
                                        "error": error.localizedDescription
                                    ]
                                )
                                // Continue app launch even if migration fails
                            }
                            semaphore.signal()
                        }

                    case .failure(let error):
                        logError(
                            event: "emergency_task_reference_update_failed",
                            message: "Emergency task reference update failed",
                            fields: [
                                "projects_assigned": String(count),
                                "error": error.localizedDescription
                            ]
                        )
                        semaphore.signal()
                    }
                }

            case .failure(let error):
                logError(
                    event: "emergency_project_uuid_assignment_failed",
                    message: "Emergency project UUID assignment failed",
                    fields: [
                        "error": error.localizedDescription
                    ]
                )
                semaphore.signal()
            }
        }

        // Wait for migration to complete (with extended timeout for emergency fix)
        let timeout = DispatchTime.now() + .seconds(60)
        if semaphore.wait(timeout: timeout) == .timedOut {
            logWarning(
                event: "emergency_migration_timeout",
                message: "Emergency migration timed out",
                fields: [
                    "timeout_seconds": "60"
                ]
            )
        }
    }

    /// 🔥 EMERGENCY: Verify migration results to ensure all data has proper UUIDs
    private func verifyMigrationResults() {

        let context = persistentContainer.viewContext

        // Check Projects
        let projectRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
        do {
            let allProjects = try context.fetch(projectRequest)

            var projectsWithUUID = 0
            var projectsWithoutUUID = 0

            for project in allProjects {
                if project.projectID != nil {
                    projectsWithUUID += 1
                    if let projectName = project.projectName {
                    }
                } else {
                    projectsWithoutUUID += 1
                }
            }


            // Check Tasks
            let taskRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
            let allTasks = try context.fetch(taskRequest)

            var tasksWithUUID = 0
            var tasksWithoutUUID = 0
            var tasksWithProjectUUID = 0
            var tasksWithoutProjectUUID = 0

            for task in allTasks {
                if task.taskID != nil {
                    tasksWithUUID += 1
                } else {
                    tasksWithoutUUID += 1
                }

                if task.projectID != nil {
                    tasksWithProjectUUID += 1
                } else {
                    tasksWithoutProjectUUID += 1
                }
            }


            // Overall status
            if projectsWithoutUUID == 0 && tasksWithoutUUID == 0 && tasksWithoutProjectUUID == 0 {
            } else {
                logWarning(
                    event: "migration_incomplete",
                    message: "Migration incomplete: entities still missing UUIDs",
                    fields: [
                        "projects_without_uuid": String(projectsWithoutUUID),
                        "tasks_without_uuid": String(tasksWithoutUUID),
                        "tasks_without_project_uuid": String(tasksWithoutProjectUUID)
                    ]
                )
            }

        } catch {
            logError(
                event: "migration_verification_failed",
                message: "Migration verification failed",
                fields: [
                    "error": error.localizedDescription
                ]
            )
        }
    }

    // MARK: - Clean Architecture Setup

    /// Setup Clean Architecture with modern components only
    func setupCleanArchitecture() {
        
        // Configure legacy DependencyContainer for backward compatibility
        DependencyContainer.shared.configure(with: persistentContainer)

        // Configure presentation container with typed API (no reflection).
        PresentationDependencyContainer.shared.configure(with: persistentContainer)
        
        // Run basic data consolidation
        consolidateDataBasic()
        
    }
    
    /// Basic data consolidation without complex type dependencies
    private func consolidateDataBasic() {

        // Run cleanup first to remove duplicates
        cleanupDuplicateProjects()

        // Ensure Inbox project exists using Core Data directly
        ensureInboxProjectExists()

        // Fix any tasks with missing data
        fixMissingTaskData()

    }

    /// Clean up duplicate projects from the database
    private func cleanupDuplicateProjects() {
        let context = persistentContainer.viewContext

        do {
            var inboxDuplicatesRemoved = 0
            var customDuplicatesRemoved = 0

            // 1. Clean up duplicate Inbox projects
            let inboxFetchRequest = Projects.fetchRequest()
            inboxFetchRequest.predicate = NSPredicate(
                format: "projectName ==[c] %@",
                ProjectConstants.inboxProjectName
            )

            let inboxProjects = try context.fetch(inboxFetchRequest)

            if inboxProjects.count > 1 {
                // Keep only the one with the correct UUID, or the first one if none match
                var projectToKeep: Projects?

                // First, try to find one with the correct UUID
                projectToKeep = inboxProjects.first { $0.projectID == ProjectConstants.inboxProjectID }

                // If no project has the correct UUID, keep the first one and update its UUID
                if projectToKeep == nil {
                    projectToKeep = inboxProjects.first
                    projectToKeep?.projectID = ProjectConstants.inboxProjectID
                    projectToKeep?.projectName = ProjectConstants.inboxProjectName
                    projectToKeep?.projecDescription = ProjectConstants.inboxProjectDescription
                }

                // Delete all other Inbox projects
                for project in inboxProjects {
                    if project.objectID != projectToKeep?.objectID {
                        context.delete(project)
                        inboxDuplicatesRemoved += 1
                    }
                }
            }

            // 2. Clean up duplicate custom projects
            let allProjectsFetchRequest = Projects.fetchRequest()
            let allProjects = try context.fetch(allProjectsFetchRequest)

            // Group projects by name (case-insensitive)
            var projectsByName: [String: [Projects]] = [:]
            for project in allProjects {
                let name = project.projectName?.lowercased() ?? ""
                if !name.isEmpty && name != ProjectConstants.inboxProjectName.lowercased() {
                    if projectsByName[name] == nil {
                        projectsByName[name] = []
                    }
                    projectsByName[name]?.append(project)
                }
            }

            // For each group with duplicates, keep only the first one
            for (_, projects) in projectsByName {
                if projects.count > 1 {
                    // Keep the first project (or the one with UUID if available)
                    let projectToKeep = projects.first { $0.projectID != nil } ?? projects.first

                    // Delete all others
                    for project in projects {
                        if project.objectID != projectToKeep?.objectID {
                            context.delete(project)
                            customDuplicatesRemoved += 1
                        }
                    }
                }
            }

            // Save changes if any duplicates were removed
            if inboxDuplicatesRemoved > 0 || customDuplicatesRemoved > 0 {
                try context.save()
            }
        } catch {
            logWarning(
                event: "duplicate_project_cleanup_failed",
                message: "Failed to clean duplicate projects",
                fields: [
                    "error": error.localizedDescription
                ]
            )
        }
    }
    
    /// Ensure Inbox project exists in Core Data with UUID
    private func ensureInboxProjectExists() {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        request.predicate = NSPredicate(
            format: "projectID == %@",
            ProjectConstants.inboxProjectID as CVarArg
        )

        do {
            let existingProjects = try context.fetch(request)

            if existingProjects.isEmpty {
                // Create Inbox project with fixed UUID
                let inboxProject = Projects(context: context)
                inboxProject.projectID = ProjectConstants.inboxProjectID
                inboxProject.projectName = ProjectConstants.inboxProjectName
                inboxProject.projecDescription = ProjectConstants.inboxProjectDescription

                try context.save()
            } else {
                // Ensure existing Inbox has the correct UUID
                if let inbox = existingProjects.first, inbox.projectID != ProjectConstants.inboxProjectID {
                    inbox.projectID = ProjectConstants.inboxProjectID
                    try context.save()
                }
            }
        } catch {
            logWarning(
                event: "ensure_inbox_project_failed",
                message: "Failed to ensure Inbox project exists",
                fields: [
                    "error": error.localizedDescription
                ]
            )
        }
    }
    
    /// Fix tasks with missing required data including UUIDs
    private func fixMissingTaskData() {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()

        do {
            let tasks = try context.fetch(request)
            var needsSave = false

            for task in tasks {
                // Generate taskID if missing
                if task.taskID == nil {
                    task.taskID = UUID()
                    needsSave = true
                }

                // Assign to Inbox if projectID is missing
                if task.projectID == nil {
                    task.projectID = ProjectConstants.inboxProjectID
                    needsSave = true
                }

                // Fix missing project name (for backward compatibility)
                if task.project == nil || task.project?.isEmpty == true {
                    task.project = "Inbox"
                    needsSave = true
                }

                // Fix missing dates
                if task.dateAdded == nil {
                    task.dateAdded = Date() as NSDate
                    needsSave = true
                }

                // Fix missing due date
                if task.dueDate == nil {
                    task.dueDate = Date() as NSDate
                    needsSave = true
                }

                // Fix missing task type
                if task.taskType == 0 {
                    task.taskType = 1 // Morning task
                    needsSave = true
                }

                // Fix missing priority
                if task.taskPriority == 0 {
                    task.taskPriority = TaskPriority.low.rawValue
                    needsSave = true
                }
            }

            if needsSave {
                try context.save()
            }

        } catch {
            logWarning(
                event: "fix_missing_task_data_failed",
                message: "Failed to fix missing task data",
                fields: [
                    "error": error.localizedDescription
                ]
            )
        }
    }
    


}
