//
//  AccessibilityIdentifiers.swift
//  LifeBoardUITests
//
//  Centralized accessibility identifiers for UI testing.
//  Every identifier here is rendered by the live Foundation shell; identifiers
//  of deleted Sunrise surfaces (search face, focus strip, schedule face, the
//  nine-step onboarding) were removed with the tests that used them.
//

import Foundation

enum AccessibilityIdentifiers {

    // MARK: - Foundation Shell

    /// The shell around the five roots (`FoundationShellLayout`,
    /// `FoundationShellDestinations`, `ScreenRootHeader`).
    enum Shell {
        /// The iPhone dock and composer chrome.
        static let compactChrome = "LifeBoardCompactChrome"
        /// The iPad and Mac top root switcher.
        static let rootSwitcher = "foundation.expanded.rootSwitcher"
        /// Dock button for a root: `home`, `plan`, `track`, `insights`, `eva`.
        static func destination(_ root: String) -> String { "foundation.destination.\(root)" }
        /// Root-switcher button for a root at iPad and Mac widths.
        static func expandedDestination(_ root: String) -> String { "foundation.expanded.destination.\(root)" }
        /// Every root's shared header.
        static func header(_ root: String) -> String { "\(root).header" }
        /// A root header's "…" menu (Settings, Add to Home, Chats).
        static func more(_ root: String) -> String { "foundation.more.\(root)" }
    }

    // MARK: - Task Route

    /// The task detail route opened from Home and Plan (`TaskRouteView`).
    enum TaskEditor {
        static let title = "task.editor.title"
        static let notes = "task.editor.notes"
        static let completion = "task.editor.completion"
        static let actions = "task.editor.actions"
        static let delete = "task.editor.delete"
        static let deleteConfirm = "task.editor.delete.confirm"
        /// A field chip: `when`, `deadline`, `duration`, `project`, `tags`, `priority`, `repeat`.
        static func chip(_ field: String) -> String { "task.editor.chip.\(field)" }
    }

    // MARK: - Plan

    enum Plan {
        static let header = "plan.header"
        /// Opens the Overdue Rescue deck from Plan's day (`PlanDaySection`).
        static let openRescue = "plan.day.openRescue"
        static let inbox = "plan.inbox"
        static let calendarNotRequested = "plan.calendar.notRequested"
        static let calendarDenied = "plan.calendar.denied"
        static let weekCompactList = "plan.week.compactList"
        static let weekSevenDayBoard = "plan.week.sevenDayBoard"
        /// Plan's lens picker: `Day`, `Week`, `Inbox`, `Backlog`.
        static func lens(_ name: String) -> String { "plan.lens.\(name)" }
    }

    // MARK: - Insights

    enum Insights {
        static let scroll = "foundation.insights.scroll"
        /// Insights' lens picker: `overview`, `trends`, `review`, `experience`.
        static func lens(_ name: String) -> String { "insights.lens.\(name)" }
    }

    // MARK: - Home Screen

    enum Home {
        /// Home's root header (`Shell.header("home")`).
        static let header = "home.header"
        static let scroll = "foundation.home.scroll"
        static let undoCompletion = "home.tasks.undoCompletion"
        static let taskRowPrefix = "home.task."
        static let taskCheckboxPrefix = "home.taskCheckbox."
        static func taskCheckbox(_ taskID: String) -> String { "home.taskCheckbox.\(taskID)" }
        static let habitsToday = "home.habitsToday"
        static let habitsTodayBoard = "home.habitsToday.board"
        /// Home's "Needs you" row for slipped work; opens Plan's overdue week.
        static let upNextRescue = "home.upNext.rescue"
        static let screenshotSeedReady = "screenshot.seed.ready"
        static let screenshotSeedFailed = "screenshot.seed.failed"
        static let addTaskButton = "home.tasks.add"
        static let taskCardShowMore = "home.tasks.showMore"
        static let taskCardShowLess = "home.tasks.showLess"
        static let taskCardDatePicker = "home.tasks.datePicker"
        static let rescueSheet = "home.rescue.sheet"
        static let rescueClose = "home.rescue.close"
        static let rescueActionKeepToday = "home.rescue.action.keepToday"
        static let rescueActionMoveLater = "home.rescue.action.moveLater"
        static let rescueCompletionViewToday = "home.rescue.completion.viewToday"
        static let rescueActionEdit = "home.rescue.action.Edit"
        static let rescueActionDelete = "home.rescue.action.Delete"
        static let rescueEditSheet = "home.rescue.edit.sheet"
        static let rescueEditSave = "home.rescue.edit.save"
        static let rescueDeleteOverlay = "home.rescue.delete.overlay"
        static let rescueDeleteConfirm = "home.rescue.delete.confirm"
        static let rescueDeleteCancel = "home.rescue.delete.cancel"
        static func rescueCard(_ id: String) -> String { "home.rescue.card.\(id)" }
    }

