import Foundation
import CoreData

/// Concrete implementation of TaskRepository using Core Data
final class CoreDataTaskRepository: TaskRepository {
    // MARK: - Properties
    
    /// Context used for fetching data and displaying in the UI
    private let viewContext: NSManagedObjectContext
    
    /// Context used for background operations like saving and updating
    private let backgroundContext: NSManagedObjectContext
    
    /// Default project name, usually "Inbox"
    private let defaultProject: String
    
    // MARK: - Initialization
    
    /// Initializes a new repository with the provided persistent container
    /// - Parameters:
    ///   - container: The Core Data persistent container to use
    ///   - defaultProject: The default project name, defaults to "Inbox"
    init(container: NSPersistentContainer, defaultProject: String = "Inbox") {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.defaultProject = defaultProject
        
        // Configure contexts
        self.viewContext.automaticallyMergesChangesFromParent = true
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Core Methods
    
    func fetchTasks(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, completion: @escaping ([TaskData]) -> Void) {
        backgroundContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors
            
            do {
                let results = try self.backgroundContext.fetch(request)
                let data = results.map { TaskData(managedObject: $0) }
                DispatchQueue.main.async { completion(data) }
            } catch {
                print("❌ Task fetch error: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
    
    func addTask(data: TaskData, completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            let managed = NTask(context: self.backgroundContext)
            managed.name = data.name
            managed.taskDetails = data.details
            managed.taskType = data.type.rawValue
            managed.taskPriority = data.priority.rawValue
            managed.dueDate = data.dueDate as NSDate
            managed.project = data.project
            managed.isComplete = data.isComplete
            managed.dateAdded = data.dateAdded as NSDate
            managed.dateCompleted = data.dateCompleted as NSDate?
            
            do {
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                print("❌ Task add error: \(error)")
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
    
    func toggleComplete(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                guard let task = try self.backgroundContext.existingObject(with: taskID) as? NTask else {
                    throw NSError(domain: "TaskRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                }
                
                task.isComplete.toggle()
                task.dateCompleted = task.isComplete ? Date() as NSDate : nil
                
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                print("❌ Task toggle complete error: \(error)")
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
    
    func deleteTask(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                let toDelete = try self.backgroundContext.existingObject(with: taskID)
                self.backgroundContext.delete(toDelete)
                
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                print("❌ Task delete error: \(error)")
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
    
    func reschedule(taskID: NSManagedObjectID, to newDate: Date, completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                guard let task = try self.backgroundContext.existingObject(with: taskID) as? NTask else {
                    throw NSError(domain: "TaskRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                }
                
                task.dueDate = newDate as NSDate
                
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                print("❌ Task reschedule error: \(error)")
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
    
    // MARK: - Task Type Specific Methods
    
    func getMorningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(
            format: "taskType == %d AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            TaskType.morning.rawValue,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    func getEveningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(
            format: "taskType == %d AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            TaskType.evening.rawValue,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    func getUpcomingTasks(completion: @escaping ([TaskData]) -> Void) {
        let predicate = NSPredicate(format: "taskType == %d", TaskType.upcoming.rawValue)
        
        fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    // MARK: - Project-Based Methods
    
    func getTasksForInbox(date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Tasks due today and not complete
        let dueTodayPredicate = NSPredicate(
            format: "project ==[c] %@ AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            defaultProject,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Tasks completed today
        let completedTodayPredicate = NSPredicate(
            format: "project ==[c] %@ AND dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
            defaultProject,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // For today's date, also include overdue tasks
        var finalPredicate: NSPredicate
        if Calendar.current.isDateInToday(date) {
            let overduePredicate = NSPredicate(
                format: "project ==[c] %@ AND dueDate < %@ AND isComplete == NO",
                defaultProject,
                startOfDay as NSDate
            )
            
            // Combine all predicates with OR
            let combinedPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate, overduePredicate]
            )
            finalPredicate = combinedPredicate
        } else {
            // For other dates, just combine due and completed
            finalPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate]
            )
        }
        
        fetchTasks(
            predicate: finalPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    func getTasksForProject(projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Tasks due today and not complete
        let dueTodayPredicate = NSPredicate(
            format: "project ==[c] %@ AND dueDate >= %@ AND dueDate < %@",
            projectName,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Tasks completed today
        let completedTodayPredicate = NSPredicate(
            format: "project ==[c] %@ AND dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
            projectName,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // For today's date, also include overdue tasks
        var finalPredicate: NSPredicate
        if Calendar.current.isDateInToday(date) {
            let overduePredicate = NSPredicate(
                format: "project ==[c] %@ AND dueDate < %@ AND isComplete == NO",
                projectName,
                startOfDay as NSDate
            )
            
            // Combine all predicates with OR
            let combinedPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate, overduePredicate]
            )
            finalPredicate = combinedPredicate
        } else {
            // For other dates, just combine due and completed
            finalPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate]
            )
        }
        
        fetchTasks(
            predicate: finalPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    func getTasksForProjectOpen(projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let dueTodayPredicate = NSPredicate(
            format: "project ==[c] %@ AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            projectName,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // For today's date, also include overdue tasks
        var finalPredicate: NSPredicate
        if Calendar.current.isDateInToday(date) {
            let overduePredicate = NSPredicate(
                format: "project ==[c] %@ AND dueDate < %@ AND isComplete == NO",
                projectName,
                startOfDay as NSDate
            )
            
            // Combine with OR
            finalPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, overduePredicate]
            )
        } else {
            finalPredicate = dueTodayPredicate
        }
        
        fetchTasks(
            predicate: finalPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    func getTasksForAllCustomProjectsOpen(date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Tasks from custom projects (not the default project)
        let notDefaultProjectPredicate = NSPredicate(
            format: "project !=[c] %@",
            defaultProject
        )
        
        // Due today and not complete
        let dueTodayPredicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        // Combine with AND
        var combinedPredicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [notDefaultProjectPredicate, dueTodayPredicate]
        )
        
        // For today's date, also include overdue tasks
        if Calendar.current.isDateInToday(date) {
            let overduePredicate = NSPredicate(
                format: "dueDate < %@ AND isComplete == NO",
                startOfDay as NSDate
            )
            
            let overdueCustomPredicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [notDefaultProjectPredicate, overduePredicate]
            )
            
            // Combine with OR
            combinedPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [combinedPredicate, overdueCustomPredicate]
            )
        }
        
        fetchTasks(
            predicate: combinedPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
}
