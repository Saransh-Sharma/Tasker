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
        static let foredropSurface = "home.foredrop.surface"
        static let foredropCollapseHint = "home.foredrop.collapseHint"
        static let addTaskButton = "home.addTaskButton"
        static let morningTasksList = "home.morningTasksList"
        static let eveningTasksList = "home.eveningTasksList"
        static let dailyScoreLabel = "home.dailyScoreLabel"
        static let streakLabel = "home.streakLabel"
        static let completionRateLabel = "home.completionRateLabel"
        static let datePicker = "home.datePicker"
        static let bottomBar = "home.bottomBar"
        static let bottomBarHome = "home.bottomBar.home"
        static let bottomBarCalendar = "home.bottomBar.calendar"
        static let bottomBarCharts = "home.bottomBar.charts"
        static let searchButton = "home.searchButton"
        static let topNavSearchButton = "home.topNav.searchButton"
        static let topNavContainer = "home.topNav.container"
        static let topNavActionRow = "home.topNav.actionRow"
        static let chatButton = "home.chatButton"
        static let inboxButton = "home.inboxButton"
        static let settingsButton = "home.settingsButton"
        static let backToTodayButton = "home.backToToday.button"
        static let reflectionReadyButton = "home.reflectionReady.button"
        static let topChromeDayProgress = "home.topChrome.dayProgress"
        static let projectFilterButton = "home.focus.menu.button"
        static let quickFilterMenuButton = "home.focus.menu.button"
        static let quickFilterMenuContainer = "home.focus.menu.container"
        static let quickFilterMenuAdvancedButton = "home.focus.menu.advanced"
        static let quickFilterGroupingPrioritizeOverdue = "home.focus.grouping.prioritizeOverdue"
        static let quickFilterGroupingGroupByProjects = "home.focus.grouping.groupByProjects"
        static let primaryWidgetRail = "home.primaryWidgetRail"
        static let primaryWidgetIndicator = "home.primaryWidget.indicator"
        static let primaryWidgetPageFocusNow = "home.primaryWidget.page.focusNow"
        static let primaryWidgetPageWeeklyOperating = "home.primaryWidget.page.weeklyOperating"
        static let primaryWidgetIndicatorFocusNow = "home.primaryWidget.indicator.focusNow"
        static let primaryWidgetIndicatorWeeklyOperating = "home.primaryWidget.indicator.weeklyOperating"
        static let dailyReflectionEntryCompact = "home.dailyReflection.entry.compact"
        static let weeklySummaryCard = "home.weeklySummary.card"
        static let calendarCard = "home.calendar.card"
        static let calendarStateActive = "home.calendar.state.active"
        static let calendarStatePermission = "home.calendar.state.permission"
        static let calendarStateNoCalendars = "home.calendar.state.noCalendars"
        static let calendarStateEmpty = "home.calendar.state.empty"
        static let calendarStateError = "home.calendar.state.error"
        static let calendarConnect = "home.calendar.connect"
        static let calendarRetry = "home.calendar.retry"
        static let previousDayHandle = "homeCalendar.previousDayHandle"
        static let nextDayHandle = "homeCalendar.nextDayHandle"
        static let focusStrip = "home.focus.strip"
        static let focusDropZone = "home.focus.dropzone"
        static let focusTitleTap = "home.focus.titleTap"
        static let passiveTrackingRail = "home.passiveTracking.rail"
        static let rescueSection = "home.rescue.section"
        static let rescueHeader = "home.rescue.header"
        static let rescueOpen = "home.rescue.open"
        static let rescueStart = "home.rescue.start"
        static let rescueExpand = "home.rescue.expand"
        static let rescueSheet = "home.rescue.sheet"
        static let listDropZone = "home.list.dropzone"
        static let chartView = "home.chartView"
        static let radarChartView = "home.radarChartView"
        static let navXpPieChart = "home.navXpPieChart"
        static let weeklyCalendar = "home.weeklyCalendar"
        static let timelineSurface = "home.timeline.surface"
        static let taskListScrollView = "home.taskList.scrollView"
        static let dailySummaryModal = "home.dailySummaryModal"
        static let dailySummaryHeroOpenCount = "home.dailySummary.hero.openCount"
        static let dailySummaryHeroCompleted = "home.dailySummary.hero.completed"
        static let dailySummaryCTAStartToday = "home.dailySummary.cta.startToday"
        static let dailySummaryCTACompleteMorning = "home.dailySummary.cta.completeMorning"
        static let dailySummaryCTAStartTriage = "home.dailySummary.cta.startTriage"
        static let dailySummaryCTAPlanTomorrow = "home.dailySummary.cta.planTomorrow"
        static let dailySummaryCTAReviewDone = "home.dailySummary.cta.reviewDone"
        static let insightsContainer = "home.insights.container"
        static let insightsTabToday = "home.insights.tab.today"
        static let insightsTabWeek = "home.insights.tab.week"
        static let insightsTabSystems = "home.insights.tab.systems"
        static let insightsScroll = "home.insights.scroll"
        static let insightsContentToday = "home.insights.content.today"
        static let insightsContentWeek = "home.insights.content.week"
        static let insightsContentSystems = "home.insights.content.systems"
        static let habitsSection = "home.habits.section"
        static let habitsRecoverySection = "home.habits.recovery"
        static let habitsSectionAction = "home.habits.section.action"
        static let habitsOpenBoard = "home.habits.openBoard"
        static let quietTrackingSummary = "home.quietTracking.summary"
        static let quietTrackingSheet = "home.quietTracking.sheet"
        static let quietTrackingSheetScroll = "home.quietTracking.sheet.scroll"
        static let quietTrackingSheetCancel = "home.quietTracking.sheet.cancel"
        static let quietTrackingSheetSave = "home.quietTracking.sheet.save"
        static let quietTrackingSheetHabitList = "home.quietTracking.sheet.habitList"
        static let quietTrackingSheetOutcomeProgress = "home.quietTracking.sheet.outcome.progress"
        static let quietTrackingSheetOutcomeLapse = "home.quietTracking.sheet.outcome.lapse"
        static let quietTrackingSheetDateToday = "home.quietTracking.sheet.date.today"
        static let quietTrackingSheetDateYesterday = "home.quietTracking.sheet.date.yesterday"
        static let quietTrackingSheetSelectedDate = "home.quietTracking.sheet.date.selected"
        static let quietTrackingSheetDatePicker = "home.quietTracking.sheet.datePicker"
        static func passiveTrackingCard(_ id: String) -> String { "home.passiveTracking.card.\(id)" }
        static func quietTrackingSheetHabit(_ id: String) -> String { "home.quietTracking.sheet.habit.\(id)" }
        static func habitRow(_ id: String) -> String { "home.habitRow.\(id)" }
        static func habitRowIcon(_ id: String) -> String { "home.habitRow.icon.\(id)" }
        static func habitRowTitle(_ id: String) -> String { "home.habitRow.title.\(id)" }
        static func habitRowStrip(_ id: String) -> String { "home.habitRow.strip.\(id)" }
        static func habitRowLastCell(_ id: String) -> String { "home.habitRow.lastCell.\(id)" }

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
        static let modePicker = "addItem.modePicker"
        static let modeTask = "addItem.mode.task"
        static let modeHabit = "addItem.mode.habit"
        static let titleField = "addTask.titleField"
        static let iconButton = "addTask.iconButton"
        static let iconPickerSheet = "addTask.iconPickerSheet"
        static let iconSearchField = "addTask.iconSearchField"
        static let iconResetButton = "addTask.iconResetButton"
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
        static let lifeAreaSelector = "addTask.lifeAreaSelector"
        static let projectSelector = "addTask.projectSelector"
        static let detailsDisclosure = "addTask.detailsDisclosure"
        static let scheduleEditor = "addTask.scheduleEditor"
        static let scheduleDateToday = "addTask.schedule.date.today"
        static let scheduleDateTomorrow = "addTask.schedule.date.tomorrow"
        static let scheduleDateCustom = "addTask.schedule.date.custom"
        static let scheduleDateSomeday = "addTask.schedule.date.someday"
        static let scheduleTimeRow = "addTask.schedule.timeRow"
        static let scheduleTimePickerSheet = "addTask.schedule.timePickerSheet"
        static let scheduleTimePicker = "addTask.schedule.timePicker"
        static let scheduleTimePickerConfirm = "addTask.schedule.timePickerConfirm"
        static let scheduleCustomDurationField = "addTask.schedule.customDurationField"
        static let reminderToggle = "addTask.reminderToggle"
        static let reminderTimePicker = "addTask.reminderTimePicker"
        static let saveButton = "addTask.saveButton"
        static let createButton = "addTask.createButton"
        static let cancelButton = "addTask.cancelButton"

        // Validation
        static let titleError = "addTask.titleError"
        static let descriptionError = "addTask.descriptionError"

        // Project Pills
        static func projectPill(projectId: String) -> String { "addTask.projectPill.\(projectId)" }
        static func scheduleDurationChip(minutes: Int) -> String { "addTask.schedule.duration.\(minutes)" }
        static func iconOption(_ symbolName: String) -> String { "addTask.iconOption.\(symbolName)" }
    }

    enum DatePickerSheet {
        static let sheet = "tasker.datePicker.sheet"
        static let calendar = "tasker.datePicker.calendar"
        static let confirmButton = "tasker.datePicker.confirmButton"
        static let customDateChip = "tasker.datePicker.customDateChip"
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
        static let dueChip = "taskDetail.chip.due"
        static let stepsDisclosure = "taskDetail.disclosure.steps"
        static let detailsDisclosure = "taskDetail.disclosure.details"
        static let relationshipsDisclosure = "taskDetail.disclosure.relationships"
        static let contextDisclosure = "taskDetail.disclosure.context"
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
        static let heroCard = "settings.hero.card"
        static let lifeManagementRow = "settings.workspace.lifeManagement.row"
        static let projectsRow = "settings.workspace.projects.row"
        static let aiAssistantRow = "settings.aiAssistant.row"
        static let modelsRow = "settings.aiAssistant.models.row"
        static let calendarAccessRow = "settings.calendar.access.row"
        static let calendarSelectionRow = "settings.calendar.selection.row"
        static let calendarIncludeDeclinedToggle = "settings.calendar.includeDeclined.toggle"
        static let calendarIncludeAllDayAgendaToggle = "settings.calendar.includeAllDayAgenda.toggle"
        static let calendarIncludeAllDayBusyToggle = "settings.calendar.includeAllDayBusy.toggle"
        static let timelineShowCalendarEventsToggle = "settings.timeline.showCalendarEvents.toggle"
        static let timelineAnchorsCard = "settings.timeline.anchors.card"
        static let timelineRiseAndShinePicker = "settings.timeline.riseAndShine.picker"
        static let timelineRiseAndShineValue = "settings.timeline.riseAndShine.value"
        static let timelineWindDownPicker = "settings.timeline.windDown.picker"
        static let timelineWindDownValue = "settings.timeline.windDown.value"
        static let appearanceInfo = "settings.appearance.info"
        static let decorativeButtonEffectsCard = "settings.appearance.decorativeButtonEffects.card"
        static let decorativeButtonEffectsToggle = "settings.appearance.decorativeButtonEffects.toggle"
        static let homeBackgroundNoiseCard = "settings.appearance.homeBackgroundNoise.card"
        static let homeBackgroundNoiseSlider = "settings.appearance.homeBackgroundNoise.slider"
        static let homeBackgroundNoiseValue = "settings.appearance.homeBackgroundNoise.value"
        static let appVersionRow = "settings.appVersionRow"
        static let aboutSection = "settings.aboutSection"
        static let onboardingRestartButton = "settings.onboarding.restartButton"
        static let chiefOfStaffCard = "settings.chiefOfStaff.card"
        static let chiefOfStaffName = "settings.chiefOfStaff.name"
        static func chiefOfStaffPersona(_ id: String) -> String { "settings.chiefOfStaff.persona.\(id)" }
    }

    // MARK: - Onboarding

    enum Onboarding {
        static let flow = "onboarding.flow"
        static let progress = "onboarding.header.progress"
        static let backdropVideo = "onboarding.backdrop.video"
        static let backdropGrain = "onboarding.backdrop.grain"
        static let welcome = "onboarding.welcome"
        static let welcomeHeroVideo = "onboarding.welcome.heroVideo"
        static let welcomeVideoGrain = "onboarding.welcome.videoGrain"
        static let welcomeIntroOverlay = "onboarding.welcome.introOverlay"
        static let welcomeIntroTitleCard = "onboarding.welcome.introTitleCard"
        static let welcomeIntroContinue = "onboarding.welcome.introContinue"
        static let goal = "onboarding.goal"
        static let pain = "onboarding.pain"
        static let evaValue = "onboarding.evaValue"
        static let lifeAreas = "onboarding.lifeAreas"
        static let habitSetup = "onboarding.habitSetup"
        static let streakPreview = "onboarding.streakPreview"
        static let evaStyle = "onboarding.evaStyle"
        static let processing = "onboarding.processing"
        static let firstTask = "onboarding.firstTask"
        static let focusRoom = "onboarding.focusRoom"
        static let habitCheckIn = "onboarding.habitCheckIn"
        static let calendarPermission = "onboarding.calendarPermission"
        static let notificationPermission = "onboarding.notificationPermission"
        static let success = "onboarding.success"
        static let skipButton = "onboarding.skipButton"
        static let nextButton = "onboarding.cta.next"
        static let frictionHelper = "onboarding.friction.helper"
        static let useAreas = "onboarding.cta.useAreas"
        static let customHabit = "onboarding.cta.customHabit"
        static let customTask = "onboarding.cta.customTask"
        static let goFinishTask = "onboarding.cta.goFinishTask"
        static let focusPrimary = "onboarding.cta.focusPrimary"
        static let markComplete = "onboarding.cta.markComplete"
        static let breakDown = "onboarding.cta.breakDown"
        static let goHome = "onboarding.cta.goHome"
        static let breakdownNext = "onboarding.cta.breakdownNext"
        static let prompt = "onboarding.prompt"
        static let promptStart = "onboarding.prompt.start"
        static let promptDismiss = "onboarding.prompt.dismiss"
        static let finish = "onboarding.success"
        static func mascotPersona(_ id: String) -> String { "onboarding.mascot.persona.\(id)" }
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
        static let editButton = "habitDetail.editButton"
        static let saveButton = "habitDetail.saveButton"
        static func dayCell(_ dateStamp: String) -> String { "habitDetail.cell.\(dateStamp)" }
    }

    // MARK: - Search Screen

    enum Search {
        static let view = "search.view"
        static let chromeContainer = "search.chromeContainer"
        static let contentContainer = "search.contentContainer"
        static let searchField = "search.searchField"
        static let resultsList = "search.resultsList"
        static let emptyStateLabel = "search.emptyStateLabel"
        static let clearButton = "search.clearButton"
        static let cancelButton = "search.cancelButton"
        static let backChip = "search.backChip"
        static let statusAll = "search.status.all"
        static let statusToday = "search.status.today"
        static let statusOverdue = "search.status.overdue"
        static let statusCompleted = "search.status.completed"
        static let priorityP0 = "search.priority.p0"
        static let priorityP1 = "search.priority.p1"
        static let priorityP2 = "search.priority.p2"
        static let priorityP3 = "search.priority.p3"
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
        static let memorySettingsRow = "llmSettings.memorySettingsRow"
        static let privacySettingsRow = "llmSettings.privacySettingsRow"
        static let creditsRow = "llmSettings.creditsRow"
        static let modelsView = "llmSettings.modelsView"
        static let installModelButton = "llmSettings.installModelButton"
    }

    enum LLMModelPicker {
        static let view = "llm.modelPicker.view"
        static let recommendedRow = "llm.modelPicker.recommendedRow"
        static let recommendedBadge = "llm.modelPicker.recommendedBadge"
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
