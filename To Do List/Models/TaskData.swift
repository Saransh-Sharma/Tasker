import Foundation
import CoreData

// Simple, self-contained TaskPriority enum to eliminate all type issues
enum TaskDataPriority: Int32, CaseIterable {
    case highest = 1
    case high = 2
    case medium = 3
    case low = 4
    
    var displayName: String {
        switch self {
        case .highest: return "Highest"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

/// A plain Swift struct representing a Task
/// This model is meant to be used by the presentation layer, separating the Core Data implementation details
struct TaskData {
    let id: NSManagedObjectID?
    let name: String
    let details: String?
    let type: Int32 // TaskType raw value: 1=morning, 2=evening, 3=upcoming, 4=inbox
    let priorityRawValue: Int32 // Store raw value to avoid enum conversion issues
    let dueDate: Date
    let project: String
    let isComplete: Bool
    let dateAdded: Date
    let dateCompleted: Date?
    
    /// Creates a TaskData from an NTask managed object
    /// - Parameter managedObject: The Core Data managed object to convert
    init(managedObject: NTask) {
        self.id = managedObject.objectID
        self.name = managedObject.name ?? "Untitled Task"
        self.details = managedObject.taskDetails
        self.type = managedObject.taskType // Direct Int32 value
        // Store raw value directly to avoid enum conversion issues
        self.priorityRawValue = managedObject.taskPriority
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
         type: Int32, // TaskType raw value
         priorityRawValue: Int32, // Use raw value instead of enum
         dueDate: Date,
         project: String = "Inbox",
         isComplete: Bool = false,
         dateAdded: Date = Date(),
         dateCompleted: Date? = nil) {
        self.id = id
        self.name = name
        self.details = details
        self.type = type
        self.priorityRawValue = priorityRawValue
        self.dueDate = dueDate
        self.project = project
        self.isComplete = isComplete
        self.dateAdded = dateAdded
        self.dateCompleted = dateCompleted
    }
    
    // MARK: - Computed Properties for Priority Access
    
    /// Priority as TaskDataPriority enum (computed property using self-contained enum)
    var priority: TaskDataPriority {
        switch priorityRawValue {
        case 1: return .highest
        case 2: return .high
        case 3: return .medium
        case 4: return .low
        default: return .medium // Default to medium
        }
    }
    
    /// Priority display text
    var priorityText: String {
        switch priorityRawValue {
        case 1: return "Highest"
        case 2: return "High"
        case 3: return "Medium"
        case 4: return "Low"
        default: return "Medium"
        }
    }
}
