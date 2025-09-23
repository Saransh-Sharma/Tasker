# Data Presentation Abstraction

<cite>
**Referenced Files in This Document**   
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift)
- [NTask+CoreDataProperties.swift](file://To%20Do%20List/NTask+CoreDataProperties.swift)
- [NTask+Extensions.swift](file://To%20Do%20List/NTask+Extensions.swift)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift)
- [README.md](file://README.md)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [TaskData Structure and Core Data Decoupling](#taskdata-structure-and-core-data-decoupling)
3. [Transformation Process from NTask to TaskData](#transformation-process-from-ntask-to-taskdata)
4. [Type-Safe Enums: TaskPriority and TaskType](#type-safe-enums-taskpriority-and-tasktype)
5. [Consumption of TaskData in View Controllers](#consumption-of-taskdata-in-view-controllers)
6. [Immutability, Performance, and Synchronization](#immutability-performance-and-synchronization)
7. [Architecture Diagram](#architecture-diagram)

## Introduction
The `TaskData` struct serves as a presentation layer abstraction over Core Data entities in the Tasker application. This document details how `TaskData` decouples the user interface from Core Data's managed object context, enabling safer threading, improved testability, and cleaner separation of concerns. The analysis covers the transformation process from the `NTask` Core Data entity to `TaskData`, the use of type-safe enums, and how view controllers consume these presentation models.

**Section sources**
- [README.md](file://README.md#L524-L571)

## TaskData Structure and Core Data Decoupling

The `TaskData` struct is a plain Swift value type that represents task information for the presentation layer, completely separated from Core Data's `NSManagedObject` system. This architectural decision provides several key benefits:

- **Thread Safety**: Unlike `NSManagedObject` instances which are tied to a specific `NSManagedObjectContext` and are not thread-safe, `TaskData` instances can be freely passed between threads and queues.
- **Testability**: As a simple struct without dependencies on Core Data, `TaskData` can be easily instantiated in unit tests without requiring a full Core Data stack.
- **Immutability**: The struct's properties are defined with `let`, making instances immutable and preventing unintended state changes.

```swift
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
}
```

By using `TaskData` instead of `NTask` in the UI layer, view controllers are insulated from Core Data's threading requirements and context management, reducing complexity and potential bugs.

**Section sources**
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)

## Transformation Process from NTask to TaskData

The transformation from `NTask` (Core Data entity) to `TaskData` (presentation model) occurs through a dedicated initializer that handles type conversion and data mapping. This process ensures data integrity while providing a clean interface for the presentation layer.

### Initialization from Core Data
When converting from an `NTask` managed object, the `TaskData` initializer performs several critical operations:

- **Type Conversion**: Converts Core Data's `Int32` attributes to Swift enums (`TaskType` and `TaskPriority`)
- **Null Safety**: Provides default values for optional attributes (e.g., "Untitled Task" for missing names)
- **Date Conversion**: Transforms `NSDate` objects to Swift `Date` type
- **Project Fallback**: Defaults to "Inbox" for tasks without an assigned project

```swift
init(managedObject: NTask) {
    self.id = managedObject.objectID
    self.name = managedObject.name ?? "Untitled Task"
    self.details = managedObject.taskDetails
    self.type = TaskType(rawValue: managedObject.taskType) ?? .morning
    self.priority = TaskPriority(rawValue: managedObject.taskPriority) ?? .medium
    self.dueDate = managedObject.dueDate as Date? ?? Date()
    self.project = managedObject.project ?? "Inbox"
    self.isComplete = managedObject.isComplete
    self.dateAdded = managedObject.dateAdded as Date? ?? Date()
    self.dateCompleted = managedObject.dateCompleted as Date?
}
```

### Data Flow Architecture
The repository pattern facilitates this transformation, with `CoreDataTaskRepository` handling the conversion when fetching data:

```mermaid
flowchart LR
A[Core Data] --> |NTask objects| B[CoreDataTaskRepository]
B --> |map to| C[TaskData instances]
C --> |passed to| D[View Controllers]
D --> E[UI Presentation]
```

**Diagram sources**
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L455)

**Section sources**
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L455)

## Type-Safe Enums: TaskPriority and TaskType

The application uses type-safe Swift enums to represent task attributes, providing compile-time safety and improved code readability compared to raw integer values.

### TaskPriority Enum
The `TaskPriority` enum defines four priority levels with corresponding raw values that map to the Core Data storage:

```swift
enum TaskPriority: Int32, CaseIterable {
    case highest = 1    // P0: 7 points
    case high = 2       // P1: 4 points
    case medium = 3     // P2: 3 points (default)
    case low = 4        // P3: 2 points
}
```

### TaskType Enum
The `TaskType` enum categorizes tasks into different types for organizational purposes:

```swift
enum TaskType: Int32, CaseIterable {
    case morning = 1    // Morning tasks
    case evening = 2    // Evening tasks
    case upcoming = 3   // Future-dated tasks
    case inbox = 4      // Uncategorized tasks
}
```

### NTask Extensions for Type Safety
The `NTask+Extensions.swift` file provides computed properties that bridge the gap between Core Data's raw integer storage and the type-safe enums:

```swift
extension NTask {
    var type: TaskType {
        get { TaskType(rawValue: self.taskType) ?? .morning }
        set { self.taskType = newValue.rawValue }
    }
    
    var priority: TaskPriority {
        get { TaskPriority(rawValue: self.taskPriority) ?? .medium }
        set { self.taskPriority = newValue.rawValue }
    }
}
```

These extensions ensure that whenever `taskType` or `taskPriority` is accessed on an `NTask` instance, it's automatically converted to the appropriate enum type, preventing invalid values and providing compile-time type checking.

**Section sources**
- [README.md](file://README.md#L436-L474)
- [NTask+Extensions.swift](file://To%20Do%20List/NTask+Extensions.swift#L1-L76)

## Consumption of TaskData in View Controllers

View controllers consume `TaskData` instances through the repository pattern, which abstracts away Core Data implementation details and provides a clean data access interface.

### Repository Pattern Implementation
The `CoreDataTaskRepository` class provides methods that return `TaskData` arrays, completely hiding Core Data operations from the presentation layer:

```swift
func fetchTasks(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, completion: @escaping ([TaskData]) -> Void) {
    viewContext.perform {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        do {
            let results = try self.viewContext.fetch(request)
            let data = results.map { TaskData(managedObject: $0) }
            DispatchQueue.main.async { completion(data) }
        } catch {
            print("❌ Task fetch error: \(error)")
            DispatchQueue.main.async { completion([]) }
        }
    }
}
}
```

### View Controller Integration
View controllers interact with `TaskData` instances without any knowledge of Core Data:

```swift
// Example usage in a view controller
func setupTaskData(for date: Date) {
    taskRepository.getMorningTasks(for: date) { tasks in
        DispatchQueue.main.async {
            self.tasks = tasks
            self.tableView.reloadData()
        }
    }
}
```

The `TaskData` instances are used directly in UI components, such as configuring table view cells:

```swift
// In UI configuration
func configureCell(cell: TaskCell, with task: TaskData) {
    cell.titleLabel.text = task.name
    cell.detailsLabel.text = task.details
    cell.priorityIndicator.backgroundColor = task.priority == .high ? .systemRed : .systemGray
    cell.dateLabel.text = dateFormatter.string(from: task.dueDate)
}
```

This approach allows view controllers to focus on presentation logic without managing Core Data contexts or threading concerns.

**Section sources**
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L455)
- [README.md](file://README.md#L1170-L1207)

## Immutability, Performance, and Synchronization

### Immutability Benefits
The immutable nature of `TaskData` provides several advantages:

- **Predictable State**: Once created, a `TaskData` instance cannot be modified, preventing race conditions in multi-threaded environments.
- **Simplified Debugging**: Immutable data structures make it easier to trace the flow of data through the application.
- **Functional Programming Benefits**: Encourages a functional approach where transformations create new instances rather than modifying existing ones.

### Performance Implications
While the transformation process adds a small overhead, the benefits outweigh the costs:

- **Memory Efficiency**: Value types are generally more memory-efficient than managed objects.
- **Reduced Context Pressure**: By converting to `TaskData` early, the main context is freed from holding managed objects for UI presentation.
- **Optimized UI Updates**: Immutable data enables more efficient diffing algorithms for table and collection views.

### Synchronization Challenges
The separation between `TaskData` and `NTask` introduces synchronization considerations:

- **One-Way Transformation**: `TaskData` is read-only; changes must be propagated back through repository methods.
- **Context Management**: The repository handles context switching between background (for saves) and main (for UI updates) queues.
- **Change Propagation**: When a task is modified, the repository saves the changes to Core Data and notifies observers through `NotificationCenter`.

The `CoreDataTaskRepository` handles synchronization by using separate contexts for background operations and UI presentation, ensuring that long-running operations don't block the main thread while maintaining data consistency.

**Section sources**
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L455)

## Architecture Diagram

```mermaid
erDiagram
PROJECTS ||--o{ NTASK : "contains"
PROJECTS {
string projectName PK
string projecDescription
}
NTASK {
string name
bool isComplete
date dueDate
string taskDetails
int taskPriority
int taskType
string project FK
date alertReminderTime
date dateAdded
bool isEveningTask
date dateCompleted
}
classDiagram
class TaskData {
+id: NSManagedObjectID?
+name: String
+details: String?
+type: TaskType
+priority: TaskPriority
+dueDate: Date
+project: String
+isComplete: Bool
+dateAdded: Date
+dateCompleted: Date?
+init(managedObject: NTask)
+init(id: NSManagedObjectID?, name: String, details: String?, type: TaskType, priority: TaskPriority, dueDate: Date, project: String, isComplete: Bool, dateAdded: Date, dateCompleted: Date?)
}
class NTask {
+name: String?
+isComplete: Bool
+dueDate: NSDate?
+taskDetails: String?
+taskPriority: Int32
+taskType: Int32
+project: String?
+alertReminderTime: NSDate?
+dateAdded: NSDate?
+isEveningTask: Bool
+dateCompleted: NSDate?
+type: TaskType
+priority: TaskPriority
+isMorningTask: Bool
+isUpcomingTask: Bool
+isHighPriority: Bool
+isMediumPriority: Bool
+isLowPriority: Bool
+updateEveningTaskStatus(_:) void
}
class CoreDataTaskRepository {
-viewContext: NSManagedObjectContext
-backgroundContext: NSManagedObjectContext
-defaultProject: String
+fetchTasks(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, completion: ([TaskData]) -> Void) void
+fetchTask(by: NSManagedObjectID, completion: (Result<NTask, Error>) -> Void) void
+addTask(data: TaskData, completion: ((Result<NTask, Error>) -> Void)?) void
+toggleComplete(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?) void
+deleteTask(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?) void
+reschedule(taskID: NSManagedObjectID, to: Date, completion: ((Result<Void, Error>) -> Void)?) void
+getMorningTasks(for: Date, completion: ([TaskData]) -> Void) void
+getEveningTasks(for: Date, completion: ([TaskData]) -> Void) void
+getUpcomingTasks(completion: ([TaskData]) -> Void) void
+getTasksForInbox(date: Date, completion: ([TaskData]) -> Void) void
+getTasksForProject(projectName: String, date: Date, completion: ([TaskData]) -> Void) void
+getTasksForProjectOpen(projectName: String, date: Date, completion: ([TaskData]) -> Void) void
+getTasksForAllCustomProjectsOpen(date: Date, completion: ([TaskData]) -> Void) void
+updateTask(taskID: NSManagedObjectID, data: TaskData, completion: ((Result<Void, Error>) -> Void)?) void
+saveTask(taskID: NSManagedObjectID, name: String, details: String?, type: TaskType, priority: TaskPriority, dueDate: Date, project: String, completion: ((Result<Void, Error>) -> Void)?) void
}
class TaskType {
+morning: TaskType
+evening: TaskType
+upcoming: TaskType
+inbox: TaskType
}
class TaskPriority {
+highest: TaskPriority
+high: TaskPriority
+medium: TaskPriority
+low: TaskPriority
}
TaskData --> NTask : "transforms from"
CoreDataTaskRepository --> NTask : "manages"
CoreDataTaskRepository --> TaskData : "creates and consumes"
NTask --> TaskType : "uses rawValue"
NTask --> TaskPriority : "uses rawValue"
```

**Diagram sources**
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)
- [NTask+CoreDataProperties.swift](file://To%20Do%20List/NTask+CoreDataProperties.swift#L1-L54)
- [NTask+Extensions.swift](file://To%20Do%20List/NTask+Extensions.swift#L1-L76)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L455)
- [README.md](file://README.md#L887-L924)