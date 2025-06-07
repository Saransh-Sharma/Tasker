//
//  ProjectManager.swift
//  To Do List
//
//  Created by Saransh Sharma on 29/06/20.
//  Copyright 2020 saransh1337. All rights reserved.
//

import Combine
import Foundation
import UIKit
import CoreData

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

class ProjectManager: ObservableObject {
    static let sharedInstance = ProjectManager()

    @Published var projects: [Projects] = [] // This is the single source of truth for UI updates

    let context: NSManagedObjectContext!
    var defaultProject = "Inbox"
    var defaultProjectDescription = "Catch all project for all tasks no attached to a project"

    // Computed property for display. It operates on the already fetched `projects`.
    // It does NOT trigger a new fetch.
    var displayedProjects: [Projects] {
        var localProjects = projects.uniqued() // Work with a uniqued copy

        // Move "Inbox" to the top for display
        if let inboxIndex = localProjects.firstIndex(where: { $0.projectName?.lowercased() == defaultProject.lowercased() }) {
            let inboxProject = localProjects.remove(at: inboxIndex)
            localProjects.insert(inboxProject, at: 0)
        }
        return localProjects
    }
    
    var count: Int {
        return projects.count
    }
    
    func projectAtIndex(index: Int) -> Projects {
        // Add bounds check for safety
        guard index >= 0 && index < projects.count else {
            fatalError("ProjectManager: Index out of bounds in projectAtIndex.")
        }
        return projects[index]
    }
    
    
    // Central method to refresh data from Core Data and ensure defaults.
    // This should be called when the UI needs to load/reload project data.
    func refreshAndPrepareProjects() {
        print("ProjectManager: refreshAndPrepareProjects called.")
        fetchProjects() // Step 1: Get the latest from Core Data
        fixMissingProjecsDataWithDefaultsInternal() // Step 2: Ensure "Inbox" and other defaults are fine
    }