    enum Snackbar {
        static let view = "lifeboard.snackbar"
    }

    // MARK: - Add Task Screen

    enum AddTask {
        static let view = "addTask.view"
        static let titleField = "addTask.titleField"
        static let iconButton = "addTask.iconButton"
        static let descriptionField = "addTask.descriptionField"
        static let lifeAreaSelector = "addTask.lifeAreaSelector"
        static let detailsDisclosure = "addTask.detailsDisclosure"
        static let timelinePreview = "addTask.timelinePreview"
        static let scheduleEditor = "addTask.scheduleEditor"
        static let scheduleTimeRow = "addTask.schedule.timeRow"
        static let scheduleTimePickerSheet = "addTask.schedule.timePickerSheet"
        static let scheduleTimePicker = "addTask.schedule.timePicker"
        static let scheduleTimePickerConfirm = "addTask.schedule.timePickerConfirm"
        static let scheduleCustomDurationField = "addTask.schedule.customDurationField"
        static let saveButton = "addTask.saveButton"
        static let createButton = "addTask.createButton"
        static let cancelButton = "addTask.cancelButton"

        static func scheduleDurationChip(minutes: Int) -> String { "addTask.schedule.duration.\(minutes)" }
    }

    enum DatePickerSheet {
        static let sheet = "lifeboard.datePicker.sheet"
        static let calendar = "lifeboard.datePicker.calendar"
        static let confirmButton = "lifeboard.datePicker.confirmButton"
        static let customDateChip = "lifeboard.datePicker.customDateChip"
    }

    // MARK: - Task Detail Screen

    enum TaskDetail {
        static let view = "taskDetail.view"
        static let titleField = "taskDetail.titleField"
        static let descriptionField = "taskDetail.descriptionField"
        static let priorityControl = "taskDetail.priorityControl"
        static let projectLabel = "taskDetail.projectLabel"
        static let completeButton = "taskDetail.completeButton"
        static let deleteButton = "taskDetail.deleteButton"
        static let closeButton = "taskDetail.closeButton"
        static let dueChip = "taskDetail.chip.due"
        static let stepsDisclosure = "taskDetail.disclosure.steps"
        static let detailsDisclosure = "taskDetail.disclosure.details"
        static let relationshipsDisclosure = "taskDetail.disclosure.relationships"
        static let contextDisclosure = "taskDetail.disclosure.context"
    }

    // MARK: - Settings Screen

    enum Settings {
        static let navigationBar = "Settings"
        static let doneButton = "Done"
        static let heroCard = "settings.hero.card"
        static let lifeManagementRow = "settings.workspace.lifeManagement.row"
        static let aiAssistantRow = "settings.aiAssistant.row"
        static let calendarAccessRow = "settings.calendar.access.row"
        static let calendarSelectionRow = "settings.calendar.selection.row"
        static let calendarIncludeDeclinedToggle = "settings.calendar.includeDeclined.toggle"
        static let calendarIncludeAllDayAgendaToggle = "settings.calendar.includeAllDayAgenda.toggle"
        static let calendarIncludeAllDayBusyToggle = "settings.calendar.includeAllDayBusy.toggle"
        static let timelineShowCalendarEventsToggle = "settings.timeline.showCalendarEvents.toggle"
        static let timelineAnchorsCard = "settings.timeline.anchors.card"
        static let timelineRiseAndShinePicker = "settings.timeline.riseAndShine.picker"
        static let timelineWindDownPicker = "settings.timeline.windDown.picker"
        static let decorativeButtonEffectsCard = "settings.appearance.decorativeButtonEffects.card"
        static let decorativeButtonEffectsToggle = "settings.appearance.decorativeButtonEffects.toggle"
        static let appVersionRow = "settings.appVersionRow"
        static let onboardingRestartButton = "settings.onboarding.restartButton"
        static let chiefOfStaffCard = "settings.chiefOfStaff.card"
        static let chiefOfStaffName = "settings.chiefOfStaff.name"
        static func chiefOfStaffPersona(_ id: String) -> String { "settings.chiefOfStaff.persona.\(id)" }
    }

