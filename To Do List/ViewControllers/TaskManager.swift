//
//  TaskManager.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import Timepiece
import CoreData 

class TaskManager {
    //Singleton
    static let sharedInstance = TaskManager()
    
    private var tasks = [NTask]()
    //private var morningTasks = [NTask]()
    //private var eveningTasks = [NTask]()
    private var upcomingTasks = [NTask]()
    private var inboxTasks = [NTask]()
    
    let context: NSManagedObjectContext!
    var count: Int {
        get {
            fetchTasks()
            return tasks.count
        }
    }
    var getAllTasks: [NTask] {
        get {
            fetchTasks()
            return tasks
        }
    }
//    var getMorningTasks: [NTask] {
//        get {
//            var morningTasks = [NTask]()
//            fetchTasks()
//            for each in tasks {
//                // taskType 1 is morning
//                if each.taskType == 1 {
//                    morningTasks.append(each)
//                }
//            }
//            return morningTasks
//        }
//    }
//    var getEveningTasks: [NTask] {
//        get {
//            var eveningTasks = [NTask]()
//            fetchTasks()
//            for each in tasks {
//                // taskType 2 is evening
//                if each.taskType == 2 {
//                    eveningTasks.append(each)
//                }
//            }
//            return eveningTasks
//        }
//    }
    var getUpcomingTasks: [NTask] {
        get {
            fetchTasks()
            for each in tasks {
                // taskType 3 is upcoming
                if each.taskType == 3 {
                    upcomingTasks.append(each)
                }
            }
            return upcomingTasks
        }
    }
    var getInboxTasks: [NTask] {
        get {
            fetchTasks()
            for each in tasks {
                // taskType 4 is inbox
                if each.taskType == 4 {
                    inboxTasks.append(each)
                }
            }
            return inboxTasks
        }
    }
    
    func getMorningTasksForDate(date: Date) -> [NTask] {
           
        print("-----------------------")
                 
        print("Fetching MORNINNG tasks by date")
        
                var morningTasks = [NTask]()
                fetchTasks()
        
        print("getMorningTaskByDate: task count is: \(tasks.count)")
                for each in tasks {
                    // taskType 1 is morning
                    //task.dateAdded = Date.today() as NSDate
                    if each.taskType == 1 && each.dueDate == date as NSDate {
                        morningTasks.append(each)
                    } else {
//                        print("task date: \(each.dueDate)")
//                        print("passed date: \(date)")
                    }
                }
        for each in morningTasks {
            print("Fetched: "+each.name)
        }
        print("Morning Task Size = \(morningTasks.count)")
                 return morningTasks
    }
    
    func getEveningTaskByDate(date: Date) -> [NTask] {
           
        print("-----------------------")
                 
        print("Fetching EVENING tasks by date")
        
                var eveningTasks = [NTask]()
                fetchTasks()
        print("getEveningTaskByDate: task count is: \(tasks.count)")
                for each in tasks {
                    // taskType 1 is morning
                    //task.dateAdded = Date.today() as NSDate
                    if each.taskType == 2 && each.dueDate == date as NSDate {
                        eveningTasks.append(each)
                    } else {
                          print("task date: \(each.dueDate)")
                                              print("passed date: \(date)")
                    }
                }
        for each in eveningTasks {
                  print("Fetched: "+each.name)
              }
              print("Evenning Task Size = \(eveningTasks.count)")
                 return eveningTasks
    }
    
    //usee this at home view t get todays tasks  with all unfished
      func getMorningTasksForToday() -> [NTask] {
               
            print("-----------------------")
                     
            print("Fetching MORNINNG tasks")
            
                    var morningTasks = [NTask]()
                    fetchTasks()
            
            print("getMorningTaskByDate: task count is: \(tasks.count)")
        let today = Date.today()
                    for each in tasks {
                        // taskType 1 is morning
                        //task.dateAdded = Date.today() as NSDate
                        if each.taskType == 1 && each.dueDate == today as NSDate { //get finished & unfinished tasks today // Morning + tasks added today
                            morningTasks.append(each)
                            
                        } else if (each.taskType == 1 && each.isComplete == false) { //get older unfinished tasks // Morninng + incomplete
                            morningTasks.append(each)
                        } else if (each.taskType == 1 && each.dateCompleted == today as NSDate) { //get tasks that were completed today
                            morningTasks.append(each)
                        }
                            else {
    //                        print("task date: \(each.dueDate)")
    //                        print("passed date: \(date)")
                        }
                    }
            for each in morningTasks {
                print("Fetched: "+each.name)
            }
            print("Morning Task Size = \(morningTasks.count)")
                     return morningTasks
        }
    