    // Fetches projects from Core Data and updates the @Published `projects` array.
    private func fetchProjects() {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Projects")
        do {
            let results = try context.fetch(fetchRequest)
            // Ensure updates to @Published property are on the main thread if called from background
            DispatchQueue.main.async {
                self.projects = results as? [Projects] ?? []
                print("ProjectManager: Fetched \(self.projects.count) projects.")
            }
        } catch let error as NSError {
            print("ProjectManager: Could not fetch projects! \(error), \(error.userInfo)")
            DispatchQueue.main.async {
                self.projects = [] // Clear projects on error
            }
        }
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("ProjectManager: Context saved successfully.")
            } catch let error as NSError {
                print("ProjectManager failed saving context! \(error), \(error.userInfo)")
            }
        }
    }
    
    func removeProjectAtIndex(index: Int) {
        context.delete(projectAtIndex(index: index))
        projects.remove(at: index)
        saveContext()
        fetchProjects() // Refresh after modification
    }
    
    // Internal version of fixMissingProjecsDataWithDefaults.
    // Assumes `self.projects` might be stale and works on a copy, then triggers a final fetch if DB changes.
    private func fixMissingProjecsDataWithDefaultsInternal() {
        print("ProjectManager: Starting fixMissingProjecsDataWithDefaultsInternal.")
        
        // Perform operations on a temporary copy or directly if confident about threading.
        // The key is that any changes to Core Data must be followed by `saveContext()`
        // and then `fetchProjects()` to update the @Published `self.projects`.

        let localProjectsCopy = self.projects // Work on a copy of the current state
        var allFoundInboxProjects: [Projects] = []
        var otherNonInboxProjects: [Projects] = []

        for project in localProjectsCopy {
            if project.projectName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == defaultProject.lowercased() {
                allFoundInboxProjects.append(project)
            } else {
                otherNonInboxProjects.append(project)
            }
        }

        var requiresCoreDataSave = false

        if allFoundInboxProjects.isEmpty {
            print("ProjectManager: No Inbox project found. Creating default '\(defaultProject)' project.")
            let newInbox = NSEntityDescription.insertNewObject(forEntityName: "Projects", into: context) as! Projects
            newInbox.projectName = defaultProject
            newInbox.projecDescription = defaultProjectDescription
            requiresCoreDataSave = true
        } else {
            let primaryInbox = allFoundInboxProjects.removeFirst() 
            
            if primaryInbox.projectName != defaultProject {
                primaryInbox.projectName = defaultProject
                requiresCoreDataSave = true
            }
            if primaryInbox.projecDescription != defaultProjectDescription {
                primaryInbox.projecDescription = defaultProjectDescription
                requiresCoreDataSave = true
            }

            if !allFoundInboxProjects.isEmpty {
                print("ProjectManager: Found \(allFoundInboxProjects.count) duplicate Inbox project(s). Merging into '\(defaultProject)'.")
                for duplicateInbox in allFoundInboxProjects {
                    if let duplicateName = duplicateInbox.projectName, !duplicateName.isEmpty {
                        let tasksToReassign = TaskManager.sharedInstance.getTasksForProjectByName(projectName: duplicateName)
                        if !tasksToReassign.isEmpty {
                            for task in tasksToReassign { task.project = primaryInbox.projectName }
                            // TaskManager.sharedInstance.saveContext() // TaskManager should handle its own saves
                        }
                    }
                    context.delete(duplicateInbox)
                    requiresCoreDataSave = true
                }
                if !allFoundInboxProjects.isEmpty {
                     TaskManager.sharedInstance.saveContext() // Save task changes if any reassignments happened
                }
            }
        }

        if requiresCoreDataSave {
            saveContext() // Save changes to Projects entities
            fetchProjects() // Crucial: Re-fetch to update @Published self.projects and notify UI
        } else {
            // If no DB changes, but `self.projects` might have been inconsistent before this check,
            // a `fetchProjects()` might still be beneficial, or ensure `self.projects` is already up-to-date.
            // For simplicity, if `requiresCoreDataSave` is false, we assume `self.projects` was accurate
            // regarding the Inbox state or no changes were needed.
            print("ProjectManager: Inbox project is already consistent or no DB changes made by fixMissingProjecsDataWithDefaultsInternal.")
        }
        print("ProjectManager: fixMissingProjecsDataWithDefaultsInternal finished. Total projects now: \(self.projects.count)")
    }
    
    // Public method that calls the internal version - for backward compatibility
    func fixMissingProjecsDataWithDefaults() {
        // Call the internal version which does the work and properly updates the published property
        fixMissingProjecsDataWithDefaultsInternal()
    }
    
    func deleteAllProjects() {
        
        fetchProjects()
        let mCount = count
        
        print("mCount is: \(mCount)")
        
        var ticker = 0
        
        while mCount>ticker {
            
            context.delete(projectAtIndex(index: ticker))
            projects.remove(at: ticker)
            
            ticker = ticker+1
            print("Deleted at : \(ticker)")
            saveContext()
        }
        
        print("Doone removing all !")
    }
    
