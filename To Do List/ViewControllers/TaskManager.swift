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

/// TaskManager is a singleton class responsible for managing all task-related operations in the Tasker app.
/// 
/// This class handles CRUD operations for tasks, including creating, reading, updating, and deleting tasks.
/// It also provides methods for filtering tasks by various criteria such as project, date, completion status, etc.
/// TaskManager uses Core Data for persistence and maintains the state of all tasks in the application.
class TaskManager {
    /// Singleton instance of TaskManager
    /// Use this shared instance to access task management functionality throughout the app
    static let sharedInstance = TaskManager()
    
    /// Array containing all tasks fetched from Core Data
    private var tasks = [NTask]()
    /// Array containing upcoming tasks (taskType = 3)
    private var upcomingTasks = [NTask]()
    /// Array containing all tasks in the Inbox project
    private var allInboxTasks = [NTask]()
    /// Array containing all tasks in custom projects (non-Inbox)
    private var allCustomProjectTasks = [NTask]()
    
    /// Core Data managed object context for database operations
    let context: NSManagedObjectContext!
    /// Total number of tasks in the database
    /// - Returns: Count of all tasks after fetching the latest data
    var count: Int {
        get {
            fetchTasks()
            return tasks.count
        }
    }
    /// All tasks in the database
    /// - Returns: Array of all tasks after fetching the latest data
    var getAllTasks: [NTask] {
        get {
            fetchTasks()
            return tasks
        }
    }
    /// All upcoming tasks (taskType = 3)
    /// - Returns: Array of upcoming tasks after fetching the latest data
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
    /// All tasks in the Inbox project
    /// - Returns: Array of all tasks in the default Inbox project after fetching the latest data
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
    /// All tasks in custom projects (non-Inbox)
    /// - Returns: Array of all tasks in custom projects (excluding Inbox) after fetching the latest data
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
    
    // MARK: - Project-Based Task Retrieval Methods
    /// Methods for retrieving tasks based on project name and other criteria
    /// Retrieves all tasks belonging to a specific project
    /// - Parameter projectName: The name of the project to filter tasks by
    /// - Returns: Array of tasks that belong to the specified project
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
    
    // MARK: - Inbox Task Retrieval Methods
    /// Methods for retrieving tasks from the Inbox project
    /// Retrieves all Inbox tasks for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of Inbox tasks for the specified date
    func getTasksForInboxForDate_All(date: Date) -> [NTask] {
        
        print("refg: *********** *********** *********** ***********")
        print("refg: getTasksForInboxForDate_All - date \(date.stringIn(dateStyle: .short, timeStyle: .none)) - A")
        print("refg: *********** *********** *********** ***********")
        
        var inboxTasks = [NTask]()
        fetchTasks()
        
        
        for each in tasks {
            print("ref **** getTasksForInboxForDate_All NAME  - \(each.name)")
            let currentProjectName = each.project?.lowercased()
            let currentDueDate = each.dueDate
            //            print("0 ref: getTasksForInboxForDate_All - project \(each.project!.lowercased())")
            //            print("1 ref: getTasksForInboxForDate_All - project \(each.project!.lowercased() ?? "inbox")")
            if currentProjectName!.contains("\(ProjectManager.sharedInstance.defaultProject.lowercased())") {
                //                 tasks.append(each)
                print("! refg : getTasksForInboxForDate_All - found INBOX task ! - B")
                if currentDueDate == date as NSDate {
                    inboxTasks.append(each)
                }
                
                if (date == Date.today() && date > each.dueDate! as Date) { //add overdue inbox tasks
                    
                    
                    if (!each.isComplete) {
                        
                        print ("refg : addig overdue OPEN inbox task: \(each.name)")
                        inboxTasks.append(each)
                    } else if (each.isComplete) {
                        
                        if (each.dateCompleted != nil) {
                            if (date == each.dateCompleted! as Date) {
                                print ("refg : addig overdue DONE Today inbox task: \(each.name)")
                                inboxTasks.append(each)
                            }
                        }
                        
                        
                    }
                }
                
            }
            //            } else if currentProjectName == nil {
            //                print("!! ref: getTasksForInboxForDate_All - found HEADLESS INBOX task ! - C")
            //                tasks.append(each)
            //            }
            
            if currentProjectName == nil {
                print("!! refg: getTasksForInboxForDate_All - found HEADLESS INBOX task ! - C")
                if currentDueDate == date as NSDate {
                    inboxTasks.append(each)
                }
            }
        }
        print("!!! refg: getTasksForInboxForDate_All - inbox count: \(inboxTasks.count) - Z")
        print("refg INBOX TASK LIST")
        for each in inboxTasks {
            
            print("refg \(each.name)")
            
        }
        
        return inboxTasks
    }
    
    /// Retrieves all tasks for a specific custom project and date
    /// - Parameters:
    ///   - projectName: The name of the custom project to filter tasks by
    ///   - date: The date to filter tasks by
    /// - Returns: Array of tasks for the specified project and date
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
    
    /// Retrieves open (incomplete) tasks for a specific project and date
    /// - Parameters:
    ///   - projectName: The name of the project to filter tasks by
    ///   - date: The date to filter tasks by
    /// - Returns: Array of open tasks for the specified project and date
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
    
