# Tasker - Gamified Tasks & Productivity Pulse

Tasker is a sophisticated iOS productivity application that transforms task management into an engaging, gamified experience. Built with Swift and UIKit, it combines modern iOS design patterns with powerful productivity features including CloudKit synchronization, advanced analytics, and a comprehensive scoring system.

## Key Features

- **Gamified Task Management**: Transform productivity into a game with a scoring system based on task priority and completion.
- **Smart Task Organization**: Create, organize, and prioritize tasks with intelligent categorization.
- **Project-Based Workflow**: Manage tasks through custom projects with a dedicated project management system.
- **Advanced Analytics**: Detailed productivity analysis through interactive charts and visualizations.
- **CloudKit Synchronization**: Seamless task sync across all your Apple devices.
- **Daily Productivity Pulse**: Real-time motivation through dynamic scoring and progress tracking.
- **Flexible Task Scheduling**: Support for morning, evening, upcoming, and inbox task categorization.
- **Priority-Based Scoring**: Intelligent scoring system that rewards high-priority task completion.
- **Modern UI/UX**: Material Design components with FluentUI integration for a polished user experience.

---
| ![app_store](https://user-images.githubusercontent.com/4607881/123705006-fbb21700-d883-11eb-9c32-7c201067bf08.png)  | [App Store Link](https://apps.apple.com/app/id1574046107) | ![Tasker v1 0 0](https://user-images.githubusercontent.com/4607881/123707145-e4285d80-d886-11eb-8868-13d257fab8f4.gif) |
| ------------- | ------------- | --------|
---

## Installation
- Run `pod install` on project directory ([CocoaPods Installation](https://guides.cocoapods.org/using/getting-started.html))
- Open `Tasker.xcworkspace`
- Build & run, enjoy

## Project Architecture

### Overview
Tasker follows a **Model-View-Controller (MVC)** architecture pattern with additional manager classes for business logic separation. The app is built using:

- **Core Data** with **CloudKit** integration for data persistence and synchronization
- **Material Design Components** and **FluentUI** for modern UI components
- **Charts framework** for advanced data visualization
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

#### 1. Data Layer
**Core Data Stack with CloudKit Integration**
- `NSPersistentCloudKitContainer` for automatic CloudKit synchronization
- Two main entities: `NTask` and `Projects`
- Automatic conflict resolution and data merging across devices

#### 2. Business Logic Layer
**Manager Classes (Singleton Pattern)**
- `TaskManager` - Centralized task operations and data fetching
- `ProjectManager` - Project lifecycle management and organization
- Separation of concerns for maintainable codebase

#### 3. Presentation Layer
**View Controllers and Custom Views**
- Modular view controller design with specialized responsibilities
- Custom backdrop/foredrop view system for layered UI
- Reusable UI components with consistent theming

#### 4. Utility Layer
**Helper Classes and Extensions**
- `ToDoColors` - Centralized color theming system
- `ToDoFont` - Typography management
- `ToDoTimeUtils` - Date and time formatting utilities

## Core Entities & Data Model

### NTask Entity
The primary task entity (`NTask`) stores all information related to a task. Its properties, defined in `NTask+CoreDataProperties.swift`, include:

```swift
@NSManaged public var name: String                    // Task title
@NSManaged public var isComplete: Bool                // Completion status
@NSManaged public var dueDate: NSDate?               // Due date for scheduling
@NSManaged public var taskDetails: String?           // Additional task description
@NSManaged public var taskPriority: Int32            // Priority level (1-4: P0-P3)
@NSManaged public var taskType: Int32                // Category (1: morning, 2: evening, 3: upcoming, 4: inbox)
@NSManaged public var project: String?               // Associated project name
@NSManaged public var alertReminderTime: NSDate?     // Notification scheduling
@NSManaged public var dateAdded: NSDate?             // Creation timestamp
@NSManaged public var isEveningTask: Bool            // Evening task flag
@NSManaged public var dateCompleted: NSDate?         // Completion timestamp
```

**Task Priority System:**
- **P0 (Priority 1)**: Highest priority - 7 points
- **P1 (Priority 2)**: High priority - 4 points
- **P2 (Priority 3)**: Medium priority - 3 points (default)
- **P3 (Priority 4)**: Low priority - 2 points

**Task Type Categories:**
- **Morning Tasks (1)**: Tasks scheduled for morning completion
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
         Analytics Update → Charts Framework
```
**Detailed Flow:**
When `HomeViewController` needs to display tasks, it calls methods on `TaskManager` (e.g., `getMorningTasksForDate(date:)`). The `TaskManager` then constructs and executes an `NSFetchRequest` against the Core Data stack. The results (`[NTask]`) are returned to `HomeViewController`, which then processes this data to populate its UITableView. Similar flows occur for project filtering, where `ProjectManager` might be consulted first to get relevant projects before tasks are fetched.

**Filtering Logic:**
- **Date-based filtering**: Tasks for specific dates
- **Project-based filtering**: Tasks within specific projects
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

## Feature Implementation Details

### Home Screen (`HomeViewController`)
**Primary Interface Hub**
- **Backdrop/Foredrop Architecture**: Layered UI system for depth and visual hierarchy
- **Dynamic Scoring Display**: Real-time score calculation and prominent display
- **Interactive Charts**: Line charts and pie charts for productivity visualization
- **Calendar Integration**: `FSCalendar` for date-based task navigation
- **Project Filtering**: Pill-button interface for project-based task filtering

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

**Line Chart Implementation:**
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
**Seamless Multi-Device Synchronization**

**Configuration:**
```swift
lazy var persistentContainer: NSPersistentCloudKitContainer = {
    let container = NSPersistentCloudKitContainer(name: "TaskModel")
    // CloudKit container configuration
    // Automatic sync setup
    return container
}()
```

**Sync Features:**
- Automatic background synchronization
- Conflict resolution handling
- Offline capability with sync on reconnection
- Privacy-focused private database usage

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
pod 'Charts', '~> 3.5.0' # Advanced charting capabilities

# UI Frameworks
pod 'MaterialComponents', '~> 109.2.0' # Material Design components
pod 'MicrosoftFluentUI', '~> 0.1.0' # Microsoft's design system

# Calendar & Date
pod 'FSCalendar', '~> 2.8.1' # Feature-rich calendar component
pod 'Timepiece', '~> 1.3.1' # Date manipulation utilities

# Animation & UI
pod 'ViewAnimator', '~> 2.7.0' # View animation utilities
pod 'TinyConstraints', '~> 4.0.1' # Auto Layout helper
pod 'SemiModalViewController', '~> 1.0.1' # Modal presentation styles

# Firebase Suite
pod 'Firebase/Analytics' # User analytics
pod 'Firebase/Crashlytics' # Crash reporting
pod 'Firebase/Performance' # Performance monitoring
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
├── Model/                    # Core Data entities
├── View/                     # Custom UI components
│   ├── Theme/               # Design system
│   └── Animation/           # Animation utilities
├── ViewControllers/         # Screen controllers
│   ├── Charts/             # Analytics implementation
│   └── Delegates/          # Protocol implementations
├── Utils/                   # Helper utilities
└── Resources/              # Assets and configurations
```

This architecture ensures Tasker delivers a robust, scalable, and delightful task management experience while maintaining code quality and development efficiency.

## Screenshots

![001](https://user-images.githubusercontent.com/4607881/84248757-81eba600-ab27-11ea-9b9e-bab409a6fedc.gif)

![002](https://user-images.githubusercontent.com/4607881/84248763-84e69680-ab27-11ea-986a-82ec6419916e.gif)

![003](https://user-images.githubusercontent.com/4607881/84249030-dc850200-ab27-11ea-9736-7eaa6979bc3d.gif)

![004](https://user-images.githubusercontent.com/4607881/84249226-1e15ad00-ab28-11ea-85c3-27f5320bcab1.gif)

## Path to Clean Architecture

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
