# Repository Pattern Implementation

<cite>
**Referenced Files in This Document**   
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L117)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)
- [NTask+CoreDataProperties.swift](file://To%20Do%20List/NTask+CoreDataProperties.swift#L1-L53)
- [NTask+CoreDataClass.swift](file://To%20Do%20List/NTask+CoreDataClass.swift#L1-L16)
- [README.md](file://README.md#L572-L985)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)

## Introduction
The Tasker application implements a clean, testable architecture using the Repository Pattern to abstract data access operations. This document details how the `TaskRepository` protocol defines a clear interface for task data operations and how `CoreDataTaskRepository` provides a concrete implementation using Core Data. The design enables dependency injection, improves testability, and separates concerns between data access and business logic. The repository handles all CRUD operations, complex queries, and threading considerations while presenting a clean API to view controllers and services.

## Project Structure
The project follows a layered architecture with clear separation of concerns. The repository implementation resides in dedicated directories, separating data access logic from UI and business logic components.

```mermaid
graph TB
subgraph "Data Layer"
Repository[Repositories/]
Model[Models/]
CoreData[Core Data Entities]
end
subgraph "Business Logic"
Services[Services/]
UseCases[Use Cases]
end
subgraph "Presentation"
ViewControllers[View Controllers]
Views[SwiftUI Views]
ViewModels[ViewModels]
end
Repository --> CoreData
Services --> Repository
ViewModels --> Services
ViewControllers --> ViewModels
Views --> ViewModels
```

**Diagram sources**
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L117)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)

**Section sources**
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L117)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)

## Core Components
The repository pattern implementation consists of three key components: the `TaskRepository` protocol defining the interface, the `CoreDataTaskRepository` class providing the concrete implementation, and the `TaskData` struct serving as the data transfer object between layers. This separation ensures that the presentation layer remains decoupled from Core Data implementation details.

**Section sources**
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L117)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)

## Architecture Overview
The repository pattern acts as an intermediary between the application's business logic and the data storage layer. It encapsulates the complexity of data access, providing a simplified interface to the rest of the application. This architecture enables easy testing through mocking and allows for future data source changes without affecting the rest of the codebase.

```mermaid
graph LR
A[View Controller] --> B[TaskRepository Protocol]
B --> C[CoreDataTaskRepository]
C --> D[Core Data Stack]
D --> E[SQLite Store]
F[Unit Tests] --> B
G[Mock Repository] --> B
style A fill:#f9f,stroke:#333
style D fill:#f96,stroke:#333
style E fill:#bbf,stroke:#333
style F fill:#6f9,stroke:#333
```

**Diagram sources**
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L117)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)

## Detailed Component Analysis

### TaskRepository Protocol Analysis
The `TaskRepository` protocol defines a comprehensive interface for all task data operations, enabling dependency injection and making the codebase highly testable. By using protocol-oriented programming, the application can easily swap implementations for testing or future enhancements.

```mermaid
classDiagram
class TaskRepository {
<<protocol>>
+fetchTasks(predicate : NSPredicate?, sortDescriptors : [NSSortDescriptor]?, completion : ([TaskData]) -> Void) void
+fetchTask(by : NSManagedObjectID, completion : (Result<NTask, Error>) -> Void) void
+addTask(data : TaskData, completion : (Result<NTask, Error>) -> Void)? void
+toggleComplete(taskID : NSManagedObjectID, completion : (Result<Void, Error>) -> Void)? void
+deleteTask(taskID : NSManagedObjectID, completion : (Result<Void, Error>) -> Void)? void
+reschedule(taskID : NSManagedObjectID, to : Date, completion : (Result<Void, Error>) -> Void)? void
+getMorningTasks(for : Date, completion : ([TaskData]) -> Void) void
+getEveningTasks(for : Date, completion : ([TaskData]) -> Void) void
+getUpcomingTasks(completion : ([TaskData]) -> Void) void
+getTasksForInbox(date : Date, completion : ([TaskData]) -> Void) void
+getTasksForProject(projectName : String, date : Date, completion : ([TaskData]) -> Void) void
+getTasksForProjectOpen(projectName : String, date : Date, completion : ([TaskData]) -> Void) void
+getTasksForAllCustomProjectsOpen(date : Date, completion : ([TaskData]) -> Void) void
+updateTask(taskID : NSManagedObjectID, data : TaskData, completion : (Result<Void, Error>) -> Void)? void
+saveTask(taskID : NSManagedObjectID, name : String, details : String?, type : TaskType, priority : TaskPriority, dueDate : Date, project : String, completion : (Result<Void, Error>) -> Void)? void
}
class CoreDataTaskRepository {
-viewContext : NSManagedObjectContext
-backgroundContext : NSManagedObjectContext
-defaultProject : String
+init(container : NSPersistentContainer, defaultProject : String) void
}
TaskRepository <|.. CoreDataTaskRepository : implements
```

**Diagram sources**
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L117)

**Section sources**
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L117)

### CoreDataTaskRepository Implementation Analysis
The `CoreDataTaskRepository` class provides a concrete implementation of the `TaskRepository` protocol using Core Data. It handles all threading considerations by using separate managed object contexts for the main thread (viewContext) and background operations (backgroundContext), ensuring optimal performance and thread safety.

