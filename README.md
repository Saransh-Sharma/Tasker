# Tasker - Gamified Tasks & Productivity Pulse

Tasker is a sophisticated iOS productivity application that transforms task management into an engaging, gamified experience. Built with Swift and UIKit, it combines modern iOS design patterns with powerful productivity features including CloudKit synchronization, advanced analytics, and a comprehensive scoring system.

## Key Features

### 🎯 **Comprehensive Task Management System**
- **Task Creation & Editing**: Rich task creation with title, description, priority levels (P0-P4), and due dates
- **Task Types**: Morning, Evening, Upcoming, and Inbox categorization with automatic scheduling
- **Priority System**: 4-level priority system (P0-Highest, P1-High, P2-Medium, P3-Low) with visual indicators
- **Task Completion**: Mark tasks as complete with automatic scoring and streak tracking
- **Task Rescheduling**: Built-in reschedule functionality for overdue or postponed tasks
- **Task Details View**: Comprehensive FluentUI-based detail view with full editing capabilities

### 📁 **Advanced Project Management**
- **Custom Projects**: Create, edit, and delete custom project categories
- **Default Inbox System**: Automatic "Inbox" project for uncategorized tasks
- **Project-Based Filtering**: View tasks filtered by specific projects
- **Project Analytics**: Track completion rates and progress per project
- **Project Grouping**: Tasks automatically grouped by project in list views

### 📊 **Analytics & Gamification Dashboard**
- **Visual Charts**: Interactive charts showing task completion trends and patterns
- **Scoring System**: Dynamic scoring based on task priority (P0: 7pts, P1: 4pts, P2: 3pts, P3: 2pts)
- **Streak Tracking**: Consecutive day completion streaks with up to 30-day history
- **Daily Score Calculation**: Real-time score updates based on completed tasks
- **Performance Insights**: Historical data visualization for productivity tracking

### 🎨 **Modern FluentUI Interface**
- **FluentUI Components**: Microsoft FluentUI design system integration
- **Table Cell Views**: Custom FluentUI table cells with priority indicators and due date displays
- **Segmented Controls**: FluentUI segmented controls for task type selection
- **Material Design Elements**: MDC text fields, floating action buttons, and ripple effects
- **Responsive Design**: Adaptive layouts for different screen sizes

### 📅 **Smart Scheduling & Calendar**
- **Calendar Integration**: FSCalendar integration for visual task scheduling
- **Date-Based Views**: Today, custom date, upcoming, and history views
- **Overdue Detection**: Automatic identification and highlighting of overdue tasks
- **Time-Based Organization**: Morning/evening task separation with automatic categorization

### ☁️ **Cloud Sync & Data Management**
- **CloudKit Integration**: Seamless cross-device synchronization
- **Core Data Repository**: Robust local data storage with background context operations
- **Type-Safe Enums**: TaskType and TaskPriority enums with Core Data integration
- **Data Validation**: Comprehensive validation rules for task creation and editing

### 🔍 **Advanced Search & Filtering**
- **Multi-Criteria Filtering**: Filter by project, priority, completion status, and date ranges
- **Search Functionality**: Real-time search across task titles and descriptions
- **View Type System**: 7 different view modes (Today, Custom Date, Project, Upcoming, History, All Projects, Selected Projects)
- **Smart Grouping**: Automatic grouping by project with customizable sorting

