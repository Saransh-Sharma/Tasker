//
//  TaskManager.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import CoreData 

class TaskManager {
    //Singleton
    static let sharedInstance = TaskManager()

    private var tasks = [NTask]()
    let context: NSManagedObjectContext!

    func addNewTaskWithName(name: String) {
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        //set all default properties on adding a task
        task.name = name
        task.isComplete = false
        
        tasks.append(task)
        saveContext()
    }
    
    func taskAtIndex(index: Int) -> NTask {
        return tasks[index]
    }
    
    func removeTaskAtIndex(index: Int) {
        context.delete(taskAtIndex(index: index))
        tasks.remove(at: index)
    }
    
    
    func saveContext() {
        do {
            try context.save()
        } catch let error as NSError {
            print("TaskManager failed saving context ! \(error), \(error.userInfo)")
        }
    }
    
    func fetchTasks() {
        
        let fetchRequest =
            NSFetchRequest<NSManagedObject>(entityName: "NTask")
        //3
        do {
            let results = try context.fetch(fetchRequest)
            tasks = results as! [NTask]
        } catch let error as NSError {
            print("TaskManager could not fetch tasks ! \(error), \(error.userInfo)")
            
        }
    }
    
    // MARK: Init
    
    private init() {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        context = appDelegate.persistentContainer.viewContext
        
        fetchTasks()
    }
    
    
}



