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
        
        
        FirebaseApp.configure()
        
        // Register for CloudKit silent pushes
        application.registerForRemoteNotifications()
        
        // 1) Force the container to load now (so CloudKit subscriptions are registered)
        _ = persistentContainer
        
        // **CRITICAL: Call consolidation logic after Core Data stack is ready**
        ProjectManager.sharedInstance.fixMissingProjecsDataWithDefaults()
        TaskManager.sharedInstance.fixMissingTasksDataWithDefaults()
        
        // Configure the dependency container
        DependencyContainer.shared.configure(with: persistentContainer)
        
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

            for event in events {
                // Log the event type
                print("📡 CloudKit event:", event.type)

                // Log any errors
                if let err = event.error {
                    print("   ⛔️ error:", err)
                }

            }
        }
        
        return true
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
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            print("Successfully loaded persistent store: \(storeDescription.url?.lastPathComponent ?? "N/A") with CloudKit options: \(storeDescription.cloudKitContainerOptions?.containerIdentifier ?? "None")")
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
            print("AppDelegate: Handling persistent store remote change notification.")
            context.mergeChanges(fromContextDidSave: notification) // Correct method signature
            print("AppDelegate: Successfully merged changes from remote store.")

            // **CRITICAL: Call consolidation logic after merging CloudKit changes**
            ProjectManager.sharedInstance.fixMissingProjecsDataWithDefaults()
            TaskManager.sharedInstance.fixMissingTasksDataWithDefaults() // Re-check tasks
            
            // Notify repository system about potential data changes
            NotificationCenter.default.post(name: Notification.Name("DataDidChangeFromCloudSync"), object: nil)

            // Consider posting a custom notification if UI needs to react strongly to these background changes
            // NotificationCenter.default.post(name: Notification.Name("DataDidChangeFromCloudSync"), object: nil)
        }
    }
    
    // Remote notification registration success/failure callbacks
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        print("✅ APNs token registered successfully")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs registration failed: \(error)")
    }
    


}

