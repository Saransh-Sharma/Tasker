//
//  ProjectManager.swift
//  To Do List
//
//  Created by Saransh Sharma on 29/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

class ProjectManager {
    
    
    //Singleton
    static let sharedInstance = ProjectManager()
    
    private var projects = [Projects]()
    
    let context: NSManagedObjectContext!
    var count: Int {
        get {
            fetchProjects()
            return projects.count
        }
    }
    var defaultProject = "Inbox"
    var defaultProjectDescription = "Catch all project for all tasks no attached to a project"
    
    func projectAtIndex(index: Int) -> Projects {
        return projects[index]
    }
    
    var getAllProjects: [Projects] {
        get {
            fetchProjects()
            var inboxPosition = 0
            for eaxh in projects {
                print("ProjectManager: Found Project: \(String(describing: eaxh.projectName))")
                
                if ((String(describing: eaxh.projectName)) == "Inbox") {
                    let element = projects.remove(at: inboxPosition)
                    projects.insert(element, at: 0)
                }
                inboxPosition = inboxPosition + 1
            }
            projects = projects.uniqued()
            return projects
        }
    }
    
    
    func saveContext() {
        do {
            try context.save()
        } catch let error as NSError {
            print("ProjectManager failed saving context ! \(error), \(error.userInfo)")
        }
    }
    
    func removeProjectAtIndex(index: Int) {
        context.delete(projectAtIndex(index: index))
        projects.remove(at: index)
        saveContext()
    }
    
