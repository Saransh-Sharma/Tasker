<docs>
# Task Management System

<cite>
**Referenced Files in This Document**   
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift) - *Updated in recent commit*
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift) - *Updated in recent commit*
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift) - *Updated in recent commit*
- [FilterTasksUseCase.swift](file://To Do List/UseCases/Task/FilterTasksUseCase.swift) - *Added in recent commit*
- [SortTasksUseCase.swift](file://To Do List/UseCases/Task/SortTasksUseCase.swift) - *Added in recent commit*
- [SearchTasksUseCase.swift](file://To Do List/UseCases/Task/SearchTasksUseCase.swift) - *Added in recent commit*
- [TaskCollaborationUseCase.swift](file://To Do List/UseCases/Task/TaskCollaborationUseCase.swift) - *Added in recent commit*
- [NTask+CoreDataClass.swift](file://To Do List/NTask+CoreDataClass.swift)
- [NTask+CoreDataProperties.swift](file://To Do List/NTask+CoreDataProperties.swift)
- [NTask+Extensions.swift](file://To Do List/NTask+Extensions.swift)
</cite>

## Update Summary
- Added comprehensive documentation for new use case implementations: filtering, sorting, searching, and collaboration
- Updated architecture overview to reflect the use case layer integration
- Enhanced detailed component analysis with new use case interactions
- Added new sections for use case implementations and their integration with existing components
- Updated dependency analysis to include new use case dependencies
- Added performance considerations for new use case implementations

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Use Case Implementations](#use-case-implementations)
7. [Dependency Analysis](#dependency-analysis)
8. [Performance Considerations](#performance-considerations)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Conclusion](#conclusion)

## Introduction
This document provides a comprehensive analysis of the task management system's Repository pattern implementation, now enhanced with new use case implementations. It focuses on the separation between the `TaskRepository` protocol and its concrete `CoreDataTaskRepository` implementation using Core Data. The system enables dependency injection, promotes testability, and ensures thread-safe data access across the application. Special attention is given to how tasks are queried by type (morning/evening), how completion updates trigger UI refreshes and score recalculations, and the mechanisms in place for maintaining data consistency across contexts. The document has been updated to include new use case implementations for filtering, sorting, searching, and collaboration.

## Project Structure

```mermaid
graph TB
subgraph "Root"
Assets[Assets.xcassets]
Pods[Pods/]
README[README.md]
end
subgraph "To Do List"
AppDelegate[AppDelegate.swift]
SceneDelegate[SceneDelegate.swift]
TintTextField[TintTextField.swift]
subgraph "Repositories"
TaskRepository[TaskRepository.swift]
CoreDataTaskRepository[CoreDataTaskRepository.swift]
end
subgraph "ViewControllers"
HomeVC[HomeViewController.swift]
AddTaskVC[AddTaskViewController.swift]
InboxVC[InboxViewController.swift]
NewProjectVC[NewProjectViewController.swift]
end
subgraph "Models"
NTaskClass[NTask+CoreDataClass.swift]
NTaskProps[NTask+CoreDataProperties.swift]
NTaskExt[NTask+Extensions.swift]
end
subgraph "LLM"
ChatHost[ChatHostViewController.swift]
end
subgraph "UseCases"
FilterTasks[FilterTasksUseCase.swift]
SortTasks[SortTasksUseCase.swift]
SearchTasks[SearchTasksUseCase.swift]
TaskCollaboration[TaskCollaborationUseCase.swift]
end
end
Assets --> HomeVC
TaskRepository --> CoreDataTaskRepository
CoreDataTaskRepository --> NTaskClass
HomeVC --> TaskRepository
HomeVC --> CoreDataTaskRepository
HomeVC --> FilterTasks
HomeVC --> SortTasks
HomeVC --> SearchTasks
HomeVC --> TaskCollaboration
```

**Diagram sources**
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift)
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift)
- [FilterTasksUseCase.swift](file://To Do List/UseCases/Task/FilterTasksUseCase.swift)
- [SortTasksUseCase.swift](file://To Do List/UseCases/Task/SortTasksUseCase.swift)
- [SearchTasksUseCase.swift](file://To Do List/UseCases/Task/SearchTasksUseCase.swift)
- [TaskCollaborationUseCase.swift](file://To Do List/UseCases/Task/TaskCollaborationUseCase.swift)

**Section sources**
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift)

## Core Components

The core components of the task management system revolve around the Repository pattern, which abstracts data access logic behind a protocol. The `TaskRepository` defines a comprehensive contract for all CRUD operations and specialized queries, enabling loose coupling between the UI layer and persistence mechanism. The `CoreDataTaskRepository` provides a concrete implementation using Core Data with proper context management for thread safety. The `HomeViewController` consumes this repository via dependency injection, allowing it to remain agnostic of the underlying data storage details while supporting rich querying capabilities including filtering by `TaskType`, project, and date ranges. The system has been enhanced with new use case implementations for filtering, sorting, searching, and collaboration, which provide advanced functionality while maintaining separation of concerns.

**Section sources**
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift#L1-L117)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift#L1-L455)
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift#L1-L1106)
- [FilterTasksUseCase.swift](file://To Do List/UseCases/Task/FilterTasksUseCase.swift#L1-L530)
- [SortTasksUseCase.swift](file://To Do List/UseCases/Task/SortTasksUseCase.swift#L1-L587)
- [SearchTasksUseCase.swift](file://To Do List/UseCases/Task/SearchTasksUseCase.swift#L1-L601)
- [TaskCollaborationUseCase.swift](file://To Do List/UseCases/Task/TaskCollaborationUseCase.swift#L1-L799)

## Architecture Overview

```mermaid
graph TD
A[HomeViewController] --> |Dependency Injection| B(TaskRepository)
B --> C[CoreDataTaskRepository]
C --> D[viewContext<br/>Main Queue]
C --> E[backgroundContext<br/>Private Queue]
D --> F[(Persistent Store)]
E --> F
A --> G[SwiftUI Chart Card]
A --> H[FSCalendar]
C --> |NotificationCenter| A
G --> |Updates| A
H --> |Date Selection| A
A --> I[FilterTasksUseCase]
A --> J[SortTasksUseCase]
A --> K[SearchTasksUseCase]
A --> L[TaskCollaborationUseCase]
I --> B
J --> B
K --> B
L --> B
style A fill:#4B9CD3,stroke:#34495E
style B fill:#27AE60,stroke:#34495E
style C fill:#27AE60,stroke:#34495E
style D fill:#F39C12,stroke:#34495E
style E fill:#E67E22,stroke:#34495E
style F fill:#1ABC9C,stroke:#34495E
style G fill:#9B59B6,stroke:#34495E
style H fill:#3498DB,stroke:#34495E
style I fill:#8E44AD,stroke:#34495E
style J fill:#16A085,stroke:#34495E
style K fill:#2980B9,stroke:#34495E
style L fill:#C0392B,stroke:#34495E
```

**Diagram sources**
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift)
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift)
- [FilterTasksUseCase.swift](file://To Do List/UseCases/Task/FilterTasksUseCase.swift)
- [SortTasksUseCase.swift](file://To Do List/UseCases/Task/SortTasksUseCase.swift)
- [SearchTasksUseCase.swift](file://To Do List/UseCases/Task/SearchTasksUseCase.swift)
- [TaskCollaborationUseCase.swift](file://To Do List/UseCases/Task/TaskCollaborationUseCase.swift)

## Detailed Component Analysis

### TaskRepository Protocol Analysis

The `TaskRepository` protocol defines a comprehensive interface for task data operations, enabling dependency injection and testability. It abstracts all data access concerns from the view layer.

```mermaid
classDiagram
class TaskRepository {
<<protocol>>
+fetchTasks(predicate : NSPredicate?, sortDescriptors : [NSSortDescriptor]?, completion : ([TaskData]) -> Void)
+fetchTask(by : NSManagedObjectID, completion : (Result<NTask, Error>) -> Void)
+addTask(data : TaskData, completion : (Result<NTask, Error>) -> Void)?
+toggleComplete(taskID : NSManagedObjectID, completion : (Result<Void, Error>) -> Void)?
+deleteTask(taskID : NSManagedObjectID, completion : (Result<Void, Error>) -> Void)?
+reschedule(taskID : NSManagedObjectID, to : Date, completion : (Result<Void, Error>) -> Void)?
+getMorningTasks(for : Date, completion : ([TaskData]) -> Void)
+getEveningTasks(for : Date, completion : ([TaskData]) -> Void)
+getUpcomingTasks(completion : ([TaskData]) -> Void)
+getTasksForInbox(date : Date, completion : ([TaskData]) -> Void)
+getTasksForProject(projectName : String, date : Date, completion : ([TaskData]) -> Void)
+getTasksForProjectOpen(projectName : String, date : Date, completion : ([TaskData]) -> Void)
+getTasksForAllCustomProjectsOpen(date : Date, completion : ([TaskData]) -> Void)
+updateTask(taskID : NSManagedObjectID, data : TaskData, completion : (Result<Void, Error>) -> Void)?
+saveTask(taskID : NSManagedObjectID, name : String, details : String?, type : TaskType, priority : TaskPriority, dueDate : Date, project : String, completion : (Result<Void, Error>) -> Void)?
}
class CoreDataTaskRepository {
-viewContext : NSManagedObjectContext
-backgroundContext : NSManagedObjectContext
-defaultProject : String
+init(container : NSPersistentContainer, defaultProject : String)
}
CoreDataTaskRepository ..|> TaskRepository : implements
```

**Diagram sources**
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift#L1-L117)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift#L1-L455)

### CoreDataTaskRepository Implementation Analysis

The `CoreDataTaskRepository` implements the `TaskRepository` protocol using Core Data with proper concurrency management. It utilizes two managed object contexts: a `viewContext` for UI-related fetches and a `backgroundContext` for all write operations.

```mermaid
sequenceDiagram
participant HomeVC as HomeViewController
participant Repo as CoreDataTaskRepository
participant BGContext as backgroundContext
participant ViewContext as viewContext
participant Store as Persistent Store
HomeVC->>Repo : toggleComplete(taskID)
Repo->>BGContext : perform block
BGContext->>BGContext : Fetch task with taskID
BGContext->>BGContext : Toggle isComplete status
BGContext->>BGContext : Update dateCompleted
BGContext->>BGContext : Save context
BGContext-->>Repo : Success
Repo->>HomeVC : Notify completion
Repo->>HomeVC : Post TaskCompletionChanged notification
HomeVC->>HomeVC : Refresh charts and score
```

**Diagram sources**
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift#L1-L455)
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift#L1-L1106)

### HomeViewController Integration Analysis

The `HomeViewController` integrates with the repository pattern through dependency injection, consuming the `TaskRepository` protocol rather than the concrete implementation.

```mermaid
flowchart TD
A[HomeViewController.viewDidLoad] --> B[Inject TaskRepository]
B --> C[Observe TaskCompletionChanged Notification]
C --> D[Setup UI Components]
D --> E[Load Initial Data]
E --> F[Update View Based on Date/Project]
G[User Toggles Task] --> H[Call taskRepository.toggleComplete]
H --> I[Repository Saves in Background]
I --> J[Post Notification]
J --> K[HomeVC Updates Charts/Score]
K --> L[UI Refreshed]
M[User Filters by Project] --> N[Call getTasksForProjectOpen]
N --> O[Repository Applies Predicate]
O --> P[Return Filtered Tasks]
P --> Q[Update Table View]
```

**Diagram sources**
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift#L1-L1106)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift#L1-L455)

**Section sources**
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift#L1-L1106)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift#L1-L455)

## Use Case Implementations

### FilterTasksUseCase Implementation

The `FilterTasksUseCase` provides advanced filtering capabilities for tasks based on multiple criteria including completion status, priorities, categories, contexts, energy levels, date ranges, and tags. It implements a caching mechanism to improve performance for repeated filter operations.

```mermaid
classDiagram
class FilterTasksUseCase {
-taskRepository : TaskRepositoryProtocol
-cacheService : CacheServiceProtocol?
+filterTasks(criteria : FilterCriteria, completion : (Result<FilteredTasksResult, FilterError>) -> Void)
+filterByProject(projectName : String, includeCompleted : Bool, completion : (Result<[Task], FilterError>) -> Void)
+filterByPriority(priorities : [TaskPriority], scope : FilterScope, completion : (Result<[Task], FilterError>) -> Void)
+filterByCategory(categories : [TaskCategory], completion : (Result<[Task], FilterError>) -> Void)
+filterByContext(contexts : [TaskContext], completion : (Result<[Task], FilterError>) -> Void)
+filterByEnergyLevel(energyLevels : [TaskEnergy], completion : (Result<[Task], FilterError>) -> Void)
+filterByDateRange(startDate : Date, endDate : Date, completion : (Result<[Task], FilterError>) -> Void)
+filterByTags(tags : [String], matchMode : TagMatchMode, completion : (Result<[Task], FilterError>) -> Void)
}
class FilterCriteria {
+scope : FilterScope
+completionStatus : CompletionStatusFilter
+priorities : [TaskPriority]
+categories : [TaskCategory]
+contexts : [TaskContext]
+energyLevels : [TaskEnergy]
+dateRange : DateRange?
+tags : [String]
+hasEstimate : Bool?
+hasDependencies : Bool?
+tagMatchMode : TagMatchMode
+requireDueDate : Bool
+cacheKey : String
+activeFilters : [String]
}
class FilteredTasksResult {
+tasks : [Task]
+criteria : FilterCriteria
+totalCount : Int
+appliedFilters : [String]
}
FilterTasksUseCase --> TaskRepositoryProtocol : "depends on"
FilterTasksUseCase --> CacheServiceProtocol : "optional dependency"
```

**Diagram sources**
- [FilterTasksUseCase.swift](file://To Do List/UseCases/Task/FilterTasksUseCase.swift#L1-L530)

**Section sources**
- [FilterTasksUseCase.swift](file://To Do List/UseCases/Task/FilterTasksUseCase.swift#L1-L530)

### SortTasksUseCase Implementation

The `SortTasksUseCase` provides comprehensive sorting capabilities for tasks with multiple criteria and advanced options. It supports primary, secondary, and tertiary sorting fields with configurable sort order.

```mermaid
classDiagram
class