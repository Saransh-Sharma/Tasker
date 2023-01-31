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
        
        var database = CKContainer(identifier: "iCloud.TaskerCloudKit").privateCloudDatabase
        
        
//        // Create a store description for a local store
//            let localStoreLocation = URL(fileURLWithPath: "/path/to/local.store")
//            let localStoreDescription =
//                NSPersistentStoreDescription(url: localStoreLocation)
//            localStoreDescription.configuration = "Local"

        // Create a store description for a CloudKit-backed local store
//          let cloudStoreLocation = URL(fileURLWithPath: "/path/to/cloud.store")
//          let cloudStoreDescription =
//              NSPersistentStoreDescription(url: cloudStoreLocation)
//          cloudStoreDescription.configuration = "Cloud"

        // Set the container options on the cloud store
//          cloudStoreDescription.cloudKitContainerOptions =
//              NSPersistentCloudKitContainerOptions(
//                containerIdentifier: "iCloud.TaskerCloudKit")
        
        // Update the container's list of store descriptions
//         container.persistentStoreDescriptions = [
//             cloudStoreDescription
////             localStoreDescription
//         ]
        
//        // Load both stores
//         container.loadPersistentStores { storeDescription, error in
//             guard error == nil else {
//                 fatalError("Could not load persistent stores. \(error!)")
//             }
//         }
        
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
        })
        return container
    }()
    
//    func deleteRecordZone(withID zoneID: CKRecordZone.ID) async throws -> CKRecordZone.ID {
//
//    }
    
    func deleteAllUserData(
        withRecordZoneID zoneID: CKRecordZone.ID,
        completionHandler: @escaping (CKRecordZone.ID?, Error?) -> Void
    ) {
        
    }
    
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

}

