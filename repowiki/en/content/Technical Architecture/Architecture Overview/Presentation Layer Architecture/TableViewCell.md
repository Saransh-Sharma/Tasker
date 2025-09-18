# TableViewCell

<cite>
**Referenced Files in This Document**   
- [FluentUIToDoTableViewController.swift](file://To%20Do%20List/ViewControllers/FluentUIToDoTableViewController.swift)
- [TableViewCell Sample Data.swift](file://To%20Do%20List/ViewControllers/TableViewCell%20Sample%20Data.swift)
- [README.md](file://README.md)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Design and Layout](#design-and-layout)
3. [Data Binding and Task State Management](#data-binding-and-task-state-management)
4. [UI Framework Integration](#ui-framework-integration)
5. [Cell Reuse and Performance](#cell-reuse-and-performance)
6. [Dynamic Content and Accessibility](#dynamic-content-and-accessibility)
7. [Customization and Gesture Support](#customization-and-gesture-support)

## Introduction

The TableViewCell is a custom `UITableViewCell` subclass used in the Tasker application to render individual tasks within a `UITableView`. It serves as the primary visual representation of a task, displaying key information such as task name, description, due date, priority, and completion status. The cell is designed to be reusable, efficient, and visually consistent with the app’s overall design language, which combines Microsoft FluentUI and Google’s Material Design Components.

This document provides a comprehensive overview of the TableViewCell’s architecture, functionality, and integration within the Tasker app, based on analysis of the project’s source code and documentation.

**Section sources**
- [README.md](file://README.md#L1124-L1168)

## Design and Layout

The TableViewCell follows a structured layout hierarchy built using stack views to ensure responsive and consistent rendering across different device sizes and content variations. The visual hierarchy is as follows:

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

The cell uses a combination of leading and trailing accessory views to display metadata such as due dates and priority indicators. The completion checkbox is implemented as a custom `UIButton` with a circular border and dynamic checkmark image, styled to match FluentUI guidelines.

The layout supports multiple configurations:
- **Single-line cells** for minimal tasks
- **Double-line cells** with title and description
- **Triple-line cells** with additional metadata
- **Empty state cells** with placeholder text and icons

**Section sources**
- [README.md](file://README.md#L1124-L1168)
- [TableViewCell Sample Data.swift](file://To%20Do%20List/ViewControllers/TableViewCell%20Sample%20Data.swift#L0-L301)

## Data Binding and Task State Management

The TableViewCell binds to `NTask` model objects, which represent individual tasks in the app’s Core Data store. The binding is managed indirectly through the `FluentUIToDoTableViewController`, which configures each cell during `cellForRowAt` by extracting data from the `NTask` instance.

### Task State Representation

The cell visually reflects the following task states:

**Completion States:**
- **Pending**: Standard appearance with interactive elements
- **Completed**: Strikethrough text, muted colors, and checkmark animation
- **Overdue**: Red accent colors, warning icons, and urgent styling

### Data Binding Process

The `FluentUIToDoTableViewController` configures each cell using the `setup` method, which accepts:
- `title`: Task name
- `subtitle`: Task description
- `attributedTitle` and `attributedSubtitle`: For styled text (e.g., strikethrough)
- `customView`: Completion checkbox
- `accessoryType`: None, disclosure indicator, or checkmark

```swift
cell.setup(
    title: taskTitle,
    subtitle: taskSubtitle,
    customView: checkBox,
    accessoryType: .none
)
```

For completed tasks, attributed strings with strikethrough attributes are used:

```swift
let attributedTitle = NSAttributedString(
    string: task.name ?? "Untitled Task",
    attributes: [
        .font: fluentTheme.typography(.body1),
        .foregroundColor: fluentTheme.color(.foreground2),
        .strikethroughStyle: NSUnderlineStyle.single.rawValue
    ]
)
```

**Section sources**
- [FluentUIToDoTableViewController.swift](file://To%20Do%20List/ViewControllers/FluentUIToDoTableViewController.swift#L400-L600)

## UI Framework Integration

The TableViewCell integrates two major UI frameworks to achieve a cohesive design:

### FluentUI Integration

The cell is part of the `MicrosoftFluentUI` framework, which provides:
- Consistent typography and color theming
- Pre-styled components like `Label`, `SegmentedControl`, and `TableViewCell`
- Dynamic type support for accessibility
- Built-in support for dark mode and high contrast

The cell uses `fluentTheme` to access typography and color styles:

```swift
cell.backgroundColor = fluentTheme.color(.background1)
```

### Material Design Components

The app also uses `MaterialComponents` for specific UI elements:
- `MDCFloatingButton` for primary actions
- `MDCFilledTextField` for task editing
- Ripple touch effects via `MDCRippleTouchController`

This hybrid approach allows the app to leverage FluentUI’s modern, clean aesthetics while maintaining Material Design’s tactile feedback and elevation principles.

**Section sources**
- [README.md](file://README.md#L1092-L1122)
- [FluentUIToDoTableViewController.swift](file://To%20Do%20List/ViewControllers/FluentUIToDoTableViewController.swift#L0-L199)

## Cell Reuse and Performance

The TableViewCell is optimized for performance through several mechanisms:

### Cell Reuse

The cell is registered with the table view using a reusable identifier:

```swift
tableView.register(TableViewCell.self, forCellReuseIdentifier: TableViewCell.identifier)
```

During `cellForRowAt`, cells are dequeued and reconfigured rather than created anew, minimizing memory allocation and layout overhead.

### Efficient Reconfiguration

Instead of recreating the checkbox for each cell, the `reconfigureCell(at:)` method attempts to reuse existing checkbox instances:

```swift
var existingCheckBox: UIButton?
if let accessoryView = cell.accessoryView {
    // Search for existing checkbox
}
```

If no existing checkbox is found, a new one is created and attached.

### Smooth Animations

State transitions, such as checkbox toggling, are animated at 60fps:

```swift
UIView.animate(withDuration: 0.7) {
    checkBox.backgroundColor = isComplete ? UIColor.clear : UIColor.clear
    checkBox.setImage(isComplete ? checkmarkImage : nil, for: .normal)
}
```

### Background Processing

Data fetching is performed on background threads using `TaskManager`, with UI updates dispatched to the main queue:

```swift
DispatchQueue.main.async {
    self.toDoData = sections
    self.tableView.reloadData()
}
```

**Section sources**
- [FluentUIToDoTableViewController.swift](file://To%20Do%20List/ViewControllers/FluentUIToDoTableViewController.swift#L400-L600)
- [README.md](file://README.md#L1170-L1207)

## Dynamic Content and Accessibility

The TableViewCell supports dynamic content sizing and comprehensive accessibility features.

### Dynamic Sizing

The cell uses Auto Layout with compression resistance and content hugging priorities to handle variable-length text. Labels can wrap or truncate based on configuration:

```swift
label.numberOfLines = 0 // Allows wrapping
label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
```

### Accessibility Features

The cell provides full VoiceOver support:
- Comprehensive accessibility labels for all UI elements
- Custom accessibility actions for swipe gestures
- Proper reading order and navigation

Due dates and priority levels are announced clearly, and the completion checkbox has appropriate accessibility traits.

**Section sources**
- [README.md](file://README.md#L1124-L1168)
- [TableViewCell Sample Data.swift](file://To%20Do%20List/ViewControllers/TableViewCell%20Sample%20Data.swift#L0-L301)

## Customization and Gesture Support

The TableViewCell supports multiple customization options and gesture interactions.

### Swipe-to-Dismiss

The cell supports both leading and trailing swipe actions:

- **Leading Swipe (Left to Right)**:
  - Reschedule (blue)
  - Delete (red)

- **Trailing Swipe (Right to Left)**:
  - Mark Complete (green, for pending tasks)
  - Reopen (orange, for completed tasks)

These are implemented using `UISwipeActionsConfiguration`:

```swift
override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
```

### Tap and Long Press

- **Tap**: Navigates to task detail view via semi-modal presentation
- **Long Press**: Triggers context menu with additional options (not fully implemented in current code)

### Task Type Customization

The cell can be customized for different task types (Morning, Evening, Upcoming, Inbox) through the `ToDoListViewType` enum, which affects filtering and sorting but not visual appearance directly.

**Section sources**
- [FluentUIToDoTableViewController.swift](file://To%20Do%20List/ViewControllers/FluentUIToDoTableViewController.swift#L600-L800)