    func fixMissingProjecsDataWithDefaults() {
        fetchProjects() // Ensure 'self.projects' is up-to-date with the latest from Core Data

        var allFoundInboxProjects = [Projects]()
        var otherNonInboxProjects = [Projects]() // To store projects that are definitely not "Inbox"

        // 1. Identify all potential "Inbox" projects (case-insensitive) and separate others
        for project in self.projects {
            if project.projectName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == defaultProject.lowercased() {
                allFoundInboxProjects.append(project)
            } else {
                otherNonInboxProjects.append(project)
            }
        }

        if allFoundInboxProjects.isEmpty {
            // 2. No "Inbox" project exists: Create a new one with the canonical name and description.
            print("ProjectManager: No Inbox project found. Creating default '\(defaultProject)' project.")
            let newInbox = NSEntityDescription.insertNewObject(forEntityName: "Projects", into: context) as! Projects
            newInbox.projectName = defaultProject // Use the canonical name (e.g., "Inbox" with correct casing)
            newInbox.projecDescription = defaultProjectDescription
            
            // Update the local projects array immediately
            self.projects = [newInbox] + otherNonInboxProjects
            saveContext() // Persist the new Inbox project
            print("ProjectManager: Default '\(defaultProject)' project created successfully.")

        } else {
            // 3. One or more "Inbox" projects exist: Consolidate them.
            // Designate the first one found as the primary.
            let primaryInbox = allFoundInboxProjects.removeFirst() 
            var requiresSave = false // Flag to track if changes were made that need saving

            // 3a. Ensure the primary Inbox has the canonical name and description.
            if primaryInbox.projectName != defaultProject {
                print("ProjectManager: Correcting primary Inbox project name from '\(primaryInbox.projectName ?? "N/A")' to '\(defaultProject)'.")
                primaryInbox.projectName = defaultProject
                requiresSave = true
            }
            if primaryInbox.projecDescription != defaultProjectDescription {
                print("ProjectManager: Correcting primary Inbox project description.")
                primaryInbox.projecDescription = defaultProjectDescription
                requiresSave = true
            }

            // 3b. If there were other "Inbox" projects (duplicates), merge them into the primaryInbox.
            if !allFoundInboxProjects.isEmpty {
                print("ProjectManager: Found \(allFoundInboxProjects.count) duplicate Inbox project(s). Merging into '\(defaultProject)'.")
                for duplicateInbox in allFoundInboxProjects {
                    if let duplicateName = duplicateInbox.projectName, !duplicateName.isEmpty {
                        // Reassign tasks from the duplicate to the primary Inbox
                        let tasksToReassign = TaskManager.sharedInstance.getTasksForProjectByName(projectName: duplicateName)
                        if !tasksToReassign.isEmpty {
                            print("ProjectManager: Reassigning \(tasksToReassign.count) tasks from duplicate '\(duplicateName)' to '\(defaultProject)'.")
                            for task in tasksToReassign {
                                task.project = primaryInbox.projectName // Assign to the primary Inbox's canonical name
                            }
                        }
                    }
                    // Delete the duplicate project entity from Core Data
                    print("ProjectManager: Deleting duplicate Inbox project: '\(duplicateInbox.projectName ?? "N/A")' (ID: \(duplicateInbox.objectID)).")
                    context.delete(duplicateInbox)
                    requiresSave = true
                }
                // Ensure TaskManager saves changes to reassigned tasks
                if !allFoundInboxProjects.isEmpty { // Only save if tasks were potentially reassigned
                     TaskManager.sharedInstance.saveContext()
                }
            }
            
            // Update the local 'self.projects' array to reflect the consolidated state
            self.projects = [primaryInbox] + otherNonInboxProjects
            
            if requiresSave {
                saveContext() // Persist changes (renaming, deletions)
                print("ProjectManager: Inbox consolidation complete. Changes saved.")
            } else {
                print("ProjectManager: Inbox project is already consistent. No changes made.")
            }
        }
        
        // Re-fetch projects to ensure the 'self.projects' array accurately reflects the database state after consolidation.
        // This is important for subsequent operations within the same app session.
        fetchProjects()
        let finalInboxCount = self.projects.filter { $0.projectName?.lowercased() == defaultProject.lowercased() }.count
        print("ProjectManager: Post-consolidation check. Current canonical '\(defaultProject)' count: \(finalInboxCount). Total projects: \(self.projects.count)")
        if finalInboxCount > 1 {
            print("ProjectManager: WARNING - Multiple Inbox projects still detected post-consolidation. Further investigation needed.")
        } else if finalInboxCount == 0 && !self.projects.isEmpty { // Added check to ensure projects list isn't empty
            print("ProjectManager: WARNING - No Inbox project detected post-consolidation when projects exist. Further investigation needed.")
        }
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
    
    func fetchProjects() {
        
        let fetchRequest =
        NSFetchRequest<NSManagedObject>(entityName: "Projects")
        //3
        do {
            let results = try context.fetch(fetchRequest)
            projects = results as! [Projects]
        } catch let error as NSError {
            print("ProjectManager could not fetch tasks ! \(error), \(error.userInfo)")
            
        }
        
        print("projectManger: fetchProjects - DONE")
    }
    
    func addNewProject(with name: String, and description: String) -> Bool {
        // Validate the project name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if name is empty
        if trimmedName.isEmpty {
            return false
        }
        
        // Check if this is an attempt to create another "Inbox"
        if trimmedName.lowercased() == defaultProject.lowercased() {
            print("User trying to make another inbox!")
            return false
        }
        
        // Check if project with this name already exists (case insensitive)
        let allProjects = getAllProjects
        for project in allProjects {
            if project.projectName?.lowercased() == trimmedName.lowercased() {
                print("Project with name '\(trimmedName)' already exists!")
                return false
            }
        }
        
        // Create and configure new project
        let proj = NSEntityDescription.insertNewObject(forEntityName: "Projects", into: context) as! Projects
        proj.projectName = trimmedName
        proj.projecDescription = description
        
        // Save to Core Data
        projects.append(proj)
        saveContext()
        
        print("Project added: '\(trimmedName)'. Total projects: \(getAllProjects.count)")
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
    func updateProject(_ projectToUpdate: Projects, newName: String, newDescription: String) -> Bool {
        // Validate the new name
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if name is empty
        if trimmedName.isEmpty {
            return false
        }
        
        // Get current project name for comparison
        let oldProjectName = projectToUpdate.projectName
        
        // Check if attempting to rename to "Inbox" when not already Inbox
        if trimmedName.lowercased() == defaultProject.lowercased() && 
           oldProjectName?.lowercased() != defaultProject.lowercased() {
            print("Cannot rename project to 'Inbox' as this is a reserved name")
            return false
        }
        
        // Check if trying to update the default Inbox project name
        if oldProjectName?.lowercased() == defaultProject.lowercased() && 
           trimmedName.lowercased() != defaultProject.lowercased() {
            print("Cannot rename the default 'Inbox' project")
            return false
        }
        
        // Check for name conflicts with other projects
        if trimmedName.lowercased() != oldProjectName?.lowercased() {
            let allProjects = getAllProjects
            for project in allProjects {
                if project != projectToUpdate && project.projectName?.lowercased() == trimmedName.lowercased() {
                    print("Another project with the name '\(trimmedName)' already exists")
                    return false
                }
            }
        }
        
        // Save the old name for task updates
        let oldName = projectToUpdate.projectName
        
        // Update the project
        projectToUpdate.projectName = trimmedName
        projectToUpdate.projecDescription = newDescription
        saveContext()
        
        // If the name changed, update all tasks assigned to this project
        if oldName != trimmedName && oldName != nil {
            updateTasksForProjectRename(oldName: oldName!, newName: trimmedName)
        }
        
        return true
    }
    
    /**
     Deletes a project and reassigns its tasks to the default "Inbox" project.
     - Parameter projectToDelete: The Projects entity to delete
     - Returns: Bool indicating success or failure
    */
    func deleteProject(_ projectToDelete: Projects) -> Bool {
        // Protect the default Inbox project from deletion
        if projectToDelete.projectName?.lowercased() == defaultProject.lowercased() {
            print("Cannot delete the default 'Inbox' project")
            return false
        }
        
        // Save the project name for task reassignment
        let deletedProjectName = projectToDelete.projectName
        
        // Reassign tasks if the project has a valid name
        if let projectName = deletedProjectName, !projectName.isEmpty {
            reassignTasksToInbox(fromProject: projectName)
        }
        
        // Delete the project
        context.delete(projectToDelete)
        if let index = projects.firstIndex(of: projectToDelete) {
            projects.remove(at: index)
        }
        saveContext()
        
        return true
    }
    
    /**
     Reassigns all tasks from a specific project to the default Inbox project.
     - Parameter fromProject: The name of the project whose tasks should be reassigned
    */
    private func reassignTasksToInbox(fromProject: String) {
        // Get tasks for the project being deleted
        let tasksToReassign = TaskManager.sharedInstance.getTasksForProjectByName(projectName: fromProject)
        
        // Reassign each task to the Inbox project
        for task in tasksToReassign {
            task.project = defaultProject
        }
        
        // Save the changes
        TaskManager.sharedInstance.saveContext()
    }
    
    /**
     Updates task project references when a project is renamed.
     - Parameters:
        - oldName: The original name of the project
        - newName: The new name of the project
    */
    private func updateTasksForProjectRename(oldName: String, newName: String) {
        // Get tasks for the project being renamed
        let tasksToUpdate = TaskManager.sharedInstance.getTasksForProjectByName(projectName: oldName)
        
        // Update each task with the new project name
        for task in tasksToUpdate {
            task.project = newName
        }
        
        // Save the changes
        TaskManager.sharedInstance.saveContext()
    }
    
    // MARK: Init
    
    private init() {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        context = appDelegate.persistentContainer.viewContext
        
        fetchProjects()
    }
}
