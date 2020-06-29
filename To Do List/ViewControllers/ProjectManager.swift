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
    
    func projectAtIndex(index: Int) -> Projects {
        return projects[index]
    }
    
    var getAllProjects: [Projects] {
        get {
            fetchProjects()
            //            getProjects()
            for eaxh in projects {
                print("ProjectManager: Found Project: \(String(describing: eaxh.projectName))")
            }
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
