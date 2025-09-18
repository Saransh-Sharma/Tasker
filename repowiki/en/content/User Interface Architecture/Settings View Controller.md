# Settings View Controller

<cite>
**Referenced Files in This Document**   
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift)
- [ThemeSelectionCell.swift](file://To%20Do%20List/ViewControllers/Settings/ThemeSelectionCell.swift)
- [ToDoColors.swift](file://To%20Do%20List/View/Theme/ToDoColors.swift)
- [ProjectManager.swift](file://To%20Do%20List/ViewControllers/ProjectManager.swift)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)

## Introduction
The `SettingsPageViewController` is a central interface in the Tasker application responsible for managing user preferences and app configuration. It provides users with control over appearance settings such as dark mode and custom themes, access to LLM-related features, project management, and app metadata. The controller dynamically updates its UI based on user interactions and system events, ensuring a responsive and consistent experience across device states and themes. This document details the implementation, architecture, and integration points of the `SettingsPageViewController`, focusing on its role in handling user settings, theme management, and navigation.

## Project Structure
The `SettingsPageViewController` resides within the ViewControllers directory and interacts with several key components including theme management, project data handling, and LLM configuration. It uses a modular structure with embedded view controllers and custom UI components to deliver a cohesive settings experience.

```mermaid
graph TB
SettingsPageViewController --> ThemeSelectionCell
SettingsPageViewController --> ProjectManagementViewControllerEmbedded
SettingsPageViewController --> ToDoColors
SettingsPageViewController --> ProjectManager
ThemeSelectionCell --> ThemeCardCell
ProjectManagementViewControllerEmbedded --> ProjectManager
```

**Diagram sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)
- [ThemeSelectionCell.swift](file://To%20Do%20List/ViewControllers/Settings/ThemeSelectionCell.swift#L1-L129)
- [ToDoColors.swift](file://To%20Do%20List/View/Theme/ToDoColors.swift#L1-L158)
- [ProjectManager.swift](file://To%20Do%20List/ViewControllers/ProjectManager.swift#L1-L338)

**Section sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)

## Core Components
The `SettingsPageViewController` manages user preferences through a table-based interface, utilizing structured data models (`SettingsItem` and `SettingsSection`) to organize settings into logical groups. It handles dynamic content such as version display, theme switching, and navigation to sub-settings. The controller integrates with `UserDefaults` via the `ToDoColors` class to persist theme selections and responds to system-wide trait changes for dark mode. Custom cells like `ThemeSelectionCell` enable rich, interactive elements within the table view.

**Section sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)
- [ToDoColors.swift](file://To%20Do%20List/View/Theme/ToDoColors.swift#L1-L158)

## Architecture Overview
The `SettingsPageViewController` follows a MVC (Model-View-Controller) pattern, delegating data management to model classes like `ProjectManager` and `AppManager`, while maintaining responsibility for UI presentation and user interaction. It uses `UITableView` as its primary interface component, with custom cell types for specialized functionality. The architecture emphasizes separation of concerns, with distinct sections handling appearance, LLM settings, and project management.

```mermaid
classDiagram
class SettingsPageViewController {
+sections : [SettingsSection]
+setupTableView()
+setupSettingsSections()
+toggleDarkMode()
+navigateToThemeSelection()
}
class SettingsSection {
+title : String?
+items : [SettingsItem]
}
class SettingsItem {
+title : String
+iconName : String?
+action : (() -> Void)?
+detailText : String?
}
class ThemeSelectionCell {
+collectionView : UICollectionView
+configureCollectionView()
}
class ToDoColors {
+themes : [Theme]
+currentIndex : Int
+setTheme(index : Int)
}
class ProjectManager {
+projects : [Projects]
+displayedProjects : [Projects]
+addNewProject()
+updateProject()
+deleteProject()
}
SettingsPageViewController --> SettingsSection : "contains"
SettingsSection --> SettingsItem : "contains"
SettingsPageViewController --> ThemeSelectionCell : "uses"
SettingsPageViewController --> ToDoColors : "depends on"
SettingsPageViewController --> ProjectManager : "uses"
ThemeSelectionCell --> ThemeCardCell : "delegates"
ToDoColors --> UserDefaults : "persists"
```

**Diagram sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)
- [ThemeSelectionCell.swift](file://To%20Do%20List/ViewControllers/Settings/ThemeSelectionCell.swift#L1-L129)
- [ToDoColors.swift](file://To%20Do%20List/View/Theme/ToDoColors.swift#L1-L158)
- [ProjectManager.swift](file://To%20Do%20List/ViewControllers/ProjectManager.swift#L1-L338)

## Detailed Component Analysis

### SettingsPageViewController Analysis
The `SettingsPageViewController` serves as the main entry point for user configuration in Tasker. It organizes settings into sections such as Appearance, LLM Settings, and About, each containing actionable items represented by `SettingsItem` instances. The controller dynamically generates these items based on current app state, such as displaying the appropriate dark mode toggle text and icon.

#### For Object-Oriented Components:
```mermaid
classDiagram
class SettingsPageViewController {
-settingsTableView : UITableView
-sections : [SettingsSection]
-isDarkMode : Bool
+viewDidLoad()
+viewWillAppear()
+setupTableView()
+setupSettingsSections()
+toggleDarkMode()
+showVersionInfo()
}
class SettingsSection {
+title : String?
+items : [SettingsItem]
}
class SettingsItem {
+title : String
+iconName : String?
+action : (() -> Void)?
+detailText : String?
}
SettingsPageViewController --> SettingsSection : "owns"
SettingsSection --> SettingsItem : "contains"
```

**Diagram sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)

#### For API/Service Components:
```mermaid
sequenceDiagram
participant User
participant SettingsVC as SettingsPageViewController
participant ToDoColors as ToDoColors
participant UserDefaults as UserDefaults
User->>SettingsVC : Taps Dark Mode toggle
SettingsVC->>SettingsVC : toggleDarkMode()
SettingsVC->>SettingsVC : isDarkMode = !isDarkMode
SettingsVC->>SettingsVC : Apply UIUserInterfaceStyle
SettingsVC->>SettingsVC : setupSettingsSections()
SettingsVC->>SettingsVC : settingsTableView.reloadData()
User->>SettingsVC : Selects theme from picker
SettingsVC->>ThemeSelectionCell : didSelectItemAt
ThemeSelectionCell->>ToDoColors : setTheme(index)
ToDoColors->>UserDefaults : Save index
ToDoColors->>NotificationCenter : Post themeChanged
NotificationCenter->>SettingsVC : themeChanged()
SettingsVC->>SettingsVC : settingsTableView.reloadData()
```

**Diagram sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)
- [ThemeSelectionCell.swift](file://To%20Do%20List/ViewControllers/Settings/ThemeSelectionCell.swift#L1-L129)
- [ToDoColors.swift](file://To%20Do%20List/View/Theme/ToDoColors.swift#L1-L158)

#### For Complex Logic Components:
```mermaid
flowchart TD
Start([SettingsPageViewController.viewDidLoad]) --> SetupNav["Setup Navigation Title and Done Button"]
SetupNav --> CheckDarkMode["Check Current Dark Mode State"]
CheckDarkMode --> CreateTableView["Create and Configure UITableView"]
CreateTableView --> SetupData["Call setupSettingsSections()"]
SetupData --> DefineSections["Define Settings Sections"]
DefineSections --> DynamicTitle["Set Dynamic Mode Title and Icon"]
DynamicTitle --> AssignData["Assign sections array"]
AssignData --> Complete["View Ready for Display"]
ViewAppear([SettingsPageViewController.viewWillAppear]) --> AddObserver["Add themeChanged Observer"]
AddObserver --> RefreshData["Call setupSettingsSections()"]
RefreshData --> ReloadTable["Reload TableView Data"]
ToggleDarkMode([User Toggles Dark Mode]) --> InvertState["Invert isDarkMode Flag"]
InvertState --> ApplyStyle["Apply UIUserInterfaceStyle to All Windows"]
ApplyStyle --> ShowToast["Show Confirmation Alert"]
ShowToast --> UpdateUI["Call setupSettingsSections() and reloadData()"]
```

**Diagram sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)

**Section sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)

### Theme Selection Cell Analysis
The `ThemeSelectionCell` provides a horizontal scrollable interface for selecting color themes within the settings. It uses a `UICollectionView` embedded within a `UITableViewCell` to display theme options as cards, each representing a different color scheme.

#### For Object-Oriented Components:
```mermaid
classDiagram
class ThemeSelectionCell {
-collectionView : UICollectionView
-themes : [Theme]
-currentIndex : Int
+configureCollectionView()
+themeChanged()
}
class ThemeCardCell {
-primaryView : UIView
-secondaryView : UIView
+configure(primary : UIColor, secondary : UIColor, selected : Bool)
}
class ToDoColors {
+themes : [Theme]
+currentIndex : Int
+setTheme(index : Int)
}
ThemeSelectionCell --> ThemeCardCell : "delegates rendering"
ThemeSelectionCell --> ToDoColors : "reads themes and index"
ThemeSelectionCell --> NotificationCenter : "listens for themeChanged"
```

**Diagram sources**
- [ThemeSelectionCell.swift](file://To%20Do%20List/ViewControllers/Settings/ThemeSelectionCell.swift#L1-L129)
- [ToDoColors.swift](file://To%20Do%20List/View/Theme/ToDoColors.swift#L1-L158)

**Section sources**
- [ThemeSelectionCell.swift](file://To%20Do%20List/ViewControllers/Settings/ThemeSelectionCell.swift#L1-L129)

## Dependency Analysis
The `SettingsPageViewController` has well-defined dependencies on several key components that enable its functionality. These dependencies are managed through direct instantiation or singleton access patterns.

```mermaid
graph TD
SettingsPageViewController --> AppManager
SettingsPageViewController --> ToDoColors
SettingsPageViewController --> ProjectManager
SettingsPageViewController --> TaskManager
SettingsPageViewController --> ThemeSelectionCell
ThemeSelectionCell --> ToDoColors
ThemeSelectionCell --> ThemeCardCell
ProjectManager --> CoreData
ProjectManager --> UserDefaults
SettingsPageViewController --> UIHostingController
SettingsPageViewController --> UIAlertController
```

**Diagram sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)
- [ThemeSelectionCell.swift](file://To%20Do%20List/ViewControllers/Settings/ThemeSelectionCell.swift#L1-L129)
- [ToDoColors.swift](file://To%20Do%20List/View/Theme/ToDoColors.swift#L1-L158)
- [ProjectManager.swift](file://To%20Do%20List/ViewControllers/ProjectManager.swift#L1-L338)

**Section sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)
- [ThemeSelectionCell.swift](file://To%20Do%20List/ViewControllers/Settings/ThemeSelectionCell.swift#L1-L129)
- [ToDoColors.swift](file://To%20Do%20List/View/Theme/ToDoColors.swift#L1-L158)
- [ProjectManager.swift](file://To%20Do%20List/ViewControllers/ProjectManager.swift#L1-L338)

## Performance Considerations
The `SettingsPageViewController` maintains good performance through efficient data management and UI updates. It avoids unnecessary Core Data fetches by relying on the `ProjectManager`'s published properties and only refreshes data when necessary. The use of `UITableView` with cell reuse ensures memory efficiency, while the embedded `UICollectionView` in `ThemeSelectionCell` is optimized with proper constraints and layout configuration. Theme changes are broadcast via `NotificationCenter`, allowing for targeted UI updates without full view reloads where possible.

## Troubleshooting Guide
Common issues with the `SettingsPageViewController` typically involve theme persistence, UI responsiveness, or navigation failures. Ensure that `UserDefaults` writes are successful by verifying the `selectedThemeIndex` key. Confirm that `NotificationCenter` observers are properly added and removed in `viewWillAppear` and `viewWillDisappear` to prevent memory leaks or missed updates. For display issues with the theme picker, verify that the `ThemeSelectionCell` constraints are correctly applied and that the collection view's data source methods are properly implemented.

**Section sources**
- [SettingsPageViewController.swift](file://To%20Do%20List/ViewControllers/SettingsPageViewController.swift#L1-L562)
- [ThemeSelectionCell.swift](file://To%20Do%20List/ViewControllers/Settings/ThemeSelectionCell.swift#L1-L129)
- [ToDoColors.swift](file://To%20Do%20List/View/Theme/ToDoColors.swift#L1-L158)

## Conclusion
The `SettingsPageViewController` effectively serves as the central hub for user configuration in Tasker, providing a clean, organized interface for managing app preferences. Its integration with `UserDefaults` through `ToDoColors` enables persistent theme selection, while its modular design allows for extensible settings sections. The controller demonstrates effective use of iOS design patterns including MVC, delegation, and notification-based updates. By leveraging `UITableView` with custom cells and embedded view controllers, it delivers a rich user experience while maintaining code organization and performance.