    /// Retrieves open (incomplete) tasks from all custom projects for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of open tasks from all custom projects for the specified date
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

                
            }
        }
        print("tasks for NON inbox count: \(mtasks.count)")
        return mtasks
    }
    
    /// Retrieves all tasks from all custom projects for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of all tasks from all custom projects for the specified date
    func getTasksForAllCustomProjectsByNameForDate_All(date: Date) -> [NTask] {
        
        var mtasks = [NTask]()
        fetchTasks()
        
        for each in tasks {
            let currentProjectName = each.project?.lowercased()
            
            if currentProjectName?.lowercased() != ProjectManager.sharedInstance.defaultProject.lowercased() { //if not INBOX
                
                
                if !each.isComplete {
                    
                    if (each.dueDate == date as NSDate) {
                        print("proj00 adding custom TASK -->\(each.name)")
                        mtasks.append(each)
                    } else if (each.dateCompleted  == date as NSDate) {
                        print("proj00 adding custom completed TASK -->\(each.name)")
                        mtasks.append(each)
                    }
                }
                
//                if (each.dateCompleted != nil) {
//                    if (each.dateCompleted! as Date > date && each.dateAdded! as Date == date) {
//                        print("rhur name: \(each.name)")
//                        mtasks.append(each)
//                    }
//
//                }
                
                
                
            }
        }
        print("tasks for NON inbox count: \(mtasks.count)")
        return mtasks
    }
    
    /// Retrieves completed tasks for a specific project and date
    /// - Parameters:
    ///   - projectName: The name of the project to filter tasks by
    ///   - date: The date to filter tasks by
    /// - Returns: Array of completed tasks for the specified project and date
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
    
    /// Retrieves overdue tasks for a specific project and date
    /// - Parameters:
    ///   - projectName: The name of the project to filter tasks by
    ///   - date: The date to filter tasks by
    /// - Returns: Array of overdue tasks for the specified project and date
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
    
    
    // MARK: - Time-Based Task Retrieval Methods
    /// Methods for retrieving tasks based on time of day (morning/evening)
    
    /// Retrieves morning tasks (taskType = 1) for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of morning tasks for the specified date
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
    
    /// Retrieves evening tasks (taskType = 2) for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of evening tasks for the specified date
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
    
    /// Retrieves morning tasks (taskType = 1) for today, including unfinished tasks from previous days
    /// Used in the home view to display today's tasks along with all unfinished tasks
    /// - Returns: Array of morning tasks for today and unfinished tasks from previous days
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
                                print("Green 2: \(each.name)")
                
                if ((each.dueDate! as Date) < today) {
//                    print("Green  - adding morning task: \(each.name)")
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
    
    /// Retrieves evening tasks (taskType = 2) for today, including unfinished tasks from previous days
    /// - Returns: Array of evening tasks for today and unfinished tasks from previous days
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
    
    // MARK: - Task Creation Methods
    /// Methods for creating new tasks with various properties
    
    /// Creates a new task with basic properties
    /// - Parameters:
    ///   - name: The name/title of the task
    ///   - taskType: The type of task (1=morning, 2=evening, 3=upcoming)
    ///   - taskPriority: The priority level of the task (higher number = higher priority)
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
    
    /// Creates a new task scheduled for today
    /// - Parameters:
    ///   - name: The name/title of the task
    ///   - taskType: The type of task (1=morning, 2=evening, 3=upcoming)
    ///   - taskPriority: The priority level of the task (higher number = higher priority)
    ///   - isEveningTask: Boolean indicating if this is an evening task
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
    
    /// Creates a new task scheduled for a future date
    /// - Parameters:
    ///   - name: The name/title of the task
    ///   - taskType: The type of task (1=morning, 2=evening, 3=upcoming)
    ///   - taskPriority: The priority level of the task (higher number = higher priority)
    ///   - futureTaskDate: The future date when the task is due
    ///   - isEveningTask: Boolean indicating if this is an evening task
    ///   - project: The project this task belongs to (defaults to "inbox" if empty)
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
    
    /// Creates a new morning task with default properties
    /// - Parameter name: The name/title of the task
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
    
    /// Creates a new evening task with default properties
    /// - Parameter name: The name/title of the task
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
    
    // MARK: - Task Management Utility Methods
    /// Utility methods for accessing, modifying, and managing tasks
    
    /// Retrieves a task at a specific index in the tasks array
    /// - Parameter index: The index of the task to retrieve
    /// - Returns: The task at the specified index
    func taskAtIndex(index: Int) -> NTask {
        return tasks[index]
    }
    
    /// Removes a task at a specific index from the tasks array and deletes it from Core Data
    /// - Parameter index: The index of the task to remove
    func removeTaskAtIndex(index: Int) {
        context.delete(taskAtIndex(index: index))
        tasks.remove(at: index)
        saveContext()
    }
    
    
    /// Saves the current state of the managed object context to persist changes to Core Data
    /// This method should be called after any changes to tasks to ensure they are saved to the database
    func saveContext() {
        do {
            try context.save()
        } catch let error as NSError {
            print("TaskManager failed saving context ! \(error), \(error.userInfo)")
        }
    }
    
    /// Fixes missing or inconsistent task data by applying default values
    /// Specifically, ensures all tasks have a project assigned (defaults to "inbox")
    /// This method is called during app initialization to maintain data integrity
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
    
    /// Fetches all tasks from Core Data and updates the tasks array
    /// This method is called by various other methods to ensure they are working with the latest data
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
    
    // MARK: - Initialization
    
    /// Private initializer to enforce the singleton pattern
    /// Sets up the Core Data context and fetches initial tasks
    private init() {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        context = appDelegate.persistentContainer.viewContext
        
        fetchTasks()
    }
    
    
}

// MARK: - Task Types
/// Task Type Constants:
/// - 1: Morning task
/// - 2: Evening task
/// - 3: Upcoming task

// MARK: - Task Priorities
/// Task Priority Levels:
/// - Higher number indicates higher priority
/// - Default priority is 3



