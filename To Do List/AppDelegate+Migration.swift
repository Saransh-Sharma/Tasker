//
//  AppDelegate+Migration.swift
//  Tasker
//
//  Extension to setup Clean Architecture migration in AppDelegate
//

import Foundation
import CoreData

extension AppDelegate {
    
    /// Setup Clean Architecture with migration support
    func setupCleanArchitecture() {
        print("🏗️ Setting up Clean Architecture...")
        
        // Step 1: Configure the presentation dependency container
        PresentationDependencyContainer.shared.configure(with: persistentContainer)
        
        // Step 2: Setup migration adapters for backward compatibility
        MigrationHelper.setupMigrationAdapters(
            container: PresentationDependencyContainer.shared,
            context: persistentContainer.viewContext
        )
        
        // Step 3: Run data consolidation using new architecture
        consolidateDataWithCleanArchitecture()
        
        print("✅ Clean Architecture setup complete")
    }
    
    /// Consolidate data using Clean Architecture instead of singletons
    private func consolidateDataWithCleanArchitecture() {
        let coordinator = PresentationDependencyContainer.shared.coordinator
        
        // Ensure Inbox project exists
        coordinator.manageProjects.getAllProjects { result in
            switch result {
            case .success(let projects):
                // Check if Inbox exists
                let hasInbox = projects.contains { $0.project.name.lowercased() == "inbox" }
                
                if !hasInbox {
                    // Create Inbox project
                    let request = CreateProjectRequest(
                        name: "Inbox",
                        description: "Default project for uncategorized tasks"
                    )
                    
                    coordinator.manageProjects.createProject(request: request) { _ in
                        print("✅ Created default Inbox project")
                    }
                }
                
            case .failure(let error):
                print("⚠️ Failed to check projects: \(error)")
            }
        }
        
        // Fix any tasks with missing data
        fixMissingTaskData()
    }
    
    /// Fix tasks with missing required data
    private func fixMissingTaskData() {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        do {
            let tasks = try context.fetch(request)
            var needsSave = false
            
            for task in tasks {
                // Fix missing project
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
                    task.taskType = TaskType.morning.rawValue
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
                print("✅ Fixed missing task data")
            }
            
        } catch {
            print("⚠️ Error fixing task data: \(error)")
        }
    }
}
