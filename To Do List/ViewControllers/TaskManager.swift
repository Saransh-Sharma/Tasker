//
//  TaskManager.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/05/20.
//  Copyright 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import Timepiece
import CoreData

/// Defines the type of task in the system
/// Used to categorize tasks into morning, evening, or upcoming
enum TaskType: Int32, CaseIterable {
    case morning = 1
    case evening = 2
    case upcoming = 3
    
    var description: String {
        switch self {
        case .morning: return "Morning"
        case .evening: return "Evening"
        case .upcoming: return "Upcoming"
        }
    }
}

/// Defines the priority level of a task
/// Higher values indicate higher priority
enum TaskPriority: Int32, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

/// TaskManager is a singleton class responsible for managing all task-related operations in the Tasker app.
/// 
/// This class handles CRUD operations for tasks, including creating, reading, updating, and deleting tasks.
/// It also provides methods for filtering tasks by various criteria such as project, date, completion status, etc.
/// TaskManager uses Core Data for persistence and maintains the state of all tasks in the application.
class TaskManager {
    /// Singleton instance of TaskManager
    /// Use this shared instance to access task management functionality throughout the app
    static let sharedInstance = TaskManager()
    
    /// LEGACY: Array containing all tasks fetched from Core Data
    /// This is kept for backward compatibility with existing code
    /// New code should use direct predicate-based fetching with fetchTasks(predicate:sortDescriptors:)
    private var tasks = [NTask]()
    
    /// Core Data managed object context for database operations
    let context: NSManagedObjectContext!
    /// Total number of tasks in the database
    /// - Returns: Count of all tasks after fetching the latest data
    var count: Int {
        get {
            return fetchTasks(predicate: nil).count
        }
    }
    /// All tasks in the database
    /// - Returns: Array of all tasks after fetching the latest data
    var getAllTasks: [NTask] {
        get {
            return fetchTasks(predicate: nil, sortDescriptors: nil)
        }
    }
    
    /// All upcoming tasks (taskType = 3)
    /// - Returns: Array of upcoming tasks after fetching the latest data
    func getUpcomingTasks() -> [NTask] {
        let predicate = NSPredicate(format: "taskType == %d", TaskType.upcoming.rawValue)
        let sortByDate = NSSortDescriptor(key: "dueDate", ascending: true)
        return fetchTasks(predicate: predicate, sortDescriptors: [sortByDate])
    }
    
    /// All tasks in the Inbox project
    /// - Returns: Array of all tasks in the default Inbox project after fetching the latest data
    func getAllInboxTasks() -> [NTask] {
        let predicate = NSPredicate(format: "project ==[c] %@", ProjectManager.sharedInstance.defaultProject)
        return fetchTasks(predicate: predicate, sortDescriptors: nil)
    }
    
    /// All tasks in custom projects (non-Inbox)
    /// - Returns: Array of all tasks in custom projects (excluding Inbox) after fetching the latest data
    func getAllCustomProjectTasks() -> [NTask] {
        let predicate = NSPredicate(format: "project !=[c] %@", ProjectManager.sharedInstance.defaultProject)
        return fetchTasks(predicate: predicate, sortDescriptors: nil)
    }
    
    // MARK: - Project-Based Task Retrieval Methods
    /// Methods for retrieving tasks based on project name and other criteria
    
    /// Converts a ToDoListData.TaskListItem to an NTask object
    /// This method attempts to find an NTask with a matching name from the TaskListItem
    /// - Parameter taskListItem: The TaskListItem to convert
    /// - Returns: The corresponding NTask if found, nil otherwise
    func getTaskFromTaskListItem(taskListItem: ToDoListData.TaskListItem) -> NTask? {
        // Use case-insensitive predicate to find tasks with matching name
        let predicate = NSPredicate(
            format: "name ==[c] %@", 
            taskListItem.TaskTitle
        )
        
        // Fetch tasks matching the predicate
        let matchingTasks = fetchTasks(predicate: predicate)
        
        // Return the first matching task, or nil if none found
        if let matchedTask = matchingTasks.first {
            print("TaskManager: Found matching task '\(matchedTask.name)' for TaskListItem '\(taskListItem.TaskTitle)'")
            return matchedTask
        } else {
            print("TaskManager: No matching task found for TaskListItem '\(taskListItem.TaskTitle)'")
            return nil
        }
    }
    
