# Third-Party UI Libraries

<cite>
**Referenced Files in This Document**   
- [Podfile](file://Podfile)
- [TinyPieChart.swift](file://To%20Do%20List/ViewControllers/Charts/TinyPieChart.swift)
- [BalloonMarker.swift](file://To%20Do%20List/ViewControllers/Charts/BalloonMarker.swift)
- [HomeViewController+LegacyChartShims.swift](file://To%20Do%20List/ViewControllers/HomeViewController+LegacyChartShims.swift)
- [HomeCalendarExtention.swift](file://To%20Do%20List/ViewControllers/Delegates/HomeCalendarExtention.swift)
- [AddTaskCalendarExtention.swift](file://To%20Do%20List/ViewControllers/Delegates/AddTaskCalendarExtention.swift)
- [FluentUIToDoTableViewController.swift](file://To%20Do%20List/ViewControllers/FluentUIToDoTableViewController.swift)
- [AddTaskViewController.swift](file://To%20Do%20List/ViewControllers/AddTaskViewController.swift)
</cite>

## Table of Contents
1. [DGCharts Integration](#dgcharts-integration)
2. [CircleMenu Implementation](#circlemenu-implementation)
3. [FluentUI Components](#fluentui-components)
4. [FSCalendar Usage](#fscalendar-usage)
5. [SemiModalViewController](#semimodalviewcontroller)

## DGCharts Integration

DGCharts (version 5.1) is used for rendering task completion analytics and scoring visualizations in Tasker. The library is integrated primarily through the `TinyPieChart` component for displaying daily scores and productivity metrics. The pie chart visualization is configured with custom theming to match the app's design system, including hole radius percentage of 0.60, custom shadow effects, and center text formatting that dynamically adjusts font size based on score magnitude.

The chart data binding follows a delegation pattern where the `HomeViewController` updates the chart data through the `updateTinyPieChartData` method, which generates entries from task completion data. Custom markers using the `BalloonMarker` class provide interactive tooltips when users tap on data points, enhancing the user experience with contextual information. The library supports real-time updates synchronized with Core Data changes through NSFetchedResultsController integration, ensuring charts reflect the latest task completion status.

Accessibility considerations include proper contrast ratios for color-coded data segments and support for VoiceOver to announce chart values. Performance optimization is achieved by limiting the number of data entries and using efficient data structures for score calculations. The library's animation capabilities are utilized to create engaging visual feedback, such as spinning animations when the pie chart is updated.

**Section sources**
- [Podfile](file://Podfile#L17)
- [TinyPieChart.swift](file://To%20Do%20List/ViewControllers/Charts/TinyPieChart.swift#L1-L160)
- [BalloonMarker.swift](file://To%20Do%20List/ViewControllers/Charts/BalloonMarker.swift#L1-L208)
- [HomeViewController+LegacyChartShims.swift](file://To%20Do%20List/ViewControllers/HomeViewController+LegacyChartShims.swift#L1-L40)

## CircleMenu Implementation

CircleMenu (version 4.1.0) provides radial menu interactions for navigation shortcuts and task creation workflows. The library is implemented as a circular button menu that expands to reveal multiple action items arranged in a radial pattern. Each menu item represents a specific task creation or navigation function, allowing users to quickly access frequently used features.

The menu customization includes configurable button colors, icons, and animation timing to match the app's visual identity. The radial layout optimizes screen space usage while maintaining intuitive gesture-based interactions. Menu items can be dynamically updated based on context, such as showing different options when creating morning versus evening tasks.

Accessibility features include sufficient touch target sizes and support for assistive technologies to navigate the menu items sequentially. Performance considerations involve lazy loading of menu content and efficient animation rendering to maintain 60fps during interactions. The library integrates with the app's dependency injection system to receive configuration parameters and communicate selection events back to the parent view controller.

**Section sources**
- [Podfile](file://Podfile#L16)

## FluentUI Components

FluentUI (version 0.33.2) provides navigation components and consistent interface elements across view controllers in Tasker. The library is extensively used in the `FluentUIToDoTableViewController` for creating table cells with priority indicators, due date displays, and project grouping. Custom table cells implement Microsoft's Fluent Design System with consistent typography, spacing, and color schemes.

Key components include `TableViewCell` for task listings, `SegmentedControl` for task type selection (Morning/Evening/Upcoming), and various FluentUI-styled buttons and controls. The implementation combines FluentUI components with Material Design elements from the MaterialComponents library, creating a hybrid interface that leverages the strengths of both design systems.

Accessibility support includes comprehensive VoiceOver labels, proper reading order, and support for dynamic type scaling. The components are optimized for performance through efficient cell reuse in table views and lazy loading of content. Theming is consistent across the application, with color and typography settings synchronized between FluentUI and the app's custom `ToDoColors` and `ToDoFont` systems.

**Section sources**
- [Podfile](file://Podfile#L19)
- [FluentUIToDoTableViewController.swift](file://To%20Do%20List/ViewControllers/FluentUIToDoTableViewController.swift#L1-L1492)

## FSCalendar Usage

FSCalendar (version 2.8.1) is implemented for date selection and task scheduling throughout the application. The library is integrated in both the `HomeViewController` and `AddTaskViewController` to provide visual calendar interfaces for selecting due dates and navigating between days. The calendar is configured with custom theming to match the app's design, including white text on dark purple backgrounds, red weekend indicators, and custom selection styling.

The implementation includes subtitle support that displays the number of tasks for each date, providing at-a-glance productivity insights. Event handling is implemented through delegate methods that respond to date selection, updating the task list and analytics views accordingly. When a user selects a date, the app filters tasks for that day and recalculates the daily score, ensuring all views remain synchronized.

Accessibility features include proper VoiceOver support for calendar navigation and date announcements. Performance optimizations include limiting the visible date range and efficient cell reuse. The calendar supports both week and month view modes, with smooth transitions between them. Integration with Core Data ensures that task counts are updated in real-time as tasks are created or completed.

**Section sources**
- [Podfile](file://Podfile#L18)
- [HomeCalendarExtention.swift](file://To%20Do%20List/ViewControllers/Delegates/HomeCalendarExtention.swift#L1-L233)
- [AddTaskCalendarExtention.swift](file://To%20Do%20List/ViewControllers/Delegates/AddTaskCalendarExtention.swift#L1-L86)

## SemiModalViewController

SemiModalViewController (version 1.0.1) is used for presenting non-blocking modal interfaces such as task details and settings. The library enables the presentation of modal views that occupy only part of the screen, allowing users to maintain context with the underlying content. This approach is particularly effective for task editing, where users can view and modify task details without losing sight of the main task list.

The presentation logic is implemented in the `FluentUIToDoTableViewController` where tapping a task cell presents a semi-modal view containing task metadata, description, project assignment, and priority selection controls. The modal includes a drag indicator for dismissal and supports both tap and swipe gestures to close. Dismissal callbacks are implemented to refresh the parent view when changes are saved, ensuring data consistency.

Customization options include configurable height, animation duration, and background dimming level. Accessibility considerations include proper focus management and support for assistive technologies to navigate modal content. Performance is optimized by reusing modal view controllers and minimizing layout calculations during presentation and dismissal animations.

**Section sources**
- [Podfile](file://Podfile#L15)
- [FluentUIToDoTableViewController.swift](file://To%20Do%20List/ViewControllers/FluentUIToDoTableViewController.swift#L1-L1492)
- [AddTaskViewController.swift](file://To%20Do%20List/ViewControllers/AddTaskViewController.swift#L1-L518)