```mermaid
sequenceDiagram
participant VC as View Controller
participant Repo as CoreDataTaskRepository
participant BG as backgroundContext
participant UI as viewContext
participant Main as Main Thread
VC->>Repo : addTask(data : TaskData)
Repo->>BG : perform block
BG->>BG : Create NTask managed object
BG->>BG : Set properties from TaskData
BG->>BG : save()
BG-->>Repo : Success/Failure
Repo->>Main : DispatchQueue.main.async
Main->>VC : completion(result)
```

**Diagram sources**
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)

**Section sources**
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)

### TaskData Model Analysis
The `TaskData` struct serves as a plain Swift data transfer object that decouples the presentation layer from Core Data implementation details. It provides two initialization methods: one for converting from a Core Data managed object and another for creating new instances with specified properties.

```mermaid
classDiagram
class TaskData {
+id : NSManagedObjectID?
+name : String
+details : String?
+type : TaskType
+priority : TaskPriority
+dueDate : Date
+project : String
+isComplete : Bool
+dateAdded : Date
+dateCompleted : Date?
+init(managedObject : NTask) void
+init(id : NSManagedObjectID?, name : String, details : String?, type : TaskType, priority : TaskPriority, dueDate : Date, project : String, isComplete : Bool, dateAdded : Date, dateCompleted : Date?) void
}
class NTask {
+name : String?
+isComplete : Bool
+dueDate : NSDate?
+taskDetails : String?
+taskPriority : Int32
+taskType : Int32
+project : String?
+alertReminderTime : NSDate?
+dateAdded : NSDate?
+isEveningTask : Bool
+dateCompleted : NSDate?
}
TaskData --> NTask : converts to/from
```

**Diagram sources**
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)
- [NTask+CoreDataProperties.swift](file://To%20Do%20List/NTask+CoreDataProperties.swift#L1-L53)

**Section sources**
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L1-L56)
- [NTask+CoreDataProperties.swift](file://To%20Do%20List/NTask+CoreDataProperties.swift#L1-L53)

## Dependency Analysis
The repository pattern implementation shows a clear dependency hierarchy, with higher-level components depending on abstractions rather than concrete implementations. This design enables easy testing and future extensibility.

```mermaid
graph TD
A[View Controllers] --> B[TaskRepository Protocol]
C[ViewModels] --> B
D[Unit Tests] --> B
B --> E[CoreDataTaskRepository]
E --> F[NSPersistentContainer]
E --> G[NSManagedObjectContext]
H[MockTaskRepository] --> B
style A fill:#f9f,stroke:#333
style C fill:#f9f,stroke:#333
style D fill:#6f9,stroke:#333
style H fill:#6f9,stroke:#333
style F fill:#f96,stroke:#333
style G fill:#f96,stroke:#333
```

**Diagram sources**
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L117)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)

**Section sources**
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L117)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)

## Performance Considerations
The repository implementation addresses Core Data's threading requirements through a dual-context approach. The `viewContext` is configured with `automaticallyMergesChangesFromParent = true`, allowing it to automatically receive changes saved on the background context. The `backgroundContext` uses a `NSMergeByPropertyObjectTrumpMergePolicy` to resolve merge conflicts appropriately.

For read operations, the repository uses the `viewContext` to ensure the UI always displays the most recent data. Write operations (create, update, delete) are performed on the `backgroundContext` to prevent blocking the main thread. All completion handlers are dispatched to the main queue using `DispatchQueue.main.async` to ensure UI updates occur on the correct thread.

The implementation also includes comprehensive error handling with descriptive error messages logged to the console, aiding in debugging and monitoring.

## Troubleshooting Guide
Common issues with the repository implementation typically involve threading conflicts or data consistency problems:

1. **Threading Violations**: Always perform Core Data operations within the appropriate context's perform block. Never access managed objects across threads directly.

2. **Context Merge Issues**: Ensure the `viewContext` has `automaticallyMergesChangesFromParent = true` set, as implemented in the `CoreDataTaskRepository` initialization.

3. **Missing Object Errors**: When fetching objects by `NSManagedObjectID`, always handle the case where the object might not exist (404 error), as shown in the `fetchTask(by:completion:)` method.

4. **Notification Handling**: The repository posts a `TaskCompletionChanged` notification when tasks are completed, which should be observed by components that need to update their state (e.g., analytics services).

5. **Memory Management**: The use of completion closures with `[weak self]` references is recommended when capturing the repository to prevent retain cycles, though this is not shown in the current implementation.

**Section sources**
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L454)
- [README.md](file://README.md#L925-L976)

## Conclusion
The repository pattern implementation in Tasker provides a robust, maintainable architecture for data access. By defining a clear protocol interface and providing a well-structured concrete implementation, the codebase achieves separation of concerns, improved testability, and easier maintenance. The dual-context approach properly handles Core Data's threading requirements, while the `TaskData` struct effectively decouples the presentation layer from persistence details. This implementation serves as a strong foundation for future enhancements and demonstrates best practices in iOS application architecture.