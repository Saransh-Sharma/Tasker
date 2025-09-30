# Domain Layer

<cite>
**Referenced Files in This Document**   
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [CoreDataTaskRepository+Domain.swift](file://To%20Do%20List/State/Repositories/CoreDataTaskRepository+Domain.swift#L1-L405)
- [TaskMapper.swift](file://To%20Do%20List/Domain/Mappers/TaskMapper.swift#L1-L150)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Domain Layer Overview](#domain-layer-overview)
3. [Core Domain Models](#core-domain-models)
4. [Domain Interfaces and Protocols](#domain-interfaces-and-protocols)
5. [Domain Layer Implementation](#domain-layer-implementation)
6. [Integration with Other Layers](#integration-with-other-layers)
7. [Practical Examples](#practical-examples)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)

## Introduction
The Domain Layer in the Tasker application represents the core business logic and entities that define the application's purpose and functionality. This layer implements Clean Architecture principles by maintaining independence from infrastructure concerns such as data persistence and user interface. The domain layer encapsulates the essential business rules, data models, and interfaces that govern task management operations, providing a stable foundation that can be easily tested and evolved over time. By separating domain concerns from implementation details, the architecture enhances maintainability, testability, and flexibility.

## Domain Layer Overview

```mermaid
graph TD
subgraph "Domain Layer"
A[Task Model] --> B[TaskRepositoryProtocol]
C[TaskType Enum] --> A
D[TaskPriority Enum] --> A
E[TaskValidationError] --> A
B --> F[TaskMapper]
end
subgraph "Other Layers"
G[Data Layer] --> B
H[Presentation Layer] --> A
end
```

**Diagram sources**
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)

**Section sources**
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)

## Core Domain Models

The Task model serves as the central domain entity in the Tasker application, representing a pure Swift implementation of a task with no dependencies on external frameworks. This struct encapsulates all essential properties of a task including name, details, type, priority, due date, project association, completion status, and timestamps. The model includes comprehensive business logic through computed properties that determine task scoring, overdue status, and temporal characteristics. Validation rules are implemented through a dedicated validation method that checks for empty names, excessive character counts, and other data integrity constraints. The domain model adheres to Swift best practices by conforming to Equatable and Hashable protocols, enabling reliable comparison and hashing operations.

**Section sources**
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)

## Domain Interfaces and Protocols

```mermaid
classDiagram
class TaskRepositoryProtocol {
<<protocol>>
+fetchAllTasks(completion : (Result<[Task], Error>) -> Void)
+fetchTasks(for : Date, completion : (Result<[Task], Error>) -> Void)
+fetchTodayTasks(completion : (Result<[Task], Error>) -> Void)
+fetchTasks(for : String, completion : (Result<[Task], Error>) -> Void)
+fetchOverdueTasks(completion : (Result<[Task], Error>) -> Void)
+fetchUpcomingTasks(completion : (Result<[Task], Error>) -> Void)
+fetchCompletedTasks(completion : (Result<[Task], Error>) -> Void)
+fetchTasks(ofType : TaskType, completion : (Result<[Task], Error>) -> Void)
+fetchTask(withId : UUID, completion : (Result<Task?, Error>) -> Void)
+createTask(_ : Task, completion : (Result<Task, Error>) -> Void)
+updateTask(_ : Task, completion : (Result<Task, Error>) -> Void)
+completeTask(withId : UUID, completion : (Result<Task, Error>) -> Void)
+uncompleteTask(withId : UUID, completion : (Result<Task, Error>) -> Void)
+rescheduleTask(withId : UUID, to : Date, completion : (Result<Task, Error>) -> Void)
+deleteTask(withId : UUID, completion : (Result<Void, Error>) -> Void)
+deleteCompletedTasks(completion : (Result<Void, Error>) -> Void)
+createTasks(_ : [Task], completion : (Result<[Task], Error>) -> Void)
+updateTasks(_ : [Task], completion : (Result<[Task], Error>) -> Void)
+deleteTasks(withIds : [UUID], completion : (Result<Void, Error>) -> Void)
}
```

**Diagram sources**
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)

**Section sources**
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)

## Domain Layer Implementation

The domain layer implementation in Tasker follows Clean Architecture principles by providing a clear separation between business logic and infrastructure concerns. The TaskRepositoryProtocol defines a comprehensive contract for all task-related operations, enabling dependency injection and facilitating testing through mock implementations. This protocol includes methods for all CRUD operations, specialized fetching scenarios, and batch processing capabilities. The implementation leverages Swift's Result type for error handling, ensuring type-safe asynchronous operations that maintain UI responsiveness. The domain layer communicates with the data layer through mappers that convert between domain models and persistence entities, maintaining the independence of business logic from storage mechanisms.

**Section sources**
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)
- [CoreDataTaskRepository+Domain.swift](file://To%20Do%20List/State/Repositories/CoreDataTaskRepository+Domain.swift#L1-L405)
- [TaskMapper.swift](file://To%20Do%20List/Domain/Mappers/TaskMapper.swift#L1-L150)

## Integration with Other Layers

```mermaid
graph TD
subgraph "Domain Layer"
A[Task] --> B[TaskRepositoryProtocol]
end
subgraph "Data Layer"
C[CoreDataTaskRepository] --> B
D[NTask] --> C
end
subgraph "Business Logic Layer"
E[TaskManager] --> A
end
subgraph "Presentation Layer"
F[HomeViewController] --> A
G[AddTaskViewController] --> A
end
B --> C
A --> E
A --> F
A --> G
```

**Diagram sources**
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)
- [CoreDataTaskRepository+Domain.swift](file://To%20Do%20List/State/Repositories/CoreDataTaskRepository+Domain.swift#L1-L405)

The domain layer integrates with other architectural layers through well-defined interfaces and dependency injection. The data layer implements the TaskRepositoryProtocol through the CoreDataTaskRepository class, which handles the conversion between the domain Task model and the Core Data NTask entity using the TaskMapper. Business logic components such as TaskManager interact with domain models directly, leveraging their built-in validation and business rules. The presentation layer receives domain models for display and passes user actions to repository interfaces, maintaining separation of concerns. This integration pattern ensures that business logic remains independent of UI and persistence details, allowing for easier testing and future modifications.

**Section sources**
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)
- [CoreDataTaskRepository+Domain.swift](file://To%20Do%20List/State/Repositories/CoreDataTaskRepository+Domain.swift#L1-L405)

## Practical Examples

### Creating a New Task
To create a new task, clients of the domain layer instantiate a Task struct with the desired properties and pass it to the createTask method of a TaskRepositoryProtocol implementation. The domain model automatically validates the input data and assigns default values where appropriate. The repository handles the persistence details while returning a Result type that indicates success or failure.

### Fetching Tasks by Date
Clients can retrieve tasks for a specific date by calling the fetchTasks(for:completion:) method on the repository. This operation returns all tasks scheduled for the specified date, allowing the presentation layer to display time-specific task lists. The domain layer handles the filtering logic through appropriate predicates applied to the underlying data store.

### Updating Task Completion Status
To mark a task as complete, clients call the completeTask(withId:completion:) method on the repository, passing the task's UUID. The domain layer updates the task's isComplete property and records the completion timestamp, triggering appropriate notifications for UI updates. The reverse operation (marking as incomplete) follows a similar pattern.

**Section sources**
- [Task.swift](file://To%20Do%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)

## Troubleshooting Guide

Common issues in the domain layer typically relate to data validation, type mismatches, and asynchronous operation handling. When encountering validation errors during task creation, verify that the task name is not empty and does not exceed 200 characters, and that details do not exceed 1000 characters. For issues with task retrieval, ensure that date parameters are properly formatted and that the repository implementation is correctly handling predicates. When debugging asynchronous operations, confirm that completion handlers are being called on the appropriate queue (typically the main queue for UI updates). If domain model properties are not being updated as expected, verify that value types are being properly reassigned, as structs are copied rather than referenced.

**Section sources**
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [TaskRepositoryProtocol.swift](file://To%20Do%20List/Domain/Interfaces/TaskRepositoryProtocol.swift#L1-L80)

## Conclusion
The Domain Layer in the Tasker application successfully implements Clean Architecture principles by encapsulating business logic in framework-independent models and protocols. The Task struct provides a robust domain model with built-in validation and business rules, while the TaskRepositoryProtocol defines a comprehensive interface for data operations that enables dependency injection and testing. This separation of concerns enhances the application's maintainability, testability, and flexibility, allowing for easier evolution of both business rules and implementation details. The domain layer serves as a stable foundation that can be easily integrated with different data persistence mechanisms and user interface technologies, ensuring long-term sustainability of the application architecture.