    /// Retrieves all tasks belonging to a specific project
    /// - Parameter projectName: The name of the project to filter tasks by
    /// - Returns: Array of tasks that belong to the specified project
    func getTasksForProjectByName(projectName: String) -> [NTask] {
        // Use case-insensitive contains predicate to find tasks with matching project name
        let predicate = NSPredicate(format: "project CONTAINS[c] %@", projectName)
        
        return fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
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
        
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Tasks due on this date in the Inbox
        let dueTodayPredicate = NSPredicate(
            format: "project ==[c] %@ AND dueDate >= %@ AND dueDate < %@",
            ProjectManager.sharedInstance.defaultProject,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Overdue tasks that are still open (for current date only)
        let overduePredicate = NSPredicate(
            format: "project ==[c] %@ AND dueDate < %@ AND isComplete == NO AND %@ == %@",
            ProjectManager.sharedInstance.defaultProject,
            startOfDay as NSDate,
            date as NSDate,
            Date.today() as NSDate
        )
        
        // Tasks completed on this date
        let completedTodayPredicate = NSPredicate(
            format: "project ==[c] %@ AND dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
            ProjectManager.sharedInstance.defaultProject,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Tasks with nil project (headless)
        let nilProjectPredicate = NSPredicate(
            format: "project == nil AND dueDate >= %@ AND dueDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Combine all conditions
        let combinedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            dueTodayPredicate,
            overduePredicate,
            completedTodayPredicate,
            nilProjectPredicate
        ])
        
        let tasks = fetchTasks(predicate: combinedPredicate, sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)])
        
        print("!!! refg: getTasksForInboxForDate_All - inbox count: \(tasks.count) - Z")
        print("refg INBOX TASK LIST")
        for each in tasks {
            print("refg \(each.name)")
        }
        
