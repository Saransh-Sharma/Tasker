import Foundation
import CoreData

/// Protocol defining the contract for any task repository implementation
/// This allows for dependency injection and makes the code testable by providing
/// a way to mock the repository in tests
protocol TaskRepository {
    /// Fetches tasks based on the provided predicate and sort descriptors
    /// - Parameters:
    ///   - predicate: Optional predicate to filter the tasks
    ///   - sortDescriptors: Optional sort descriptors to sort the tasks
    ///   - completion: Completion handler that receives the fetched tasks
    func fetchTasks(predicate: NSPredicate?, 
                   sortDescriptors: [NSSortDescriptor]?, 
                   completion: @escaping ([TaskData]) -> Void)
    
    /// Adds a new task to the repository
    /// - Parameters:
    ///   - data: The task data to add
    ///   - completion: Optional completion handler that receives the result
    func addTask(data: TaskData, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Toggles the completion status of a task
    /// - Parameters:
    ///   - taskID: The ID of the task to toggle
    ///   - completion: Optional completion handler that receives the result
    func toggleComplete(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Deletes a task from the repository
    /// - Parameters:
    ///   - taskID: The ID of the task to delete
    ///   - completion: Optional completion handler that receives the result
    func deleteTask(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Reschedules a task to a new date
    /// - Parameters:
    ///   - taskID: The ID of the task to reschedule
    ///   - newDate: The new date for the task
    ///   - completion: Optional completion handler that receives the result
    func reschedule(taskID: NSManagedObjectID, to newDate: Date, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Fetches morning tasks for a specific date
    /// - Parameters:
    ///   - date: The date to filter tasks by
    ///   - completion: Completion handler that receives the fetched tasks
    func getMorningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void)
    
    /// Fetches evening tasks for a specific date
    /// - Parameters:
    ///   - date: The date to filter tasks by
    ///   - completion: Completion handler that receives the fetched tasks
    func getEveningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void)
    
    /// Fetches upcoming tasks
    /// - Parameter completion: Completion handler that receives the fetched tasks
    func getUpcomingTasks(completion: @escaping ([TaskData]) -> Void)
    
    /// Fetches tasks for the inbox project for a specific date
    /// - Parameters:
    ///   - date: The date to filter tasks by
    ///   - completion: Completion handler that receives the fetched tasks
    func getTasksForInbox(date: Date, completion: @escaping ([TaskData]) -> Void)
    
    /// Fetches tasks for a specific project and date
    /// - Parameters:
    ///   - projectName: The name of the project
    ///   - date: The date to filter tasks by
    ///   - completion: Completion handler that receives the fetched tasks
    func getTasksForProject(projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void)
    
    /// Fetches open tasks for a specific project and date
    /// - Parameters:
    ///   - projectName: The name of the project
    ///   - date: The date to filter tasks by
    ///   - completion: Completion handler that receives the fetched tasks
    func getTasksForProjectOpen(projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void)
    
    /// Fetches open tasks for all custom projects for a specific date
    /// - Parameters:
    ///   - date: The date to filter tasks by
    ///   - completion: Completion handler that receives the fetched tasks
    func getTasksForAllCustomProjectsOpen(date: Date, completion: @escaping ([TaskData]) -> Void)
    
    /// Updates an existing task with new data
    /// This method allows comprehensive updates to any and all properties of a task
    /// - Parameters:
    ///   - taskID: The ID of the task to update
    ///   - data: The updated task data containing all new property values
    ///   - completion: Optional completion handler that receives the result
    func updateTask(taskID: NSManagedObjectID, data: TaskData, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Saves changes to an existing task
    /// This method is specifically designed for the task details page to persist user changes
    /// - Parameters:
    ///   - taskID: The ID of the task to save
    ///   - name: Updated task name
    ///   - details: Updated task details
    ///   - type: Updated task type
    ///   - priority: Updated task priority
    ///   - dueDate: Updated due date
    ///   - project: Updated project assignment
    ///   - completion: Optional completion handler that receives the result
    func saveTask(taskID: NSManagedObjectID, 
                 name: String,
                 details: String?,
                 type: TaskType,
                 priority: TaskPriority,
                 dueDate: Date,
                 project: String,
                 completion: ((Result<Void, Error>) -> Void)?)
}
