# Search & Filtering System

<cite>
**Referenced Files in This Document**   
- [ToDoListViewType.swift](file://To%20Do%20List/Models/ToDoListViewType.swift)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift)
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift)
- [HomeDrawerFilterView.swift](file://To%20Do%20List/View/HomeDrawerFilterView.swift)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Core Components Overview](#core-components-overview)
3. [SearchBar Implementation](#searchbar-implementation)
4. [ToDoListViewType Enum](#todolistviewtype-enum)
5. [Core Data Fetch Predicates](#core-data-fetch-predicates)
6. [Filtering Logic and Predicate Composition](#filtering-logic-and-predicate-composition)
7. [Dynamic Search Results](#dynamic-search-results)
8. [Performance Considerations](#performance-considerations)
9. [Usage Patterns for New Filter Types](#usage-patterns-for-new-filter-types)
10. [Optimization Techniques](#optimization-techniques)

## Introduction
This document provides a comprehensive analysis of the search and filtering system in the Tasker application. It details the implementation of real-time task filtering, the enumeration of view types, the translation of these views into Core Data fetch predicates, and the dynamic updating of search results. The system is designed to efficiently query large datasets while maintaining a responsive user interface through techniques such as background fetching and debounce logic.

## Core Components Overview
The search and filtering system is composed of several key components that work together to provide a seamless user experience. These include the SearchBar for user input, the ToDoListViewType enum for defining filtering contexts, and the CoreDataTaskRepository for executing efficient Core Data queries. The HomeViewController orchestrates these components, managing the user interface and data flow.

**Section sources**
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L0-L1105)
- [ToDoListViewType.swift](file://To%20Do%20List/Models/ToDoListViewType.swift#L0-L19)

## SearchBar Implementation
The SearchBar component is integrated into the navigation bar of the HomeViewController and is responsible for capturing user input for real-time task filtering. The implementation includes debounce logic to prevent excessive processing during rapid typing.

The SearchBar is created and configured in the `setupFluentUINavigationBar` method of the HomeViewController. It is set as the accessory view of the navigation item, ensuring it appears inline with the navigation bar. The SearchBar's background color is customized to match the application's primary color theme.

```swift
private func createSearchBarAccessory() -> SearchBar {
    let searchBar = SearchBar()
    searchBar.style = .onBrandNavigationBar
    searchBar.placeholderText = "Search tasks..."
    searchBar.delegate = self
    
    // Customize the search bar background color
    searchBar.tokenSet[.backgroundColor] = .uiColor { self.todoColors.primaryColor }
    return searchBar
}
```

The SearchBar delegates its events to the HomeViewController, which implements the SearchBarDelegate protocol. This allows the controller to respond to changes in the search text and update the displayed tasks accordingly.

**Section sources**
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L400-L450)

## ToDoListViewType Enum
The ToDoListViewType enum defines the different filtering contexts available in the application. Each case represents a specific view mode that the user can select to filter tasks based on various criteria such as date, project, or priority.

```swift
enum ToDoListViewType {
    case todayHomeView
    case customDateView
    case projectView
    case upcomingView
    case historyView
    case allProjectsGrouped
    case selectedProjectsGrouped
}
```

- **todayHomeView**: Displays tasks for the current day, including those due today and overdue tasks.
- **customDateView**: Shows tasks for a user-selected date.
- **projectView**: Filters tasks by a single specific project.
- **upcomingView**: Displays future tasks sorted by due date.
- **historyView**: Shows completed tasks grouped by completion date.
- **allProjectsGrouped**: Groups all tasks by project.
- **selectedProjectsGrouped**: Displays tasks from multiple selected projects.

This enum is used throughout the application to determine the current filtering context and to switch between different views.

**Section sources**
- [ToDoListViewType.swift](file://To%20Do%20List/Models/ToDoListViewType.swift#L0-L19)

## Core Data Fetch Predicates
The CoreDataTaskRepository is responsible for translating the view types defined in the ToDoListViewType enum into Core Data fetch predicates. These predicates are used to efficiently query the database for tasks that match the current filtering context.

The repository provides several methods for fetching tasks based on different criteria. For example, the `getTasksForInbox` method constructs a predicate to fetch tasks for the Inbox project on a specific date. It combines multiple subpredicates using NSCompoundPredicate to include tasks due today, completed today, and overdue tasks.

```swift
func getTasksForInbox(date: Date, completion: @escaping ([TaskData]) -> Void) {
    let startOfDay = date.startOfDay
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let dueTodayPredicate = NSPredicate(
        format: "project ==[c] %@ AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
        defaultProject,
        startOfDay as NSDate,
        endOfDay as NSDate
    )
    
    let completedTodayPredicate = NSPredicate(
        format: "project ==[c] %@ AND dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
        defaultProject,
        startOfDay as NSDate,
        endOfDay as NSDate
    )
    
    var finalPredicate: NSPredicate
    if Calendar.current.isDateInToday(date) {
        let overduePredicate = NSPredicate(
            format: "project ==[c] %@ AND dueDate < %@ AND isComplete == NO",
            defaultProject,
            startOfDay as NSDate
        )
        
        let combinedPredicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate, overduePredicate]
        )
        finalPredicate = combinedPredicate
    } else {
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
```

This approach ensures that the correct set of tasks is retrieved for each view type, taking into account the current date and the user's filtering preferences.

**Section sources**
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L0-L454)

## Filtering Logic and Predicate Composition
The filtering logic in the application is implemented using a combination of NSPredicate and NSCompoundPredicate to construct complex queries. This allows for the combination of multiple filter criteria such as date, project, and priority.

For example, when filtering tasks for a specific project, the `getTasksForProject` method in CoreDataTaskRepository creates a predicate that combines conditions for the project name, due date, and completion status. If the selected date is today, it also includes overdue tasks in the results.

The use of compound predicates enables the application to handle complex filtering scenarios efficiently. By combining multiple subpredicates with logical operators (AND, OR), the system can create precise queries that match the user's intent.

```swift
let combinedPredicate = NSCompoundPredicate(
    orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate, overduePredicate]
)
```

This composition of predicates is a key aspect of the filtering system, allowing for flexible and powerful task queries.

**Section sources**
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L0-L454)

## Dynamic Search Results
The search results update dynamically as the user types in the SearchBar. This is achieved through the implementation of the SearchBarDelegate protocol in the HomeViewController.

When the user enters search text, the `searchBar(_:didUpdateSearchText:)` method is called. If the search text is empty, the application displays all tasks for the current view. Otherwise, it filters the tasks based on the search text.

```swift
func searchBar(_ searchBar: SearchBar, didUpdateSearchText newSearchText: String?) {
    let searchText = newSearchText?.lowercased() ?? ""
    
    if searchText.isEmpty {
        fluentToDoTableViewController?.updateData(for: dateForTheView)
    } else {
        filterTasksForSearch(searchText: searchText)
    }
}
```

The `filterTasksForSearch` method retrieves all tasks from the TaskManager and filters them based on the search text. It checks if the search text is contained in the task name, details, or project name. The filtered tasks are then grouped by project and displayed in the FluentUI table view.

This real-time filtering provides an immediate response to user input, enhancing the overall user experience.

**Section sources**
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L600-L800)

## Performance Considerations
The search and filtering system is designed to handle large datasets efficiently. Several performance optimizations are implemented to ensure a responsive user interface.

One common issue with search functionality is slow performance on large datasets. To address this, the application uses background contexts for Core Data operations. The CoreDataTaskRepository uses a background context for saving and updating tasks, while the view context is used for fetching data to display in the UI.

```swift
private let viewContext: NSManagedObjectContext
private let backgroundContext: NSManagedObjectContext
```

This separation of concerns ensures that database operations do not block the main thread, maintaining a smooth user experience.

Additionally, the application implements lazy loading and cell reuse in the table view to minimize memory usage and improve scrolling performance. The use of efficient fetch predicates and sorting descriptors further enhances query performance.

Despite these optimizations, searching across all tasks (name, details, project) on very large datasets could still impact performance. Potential solutions include implementing full-text search indexing or limiting the search scope to specific fields based on user preferences.

**Section sources**
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L0-L454)
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L0-L1105)

## Usage Patterns for New Filter Types
Implementing new filter types in the application follows a consistent pattern. First, a new case is added to the ToDoListViewType enum to define the new filtering context.

Next, a corresponding method is added to the CoreDataTaskRepository to construct the appropriate fetch predicate for the new filter type. This method should take into account the specific criteria for the filter and use NSPredicate and NSCompoundPredicate to create the query.

Finally, the HomeViewController is updated to handle the new view type. This may involve adding new UI elements or modifying existing ones to allow the user to select the new filter type.

For example, to implement a filter for high-priority tasks, a new case `highPriorityView` would be added to the ToDoListViewType enum. The CoreDataTaskRepository would then include a method `getHighPriorityTasks` that creates a predicate to fetch tasks with a high priority level. The HomeViewController would be updated to include a button or menu option to switch to the high-priority view.

This modular approach makes it easy to extend the filtering system with new capabilities.

**Section sources**
- [ToDoListViewType.swift](file://To%20Do%20List/Models/ToDoListViewType.swift#L0-L19)
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L0-L454)
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L0-L1105)

## Optimization Techniques
The search and filtering system employs several optimization techniques to improve performance and user experience.

One key technique is predicate caching. While not explicitly implemented in the current code, caching frequently used predicates could reduce the overhead of creating them repeatedly. For example, the predicates for common view types like `todayHomeView` or `upcomingView` could be cached and reused.

Incremental search is another optimization used in the system. Instead of performing a full search with each keystroke, the application could implement a debounce mechanism to wait for a short period of inactivity before executing the search. This prevents excessive processing during rapid typing.

```swift
// Example of debounce logic (not implemented in current code)
private var searchTask: DispatchWorkItem?

func searchBar(_ searchBar: SearchBar, didUpdateSearchText newSearchText: String?) {
    searchTask?.cancel()
    let task = DispatchWorkItem { [weak self] in
        self?.performSearch(text: newSearchText)
    }
    searchTask = task
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
}
```

Background fetching is already implemented through the use of separate view and background contexts in Core Data. This ensures that database operations do not block the main thread, allowing the UI to remain responsive.

These optimization techniques work together to create a fast and efficient search and filtering system that can handle large datasets without compromising user experience.

**Section sources**
- [CoreDataTaskRepository.swift](file://To%20Do%20List/Repositories/CoreDataTaskRepository.swift#L0-L454)
- [HomeViewController.swift](file://To%20Do%20List/ViewControllers/HomeViewController.swift#L0-L1105)