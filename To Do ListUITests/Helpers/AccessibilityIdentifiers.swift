//
//  AccessibilityIdentifiers.swift
//  To Do ListUITests
//
//  Centralized accessibility identifiers for UI testing
//  NOTE: These identifiers need to be added to the actual UI elements in the app
//

import Foundation

enum AccessibilityIdentifiers {

    // MARK: - Home Screen

    enum Home {
        static let view = "home.view"
        static let addTaskButton = "home.addTaskButton"
        static let morningTasksList = "home.morningTasksList"
        static let eveningTasksList = "home.eveningTasksList"
        static let dailyScoreLabel = "home.dailyScoreLabel"
        static let streakLabel = "home.streakLabel"
        static let completionRateLabel = "home.completionRateLabel"
        static let datePicker = "home.datePicker"
        static let searchButton = "home.searchButton"
        static let inboxButton = "home.inboxButton"
        static let settingsButton = "home.settingsButton"
        static let projectFilterButton = "home.focus.menu.button"
        static let quickFilterMenuButton = "home.focus.menu.button"
        static let quickFilterMenuContainer = "home.focus.menu.container"
        static let quickFilterMenuAdvancedButton = "home.focus.menu.advanced"
        static let quickFilterGroupingPrioritizeOverdue = "home.focus.grouping.prioritizeOverdue"
        static let quickFilterGroupingGroupByProjects = "home.focus.grouping.groupByProjects"
        static let focusStrip = "home.focus.strip"
        static let chartView = "home.chartView"
        static let navXpPieChart = "home.navXpPieChart"
        static let taskListScrollView = "home.taskList.scrollView"

        // Task Cell
        static func taskCell(index: Int) -> String { "home.taskCell.\(index)" }
        static func taskCheckbox(index: Int) -> String { "home.taskCheckbox.\(index)" }
        static func taskTitle(index: Int) -> String { "home.taskTitle.\(index)" }
        static func taskPriority(index: Int) -> String { "home.taskPriority.\(index)" }
        static func taskProject(index: Int) -> String { "home.taskProject.\(index)" }
    }

    // MARK: - Add Task Screen

    enum AddTask {
        static let view = "addTask.view"
        static let titleField = "addTask.titleField"
        static let descriptionField = "addTask.descriptionField"
        static let prioritySegmentedControl = "addTask.prioritySegmentedControl"
        static let dueDatePicker = "addTask.dueDatePicker"
        static let dueDateButton = "addTask.dueDateButton"
        static let projectPicker = "addTask.projectPicker"
        static let projectPillContainer = "addTask.projectPillContainer"
        static let taskTypeSelector = "addTask.taskTypeSelector"
        static let morningButton = "addTask.morningButton"
        static let eveningButton = "addTask.eveningButton"
        static let upcomingButton = "addTask.upcomingButton"
        static let reminderToggle = "addTask.reminderToggle"
        static let reminderTimePicker = "addTask.reminderTimePicker"
        static let saveButton = "addTask.saveButton"
        static let cancelButton = "addTask.cancelButton"

        // Validation
        static let titleError = "addTask.titleError"
        static let descriptionError = "addTask.descriptionError"

        // Project Pills
        static func projectPill(projectId: String) -> String { "addTask.projectPill.\(projectId)" }
    }

    // MARK: - Task Detail Screen

    enum TaskDetail {
        static let view = "taskDetail.view"
        static let titleField = "taskDetail.titleField"
        static let descriptionField = "taskDetail.descriptionField"
        static let priorityControl = "taskDetail.priorityControl"
        static let dueDateLabel = "taskDetail.dueDateLabel"
        static let projectLabel = "taskDetail.projectLabel"
        static let completeButton = "taskDetail.completeButton"
        static let deleteButton = "taskDetail.deleteButton"
        static let saveButton = "taskDetail.saveButton"
        static let closeButton = "taskDetail.closeButton"
        static let editButton = "taskDetail.editButton"
    }

    // MARK: - Inbox Screen

    enum Inbox {
        static let view = "inbox.view"
        static let tasksList = "inbox.tasksList"
        static let emptyStateLabel = "inbox.emptyStateLabel"
        static let taskCount = "inbox.taskCount"
    }

    // MARK: - Weekly View Screen

    enum Weekly {
        static let view = "weekly.view"
        static let tasksList = "weekly.tasksList"
        static let weekSelector = "weekly.weekSelector"
        static let previousWeekButton = "weekly.previousWeekButton"
        static let nextWeekButton = "weekly.nextWeekButton"
    }

    // MARK: - Upcoming Tasks Screen

