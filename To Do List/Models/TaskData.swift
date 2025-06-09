import Foundation
import CoreData

/// A plain Swift struct representing a Task
/// This model is meant to be used by the presentation layer, separating the Core Data implementation details
struct TaskData {
    let id: NSManagedObjectID?
    let name: String
    let details: String?
    let type: TaskType
    let priority: TaskPriority
    let dueDate: Date
    let project: String
    let isComplete: Bool
    let dateAdded: Date
    let dateCompleted: Date?
    
    /// Creates a TaskData from an NTask managed object
    /// - Parameter managedObject: The Core Data managed object to convert
    init(managedObject: NTask) {
        self.id = managedObject.objectID
        self.name = managedObject.name
        self.details = managedObject.taskDetails
        self.type = TaskType(rawValue: managedObject.taskType) ?? .morning
        self.priority = TaskPriority(rawValue: managedObject.taskPriority) ?? .medium
        self.dueDate = managedObject.dueDate as Date? ?? Date()
        self.project = managedObject.project ?? "Inbox"
        self.isComplete = managedObject.isComplete
        self.dateAdded = managedObject.dateAdded as Date? ?? Date()
        self.dateCompleted = managedObject.dateCompleted as Date?
    }
    
    /// Creates a new TaskData instance with provided values
    /// - Parameters values for the task properties
    init(id: NSManagedObjectID? = nil, 
         name: String,
         details: String? = nil,
         type: TaskType,
         priority: TaskPriority,
         dueDate: Date,
         project: String = "Inbox",
         isComplete: Bool = false,
         dateAdded: Date = Date(),
         dateCompleted: Date? = nil) {
        self.id = id
        self.name = name
        self.details = details
        self.type = type
        self.priority = priority
        self.dueDate = dueDate
        self.project = project
        self.isComplete = isComplete
        self.dateAdded = dateAdded
        self.dateCompleted = dateCompleted
    }
}