    // MARK: - Onboarding

    /// The four-screen first run — the only onboarding the app presents.
    /// Mirrors `LifeWeaveAccessibilityID` in the app target.
    enum LifeWeave {
        static let flow = "onboarding.lifeweave.flow"
        static let canvas = "onboarding.lifeweave.canvas"
        static let progress = "onboarding.lifeweave.progress"
        static let back = "onboarding.lifeweave.back"
        static let error = "onboarding.lifeweave.error"
        static let primaryAction = "onboarding.lifeweave.primary"
        static let secondaryAction = "onboarding.lifeweave.secondary"
        static let captureField = "onboarding.lifeweave.capture.field"
        static let revealReceipt = "onboarding.lifeweave.reveal.receipt"

        static let hoursEdit = "onboarding.lifeweave.reveal.hours.edit"
        static let dayShapeDone = "onboarding.lifeweave.dayshape.done"

        static func step(_ suffix: String) -> String { "onboarding.lifeweave.step.\(suffix)" }
        static func intent(_ id: String) -> String { "onboarding.lifeweave.intent.\(id)" }
        static func lifeArea(_ id: String) -> String { "onboarding.lifeweave.area.\(id)" }
        static func dayShapePreset(_ id: String) -> String { "onboarding.lifeweave.preset.\(id)" }
    }

    enum HabitBoard {
        static let view = "habitBoard.view"
        static let rangeTitle = "habitBoard.rangeTitle"
        static let rangeSubtitle = "habitBoard.rangeSubtitle"
        static let previousWindow = "habitBoard.window.previous"
        static let nextWindow = "habitBoard.window.next"
        static let pinnedHeader = "habitBoard.pinned.header"
        static let loadingState = "habitBoard.state.loading"
        static let emptyState = "habitBoard.state.empty"
        static let errorState = "habitBoard.state.error"
        static let retryButton = "habitBoard.state.retry"
        static let createButton = "habitBoard.state.create"
        static func row(_ habitID: String) -> String { "habitBoard.row.\(habitID)" }
        static func pinnedTitle(_ habitID: String) -> String { "habitBoard.pinnedTitle.\(habitID)" }
        static func dayHeader(_ dateStamp: String) -> String { "habitBoard.dayHeader.\(dateStamp)" }
        static func dayCell(_ habitID: String, dateStamp: String) -> String { "habitBoard.cell.\(habitID).\(dateStamp)" }
    }

    enum HabitDetail {
        static let view = "habitDetail.view"
        static let grid = "habitDetail.grid"
        static let contextPrimary = "habitDetail.context.primary"
        static let contextSecondary = "habitDetail.context.secondary"
        static let detailsDisclosure = "habitDetail.detailsDisclosure"
        static let helperText = "habitDetail.helperText"
        static let currentStreakMetric = "habitDetail.metric.currentStreak"
        static let bestStreakMetric = "habitDetail.metric.bestStreak"
        static let totalCountMetric = "habitDetail.metric.totalCount"
        static let completionRateMetric = "habitDetail.metric.completionRate"
        static func dayCell(_ dateStamp: String) -> String { "habitDetail.cell.\(dateStamp)" }
    }

    // MARK: - LLM Settings Screen

    enum LLMSettings {
        static let view = "llmSettings.view"
        static let modelsSettingsRow = "llmSettings.modelsSettingsRow"
        static let chatsSettingsRow = "llmSettings.chatsSettingsRow"
        static let memorySettingsRow = "llmSettings.memorySettingsRow"
        static let privacySettingsRow = "llmSettings.privacySettingsRow"
        static let modelsView = "llmSettings.modelsView"
        static let installModelButton = "llmSettings.installModelButton"
    }

    enum LLMModelPicker {
        static let view = "llm.modelPicker.view"
        static let recommendedRow = "llm.modelPicker.recommendedRow"
        static let recommendedBadge = "llm.modelPicker.recommendedBadge"
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
        static let alertOKButton = "OK"
        static let alertCancelButton = "Cancel"
        static let alertDeleteButton = "Delete"
    }

    // MARK: - Priority Labels

    enum Priority {
        static let none = "None"
        static let low = "Low"      // P3
        static let medium = "Medium" // P2
        static let high = "High"    // P1
        static let max = "Max"      // P0
    }

    // MARK: - Project Constants

    enum ProjectConstants {
        static let inboxProjectID = "00000000-0000-0000-0000-000000000001"
        static let inboxProjectName = "Inbox"
    }
}
