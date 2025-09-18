# Task Filtering and Organization

<cite>
**Referenced Files in This Document**   
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift)
- [TaskManager.swift](file://To%20Do%20List/ViewControllers/TaskManager.swift)
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift)
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift)
- [Task.swift](file://To%20Do%20List/Model/Task.swift)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Task Categorization System](#task-categorization-system)
3. [Task Filtering in HomeViewController](#task-filtering-in-homeviewcontroller)
4. [Query Patterns with NSPredicate and NSSortDescriptor](#query-patterns-with-nspredicate-and-nssortdescriptor)
5. [User Interaction and UI Updates](#user-interaction-and-ui-updates)
6. [TaskPriority Role in Sorting and Visual Representation](#taskpriority-role-in-sorting-and-visual-representation)
7. [Performance Issues and Optimizations](#performance-issues-and-optimizations)
8. [Extending Filters for Custom Views and Search](#extending-filters-for-custom-views-and-search)
9. [Conclusion](#conclusion)

## Introduction
The Tasker application implements a sophisticated task filtering and organization system that enables users to efficiently manage their tasks through categorization, filtering, and sorting mechanisms. This document details how tasks are categorized by TaskType (morning, evening, upcoming) and filtered by project membership within the HomeViewController. It explains the query patterns used in the fetchTasks method to retrieve filtered datasets efficiently using NSPredicate and sorting with NSSortDescriptor. The document also covers how user interactions trigger re-fetching and UI updates, the role of the TaskPriority enum in sorting and visual representation, common performance issues with large datasets, and recommendations for optimizations and extending filters to support custom views or search queries.

## Task Categorization System
The Tasker application categorizes tasks using the TaskType enum, which defines three primary categories: morning, evening, and upcoming. These categories help users organize their tasks based on the time of day or when they are scheduled. The TaskType enum is implemented as a Swift enum with raw values of type Int32, where morning is assigned a raw value of 1, evening is assigned a raw value of 2, and upcoming is assigned a raw value of 3. This categorization system is integral to the application's ability to group and display tasks in a meaningful way, allowing users to focus on tasks relevant to their current context.

The TaskType enum is used throughout the application to filter and display tasks based on their type. For example, the HomeViewController uses this enum to determine which tasks to display when the user selects a specific view type, such as morning or evening tasks. The enum values are stored in the Core Data model as raw integer values, ensuring efficient storage and retrieval. The application also provides methods to convert between the enum values and their raw integer representations, facilitating seamless integration between the user interface and the underlying data model.

**Section sources**
- [TaskManager.swift](file://To%20Do%20List/ViewControllers/TaskManager.swift#L600-L650)

## Task Filtering in HomeViewController
The HomeViewController is responsible for managing task filtering based on project membership and other criteria. It uses the selectedProjectNamesForFilter array to track which projects the user has selected for filtering. When the user interacts with the project selection interface, the selectedProjectNamesForFilter array is updated accordingly, and the view is refreshed to display tasks from the selected projects. This filtering mechanism allows users to focus on tasks from specific projects, improving their ability to manage and complete tasks efficiently.

The HomeViewController also supports various view types through the ToDoListViewType enum, which includes cases such as todayHomeView, customDateView, projectView, upcomingView, historyView, allProjectsGrouped, and selectedProjectsGrouped. Each view type corresponds to a different filtering context, enabling users to view tasks based on different criteria such as date, project, or completion status. For example, when the user selects the projectView, the HomeViewController filters tasks to display only those belonging to the selected project. This flexible filtering system enhances the user experience by providing multiple ways to organize and view tasks.

**Section sources**
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L150-L200)

## Query Patterns with NSPredicate and NSSortDescriptor
The Tasker application uses NSPredicate and NSSortDescriptor to efficiently query and sort tasks in the fetchTasks method. NSPredicate is used to filter tasks based on various criteria such as task type, project, and date. For example, to fetch morning tasks for a specific date, the application constructs an NSPredicate that checks if the task type is morning and the due date falls within the specified date range. This predicate is then applied to the fetch request to retrieve only the relevant tasks.

NSSortDescriptor is used to sort the fetched tasks based on priority and due date. The application typically sorts tasks by priority in descending order, ensuring that higher priority tasks appear first, followed by sorting by due date in ascending order to display tasks with earlier due dates first. This sorting strategy helps users focus on the most important and time-sensitive tasks. The combination of NSPredicate and NSSortDescriptor allows the application to efficiently retrieve and present filtered and sorted task data, enhancing the user experience.

```mermaid
flowchart TD
A[Start Fetch Tasks] --> B[Create Fetch Request]
B --> C[Apply NSPredicate for Filtering]
C --> D[Apply NSSortDescriptor for Sorting]
D --> E[Execute Fetch Request]
E --> F[Return Filtered and Sorted Tasks]
```

**Diagram sources**
- [TaskRepository.swift](file://To%20Do%20List/Repositories/TaskRepository.swift#L12-L30)
- [TaskManager.swift](file://To%20Do%20List/ViewControllers/TaskManager.swift#L700-L750)

## User Interaction and UI Updates
User interactions in the Tasker application trigger re-fetching and UI updates to ensure that the displayed tasks are always up-to-date. When a user adds a new task, completes a task, or changes the filtering criteria, the application responds by re-fetching the relevant tasks and updating the UI accordingly. For example, when a user adds a new task, the HomeViewController calls the updateViewForHome method to refresh the displayed tasks based on the current view type and filtering criteria. This ensures that the new task is immediately visible to the user if it matches the current filtering context.

The application also uses notifications to trigger UI updates when task data changes. For instance, when a task's completion status is toggled, the TaskManager posts a TaskCompletionChanged notification, which the HomeViewController observes. Upon receiving this notification, the HomeViewController updates the UI to reflect the change in task status, such as updating the task's visual representation and recalculating the daily score. This reactive approach to UI updates ensures that the user interface remains synchronized with the underlying data, providing a seamless and responsive user experience.

**Section sources**
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L1000-L1100)
- [TaskManager.swift](file://To%20Do%20List/ViewControllers/TaskManager.swift#L800-L850)

## TaskPriority Role in Sorting and Visual Representation
The TaskPriority enum plays a crucial role in both sorting tasks and their visual representation within the Tasker application. The enum defines four priority levels: low, medium, high, and veryLow, each with a corresponding raw value that determines its order in sorting. When tasks are fetched and displayed, they are sorted by priority in descending order, ensuring that higher priority tasks appear first in the list. This sorting mechanism helps users focus on the most important tasks, improving their productivity and task management efficiency.

In addition to sorting, the TaskPriority enum influences the visual representation of tasks in the user interface. Each priority level is associated with a specific color, which is used to highlight the task in the task list. For example, high priority tasks are displayed with a red indicator, medium priority tasks with an orange indicator, and low priority tasks with a blue indicator. This color-coding system provides a quick visual cue for users to identify the priority of each task, making it easier to prioritize their work. The combination of sorting and visual representation based on TaskPriority enhances the user experience by providing clear and intuitive task management capabilities.

**Section sources**
- [TaskManager.swift](file://To%20Do%20List/ViewControllers/TaskManager.swift#L650-L700)
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L50-L60)

## Performance Issues and Optimizations
The Tasker application may experience performance issues when filtering large datasets, particularly when using complex predicates or sorting large numbers of tasks. To address these issues, the application can implement several optimizations. One effective optimization is pre-fetching commonly accessed data, such as tasks for the current day or frequently used projects, to reduce the need for repeated database queries. Pre-fetching can significantly improve the responsiveness of the user interface by minimizing the time required to display tasks.

Another optimization is caching filtered results to avoid redundant computations. When a user applies a filter, the application can store the resulting dataset in a cache, allowing for quick retrieval if the same filter is applied again. This caching mechanism reduces the computational overhead of filtering and sorting tasks, especially for complex filters that involve multiple criteria. Additionally, using fetched properties in Core Data can further enhance performance by allowing the database to handle filtering and sorting operations more efficiently. These optimizations collectively improve the application's performance, ensuring a smooth and responsive user experience even with large datasets.

**Section sources**
- [TaskManager.swift](file://To%20Do%20List/ViewControllers/TaskManager.swift#L900-L950)

## Extending Filters to Support Custom Views or Search Queries
The Tasker application's filtering system can be extended to support custom views and search queries, providing users with even greater flexibility in managing their tasks. Custom views can be implemented by defining new cases in the ToDoListViewType enum and adding corresponding filtering logic in the HomeViewController. For example, a custom view could display tasks based on a specific tag or category, allowing users to organize tasks in ways that suit their workflow.

Search queries can be integrated into the filtering system by adding a search bar to the user interface and implementing real-time search functionality. When the user enters a search term, the application can filter tasks based on the task name, details, or project, providing immediate feedback on matching tasks. This search functionality can be enhanced by using full-text search capabilities in Core Data or by implementing a custom search algorithm that supports fuzzy matching and keyword highlighting. By extending the filtering system to support custom views and search queries, the Tasker application can better meet the diverse needs of its users, improving their ability to manage and complete tasks efficiently.

**Section sources**
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L500-L550)

## Conclusion
The Tasker application's task filtering and organization system provides a robust and flexible framework for managing tasks. By categorizing tasks using the TaskType enum, filtering tasks based on project membership and other criteria, and using NSPredicate and NSSortDescriptor for efficient querying and sorting, the application enables users to effectively organize and prioritize their tasks. The integration of user interactions and UI updates ensures that the displayed tasks are always up-to-date, while the use of TaskPriority for sorting and visual representation enhances the user experience. Performance optimizations such as pre-fetching, caching, and using fetched properties help maintain a responsive interface even with large datasets. Finally, extending the filtering system to support custom views and search queries can further improve the application's usability, making it a powerful tool for task management.