    enum Upcoming {
        static let view = "upcoming.view"
        static let tasksList = "upcoming.tasksList"
        static let emptyStateLabel = "upcoming.emptyStateLabel"
    }

    // MARK: - Settings Screen

    enum Settings {
        static let view = "settings.view"
        static let navigationBar = "Settings"
        static let doneButton = "Done"
        static let projectManagementRow = "Project Management"
        static let llmSettingsRow = "LLM Settings"
        static let appearanceRow = "Appearance"
        static let darkModeToggle = "settings.darkModeToggle"
        static let appVersionLabel = "settings.appVersionLabel"
        static let aboutSection = "settings.aboutSection"
    }

    // MARK: - Project Management Screen

    enum ProjectManagement {
        static let view = "projectManagement.view"
        static let navigationBar = "Projects"
        static let addProjectButton = "projectManagement.addProjectButton"
        static let projectsList = "projectManagement.projectsList"
        static let emptyStateLabel = "projectManagement.emptyStateLabel"

        // Project Cell
        static func projectCell(index: Int) -> String { "projectManagement.projectCell.\(index)" }
        static func projectName(index: Int) -> String { "projectManagement.projectName.\(index)" }
        static func projectTaskCount(index: Int) -> String { "projectManagement.projectTaskCount.\(index)" }
        static func projectColor(index: Int) -> String { "projectManagement.projectColor.\(index)" }
    }

    // MARK: - New Project Screen

    enum NewProject {
        static let view = "newProject.view"
        static let nameField = "newProject.nameField"
        static let descriptionField = "newProject.descriptionField"
        static let colorPicker = "newProject.colorPicker"
        static let iconPicker = "newProject.iconPicker"
        static let saveButton = "newProject.saveButton"
        static let cancelButton = "newProject.cancelButton"

        // Validation
        static let nameError = "newProject.nameError"
    }

    // MARK: - Search Screen

    enum Search {
        static let view = "search.view"
        static let searchField = "search.searchField"
        static let resultsList = "search.resultsList"
        static let emptyStateLabel = "search.emptyStateLabel"
        static let clearButton = "search.clearButton"
        static let cancelButton = "search.cancelButton"
    }

    // MARK: - Analytics Screen

    enum Analytics {
        static let view = "analytics.view"
        static let radarChart = "analytics.radarChart"
        static let dailyScoreLabel = "analytics.dailyScoreLabel"
        static let weeklyScoreLabel = "analytics.weeklyScoreLabel"
        static let monthlyScoreLabel = "analytics.monthlyScoreLabel"
        static let streakLabel = "analytics.streakLabel"
        static let completionRateLabel = "analytics.completionRateLabel"
        static let productivityTrendChart = "analytics.productivityTrendChart"
    }

    // MARK: - LLM Settings Screen

    enum LLMSettings {
        static let view = "llmSettings.view"
        static let modelsSettingsRow = "llmSettings.modelsSettingsRow"
        static let chatsSettingsRow = "llmSettings.chatsSettingsRow"
        static let creditsRow = "llmSettings.creditsRow"
    }

    // MARK: - Tab Bar

    enum TabBar {
        static let home = "Home"
        static let inbox = "Inbox"
        static let weekly = "Weekly"
        static let upcoming = "Upcoming"
        static let settings = "Settings"
    }

    // MARK: - Common Elements

    enum Common {
        static let backButton = "Back"
        static let doneButton = "Done"
        static let cancelButton = "Cancel"
        static let saveButton = "Save"
        static let deleteButton = "Delete"
        static let editButton = "Edit"
        static let closeButton = "Close"

        // Alerts
        static let alertTitle = "alert.title"
        static let alertMessage = "alert.message"
        static let alertOKButton = "OK"
        static let alertCancelButton = "Cancel"
        static let alertDeleteButton = "Delete"

        // Loading
        static let loadingIndicator = "common.loadingIndicator"
        static let loadingMessage = "common.loadingMessage"
    }

    // MARK: - Priority Labels

    enum Priority {
        static let none = "None"
        static let low = "Low"      // P3
        static let medium = "Medium" // P2
        static let high = "High"    // P1
        static let max = "Max"      // P0
    }

    // MARK: - Task Type Labels

    enum TaskType {
        static let morning = "Morning"
        static let evening = "Evening"
        static let upcoming = "Upcoming"
        static let inbox = "Inbox"
    }

    // MARK: - Project Constants

    enum ProjectConstants {
        static let inboxProjectID = "00000000-0000-0000-0000-000000000001"
        static let inboxProjectName = "Inbox"
    }
}