        return tasks
    }
    
    /// Retrieves all tasks for a specific custom project and date
    /// - Parameters:
    ///   - projectName: The name of the custom project to filter tasks by
    ///   - date: The date to filter tasks by
    /// - Returns: Array of tasks for the specified project and date
    func getTasksForCustomProjectByNameForDate_All(projectName: String, date: Date) -> [NTask] {
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Project name matching and due date matching in a single predicate
        let predicate = NSPredicate(
            format: "project CONTAINS[c] %@ AND dueDate >= %@ AND dueDate < %@",
            projectName,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        return fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    /// Retrieves open (incomplete) tasks for a specific project and date
    /// - Parameters:
    ///   - projectName: The name of the project to filter tasks by
    ///   - date: The date to filter tasks by
    /// - Returns: Array of open tasks for the specified project and date
    func getTasksForProjectByNameForDate_Open(projectName: String, date: Date) -> [NTask] {
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Project name predicate (case insensitive contains)
        let projectPredicate = NSPredicate(format: "project CONTAINS[c] %@", projectName)
        
        // Tasks due on this date and not complete
        let dueTodayAndOpenPredicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Tasks completed on this date
        let completedTodayPredicate = NSPredicate(
            format: "dateCompleted >= %@ AND dateCompleted < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Create different predicates based on whether we're looking at today or another date
        var finalPredicate: NSPredicate
        
        if Calendar.current.isDateInToday(date) {
            // For today, include overdue and incomplete tasks
            let overduePredicate = NSPredicate(
                format: "dueDate < %@ AND isComplete == NO",
                startOfDay as NSDate
            )
            
            // For today: due today & open, OR completed today, OR overdue & open
            let datePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                dueTodayAndOpenPredicate,
                completedTodayPredicate,
                overduePredicate
            ])
            
            finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [projectPredicate, datePredicate])
        } else {
            // For other days: due on that day & open, OR completed on that day
            let datePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                dueTodayAndOpenPredicate,
                completedTodayPredicate
            ])
            
            finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [projectPredicate, datePredicate])
        }
        
        let tasks = fetchTasks(
            predicate: finalPredicate, 
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
        
        print("tasks for project \(projectName) count: \(tasks.count)")
        return tasks
    }
    
    /// Retrieves open (incomplete) tasks from all custom projects for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of open tasks from all custom projects for the specified date
    /// Retrieves all tasks for a specific project and date
    /// - Parameters:
    ///   - projectName: The name of the project to filter tasks by
    ///   - date: The date to filter tasks by
    /// - Returns: Array of all tasks for the specified project and date
    func getTasksByProjectNameAndDate(projectName: String, date: Date) -> [NTask] {
        var filteredTasks = [NTask]()
        fetchTasks()
        
        for each in tasks {
            let currentProjectName = each.project?.lowercased()
            if currentProjectName == projectName.lowercased() && each.dueDate as Date? == date {
                filteredTasks.append(each)
            }
        }
        return filteredTasks
    }
    
    func getTasksForAllCustomProjectsByNameForDate_Open(date: Date) -> [NTask] {
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Find tasks in non-inbox projects, due today, and not completed
        let notInboxPredicate = NSPredicate(format: "project != %@", ProjectManager.sharedInstance.defaultProject)
        let dueTodayPredicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@ AND isComplete == NO", 
                                           startOfDay as NSDate, endOfDay as NSDate)
        
        // Also include tasks completed today
        let completedTodayPredicate = NSPredicate(format: "dateCompleted >= %@ AND dateCompleted < %@", 
                                                 startOfDay as NSDate, endOfDay as NSDate)
        
        // Combine predicates to get all open tasks for non-inbox projects
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            notInboxPredicate,
            NSCompoundPredicate(orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate])
        ])
        
        let tasks = fetchTasks(
            predicate: predicate, 
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
        
        print("tasks for NON inbox count: \(tasks.count)")
        return tasks
    }
    
    /// Retrieves all tasks from all custom projects for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of all tasks from all custom projects for the specified date
    func getTasksForAllCustomProjectsByNameForDate_All(date: Date) -> [NTask] {
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Find tasks in non-inbox projects
        let notInboxPredicate = NSPredicate(format: "project != %@", ProjectManager.sharedInstance.defaultProject)
        
        // Tasks due today OR completed today
        let dueTodayPredicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", 
                                          startOfDay as NSDate, endOfDay as NSDate)
        let completedTodayPredicate = NSPredicate(format: "dateCompleted >= %@ AND dateCompleted < %@", 
                                                startOfDay as NSDate, endOfDay as NSDate)
        
        // Combine predicates to get all tasks for non-inbox projects
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            notInboxPredicate,
            NSCompoundPredicate(orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate])
        ])
        
        let tasks = fetchTasks(
            predicate: predicate, 
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
        
        print("tasks for NON inbox count: \(tasks.count)")
        return tasks
    }
    
    /// Retrieves completed tasks for a specific project and date
    /// - Parameters:
    ///   - projectName: The name of the project to filter tasks by
    ///   - date: The date to filter tasks by
    /// - Returns: Array of completed tasks for the specified project and date
    func getTasksForProjectByNameForDate_Complete(projectName: String, date: Date) -> [NTask] {
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Project name predicate (case insensitive contains)
        let projectPredicate = NSPredicate(format: "project CONTAINS[c] %@", projectName)
        
        // Tasks due on this date and complete
        let completedTasksPredicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@ AND isComplete == YES",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Combine predicates
        let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            projectPredicate, 
            completedTasksPredicate
        ])
        
        return fetchTasks(
            predicate: finalPredicate, 
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    /// Retrieves overdue tasks for a specific project and date
    /// - Parameters:
    ///   - projectName: The name of the project to filter tasks by
    ///   - date: The date to filter tasks by
    /// - Returns: Array of overdue tasks for the specified project and date
    func getTasksForProjectByNameForDate_Overdue(projectName: String, date: Date) -> [NTask] {
        // Get start of day for proper date comparison
        let startOfDay = date.startOfDay
        
        // Project name predicate (case insensitive contains)
        let projectPredicate = NSPredicate(format: "project CONTAINS[c] %@", projectName)
        
        // Tasks due before this date and not complete (overdue)
        let overduePredicate = NSPredicate(
            format: "dueDate < %@ AND isComplete == NO",
            startOfDay as NSDate
        )
        
        // Combine predicates
        let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            projectPredicate, 
            overduePredicate
        ])
        
        return fetchTasks(
            predicate: finalPredicate, 
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    
    // MARK: - Time-Based Task Retrieval Methods
    /// Methods for retrieving tasks based on time of day (morning/evening)
    
    /// Retrieves morning tasks (taskType = 1) for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of morning tasks for the specified date
    func getMorningTasksForDate(date: Date) -> [NTask] {
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Morning tasks (taskType = 1) due on this date
        let predicate = NSPredicate(
            format: "taskType == %d AND dueDate >= %@ AND dueDate < %@",
            1, // taskType 1 is morning
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        return fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    /// Retrieves evening tasks (taskType = 2) for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of evening tasks for the specified date
    func getEveningTaskByDate(date: Date) -> [NTask] {
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Evening tasks (taskType = 2) due on this date
        let predicate = NSPredicate(
            format: "taskType == %d AND dueDate >= %@ AND dueDate < %@",
            2, // taskType 2 is evening
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        return fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    /// Retrieves morning tasks (taskType = 1) for today, including unfinished tasks from previous days
    /// Used in the home view to display today's tasks along with all unfinished tasks
    /// - Returns: Array of morning tasks for today and unfinished tasks from previous days
    func getMorningTasks(for date: Date) -> [NTask] {
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let today = Date.today()
        
        // Morning tasks (taskType = 1) due on this date
        let dueTodayPredicate = NSPredicate(
            format: "taskType == %d AND dueDate >= %@ AND dueDate < %@",
            1, // taskType 1 is morning
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Older unfinished morning tasks (from previous dates)
        let overdueUnfinishedPredicate = NSPredicate(
            format: "taskType == %d AND dueDate < %@ AND isComplete == NO",
            1, // taskType 1 is morning
            startOfDay as NSDate
        )
        
        // Morning tasks completed today
        let completedTodayPredicate = NSPredicate(
            format: "taskType == %d AND dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
            1, // taskType 1 is morning
            today.startOfDay as NSDate,
            Calendar.current.date(byAdding: .day, value: 1, to: today.startOfDay)! as NSDate
        )
        
        // Combine all conditions
        let combinedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            dueTodayPredicate,
            overdueUnfinishedPredicate,
            completedTodayPredicate
        ])
        
        let tasks = fetchTasks(
            predicate: combinedPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
        
        // Keep the debug prints for manual verification (will be cleaned up in later phases)
        for task in tasks {
            if (task.dueDate! as Date) >= startOfDay && (task.dueDate! as Date) < endOfDay {
                print("Green 1: \(task.name)")
            } else if (task.dueDate! as Date) < (today.startOfDay as NSDate) as Date && !task.isComplete {
                print("Green 2: \(task.name)")
            } else if (task.dateCompleted as? Date) == today {
                print("Green 3: \(task.name)")
            }
        }
        
        return tasks
    }
    
    /// Retrieves evening tasks (taskType = 2) for today, including unfinished tasks from previous days
    /// - Returns: Array of evening tasks for today and unfinished tasks from previous days
    func getEveningTasksForToday() -> [NTask] {
        let today = Date.today()
        let startOfDay = today.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Evening tasks (taskType = 2) due today
        let dueTodayPredicate = NSPredicate(
            format: "taskType == %d AND dueDate >= %@ AND dueDate < %@",
            2, // taskType 2 is evening
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // All unfinished evening tasks (regardless of due date)
        let unfinishedPredicate = NSPredicate(
            format: "taskType == %d AND isComplete == NO",
            2 // taskType 2 is evening
        )
        
        // Evening tasks completed today
        let completedTodayPredicate = NSPredicate(
            format: "taskType == %d AND dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
            2, // taskType 2 is evening
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Combine all conditions
        let combinedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            dueTodayPredicate,
            unfinishedPredicate,
            completedTodayPredicate
        ])
        
        return fetchTasks(
            predicate: combinedPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    // MARK: - Task Retrieval by Date
    /// Retrieves all tasks for a specific date
    /// - Parameter date: The date to filter tasks by
    /// - Returns: Array of all tasks for the specified date
    func getAllTasksForDate(date: Date) -> [NTask] {
        // Get start and end of day for proper date range comparison
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Tasks due on this date
        let dueTodayPredicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Overdue tasks if we're looking at today
        var predicates = [dueTodayPredicate]
        
        if Calendar.current.isDateInToday(date) {
            let overduePredicate = NSPredicate(
                format: "dueDate < %@ AND isComplete == NO",
                startOfDay as NSDate
            )
            predicates.append(overduePredicate)
        }
        
        // Tasks completed on this date
        let completedTodayPredicate = NSPredicate(
            format: "dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        predicates.append(completedTodayPredicate)
        
        // Combine all conditions
        let finalPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        return fetchTasks(
            predicate: finalPredicate, 
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    // MARK: - Project-Based Morning/Evening Task Retrieval
    /// Retrieves morning tasks for a specific project
    /// - Parameter projectName: The name of the project to filter tasks by
    /// - Returns: Array of morning tasks for the specified project
    func getMorningTasksForProject(projectName: String) -> [NTask] {
        // Morning tasks for the specified project
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "taskType == %d", TaskType.morning.rawValue),
            NSPredicate(format: "project ==[c] %@", projectName)
        ])
        
        return fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    /// Retrieves evening tasks for a specific project
    /// - Parameter projectName: The name of the project to filter tasks by
    /// - Returns: Array of evening tasks for the specified project
    func getEveningTasksForProject(projectName: String) -> [NTask] {
        // Evening tasks for the specified project
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "taskType == %d", TaskType.evening.rawValue),
            NSPredicate(format: "project ==[c] %@", projectName)
        ])
        
        return fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)]
        )
    }
    
    // MARK: - Task Creation Methods
    /// Methods for creating new tasks with various properties
    
    /// Creates a new task with basic properties
    /// - Parameters:
    ///   - name: The name/title of the task
    ///   - taskType: The type of task (morning, evening, upcoming)
    ///   - taskPriority: The priority level of the task
    @discardableResult
    func addNewTask(name: String, taskType: TaskType, taskPriority: TaskPriority) -> NTask {
        
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.type = taskType
        task.priority = taskPriority
        
        // No longer need to append to in-memory array since we're using predicate-driven fetching
        saveContext()
        print("addNewTaskWithName task count now is: \(getAllTasks.count)")
        
        return task
    }
    
    /// Legacy method signature for backward compatibility
    /// - Parameters:
    ///   - name: The name/title of the task
    ///   - taskType: The type of task as integer (1=morning, 2=evening, 3=upcoming)
    ///   - taskPriority: The priority level of the task as integer (1=low, 2=medium, 3=high)
    func addNewTask(name: String, taskType: Int, taskPriority: Int) {
        let type = TaskType(rawValue: Int32(taskType)) ?? .morning
        let priority = TaskPriority(rawValue: Int32(taskPriority)) ?? .medium
        addNewTask(name: name, taskType: type, taskPriority: priority)
    }
    
    /// Creates a new task scheduled for today
    /// - Parameters:
    ///   - name: The name/title of the task
    ///   - taskType: The type of task (morning, evening, upcoming)
    ///   - taskPriority: The priority level of the task
    ///   - isEveningTask: Boolean indicating if this is an evening task
    ///   - project: The project this task belongs to (defaults to "inbox" if empty)
    @discardableResult
    func addNewTask_Today(name: String, taskType: TaskType, taskPriority: TaskPriority, isEveningTask: Bool, project: String) -> NTask {
        
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.type = taskType
        task.priority = taskPriority
        task.dateAdded = Date.today() as NSDate
        task.dueDate = Date.today() as NSDate
        task.setValue(isEveningTask, forKey: "isEveningTask")  // This will also set type to .evening if true
        
        // Set project, defaulting to inbox if empty
        if project.isEmpty {
            task.project = ProjectManager.sharedInstance.defaultProject
        } else {
            task.project = project
        }
        
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
        
        // No longer need to append to in-memory array since we're using predicate-driven fetching
        saveContext()
        print("addNewTaskWithName task count now is: \(getAllTasks.count)")
        
        return task
    }
    
    /// Creates a new task scheduled for a future date
    /// - Parameters:
    ///   - name: The name/title of the task
    ///   - taskType: The type of task (morning, evening, upcoming)
    ///   - taskPriority: The priority level of the task
    ///   - futureTaskDate: The future date when the task is due
    ///   - isEveningTask: Boolean indicating if this is an evening task
    ///   - project: The project this task belongs to (defaults to "inbox" if empty)
    /// - Returns: The newly created NTask object
    @discardableResult
    func addNewTask_Future(name: String, taskType: TaskType, taskPriority: TaskPriority, futureTaskDate: Date, isEveningTask: Bool, project: String) -> NTask {
        
        print("🏗️ TaskManager: Creating new task entity in Core Data...")
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        print("🏗️ TaskManager: Setting task properties...")
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.type = taskType
        task.priority = taskPriority
        task.dateAdded = Date.today() as NSDate
        task.dueDate = futureTaskDate as NSDate
        task.setValue(isEveningTask, forKey: "isEveningTask") // This will also set type to .evening if true
        
        
        if(project.isEmpty) {
            task.project = "inbox"
        } else {
            task.project = project
        }
        
        print("🏗️ TaskManager: Task properties set - Name: '\(name)', Due: \(futureTaskDate.stringIn(dateStyle: .full, timeStyle: .none)), Project: '\(task.project ?? "nil")'")
        
        // No longer need to append to in-memory array since we're using predicate-driven fetching
        print("🏗️ TaskManager: About to save context...")
        saveContext()
        print("🏗️ TaskManager: Context saved. Total task count: \(getAllTasks.count)")
        
        return task
    }
    
    /// Legacy method signature for backward compatibility
    /// - Parameters:
    ///   - name: The name/title of the task
    ///   - taskType: The type of task as integer (1=morning, 2=evening, 3=upcoming)
    ///   - taskPriority: The priority level of the task as integer (1=low, 2=medium, 3=high)
    ///   - futureTaskDate: The future date when the task is due
    ///   - isEveningTask: Boolean indicating if this is an evening task
    ///   - project: The project this task belongs to
    /// - Returns: The newly created NTask object
    @discardableResult
    func addNewTask_Future(name: String, taskType: Int, taskPriority: Int, futureTaskDate: Date, isEveningTask: Bool, project: String) -> NTask {
        let type = TaskType(rawValue: Int32(taskType)) ?? .morning
        let priority = TaskPriority(rawValue: Int32(taskPriority)) ?? .medium
        return addNewTask_Future(name: name, taskType: type, taskPriority: priority, futureTaskDate: futureTaskDate, isEveningTask: isEveningTask, project: project)
    }
    
    /// Creates a new morning task with default properties
    /// - Parameter name: The name/title of the task
    /// - Returns: The newly created NTask object
    @discardableResult
    func addNewMorningTaskWithName(name: String) -> NTask {
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        // Set all default properties on adding a task
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.type = .morning
        task.priority = .medium
        
        // No longer need to append to in-memory array since we're using predicate-driven fetching
        saveContext()
        print("addNewTaskWithName task count now is: \(getAllTasks.count)")
        
        return task
    }
    
    /// Creates a new evening task with default properties
    /// - Parameter name: The name/title of the task
    /// - Returns: The newly created NTask object
    @discardableResult
    func addNewEveningTaskWithName(name: String) -> NTask {
        let task = NSEntityDescription.insertNewObject( forEntityName: "NTask", into: context) as! NTask
        
        // Set all default properties on adding a task
        task.name = name
        task.isComplete = false
        task.taskDetails = "Fill in task details here"
        task.type = .evening
        task.priority = .medium
        
        // No longer need to append to in-memory array since we're using predicate-driven fetching
        saveContext()
        print("addNewTaskWithName task count now is: \(getAllTasks.count)")
        
        return task
    }
    
    // MARK: - Task Management Utility Methods
    /// Utility methods for accessing, modifying, and managing tasks
    
    /// Retrieves a task at a specific index in the tasks array
    /// - Parameter index: The index of the task to retrieve
    /// - Returns: The task at the specified index
    func taskAtIndex(index: Int) -> NTask {
        // This method is no longer safe with predicate-based fetching
        // as the index wouldn't be consistent across different fetch calls
        // Keeping for backward compatibility, but this should be replaced with ID-based lookup
        let allTasks = fetchTasks(predicate: nil)
        guard index < allTasks.count else {
            fatalError("Index out of bounds in taskAtIndex")
        }
        return allTasks[index]
    }
    
    /// Removes a task at a specific index from the tasks array and deletes it from Core Data
    /// - Parameter index: The index of the task to remove
    func removeTaskAtIndex(index: Int) {
        // Get the task using the updated taskAtIndex method
        let task = taskAtIndex(index: index)
        context.delete(task)
        // No longer need to remove from in-memory array
        // tasks.remove(at: index)
        saveContext()
    }
    
    /// Toggle a task's completion status and update dateCompleted
    func toggleTaskComplete(task: NTask) {
        task.isComplete.toggle()
        if task.isComplete {
            task.dateCompleted = Date.today() as NSDate
        } else {
            task.dateCompleted = nil
        }
        saveContext()
    }

    /// Reschedule a task's dueDate to a new date
    func reschedule(task: NTask, to newDate: Date) {
        task.dueDate = newDate as NSDate
        saveContext()
    }
    
    /// Saves the current state of the managed object context to persist changes to Core Data
    /// This method should be called after any changes to tasks to ensure they are saved to the database
    func saveContext() {
        print("💾 TaskManager: saveContext() called - about to save to Core Data...")
        do {
            try context.save()
            print("✅ TaskManager: Core Data save SUCCESSFUL at \(Date()) – Total tasks: \(getAllTasks.count)")
            print("✅ TaskManager: Context has changes: \(context.hasChanges)")
        } catch let error as NSError {
            print("❌ TaskManager: Core Data save FAILED! Error: \(error), UserInfo: \(error.userInfo)")
        }
    }
    
    /// Fixes missing or inconsistent task data by applying default values
    /// Specifically, ensures all tasks have a project assigned (defaults to "inbox")
    /// This method is called during app initialization to maintain data integrity
    func fixMissingTasksDataWithDefaults() {
        // Get all tasks with no predicate filtering
        let allTasks = fetchTasks(predicate: nil)
        
        //FIX inbox as a default added project in projects
        
        //FIX default project to 'inbox'
        for each in allTasks {
            if each.project?.isEmpty ?? true {
                print("**** ERROR FORCE PROJECT **** \(each.name) --- to --- inbox")
                
                each.project = "inbox"
                saveContext()
            }
        }
    }
    
    /// Fetches all tasks from Core Data and updates the tasks array
    /// This method is called by various other methods to ensure they are working with the latest data
    /// Note: This method is kept for backward compatibility. New code should use fetchTasks(predicate:, sortDescriptors:)
    // MARK: - Legacy Method
    /// This method is kept for backward compatibility
    /// It populates the tasks array with all tasks - in new code, use direct predicate-based fetching instead
    func fetchTasks() {
        tasks = fetchTasks(predicate: nil, sortDescriptors: nil)
    }
    
    /// Fetches tasks from Core Data based on the provided predicate and sort descriptors
    /// - Parameters:
    ///   - predicate: NSPredicate to filter tasks (optional)
    ///   - sortDescriptors: Array of NSSortDescriptor to sort results (optional)
    /// - Returns: Array of NTask objects matching the predicate
    private func fetchTasks(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]? = nil) -> [NTask] {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ TaskManager fetch error: \(error)")
            return []
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