---
| ![app_store](https://user-images.githubusercontent.com/4607881/123705006-fbb21700-d883-11eb-9c32-7c201067bf08.png)  | [App Store Link](https://apps.apple.com/app/id1574046107) | ![Tasker v1 0 0](https://user-images.githubusercontent.com/4607881/123707145-e4285d80-d886-11eb-8868-13d257fab8f4.gif) |
| ------------- | ------------- | --------|
---

## Recent Improvements (2025)

- Added BEMCheckBox integration for inline checkboxes and automatic strike-through of completed tasks (June 2025)
- Fixed project filter logic ensuring the main filter button stays visible when project filters are active (June 2025)
- Introduced Chat assistant interface (`ChatHostViewController`) accessible from the bottom app bar (May 2025)
- Implemented automatic merging of duplicate "Inbox" projects during data integrity checks (April 2025)
- Refactored core data flow toward a Repository & Dependency-Injection pattern for better testability (March 2025)

## Installation
- Run `pod install` on project directory ([CocoaPods Installation](https://guides.cocoapods.org/using/getting-started.html))
- Open `Tasker.xcworkspace`
- Build & run, enjoy

## Project Architecture

### Overview
Tasker follows a **Model-View-Controller (MVC)** architecture pattern with additional manager classes for business logic separation. The app is built using:

- **Core Data** with **CloudKit** integration for data persistence and synchronization
- **Material Design Components** and **FluentUI** for modern UI components
- **DGCharts framework** for advanced data visualization
- **Firebase** for analytics, crashlytics, and performance monitoring
- **Singleton pattern** for data managers to ensure consistent state management

### In-Depth Architecture Analysis

**Manager Class Interactions:**
`TaskManager` and `ProjectManager` serve as central hubs for managing `NTask` and `Projects` data, respectively. ViewControllers interact with these managers to fetch, create, or update data. For instance, `HomeViewController` calls methods like `TaskManager.sharedInstance.getMorningTasksForToday()` to populate its table view. Similarly, when a user creates a task, ViewControllers invoke manager methods such as `TaskManager.sharedInstance.createTask(...)` to persist the new data.

**ViewController Responsibilities:**
ViewControllers, exemplified by `HomeViewController`, currently handle a broad spectrum of responsibilities. These include setting up the user interface (often involving complex custom views like calendars and charts), managing user interactions, initiating data fetching operations by calling manager classes, and directly updating the UI in response to new data. Additionally, some business logic, such as calculating scores for display, is triggered from within `HomeViewController`.

**Custom UI Components:**
The `To Do List/View/` directory houses a variety of custom UI components, including `HomeBackdropView`, `HomeForedropView`, and `HomeBottomBarView`. These components are crucial for creating the app's distinctive layered user interface and contribute significantly to the overall user experience. They are designed to work seamlessly with UIKit, Material Components, and FluentUI to deliver a polished and engaging visual presentation.

### Architecture Layers

## Deep Analysis: TaskManager Architecture & Evolution

### TaskManager: The Legacy Foundation

`TaskManager` serves as the central hub for all task-related operations in the Tasker application. As a singleton class (`TaskManager.sharedInstance`), it provides a unified interface for task management across the entire application.

#### Core Responsibilities

**1. Core Data Management**
- Manages the Core Data `NSManagedObjectContext` for database operations
- Handles CRUD operations for `NTask` entities
- Provides context saving and error handling

**2. Task Type Management**
- Defines `TaskType` enum: `.morning`, `.evening`, `.upcoming`
- Defines `TaskPriority` enum: `.low`, `.medium`, `.high`
- Manages task categorization and filtering

**3. Task Lifecycle Operations**
```swift
// Core CRUD Operations
func addNewMorningTaskWithName(name: String, project: String)
func addNewEveningTaskWithName(name: String, project: String)
func toggleTaskComplete(task: NTask)
func removeTaskAtIndex(index: Int)
func reschedule(task: NTask, to date: Date)
```

**4. Advanced Query Interface**
- Date-based filtering (today, overdue, specific dates)
- Project-based filtering
- Completion status filtering
- Complex predicate-based queries using `NSPredicate`

#### Key Methods Analysis

**Task Retrieval Methods:**
- `getTasksForInboxForDate_All(date:)` - Inbox tasks for specific date
- `getTasksForProjectByName(projectName:)` - All tasks for a project
- `getTasksForAllCustomProjectsByNameForDate_Open(date:)` - Open custom project tasks
- `getTasksDueToday()` - Tasks due today
- `getTasksCompletedToday()` - Completed tasks for today
- `getOverdueTasks()` - Overdue incomplete tasks

**Data Integrity Methods:**
- `fixMissingTasksDataWithDefaults()` - Ensures data consistency
- `saveContext()` - Persists changes to Core Data
- `fetchTasks(predicate:sortDescriptors:)` - Generic fetch with filtering

### Architectural Evolution: From Monolith to Clean Architecture

#### Phase 1: Legacy Architecture (Pre-2025)
```
┌─────────────────┐
│  View Controllers│
│        ↓        │
│   TaskManager   │ ← Singleton, tightly coupled
│        ↓        │
│   Core Data     │
└─────────────────┘
```

**Challenges:**
- Tight coupling between UI and data layer
- Difficult to test due to singleton dependencies
- Mixed responsibilities (UI logic + data access)
- Hard to mock for unit testing

#### Phase 2: Repository Pattern Introduction (2025)
```
┌─────────────────┐
│  View Controllers│
│        ↓        │
│ TaskRepository  │ ← Protocol-based abstraction
│        ↓        │
│CoreDataTaskRepo │ ← Concrete implementation
│        ↓        │
│   Core Data     │
└─────────────────┘
```

**Improvements:**
- Protocol-based abstraction (`TaskRepository`)
- Dependency injection via `DependencyContainer`
- Background context operations for better performance
- `TaskData` struct for UI decoupling

#### Phase 3: Clean Architecture Target
```
┌─────────────────┐
│ Presentation    │ ← SwiftUI/UIKit Views
│        ↓        │
│ Domain          │ ← Business Logic & Use Cases
│        ↓        │
│ Data            │ ← Repository Pattern
│        ↓        │
│ Infrastructure  │ ← Core Data, Network, etc.
└─────────────────┘
```

### Current State: Hybrid Architecture

The application currently operates in a **hybrid state** where:

**Legacy Components (TaskManager):**
- Still used extensively throughout the codebase
- Provides backward compatibility
- Handles complex business logic and data validation
- Used in: `HomeViewController`, `AddTaskViewController`, `ProjectManager`

**Modern Components (TaskRepository):**
- Used in newer view controllers like `TaskListViewController`
- Provides cleaner, testable architecture
- Better separation of concerns
- Async operations with completion handlers

### Migration Strategy

#### Completed Migrations ✅
1. **TaskListViewController** - Fully migrated to repository pattern with NSFetchedResultsController
2. **DependencyContainer** - Centralized dependency management with injection system
3. **TaskData struct** - UI/Core Data decoupling layer
4. **Background contexts** - Improved performance for data operations
5. **CoreDataTaskRepository** - Complete repository implementation with async operations
6. **TaskScoringService** - Dedicated service for scoring logic
7. **DateUtils & LoggingService** - Utility layer implementations

#### Pending Migrations 🔄
1. **HomeViewController** - Still heavily dependent on TaskManager singleton
2. **AddTaskViewController** - Mixed usage of both patterns
3. **Project Management** - ProjectManager still calls TaskManager directly
4. **Analytics & Charts** - Direct TaskManager dependencies remain

### Technical Debt & Refactoring Opportunities

#### 1. Singleton Dependencies
```swift
// Current (Legacy)
TaskManager.sharedInstance.toggleTaskComplete(task: task)

// Target (Dependency Injection)
class HomeViewController: TaskRepositoryDependent {
    var taskRepository: TaskRepository!
    // Use injected dependency
}
```

#### 2. Mixed Responsibilities
- TaskManager handles both data access AND business logic
- Should be split into separate concerns
- Business logic should move to Use Cases/Services

#### 3. Error Handling
```swift
// Legacy: Silent failures
TaskManager.sharedInstance.saveContext()

// Modern: Explicit error handling
taskRepository.addTask(data: taskData) { result in
    switch result {
    case .success: // Handle success
    case .failure(let error): // Handle error
    }
}
```

### Performance Considerations

#### TaskManager Optimizations
- Uses `NSFetchedResultsController` for efficient UI updates
- Implements lazy loading with computed properties
- Caches frequently accessed data

#### Repository Pattern Benefits
- Background context operations prevent UI blocking
- Better memory management with proper context handling
- Async operations with completion handlers

### Testing Strategy

#### Current Challenges
- Singleton pattern makes unit testing difficult
- Tight coupling to Core Data
- Hard to mock dependencies

#### Repository Pattern Advantages
```swift
// Mockable for testing
protocol TaskRepository {
    func fetchTasks(completion: @escaping ([TaskData]) -> Void)
}

class MockTaskRepository: TaskRepository {
    func fetchTasks(completion: @escaping ([TaskData]) -> Void) {
        completion([/* mock data */])
    }
}
```

### Refactored Architecture (2025 Update)

Tasker has undergone a comprehensive refactoring to improve maintainability, testability, and performance. This refactoring has been implemented in six phases:

#### Phase 1: Predicate-Driven Fetching & Removal of Stored Arrays ✅
- Core Data queries now use `NSPredicate` filtering for efficient data access
- Eliminated redundant memory storage of task arrays
- Improved memory usage and reduced data synchronization issues

#### Phase 2: Type-Safe Enums & Data Model Cleanup ✅
- Replaced raw integer constants with Swift enums (`TaskType`, `TaskPriority`)
- Core Data attributes aligned with enum raw values for type safety
- Added proper conversion between Int32 Core Data attributes and Swift enums

#### Phase 3: Protocol-Oriented Repository & Dependency Injection ✅
- Created `TaskRepository` protocol for data access abstraction
- Implemented `CoreDataTaskRepository` with background context operations
- Introduced `TaskData` struct to decouple UI from Core Data dependencies
- Added `DependencyContainer` for proper dependency injection

#### Phase 4: Concurrency & NSFetchedResultsController ✅
- Enhanced `CoreDataTaskRepository` with background context operations
- Implemented `NSFetchedResultsController` for efficient UI updates
- Added table view integration with swipe actions
- Improved UI responsiveness and memory efficiency

#### Phase 5: Utility Layers ✅
- Created comprehensive date extension utilities (`DateUtils.swift`)
- Implemented dedicated task scoring service (`TaskScoringService.swift`)
- Added structured logging system (`LoggingService.swift`)
- Improved code organization and reusability

#### Phase 6: SwiftUI Integration (Partial Implementation)
- `ProjectManagementView.swift` - SwiftUI implementation for project management
- `SettingsView.swift` - SwiftUI-based settings interface
- Hybrid UIKit/SwiftUI architecture for modern UI components
- SwiftUI integration in HomeViewController for hosting SwiftUI views

#### Phase 7: Testing & Quality Assurance (Minimal Implementation)
- Basic test file structure exists (`To_Do_ListTests.swift`, `To_Do_ListUITests.swift`)
- Test files contain placeholder templates without actual test implementations
- **Needs Implementation**: Unit tests for repositories and services
- **Needs Implementation**: Integration tests for Core Data implementation
- **Needs Implementation**: UI tests for critical user flows

#### 1. Data Layer
**Core Data Stack with CloudKit Integration**
- `NSPersistentCloudKitContainer` for automatic CloudKit synchronization
- Two main entities: `NTask` and `Projects`
- Automatic conflict resolution and data merging across devices

#### 2. Business Logic Layer
**Repositories & Services (Protocol-Oriented Design)**
- `TaskRepository` - Protocol defining task data operations
- `CoreDataTaskRepository` - Core Data implementation of TaskRepository
- `TaskScoringService` - Business logic for task scoring and analytics
- `DependencyContainer` - Service locator for dependency injection

**Legacy Manager Classes (Being Phased Out)**
- `TaskManager` - Original centralized task operations (being replaced by TaskRepository)
- `ProjectManager` - Project lifecycle management (future refactoring target)

#### 3. Presentation Layer
**View Controllers and Custom Views**
- Modular view controller design with specialized responsibilities
- Custom backdrop/foredrop view system for layered UI
- Reusable UI components with consistent theming

#### 4. Utility Layer
**Helper Classes and Extensions**
- `ToDoColors` - Centralized color theming system
- `ToDoFont` - Typography management
- `DateUtils` - Comprehensive date and time utilities
- `LoggingService` - Structured logging system with multiple levels
- `TaskScoringService` - Dedicated service for task scoring and analytics
- `ToDoTimeUtils` - Legacy time utilities (being migrated to DateUtils)

## Core Entities & Data Model

### NTask Entity
The primary task entity (`NTask`) stores all information related to a task. Its properties, defined in `NTask+CoreDataProperties.swift`, include:

```swift
@NSManaged public var name: String                    // Task title
@NSManaged public var isComplete: Bool                // Completion status
@NSManaged public var dueDate: NSDate?               // Due date for scheduling
@NSManaged public var taskDetails: String?           // Additional task description
@NSManaged public var taskPriority: Int32            // Priority level (stored as enum raw value)
@NSManaged public var taskType: Int32                // Category (stored as enum raw value)
@NSManaged public var project: String?               // Associated project name
@NSManaged public var alertReminderTime: NSDate?     // Notification scheduling
@NSManaged public var dateAdded: NSDate?             // Creation timestamp
@NSManaged public var isEveningTask: Bool            // Evening task flag
@NSManaged public var dateCompleted: NSDate?         // Completion timestamp
```

**Task Priority System (Type-Safe Enum):**
```swift
enum TaskPriority: Int32, CaseIterable {
    case highest = 1    // P0: 7 points
    case high = 2       // P1: 4 points
    case medium = 3     // P2: 3 points (default)
    case low = 4        // P3: 2 points
}
```

**Task Type Categories (Type-Safe Enum):**
```swift
enum TaskType: Int32, CaseIterable {
    case morning = 1    // Morning tasks
    case evening = 2    // Evening tasks
    case upcoming = 3   // Future-dated tasks
    case inbox = 4      // Uncategorized tasks
}
```

### NTask Extensions & Type-Safe Accessors

The `NTask+Extensions.swift` file provides type-safe computed properties and business logic:

```swift
// Type-safe enum accessors
extension NTask {
    var taskType: TaskType {
        get { TaskType(rawValue: self.taskType) ?? .morning }
        set { self.taskType = newValue.rawValue }
    }
    
    var taskPriority: TaskPriority {
        get { TaskPriority(rawValue: self.taskPriority) ?? .medium }
        set { self.taskPriority = newValue.rawValue }
    }
    
    // Computed properties for task categorization
    var isMorningTask: Bool {
        return taskType == .morning
    }
    
    var isUpcomingTask: Bool {
        return taskType == .upcoming
    }
    
    var isHighPriority: Bool {
        return taskPriority == .highest || taskPriority == .high
    }
    
    var isMediumPriority: Bool {
        return taskPriority == .medium
    }
    
    var isLowPriority: Bool {
        return taskPriority == .low
    }
    
    // Business logic for evening task management
    func updateEveningTaskStatus() {
        if taskType == .evening {
            isEveningTask = true
        } else {
            isEveningTask = false
        }
    }
}
```

### TaskData Presentation Model

The `TaskData.swift` struct serves as a clean presentation layer model:

```swift
struct TaskData {
    let id: UUID
    let name: String
    let details: String?
    let type: TaskType
    let priority: TaskPriority
    let dueDate: Date?
    let project: String?
    let isComplete: Bool
    let dateAdded: Date?
    let dateCompleted: Date?
    
    // Initializer from Core Data managed object
    init(from managedObject: NTask) {
        self.id = managedObject.objectID.uriRepresentation().absoluteString
        self.name = managedObject.name ?? ""
        self.details = managedObject.taskDetails
        self.type = TaskType(rawValue: managedObject.taskType) ?? .morning
        self.priority = TaskPriority(rawValue: managedObject.taskPriority) ?? .medium
        self.dueDate = managedObject.dueDate as Date?
        self.project = managedObject.project
        self.isComplete = managedObject.isComplete
        self.dateAdded = managedObject.dateAdded as Date?
        self.dateCompleted = managedObject.dateCompleted as Date?
    }
    
    // Initializer for new tasks
    init(name: String, details: String?, type: TaskType, priority: TaskPriority, 
         dueDate: Date?, project: String?) {
        self.id = UUID()
        self.name = name
        self.details = details
        self.type = type
        self.priority = priority
        self.dueDate = dueDate
        self.project = project
        self.isComplete = false
        self.dateAdded = Date()
        self.dateCompleted = nil
    }
}
```

### ToDoListViewType Enum

The view type system provides flexible list filtering:

```swift
enum ToDoListViewType {
    case todayHomeView      // Today's tasks
    case customDateView     // Tasks for specific date
    case projectView        // Tasks filtered by project
    case upcomingView       // Future tasks
    case historyView        // Completed tasks
    case allProjectsGrouped // All tasks grouped by project
    case selectedProjectsGrouped // Selected projects only
}
```

### Core Data Repository Pattern

The repository pattern abstracts data access:

```swift
class CoreDataTaskRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchTasks(for viewType: ToDoListViewType, date: Date? = nil, 
                   project: String? = nil) -> [TaskData] {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        switch viewType {
        case .todayHomeView:
            request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", 
                                          Calendar.current.startOfDay(for: Date()) as NSDate,
                                          Calendar.current.date(byAdding: .day, value: 1, 
                                          to: Calendar.current.startOfDay(for: Date()))! as NSDate)
        case .projectView:
            if let project = project {
                request.predicate = NSPredicate(format: "project == %@", project)
            }
        case .upcomingView:
            request.predicate = NSPredicate(format: "dueDate > %@", Date() as NSDate)
        case .historyView:
            request.predicate = NSPredicate(format: "isComplete == YES")
        default:
            break
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "taskPriority", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        
        do {
            let managedTasks = try context.fetch(request)
            return managedTasks.map { TaskData(from: $0) }
        } catch {
            print("Error fetching tasks: \(error)")
            return []
        }
    }
    
    func save(task: TaskData) throws {
        let managedTask = NTask(context: context)
        managedTask.name = task.name
        managedTask.taskDetails = task.details
        managedTask.taskType = task.type.rawValue
        managedTask.taskPriority = task.priority.rawValue
        managedTask.dueDate = task.dueDate as NSDate?
        managedTask.project = task.project
        managedTask.isComplete = task.isComplete
        managedTask.dateAdded = task.dateAdded as NSDate?
        managedTask.dateCompleted = task.dateCompleted as NSDate?
        
        try context.save()
    }
}
```

### Task Scoring Service

The scoring system calculates points based on priority and completion:

```swift
class TaskScoringService {
    static func calculateScore(for task: TaskData) -> Int {
        guard task.isComplete else { return 0 }
        
        switch task.priority {
        case .highest: return 7  // P0 tasks
        case .high: return 4     // P1 tasks
        case .medium: return 3   // P2 tasks (default)
        case .low: return 2      // P3 tasks
        }
    }
    
    static func calculateDailyScore(tasks: [TaskData]) -> Int {
        return tasks.reduce(0) { total, task in
            total + calculateScore(for: task)
        }
    }
    
    static func calculateWeeklyScore(tasks: [TaskData]) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        let weeklyTasks = tasks.filter { task in
            guard let completedDate = task.dateCompleted else { return false }
            return completedDate >= weekStart && completedDate <= now
        }
        
        return calculateDailyScore(tasks: weeklyTasks)
    }
}
```

### Core Data & Enum Integration

The refactored architecture properly handles the conversion between Core Data's `Int32` attributes and Swift enums:

**Converting from Enum to Int32 (when saving):**
```swift
// In CoreDataTaskRepository.swift
managed.taskType = data.type.rawValue     // Store enum's raw value
managed.taskPriority = data.priority.rawValue
```

**Converting from Int32 to Enum (when fetching):**
```swift
// In TaskData.swift initializer
self.type = TaskType(rawValue: managedObject.taskType) ?? .morning
self.priority = TaskPriority(rawValue: managedObject.taskPriority) ?? .medium
```

**Using Enum Values in Switch Statements:**
```swift
// In TaskCell.configure(with:) method
switch task.taskPriority {
case TaskPriority.high.rawValue:
    priorityIndicator.backgroundColor = .systemRed
// ...
}
```
- **Evening Tasks (2)**: Tasks scheduled for evening completion
- **Upcoming Tasks (3)**: Future-scheduled tasks
- **Inbox Tasks (4)**: Unscheduled/default category

### Projects Entity
Simple project organization structure:

```swift
@NSManaged public var projectName: String?           // Project identifier
@NSManaged public var projectDescription: String?     // Project description
```

**Default Project System:**
- "Inbox" serves as the default catch-all project
- Custom projects can be created for task organization
- Project-based task filtering and management

## Domain Logic & Business Rules

### Scoring System
The gamification core revolves around a sophisticated scoring algorithm:

```swift
func getTaskScore(task: NTask) -> Int {
    switch task.taskPriority {
    case 1: return 7  // P0 - Highest priority
    case 2: return 4  // P1 - High priority  
    case 3: return 3  // P2 - Medium priority
    case 4: return 2  // P3 - Low priority
    default: return 1 // Fallback
    }
}
```

### Task Management Rules
1. **Default Assignment**: New tasks default to P2 priority and morning type
2. **Project Association**: Tasks without explicit project assignment go to "Inbox"
3. **Completion Tracking**: `dateCompleted` timestamp enables historical analysis
4. **Evening Task Logic**: Special handling for evening-scheduled tasks

### Data Validation
- Project existence validation with automatic "Inbox" creation
- Task priority bounds checking (1-4 range)
- Date validation for scheduling and completion tracking

## Data Flow Architecture

### 1. Task Creation Flow
```
AddTaskViewController → TaskManager → Core Data → CloudKit
                    ↓
            UI Updates → HomeViewController
```

**Detailed Flow:**
1. User inputs task details in `AddTaskViewController`.
2. Task metadata (priority, project, type, dates) is collected.
3. `TaskManager.sharedInstance` is called to create a new `NTask` entity with the provided details.
4. The `TaskManager` saves the new task to the local Core Data store.
5. CloudKit automatically synchronizes the changes to other devices if connected.
6. The UI, typically in `HomeViewController` or the originating view, refreshes to display the newly added task.

### 2. Task Retrieval & Display Flow
```
HomeViewController → TaskManager → Core Data Fetch → UI Rendering
                 ↓
         Analytics Update → DGCharts Framework
```
**Detailed Flow:**
When `HomeViewController` needs to display tasks, it calls methods on `TaskManager` (e.g., `getMorningTasksForDate(date:)`). The `TaskManager` then constructs and executes an `NSFetchRequest` against the Core Data stack. The results (`[NTask]`) are returned to `HomeViewController`, which then processes this data to populate its UITableView. Similar flows occur for project filtering, where `ProjectManager` might be consulted first to get relevant projects before tasks are fetched.

**Filtering Logic:**
- **Date-based filtering**: Tasks for specific dates
- **Project-based filtering**: Tasks within specific projects
  - **All Projects View**: Group and display tasks by all available projects
  - **Multi-Project Selection**: Select multiple specific projects to filter tasks
  - **Single Project View**: Focus on tasks from one selected project
  - **Project Drawer Interface**: Access project filtering through the top drawer menu
- **Type-based filtering**: Morning, evening, upcoming, inbox categorization
- **Completion status filtering**: Active vs completed tasks

### 3. Analytics & Scoring Flow
```
Task Completion → Score Calculation → Chart Data Update → UI Refresh
              ↓
      Historical Data → Trend Analysis → Productivity Insights
```

### 4. Project Management Flow
```
ProjectManager → Projects Entity → Task Association → UI Organization
            ↓
    Default Project Validation → "Inbox" Creation if Missing
```

## Implemented Use Cases & User Workflows

### 🎯 **Core Task Management Use Cases**

#### **Daily Task Planning Workflow**
1. **Morning Planning**: Users start their day by reviewing tasks in the Home screen
2. **Task Prioritization**: Assign P0-P4 priorities based on urgency and importance
3. **Time-Based Scheduling**: Categorize tasks as Morning, Evening, or Upcoming
4. **Project Assignment**: Organize tasks into custom projects or default Inbox
5. **Progress Tracking**: Monitor completion through real-time scoring system

#### **Task Creation & Management Workflow**
1. **Quick Task Addition**: Use AddTaskViewController with Material Design text fields
2. **Rich Task Details**: Add descriptions, due dates, and priority levels
3. **Project Selection**: Choose from existing projects or create new ones
4. **Task Type Assignment**: Automatic categorization based on time preferences
5. **Validation & Saving**: Core Data repository ensures data integrity

#### **Task Completion & Scoring Workflow**
1. **Task Completion**: Mark tasks complete through FluentUI table cells
2. **Automatic Scoring**: Calculate points based on priority (P0: 7pts, P1: 4pts, P2: 3pts, P3: 2pts)
3. **Streak Tracking**: Maintain consecutive completion streaks up to 30 days
4. **Analytics Update**: Real-time dashboard updates with completion trends
5. **Gamification Feedback**: Visual feedback through charts and score displays

### 📁 **Project Management Use Cases**

#### **Project Organization Workflow**
1. **Project Creation**: Use ProjectManagementView to create custom project categories
2. **Task Assignment**: Assign tasks to projects during creation or editing
3. **Project Filtering**: View tasks filtered by specific projects
4. **Project Analytics**: Track completion rates and progress per project
5. **Project Management**: Edit, delete, or reorganize projects as needed

#### **Multi-Project Task Management**
1. **Cross-Project View**: See all tasks across projects in unified views
2. **Project Grouping**: Automatic grouping by project in FluentUIToDoTableViewController
3. **Project Switching**: Quick navigation between different project views
4. **Bulk Operations**: Manage multiple tasks within project contexts

### 📊 **Analytics & Insights Use Cases**

#### **Productivity Analysis Workflow**
1. **Daily Metrics**: View daily completion scores and task counts
2. **Trend Analysis**: Analyze productivity patterns through interactive charts
3. **Streak Monitoring**: Track consecutive completion days for motivation
4. **Performance Insights**: Identify peak productivity periods and patterns
5. **Goal Setting**: Use historical data to set realistic productivity goals

## Feature Implementation Details

### 🏠 **Home Screen (HomeViewController)**
The main dashboard provides comprehensive task management:
- **Daily Task Overview**: Today's tasks grouped by project with FluentUI styling
- **Interactive Analytics Charts**: DGCharts framework integration for visual productivity trends
- **Real-time Score Display**: Dynamic scoring with streak counter and daily totals
- **Quick Actions**: Fast access to task creation via floating action buttons
- **Calendar Integration**: FSCalendar for date-based task navigation
- **Search Functionality**: Real-time search across task titles and descriptions
- **PillButtonBar**: Custom segmented control for task type filtering

### 📋 **FluentUI Task List (FluentUIToDoTableViewController)**
Advanced table view implementation with Microsoft FluentUI components:
- **Custom Table Cells**: FluentUI-styled cells with priority indicators and due date displays
- **Project Grouping**: Automatic grouping by project including "Inbox" section
- **Priority Visual Indicators**: Color-coded priority badges (P0-P4) with appropriate icons
- **Overdue Detection**: Automatic highlighting of overdue tasks with visual cues
- **Swipe Actions**: Context menus for edit, delete, and reschedule operations
- **Accessibility Support**: VoiceOver and accessibility label integration
- **Pull-to-Refresh**: Real-time data synchronization with Core Data
- **Empty State Handling**: Elegant empty state views for projects without tasks

### 📝 **Task Details View (TaskDetailViewFluent)**
Comprehensive task editing interface:
- **FluentUI Components**: Native Microsoft FluentUI text fields, buttons, and controls
- **Rich Text Editing**: Multi-line description support with Material Design text areas
- **Priority Selection**: Visual priority picker with immediate feedback
- **Date Selection**: Integrated date picker for due date assignment
- **Project Assignment**: Dropdown selection for project categorization
- **Task Type Controls**: Segmented control for Morning/Evening/Upcoming classification
- **Validation Logic**: Real-time validation with error messaging
- **Auto-save Functionality**: Background saving with conflict resolution

### ➕ **Task Creation (AddTaskViewController)**
Streamlined task creation with advanced UI components:
- **Material Design Integration**: MDC text fields and floating action buttons
- **Smart Defaults**: Automatic project and priority assignment based on context
- **Calendar Integration**: FSCalendar for visual due date selection
- **Project Selection**: Dynamic project picker with "Add Project" functionality
- **Priority Assignment**: Visual priority selection with immediate preview
- **Task Type Toggle**: Evening task switch with automatic type assignment
- **Backdrop Design**: Layered UI design with backdrop and foredrop containers
- **Validation & Error Handling**: Comprehensive input validation with user feedback

### 📊 **Analytics & Visualization**
Comprehensive productivity insights powered by **DGCharts** (version 5.1):
- **Completion Trends**: Daily, weekly, and monthly completion rate charts with dynamic scaling
- **Priority Distribution**: Pie charts showing task priority patterns with TinyPieChart implementation
- **Project Performance**: Bar charts with per-project completion statistics
- **Streak Visualization**: Line charts tracking consecutive completion days with cubic Bezier smoothing
- **Score Progression**: Historical score tracking via TaskScoringService with trend analysis
- **Interactive Charts**: Touch-enabled charts with custom markers, balloon tooltips, and animations
- **Calendar Integration**: Charts synchronized with FSCalendar for weekly/monthly views
- **Real-time Updates**: Charts update automatically with NSFetchedResultsController integration

### 🗂️ **Project Management System (ProjectManagementView)**
Robust project organization with SwiftUI integration:
- **SwiftUI Interface**: Modern declarative UI for project management
- **CRUD Operations**: Create, read, update, delete operations for projects
- **Default Inbox System**: Automatic "Inbox" project for uncategorized tasks
- **Project Analytics**: Real-time completion statistics per project
- **Bulk Operations**: Multi-task project assignment and management
- **Project Validation**: Duplicate name prevention and validation rules
- **Context Menus**: Long-press menus for project editing and deletion
- **Search & Filter**: Project search functionality with real-time filtering

## FluentUI Components & Table Cell Architecture

### 🎨 **FluentUI Integration Details**

#### **FluentUI Table Cells (FluentUIToDoTableViewController)**
The app leverages Microsoft's FluentUI design system for a modern, accessible interface:

```swift
// Custom FluentUI table cell configuration
class FluentUIToDoTableViewController: UITableViewController {
    // FluentUI cell registration
    tableView.register(TableViewCell.self, forCellReuseIdentifier: "FluentUITaskCell")
    tableView.register(TableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "FluentUIHeader")
}
```

#### **Table Cell Components & Features**

**Priority Indicators:**
- **P0 (Highest)**: Red circle with "!!" icon, 7-point scoring
- **P1 (High)**: Orange circle with "!" icon, 4-point scoring  
- **P2 (Medium)**: Yellow circle with "-" icon, 3-point scoring
- **P3 (Low)**: Green circle with "↓" icon, 2-point scoring

**Due Date Display:**
- **Today**: Highlighted with "Today" label
- **Overdue**: Red text with warning indicators
- **Future**: Standard date formatting (MM/dd/yyyy)
- **No Due Date**: Graceful handling with placeholder text

**Task Status Indicators:**
- **Completion Checkboxes**: FluentUI-styled checkboxes with animation
- **Project Labels**: Color-coded project tags with rounded corners
- **Task Type Badges**: Morning/Evening/Upcoming visual indicators

#### **FluentUI Segmented Controls**
Task type selection using FluentUI SegmentedControl:

```swift
// FluentUI Segmented Control for task types
let segmentedControl = SegmentedControl(items: [
    SegmentItem(title: "Morning"),
    SegmentItem(title: "Evening"), 
    SegmentItem(title: "Upcoming"),
    SegmentItem(title: "Inbox")
])
```

#### **Material Design Integration**
Combination of FluentUI and Material Design Components:

**Text Fields:**
- `MDCFilledTextField` for task titles and descriptions
- `MDCOutlinedTextField` for secondary inputs
- Auto-validation with real-time error messaging

**Floating Action Buttons:**
- `MDCFloatingButton` for primary actions (Add Task, Save)
- Ripple effects with `MDCRippleTouchController`
- Consistent Material Design elevation and shadows

### 📱 **Table Cell View Architecture**

#### **Cell Hierarchy & Layout**

```
FluentUI TableViewCell
├── Content Stack View
│   ├── Priority Indicator View
│   │   ├── Priority Circle (Color-coded)
│   │   └── Priority Icon (Symbol)
│   ├── Task Content View
│   │   ├── Task Title Label
│   │   ├── Task Description Label (Optional)
│   │   └── Project Tag View
│   └── Accessory Stack View
│       ├── Due Date Label
│       ├── Overdue Warning Icon
│       └── Completion Checkbox
└── Separator View
```

#### **Cell State Management**

**Completion States:**
- **Pending**: Standard appearance with interactive elements
- **Completed**: Strikethrough text, muted colors, checkmark animation
- **Overdue**: Red accent colors, warning icons, urgent styling

**Interactive Elements:**
- **Swipe Actions**: Edit, Delete, Reschedule, Mark Complete
- **Long Press**: Context menu with additional options
- **Tap Gestures**: Navigate to task detail view
- **Checkbox Interaction**: Immediate completion toggle with animation

#### **Accessibility Features**

**VoiceOver Support:**
- Comprehensive accessibility labels for all UI elements
- Custom accessibility actions for swipe gestures
- Proper reading order and navigation

**Dynamic Type:**
- Automatic font scaling based on user preferences
- Responsive layout adjustments for larger text sizes
- Maintained visual hierarchy across all text sizes

### 🔄 **Data Binding & Updates**

#### **Real-time Data Synchronization**

```swift
// Core Data integration with table view updates
func setupTaskData(for date: Date) {
    let tasks = taskRepository.fetchTasks(for: date)
    let groupedTasks = Dictionary(grouping: tasks) { task in
        task.project ?? "Inbox"
    }
    
    DispatchQueue.main.async {
        self.tasksByProject = groupedTasks
        self.tableView.reloadData()
    }
}
```

#### **Performance Optimizations**
- **Cell Reuse**: Efficient cell dequeuing and configuration
- **Lazy Loading**: On-demand data fetching for large datasets
- **Background Processing**: Core Data operations on background contexts
- **Smooth Animations**: 60fps animations for state transitions

### 🎯 **Advanced Filtering & Search**

#### **Multi-Criteria Filtering System**
- **Project-based Views**: Filter tasks by specific projects with real-time updates
- **Date Range Filtering**: Custom date ranges with calendar picker integration
- **Priority Filtering**: Focus on high-priority items with visual emphasis
- **Completion Status**: Toggle between pending, completed, and all tasks
- **Search Integration**: Real-time search across task titles and descriptions

#### **View Type System**
Supports 7 different view modes through `ToDoListViewType` enum:
- `todayHomeView`: Today's tasks with priority grouping
- `customDateView`: Tasks for user-selected dates
- `projectView`: Single project task filtering
- `upcomingView`: Future tasks with due date sorting
- `historyView`: Completed tasks with completion date grouping
- `allProjectsGrouped`: All tasks grouped by project
- `selectedProjectsGrouped`: Multiple selected projects view

### Project Filtering System
**Multi-level Project Organization**
- **Filter Drawer Interface**: Accessible via the top drawer menu in `HomeViewController`
- **Project Selection Mechanisms**:
  - **All Projects View**: Groups tasks by project, displaying each project as a separate section
  - **Multi-Project Selection**: Uses a collection view of project pills that allows selecting multiple projects simultaneously
  - **Single Project View**: Focuses the view on tasks from one specific project
- **User Interaction Flow**:
  1. **Accessing Filters**: Tap the filter icon in the top navigation bar to open the drawer
  2. **All Projects View**: Select "Show All Projects" to see tasks grouped by project
  3. **Multi-Project Selection**: 
     - Tap on project pills in the selection view to select multiple projects
     - Selected projects are highlighted visually
     - Tap "Apply Filters" to view tasks from only the selected projects
  4. **Single Project View**: Tap on a project pill in the main interface to focus on that project
  5. **Clearing Filters**: Tap the X button to clear project filters and return to the default view
- **Implementation Details**:
  - `HomeDrawerFilterView.swift`: Contains the drawer UI with project filtering options
  - `ProjectPillCell.swift`: Custom collection view cell for project selection
  - `selectedProjectNamesForFilter`: Array in `HomeViewController` that tracks selected projects
  - `prepareAndFetchTasksForProjectGroupedView()`: Method that fetches and organizes tasks by project
  - View type management through `ToDoListViewType` enum (.allProjectsGrouped, .selectedProjectsGrouped, .projectView)
- **Project Data Flow**:
  - `ProjectManager` maintains the source of truth for projects with the `@Published projects` property
  - `displayedProjects` computed property ensures "Inbox" is always first in the list
  - Project selection state is maintained in `HomeViewController`
  - Task filtering by project is handled by `TaskManager` methods

**Key Components:**
- Score counter with dynamic font sizing
- Tiny pie chart for completion ratio visualization
- Line chart for historical productivity trends
- Project filter bar with dynamic project loading
- Task list with priority-based visual indicators

### Task Creation (`AddTaskViewController`)
**Comprehensive Task Input Interface**
- **Material Design Text Fields**: `MDCFilledTextField` for modern input experience
- **Priority Selection**: Segmented control for P0-P3 priority assignment
- **Project Assignment**: Dynamic project selection with "Add Project" capability
- **Date Scheduling**: Calendar picker for due date assignment
- **Evening Task Toggle**: Special categorization for evening tasks

**Validation & UX:**
- Real-time input validation
- Keyboard optimization for task entry
- Return key handling for quick task creation
- Cancel/save action handling

### Analytics & Visualization
**Multi-Chart Dashboard**

**Line Chart Implementation (DGCharts Framework):**
- Historical productivity trends
- Cubic Bezier curve smoothing for elegant visualization
- Custom color theming integration
- Interactive data point exploration

**Pie Chart Implementation:**
- Task completion ratio visualization
- Dynamic center text with score display
- Shadow effects for visual depth
- Responsive font sizing based on score magnitude

**Chart Data Flow:**
```swift
// Line Chart Data Generation
func updateLineChartData() {
    let dataSet = LineChartDataSet(entries: generateLineChartData(), label: "Score")
    // Styling and animation configuration
    lineChartView.data = LineChartData(dataSet: dataSet)
}

// Pie Chart Score Integration
func setTinyPieChartScoreText() -> NSAttributedString {
    let score = calculateTodaysScore()
    // Dynamic font sizing based on score
    // Color and styling application
}
```

### Project Management System
**Hierarchical Task Organization**

**Project Lifecycle:**
1. **Creation**: Dynamic project creation through UI
2. **Assignment**: Task-to-project association
3. **Filtering**: Project-based task views
4. **Management**: Project editing and deletion

**Default Project Handling:**
```swift
func fixMissingProjectsDataWithDefaults() {
    // Ensures "Inbox" project always exists
    // Handles missing project scenarios
    // Maintains data integrity
}
```

### CloudKit Integration
**Fully Implemented Multi-Device Synchronization**

**Configuration:**
```swift
lazy var persistentContainer: NSPersistentCloudKitContainer = {
    let container = NSPersistentCloudKitContainer(name: "TaskModel")
    
    guard let description = container.persistentStoreDescriptions.first else {
        fatalError("Failed to retrieve a persistent store description.")
    }
    
    // CloudKit container setup
    description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        containerIdentifier: "iCloud.TaskerCloudKit"
    )
    
    // Enable history tracking and remote notifications
    description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    
    return container
}()
```

**Sync Features:**
- **Container Identifier**: `iCloud.TaskerCloudKit` for dedicated CloudKit container
- **Remote Change Notifications**: Real-time sync with silent push notifications
- **History Tracking**: `NSPersistentHistoryTrackingKey` for robust sync conflict resolution
- **Merge Policy**: `NSMergeByPropertyStoreTrumpMergePolicy` for intelligent conflict handling
- **Background Sync**: Automatic merging of remote changes via `handlePersistentStoreRemoteChange`
- **Data Consolidation**: Post-sync validation and cleanup with ProjectManager and TaskManager
- **Offline Capability**: Local-first architecture with automatic sync on reconnection
- **Privacy-focused**: User data remains in their personal iCloud private database

### Theming & Design System
**Consistent Visual Identity**

**Color System (`ToDoColors`):**
```swift
var primaryColor = #colorLiteral(red: 0.5490196078, green: 0.5450980392, blue: 0.8196078431, alpha: 1)
var secondaryAccentColor = #colorLiteral(red: 0.9824339747, green: 0.5298179388, blue: 0.176022768, alpha: 1)
var completeTaskSwipeColor = UIColor(red: 46/255.0, green: 204/255.0, blue: 113/255.0, alpha: 1.0)
```

**Typography System (`ToDoFont`):**
- System font with design variants (rounded, monospaced)
- Consistent weight and sizing hierarchy
- Accessibility-compliant font scaling

## Dependencies & External Libraries

### Core Dependencies

```ruby
# Data Visualization
pod 'DGCharts', '~> 5.1' # Advanced charting capabilities (updated from Charts)

# UI Frameworks
pod 'MaterialComponents', '~> 124.2' # Material Design components
pod 'MicrosoftFluentUI', '~> 0.33.2' # Microsoft's design system

# Calendar & Date
pod 'FSCalendar', '~> 2.8.1' # Feature-rich calendar component
pod 'Timepiece', '~> 1.3.1' # Date manipulation utilities

# Animation & UI
pod 'ViewAnimator', '~> 3.1' # View animation utilities
pod 'TinyConstraints', '~> 4.0.1' # Auto Layout helper
pod 'SemiModalViewController', '~> 1.0.1' # Modal presentation styles

# Firebase Suite
pod 'Firebase/Analytics', '~> 11.13' # User analytics
pod 'Firebase/Crashlytics', '~> 11.13' # Crash reporting
pod 'Firebase/Performance', '~> 11.13' # Performance monitoring
```

### Current Architecture Benefits
1.  **Scalability**: Modular design allows easy feature additions.
2.  **Maintainability**: Clear separation of concerns.
3.  **Testability**: Manager classes enable unit testing (though this can be improved).
4.  **Performance**: Efficient Core Data queries with CloudKit optimization.
5.  **User Experience**: Smooth animations and responsive UI.

## Development Workflow

### Build Configuration
- **Minimum iOS Version**: 13.0
- **Development Environment**: Xcode with Swift 5+
- **Dependency Management**: CocoaPods
- **Cloud Services**: CloudKit for data sync, Firebase for analytics

**Firebase Usage:**
Firebase is initialized in `AppDelegate` and is primarily used for backend services like analytics (tracking user interactions and feature usage), crash reporting (Crashlytics), and performance monitoring, helping to improve app stability and understand user behavior.

### Code Organization
```
Tasker/
├── To Do List/              # Main application code
│   ├── Models/              # Core Data entities (NTask, Projects)
│   ├── Repositories/        # Repository pattern implementation
│   │   ├── TaskRepository.swift
│   │   └── CoreDataTaskRepository.swift
│   ├── Services/            # Business logic services
│   │   └── TaskScoringService.swift
│   ├── Managers/            # Legacy manager classes
│   │   ├── TaskManager.swift
│   │   ├── ProjectManager.swift
│   │   └── DependencyContainer.swift
│   ├── ViewControllers/     # Screen controllers
│   │   ├── HomeViewController.swift
│   │   ├── AddTaskViewController.swift
│   │   ├── TaskListViewController.swift
│   │   └── ProjectManagementViewController.swift
│   ├── View/                # Custom UI components
│   │   ├── ProjectManagementView.swift (SwiftUI)
│   │   └── Theme components
│   ├── Utils/               # Helper utilities
│   │   ├── DateUtils.swift
│   │   ├── LoggingService.swift
│   │   └── ToDoTimeUtils.swift
│   └── Storyboards/         # Interface Builder files
└── Resources/              # Assets and configurations
```

This architecture ensures Tasker delivers a robust, scalable, and delightful task management experience while maintaining code quality and development efficiency.

## Project Structure

The Tasker project follows a hybrid architecture combining MVC patterns with Repository pattern and dependency injection:

```
To Do List/
├── Assets/                     # App icons, images, and visual assets
├── Managers/                   # Core business logic managers
│   ├── TaskManager.swift       # Task operations and business logic
│   ├── ProjectManager.swift    # Project management functionality
│   └── DependencyContainer.swift # Dependency injection container
├── Model/                      # Core Data model files
│   └── TaskModel.xcdatamodeld  # Core Data schema
├── Models/                     # Data models and entities
│   ├── TaskData.swift          # Task presentation model
│   ├── ToDoListViewType.swift  # View type enumeration
│   └── TaskType/Priority enums # Task categorization
├── Repositories/               # Data access layer
│   ├── TaskRepository.swift    # Task repository protocol
│   └── CoreDataTaskRepository.swift # Core Data implementation
├── Services/                   # Business services
│   ├── TaskScoringService.swift # Task scoring algorithms
│   └── NotificationService.swift # Push notification handling
├── Utils/                      # Utility classes and extensions
│   ├── DateUtils.swift         # Date manipulation utilities
│   └── Core Data Models/       # NTask entity and extensions
├── View/                       # Custom UI components
│   ├── Charts/                 # Chart components and formatters
│   ├── Animation/              # Chart and UI animations
│   └── Theme/                  # Color schemes and typography
├── ViewControllers/            # MVC view controllers
│   ├── HomeViewController.swift # Main dashboard
│   ├── TaskListViewController.swift # Task list management
│   └── AddTask/                # Task creation interfaces
└── Storyboards/                # Interface Builder files
    └── Main.storyboard         # Primary UI layout

Demo Projects:
├── FSCalendarSwiftExample/     # Calendar component demo
└── FluentUI.Demo/              # Microsoft FluentUI showcase

Configuration:
├── Podfile                     # CocoaPods dependencies
├── Podfile.lock               # Locked dependency versions
└── *.xcworkspace              # Xcode workspace files
```

## Screenshots

![001](https://user-images.githubusercontent.com/4607881/84248757-81eba600-ab27-11ea-9b9e-bab409a6fedc.gif)

![002](https://user-images.githubusercontent.com/4607881/84248763-84e69680-ab27-11ea-986a-82ec6419916e.gif)

![003](https://user-images.githubusercontent.com/4607881/84249030-dc850200-ab27-11ea-9736-7eaa6979bc3d.gif)

![004](https://user-images.githubusercontent.com/4607881/84249226-1e15ad00-ab28-11ea-85c3-27f5320bcab1.gif)

## Path to Clean Architecture

### Current State and Future Direction
Tasker is currently in a transitional phase, evolving from a traditional MVC architecture to Clean Architecture principles. This migration is being implemented incrementally to maintain stability while improving code organization and testability.

### Introduction to Clean Architecture
Clean Architecture is a software design philosophy that separates concerns into distinct, concentric layers. It emphasizes independence from frameworks, UI, database, and external agencies. The core idea is that business logic and application logic should stand at the center, with dependencies pointing inwards.

**Core Principles:**
-   **Entities:** Represent enterprise-wide business rules and data structures. They are the most general and high-level rules and are typically plain Swift objects or structs, having no knowledge of other layers.
-   **Use Cases (Interactors):** Contain application-specific business rules. They orchestrate the flow of data to and from Entities and direct those Entities to use their critical business rules to achieve the goals of the use case.
-   **Interface Adapters:** This layer converts data from the format most convenient for Use Cases and Entities to the format most convenient for external agencies like the UI or database. This includes Presenters, ViewModels, and Controllers (in an MVC context adapted for Clean Architecture).
-   **Frameworks & Drivers:** The outermost layer consists of frameworks and tools such as the Database (e.g., Core Data), the UI (e.g., UIKit), and external interfaces. This layer is where all the details go.

**Benefits:**
Adopting Clean Architecture can lead to systems that are:
-   **Independent of Frameworks:** The core business logic is not tied to specific frameworks.
-   **Testable:** Business rules can be tested without the UI, Database, Web Server, or any other external element.
-   **Independent of UI:** The UI can change easily, without changing the rest of the system.
-   **Independent of Database:** You can swap out Oracle or SQL Server for Mongo, BigTable, or CouchDB. Your business rules are not bound to the database.
-   **Maintainable & Scalable:** Changes in one area are less likely to impact others, making the system easier to maintain and scale.

### Proposed Layers for Tasker (Clean Architecture)

Here's a potential structure for Tasker if it were to adopt Clean Architecture:

#### 1. Domain Layer
This is the core of the application, containing the enterprise-wide and application-specific business rules.
-   **Entities:**
    *   Plain Swift structs/classes representing `CleanTask` and `CleanProject`. These would be independent of Core Data.
        *   Example: `struct CleanTask { let id: UUID; var name: String; var priority: Int; var isCompleted: Bool; var dueDate: Date?; ... }`
        *   Example: `struct CleanProject { let id: UUID; var name: String; var description: String?; ... }`
    *   **Use Cases (Interactors):**
        *   Classes that encapsulate specific application actions and orchestrate data flow using Entities.
        *   Examples:
            *   `AddTaskUseCase(taskRepository: TaskRepositoryProtocol)`
            *   `CompleteTaskUseCase(taskRepository: TaskRepositoryProtocol, scoringService: ScoringServiceProtocol)`
            *   `GetTasksForDateUseCase(taskRepository: TaskRepositoryProtocol)`
            *   `CalculateDailyScoreUseCase(taskRepository: TaskRepositoryProtocol)` // Could also be part of a broader `ScoringService`
            *   `ManageProjectUseCase(projectRepository: ProjectRepositoryProtocol)` // For creating, updating, deleting projects
    *   **Repository Protocols:**
        *   Abstract interfaces defining data operations for entities. These protocols are owned by the Domain layer.
        *   Example: `protocol TaskRepositoryProtocol { func getAllTasks() async throws -> [CleanTask]; func getTask(byId id: UUID) async throws -> CleanTask?; func save(task: CleanTask) async throws; func delete(taskId: UUID) async throws; ... }`
        *   Example: `protocol ProjectRepositoryProtocol { func getAllProjects() async throws -> [CleanProject]; func save(project: CleanProject) async throws; ... }`

#### 2. Data Layer (Infrastructure)
This layer is responsible for data persistence and retrieval, implementing the repository protocols defined in the Domain layer.
-   **Repositories (Implementations):**
    *   `CoreDataTaskRepository(context: NSManagedObjectContext): TaskRepositoryProtocol`: This class would handle fetching `NTask` (Core Data managed objects) and mapping them to/from `CleanTask` domain entities. It would also manage saving `CleanTask` entities back to Core Data.
    *   `CoreDataProjectRepository(context: NSManagedObjectContext): ProjectRepositoryProtocol`: Similar responsibilities for `Projects` and `CleanProject` entities.
-   **Data Sources:**
    *   Direct interaction with Core Data (`NSPersistentCloudKitContainer`).
    *   CloudKit synchronization would continue to be managed by Core Data's `NSPersistentCloudKitContainer`. The Data layer abstracts these details away from the Domain layer, meaning the Use Cases are unaware of Core Data or CloudKit.
-   **Mappers:**
    *   Utility functions or structs responsible for converting data between Core Data `NSManagedObject`s (e.g., `NTask`) and Domain `Entities` (e.g., `CleanTask`), and vice-versa.

#### 3. Presentation Layer (e.g., MVVM - Model-View-ViewModel)
This layer is responsible for presenting data to the user and handling user interactions.
-   **ViewModels:** (e.g., `HomeViewModel`, `AddTaskViewModel`, `ProjectListViewModel`)
    *   Each ViewModel would own and call relevant Use Cases to fetch or modify data.
    *   They transform data received from Use Cases into a format suitable for display (e.g., formatting dates, calculating progress percentages for UI elements).
    *   They expose data to the Views, often using reactive programming frameworks like Combine or RxSwift, or through simple observable properties with callbacks.
    *   Handle user input by invoking appropriate Use Cases.
-   **Views (ViewControllers & Custom Views):**
    *   Would become significantly thinner and more focused on UI responsibilities.
    *   Display data provided by their respective ViewModels.
    *   Forward user input and events to their ViewModels.
    *   Contain minimal to no business logic or direct data access. `HomeViewController`, for example, would delegate most of its current responsibilities to a `HomeViewModel`.

#### 4. Dependency Injection
-   A mechanism for constructing and providing dependencies throughout the application would be essential.
-   This could be achieved through:
    *   **Manual Dependency Injection:** Passing dependencies through initializers (constructor injection) or properties (property injection).
    *   **DI Containers:** Using libraries like Swinject or Factory to manage dependencies and their lifetimes.
-   Example: An `AddTaskViewModel` would receive an `AddTaskUseCase` instance, which in turn would have received a `CoreDataTaskRepository` (conforming to `TaskRepositoryProtocol`) instance.

### Key Refactoring Steps & Considerations

Migrating Tasker to a Clean Architecture would be a significant undertaking. Here are some key steps and considerations:

-   **Define Domain Entities:** Start by defining the pure Swift `CleanTask` and `CleanProject` structs/classes. These will form the core of your Domain layer.
-   **Define Repository Protocols:** Create the `TaskRepositoryProtocol` and `ProjectRepositoryProtocol` in the Domain layer.
-   **Implement Data Layer Repositories:**
    *   Create `CoreDataTaskRepository` and `CoreDataProjectRepository`.
    *   Implement data mapping functions to convert between Core Data `NTask`/`Projects` and `CleanTask`/`CleanProject` entities. This is a critical step for decoupling.
-   **Identify and Implement Use Cases:**
    *   Break down the existing functionality of `TaskManager` and `ProjectManager` into specific Use Cases.
    *   For example, `TaskManager.createTask(...)` could become `AddTaskUseCase.execute(taskData: ...)`.
    *   Scoring logic could be encapsulated within specific Use Cases or a dedicated `ScoringService` in the Domain layer.
-   **Refactor ViewControllers to use ViewModels (MVVM):**
    *   **`HomeViewController`:** This would be a major refactoring target.
        *   Introduce a `HomeViewModel`.
        *   The ViewModel would use Use Cases like `GetTasksForDateUseCase`, `GetProjectsUseCase`, and `CalculateDailyScoreUseCase`.
        *   The ViewController would observe the ViewModel for data to display (tasks, projects, score, chart data) and forward user actions (date changes, project selection) to the ViewModel.
    *   **`AddTaskViewController`:**
        *   Introduce an `AddTaskViewModel`.
        *   The ViewModel would use an `AddTaskUseCase` and potentially a `ManageProjectUseCase` (for fetching projects for selection or adding new ones).
-   **Decouple Managers:**
    *   The existing `TaskManager` and `ProjectManager` singletons mix data access, business rules, and sometimes state management. Their responsibilities need to be carefully disentangled:
        *   Data fetching and persistence logic moves to the Repository implementations in the Data Layer.
        *   Application-specific business rules (e.g., task validation, setting default values) move to Use Cases in the Domain Layer.
        *   Cross-cutting concerns like scoring, if complex, might become their own services within the Domain Layer, injected into Use Cases.
-   **Establish Dependency Injection:** Choose a DI strategy (manual or container) and apply it consistently to provide dependencies to Use Cases, Repositories, and ViewModels.
-   **Incremental Adoption:**
    *   It's highly recommended to adopt Clean Architecture incrementally rather than attempting a "big bang" refactor.
    *   Start with one feature or a small part of the application (e.g., the task creation flow or the display of morning tasks). Refactor this slice fully to the new architecture.
    *   This allows the team to learn and adapt, and provides value sooner.
-   **Testing:**
    *   A major driver for Clean Architecture is improved testability.
    *   **Domain Layer:** Entities and Use Cases can be unit tested in isolation. Use Cases can be tested by providing mock repository implementations.
    *   **Presentation Layer:** ViewModels can be unit tested by mocking the Use Cases they depend on.
    *   **Data Layer:** Repositories can be integration tested against a test Core Data stack.

By following these steps, Tasker can transition towards a more robust, maintainable, and testable architecture, better equipped for future growth and changes.
