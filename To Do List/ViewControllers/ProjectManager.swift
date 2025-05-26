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
        fetchProjects()
        
        // Find all Inbox projects (case insensitive)
        var inboxProjects = [Projects]()
        for project in projects {
            if project.projectName?.lowercased() == defaultProject.lowercased() {
                inboxProjects.append(project)
            }
        }
        
        // Handle different scenarios
        if inboxProjects.isEmpty {
            // No Inbox project exists, create one
            print("No Inbox project found! Creating default 'Inbox' project")
            
            let newInbox = NSEntityDescription.insertNewObject(forEntityName: "Projects", into: context) as! Projects
            newInbox.projectName = defaultProject // Use proper case from defaultProject variable
            newInbox.projecDescription = defaultProjectDescription
            
            projects.insert(newInbox, at: 0)
            saveContext()
        } else if inboxProjects.count > 1 {
            // Multiple Inbox projects found, merge them
            print("Found \(inboxProjects.count) Inbox projects! Merging them...")
            
            // Keep the first Inbox project (ensure it has the proper capitalization)
            let primaryInbox = inboxProjects[0]
            primaryInbox.projectName = defaultProject // Ensure correct capitalization
            
            // Move tasks from duplicate Inbox projects to the primary one
            for i in 1..<inboxProjects.count {
                let duplicateInbox = inboxProjects[i]
                
                // Get all tasks assigned to this duplicate Inbox
                if let duplicateName = duplicateInbox.projectName {
                    // Reassign tasks to the primary Inbox
                    let tasksToReassign = TaskManager.sharedInstance.getTasksForProjectByName(projectName: duplicateName)
                    for task in tasksToReassign {
                        task.project = defaultProject
                    }
                    
                    // Delete the duplicate Inbox project
                    context.delete(duplicateInbox)
                    if let index = projects.firstIndex(of: duplicateInbox) {
                        projects.remove(at: index)
                    }
                }
            }
            
            // Save all changes
            TaskManager.sharedInstance.saveContext()
            saveContext()
            print("Successfully merged duplicate Inbox projects")
        } else {
            // Exactly one Inbox project exists, ensure correct capitalization
            let existingInbox = inboxProjects[0]
            if existingInbox.projectName != defaultProject {
                existingInbox.projectName = defaultProject
                saveContext()
                print("Updated Inbox project capitalization")
            }
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
