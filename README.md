# Tasker - Gamified Tasks & Productivity Pulse

Tasker is a sophisticated iOS productivity application that transforms task management into an engaging, gamified experience. Built with Swift and UIKit, it combines modern iOS design patterns with powerful productivity features including CloudKit synchronization, advanced analytics, and a comprehensive scoring system.

## Key Features

• **Gamified Task Management** - Transform productivity into a game with scoring system based on task priority and completion
• **Smart Task Organization** - Create, organize, and prioritize tasks with intelligent categorization
• **Project-Based Workflow** - Manage tasks through custom projects with dedicated project management system
• **Advanced Analytics** - Detailed productivity analysis through interactive charts and visualizations
• **CloudKit Synchronization** - Seamless task sync across all your Apple devices
• **Daily Productivity Pulse** - Real-time motivation through dynamic scoring and progress tracking
• **Flexible Task Scheduling** - Support for morning, evening, upcoming, and inbox task categorization
• **Priority-Based Scoring** - Intelligent scoring system that rewards high-priority task completion
• **Modern UI/UX** - Material Design components with FluentUI integration for polished user experience

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
The primary task entity with comprehensive metadata:

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
@NSManaged public var projecDescription: String?     // Project description
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
1. User inputs task details in `AddTaskViewController`
2. Task metadata collected (priority, project, type, dates)
3. `TaskManager.sharedInstance` creates new `NTask` entity
4. Core Data saves to local store
5. CloudKit automatically syncs across devices
6. UI refreshes to display new task

### 2. Task Retrieval & Display Flow
```
HomeViewController → TaskManager → Core Data Fetch → UI Rendering
                 ↓
         Analytics Update → Charts Framework
```

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
func fixMissingProjecsDataWithDefaults() {
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
pod 'Charts', '~> 3.5.0'                    # Advanced charting capabilities

# UI Frameworks  
pod 'MaterialComponents', '~> 109.2.0'      # Material Design components
pod 'MicrosoftFluentUI', '~> 0.1.0'         # Microsoft's design system

# Calendar & Date
pod 'FSCalendar', '~> 2.8.1'               # Feature-rich calendar component
pod 'Timepiece', '~> 1.3.1'                # Date manipulation utilities

# Animation & UI
pod 'ViewAnimator', '~> 2.7.0'              # View animation utilities
pod 'TinyConstraints', '~> 4.0.1'           # Auto Layout helper
pod 'SemiModalViewController', '~> 1.0.1'   # Modal presentation styles

# Firebase Suite
pod 'Firebase/Analytics'                    # User analytics
pod 'Firebase/Crashlytics'                  # Crash reporting
pod 'Firebase/Performance'                  # Performance monitoring
```

### Architecture Benefits
1. **Scalability**: Modular design allows easy feature additions
2. **Maintainability**: Clear separation of concerns
3. **Testability**: Manager classes enable unit testing
4. **Performance**: Efficient Core Data queries with CloudKit optimization
5. **User Experience**: Smooth animations and responsive UI

## Development Workflow

### Build Configuration
- **Minimum iOS Version**: 13.0
- **Development Environment**: Xcode with Swift 5+
- **Dependency Management**: CocoaPods
- **Cloud Services**: CloudKit for data sync, Firebase for analytics

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
