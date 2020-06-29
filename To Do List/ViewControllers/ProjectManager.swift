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
            //            for eaxh in projects {
            //                print("ProjectManager: Found Project: \(String(describing: eaxh.projectName))")
            //            }
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
        
        
        //FIX inbox as a defaukt added project in projects
        
        
        //FIX default project to 'inbox'
        var isThereInbox = false
        for each in projects {
            
            if each.projectName?.lowercased() == defaultProject.lowercased() {
                print("FOUND INBOX !")
                isThereInbox = true
            }
        }
        
        if isThereInbox {
            print("YES THERE IS INBOX !!")
        } else {
            print("No inbox ! Intilizing projeccts with default project 'inbox'")
            
            let proj = NSEntityDescription.insertNewObject( forEntityName: "Projects", into: context) as! Projects

                proj.projectName = defaultProject
                proj.projecDescription = defaultProjectDescription
                  
            projects.insert(proj, at: 0)
            saveContext()
            // SAVE context !!
        }
        
        for each in projects {
                
                if each.projectName?.lowercased() == defaultProject.lowercased() {
                    print("FOUND INBOX ! 2nd time round !")
                    isThereInbox = true
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
        
        let proj = NSEntityDescription.insertNewObject( forEntityName: "Projects", into: context) as! Projects
        
        
        proj.projectName = name
        proj.projecDescription = description
        
        let allProjects = getAllProjects
        
        for each in allProjects {
            if each.projectName?.lowercased() == name {
                print("projectManger: addNewProject - project \(name) already exists !")
                return false
            }
        }
        
        projects.append(proj)
        saveContext()
        
        print("projectManger: addNewProject - project added : \(getAllProjects.count)")
        print("projectManger: addNewProject - project count now is: \(getAllProjects.count)")
        
        return true
    }
    
    //    func getAllProjeects(with name: String, and description: String) {
    //
    //        let proj = NSEntityDescription.insertNewObject( forEntityName: "Projects", into: context) as! Projects
    //
    //
    //        proj.projectName = name
    //        proj.projecDescription = description
    //
    //
    //        projects.append(proj)
    //        saveContext()
    //
    //        print("addNewProject task count now is: \(getAllProjects.count)")
    //    }
    
    
    
    
    // MARK: Init
    
    private init() {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        context = appDelegate.persistentContainer.viewContext
        
        fetchProjects()
    }
}