     func getEveningTasksForToday() -> [NTask] {
               
            print("-----------------------")
                     
            print("Fetching EVENING tasks")
            
                    var eveningTasks = [NTask]()
                    fetchTasks()
            
            print("getMorningTaskByDate: task count is: \(tasks.count)")
        let today = Date.today()
                    for each in tasks {
                        // taskType 1 is morning
                        //task.dateAdded = Date.today() as NSDate
                        if each.taskType == 2 && each.dueDate == today as NSDate { //get finnisshed & unfinished tasks today
                            eveningTasks.append(each)
                            
                        } else if (each.taskType == 2 && each.isComplete == false) { //get older unfinished tasks
                            eveningTasks.append(each)
                        }
                            else {
    //                        print("task date: \(each.dueDate)")
    //                        print("passed date: \(date)")
                        }
                    }
            for each in eveningTasks {
                print("Fetched: "+each.name)
            }
            print("eveningTasks  Size = \(eveningTasks.count)")
                     return eveningTasks
        }
    
    func addNewTask(name: String, taskType: Int, taskPriority: Int) {
        
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.taskType = Int32(taskType)
        task.taskPriority = Int32(taskPriority)
        
        tasks.append(task)
        saveContext()
        print("addNewTaskWithName task count now is: \(getAllTasks.count)")
    }
    
    func addNewTask_Today(name: String, taskType: Int, taskPriority: Int, isEveningTask: Bool) {
        
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.taskType = Int32(taskType)
        task.taskPriority = Int32(taskPriority)
        task.dateAdded = Date.today() as NSDate
        task.dueDate = Date.today() as NSDate
        task.isEveningTask = isEveningTask
        
        let today = Date.today()
        let today2 = Date(year: 2014, month: 8, day: 14, hour: 20, minute: 25, second: 43)
        
        print("---------------------------------------")
        print("Today is: \(today)")
        print("Today is: \(today.stringIn(dateStyle: .long, timeStyle: .medium))")
        print("Today is: \(today.stringIn(dateStyle: .short, timeStyle: .short))")
        print("Today is: \(today.stringIn(dateStyle: .long, timeStyle: .short))")
        print("----------------------")
        print("TODAY_2 is: \(today2)")
        print("TODAY_2  is: \(today2.stringIn(dateStyle: .long, timeStyle: .medium))")
          print("TODAY_2  is: \(today2.stringIn(dateStyle: .short, timeStyle: .short))")
          print("TODAY_2  is: \(today2.stringIn(dateStyle: .long, timeStyle: .short))")
        print("---------------------------------------")
//        print("TODAY_2  NSDATE: \(Date.today() as NSDate)")
        
//        print("Today is: \(Date.)")
        print("---------------------------------------")
        
        tasks.append(task)
        saveContext()
        print("addNewTaskWithName task count now is: \(getAllTasks.count)")
    }
    
    func addNewTask_Future(name: String, taskType: Int, taskPriority: Int, futureTaskDate: Date, isEveningTask: Bool) {
        
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.taskType = Int32(taskType)
        task.taskPriority = Int32(taskPriority)
        task.dateAdded = Date.today() as NSDate
        task.dueDate = futureTaskDate as NSDate
        task.isEveningTask = isEveningTask
        
        
        
        tasks.append(task)
        saveContext()
        print("addNewTaskWithName task count now is: \(getAllTasks.count)")
    }
    
    func addNewMorningTaskWithName(name: String) {
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        //set all default properties on adding a task
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.taskType = 1
        task.taskPriority = 3
        
        tasks.append(task)
        saveContext()
        print("addNewTaskWithName task count now is: \(getAllTasks.count)")
    }
    
    func addNewEveningTaskWithName(name: String) {
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        //set all default properties on adding a task
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.taskType = 2
        task.taskPriority = 3
        
        tasks.append(task)
        saveContext()
        print("addNewTaskWithName task count now is: \(getAllTasks.count)")
    }
    
    func taskAtIndex(index: Int) -> NTask {
        return tasks[index]
    }
    
    func removeTaskAtIndex(index: Int) {
        context.delete(taskAtIndex(index: index))
        tasks.remove(at: index)
        saveContext()
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



