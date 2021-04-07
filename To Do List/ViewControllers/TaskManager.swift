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
    private var allInboxTasks = [NTask]()
    private var allCustomProjectTasks = [NTask]()
//    private var todaysInboxTasks = [NTask]()
//    private var todaysCustomProjectTasks = [NTask]()
    
    
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
    var getAllInboxTasks: [NTask] {
        get {
            fetchTasks()
            for each in tasks {
                if each.project?.lowercased() == ProjectManager.sharedInstance.defaultProject {
                    allInboxTasks.append(each)
                }
            }
            return allInboxTasks
        }
    }
        var getAllCustomProjectTasks: [NTask] {
            get {
                fetchTasks()
                for each in tasks {
                    if each.project?.lowercased() != ProjectManager.sharedInstance.defaultProject {
                        allCustomProjectTasks.append(each)
                    }
                }
                return allCustomProjectTasks
            }
        }
    

    
    func getTasksForProjectByName(projectName: String) -> [NTask] {
        
        var projectTasks = [NTask]()
        fetchTasks()
        
        for each in tasks {
            let currentProjectName = each.project?.lowercased()
            if currentProjectName!.contains("\(projectName)") {
                projectTasks.append(each)
            }
        }
        return projectTasks
    }
    
    func getTasksForInboxForDate_All(date: Date) -> [NTask] {
          
        print("ref: getTasksForInboxForDate_All - date \(date.stringIn(dateStyle: .short, timeStyle: .none)) - A")
          var inboxTasks = [NTask]()
          fetchTasks()
        
          
          for each in tasks {
            print("**** getTasksForInboxForDate_All NAME  - \(each.name)")
              let currentProjectName = each.project?.lowercased()
              let currentDueDate = each.dueDate
            print("0 ref: getTasksForInboxForDate_All - project \(each.project!.lowercased())")
            print("1 ref: getTasksForInboxForDate_All - project \(each.project!.lowercased() ?? "inbox")")
            if currentProjectName!.contains("\(ProjectManager.sharedInstance.defaultProject.lowercased())") {
                  //                 tasks.append(each)
                print("! ref: getTasksForInboxForDate_All - found INBOX task ! - B")
                  if currentDueDate == date as NSDate {
                      inboxTasks.append(each)
                  }
            }
//            } else if currentProjectName == nil {
//                print("!! ref: getTasksForInboxForDate_All - found HEADLESS INBOX task ! - C")
//                tasks.append(each)
//            }
                
                if currentProjectName == nil {
                    print("!! ref: getTasksForInboxForDate_All - found HEADLESS INBOX task ! - C")
                    if currentDueDate == date as NSDate {
                        inboxTasks.append(each)
                    }
                }
          }
        print("!!! ref: getTasksForInboxForDate_All - inbox count: \(inboxTasks.count) - Z")
          return inboxTasks
      }
    
    func getTasksForCustomProjectByNameForDate_All(projectName: String, date: Date) -> [NTask] {
        
        var customProjectTasks = [NTask]()
        fetchTasks()
        
        for each in tasks {
            let currentProjectName = each.project?.lowercased()
            let currentDueDate = each.dueDate
            if currentProjectName!.contains("\(projectName)") {
                //                 tasks.append(each)
                if currentDueDate == date as NSDate {
                    customProjectTasks.append(each)
                }
            }
        }
        return customProjectTasks
    }
    
    func getTasksForProjectByNameForDate_Open(projectName: String, date: Date) -> [NTask] {
        
        var mtasks = [NTask]()
        fetchTasks()
        
        for each in tasks {
            let currentProjectName = each.project?.lowercased()
            //            let currentDueDate = each.dueDate
            if currentProjectName!.contains("\(projectName.lowercased())") {
                
                
                
                if (date == Date.today()) {
                    //                    print("IS Today !")
                    
                    if each.dueDate == date as NSDate && !each.isComplete { //added today, open
                        
                        mtasks.append(each)
                        
                    }
                    else if (each.dateCompleted == date as NSDate) { //completed on that day
                        mtasks.append(each)
                    } else if ((each.dueDate! as Date) < date && !each.isComplete) {
                        mtasks.append(each)
                    }
                    
                    
                } else {
                    //                    print("NOT Today !")
                    if each.dueDate == date as NSDate && !each.isComplete { //added today, open
                        
                        mtasks.append(each)
                        
                    }
                    else if (each.dateCompleted == date as NSDate) { //completed on that day
                        mtasks.append(each)
                    }
                    
                }
                
            }
        }
        print("tasks for inbox count: \(mtasks.count)")
        return mtasks
    }
    
    func getTasksForAllCustomProjectsByNameForDate_Open(date: Date) -> [NTask] {
        
        var mtasks = [NTask]()
        fetchTasks()
        
        for each in tasks {
            let currentProjectName = each.project?.lowercased()
            let currentDueDate = each.dueDate
            
            if currentProjectName?.lowercased() != ProjectManager.sharedInstance.defaultProject.lowercased() {
                
                print("tasks for NON inbox : --------------")
                
                print("tasks for NON inbox : found NON INBOX  \((currentProjectName?.lowercased())! as String)")
                if !each.isComplete {
                    print("tasks for NON inbox : is open!")
                }
                print("tasks for NON inbox : --------------")
                
                if (date == Date.today()) {
                    //                      print("IS Today !")
                    
                    if each.dueDate == date as NSDate && !each.isComplete { //added today, open
                        
                        mtasks.append(each)
                        
                    }
                    else if (each.dateCompleted == date as NSDate) { //completed on that day
                        mtasks.append(each)
                    } else if ((each.dueDate! as Date) < date && !each.isComplete) {
                        mtasks.append(each)
                    }
                    
                    
                } else {
                    //                      print("NOT Today !")
                    if each.dueDate == date as NSDate && !each.isComplete { //added today, open
                        
                        mtasks.append(each)
                        
                    }
                    else if (each.dateCompleted == date as NSDate) { //completed on that day
                        mtasks.append(each)
                    }
                    
                }
                
                //                if currentDueDate == date as NSDate {
                //                    if !each.isComplete {
                //                        print("tasks for NON inbox :  Today !")
                //                        mtasks.append(each)
                //                    }
                //                } else {
                //                    print("tasks for NON inbox : NOT Today !")
                //                }
                
                //date < currentDueDate! as Date
                
                //                if (currentDueDate! as Date > date) {
                //                if (date > currentDueDate! as Date ) {
                //
                //                    if !each.isComplete {
                //                        mtasks.append(each)
                //                    }
                //                } else {
                //                    print("asks for NON inbox : is rollover task")
                //                }
                
            }
        }
        print("tasks for NON inbox count: \(mtasks.count)")
        return mtasks
    }
    
    func getTasksForProjectByNameForDate_Complete(projectName: String, date: Date) -> [NTask] {
        
        var tasks = [NTask]()
        fetchTasks()
        
        for each in tasks {
            let currentProjectName = each.project?.lowercased()
            let currentDueDate = each.dueDate
            if currentProjectName!.contains("\(projectName)") {
                //                 tasks.append(each)
                if currentDueDate == date as NSDate {
                    tasks.append(each)
                }
            }
        }
        return tasks
    }
    
    func getTasksForProjectByNameForDate_Overdue(projectName: String, date: Date) -> [NTask] {
        
        var tasks = [NTask]()
        fetchTasks()
        
        for each in tasks {
            let currentProjectName = each.project?.lowercased()
            let currentDueDate = each.dueDate
            if currentProjectName!.contains("\(projectName)") {
                //                 tasks.append(each)
                if currentDueDate == date as NSDate {
                    tasks.append(each)
                }
            }
        }
        return tasks
    }
    
    
    func getMorningTasksForDate(date: Date) -> [NTask] {
        
        var morningTasks = [NTask]()
        fetchTasks()
        
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
        return morningTasks
    }
    
    func getEveningTaskByDate(date: Date) -> [NTask] {
        
        var eveningTasks = [NTask]()
        fetchTasks()
        for each in tasks {
            // taskType 1 is morning
            //task.dateAdded = Date.today() as NSDate
            if each.taskType == 2 && each.dueDate == date as NSDate {
                eveningTasks.append(each)
            } else {
                //                          print("task date: \(each.dueDate)")
                //                                              print("passed date: \(date)")
            }
        }
        return eveningTasks
    }
    
    //usee this at home view t get todays tasks  with all unfished
    func getMorningTasksForToday() -> [NTask] {
        
        
        var morningTasks = [NTask]()
        fetchTasks()
        
        //        print("getMorningTaskByDate: task count is: \(tasks.count)")
        let today = Date.today()
        for each in tasks {
            // taskType 1 is morning
            if each.taskType == 1 && each.dueDate == today as NSDate { //get morning tasks added today
                morningTasks.append(each)
                print("Green 1: \(each.name)")
            } else if (each.taskType == 1 && each.isComplete == false) { //get older unfinished tasks // Morninng + incomplete
                //                morningTasks.append(each)
                //                print("Green 2: \(each.name)")
                
                if ((each.dueDate! as Date) < today) {
                    morningTasks.append(each)
                }
                
                //                if (each.dueDate! as Date > today) {
                //                    print("Green 2: SKIP")
                //                } else {
                //                    print("Green 2: Add Old task \(each.name)")
                //                    morningTasks.append(each)
                //                }
                
            } else if (each.taskType == 1 && each.dateCompleted == today as NSDate) { //get rollover tasks that were completed today
                morningTasks.append(each)
                print("Green 3: \(each.name)")
            }
            else {
                //                        print("task date: \(each.dueDate)")
                //                        print("passed date: \(date)")
            }
        }
        return morningTasks
    }
    
    func getEveningTasksForToday() -> [NTask] {
        
        var eveningTasks = [NTask]()
        fetchTasks()
        
        let today = Date.today()
        for each in tasks {
            // taskType 2 is evenning
            //task.dateAdded = Date.today() as NSDate
            if each.taskType == 2 && each.dueDate == today as NSDate { //get evening tasks added today
                eveningTasks.append(each)
            } else if (each.taskType == 2 && each.isComplete == false) { //get older unfinished tasks
                eveningTasks.append(each)
            }else if (each.taskType == 2 && each.dateCompleted == today as NSDate) { //get rollover tasks that were completed today
                eveningTasks.append(each)
            }
            else {
                //                        print("task date: \(each.dueDate)")
                //                        print("passed date: \(date)")
            }
        }
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
    
    func addNewTask_Future(name: String, taskType: Int, taskPriority: Int, futureTaskDate: Date, isEveningTask: Bool, project: String) {
        
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        
        
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.taskType = Int32(taskType)
        task.taskPriority = Int32(taskPriority)
        task.dateAdded = Date.today() as NSDate
        task.dueDate = futureTaskDate as NSDate
        task.isEveningTask = isEveningTask
        
        
        if(project.isEmpty) {
            task.project = "inbox"
        } else {
            task.project = project
        }
        
        print("addNewTask_Future: \(futureTaskDate.stringIn(dateStyle: .full, timeStyle: .none))")
        
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
    
    func fixMissingTasksDataWithDefaults() {
        fetchTasks()
        ProjectManager.sharedInstance.fetchProjects()
        
        //FIX inbox as a defaukt added project in projects
        
        
        //FIX default project to 'inbox'
        for each in tasks {
            //                if each.project!.isEmpty || each.project == "" || each.project == nil {
            if each.project?.isEmpty ?? true {
                
                print("**** FORCE PROJECT **** \(each.name) --- to --- inbox")
                
                each.project = "inbox"
                saveContext()
                
            } else {
                print("**** PROJECT is \(each.project! as String)")
            }
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



