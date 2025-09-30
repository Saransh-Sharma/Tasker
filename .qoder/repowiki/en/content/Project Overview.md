# Project Overview

<cite>
**Referenced Files in This Document**   
- [README.md](file://README.md) - *Updated in recent commits with architectural changes*
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift) - *Added in commit ab127a34627bba03544c3c3260076a3e6f0cb35c*
- [CreateTaskUseCase.swift](file://To%20Do%20List/UseCases/Task/CreateTaskUseCase.swift) - *Added in commit ab127a34627bba03544c3c3260076a3e6f0cb35c*
- [HomeViewModel.swift](file://To%20Do%20List/Presentation/ViewModels/HomeViewModel.swift) - *Added in commit 0b17e78ca3caff048d96d9b9df0274a37628d7aa*
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift) - *Updated in recent commits*
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift) - *Updated in recent commits*
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift) - *Updated in recent commits*
- [AddTaskViewController.swift](file://To%20Do%20List/ViewControllers/AddTaskViewController.swift) - *Updated in recent commits*
</cite>

## Update Summary
**Changes Made**   
- Updated architectural description to reflect Clean Architecture implementation
- Added new sections on Domain Models, Use Cases, and ViewModels
- Removed outdated references to legacy TaskManager and ProjectManager singletons
- Updated codebase terminology to reflect new architecture
- Added new user workflows reflecting modern implementation
- Updated technical stack and architecture section with new patterns

## Table of Contents
1. [Introduction](#introduction)
2. [Target Audience](#target-audience)
3. [Core Features](#core-features)
4. [Technical Stack and Architecture](#technical-stack-and-architecture)
5. [Key Differentiators](#key-differentiators)
6. [User Workflows](#user-workflows)
7. [Codebase Terminology](#codebase-terminology)
8. [Further Exploration](#further-exploration)

## Introduction

Tasker is a time-based task management application designed exclusively for iOS users seeking a structured, gamified approach to productivity. Unlike conventional to-do list apps, Tasker emphasizes temporal organization by categorizing tasks into **Morning** and **Evening** segments, encouraging users to plan their day with intentionality. The app leverages **iCloud synchronization** via Core Data and CloudKit to ensure seamless task continuity across all Apple devices. A unique **daily scoring system** transforms task completion into a rewarding experience, providing users with quantifiable feedback on their productivity. This combination of time segmentation, cloud sync, project grouping, and performance analytics makes Tasker a powerful tool for individuals aiming to build consistent, high-impact daily routines.

**Section sources**
- [README.md](file://README.md#L1-L50)

## Target Audience

Tasker is tailored for **productivity-focused iOS users** who are looking for more than a simple checklist. The ideal user is someone who values structure, seeks to optimize their daily workflow, and is motivated by measurable progress. This includes professionals managing complex workloads, students balancing academic and personal tasks, and anyone striving to develop disciplined habits. The app's scoring and analytics features particularly appeal to users who respond well to gamification and data-driven insights into their behavior.

## Core Features

Tasker offers a comprehensive suite of features designed to enhance personal organization and productivity:

- **Task Creation & Management**: Users can create tasks with a title, description, priority level (P0 to P3), and assign them to a specific project. Tasks are automatically categorized as Morning, Evening, or Upcoming based on their due date and time.
- **Time-Based Categorization**: The app's core innovation is its division of tasks into **Morning** and **Evening** categories, promoting a balanced approach to daily planning and preventing task overload.
- **iCloud Synchronization**: Built on **Core Data with CloudKit**, Tasker ensures that all tasks, projects, and completion status are automatically synced across an iCloud user's iPhone, iPad, and Mac.
- **Project Grouping**: Users can create custom projects to organize related tasks. The app features a default "Inbox" project for uncategorized items, and tasks can be easily filtered and viewed by project.
- **Daily Scoring & Analytics**: Each completed task contributes to a daily score based on its priority (P0: 7pts, P1: 4pts, P2: 3pts, P3: 2pts). The `HomeViewController` displays interactive charts powered by the DGCharts framework, providing visual insights into completion trends, streaks, and overall productivity over time.

**Section sources**
- [README.md](file://README.md#L51-L100)
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L1-L50)

## Technical Stack and Architecture

Tasker is built using **Swift** and the **UIKit** framework, ensuring a native iOS experience. The data persistence layer is powered by **Core Data**, which is seamlessly integrated with **CloudKit** for automatic iCloud synchronization. For analytics and data visualization, the app uses the **DGCharts** framework to render interactive bar and line charts.

The application has been refactored to follow a **Clean Architecture** pattern, which consists of three main layers:

1. **Presentation Layer**: Handles UI and user interactions through ViewControllers and ViewModels
2. **Domain Layer**: Contains business logic, use cases, and pure Swift domain models
3. **Data Layer**: Manages data persistence and retrieval through repositories and Core Data

The primary data model is the `Task` struct, a pure Swift domain model that represents a task without any framework dependencies. This model is used throughout the application to ensure type safety and separation from persistence concerns.

The business logic is organized into **Use Cases** that encapsulate specific workflows such as task creation, completion, and rescheduling. These use cases are stateless operations that coordinate the flow of data between layers. For example, the `CreateTaskUseCase` handles all business rules related to task creation, including validation, project assignment, and reminder scheduling.

The presentation layer uses **ViewModels** to manage the state of the UI and handle user interactions. The `HomeViewModel` observes changes in the application state and exposes data to the `HomeViewController` through Combine's `@Published` properties. This decoupling allows for reactive UI updates and easier testing.

Data access is abstracted through the **Repository Pattern**. The `TaskRepository` protocol defines the interface for all task data operations, while `CoreDataTaskRepository` provides the concrete implementation that interacts with Core Data. This abstraction enables dependency injection and makes the code more testable.

**Section sources**
- [README.md](file://README.md#L101-L200)
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [CreateTaskUseCase.swift](file://To%20Do%20List/UseCases/Task/CreateTaskUseCase.swift#L1-L225)
- [HomeViewModel.swift](file://To%20Do%20List/Presentation/ViewModels/HomeViewModel.swift#L1-L379)
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L118)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L455)

## Key Differentiators

Tasker distinguishes itself from standard to-do apps through two primary mechanisms: **time segmentation** and **scoring mechanics**. While most apps simply list tasks, Tasker forces a temporal decision by requiring users to place tasks in a morning or evening context. This encourages mindful planning and helps prevent the common pitfall of an overly ambitious, unstructured list.

The **scoring system** adds a layer of gamification that transforms task completion from a mundane chore into a rewarding activity. By assigning higher point values to higher-priority tasks, the app incentivizes users to tackle the most important work first. The daily score, visible on the home screen, provides a clear, immediate sense of accomplishment, while the historical analytics foster long-term motivation by showing progress over days and weeks.

Additionally, Tasker's **Clean Architecture** implementation sets it apart from typical iOS applications. By separating concerns into distinct layers, the app achieves better testability, maintainability, and scalability. The use of pure Swift domain models, stateless use cases, and reactive ViewModels represents a modern approach to iOS development that prioritizes code quality and developer experience.

## User Workflows

### Adding a Task
A user navigates to the task creation screen (typically via a floating action button). They input a task name, select a priority, choose a project, and specify whether it is a morning or evening task. When the user submits the form, the `AddTaskViewController` collects the input data and passes it to the `CreateTaskUseCase`. This use case validates the input, applies business rules (such as determining task type based on time), and creates a `Task` domain model. The use case then delegates to the `TaskRepository` to persist the task to Core Data. Upon successful creation, the `HomeViewModel` receives a notification and updates the UI to display the new task in the appropriate list.

### Viewing Daily Score
When the user opens the app, the `HomeViewController` initializes the `HomeViewModel`, which orchestrates the loading of today's tasks through the `GetTasksUseCase`. The `CalculateAnalyticsUseCase` computes the daily score by summing the points for each completed task based on its priority. The `HomeViewModel` exposes the score through its `@Published` properties, which automatically triggers UI updates in the `HomeViewController`. The score is prominently displayed, and the accompanying chart is updated to reflect the user's performance, potentially showing a streak of consecutive days with completed tasks.

**Section sources**
- [AddTaskViewController.swift](file://To%20Do%20List/ViewControllers/AddTaskViewController.swift#L1-L40)
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L100-L150)
- [CreateTaskUseCase.swift](file://To%20Do%20List/UseCases/Task/CreateTaskUseCase.swift#L1-L225)
- [HomeViewModel.swift](file://To%20Do%20List/Presentation/ViewModels/HomeViewModel.swift#L1-L379)

## Codebase Terminology

The Tasker codebase uses specific terminology that reflects its Clean Architecture:

- **`Task`**: The pure Swift domain model that represents a single task. This is the fundamental data model object used throughout the application.
- **`TaskRepository`**: A protocol that defines the interface for all task data operations (fetch, create, update, delete), promoting loose coupling and testability.
- **`CoreDataTaskRepository`**: The concrete class that implements the `TaskRepository` protocol, handling all interactions with the Core Data persistent store.
- **`Use Case`**: A stateless class that encapsulates a specific business workflow, such as `CreateTaskUseCase` or `CompleteTaskUseCase`.
- **`ViewModel`**: A class that manages the state of a view and handles user interactions, such as `HomeViewModel` or `AddTaskViewModel`.
- **`Domain Model`**: Pure Swift structs that represent business concepts without framework dependencies, ensuring type safety and separation of concerns.

**Section sources**
- [Task.swift](file://To%20Do%20List/Domain/Models/Task.swift#L1-L140)
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L1-L20)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L1-L15)
- [CreateTaskUseCase.swift](file://To%20Do%20List/UseCases/Task/CreateTaskUseCase.swift#L1-L225)
- [HomeViewModel.swift](file://To%20Do%20List/Presentation/ViewModels/HomeViewModel.swift#L1-L379)

## Further Exploration

For a deeper understanding of the Tasker application, explore the following sections of the documentation:
- **Architecture Overview**: A detailed diagram of the Clean Architecture implementation with Presentation, Domain, and Data layers.
- **Domain Models Reference**: Complete documentation of the pure Swift domain models including `Task`, `Project`, and related enums.
- **Use Cases Documentation**: Detailed descriptions of all business workflows and their implementation.
- **ViewModels Guide**: Explanation of how ViewModels manage UI state and coordinate with use cases.
- **Testing Strategy**: An outline of the unit and integration tests for the new architecture.