//    func fetchProjects() {
//        
//        let fetchRequest =
//        NSFetchRequest<NSManagedObject>(entityName: "Projects")
//        //3
//        do {
//            let results = try context.fetch(fetchRequest)
//            projects = results as! [Projects]
//        } catch let error as NSError {
//            print("ProjectManager could not fetch tasks ! \(error), \(error.userInfo)")
//            
//        }
//        
//        print("projectManger: fetchProjects - DONE")
//    }
    
    func addNewProject(with name: String, and description: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            print("ProjectManager Error: Project name cannot be empty.")
            return false
        }
        if trimmedName.lowercased() == defaultProject.lowercased() {
            print("ProjectManager Error: Cannot create project with reserved name 'Inbox'.")
            return false
        }
        // Check against the current `self.projects` state
        if self.projects.contains(where: { $0.projectName?.lowercased() == trimmedName.lowercased() }) {
            print("ProjectManager Error: Project with name '\(trimmedName)' already exists.")
            return false
        }

        let proj = NSEntityDescription.insertNewObject(forEntityName: "Projects", into: context) as! Projects
        proj.projectName = trimmedName
        proj.projecDescription = description
        
        saveContext()
        fetchProjects() // Refresh @Published projects array
        
        print("Project added: '\(trimmedName)'. Total projects: \(self.projects.count)")
        return true
    }
    
    /**
     Updates an existing project with a new name and description.
     - Parameters:
        - projectToUpdate: The Projects entity to update
        - newName: The new name for the project
        - newDescription: The new description for the project
     - Returns: Bool indicating success or failure
    */
    // Method to get all projects - added to fix missing reference
    func getAllProjects() -> [Projects] {
        // Return the current projects array which is already fetched from Core Data
        return self.displayedProjects
    }
    
    func updateProject(_ projectToUpdate: Projects, newName: String, newDescription: String) -> Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return false }
        
        let oldProjectName = projectToUpdate.projectName
        
        // Prevent renaming a normal project to "Inbox"
        if trimmedName.lowercased() == defaultProject.lowercased() && oldProjectName?.lowercased() != defaultProject.lowercased() {
            print("ProjectManager Error: Cannot rename project to 'Inbox'.")
            return false
        }
        // Prevent renaming the "Inbox" project to something else
        if oldProjectName?.lowercased() == defaultProject.lowercased() && trimmedName.lowercased() != defaultProject.lowercased() {
            print("ProjectManager Error: Cannot rename the default 'Inbox' project.")
            return false
        }

        // Check for name conflicts if the name is actually changing
        if trimmedName.lowercased() != oldProjectName?.lowercased() {
            if self.projects.contains(where: { $0.objectID != projectToUpdate.objectID && $0.projectName?.lowercased() == trimmedName.lowercased() }) {
                print("ProjectManager Error: Another project with the name '\(trimmedName)' already exists.")
                return false
            }
        }
        
        projectToUpdate.projectName = trimmedName
        projectToUpdate.projecDescription = newDescription
        
        if let oldName = oldProjectName, oldName != trimmedName {
            updateTasksForProjectRename(oldName: oldName, newName: trimmedName)
        }
        saveContext() 
        fetchProjects() 
        return true
    }
    
    func deleteProject(_ projectToDelete: Projects) -> Bool {
        if projectToDelete.projectName?.lowercased() == defaultProject.lowercased() {
            print("ProjectManager Error: Cannot delete the default 'Inbox' project.")
            return false
        }
        
        if let deletedProjectName = projectToDelete.projectName, !deletedProjectName.isEmpty {
            reassignTasksToInbox(fromProject: deletedProjectName)
        }
        
        context.delete(projectToDelete)
        saveContext()
        fetchProjects()
        return true
    }
    
    private func reassignTasksToInbox(fromProject: String) {
        let tasksToReassign = TaskManager.sharedInstance.getTasksForProjectByName(projectName: fromProject)
        if !tasksToReassign.isEmpty {
            for task in tasksToReassign where !task.isComplete {
                task.project = defaultProject
            }
            TaskManager.sharedInstance.saveContext() // TaskManager saves its context
        }
    }
    
    private func updateTasksForProjectRename(oldName: String, newName: String) {
        let tasksToUpdate = TaskManager.sharedInstance.getTasksForProjectByName(projectName: oldName)
        if !tasksToUpdate.isEmpty {
            for task in tasksToUpdate {
                task.project = newName
            }
            TaskManager.sharedInstance.saveContext() // TaskManager saves its context
        }
    }
    
    // MARK: Init
    
    private init() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        context = appDelegate.persistentContainer.viewContext
        // Initial fetch can be deferred to the first call of `refreshAndPrepareProjects`.
        // We don't call fetchProjects() here to avoid potential update cycles during view initialization
    }
}
