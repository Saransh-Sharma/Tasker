//
//  HomeViewController.swift
//  To Do List
//
//  SwiftUI host for Home screen with backdrop/foredrop shell.
//

import UIKit
import SwiftUI
import Combine
import SwiftData

public enum HomeShellPhase: String, Equatable {
    case startup
    case interactive
}

public enum HomeScrollChromeState: String, Equatable {
    case nearTop
    case expanded
    case collapsed
    case idle
}

enum HomeAnalyticsSurfaceState: Equatable {
    case idle
    case placeholder
    case loading
    case ready
}

enum HomeSearchSurfaceState: Equatable {
    case idle
    case presenting
    case preparing
    case ready
}

struct HomeLayoutMetrics: Equatable {
    let width: CGFloat
    let height: CGFloat
    let safeAreaTop: CGFloat
    let safeAreaBottom: CGFloat
    let keyboardOverlapHeight: CGFloat
    let backdropGradientHeight: CGFloat
    let taskListBottomInset: CGFloat
    let chatComposerBottomInset: CGFloat
    let chartViewportHeight: CGFloat

    static let zero = HomeLayoutMetrics(
        width: 0,
        height: 0,
        safeAreaTop: 0,
        safeAreaBottom: 0,
        keyboardOverlapHeight: 0,
        backdropGradientHeight: 0,
        taskListBottomInset: 80,
        chatComposerBottomInset: 80,
        chartViewportHeight: 560
    )

    var isReady: Bool {
        width > 1 && height > 1
    }
}

struct HomeBottomBarVisibilityPolicy {
    static func shouldConcealBottomBar(
        activeFace: HomeForedropFace,
        isPromptFocused: Bool,
        keyboardOverlapHeight: CGFloat
    ) -> Bool {
        activeFace == .chat && (isPromptFocused || keyboardOverlapHeight > 0.5)
    }

    static func chatComposerClearance(
        layoutClass: TaskerLayoutClass,
        bottomOverlayObstruction: CGFloat,
        keyboardOverlapHeight: CGFloat,
        isBottomBarConcealed: Bool,
        idleSpacing: CGFloat,
        idleExtraSpacing: CGFloat,
        keyboardSpacing: CGFloat,
        regularSpacing: CGFloat
    ) -> CGFloat {
        guard layoutClass == .phone else { return regularSpacing }
        if keyboardOverlapHeight > 0.5 {
            return keyboardOverlapHeight + keyboardSpacing
        }
        if bottomOverlayObstruction > 0.5 {
            return bottomOverlayObstruction + idleSpacing + idleExtraSpacing
        }
        if isBottomBarConcealed {
            return regularSpacing
        }
        return regularSpacing
    }
}

typealias HomeChromeState = HomeChromeSnapshot
typealias HomeTasksState = HomeTasksSnapshot
typealias HomeCalendarState = HomeCalendarSnapshot
typealias HomeOverlayState = HomeOverlaySnapshot

struct HomeRenderTransaction: Equatable {
    let chrome: HomeChromeState
    let tasks: HomeTasksState
    let habits: HomeHabitsSnapshot
    let calendar: HomeCalendarState
    let overlay: HomeOverlayState

    init(
        chrome: HomeChromeState,
        tasks: HomeTasksState,
        habits: HomeHabitsSnapshot,
        calendar: HomeCalendarState = .empty,
        overlay: HomeOverlayState
    ) {
        self.chrome = chrome
        self.tasks = tasks
        self.habits = habits
        self.calendar = calendar
        self.overlay = overlay
    }

    static let empty = HomeRenderTransaction(
        chrome: .empty,
        tasks: .empty,
        habits: .empty,
        calendar: .empty,
        overlay: .empty
    )

    func changedSliceCount(comparedTo previous: HomeRenderTransaction) -> Int {
        var count = 0
        if chrome != previous.chrome {
            count += 1
        }
        if tasks != previous.tasks {
            count += 1
        }
        if habits != previous.habits {
            count += 1
        }
        if calendar != previous.calendar {
            count += 1
        }
        if overlay != previous.overlay {
            count += 1
        }
        return count
    }
}

struct HomeChromeSnapshot: Equatable {
    let selectedDate: Date
    let activeScope: HomeListScope
    let activeFilterState: HomeFilterState
    let savedHomeViews: [SavedHomeView]
    let quickViewCounts: [HomeQuickView: Int]
    let progressState: HomeProgressState
    let dailyScore: Int
    let completionRate: Double
    let weeklySummary: HomeWeeklySummary?
    let weeklySummaryIsLoading: Bool
    let weeklySummaryErrorMessage: String?
    let projects: [Project]
    let dailyReflectionEntryState: DailyReflectionEntryState?
    let dailyPlanDraft: DailyPlanDraft?
    let momentumGuidanceText: String

    init(
        selectedDate: Date,
        activeScope: HomeListScope,
        activeFilterState: HomeFilterState,
        savedHomeViews: [SavedHomeView],
        quickViewCounts: [HomeQuickView: Int],
        progressState: HomeProgressState,
        dailyScore: Int,
        completionRate: Double,
        weeklySummary: HomeWeeklySummary?,
        weeklySummaryIsLoading: Bool = false,
        weeklySummaryErrorMessage: String? = nil,
        projects: [Project],
        dailyReflectionEntryState: DailyReflectionEntryState?,
        dailyPlanDraft: DailyPlanDraft?,
        momentumGuidanceText: String
    ) {
        self.selectedDate = selectedDate
        self.activeScope = activeScope
        self.activeFilterState = activeFilterState
        self.savedHomeViews = savedHomeViews
        self.quickViewCounts = quickViewCounts
        self.progressState = progressState
        self.dailyScore = dailyScore
        self.completionRate = completionRate
        self.weeklySummary = weeklySummary
        self.weeklySummaryIsLoading = weeklySummaryIsLoading
        self.weeklySummaryErrorMessage = weeklySummaryErrorMessage
        self.projects = projects
        self.dailyReflectionEntryState = dailyReflectionEntryState
        self.dailyPlanDraft = dailyPlanDraft
        self.momentumGuidanceText = momentumGuidanceText
    }

    static let empty = HomeChromeSnapshot(
        selectedDate: Date(),
        activeScope: .today,
        activeFilterState: .default,
        savedHomeViews: [],
        quickViewCounts: [:],
        progressState: .empty,
        dailyScore: 0,
        completionRate: 0,
        weeklySummary: nil,
        weeklySummaryIsLoading: false,
        weeklySummaryErrorMessage: nil,
        projects: [],
        dailyReflectionEntryState: nil,
        dailyPlanDraft: nil,
        momentumGuidanceText: ""
    )
}

struct HomeTasksSnapshot: Equatable {
    let morningTasks: [TaskDefinition]
    let eveningTasks: [TaskDefinition]
    let overdueTasks: [TaskDefinition]
    let dueTodaySection: HomeListSection?
    let todaySections: [HomeListSection]
    let focusNowSectionState: FocusNowSectionState
    let todayAgendaSectionState: TodayAgendaSectionState
    let agendaTailItems: [HomeAgendaTailItem]
    let habitHomeSectionState: HabitHomeSectionState
    let quietTrackingSummaryState: QuietTrackingSummaryState
    let inlineCompletedTasks: [TaskDefinition]
    let doneTimelineTasks: [TaskDefinition]
    let projects: [Project]
    let projectsByID: [UUID: Project]
    let tagNameByID: [UUID: String]
    let activeQuickView: HomeQuickView
    let todayXPSoFar: Int?
    let projectGroupingMode: HomeProjectGroupingMode
    let customProjectOrderIDs: [UUID]
    let emptyStateMessage: String?
    let emptyStateActionTitle: String?
    let canUseManualFocusDrag: Bool
    let focusTasks: [TaskDefinition]
    let focusRows: [HomeTodayRow]
    let pinnedFocusTaskIDs: [UUID]
    let todayOpenTaskCount: Int

    static let empty = HomeTasksSnapshot(
        morningTasks: [],
        eveningTasks: [],
        overdueTasks: [],
        dueTodaySection: nil,
        todaySections: [],
        focusNowSectionState: FocusNowSectionState(rows: [], pinnedTaskIDs: []),
        todayAgendaSectionState: TodayAgendaSectionState(sections: []),
        agendaTailItems: [],
        habitHomeSectionState: HabitHomeSectionState(primaryRows: [], recoveryRows: []),
        quietTrackingSummaryState: QuietTrackingSummaryState(stableRows: []),
        inlineCompletedTasks: [],
        doneTimelineTasks: [],
        projects: [],
        projectsByID: [:],
        tagNameByID: [:],
        activeQuickView: .today,
        todayXPSoFar: nil,
        projectGroupingMode: .defaultMode,
        customProjectOrderIDs: [],
        emptyStateMessage: nil,
        emptyStateActionTitle: nil,
        canUseManualFocusDrag: false,
        focusTasks: [],
        focusRows: [],
        pinnedFocusTaskIDs: [],
        todayOpenTaskCount: 0
    )

    var hasCommittedInitialContent: Bool {
        !morningTasks.isEmpty
            || !eveningTasks.isEmpty
            || !overdueTasks.isEmpty
            || !focusNowSectionState.rows.isEmpty
            || !todayAgendaSectionState.sections.isEmpty
            || !agendaTailItems.isEmpty
            || habitHomeSectionState.isVisible
            || quietTrackingSummaryState.isVisible
            || !inlineCompletedTasks.isEmpty
            || !doneTimelineTasks.isEmpty
            || rendersDefaultTodayEmptyState
            || emptyStateMessage != nil
    }

    var rendersDefaultTodayEmptyState: Bool {
        activeQuickView == .today
            && morningTasks.isEmpty
            && eveningTasks.isEmpty
            && overdueTasks.isEmpty
            && focusNowSectionState.rows.isEmpty
            && todayAgendaSectionState.sections.isEmpty
            && agendaTailItems.isEmpty
            && !habitHomeSectionState.isVisible
            && !quietTrackingSummaryState.isVisible
            && inlineCompletedTasks.isEmpty
            && doneTimelineTasks.isEmpty
    }

    static func == (lhs: HomeTasksSnapshot, rhs: HomeTasksSnapshot) -> Bool {
        lhs.morningTasks == rhs.morningTasks
            && lhs.eveningTasks == rhs.eveningTasks
            && lhs.overdueTasks == rhs.overdueTasks
            && lhs.dueTodaySection == rhs.dueTodaySection
            && lhs.todaySections == rhs.todaySections
            && lhs.focusNowSectionState == rhs.focusNowSectionState
            && lhs.todayAgendaSectionState == rhs.todayAgendaSectionState
            && lhs.agendaTailItems == rhs.agendaTailItems
            && lhs.inlineCompletedTasks == rhs.inlineCompletedTasks
            && lhs.doneTimelineTasks == rhs.doneTimelineTasks
            && lhs.projects == rhs.projects
            && lhs.projectsByID == rhs.projectsByID
            && lhs.tagNameByID == rhs.tagNameByID
            && lhs.activeQuickView == rhs.activeQuickView
            && lhs.todayXPSoFar == rhs.todayXPSoFar
            && lhs.projectGroupingMode == rhs.projectGroupingMode
            && lhs.customProjectOrderIDs == rhs.customProjectOrderIDs
            && lhs.emptyStateMessage == rhs.emptyStateMessage
            && lhs.emptyStateActionTitle == rhs.emptyStateActionTitle
            && lhs.canUseManualFocusDrag == rhs.canUseManualFocusDrag
            && lhs.focusTasks == rhs.focusTasks
            && lhs.focusRows == rhs.focusRows
            && lhs.pinnedFocusTaskIDs == rhs.pinnedFocusTaskIDs
            && lhs.todayOpenTaskCount == rhs.todayOpenTaskCount
    }
}

struct HomeHabitsSnapshot: Equatable {
    let habitHomeSectionState: HabitHomeSectionState
    let quietTrackingSummaryState: QuietTrackingSummaryState
    let errorMessage: String?

    static let empty = HomeHabitsSnapshot(
        habitHomeSectionState: HabitHomeSectionState(primaryRows: [], recoveryRows: []),
        quietTrackingSummaryState: QuietTrackingSummaryState(stableRows: []),
        errorMessage: nil
    )
}

enum HomeCalendarModuleState: Equatable {
    case permissionRequired
    case noCalendarsSelected
    case empty
    case allDayOnly
    case error(message: String)
    case active
}

struct HomeCalendarSnapshot: Equatable {
    let moduleState: HomeCalendarModuleState
    let selectedDate: Date
    let authorizationStatus: TaskerCalendarAuthorizationStatus
    let accessAction: CalendarAccessAction
    let selectedCalendarCount: Int
    let availableCalendarCount: Int
    let nextMeeting: TaskerNextMeetingSummary?
    let busyBlocks: [TaskerCalendarBusyBlock]
    let freeUntil: Date?
    let selectedDayEvents: [TaskerCalendarEventSnapshot]
    let selectedDayTimelineEvents: [TaskerCalendarEventSnapshot]
    let eventsTodayCount: Int
    let isLoading: Bool
    let errorMessage: String?

    static let empty = HomeCalendarSnapshot(
        moduleState: .permissionRequired,
        selectedDate: Date(),
        authorizationStatus: .notDetermined,
        accessAction: .requestPermission,
        selectedCalendarCount: 0,
        availableCalendarCount: 0,
        nextMeeting: nil,
        busyBlocks: [],
        freeUntil: nil,
        selectedDayEvents: [],
        selectedDayTimelineEvents: [],
        eventsTodayCount: 0,
        isLoading: false,
        errorMessage: nil
    )
}

enum TimelinePlanItemSource: Equatable {
    case task
    case calendarEvent
}

struct TimelineChecklistSummary: Equatable, Hashable {
    let completedCount: Int
    let totalCount: Int

    var isEmpty: Bool { totalCount <= 0 }
}

enum TimelineWindowRelation: Equatable, Hashable {
    case beforeWake
    case bridgeIntoWake
    case operational
    case bridgePastSleep
    case afterSleep
}

struct TimelinePlanItem: Equatable, Identifiable {
    let id: String
    let source: TimelinePlanItemSource
    let taskID: UUID?
    let eventID: String?
    let title: String
    let subtitle: String?
    let startDate: Date?
    let endDate: Date?
    let isAllDay: Bool
    let isComplete: Bool
    let tintHex: String?
    let systemImageName: String
    let accessoryText: String?
    let taskPriority: TaskPriority?
    let isPinnedFocusTask: Bool
    let hasNotes: Bool
    let isRecurring: Bool
    let checklistSummary: TimelineChecklistSummary?
    let showsProjectUtility: Bool
    let isMeetingLike: Bool
    let windowRelation: TimelineWindowRelation
    let overlapsWake: Bool
    let overlapsSleep: Bool

    init(
        id: String,
        source: TimelinePlanItemSource,
        taskID: UUID?,
        eventID: String?,
        title: String,
        subtitle: String?,
        startDate: Date?,
        endDate: Date?,
        isAllDay: Bool,
        isComplete: Bool,
        tintHex: String?,
        systemImageName: String,
        accessoryText: String?,
        taskPriority: TaskPriority? = nil,
        isPinnedFocusTask: Bool = false,
        hasNotes: Bool = false,
        isRecurring: Bool = false,
        checklistSummary: TimelineChecklistSummary? = nil,
        showsProjectUtility: Bool = false,
        isMeetingLike: Bool = false,
        windowRelation: TimelineWindowRelation = .operational,
        overlapsWake: Bool = false,
        overlapsSleep: Bool = false
    ) {
        self.id = id
        self.source = source
        self.taskID = taskID
        self.eventID = eventID
        self.title = title
        self.subtitle = subtitle
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.isComplete = isComplete
        self.tintHex = tintHex
        self.systemImageName = systemImageName
        self.accessoryText = accessoryText
        self.taskPriority = taskPriority
        self.isPinnedFocusTask = isPinnedFocusTask
        self.hasNotes = hasNotes
        self.isRecurring = isRecurring
        self.checklistSummary = checklistSummary
        self.showsProjectUtility = showsProjectUtility
        self.isMeetingLike = isMeetingLike
        self.windowRelation = windowRelation
        self.overlapsWake = overlapsWake
        self.overlapsSleep = overlapsSleep
    }

    var duration: TimeInterval? {
        guard let startDate, let endDate else { return nil }
        return max(0, endDate.timeIntervalSince(startDate))
    }

    func isActive(at date: Date) -> Bool {
        guard let startDate, let endDate, isComplete == false else { return false }
        return startDate <= date && endDate > date
    }
}

enum TimelineGapAction: String, Equatable {
    case addTask
    case scheduleInbox
    case planBlock
    case dismiss

    var title: String {
        switch self {
        case .addTask:
            return "Add Task"
        case .scheduleInbox:
            return "Schedule Inbox"
        case .planBlock:
            return "Plan Block"
        case .dismiss:
            return "Dismiss"
        }
    }
}

enum TimelineGapEmphasis: Equatable {
    case openTime
    case prepWindow
    case quietWindow
}

struct TimelineGap: Equatable, Identifiable {
    let startDate: Date
    let endDate: Date
    let suggestedTaskCount: Int
    let headline: String
    let supportingText: String
    let primaryAction: TimelineGapAction
    let secondaryAction: TimelineGapAction?
    let emphasis: TimelineGapEmphasis

    init(
        startDate: Date,
        endDate: Date,
        suggestedTaskCount: Int,
        headline: String? = nil,
        supportingText: String? = nil,
        primaryAction: TimelineGapAction? = nil,
        secondaryAction: TimelineGapAction? = nil,
        emphasis: TimelineGapEmphasis = .openTime
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.suggestedTaskCount = suggestedTaskCount
        self.headline = headline ?? "Open time"
        self.supportingText = supportingText ?? "Place something meaningful into this window."
        let resolvedPrimary = primaryAction ?? (suggestedTaskCount > 0 ? .scheduleInbox : .addTask)
        self.primaryAction = resolvedPrimary
        if let secondaryAction {
            self.secondaryAction = secondaryAction
        } else if suggestedTaskCount > 0 {
            self.secondaryAction = resolvedPrimary == .scheduleInbox ? .addTask : .scheduleInbox
        } else {
            self.secondaryAction = nil
        }
        self.emphasis = emphasis
    }

    var id: String {
        "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)"
    }

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }
}

struct TimelineAnchorItem: Equatable, Identifiable {
    let id: String
    let title: String
    let time: Date
    let systemImageName: String
    let subtitle: String?
    let isActionable: Bool

    init(
        id: String,
        title: String,
        time: Date,
        systemImageName: String,
        subtitle: String? = nil,
        isActionable: Bool = false
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.systemImageName = systemImageName
        self.subtitle = subtitle
        self.isActionable = isActionable
    }
}

enum TimelineDayLayoutMode: Equatable {
    case expanded
    case compact
}

enum TimelineDensityMode: Equatable {
    case normal
    case lightTimeline
    case sparse
}

struct TimelineDayProjection: Equatable {
    let date: Date
    let allDayItems: [TimelinePlanItem]
    let inboxItems: [TimelinePlanItem]
    let timedItems: [TimelinePlanItem]
    let gaps: [TimelineGap]
    let operationalItems: [TimelinePlanItem]
    let beforeWakeSummaryItems: [TimelinePlanItem]
    let afterSleepSummaryItems: [TimelinePlanItem]
    let bridgeItems: [TimelinePlanItem]
    let actionableGaps: [TimelineGap]
    let layoutMode: TimelineDayLayoutMode
    let calendarPlottingEnabled: Bool
    let wakeAnchor: TimelineAnchorItem
    let sleepAnchor: TimelineAnchorItem
    let activeItemID: String?
    let currentItemID: String?
    let currentTime: Date

    init(
        date: Date,
        allDayItems: [TimelinePlanItem],
        inboxItems: [TimelinePlanItem],
        timedItems: [TimelinePlanItem],
        gaps: [TimelineGap],
        operationalItems: [TimelinePlanItem]? = nil,
        beforeWakeSummaryItems: [TimelinePlanItem] = [],
        afterSleepSummaryItems: [TimelinePlanItem] = [],
        bridgeItems: [TimelinePlanItem]? = nil,
        actionableGaps: [TimelineGap]? = nil,
        layoutMode: TimelineDayLayoutMode,
        calendarPlottingEnabled: Bool = true,
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem,
        activeItemID: String?,
        currentItemID: String? = nil,
        currentTime: Date
    ) {
        self.date = date
        self.allDayItems = allDayItems
        self.inboxItems = inboxItems
        self.timedItems = timedItems
        self.gaps = gaps
        self.operationalItems = operationalItems ?? timedItems
        self.beforeWakeSummaryItems = beforeWakeSummaryItems
        self.afterSleepSummaryItems = afterSleepSummaryItems
        self.bridgeItems = bridgeItems ?? timedItems.filter { $0.overlapsWake || $0.overlapsSleep }
        self.actionableGaps = actionableGaps ?? gaps
        self.layoutMode = layoutMode
        self.calendarPlottingEnabled = calendarPlottingEnabled
        self.wakeAnchor = wakeAnchor
        self.sleepAnchor = sleepAnchor
        self.activeItemID = activeItemID
        self.currentItemID = currentItemID ?? activeItemID
        self.currentTime = currentTime
    }

    var allTimedItems: [TimelinePlanItem] {
        beforeWakeSummaryItems + timedItems + afterSleepSummaryItems
    }

    var beforeWakeItems: [TimelinePlanItem] {
        beforeWakeSummaryItems
    }

    var afterSleepItems: [TimelinePlanItem] {
        afterSleepSummaryItems
    }

    var plottedTimelineItems: [TimelinePlanItem] {
        beforeWakeItems + timedItems + afterSleepItems
    }

    var hasPlottedTimelineItems: Bool {
        plottedTimelineItems.isEmpty == false
    }

    var timelineDensityMode: TimelineDensityMode {
        let plotted = plottedTimelineItems
        guard plotted.isEmpty == false else { return .sparse }
        guard beforeWakeItems.isEmpty, afterSleepItems.isEmpty else { return .normal }
        guard plotted.count == 1, let item = plotted.first else { return .normal }
        let duration = item.duration ?? 0
        return duration < 90 * 60 ? .lightTimeline : .normal
    }

    func displayStartDate(for item: TimelinePlanItem) -> Date? {
        guard let start = item.startDate else { return nil }
        switch item.windowRelation {
        case .beforeWake, .afterSleep:
            return start
        case .bridgeIntoWake:
            return wakeAnchor.time
        case .operational, .bridgePastSleep:
            return max(start, wakeAnchor.time)
        }
    }

    func layoutInterval(for item: TimelinePlanItem) -> (start: Date, end: Date)? {
        guard let start = item.startDate, let end = item.endDate, end > start else { return nil }
        let clippedStart = max(start, wakeAnchor.time)
        let clippedEnd = min(end, sleepAnchor.time)

        switch item.windowRelation {
        case .beforeWake, .afterSleep:
            return (start, end)
        case .bridgeIntoWake, .operational, .bridgePastSleep:
            guard clippedEnd > clippedStart else { return nil }
            return (clippedStart, clippedEnd)
        }
    }
}

enum TimelineRowKind: Equatable, Hashable {
    case task
    case gap
    case anchor
}

enum TimelineTemporalState: Equatable, Hashable {
    case pastCompleted
    case pastIncomplete
    case currentTask
    case futureTask
    case activeGap
    case futureGap
    case anchor
}

enum TimelineMetadataMode: Equatable, Hashable {
    case scheduled
    case remainingTime(Int)
    case done
}

enum TimelineUtilityItem: Equatable, Hashable {
    case checklist(TimelineChecklistSummary)
    case note
    case recurring
    case calendar
    case meeting
    case project(String)
}

enum TimelineStemSegmentState: Equatable, Hashable {
    case pastCompletedSegment(String?)
    case pastIncompleteSegment(String?)
    case currentElapsedSegment(String?, progress: CGFloat)
    case currentRemainingSegment
    case futureSegment
    case gapPastSegment
    case gapFutureSegment
}

struct TimelineRenderableRow: Equatable, Identifiable {
    let id: String
    let kind: TimelineRowKind
    let temporalState: TimelineTemporalState
    let metadataMode: TimelineMetadataMode?
    let utilityItems: [TimelineUtilityItem]
    let progressRatio: CGFloat
    let title: String
    let subtitle: String?
    let isInteractiveRing: Bool
    let stemLeading: TimelineStemSegmentState
    let stemTrailing: TimelineStemSegmentState
    let isCurrentRailEmphasis: Bool
}

enum TimelineDayLoadLevel: Equatable {
    case light
    case balanced
    case busy
}

struct TimelineWeekDaySummary: Equatable, Identifiable {
    let date: Date
    let dayKey: String
    let allDayCount: Int
    let replanEligibleCount: Int
    let timedMarkers: [Date]
    let tintHexes: [String]
    let summaryText: String
    let loadLevel: TimelineDayLoadLevel

    var id: String {
        dayKey
    }
}

struct NeedsReplanSummary: Equatable {
    let count: Int
    let datedCount: Int
    let unscheduledCount: Int
    let dayCount: Int
    let newestDate: Date?
    let oldestDate: Date?

    static let empty = NeedsReplanSummary(
        count: 0,
        datedCount: 0,
        unscheduledCount: 0,
        dayCount: 0,
        newestDate: nil,
        oldestDate: nil
    )

    var title: String { "Needs Replan" }
    var persistentTitle: String { "Replan Day" }

    var subtitle: String {
        if count == 0 {
            return "No unfinished past tasks need replanning."
        }
        if unscheduledCount > 0, datedCount > 0 {
            return "\(datedCount) overdue or carry-over, \(unscheduledCount) unscheduled"
        }
        if unscheduledCount > 0 {
            return unscheduledCount == 1
                ? "1 unscheduled task needs a plan"
                : "\(unscheduledCount) unscheduled tasks need a plan"
        }
        if count == 1 {
            if let newestDate, Calendar.current.isDateInYesterday(newestDate) {
                return "1 unfinished task from yesterday"
            }
            if let newestDate {
                return "1 unfinished task from \(newestDate.formatted(.dateTime.month().day()))"
            }
            return "1 unfinished task from a past day"
        }
        if dayCount <= 1 {
            if let newestDate, Calendar.current.isDateInYesterday(newestDate) {
                return "\(count) unfinished from yesterday"
            }
            if let newestDate {
                return "\(count) unfinished from \(newestDate.formatted(.dateTime.month().day()))"
            }
            return "\(count) unfinished from a past day"
        }
        if count >= 10 {
            return "\(count) unfinished - start with the most recent"
        }
        return "\(count) unfinished from past days"
    }

    var persistentSubtitle: String {
        if count == 0 {
            return emptyStateMessage
        }
        if unscheduledCount > 0, datedCount > 0 {
            return "\(datedCount) overdue or carry-over, \(unscheduledCount) unscheduled"
        }
        if unscheduledCount > 0 {
            return unscheduledCount == 1
                ? "1 unscheduled task needs a plan"
                : "\(unscheduledCount) unscheduled tasks need a plan"
        }
        if count == 1 {
            return "1 task still needs a decision"
        }
        return "\(count) tasks still need a decision"
    }

    var callToAction: String {
        if count == 0 { return "Go to Today" }
        if count == 1 { return "Resolve" }
        if dayCount <= 1 { return "Plan the Day" }
        if count >= 10 { return "Start" }
        return "Review"
    }

    var persistentCallToAction: String {
        count == 0 ? "Add Task" : "Open"
    }

    var launcherTitle: String {
        count == 0 ? "You're all caught up" : "Plan the Day"
    }

    var launcherBodyText: String {
        if count == 0 {
            return emptyStateMessage
        }
        return "Resolve overdue, carry-over, and unscheduled work before you shape what happens next."
    }

    var launcherPrimaryActionTitle: String {
        count == 0 ? "Add Task" : "Start Replan"
    }

    private var emptyStateMessage: String {
        let variants = [
            "Your day is clear. Add one task that makes today count.",
            "Nothing needs recovery right now. Add a task to build momentum.",
            "No backlog to clean up. Add a task and give today a target."
        ]
        let dayKey = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let stableIndex = abs(((dayKey.year ?? 0) * 10_000) + ((dayKey.month ?? 0) * 100) + (dayKey.day ?? 0)) % variants.count
        return variants[stableIndex]
    }
}

enum HomeReplanCandidateKind: Equatable {
    case pastDue
    case scheduledCarryOver
    case unscheduledBacklog
}

struct HomeReplanCandidate: Equatable, Identifiable {
    let task: TaskDefinition
    let kind: HomeReplanCandidateKind
    let anchorDate: Date?
    let anchorEndDate: Date?
    let projectName: String?

    var id: UUID { task.id }

    var anchorDay: Date? {
        anchorDate.map { Calendar.current.startOfDay(for: $0) }
    }

    var rescheduleDuration: TimeInterval {
        if let scheduledStartAt = task.scheduledStartAt,
           let scheduledEndAt = task.scheduledEndAt {
            return max(scheduledEndAt.timeIntervalSince(scheduledStartAt), 15 * 60)
        }
        if let anchorDate,
           let anchorEndDate {
            return max(anchorEndDate.timeIntervalSince(anchorDate), 15 * 60)
        }
        return max(task.estimatedDuration ?? (30 * 60), 15 * 60)
    }
}

struct HomeReplanOutcomeSummary: Equatable {
    var rescheduled: Int = 0
    var movedToInbox: Int = 0
    var completed: Int = 0
    var deleted: Int = 0

    var totalResolved: Int {
        rescheduled + movedToInbox + completed + deleted
    }
}

struct TimelinePlacementCandidate: Equatable, Identifiable {
    let taskID: UUID
    let title: String
    let duration: TimeInterval
    let tintHex: String?
    let isApplying: Bool
    let errorMessage: String?

    var id: UUID { taskID }
}

enum HomeReplanApplyingAction: Equatable {
    case moveToInbox
    case reschedule
    case checkOff
    case delete
    case undo
}

enum HomeReplanSessionPhase: Equatable {
    case trayHidden
    case trayVisible(NeedsReplanSummary)
    case launcher(NeedsReplanSummary)
    case card(candidateIndex: Int)
    case placement(HomeReplanCandidate, defaultDay: Date)
    case summary(HomeReplanOutcomeSummary, skippedCount: Int)
    case skippedReview
}

struct HomeReplanSessionState: Equatable {
    let phase: HomeReplanSessionPhase
    let summary: NeedsReplanSummary?
    let persistentSummary: NeedsReplanSummary
    let currentCandidate: HomeReplanCandidate?
    let candidateIndex: Int
    let candidateTotal: Int
    let canUndo: Bool
    let outcomes: HomeReplanOutcomeSummary
    let skippedCount: Int
    let isApplying: Bool
    let applyingAction: HomeReplanApplyingAction?
    let errorMessage: String?

    static let hidden = HomeReplanSessionState(
        phase: .trayHidden,
        summary: nil,
        persistentSummary: .empty,
        currentCandidate: nil,
        candidateIndex: 0,
        candidateTotal: 0,
        canUndo: false,
        outcomes: HomeReplanOutcomeSummary(),
        skippedCount: 0,
        isApplying: false,
        applyingAction: nil,
        errorMessage: nil
    )

    var launcherSummary: NeedsReplanSummary? {
        guard case .launcher(let summary) = phase else { return nil }
        return summary
    }

    var placementCandidate: TimelinePlacementCandidate? {
        guard case .placement(let candidate, _) = phase else { return nil }
        return TimelinePlacementCandidate(
            taskID: candidate.task.id,
            title: candidate.task.title,
            duration: candidate.rescheduleDuration,
            tintHex: nil,
            isApplying: isApplying,
            errorMessage: errorMessage
        )
    }

    var suppressesBottomBar: Bool {
        switch phase {
        case .card, .placement, .summary, .skippedReview:
            return true
        case .trayHidden, .trayVisible, .launcher:
            return false
        }
    }
}

struct TimelineWeekSummary: Equatable {
    let weekStart: Date
    let weekStartsOn: Weekday
    let days: [TimelineWeekDaySummary]
}

struct HomeTimelineSnapshot: Equatable {
    let selectedDate: Date
    let foredropAnchor: ForedropAnchor
    let day: TimelineDayProjection
    let week: TimelineWeekSummary
    let placementCandidate: TimelinePlacementCandidate?
}

struct HomeOverlaySnapshot: Equatable {
    let guidanceState: HomeOnboardingGuidanceModel.State?
    let focusWhyPresented: Bool
    let triagePresented: Bool
    let triageScope: EvaTriageScope
    let triageQueueLoading: Bool
    let triageQueueErrorMessage: String?
    let triageQueue: [EvaTriageQueueItem]
    let rescuePresented: Bool
    let rescuePlan: EvaRescuePlan?
    let lastBatchRunID: UUID?
    let lastXPResult: XPEventResult?
    let replanState: HomeReplanSessionState

    static let empty = HomeOverlaySnapshot(
        guidanceState: nil,
        focusWhyPresented: false,
        triagePresented: false,
        triageScope: .visible,
        triageQueueLoading: false,
        triageQueueErrorMessage: nil,
        triageQueue: [],
        rescuePresented: false,
        rescuePlan: nil,
        lastBatchRunID: nil,
        lastXPResult: nil,
        replanState: .hidden
    )

    static func == (lhs: HomeOverlaySnapshot, rhs: HomeOverlaySnapshot) -> Bool {
        lhs.guidanceState == rhs.guidanceState
            && lhs.focusWhyPresented == rhs.focusWhyPresented
            && lhs.triagePresented == rhs.triagePresented
            && lhs.triageScope == rhs.triageScope
            && lhs.triageQueueLoading == rhs.triageQueueLoading
            && lhs.triageQueueErrorMessage == rhs.triageQueueErrorMessage
            && lhs.triageQueue.map(\.task.id) == rhs.triageQueue.map(\.task.id)
            && lhs.rescuePresented == rhs.rescuePresented
            && String(describing: lhs.rescuePlan) == String(describing: rhs.rescuePlan)
            && lhs.lastBatchRunID == rhs.lastBatchRunID
            && String(describing: lhs.lastXPResult) == String(describing: rhs.lastXPResult)
            && lhs.replanState == rhs.replanState
    }
}

@MainActor
final class HomeChromeStore: ObservableObject {
    @Published private(set) var snapshot: HomeChromeSnapshot = .empty

    func apply(_ snapshot: HomeChromeSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeTasksStore: ObservableObject {
    @Published private(set) var snapshot: HomeTasksSnapshot = .empty

    func apply(_ snapshot: HomeTasksSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeHabitsStore: ObservableObject {
    @Published private(set) var snapshot: HomeHabitsSnapshot = .empty

    func apply(_ snapshot: HomeHabitsSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeOverlayStore: ObservableObject {
    @Published private(set) var snapshot: HomeOverlaySnapshot = .empty

    func apply(_ snapshot: HomeOverlaySnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeCalendarStore: ObservableObject {
    @Published private(set) var snapshot: HomeCalendarSnapshot = .empty

    func apply(_ snapshot: HomeCalendarSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeFaceCoordinator: ObservableObject {
    @Published private(set) var activeFace: HomeForedropFace = .tasks
    @Published private(set) var shellPhase: HomeShellPhase = .startup
    @Published private(set) var layoutMetrics: HomeLayoutMetrics = .zero
    @Published private(set) var searchMutationRevision: UInt64 = 0
    @Published private(set) var analyticsSurfaceState: HomeAnalyticsSurfaceState = .idle
    @Published private(set) var searchSurfaceState: HomeSearchSurfaceState = .idle
    @Published private(set) var chatPromptFocusRequestID: UInt64 = 0
    @Published var insightsViewModel: InsightsViewModel?

    let bottomBarState = HomeBottomBarState()

    func setActiveFace(_ face: HomeForedropFace) {
        guard activeFace != face else { return }
        activeFace = face
        bottomBarState.select(face.selectedBottomBarItem)
    }

    func setShellPhase(_ phase: HomeShellPhase) {
        guard shellPhase != phase else { return }
        shellPhase = phase
    }

    func setLayoutMetrics(_ metrics: HomeLayoutMetrics) {
        guard layoutMetrics != metrics else { return }
        layoutMetrics = metrics
    }

    func setAnalyticsSurfaceState(_ state: HomeAnalyticsSurfaceState) {
        guard analyticsSurfaceState != state else { return }
        analyticsSurfaceState = state
    }

    func setSearchSurfaceState(_ state: HomeSearchSurfaceState) {
        guard searchSurfaceState != state else { return }
        searchSurfaceState = state
    }

    func recordSearchMutation() {
        searchMutationRevision &+= 1
    }

    func requestChatPromptFocus() {
        chatPromptFocusRequestID &+= 1
    }
}

private struct PhoneHomeRootContainer: View {
    let root: HomeBackdropForedropRootView
    let layoutClass: TaskerLayoutClass

    var body: some View {
        root.taskerLayoutClass(layoutClass)
    }
}

private struct HomeHostRootView: View {
    let layoutClass: TaskerLayoutClass
    let phoneRoot: HomeBackdropForedropRootView?
    let iPadRoot: AnyView?

    @ViewBuilder
    var body: some View {
        if let phoneRoot {
            PhoneHomeRootContainer(root: phoneRoot, layoutClass: layoutClass)
        } else if let iPadRoot {
            iPadRoot
        } else {
            EmptyView()
        }
    }
}

private struct HomeBottomBarContainer: View {
    let state: HomeBottomBarState
    let shellPhase: HomeShellPhase
    let isConcealed: Bool
    let onHome: () -> Void
    let onCalendar: () -> Void
    let onChartsToggle: () -> Void
    let onSearch: () -> Void
    let onChat: () -> Void
    let onCreate: () -> Void
    let layoutClass: TaskerLayoutClass
    let onHeightChange: (CGFloat) -> Void

    var body: some View {
        HomeGlassBottomBar(
            state: state,
            shellPhase: shellPhase,
            onHome: onHome,
            onCalendar: onCalendar,
            onChartsToggle: onChartsToggle,
            onSearch: onSearch,
            onChat: onChat,
            onCreate: onCreate
        )
        .padding(.horizontal, TaskerThemeManager.shared.tokens(for: layoutClass).spacing.s16)
        .padding(.bottom, 0)
        .ignoresSafeArea(.container, edges: .bottom)
        .offset(y: 0)
        .allowsHitTesting(isConcealed == false)
        .accessibilityHidden(isConcealed)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        onHeightChange(proxy.size.height)
                    }
                    .onChange(of: proxy.size.height) { _, newValue in
                        onHeightChange(newValue)
                    }
            }
        }
    }
}

private var onboardingTaskDetailDismissBridgeKey: UInt8 = 0

private final class OnboardingTaskDetailDismissBridge: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}

final class HomeViewController: UIViewController, HomeViewControllerProtocol, HomeAnalyticsViewModelsInjectable, PresentationDependencyContainerAware, UIAdaptivePresentationControllerDelegate {
    private static var hasConsumedUITestRoute = false
    private static var hasConsumedUITestOpenSettings = false
    private static var hasSeededUITestEstablishedWorkspace = false
    private static var hasSeededUITestRescueWorkspace = false
    private static var hasSeededUITestFocusWorkspace = false
    private static var hasSeededUITestHabitBoardWorkspace = false
    private static var hasSeededUITestQuietTrackingWorkspace = false

    // MARK: - Dependencies

    var viewModel: HomeViewModel!
    var chartCardViewModel: ChartCardViewModel!
    var radarChartCardViewModel: RadarChartCardViewModel!
    var presentationDependencyContainer: PresentationDependencyContainer?

    // MARK: - UI

    private var homeHostingController: UIHostingController<HomeHostRootView>?
    private var bottomBarHostingController: UIHostingController<HomeBottomBarContainer>?
    private var bottomBarBottomConstraint: NSLayoutConstraint?
    private var bottomBarHeightConstraint: NSLayoutConstraint?
    private weak var presentedCalendarScheduleController: UIViewController?
    private weak var presentedEvaChatController: UIViewController?
    private var shouldResetHomeAfterEvaChatDismissal = false
    private var insightsViewModel: InsightsViewModel?
    private let searchState = HomeSearchState()
    private let chromeStore = HomeChromeStore()
    private let tasksStore = HomeTasksStore()
    private let habitsStore = HomeHabitsStore()
    private let calendarStore = HomeCalendarStore()
    private let overlayStore = HomeOverlayStore()
    private let faceCoordinator = HomeFaceCoordinator()

    // MARK: - State

    private let notificationCenter = NotificationCenter.default
    private var cancellables = Set<AnyCancellable>()
    private var pendingChartRefreshWorkItem: DispatchWorkItem?
    private let chartRefreshDebounceSeconds: TimeInterval = 0.12
    private var pendingNotificationFocusTaskID: UUID?
    private var syncOutageBanner: UIView?
    private var syncOutageLabel: UILabel?
    private var currentLayoutClass: TaskerLayoutClass = .phone
    private let iPadShellState = HomeiPadShellState()
    private let homeChatAppManager = AppManager()
    private var iPadShellEpoch = 0
    private var didTrackLayoutClassAtLaunch = false
    private var didTrackIPadShellRendered = false
    private var hasMountedStableLayoutShell = false
    private var pendingIPadModalRequest: HomeiPadModalRequest?
    private let onboardingGuidanceModel = HomeOnboardingGuidanceModel()
    private var onboardingCoordinator: AppOnboardingCoordinator?
    private var isEmbeddedChatRuntimeEntered = false
    private var pendingExitChatTask: Task<Void, Never>?
    private var pendingInsightsLaunchRequest: InsightsLaunchRequest?
    private var pendingInsightsPreparationTask: Task<Void, Never>?
    private var pendingSearchPreparationTask: Task<Void, Never>?
    private var pendingSearchWarmupTask: Task<Void, Never>?
    private var pendingSearchMutationRefreshTask: Task<Void, Never>?
    private var pendingBackgroundSearchPrewarmTask: Task<Void, Never>?
    private var pendingBackgroundInsightsPrewarmTask: Task<Void, Never>?
    private var pendingOnboardingEvaluationTask: Task<Void, Never>?
    private var awaitsAnalyticsFirstInteractiveFrame = false
    private var retainedHomeSearchEngine: LGHomeSearchEngine?
    private var onboardingEvaluationSceneToken: Int = 1
    private var completedOnboardingEvaluationSceneToken: Int = 0
    private var lastAppliedHomeRenderTransaction: HomeRenderTransaction = .empty
    private var keyboardOverlapHeight: CGFloat = 0
    private var measuredBottomBarHeight: CGFloat = 0
    private var isEmbeddedChatPromptFocused = false


    // MARK: - Lifecycle

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()

        injectDependenciesIfNeeded()
        bindTheme()
        bindViewModel()
        bindRenderPipeline()
        mountHomeShell()
        observeMutations()
        observeNotificationRoutes()
        observeChatDeepLinks()
        observeFocusDeepLinks()
        observeHomeDeepLinks()
        observeInsightsDeepLinks()
        observeTaskScopeDeepLinks()
        observeTaskDetailDeepLinks()
        observeHabitBoardDeepLinks()
        observeHabitLibraryDeepLinks()
        observeHabitDetailDeepLinks()
        observeQuickAddDeepLinks()
        observeCalendarScheduleDeepLinks()
        observeCalendarChooserDeepLinks()
        observeWeeklyPlannerDeepLinks()
        observeWeeklyReviewDeepLinks()
        observeWidgetActionCommands()
        observeTaskCreatedForSnackbar()
        observePersistentSyncMode()
        observeIPadShellTelemetry()
        observeOnboardingRequests()
        observeKeyboardFrameChanges()
        applyTheme()
        refreshPersistentSyncOutageBanner()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (self: Self, _) in
                self.refreshLayoutClassIfNeeded()
            }
        }
        onboardingCoordinator = AppOnboardingCoordinator(
            homeViewController: self,
            presentationDependencyContainer: presentationDependencyContainer,
            guidanceModel: onboardingGuidanceModel
        )
    }

    /// Executes viewWillAppear.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    /// Executes viewDidAppear.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resetHomeSelectionAfterEvaChatDismissalIfNeeded()
        if let pendingRoute = TaskerNotificationRouteBus.shared.consumePendingRoute() {
            handleNotificationRoute(pendingRoute)
        }
        consumePendingShortcutHandoffIfNeeded()
        consumeUITestInjectedRouteIfNeeded()
        consumeUITestOpenSettingsIfNeeded()
        processPendingWidgetActionCommand()
        processPendingIPadModalRequest()
        seedUITestEstablishedWorkspaceIfNeeded { [weak self] in
            self?.seedUITestRescueWorkspaceIfNeeded {
                self?.seedUITestFocusWorkspaceIfNeeded {
                    self?.seedUITestHabitBoardWorkspaceIfNeeded {
                        self?.seedUITestQuietTrackingWorkspaceIfNeeded {
                            self?.viewModel.loadTodayTasks()
                            self?.scheduleOnboardingEvaluationIfNeeded()
                        }
                    }
                }
            }
        }
    }

    /// Executes viewDidLayoutSubviews.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshLayoutClassIfNeeded()
        refreshLayoutMetrics()
        updateInteractivePhaseIfNeeded()
        mountBottomBarOverlayIfNeeded()
        updateBottomBarBottomConstraint()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        refreshLayoutMetrics()
        updateBottomBarBottomConstraint()
    }

    /// Executes viewWillDisappear.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    deinit {
        pendingInsightsPreparationTask?.cancel()
        pendingSearchPreparationTask?.cancel()
        pendingSearchWarmupTask?.cancel()
        pendingSearchMutationRefreshTask?.cancel()
        pendingBackgroundSearchPrewarmTask?.cancel()
        pendingBackgroundInsightsPrewarmTask?.cancel()
        pendingOnboardingEvaluationTask?.cancel()
        pendingExitChatTask?.cancel()
        retainedHomeSearchEngine = nil
        notificationCenter.removeObserver(self)
    }

    // MARK: - Setup

    /// Executes injectDependenciesIfNeeded.
    private func injectDependenciesIfNeeded() {
        guard viewModel != nil else {
            fatalError("HomeViewController requires injected HomeViewModel")
        }
        guard chartCardViewModel != nil else {
            fatalError("HomeViewController requires injected ChartCardViewModel")
        }
        guard radarChartCardViewModel != nil else {
            fatalError("HomeViewController requires injected RadarChartCardViewModel")
        }
        guard presentationDependencyContainer != nil else {
            fatalError("HomeViewController requires injected PresentationDependencyContainer")
        }
    }

    /// Executes bindTheme.
    private func bindTheme() {
        TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }

    /// Executes bindViewModel.
    private func bindViewModel() {
        // HomeViewModel performs initial data loading in its initializer.
        // Keep this hook for future bindings, but avoid duplicate startup fetches.
    }

    private func bindRenderPipeline() {
        viewModel.$homeRenderTransaction
            .receive(on: RunLoop.main)
            .sink { [weak self] transaction in
                self?.applyHomeRenderTransaction(transaction)
            }
            .store(in: &cancellables)

        onboardingGuidanceModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyOverlayState(self.viewModel.homeRenderTransaction.overlay)
            }
            .store(in: &cancellables)

        viewModel.$insightsLaunchRequest
            .receive(on: RunLoop.main)
            .sink { [weak self] request in
                self?.handleInsightsLaunchRequest(request)
            }
            .store(in: &cancellables)

        faceCoordinator.$activeFace
            .receive(on: RunLoop.main)
            .sink { [weak self] activeFace in
                self?.trackFaceSelection(activeFace)
                switch activeFace {
                case .tasks:
                    self?.scheduleOnboardingEvaluationIfNeeded()
                    self?.scheduleBackgroundSurfacePrewarmIfNeeded()
                case .schedule:
                    self?.cancelBackgroundSearchPrewarm()
                    self?.cancelBackgroundSurfacePrewarm()
                case .analytics:
                    self?.cancelBackgroundSearchPrewarm()
                case .search:
                    self?.cancelBackgroundSurfacePrewarm()
                case .chat:
                    self?.cancelBackgroundSearchPrewarm()
                    self?.cancelBackgroundSurfacePrewarm()
                }
                self?.setEmbeddedChatRuntimeVisible(activeFace == .chat, trigger: "home_chat_face")
                if activeFace != .chat {
                    self?.isEmbeddedChatPromptFocused = false
                }
                self?.refreshLayoutMetrics()
                self?.mountBottomBarOverlayIfNeeded()
            }
            .store(in: &cancellables)

        faceCoordinator.$shellPhase
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.mountBottomBarOverlayIfNeeded()
                self?.scheduleOnboardingEvaluationIfNeeded()
                self?.scheduleBackgroundSurfacePrewarmIfNeeded()
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.onboardingEvaluationSceneToken &+= 1
                self.consumePendingShortcutHandoffIfNeeded()
                self.scheduleOnboardingEvaluationIfNeeded()
                self.viewModel?.refreshWeeklySummaryNow()
                self.presentationDependencyContainer?.coordinator.calendarIntegrationService.refreshContext(
                    reason: "app_did_become_active"
                )
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIApplication.significantTimeChangeNotification)
            .merge(with: notificationCenter.publisher(for: TaskerWorkspacePreferencesStore.didChangeNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.viewModel?.refreshWeeklySummaryNow()
                self?.presentationDependencyContainer?.coordinator.calendarIntegrationService.refreshContext(
                    reason: "significant_time_change"
                )
            }
            .store(in: &cancellables)

        faceCoordinator.$searchMutationRevision
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSearchMutationRevision()
            }
            .store(in: &cancellables)
    }

    private var isUsingIPadNativeShell: Bool {
        currentLayoutClass.isPad && V2FeatureFlags.iPadNativeShellEnabled
    }

    private func calendarScheduleSelectedDateBinding() -> Binding<Date> {
        Binding(
            get: { [weak self] in
                self?.viewModel?.selectedDate ?? Date()
            },
            set: { [weak self] date in
                self?.viewModel?.selectDate(date, source: .datePicker)
            }
        )
    }

    /// Executes refreshLayoutClassIfNeeded.
    private func refreshLayoutClassIfNeeded() {
        let nextLayoutClass = TaskerLayoutResolver.classify(view: view)
        guard nextLayoutClass != currentLayoutClass || homeHostingController == nil else { return }
        currentLayoutClass = nextLayoutClass
        mountHomeShell()
    }

    private var hasStableLayoutMetrics: Bool {
        let metrics = TaskerLayoutResolver.metrics(for: view)
        return metrics.width > 1 && metrics.height > 1
    }

    private func scheduleInsightsPreparationIfNeeded() {
        guard faceCoordinator.insightsViewModel == nil else {
            faceCoordinator.setAnalyticsSurfaceState(.ready)
            emitAnalyticsFirstInteractiveFrameIfNeeded()
            applyPendingInsightsLaunchRequestIfNeeded()
            return
        }

        pendingInsightsPreparationTask?.cancel()
        faceCoordinator.setAnalyticsSurfaceState(.placeholder)

        let interval = TaskerPerformanceTrace.begin("HomeInsightsFirstMount")
        pendingInsightsPreparationTask = Task { @MainActor [weak self] in
            defer {
                TaskerPerformanceTrace.end(interval)
                self?.pendingInsightsPreparationTask = nil
            }
            guard let self else { return }

            TaskerPerformanceTrace.event("HomeAnalyticsPlaceholderShown")
            await Task.yield()
            guard Task.isCancelled == false, self.faceCoordinator.activeFace == .analytics else { return }

            self.faceCoordinator.setAnalyticsSurfaceState(.loading)
            _ = self.prepareInsightsViewModelIfNeeded()
            guard Task.isCancelled == false else { return }

            self.faceCoordinator.setAnalyticsSurfaceState(.ready)
            TaskerPerformanceTrace.event("HomeAnalyticsReady")
            self.emitAnalyticsFirstInteractiveFrameIfNeeded()
            self.applyPendingInsightsLaunchRequestIfNeeded()
        }
    }

    private func scheduleOnboardingEvaluationIfNeeded() {
        guard isViewLoaded, view.window != nil else { return }
        guard faceCoordinator.shellPhase == .interactive else { return }
        guard faceCoordinator.activeFace == .tasks else { return }
        guard presentedViewController == nil else { return }
        guard onboardingEvaluationSceneToken > completedOnboardingEvaluationSceneToken else { return }
        guard pendingOnboardingEvaluationTask == nil else { return }

        let sceneToken = onboardingEvaluationSceneToken
        pendingOnboardingEvaluationTask = Task { @MainActor [weak self] in
            await self?.runOnboardingEvaluationAfterDelay(sceneToken: sceneToken)
        }
    }

    private func handleInsightsLaunchRequest(_ request: InsightsLaunchRequest?) {
        guard let request else { return }
        pendingInsightsLaunchRequest = request
        if faceCoordinator.activeFace == .analytics {
            scheduleInsightsPreparationIfNeeded()
            applyPendingInsightsLaunchRequestIfNeeded()
            return
        }
        openAnalytics(source: "launch_request", launchDefaultInsights: false)
    }

    private func applyPendingInsightsLaunchRequestIfNeeded() {
        guard let request = pendingInsightsLaunchRequest else { return }
        guard let insightsViewModel = faceCoordinator.insightsViewModel else { return }
        pendingInsightsLaunchRequest = nil
        insightsViewModel.selectTab(request.targetTab)
        insightsViewModel.highlightAchievement(request.highlightedAchievementKey)
    }

    private func trackFaceSelection(_ activeFace: HomeForedropFace) {
        let faceName: String
        switch activeFace {
        case .tasks:
            faceName = "tasks"
        case .schedule:
            faceName = "schedule"
        case .analytics:
            faceName = "analytics"
        case .search:
            faceName = "search"
        case .chat:
            faceName = "chat"
        }
        logDebug("HOME_RENDER face=\(faceName) phase=\(faceCoordinator.shellPhase.rawValue)")
    }

    private func setEmbeddedChatRuntimeVisible(_ isVisible: Bool, trigger: String) {
        if isVisible {
            pendingExitChatTask?.cancel()
            pendingExitChatTask = nil
            guard isEmbeddedChatRuntimeEntered == false else { return }
            isEmbeddedChatRuntimeEntered = true
            LLMRuntimeCoordinator.shared.enterChatScreen(trigger: trigger)
        } else {
            guard isEmbeddedChatRuntimeEntered else { return }
            isEmbeddedChatRuntimeEntered = false
            pendingExitChatTask?.cancel()
            pendingExitChatTask = Task { @MainActor [weak self] in
                guard Task.isCancelled == false else { return }
                await LLMRuntimeCoordinator.shared.exitChatScreen(reason: "home_chat_face_exit")
                guard Task.isCancelled == false else { return }
                self?.pendingExitChatTask = nil
            }
        }
    }

    private func openSchedule(source: String) {
        if isUsingIPadNativeShell {
            unwindActiveFaceForIPadDestination(source: source)
            iPadShellState.destination = .schedule
            return
        }
        guard faceCoordinator.activeFace != .schedule else { return }
        cancelBackgroundSearchPrewarm()
        cancelBackgroundSurfacePrewarm()
        pendingOnboardingEvaluationTask?.cancel()
        pendingOnboardingEvaluationTask = nil
        if faceCoordinator.activeFace == .search {
            pendingSearchPreparationTask?.cancel()
            pendingSearchWarmupTask?.cancel()
            pendingSearchMutationRefreshTask?.cancel()
            searchState.releaseResources()
            retainedHomeSearchEngine = nil
            viewModel.releaseHomeSearchViewModel()
            faceCoordinator.setSearchSurfaceState(.idle)
        }
        TaskerPerformanceTrace.event("HomeFaceSwitch")
        TaskerMemoryDiagnostics.checkpoint(
            event: "home_schedule_open",
            message: "Opening schedule surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.schedule)
        viewModel.trackHomeInteraction(
            action: "home_schedule_flip_open",
            metadata: ["source": source]
        )
    }

    private func unwindActiveFaceForIPadDestination(source: String) {
        guard faceCoordinator.activeFace != .tasks else { return }
        returnToTasks(source: source)
    }

    private func openAnalytics(source: String, launchDefaultInsights: Bool) {
        guard faceCoordinator.activeFace != .analytics else { return }
        cancelBackgroundSearchPrewarm()
        pendingOnboardingEvaluationTask?.cancel()
        pendingOnboardingEvaluationTask = nil
        awaitsAnalyticsFirstInteractiveFrame = true
        TaskerPerformanceTrace.event("HomeFaceSwitch")
        TaskerMemoryDiagnostics.checkpoint(
            event: "home_insights_open",
            message: "Opening insights surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.analytics)
        faceCoordinator.setAnalyticsSurfaceState(faceCoordinator.insightsViewModel == nil ? .placeholder : .ready)
        if launchDefaultInsights {
            viewModel.launchInsights(.default)
        }
        viewModel.trackHomeInteraction(
            action: "home_insights_flip_open",
            metadata: ["source": source]
        )
        scheduleInsightsPreparationIfNeeded()
    }

    @MainActor
    func runOnboardingEvaluationAfterDelay(
        sceneToken: Int,
        sleepNanoseconds: UInt64 = 2_000_000_000,
        retry: (@MainActor () -> Void)? = nil
    ) async {
        let clear = { [weak self] in
            self?.pendingOnboardingEvaluationTask = nil
        }
        defer { clear() }

        do {
            try await Task.sleep(nanoseconds: sleepNanoseconds)
        } catch {
            return
        }

        guard Task.isCancelled == false else { return }
        let retryEvaluation = retry ?? { [weak self] in
            self?.scheduleOnboardingEvaluationIfNeeded()
        }

        guard sceneToken == self.onboardingEvaluationSceneToken else {
            retryEvaluation()
            return
        }
        guard self.isViewLoaded, self.view.window != nil else {
            retryEvaluation()
            return
        }
        guard self.faceCoordinator.shellPhase == .interactive else {
            retryEvaluation()
            return
        }
        guard self.faceCoordinator.activeFace == .tasks else {
            retryEvaluation()
            return
        }
        guard self.presentedViewController == nil else {
            retryEvaluation()
            return
        }

        let interval = TaskerPerformanceTrace.begin("HomeOnboardingLaunchEval")
        self.onboardingCoordinator?.evaluateLaunchIfNeeded()
        self.onboardingCoordinator?.drainPendingPresentationIfPossible()
        TaskerPerformanceTrace.end(interval)
        self.completedOnboardingEvaluationSceneToken = sceneToken
    }

    private func closeAnalytics(source: String) {
        guard faceCoordinator.activeFace == .analytics else { return }
        if faceCoordinator.insightsViewModel == nil {
            pendingInsightsPreparationTask?.cancel()
        }
        awaitsAnalyticsFirstInteractiveFrame = false
        TaskerPerformanceTrace.event("HomeFaceSwitch")
        TaskerMemoryDiagnostics.checkpoint(
            event: "home_insights_close",
            message: "Closing insights surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.tasks)
        faceCoordinator.setAnalyticsSurfaceState(.idle)
        viewModel.trackHomeInteraction(
            action: "home_insights_flip_close",
            metadata: ["source": source]
        )
    }

    private func toggleInsights(source: String) {
        if faceCoordinator.activeFace == .analytics {
            closeAnalytics(source: source)
        } else {
            openAnalytics(source: source, launchDefaultInsights: true)
        }
    }

    private func openSearch(source: String) {
        guard faceCoordinator.activeFace != .search else { return }
        cancelBackgroundSurfacePrewarm()
        pendingSearchPreparationTask?.cancel()
        pendingSearchWarmupTask?.cancel()
        pendingOnboardingEvaluationTask?.cancel()
        pendingOnboardingEvaluationTask = nil
        TaskerPerformanceTrace.event("HomeFaceSwitch")
        TaskerMemoryDiagnostics.checkpoint(
            event: "home_search_open",
            message: "Opening search surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.search)
        faceCoordinator.setSearchSurfaceState(.presenting)
        TaskerPerformanceTrace.event("HomeSearchTapped")
        viewModel.trackHomeInteraction(
            action: "home_search_flip_open",
            metadata: ["source": source]
        )
        scheduleSearchPreparation()
    }

    private func closeSearch(source: String) {
        guard faceCoordinator.activeFace == .search else { return }
        pendingSearchPreparationTask?.cancel()
        pendingSearchWarmupTask?.cancel()
        pendingSearchMutationRefreshTask?.cancel()
        TaskerPerformanceTrace.event("HomeFaceSwitch")
        searchState.releaseResources()
        retainedHomeSearchEngine = nil
        viewModel.releaseHomeSearchViewModel()
        TaskerMemoryDiagnostics.checkpoint(
            event: "home_search_close",
            message: "Closing search surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.tasks)
        faceCoordinator.setSearchSurfaceState(.idle)
        viewModel.trackHomeInteraction(
            action: "home_search_flip_close",
            metadata: ["source": source]
        )
    }

    private func toggleSearch(source: String) {
        if faceCoordinator.activeFace == .search {
            closeSearch(source: source)
        } else {
            openSearch(source: source)
        }
    }

    private func openChat(source: String) {
        presentEvaChatScreen(source: source)
    }

    private func presentEvaChatScreen(source: String) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .chat
            return
        }

        if presentedEvaChatController != nil,
           presentedViewController === presentedEvaChatController {
            return
        }

        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.presentEvaChatScreen(source: source)
            }
            return
        }

        cancelBackgroundSearchPrewarm()
        cancelBackgroundSurfacePrewarm()
        pendingOnboardingEvaluationTask?.cancel()
        pendingOnboardingEvaluationTask = nil

        if faceCoordinator.activeFace == .search {
            pendingSearchPreparationTask?.cancel()
            pendingSearchWarmupTask?.cancel()
            pendingSearchMutationRefreshTask?.cancel()
            searchState.releaseResources()
            retainedHomeSearchEngine = nil
            viewModel.releaseHomeSearchViewModel()
            faceCoordinator.setSearchSurfaceState(.idle)
        }

        if faceCoordinator.activeFace == .chat {
            faceCoordinator.setActiveFace(.tasks)
        }
        isEmbeddedChatPromptFocused = false
        setEmbeddedChatRuntimeVisible(false, trigger: "dedicated_chat_screen")

        let chatHostVC = ChatHostViewController()
        if let presentationDependencyContainer {
            _ = presentationDependencyContainer.tryInject(into: chatHostVC)
        }
        let navController = UINavigationController(rootViewController: chatHostVC)
        navController.modalPresentationStyle = .fullScreen
        navController.navigationBar.prefersLargeTitles = false
        presentedEvaChatController = navController
        shouldResetHomeAfterEvaChatDismissal = true
        navController.presentationController?.delegate = self

        TaskerMemoryDiagnostics.checkpoint(
            event: "home_chat_open",
            message: "Opening Eva chat screen",
            fields: ["source": source]
        )
        viewModel.trackHomeInteraction(
            action: "home_chat_screen_open",
            metadata: ["source": source]
        )
        present(navController, animated: true)
    }

    private func closeChat(source: String) {
        guard faceCoordinator.activeFace == .chat else { return }
        TaskerPerformanceTrace.event("HomeFaceSwitch")
        TaskerMemoryDiagnostics.checkpoint(
            event: "home_chat_close",
            message: "Closing Eva chat surface",
            fields: ["source": source]
        )
        faceCoordinator.setActiveFace(.tasks)
        viewModel.trackHomeInteraction(
            action: "home_chat_flip_close",
            metadata: ["source": source]
        )
    }

    private func returnToTasks(source: String) {
        switch faceCoordinator.activeFace {
        case .tasks:
            faceCoordinator.bottomBarState.select(.home)
        case .schedule:
            TaskerPerformanceTrace.event("HomeFaceSwitch")
            faceCoordinator.setActiveFace(.tasks)
            viewModel.trackHomeInteraction(
                action: "home_schedule_flip_close",
                metadata: ["source": source]
            )
        case .analytics:
            closeAnalytics(source: source)
        case .search:
            closeSearch(source: source)
        case .chat:
            closeChat(source: source)
        }
    }

    private func handleTaskListChromeStateChange(_ state: HomeScrollChromeState) {
        faceCoordinator.bottomBarState.handleChromeStateChange(state)
    }

    private func scheduleSearchPreparation() {
        let interval = TaskerPerformanceTrace.begin("HomeSearchSurface")
        pendingSearchPreparationTask = Task { @MainActor [weak self] in
            defer {
                TaskerPerformanceTrace.end(interval)
                self?.pendingSearchPreparationTask = nil
            }
            guard let self else { return }

            await Task.yield()
            guard Task.isCancelled == false, self.faceCoordinator.activeFace == .search else { return }

            TaskerPerformanceTrace.event("HomeSearchSurfaceVisible")
            self.faceCoordinator.setSearchSurfaceState(.preparing)
            self.searchState.configureIfNeeded(
                makeEngine: {
                    self.resolveHomeSearchEngine()
                },
                dataRevisionProvider: {
                    self.viewModel.currentDataRevision
                }
            )
            TaskerPerformanceTrace.event("HomeSearchConfigured")
            guard Task.isCancelled == false, self.faceCoordinator.activeFace == .search else { return }

            self.faceCoordinator.setSearchSurfaceState(.ready)
            TaskerPerformanceTrace.event("HomeSearchSurfaceReady")
            TaskerPerformanceTrace.event("HomeSearchFirstInteractiveFrame")
            self.scheduleInitialSearchWarmupIfNeeded()
        }
    }

    private func emitAnalyticsFirstInteractiveFrameIfNeeded() {
        guard awaitsAnalyticsFirstInteractiveFrame else { return }
        guard faceCoordinator.activeFace == .analytics else { return }
        guard faceCoordinator.analyticsSurfaceState == .ready else { return }
        awaitsAnalyticsFirstInteractiveFrame = false
        TaskerPerformanceTrace.event("HomeAnalyticsFirstInteractiveFrame")
    }

    private func scheduleBackgroundSurfacePrewarmIfNeeded() {
        guard faceCoordinator.shellPhase == .interactive else { return }
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            cancelBackgroundSurfacePrewarm()
            return
        }
        guard faceCoordinator.activeFace == .tasks else { return }

        if pendingBackgroundSearchPrewarmTask == nil {
            pendingBackgroundSearchPrewarmTask = Task(priority: .utility) { @MainActor [weak self] in
                defer { self?.pendingBackgroundSearchPrewarmTask = nil }
                do {
                    try await Task.sleep(nanoseconds: 800_000_000)
                } catch {
                    return
                }
                guard let self, Task.isCancelled == false else { return }
                guard self.faceCoordinator.activeFace == .tasks else { return }
                self.searchState.configureIfNeeded(
                    makeEngine: {
                        self.resolveHomeSearchEngine()
                    },
                    dataRevisionProvider: {
                        self.viewModel.currentDataRevision
                    }
                )
                TaskerPerformanceTrace.event("HomeSearchSurfaceReady")
            }
        }

        if pendingBackgroundInsightsPrewarmTask == nil {
            pendingBackgroundInsightsPrewarmTask = Task(priority: .utility) { @MainActor [weak self] in
                defer { self?.pendingBackgroundInsightsPrewarmTask = nil }
                do {
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                } catch {
                    return
                }
                guard let self, Task.isCancelled == false else { return }
                guard self.faceCoordinator.activeFace == .tasks else { return }
                let resolvedViewModel = self.prepareInsightsViewModelIfNeeded()
                resolvedViewModel.onAppear()
            }
        }
    }

    private func cancelBackgroundSurfacePrewarm() {
        cancelBackgroundSearchPrewarm()
        cancelBackgroundInsightsPrewarm()
    }

    private func cancelBackgroundSearchPrewarm() {
        pendingBackgroundSearchPrewarmTask?.cancel()
        pendingBackgroundSearchPrewarmTask = nil
    }

    private func cancelBackgroundInsightsPrewarm() {
        pendingBackgroundInsightsPrewarmTask?.cancel()
        pendingBackgroundInsightsPrewarmTask = nil
    }

    @discardableResult
    private func prepareInsightsViewModelIfNeeded() -> InsightsViewModel {
        if let existing = faceCoordinator.insightsViewModel {
            insightsViewModel = existing
            return existing
        }

        let resolvedViewModel = viewModel.makeInsightsViewModel()
        insightsViewModel = resolvedViewModel
        faceCoordinator.insightsViewModel = resolvedViewModel
        return resolvedViewModel
    }

    private func resolveHomeSearchEngine() -> LGHomeSearchEngine {
        if let retainedHomeSearchEngine {
            return retainedHomeSearchEngine
        }
        let engine = LGHomeSearchEngine(viewModel: viewModel.makeHomeSearchViewModel())
        retainedHomeSearchEngine = engine
        return engine
    }

    private func scheduleInitialSearchWarmupIfNeeded() {
        pendingSearchWarmupTask?.cancel()
        pendingSearchWarmupTask = Task { @MainActor [weak self] in
            defer { self?.pendingSearchWarmupTask = nil }
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }
            guard let self, Task.isCancelled == false else { return }
            guard self.faceCoordinator.activeFace == .search else { return }
            guard self.faceCoordinator.searchSurfaceState == .ready else { return }
            self.searchState.activate()
        }
    }

    private func handleSearchMutationRevision() {
        searchState.markDataMutated()
        guard faceCoordinator.activeFace == .search, faceCoordinator.searchSurfaceState == .ready else { return }

        pendingSearchMutationRefreshTask?.cancel()
        pendingSearchMutationRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard Task.isCancelled == false,
                  self.faceCoordinator.activeFace == .search,
                  self.faceCoordinator.searchSurfaceState == .ready else {
                return
            }
            self.searchState.refresh(immediate: true)
        }
    }

    private func computeHomeLayoutMetrics() -> HomeLayoutMetrics {
        let safeAreaInsets = view.safeAreaInsets
        let width = view.bounds.width
        let height = view.bounds.height
        let tokens = TaskerThemeManager.shared.tokens(for: currentLayoutClass)
        let spacing = tokens.spacing
        let defaultBottomBarHeight = spacing.s12 + 56
        let shouldShowBottomBar = currentLayoutClass == .phone
            && faceCoordinator.shellPhase == .interactive
            && overlayStore.snapshot.replanState.suppressesBottomBar == false
        let bottomOverlayObstruction = currentLayoutClass == .phone
            ? (shouldShowBottomBar ? max(measuredBottomBarHeight, defaultBottomBarHeight) : 0)
            : 0
        let taskListBottomInset = currentLayoutClass == .phone
            ? bottomOverlayObstruction + spacing.s16
            : spacing.s24
        let isChatBottomBarConcealed = isBottomBarConcealedForChatInput
        let chatComposerBottomInset = HomeBottomBarVisibilityPolicy.chatComposerClearance(
            layoutClass: currentLayoutClass,
            bottomOverlayObstruction: bottomOverlayObstruction,
            keyboardOverlapHeight: keyboardOverlapHeight,
            isBottomBarConcealed: isChatBottomBarConcealed,
            idleSpacing: spacing.s40,
            idleExtraSpacing: spacing.s24,
            keyboardSpacing: spacing.s16,
            regularSpacing: spacing.s24
        )
        let chartViewportHeight = min(max(height * 0.66, 560), max(560, height - 150))

        return HomeLayoutMetrics(
            width: width,
            height: height,
            safeAreaTop: safeAreaInsets.top,
            safeAreaBottom: safeAreaInsets.bottom,
            keyboardOverlapHeight: keyboardOverlapHeight,
            backdropGradientHeight: height + safeAreaInsets.top + safeAreaInsets.bottom,
            taskListBottomInset: taskListBottomInset,
            chatComposerBottomInset: chatComposerBottomInset,
            chartViewportHeight: chartViewportHeight
        )
    }

    private func refreshLayoutMetrics() {
        faceCoordinator.setLayoutMetrics(computeHomeLayoutMetrics())
    }

    private func configureSafeAreaRegions(for hostingController: UIHostingController<HomeHostRootView>) {
        hostingController.safeAreaRegions = currentLayoutClass == .phone ? .container : .all
    }

    private func observeKeyboardFrameChanges() {
        notificationCenter.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleKeyboardFrameChange(notification)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setKeyboardOverlapHeight(0)
            }
            .store(in: &cancellables)
    }

    private func handleKeyboardFrameChange(_ notification: Notification) {
        guard currentLayoutClass == .phone else {
            setKeyboardOverlapHeight(0)
            return
        }

        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        let overlapHeight = max(0, view.bounds.maxY - keyboardFrameInView.minY)
        let adjustedOverlapHeight = max(0, overlapHeight - view.safeAreaInsets.bottom)
        setKeyboardOverlapHeight(adjustedOverlapHeight)
    }

    private func setKeyboardOverlapHeight(_ newValue: CGFloat) {
        let sanitizedValue = max(0, newValue)
        guard abs(keyboardOverlapHeight - sanitizedValue) > 0.5 else { return }
        keyboardOverlapHeight = sanitizedValue
        refreshLayoutMetrics()
        mountBottomBarOverlayIfNeeded()
        updateBottomBarBottomConstraint()
    }

    private var isBottomBarConcealedForChatInput: Bool {
        HomeBottomBarVisibilityPolicy.shouldConcealBottomBar(
            activeFace: faceCoordinator.activeFace,
            isPromptFocused: isEmbeddedChatPromptFocused,
            keyboardOverlapHeight: keyboardOverlapHeight
        )
    }

    private func setEmbeddedChatPromptFocused(_ isFocused: Bool) {
        guard isEmbeddedChatPromptFocused != isFocused else {
            refreshLayoutMetrics()
            mountBottomBarOverlayIfNeeded()
            updateBottomBarBottomConstraint()
            return
        }
        isEmbeddedChatPromptFocused = isFocused
        refreshLayoutMetrics()
        mountBottomBarOverlayIfNeeded()
        updateBottomBarBottomConstraint()
    }

    private func updateInteractivePhaseIfNeeded() {
        let layoutMetrics = faceCoordinator.layoutMetrics
        let tasksState = tasksStore.snapshot
        if faceCoordinator.shellPhase == .startup,
           layoutMetrics.isReady,
           tasksState.hasCommittedInitialContent {
            faceCoordinator.setShellPhase(.interactive)
        }
    }

    private func applyHomeRenderTransaction(_ transaction: HomeRenderTransaction) {
        guard transaction != lastAppliedHomeRenderTransaction else { return }

        let changedSliceCount = transaction.changedSliceCount(comparedTo: lastAppliedHomeRenderTransaction)
        let interval = TaskerPerformanceTrace.begin("HomeRenderTransactionCommit")
        defer {
            TaskerPerformanceTrace.event("HomeRenderSliceCommits", value: changedSliceCount)
            TaskerPerformanceTrace.end(interval)
            lastAppliedHomeRenderTransaction = transaction
        }

        if transaction.chrome != lastAppliedHomeRenderTransaction.chrome {
            chromeStore.apply(transaction.chrome)
        }
        if transaction.tasks != lastAppliedHomeRenderTransaction.tasks {
            tasksStore.apply(transaction.tasks)
            updateInteractivePhaseIfNeeded()
        }
        if transaction.habits != lastAppliedHomeRenderTransaction.habits {
            habitsStore.apply(transaction.habits)
            TaskerPerformanceTrace.event("home.render.habitsCommitted")
        }
        if transaction.calendar != lastAppliedHomeRenderTransaction.calendar {
            calendarStore.apply(transaction.calendar)
            TaskerPerformanceTrace.event("home.render.calendarCommitted")
        }
        if transaction.overlay != lastAppliedHomeRenderTransaction.overlay {
            applyOverlayState(transaction.overlay)
        }
    }

    private func applyOverlayState(_ state: HomeOverlayState) {
        overlayStore.apply(
            HomeOverlaySnapshot(
                guidanceState: onboardingGuidanceModel.state,
                focusWhyPresented: state.focusWhyPresented,
                triagePresented: state.triagePresented,
                triageScope: state.triageScope,
                triageQueueLoading: state.triageQueueLoading,
                triageQueueErrorMessage: state.triageQueueErrorMessage,
                triageQueue: state.triageQueue,
                rescuePresented: state.rescuePresented,
                rescuePlan: state.rescuePlan,
                lastBatchRunID: state.lastBatchRunID,
                lastXPResult: state.lastXPResult,
                replanState: state.replanState
            )
        )
        mountBottomBarOverlayIfNeeded()
    }

    private func mountBottomBarOverlayIfNeeded() {
        let shouldShowBottomBar = currentLayoutClass == .phone
            && faceCoordinator.shellPhase == .interactive
            && overlayStore.snapshot.replanState.suppressesBottomBar == false
        if shouldShowBottomBar == false {
            if measuredBottomBarHeight != 0 {
                measuredBottomBarHeight = 0
                refreshLayoutMetrics()
            }
            if let bottomBarHostingController {
                bottomBarHostingController.willMove(toParent: nil)
                bottomBarHostingController.view.removeFromSuperview()
                bottomBarHostingController.removeFromParent()
                self.bottomBarHostingController = nil
                bottomBarBottomConstraint = nil
                bottomBarHeightConstraint = nil
            }
            return
        }

        let root = makeBottomBarRoot()
        if let bottomBarHostingController {
            bottomBarHostingController.rootView = root
            applyBottomBarConcealmentState()
            updateBottomBarHeightConstraint()
            updateBottomBarBottomConstraint()
            return
        }

        let hostingController = UIHostingController(rootView: root)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingController)
        view.addSubview(hostingController.view)
        let bottomConstraint = hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        let heightConstraint = hostingController.view.heightAnchor.constraint(equalToConstant: resolvedBottomBarHostHeight())
        bottomBarBottomConstraint = bottomConstraint
        bottomBarHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            heightConstraint
        ])
        updateBottomBarBottomConstraint()
        hostingController.didMove(toParent: self)
        bottomBarHostingController = hostingController
        applyBottomBarConcealmentState()
    }

    private func applyBottomBarConcealmentState() {
        guard let bottomBarHostingController else { return }
        let isConcealed = isBottomBarConcealedForChatInput
        bottomBarHostingController.view.alpha = isConcealed ? 0 : 1
        bottomBarHostingController.view.isUserInteractionEnabled = !isConcealed
        bottomBarHostingController.view.accessibilityElementsHidden = isConcealed
    }

    private func resolvedBottomBarHostHeight() -> CGFloat {
        guard currentLayoutClass == .phone else { return 0 }
        let tokens = TaskerThemeManager.shared.tokens(for: currentLayoutClass)
        return max(measuredBottomBarHeight, tokens.spacing.s12 + 56)
    }

    private func updateBottomBarHeightConstraint() {
        guard let bottomBarHeightConstraint else { return }
        let height = resolvedBottomBarHostHeight()
        guard abs(bottomBarHeightConstraint.constant - height) > 0.5 else { return }
        bottomBarHeightConstraint.constant = height
    }

    private func makeBottomBarRoot() -> HomeBottomBarContainer {
        HomeBottomBarContainer(
            state: faceCoordinator.bottomBarState,
            shellPhase: faceCoordinator.shellPhase,
            isConcealed: isBottomBarConcealedForChatInput,
            onHome: { [weak self] in
                self?.returnToTasks(source: "bottom_bar_home")
            },
            onCalendar: { [weak self] in
                self?.openSchedule(source: "bottom_bar_schedule")
            },
            onChartsToggle: { [weak self] in
                self?.toggleInsights(source: "bottom_bar_analytics")
            },
            onSearch: { [weak self] in
                self?.toggleSearch(source: "bottom_bar_search")
            },
            onChat: { [weak self] in
                self?.openChat(source: "bottom_bar_chat")
            },
            onCreate: { [weak self] in
                if self?.isUsingIPadNativeShell == true {
                    if self?.currentLayoutClass == .padExpanded {
                        self?.iPadShellState.destination = .addTask
                    } else {
                        self?.presentAddTaskSheetForPadFallback()
                    }
                } else {
                    self?.AddTaskAction()
                }
            },
            layoutClass: currentLayoutClass,
            onHeightChange: { [weak self] height in
                self?.setMeasuredBottomBarHeight(height)
            }
        )
    }

    private func setMeasuredBottomBarHeight(_ newValue: CGFloat) {
        let sanitizedValue = max(0, newValue)
        guard abs(measuredBottomBarHeight - sanitizedValue) > 0.5 else { return }
        measuredBottomBarHeight = sanitizedValue
        refreshLayoutMetrics()
        updateBottomBarHeightConstraint()
        updateBottomBarBottomConstraint()
    }

    private func resolvedBottomBarDownshift() -> CGFloat {
        guard currentLayoutClass == .phone else { return 0 }
        let restingDownshift = max(0, view.safeAreaInsets.bottom - 10)
        guard isBottomBarConcealedForChatInput else { return restingDownshift }

        let tokens = TaskerThemeManager.shared.tokens(for: currentLayoutClass)
        return restingDownshift + resolvedBottomBarHostHeight() + tokens.spacing.s16
    }

    private func updateBottomBarBottomConstraint() {
        guard let bottomBarBottomConstraint else { return }
        let downshift = resolvedBottomBarDownshift()
        guard abs(bottomBarBottomConstraint.constant - downshift) > 0.5 else { return }
        bottomBarBottomConstraint.constant = downshift
        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut]
        ) {
            self.view.layoutIfNeeded()
        }
    }

    /// Executes mountHomeShell.
    private func mountHomeShell() {
        let interval = TaskerPerformanceTrace.begin("HomeShellMount")
        defer { TaskerPerformanceTrace.end(interval) }

        guard self.viewModel != nil else { return }
        guard hasMountedStableLayoutShell || hasStableLayoutMetrics else { return }

        currentLayoutClass = TaskerLayoutResolver.classify(view: view)
        if hasStableLayoutMetrics {
            hasMountedStableLayoutShell = true
            trackLayoutClassAtLaunchIfNeeded()
        }
        let existingHostingController = homeHostingController
        if existingHostingController != nil {
            iPadShellEpoch += 1
        }
        let root: HomeHostRootView

        if currentLayoutClass.isPad && V2FeatureFlags.iPadNativeShellEnabled {
            root = HomeHostRootView(
                layoutClass: currentLayoutClass,
                phoneRoot: nil,
                iPadRoot: makeIPadSplitRoot(layoutClass: currentLayoutClass)
            )
            trackIPadShellRenderedIfNeeded()
        } else {
            let homeRoot = makeHomeBackdropRoot(layoutClass: currentLayoutClass, forcedFace: nil)
            root = HomeHostRootView(
                layoutClass: currentLayoutClass,
                phoneRoot: homeRoot,
                iPadRoot: nil
            )
        }

        if let existingHostingController {
            if currentLayoutClass.isPad && V2FeatureFlags.iPadNativeShellEnabled {
                logWarning(
                    event: "ipadPrimarySurfaceShellEpochReset",
                    message: "Reset the iPad primary surface shell epoch after rebuilding the hosted root",
                    fields: [
                        "layout_class": currentLayoutClass.rawValue,
                        "shell_epoch": String(iPadShellEpoch)
                    ]
                )
            }
            configureSafeAreaRegions(for: existingHostingController)
            existingHostingController.rootView = root
            refreshLayoutMetrics()
            updateInteractivePhaseIfNeeded()
            mountBottomBarOverlayIfNeeded()
            return
        }

        let hostingController = UIHostingController(rootView: root)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        configureSafeAreaRegions(for: hostingController)

        homeHostingController = hostingController
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
        refreshLayoutMetrics()
        updateInteractivePhaseIfNeeded()
        mountBottomBarOverlayIfNeeded()
    }

    /// Executes makeHomeBackdropRoot.
    private func makeHomeBackdropRoot(
        layoutClass: TaskerLayoutClass,
        forcedFace: Binding<HomeForedropFace>?
    ) -> HomeBackdropForedropRootView {
        HomeBackdropForedropRootView(
            viewModel: viewModel,
            chromeStore: chromeStore,
            tasksStore: tasksStore,
            habitsStore: habitsStore,
            calendarStore: calendarStore,
            calendarIntegrationService: presentationDependencyContainer?.coordinator.calendarIntegrationService,
            chatAppManager: homeChatAppManager,
            overlayStore: overlayStore,
            faceCoordinator: faceCoordinator,
            searchState: searchState,
            chartCardViewModel: chartCardViewModel,
            radarChartCardViewModel: radarChartCardViewModel,
            layoutClass: layoutClass,
            forcedFace: forcedFace,
            onTaskTap: { [weak self] task in
                self?.handleTaskTap(task)
            },
            onToggleComplete: { [weak self] task in
                self?.viewModel?.toggleTaskCompletion(task)
            },
            onTimelineAnchorTap: { [weak self] anchor in
                self?.presentTimelineAnchorDetail(for: anchor)
            },
            onDeleteTask: { [weak self] task in
                self?.handleTaskDeleteRequested(task)
            },
            onRescheduleTask: { [weak self] task in
                self?.handleTaskReschedule(task)
            },
            onReorderCustomProjects: { [weak self] projectIDs in
                self?.viewModel?.setCustomProjectOrder(projectIDs)
            },
            onAddTask: { [weak self] suggestedDate in
                self?.presentAddTaskFlow(suggestedDate: suggestedDate)
            },
            onOpenChat: { [weak self] in
                self?.openChat(source: "home_chat_button")
            },
            onOpenProjectCreator: { [weak self] in
                self?.openProjectCreator()
            },
            onOpenSettings: { [weak self] in
                if self?.isUsingIPadNativeShell == true {
                    self?.iPadShellState.destination = .settings
                } else {
                    self?.onMenuButtonTapped()
                }
            },
            onOpenWeeklyPlanner: { [weak self] in
                self?.presentWeeklyPlanner()
            },
            onOpenWeeklyReview: { [weak self] in
                self?.presentWeeklyReview()
            },
            onRetryWeeklySummary: { [weak self] in
                self?.viewModel?.refreshWeeklySummaryNow()
            },
            onOpenAnalytics: { [weak self] source, launchDefaultInsights in
                self?.openAnalytics(source: source, launchDefaultInsights: launchDefaultInsights)
            },
            onCloseAnalytics: { [weak self] source in
                self?.closeAnalytics(source: source)
            },
            onOpenSearch: { [weak self] source in
                self?.openSearch(source: source)
            },
            onCloseSearch: { [weak self] source in
                self?.closeSearch(source: source)
            },
            onReturnToTasks: { [weak self] source in
                self?.returnToTasks(source: source)
            },
            onTaskListScrollChromeStateChange: { [weak self] state in
                self?.handleTaskListChromeStateChange(state)
            },
            onStartFocus: { [weak self] task in
                self?.startFocusFlow(task: task, source: "focus_strip")
            },
            onRequestCalendarPermission: { [weak self] in
                self?.viewModel?.requestCalendarPermission(openSystemSettings: {
                    guard let url = URL(string: UIApplication.openSettingsURLString),
                          UIApplication.shared.canOpenURL(url) else { return }
                    UIApplication.shared.open(url)
                })
            },
            onOpenCalendarChooser: { [weak self] in
                self?.presentCalendarChooser()
            },
            onOpenCalendarSchedule: { [weak self] in
                guard let self else { return }
                self.openSchedule(source: "home_calendar")
            },
            onRetryCalendarContext: { [weak self] in
                self?.viewModel?.refreshCalendarContext(reason: "home_calendar_retry")
            },
            onPerformChatDayTaskAction: { [weak self] action, card, completion in
                self?.performEmbeddedChatDayTaskAction(action, card: card, completion: completion)
            },
            onPerformChatDayHabitAction: { [weak self] action, card, completion in
                self?.performEmbeddedChatDayHabitAction(action, card: card, completion: completion)
            },
            onChatPromptFocusChange: { [weak self] isFocused in
                self?.setEmbeddedChatPromptFocused(isFocused)
            }
        )
    }

    /// Executes makeIPadSplitRoot.
    private func makeIPadSplitRoot(layoutClass: TaskerLayoutClass) -> AnyView {
        let root = HomeiPadSplitShellView(
            layoutClass: layoutClass,
            shellState: iPadShellState,
            shellEpoch: iPadShellEpoch,
            homeSurface: { [weak self] forcedFace in
                guard let self else { return AnyView(EmptyView()) }
                return AnyView(
                    self.makeHomeBackdropRoot(layoutClass: layoutClass, forcedFace: forcedFace)
                        .taskerLayoutClass(layoutClass)
                )
            },
            addTaskSurface: { [weak self] in
                self?.makeAddTaskInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            scheduleSurface: { [weak self] in
                self?.makeCalendarScheduleInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            settingsSurface: { [weak self] in
                self?.makeSettingsInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            lifeManagementSurface: { [weak self] in
                self?.makeLifeManagementInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            projectsSurface: { [weak self] in
                self?.makeProjectManagementInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            chatSurface: { [weak self] in
                self?.makeChatInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            modelsSurface: { [weak self] in
                self?.makeModelsInspectorRoot(layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            inspectorSurface: { [weak self] task in
                self?.makeTaskInspectorRoot(task, layoutClass: layoutClass) ?? AnyView(EmptyView())
            },
            onOpenTaskDetailSheet: { [weak self] task in
                self?.presentTaskDetailView(for: task)
            }
        )
        return AnyView(root.taskerLayoutClass(layoutClass))
    }

    private func makeAddTaskInspectorRoot(layoutClass: TaskerLayoutClass) -> AnyView {
        guard let presentationDependencyContainer else {
            return AnyView(Text("Add Task unavailable").font(.tasker(.body)))
        }
        return AnyView(
            AddTaskInspectorContainer(
                viewModel: presentationDependencyContainer.makeNewAddTaskViewModel(),
                habitViewModel: presentationDependencyContainer.makeNewAddHabitViewModel(),
                onClose: { [weak self] in
                    self?.iPadShellState.destination = .tasks
                }
            )
            .taskerLayoutClass(layoutClass)
        )
    }

    private func makeCalendarScheduleInspectorRoot(layoutClass: TaskerLayoutClass) -> AnyView {
        guard let service = presentationDependencyContainer?.coordinator.calendarIntegrationService else {
            return AnyView(Text("Schedule unavailable").font(.tasker(.body)))
        }
        return AnyView(
            CalendarScheduleView(
                service: service,
                weekStartsOn: service.weekStartsOn,
                presentationMode: .embedded,
                selectedDate: calendarScheduleSelectedDateBinding()
            )
            .taskerLayoutClass(layoutClass)
        )
    }

    private func makeSettingsInspectorRoot(layoutClass: TaskerLayoutClass) -> AnyView {
        guard let calendarService = presentationDependencyContainer?.coordinator.calendarIntegrationService else {
            return AnyView(Text("Settings unavailable").font(.tasker(.body)))
        }
        return AnyView(
            HomeiPadSettingsContainer(
                onNavigateToLifeManagement: { [weak self] in
                    self?.iPadShellState.destination = .lifeManagement
                },
                onNavigateToChats: { [weak self] in
                    self?.iPadShellState.destination = .chat
                },
                onNavigateToModels: { [weak self] in
                    self?.iPadShellState.destination = .models
                },
                onRestartOnboarding: {
                    NotificationCenter.default.post(name: .taskerStartOnboardingRequested, object: nil)
                },
                calendarIntegrationService: calendarService,
                onOpenCalendarChooser: { [weak self] in
                    self?.presentCalendarChooser()
                }
            )
            .taskerLayoutClass(layoutClass)
        )
    }

    private func makeLifeManagementInspectorRoot(layoutClass: TaskerLayoutClass) -> AnyView {
        guard let presentationDependencyContainer else {
            return AnyView(Text("Life Management unavailable").font(.tasker(.body)))
        }
        let vm = presentationDependencyContainer.makeLifeManagementViewModel()
        return AnyView(
            LifeManagementView(viewModel: vm)
                .taskerLayoutClass(layoutClass)
        )
    }

    private func makeProjectManagementInspectorRoot(layoutClass: TaskerLayoutClass) -> AnyView {
        guard let presentationDependencyContainer else {
            return AnyView(Text("Projects unavailable").font(.tasker(.body)))
        }
        let vm = presentationDependencyContainer.makeProjectManagementViewModel()
        return AnyView(
            ProjectManagementView(viewModel: vm)
                .taskerLayoutClass(layoutClass)
        )
    }

    private func makeChatInspectorRoot(layoutClass: TaskerLayoutClass) -> AnyView {
        guard let container = LLMDataController.shared else {
            return AnyView(
                LLMStoreUnavailableView()
                    .taskerLayoutClass(layoutClass)
            )
        }

        return AnyView(
            ChatContainerView(
                onOpenTaskDetail: { [weak self] task in
                    self?.handleTaskTap(task)
                },
                onPerformDayTaskAction: { [weak self] action, card, completion in
                    self?.performEmbeddedChatDayTaskAction(action, card: card, completion: completion)
                },
                onPerformDayHabitAction: { [weak self] action, card, completion in
                    self?.performEmbeddedChatDayHabitAction(action, card: card, completion: completion)
                }
            )
            .environmentObject(homeChatAppManager)
            .environment(LLMRuntimeCoordinator.shared.evaluator)
            .modelContainer(container)
            .taskerLayoutClass(layoutClass)
        )
    }

    private func makeModelsInspectorRoot(layoutClass: TaskerLayoutClass) -> AnyView {
        AnyView(
            NavigationStack {
                ModelsSettingsView()
                    .environmentObject(homeChatAppManager)
                    .environment(LLMRuntimeCoordinator.shared.evaluator)
            }
            .taskerLayoutClass(layoutClass)
        )
    }

    private func makeTaskInspectorRoot(_ task: TaskDefinition, layoutClass: TaskerLayoutClass) -> AnyView {
        AnyView(
            makeTaskDetailView(for: task, containerMode: .inspector)
                .taskerLayoutClass(layoutClass)
        )
    }

    private func trackLayoutClassAtLaunchIfNeeded() {
        guard didTrackLayoutClassAtLaunch == false else { return }
        didTrackLayoutClassAtLaunch = true
        viewModel?.trackHomeInteraction(
            action: "layout_class_at_launch_stable",
            metadata: [
                "layout_class": currentLayoutClass.rawValue,
                "is_ipad_native_shell_enabled": isUsingIPadNativeShell
            ]
        )
    }

    private func trackIPadShellRenderedIfNeeded() {
        guard didTrackIPadShellRendered == false else { return }
        guard currentLayoutClass.isPad else { return }
        didTrackIPadShellRendered = true
        viewModel?.trackHomeInteraction(
            action: "ipad_shell_rendered",
            metadata: [
                "layout_class": currentLayoutClass.rawValue
            ]
        )
    }

    private func observeIPadShellTelemetry() {
        iPadShellState.$destination
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] destination in
                guard let self else { return }
                guard self.currentLayoutClass.isPad else { return }
                self.viewModel?.trackHomeInteraction(
                    action: "ipad_destination_switch",
                    metadata: [
                        "layout_class": self.currentLayoutClass.rawValue,
                        "destination": destination.rawValue
                    ]
                )
            }
            .store(in: &cancellables)

        iPadShellState.$selectedTask
            .receive(on: RunLoop.main)
            .sink { [weak self] selectedTask in
                guard let self else { return }
                guard self.currentLayoutClass == .padExpanded else { return }
                guard selectedTask != nil else { return }
                self.viewModel?.trackHomeInteraction(
                    action: "ipad_inspector_open",
                    metadata: [
                        "layout_class": self.currentLayoutClass.rawValue
                    ]
                )
            }
            .store(in: &cancellables)

        iPadShellState.$modalRequest
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] request in
                guard let self else { return }
                guard self.currentLayoutClass.isPad else { return }
                self.iPadShellState.modalRequest = nil
                self.pendingIPadModalRequest = request
                self.processPendingIPadModalRequest()
            }
            .store(in: &cancellables)
    }

    private func processPendingIPadModalRequest() {
        guard isUsingIPadNativeShell else {
            pendingIPadModalRequest = nil
            resetPendingIPadModalWaitState()
            return
        }
        guard let request = pendingIPadModalRequest else {
            resetPendingIPadModalWaitState()
            return
        }
        if let blockingController = presentedViewController {
            if let presentationController = blockingController.presentationController {
                presentationController.delegate = self
            } else {
                viewModel?.trackHomeInteraction(
                    action: "ipad_modal_request_waiting_for_presented_controller",
                    metadata: ["layout_class": currentLayoutClass.rawValue]
                )
            }
            return
        }

        resetPendingIPadModalWaitState()
        pendingIPadModalRequest = nil
        switch request {
        case .addTask:
            viewModel?.trackHomeInteraction(
                action: "ipad_modal_request_presented",
                metadata: ["layout_class": currentLayoutClass.rawValue]
            )
            presentAddTaskSheetForPadFallback()
        }
    }

    private func resetPendingIPadModalWaitState() {
        if let presentationController = presentedViewController?.presentationController,
           presentationController.delegate === self {
            presentationController.delegate = nil
        }
    }

    /// Executes observeMutations.
    private func observeMutations() {
        notificationCenter.addObserver(
            self,
            selector: #selector(homeTaskMutationReceived(_:)),
            name: .homeTaskMutation,
            object: nil
        )
    }

    /// Executes observeNotificationRoutes.
    private func observeNotificationRoutes() {
        NotificationCenter.default.publisher(for: TaskerNotificationRouteBus.routeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let payload = notification.userInfo?["payload"] as? String else { return }
                let route = TaskerNotificationRoute.from(payload: payload, fallbackTaskID: nil)
                self?.handleNotificationRoute(route)
                _ = TaskerNotificationRouteBus.shared.consumePendingRoute()
            }
            .store(in: &cancellables)
    }

    private func observeFocusDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenFocusDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleFocusDeepLink()
            }
            .store(in: &cancellables)
    }

    private func observeChatDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenChatDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let prompt = (notification.userInfo?["prompt"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self?.handleChatDeepLink(prompt: prompt)
            }
            .store(in: &cancellables)
    }

    private func observeHomeDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenHomeDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let notice = notification.userInfo?["notice"] as? String
                self?.handleHomeDeepLink(notice: notice)
            }
            .store(in: &cancellables)
    }

    private func observeInsightsDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenInsightsDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleInsightsDeepLink()
            }
            .store(in: &cancellables)
    }

    private func observeTaskScopeDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenTaskScopeDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let scope = (notification.userInfo?["scope"] as? String)?.lowercased() ?? "today"
                let projectID = (notification.userInfo?["projectID"] as? String).flatMap(UUID.init(uuidString:))
                self?.handleTaskScopeDeepLink(scope: scope, projectID: projectID)
            }
            .store(in: &cancellables)
    }

    private func observeTaskDetailDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenTaskDetailDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let taskIDRaw = notification.userInfo?["taskID"] as? String,
                      let taskID = UUID(uuidString: taskIDRaw) else {
                    return
                }
                self?.handleTaskDetailDeepLink(taskID: taskID)
            }
            .store(in: &cancellables)
    }

    private func observeHabitBoardDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenHabitBoardDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleHabitBoardDeepLink()
            }
            .store(in: &cancellables)
    }

    private func observeHabitLibraryDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenHabitLibraryDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleHabitLibraryDeepLink()
            }
            .store(in: &cancellables)
    }

    private func observeHabitDetailDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenHabitDetailDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let taskIDRaw = notification.userInfo?["habitID"] as? String,
                      let habitID = UUID(uuidString: taskIDRaw) else {
                    return
                }
                self?.handleHabitDetailDeepLink(habitID: habitID)
            }
            .store(in: &cancellables)
    }

    private func observeQuickAddDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenQuickAddDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleQuickAddDeepLink()
            }
            .store(in: &cancellables)
    }

    private func observeCalendarScheduleDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenCalendarScheduleDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleCalendarScheduleDeepLink()
            }
            .store(in: &cancellables)
    }

    private func observeCalendarChooserDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenCalendarChooserDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleCalendarChooserDeepLink()
            }
            .store(in: &cancellables)
    }

    private func observeWeeklyPlannerDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenWeeklyPlannerDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleWeeklyPlannerDeepLink()
            }
            .store(in: &cancellables)
    }

    private func observeWeeklyReviewDeepLinks() {
        NotificationCenter.default.publisher(for: .taskerOpenWeeklyReviewDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleWeeklyReviewDeepLink()
            }
            .store(in: &cancellables)
    }

    private func observeWidgetActionCommands() {
        NotificationCenter.default.publisher(for: .taskerProcessWidgetActionCommand)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.processPendingWidgetActionCommand()
            }
            .store(in: &cancellables)
    }

    private func observePersistentSyncMode() {
        NotificationCenter.default.publisher(for: .taskerPersistentSyncModeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshPersistentSyncOutageBanner()
            }
            .store(in: &cancellables)
    }

    private func refreshPersistentSyncOutageBanner() {
        if AppDelegate.isWriteClosed {
            showPersistentSyncOutageBanner(
                message: "Sync unavailable, read-only mode. Recover from iCloud to resume edits."
            )
        } else {
            hidePersistentSyncOutageBanner()
        }
    }

    private func showPersistentSyncOutageBanner(message: String) {
        if syncOutageBanner == nil {
            let banner = UIView()
            banner.translatesAutoresizingMaskIntoConstraints = false
            banner.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.18)
            banner.layer.cornerRadius = 10
            banner.layer.masksToBounds = true

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .label
            label.numberOfLines = 2
            label.textAlignment = .center

            banner.addSubview(label)
            view.addSubview(banner)

            let topConstraint = banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
            let leadingConstraint = banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12)
            let trailingConstraint = banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
            let heightConstraint = banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)

            NSLayoutConstraint.activate([
                topConstraint,
                leadingConstraint,
                trailingConstraint,
                heightConstraint,
                label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
                label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -8)
            ])

            syncOutageBanner = banner
            syncOutageLabel = label
        }

        syncOutageLabel?.text = message
        syncOutageBanner?.isHidden = false
        syncOutageBanner?.alpha = 1
    }

    private func hidePersistentSyncOutageBanner() {
        syncOutageBanner?.isHidden = true
        syncOutageBanner?.alpha = 0
    }

    private func consumeUITestInjectedRouteIfNeeded() {
        guard Self.hasConsumedUITestRoute == false else { return }
        let prefix = "-TASKER_TEST_ROUTE:"
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else { return }
        let payload = String(argument.dropFirst(prefix.count))
        guard payload.isEmpty == false else { return }
        Self.hasConsumedUITestRoute = true
        let route = TaskerNotificationRoute.from(payload: payload, fallbackTaskID: nil)
        handleNotificationRoute(route)
    }

    private func consumeUITestOpenSettingsIfNeeded() {
        guard Self.hasConsumedUITestOpenSettings == false else { return }
        guard ProcessInfo.processInfo.arguments.contains("-TASKER_TEST_OPEN_SETTINGS") else { return }
        guard presentedViewController == nil else { return }

        Self.hasConsumedUITestOpenSettings = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            self.onMenuButtonTapped()
        }
    }

    private func seedUITestEstablishedWorkspaceIfNeeded(completion: @escaping () -> Void) {
        guard ProcessInfo.processInfo.arguments.contains("-TASKER_TEST_SEED_ESTABLISHED_WORKSPACE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestEstablishedWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestEstablishedWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createTaskDefinition = presentationDependencyContainer.coordinator.createTaskDefinition

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Career",
                    color: "#293A18",
                    icon: "briefcase.fill"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Ship one thing",
                        description: "UI test workspace seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let requests = [
                    CreateTaskDefinitionRequest(
                        title: "Draft update",
                        details: "UI test established-workspace seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: DatePreset.today.resolvedDueDate(),
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        title: "Send recap",
                        details: "UI test established-workspace seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: DatePreset.today.resolvedDueDate(),
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        title: "Plan next step",
                        details: "UI test established-workspace seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: DatePreset.today.resolvedDueDate(),
                        createdAt: Date()
                    )
                ]

                for request in requests {
                    _ = try await createTaskDefinition.executeAsync(request: request)
                }
            } catch {
                logError(
                    event: "ui_test_onboarding_workspace_seed_failed",
                    message: "Failed to seed established workspace for onboarding UI test",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    private func seedUITestRescueWorkspaceIfNeeded(completion: @escaping () -> Void) {
        let arguments = ProcessInfo.processInfo.arguments
        let shouldSeedExpandedRescue = arguments.contains("-TASKER_TEST_SEED_RESCUE_WORKSPACE")
        let shouldSeedCompactRescue = arguments.contains("-TASKER_TEST_SEED_COMPACT_RESCUE_WORKSPACE")
        guard shouldSeedExpandedRescue || shouldSeedCompactRescue else {
            completion()
            return
        }
        guard Self.hasSeededUITestRescueWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestRescueWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createTaskDefinition = presentationDependencyContainer.coordinator.createTaskDefinition

                let calendar = Calendar.current
                let now = Date()
                let anchorDay = calendar.startOfDay(for: now)
                let includeHiddenRescueRow = shouldSeedExpandedRescue

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Operations",
                    color: "#624A2E",
                    icon: "shippingbox.fill"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Recovery Queue",
                        description: "UI test rescue seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                var requests = [
                    CreateTaskDefinitionRequest(
                        title: "Rescue oldest",
                        details: "UI test rescue seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .day, value: -20, to: anchorDay),
                        priority: .max,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        title: "Rescue middle",
                        details: "UI test rescue seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .day, value: -18, to: anchorDay),
                        priority: .high,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        title: "Rescue newest",
                        details: "UI test rescue seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .day, value: -16, to: anchorDay),
                        priority: .low,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        title: "Today focus seed",
                        details: "UI test rescue seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 10, to: anchorDay),
                        priority: .high,
                        createdAt: now
                    )
                ]

                if includeHiddenRescueRow {
                    requests.insert(
                        CreateTaskDefinitionRequest(
                            title: "Rescue hidden",
                            details: "UI test rescue seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .day, value: -15, to: anchorDay),
                            priority: .high,
                            createdAt: now
                        ),
                        at: 3
                    )
                }

                for request in requests {
                    _ = try await createTaskDefinition.executeAsync(request: request)
                }
                viewModel.invalidateTaskCaches()
            } catch {
                logError(
                    event: "ui_test_rescue_workspace_seed_failed",
                    message: "Failed to seed rescue workspace for Home UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    private func seedUITestFocusWorkspaceIfNeeded(completion: @escaping () -> Void) {
        guard ProcessInfo.processInfo.arguments.contains("-TASKER_TEST_SEED_FOCUS_WORKSPACE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestFocusWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestFocusWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createTaskDefinition = presentationDependencyContainer.coordinator.createTaskDefinition
                let createHabit = presentationDependencyContainer.coordinator.createHabit

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Focus Systems",
                    color: "#5A3121",
                    icon: "scope"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Today Focus",
                        description: "UI test focus seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let anchor = DatePreset.today.resolvedDueDate() ?? Date()
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: anchor)
                let focusRowID = UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID()
                let focusAID = UUID(uuidString: "10000000-0000-0000-0000-000000000002") ?? UUID()
                let focusBID = UUID(uuidString: "10000000-0000-0000-0000-000000000003") ?? UUID()
                let focusCID = UUID(uuidString: "10000000-0000-0000-0000-000000000004") ?? UUID()
                let focusDID = UUID(uuidString: "10000000-0000-0000-0000-000000000005") ?? UUID()
                let requests = [
                    CreateTaskDefinitionRequest(
                        id: focusRowID,
                        title: "Focus Row Opens Detail",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 8, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 900,
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        id: focusAID,
                        title: "Pinned Focus A",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 9, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 900,
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        id: focusBID,
                        title: "Pinned Focus B",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 10, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 1_200,
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        id: focusCID,
                        title: "Pinned Focus C",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 11, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 2_400,
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        id: focusDID,
                        title: "Pinned Focus D",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 12, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 2_400,
                        createdAt: Date()
                    )
                ]

                for request in requests {
                    _ = try await createTaskDefinition.executeAsync(request: request)
                }

                let habitRequests = [
                    CreateHabitRequest(
                        title: "Reset desk before shutdown",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "sparkles", categoryKey: "focus"),
                        colorHex: HabitColorFamily.blue.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    ),
                    CreateHabitRequest(
                        title: "No doomscrolling after dinner",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .negative,
                        trackingMode: .lapseOnly,
                        icon: HabitIconMetadata(symbolName: "moon.zzz.fill", categoryKey: "recovery"),
                        colorHex: HabitColorFamily.coral.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    )
                ]

                for request in habitRequests {
                    _ = try await createHabit.executeAsync(request: request)
                }

                UserDefaults.standard.set(
                    [focusRowID.uuidString],
                    forKey: "home.focus.pinnedTaskIDs.v2"
                )
                UserDefaults.standard.removeObject(forKey: "home.eva.recentShuffleTaskIDs.v1")
            } catch {
                logError(
                    event: "ui_test_focus_workspace_seed_failed",
                    message: "Failed to seed focus workspace for Home UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    private func seedUITestHabitBoardWorkspaceIfNeeded(completion: @escaping () -> Void) {
        guard ProcessInfo.processInfo.arguments.contains("-TASKER_TEST_SEED_HABIT_BOARD_WORKSPACE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestHabitBoardWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestHabitBoardWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createHabit = presentationDependencyContainer.coordinator.createHabit

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Health",
                    color: "#4E9A2F",
                    icon: "heart.fill"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Daily Rhythm",
                        description: "UI test habit board seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let requests = [
                    CreateHabitRequest(
                        title: "Drink water after breakfast",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "health"),
                        colorHex: HabitColorFamily.green.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    ),
                    CreateHabitRequest(
                        title: "Choose tomorrow's top priority before bed",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "moon.stars.fill", categoryKey: "planning"),
                        colorHex: HabitColorFamily.blue.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    ),
                    CreateHabitRequest(
                        title: "No phone in bed",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .negative,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "bed.double.fill", categoryKey: "sleep"),
                        colorHex: HabitColorFamily.coral.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    )
                ]

                for request in requests {
                    _ = try await createHabit.executeAsync(request: request)
                }
            } catch {
                logError(
                    event: "ui_test_habit_board_seed_failed",
                    message: "Failed to seed habits for Habit Board UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    private func seedUITestQuietTrackingWorkspaceIfNeeded(completion: @escaping () -> Void) {
        guard ProcessInfo.processInfo.arguments.contains("-TASKER_TEST_SEED_QUIET_TRACKING_WORKSPACE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestQuietTrackingWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestQuietTrackingWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createHabit = presentationDependencyContainer.coordinator.createHabit

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Recovery",
                    color: "#D26A5C",
                    icon: "bandage.fill"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Quiet Tracking Seed",
                        description: "UI test quiet tracking seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let requests = [
                    CreateHabitRequest(
                        title: "No phone in bed",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .negative,
                        trackingMode: .lapseOnly,
                        icon: HabitIconMetadata(symbolName: "bed.double.fill", categoryKey: "sleep"),
                        colorHex: HabitColorFamily.coral.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    ),
                    CreateHabitRequest(
                        title: "No doomscrolling after dinner",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .negative,
                        trackingMode: .lapseOnly,
                        icon: HabitIconMetadata(symbolName: "moon.zzz.fill", categoryKey: "recovery"),
                        colorHex: HabitColorFamily.blue.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    )
                ]

                for request in requests {
                    _ = try await createHabit.executeAsync(request: request)
                }
            } catch {
                logError(
                    event: "ui_test_quiet_tracking_workspace_seed_failed",
                    message: "Failed to seed quiet tracking workspace for Home UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    var currentOnboardingLayoutClass: TaskerLayoutClass {
        currentLayoutClass
    }

    func prepareForOnboardingHomeGuidance() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
    }

    func makeOnboardingAddTaskController(
        prefill: AddTaskPrefillTemplate,
        onTaskCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)? = nil
    ) -> UIViewController? {
        guard let presentationDependencyContainer else {
            return nil
        }
        let viewModel = presentationDependencyContainer.makeNewAddTaskViewModel()
        viewModel.applyPrefill(prefill)
        let sheet = AddTaskSheetView(
            viewModel: viewModel,
            habitViewModel: presentationDependencyContainer.makeNewAddHabitViewModel(),
            onTaskCreated: onTaskCreated,
            onDismissWithoutTask: onDismissWithoutTask
        )
        let hostingController = UIHostingController(rootView: AnyView(sheet.taskerLayoutClass(currentLayoutClass)))
        hostingController.modalPresentationStyle = .pageSheet
        if let sheetController = hostingController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        return hostingController
    }

    func makeOnboardingAddHabitController(
        prefill: AddHabitPrefillTemplate,
        onHabitCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)? = nil
    ) -> UIViewController? {
        guard let presentationDependencyContainer else {
            return nil
        }
        let taskViewModel = presentationDependencyContainer.makeNewAddTaskViewModel()
        let habitViewModel = presentationDependencyContainer.makeNewAddHabitViewModel()
        habitViewModel.applyPrefill(prefill)
        let sheet = AddTaskSheetView(
            itemViewModel: AddItemViewModel(
                taskViewModel: taskViewModel,
                habitViewModel: habitViewModel,
                allowedModes: [.habit],
                selectedMode: .habit
            ),
            modePolicy: .habitOnly,
            onHabitCreated: onHabitCreated,
            onDismissWithoutTask: onDismissWithoutTask
        )
        let hostingController = UIHostingController(rootView: AnyView(sheet.taskerLayoutClass(currentLayoutClass)))
        hostingController.modalPresentationStyle = .pageSheet
        if let sheetController = hostingController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        return hostingController
    }

    func makeOnboardingTaskDetailController(
        task: TaskDefinition,
        onDismiss: @escaping () -> Void
    ) -> UIViewController? {
        let detailView = makeTaskDetailView(for: task, containerMode: .sheet)
        let hostingController = UIHostingController(rootView: AnyView(detailView.taskerLayoutClass(currentLayoutClass)))
        hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas

        if isUsingIPadNativeShell {
            switch currentLayoutClass {
            case .padCompact, .padRegular, .padExpanded:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }
            case .phone:
                hostingController.modalPresentationStyle = .pageSheet
            }
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }

        let dismissBridge = OnboardingTaskDetailDismissBridge(onDismiss: onDismiss)
        hostingController.presentationController?.delegate = dismissBridge
        objc_setAssociatedObject(
            hostingController,
            &onboardingTaskDetailDismissBridgeKey,
            dismissBridge,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return hostingController
    }

    // MARK: - Navigation Actions

    /// Executes onMenuButtonTapped.
    @objc func onMenuButtonTapped() {
        let settingsVC = SettingsPageViewController()
        settingsVC.presentationDependencyContainer = presentationDependencyContainer
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.navigationBar.prefersLargeTitles = false
        navController.modalPresentationStyle = .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navController, animated: true)
    }

    /// Executes AddTaskAction.
    @objc func AddTaskAction() {
        presentAddTaskFlow(suggestedDate: nil)
    }

    private func presentAddTaskFlow(suggestedDate: Date?) {
        if isUsingIPadNativeShell,
           currentLayoutClass == .padExpanded,
           suggestedDate == nil {
            iPadShellState.destination = .addTask
            return
        }

        if isUsingIPadNativeShell {
            presentAddTaskSheetForPadFallback(suggestedDate: suggestedDate)
            return
        }

        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        let vm = presentationDependencyContainer.makeNewAddTaskViewModel()
        applyTimelineSuggestedDate(suggestedDate, to: vm)
        let sheet = AddTaskSheetView(
            viewModel: vm,
            habitViewModel: presentationDependencyContainer.makeNewAddHabitViewModel(),
            modePolicy: .unified(defaultMode: .task)
        )
        let hostingVC = UIHostingController(rootView: sheet)
        hostingVC.modalPresentationStyle = .pageSheet
        if let sheetController = hostingVC.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        let interval = TaskerPerformanceTrace.begin("AddTaskSheetOpen")
        present(hostingVC, animated: true) {
            TaskerPerformanceTrace.end(interval)
        }
    }

    private func presentAddTaskSheetForPadFallback(suggestedDate: Date? = nil) {
        guard isUsingIPadNativeShell else {
            presentAddTaskFlow(suggestedDate: suggestedDate)
            return
        }
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        let vm = presentationDependencyContainer.makeNewAddTaskViewModel()
        applyTimelineSuggestedDate(suggestedDate, to: vm)
        let sheet = AddTaskSheetView(
            viewModel: vm,
            habitViewModel: presentationDependencyContainer.makeNewAddHabitViewModel(),
            modePolicy: .unified(defaultMode: .task)
        )
        let hostingVC = UIHostingController(rootView: sheet.taskerLayoutClass(currentLayoutClass))
        hostingVC.modalPresentationStyle = .formSheet
        hostingVC.preferredContentSize = CGSize(width: 540, height: 620)
        if let sheetController = hostingVC.sheetPresentationController {
            sheetController.detents = [.large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        viewModel?.trackHomeInteraction(
            action: "ipad_fallback_sheet_presented",
            metadata: [
                "layout_class": currentLayoutClass.rawValue,
                "surface": "add_task"
            ]
        )
        let interval = TaskerPerformanceTrace.begin("AddTaskSheetOpen")
        present(hostingVC, animated: true) {
            TaskerPerformanceTrace.end(interval)
        }
    }

    private func applyTimelineSuggestedDate(_ suggestedDate: Date?, to viewModel: AddTaskViewModel) {
        guard let suggestedDate else { return }
        viewModel.applyPrefill(
            AddTaskPrefillTemplate(
                title: "",
                dueDateIntent: .exact(suggestedDate),
                expandedSections: [.schedule],
                showMoreDetails: true
            )
        )
    }

    @objc private func openProjectCreator() {
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        if isUsingIPadNativeShell {
            iPadShellState.destination = .projects
            return
        }

        let viewModel = presentationDependencyContainer.makeProjectManagementViewModel()
        let rootView = ProjectManagementView(viewModel: viewModel)
            .taskerLayoutClass(currentLayoutClass)
        let controller = UIHostingController(rootView: rootView)
        controller.title = "Projects"

        let navController = UINavigationController(rootViewController: controller)
        navController.navigationBar.prefersLargeTitles = false
        navController.modalPresentationStyle = currentLayoutClass.isPad ? .formSheet : .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = currentLayoutClass.isPad ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(navController, animated: true)
    }

    @MainActor
    private func presentWeeklyPlanner() {
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }

        let weeklySummary = viewModel?.weeklySummary
        let referenceDate = weeklySummary?.weekStartDate ?? Date()
        let plannerPresentation = weeklySummary?.plannerPresentation ?? .thisWeek

        let plannerView = WeeklyPlannerView(
            viewModel: presentationDependencyContainer.makeWeeklyPlannerViewModel(
                referenceDate: referenceDate,
                plannerPresentation: plannerPresentation
            ),
            onClose: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        .taskerLayoutClass(currentLayoutClass)

        let hostingController = UIHostingController(rootView: plannerView)
        hostingController.modalPresentationStyle = currentLayoutClass.isPad ? .formSheet : .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = currentLayoutClass.isPad ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(hostingController, animated: true)
    }

    @MainActor
    private func presentWeeklyReview() {
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }

        let referenceDate = viewModel?.weeklySummary?.weekStartDate ?? Date()

        let reviewView = WeeklyReviewView(
            viewModel: presentationDependencyContainer.makeWeeklyReviewViewModel(referenceDate: referenceDate),
            onClose: { [weak self] in
                self?.dismiss(animated: true)
            },
            onCompleted: { [weak self] message in
                self?.dismiss(animated: true) {
                    self?.viewModel?.refreshAfterWeeklyReviewCompletion()
                    self?.showHomeSnackbar(message: message)
                }
            }
        )
        .taskerLayoutClass(currentLayoutClass)

        let hostingController = UIHostingController(rootView: reviewView)
        hostingController.modalPresentationStyle = currentLayoutClass.isPad ? .formSheet : .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = currentLayoutClass.isPad ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(hostingController, animated: true)
    }

    /// Executes searchButtonTapped.
    @objc func searchButtonTapped() {
        if isUsingIPadNativeShell {
            let presentSearch = { [weak self] in
                guard let self else { return }
                self.openSearch(source: "navigation_search_button")
                self.iPadShellState.destination = .search
            }

            if presentedViewController != nil {
                dismiss(animated: true) {
                    presentSearch()
                }
            } else {
                presentSearch()
            }
            return
        }

        let searchVC = LGSearchViewController()
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        presentationDependencyContainer.inject(into: searchVC)
        searchVC.modalPresentationStyle = .fullScreen
        searchVC.modalTransitionStyle = .crossDissolve
        present(searchVC, animated: true)
    }

    /// Executes chatButtonTapped.
    @objc func chatButtonTapped() {
        presentEvaChatScreen(source: "legacy_chat_button")
    }

    private func resetHomeSelectionAfterEvaChatDismissalIfNeeded() {
        guard shouldResetHomeAfterEvaChatDismissal else { return }
        guard presentedViewController == nil else { return }
        resetHomeSelectionAfterEvaChatDismissal()
    }

    private func resetHomeSelectionAfterEvaChatDismissal() {
        shouldResetHomeAfterEvaChatDismissal = false
        presentedEvaChatController = nil
        faceCoordinator.setActiveFace(.tasks)
        faceCoordinator.bottomBarState.select(.home)
    }

    private func performEmbeddedChatDayTaskAction(
        _ action: EvaDayTaskAction,
        card: EvaDayTaskCard,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let viewModel else {
            completion(.failure(embeddedChatError(code: 1, message: "Home view model unavailable")))
            return
        }

        switch action {
        case .done:
            viewModel.setTaskCompletion(taskID: card.taskID, to: true) { result in
                completion(result.map { _ in })
            }
        case .reopen:
            viewModel.setTaskCompletion(taskID: card.taskID, to: false) { result in
                completion(result.map { _ in })
            }
        case .tomorrow:
            let calendar = Calendar.current
            let baseDay = calendar.startOfDay(for: Date())
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: baseDay) else {
                completion(.failure(embeddedChatError(code: 2, message: "Could not compute tomorrow")))
                return
            }
            viewModel.rescheduleTask(taskID: card.taskID, to: tomorrow) { result in
                completion(result.map { _ in })
            }
        case .open:
            handleTaskTap(card.taskSnapshot)
            completion(.success(()))
        }
    }

    private func performEmbeddedChatDayHabitAction(
        _ action: EvaDayHabitAction,
        card: EvaDayHabitCard,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if action == .open {
            handleHabitDetailDeepLink(habitID: card.habitID)
            completion(.success(()))
            return
        }

        guard let coordinator = presentationDependencyContainer?.coordinator else {
            completion(.failure(embeddedChatError(code: 3, message: "Coordinator unavailable")))
            return
        }

        let habitAction: HabitOccurrenceAction
        switch action {
        case .done:
            habitAction = .complete
        case .skip:
            habitAction = .skip
        case .stayedClean:
            habitAction = .abstained
        case .lapsed, .logLapse:
            habitAction = .lapsed
        case .open:
            handleHabitDetailDeepLink(habitID: card.habitID)
            completion(.success(()))
            return
        }

        coordinator.resolveHabitOccurrence.execute(
            habitID: card.habitID,
            action: habitAction,
            on: card.dueAt ?? Date()
        ) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.viewModel?.refreshCurrentScopeContent(source: "eva_chat_habit_action")
                }
                completion(result)
            }
        }
    }

    private func embeddedChatError(code: Int, message: String) -> NSError {
        NSError(
            domain: "HomeEmbeddedEvaChat",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    // MARK: - Task Routing

    /// Executes handleTaskTap.
    private func handleTaskTap(_ task: TaskDefinition) {
        if isUsingIPadNativeShell, currentLayoutClass == .padExpanded {
            iPadShellState.selectedTask = task
            return
        }
        presentTaskDetailView(for: task)
    }

    /// Executes handleTaskReschedule.
    private func handleTaskReschedule(_ task: TaskDefinition) {
        let rescheduleVC = RescheduleViewController(
            taskTitle: task.title,
            currentDueDate: task.dueDate
        ) { [weak self] (selectedDate: Date) in
            guard let self else { return }
            self.viewModel?.rescheduleTask(task, to: selectedDate)
        }

        let navController = UINavigationController(rootViewController: rescheduleVC)
        present(navController, animated: true)
    }

    /// Executes handleTaskDeleteRequested.
    private func handleTaskDeleteRequested(_ task: TaskDefinition) {
        guard let viewModel else { return }
        guard task.recurrenceSeriesID != nil else {
            viewModel.deleteTask(taskID: task.id) { _ in }
            return
        }

        let alert = UIAlertController(
            title: "Delete recurring task?",
            message: "Choose whether to delete only this task or every task in the series.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Delete This Task", style: .destructive) { _ in
            viewModel.deleteTask(taskID: task.id, scope: .single) { _ in }
        })
        alert.addAction(UIAlertAction(title: "Delete Entire Series", style: .destructive) { _ in
            viewModel.deleteTask(taskID: task.id, scope: .series) { _ in }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    private func presentTimelineAnchorDetail(for anchor: TimelineAnchorItem) {
        guard let selection = TimelineAnchorSelection(anchorID: anchor.id) else { return }
        viewModel?.trackHomeInteraction(
            action: "home_timeline_anchor_edit_opened",
            metadata: ["anchor": selection.rawValue, "layout_class": currentLayoutClass.rawValue]
        )

        let detailView = TimelineAnchorDetailSheetView(selection: selection)
        let hostingController = UIHostingController(rootView: detailView.taskerLayoutClass(currentLayoutClass))
        hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas

        if isUsingIPadNativeShell {
            hostingController.modalPresentationStyle = .formSheet
            hostingController.preferredContentSize = CGSize(width: 540, height: 520)
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }

        present(hostingController, animated: true)
    }

    /// Executes presentTaskDetailView.
    private func presentTaskDetailView(for task: TaskDefinition) {
        let detailView = makeTaskDetailView(for: task, containerMode: .sheet)

        let hostingController = UIHostingController(rootView: detailView.taskerLayoutClass(currentLayoutClass))
        hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        if isUsingIPadNativeShell {
            switch currentLayoutClass {
            case .padCompact:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                viewModel?.trackHomeInteraction(
                    action: "ipad_task_detail_fallback_formsheet",
                    metadata: ["layout_class": currentLayoutClass.rawValue]
                )
                viewModel?.trackHomeInteraction(
                    action: "ipad_fallback_sheet_presented",
                    metadata: ["layout_class": currentLayoutClass.rawValue, "surface": "task_detail_formsheet"]
                )
            case .padRegular:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }
                viewModel?.trackHomeInteraction(
                    action: "ipad_task_detail_fallback_formsheet",
                    metadata: ["layout_class": currentLayoutClass.rawValue]
                )
                viewModel?.trackHomeInteraction(
                    action: "ipad_fallback_sheet_presented",
                    metadata: ["layout_class": currentLayoutClass.rawValue, "surface": "task_detail_formsheet"]
                )
            case .padExpanded:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }
            case .phone:
                hostingController.modalPresentationStyle = .pageSheet
            }
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }

        let interval = TaskerPerformanceTrace.begin("TaskDetailOpen")
        present(hostingController, animated: true) {
            TaskerPerformanceTrace.end(interval)
        }
    }

    /// Executes makeTaskDetailView.
    private func makeTaskDetailView(
        for task: TaskDefinition,
        containerMode: TaskDetailContainerMode
    ) -> TaskDetailSheetView {
        TaskDetailSheetView(
            task: task,
            projects: viewModel?.projects ?? [],
            todayXPSoFar: {
                guard let viewModel else { return nil }
                if V2FeatureFlags.gamificationV2Enabled, viewModel.progressState.todayTargetXP <= 0 {
                    return nil
                }
                return viewModel.progressState.earnedXP
            }(),
            isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
            containerMode: containerMode,
            onUpdate: { [weak self] taskID, request, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.updateTask(taskID: taskID, request: request, completion: completion)
            },
            onSetCompletion: { [weak self] taskID, isComplete, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.setTaskCompletion(taskID: taskID, to: isComplete, completion: completion)
            },
            onDelete: { [weak self] taskID, scope, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.deleteTask(taskID: taskID, scope: scope, completion: completion)
            },
            onReschedule: { [weak self] taskID, date, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.rescheduleTask(taskID: taskID, to: date, completion: completion)
            },
            onLoadMetadata: { [weak self] projectID, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.loadTaskDetailMetadata(projectID: projectID, completion: completion)
            },
            onLoadRelationshipMetadata: { [weak self] projectID, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 9,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.loadTaskDetailRelationshipMetadata(projectID: projectID, completion: completion)
            },
            onLoadChildren: { [weak self] parentTaskID, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 6,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.loadTaskChildren(parentTaskID: parentTaskID, completion: completion)
            },
            onCreateTask: { [weak self] request, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 7,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.createTaskDefinition(request: request, completion: completion)
            },
            onCreateTag: { [weak self] name, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 8,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.createTagForTaskDetail(name: name, completion: completion)
            },
            onCreateProject: { [weak self] name, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 9,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.createProjectForTaskDetail(name: name, completion: completion)
            },
            onSaveReflectionNote: { [weak self] note, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.saveReflectionNote(note, completion: completion)
            },
            onLoadTaskFitHint: { [weak self] task, completion in
                Task { @MainActor [weak self] in
                    guard let self, let service = self.presentationDependencyContainer?.coordinator.calendarIntegrationService else {
                        completion(.unknown)
                        return
                    }
                    completion(service.taskFitHint(for: task))
                }
            }
        )
    }

    private func presentCalendarChooser() {
        guard let service = presentationDependencyContainer?.coordinator.calendarIntegrationService else { return }
        let chooser = EventKitCalendarChooserContainerView(
            service: service,
            initialSelectedCalendarIDs: service.snapshot.selectedCalendarIDs,
            onCommit: { selectedIDs in
                service.updateSelectedCalendarIDs(selectedIDs)
            }
        )
        let host = UIHostingController(rootView: AnyView(chooser.taskerLayoutClass(currentLayoutClass)))
        host.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        host.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        if let sheet = host.sheetPresentationController {
            let detents: [UISheetPresentationController.Detent] = [.medium(), .large()]
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
        }
        present(host, animated: true)
    }

    private func presentCalendarSchedule() {
        if isUsingIPadNativeShell {
            unwindActiveFaceForIPadDestination(source: "calendar_schedule_modal")
            iPadShellState.destination = .schedule
            return
        }
        guard let service = presentationDependencyContainer?.coordinator.calendarIntegrationService else { return }
        let view = CalendarScheduleView(
            service: service,
            weekStartsOn: service.weekStartsOn,
            presentationMode: .modal,
            selectedDate: calendarScheduleSelectedDateBinding()
        )
        let host = UIHostingController(rootView: AnyView(view.taskerLayoutClass(currentLayoutClass)))
        host.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        host.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        if let sheet = host.sheetPresentationController {
            let detents: [UISheetPresentationController.Detent] = currentLayoutClass.isPad
                ? [.large()]
                : [.medium(), .large()]
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
        }
        presentedCalendarScheduleController = host
        host.presentationController?.delegate = self
        present(host, animated: true)
    }

    private func handleFocusDeepLink() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        let preferredTask = viewModel?.focusTasks.first
            ?? viewModel?.morningTasks.first(where: { !$0.isComplete })
            ?? viewModel?.eveningTasks.first(where: { !$0.isComplete })
        startFocusFlow(task: preferredTask, source: "deeplink")
    }

    private func handleChatDeepLink(prompt: String?) {
        let launchRequest = EvaChatLaunchRequest(prompt: prompt)
        do {
            try EvaChatLaunchRequestStore.shared.submit(launchRequest)
        } catch {
            logError(
                event: "shortcut_chat_launch_request_store_failed",
                message: "Failed to persist Eva chat launch request",
                fields: [
                    "error": error.localizedDescription
                ]
            )
        }

        routeToChatSurface()
    }

    private func routeToChatSurface() {
        if isUsingIPadNativeShell {
            let routeToChat = { [weak self] in
                self?.iPadShellState.destination = .chat
            }

            if presentedViewController != nil {
                dismiss(animated: true) {
                    routeToChat()
                }
                return
            }

            routeToChat()
            return
        }

        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.presentEvaChatScreen(source: "deeplink_chat")
            }
            return
        }

        presentEvaChatScreen(source: "deeplink_chat")
    }

    private func consumePendingShortcutHandoffIfNeeded() {
        if let action = PendingShortcutLaunchActionStore.shared.consumePendingAction() {
            handlePendingShortcutLaunchAction(action)
        }
        if let signal = ShortcutMutationSignalStore.shared.consumePendingSignal() {
            handlePendingShortcutMutationSignal(signal)
        }
    }

    private func handlePendingShortcutLaunchAction(_ action: PendingShortcutLaunchAction) {
        switch action.kind {
        case .askEva:
            handleChatDeepLink(prompt: action.prompt)
        case .startFocus:
            handleFocusDeepLink()
        }
    }

    private func handlePendingShortcutMutationSignal(_ signal: ShortcutMutationSignal) {
        switch signal.kind {
        case .taskCreated:
            faceCoordinator.recordSearchMutation()
            viewModel?.handleExternalMutation(reason: .created)
        }
    }

    private func handleHomeDeepLink(notice: String? = nil) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        viewModel?.setQuickView(.today)
        if let notice, notice.isEmpty == false {
            showHomeSnackbar(message: notice)
        }
    }

    private func handleInsightsDeepLink() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .analytics
        }
        viewModel?.launchInsights(.default)
    }

    private func handleTaskScopeDeepLink(scope: String, projectID: UUID?) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        switch scope {
        case "upcoming":
            viewModel?.clearProjectFilters()
            viewModel?.setQuickView(.upcoming)
        case "overdue":
            viewModel?.clearProjectFilters()
            viewModel?.setQuickView(.overdue)
        case "project":
            guard let projectID else {
                viewModel?.clearProjectFilters()
                viewModel?.setQuickView(.today)
                return
            }
            viewModel?.setQuickView(.today)
            viewModel?.setProjectFilters([projectID])
        default:
            viewModel?.clearProjectFilters()
            viewModel?.setQuickView(.today)
        }
    }

    private func handleTaskDetailDeepLink(taskID: UUID) {
        viewModel?.setQuickView(.today)
        pendingNotificationFocusTaskID = taskID
        resolveAndPresentTaskDetail(taskID: taskID)
    }

    private func handleHabitBoardDeepLink() {
        routeToHabitDeepLinkDestination {
            NotificationCenter.default.post(name: .taskerPresentHabitBoard, object: nil)
        }
    }

    private func handleHabitLibraryDeepLink() {
        routeToHabitDeepLinkDestination {
            NotificationCenter.default.post(name: .taskerPresentHabitLibrary, object: nil)
        }
    }

    private func handleHabitDetailDeepLink(habitID: UUID) {
        routeToHabitDeepLinkDestination {
            NotificationCenter.default.post(
                name: .taskerPresentHabitDetail,
                object: nil,
                userInfo: ["habitID": habitID.uuidString]
            )
        }
    }

    private func routeToHabitDeepLinkDestination(_ completion: @escaping () -> Void) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        viewModel?.setQuickView(.today)

        if presentedViewController != nil {
            dismiss(animated: true) {
                DispatchQueue.main.async {
                    completion()
                }
            }
            return
        }

        DispatchQueue.main.async {
            completion()
        }
    }

    private func handleQuickAddDeepLink() {
        if isUsingIPadNativeShell {
            if presentedViewController != nil {
                dismiss(animated: true) { [weak self] in
                    guard let self else { return }
                    if self.currentLayoutClass == .padExpanded {
                        self.iPadShellState.destination = .addTask
                    } else {
                        self.presentAddTaskSheetForPadFallback()
                    }
                }
                return
            }
            if currentLayoutClass == .padExpanded {
                iPadShellState.destination = .addTask
            } else {
                presentAddTaskSheetForPadFallback()
            }
            return
        }
        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.AddTaskAction()
            }
            return
        }
        AddTaskAction()
    }

    private func handleCalendarScheduleDeepLink() {
        if isUsingIPadNativeShell {
            let routeToSchedule = { [weak self] in
                self?.iPadShellState.destination = .schedule
            }
            if presentedViewController != nil {
                dismiss(animated: true) {
                    routeToSchedule()
                }
                return
            }
            routeToSchedule()
            return
        }

        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.openSchedule(source: "deeplink_schedule")
            }
            return
        }
        openSchedule(source: "deeplink_schedule")
    }

    private func handleCalendarChooserDeepLink() {
        let openChooser = { [weak self] in
            guard let self else { return }
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .schedule
            }
            self.presentCalendarChooser()
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                openChooser()
            }
            return
        }
        openChooser()
    }

    private func handleWeeklyPlannerDeepLink() {
        let openPlanner = { [weak self] in
            guard let self else { return }
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .tasks
            }
            self.viewModel?.setQuickView(.today)
            self.presentWeeklyPlanner()
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                openPlanner()
            }
            return
        }

        openPlanner()
    }

    private func handleWeeklyReviewDeepLink() {
        let openReview = { [weak self] in
            guard let self else { return }
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .tasks
            }
            self.viewModel?.setQuickView(.today)
            self.presentWeeklyReview()
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                openReview()
            }
            return
        }

        openReview()
    }

    private func processPendingWidgetActionCommand() {
        guard V2FeatureFlags.interactiveTaskWidgetsEnabled else { return }
        guard AppDelegate.isWriteClosed == false else { return }
        guard let command = TaskListWidgetActionCommand.loadPending() else { return }

        if command.expiresAt <= Date() {
            TaskListWidgetActionCommand.clearPending()
            return
        }

        processWidgetActionCommand(command, attemptsRemaining: 2)
    }

    private func processWidgetActionCommand(_ command: TaskListWidgetActionCommand, attemptsRemaining: Int) {
        guard let viewModel else { return }

        guard let task = viewModel.taskSnapshot(for: command.taskID) else {
            guard attemptsRemaining > 0 else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            viewModel.loadTodayTasks()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.processWidgetActionCommand(command, attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }

        switch command.action {
        case .complete:
            guard task.isComplete == false else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            viewModel.setTaskCompletion(taskID: task.id, to: true) { _ in
                TaskListWidgetActionCommand.clearPending()
            }
            viewModel.setQuickView(.today)

        case .defer15m, .defer60m:
            guard task.isComplete == false else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            let deferMinutes = command.action == .defer15m ? 15 : 60
            let idempotenceThreshold = command.createdAt.addingTimeInterval(TimeInterval(max(deferMinutes - 1, 1) * 60))
            if let dueDate = task.dueDate, dueDate >= idempotenceThreshold {
                TaskListWidgetActionCommand.clearPending()
                return
            }

            let requestedDate = Date().addingTimeInterval(TimeInterval(deferMinutes * 60))
            let clampedDate = min(requestedDate, Date().addingTimeInterval(24 * 60 * 60))
            viewModel.rescheduleTask(taskID: task.id, to: clampedDate) { _ in
                TaskListWidgetActionCommand.clearPending()
            }
            viewModel.setQuickView(.today)
        }
    }

    private func startFocusFlow(task: TaskDefinition?, source: String) {
        guard let viewModel else { return }
        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.startFocusFlow(task: task, source: source)
            }
            return
        }

        viewModel.startFocusSession(taskID: task?.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let session):
                    self.presentFocusTimer(task: task, session: session, source: source)
                case .failure(let error):
                    if let focusError = error as? FocusSessionError, case .alreadyActive = focusError {
                        self.resumeActiveFocusSession(source: source)
                    } else {
                        logWarning(
                            event: "focus_session_start_failed",
                            message: "Failed to start focus session",
                            fields: [
                                "source": source,
                                "error": error.localizedDescription
                            ]
                        )
                    }
                }
            }
        }
    }

    private func resumeActiveFocusSession(source: String) {
        viewModel?.fetchActiveFocusSession { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let session):
                guard let session else {
                    self.viewModel?.setQuickView(.today)
                    logWarning(
                        event: "focus_session_resume_missing",
                        message: "Expected an active focus session to resume, but none was found",
                        fields: ["source": source]
                    )
                    return
                }

                let task = resolveTaskForFocusSession(taskID: session.taskID)
                presentFocusTimer(task: task, session: session, source: "\(source)_resume")
            case .failure(let error):
                self.viewModel?.setQuickView(.today)
                logWarning(
                    event: "focus_session_resume_failed",
                    message: "Failed to resume active focus session",
                    fields: [
                        "source": source,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    private func resolveTaskForFocusSession(taskID: UUID?) -> TaskDefinition? {
        guard let taskID else { return nil }
        var candidates: [TaskDefinition] = []
        candidates.append(contentsOf: viewModel?.focusTasks ?? [])
        candidates.append(contentsOf: viewModel?.morningTasks ?? [])
        candidates.append(contentsOf: viewModel?.eveningTasks ?? [])
        candidates.append(contentsOf: viewModel?.overdueTasks ?? [])
        return candidates.first(where: { $0.id == taskID })
    }

    private func presentFocusTimer(task: TaskDefinition?, session: FocusSessionDefinition, source: String) {
        let timerView = FocusTimerView(
            taskTitle: task?.title,
            taskPriority: task?.priority.displayName,
            targetDurationSeconds: session.targetDurationSeconds,
            onComplete: { [weak self] _ in
                self?.dismiss(animated: true) {
                    self?.finishFocusSession(sessionID: session.id, source: source)
                }
            },
            onCancel: { [weak self] in
                self?.dismiss(animated: true) {
                    self?.finishFocusSession(sessionID: session.id, source: "\(source)_cancel")
                }
            }
        )
        let host = UIHostingController(rootView: timerView)
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
    }

    private func finishFocusSession(sessionID: UUID, source: String) {
        viewModel?.endFocusSession(sessionID: sessionID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let focusResult):
                    self.presentFocusSummary(focusResult)
                    self.viewModel?.trackHomeInteraction(
                        action: "focus_session_finished",
                        metadata: [
                            "source": source,
                            "duration_seconds": focusResult.session.durationSeconds,
                            "awarded_xp": focusResult.xpResult?.awardedXP ?? 0
                        ]
                    )
                case .failure(let error):
                    logWarning(
                        event: "focus_session_end_failed",
                        message: "Failed to end focus session",
                        fields: [
                            "source": source,
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
        }
    }

    private func presentFocusSummary(_ result: FocusSessionResult) {
        guard let viewModel else { return }
        let summaryView = FocusSessionSummaryView(
            durationSeconds: result.session.durationSeconds,
            xpAwarded: result.xpResult?.awardedXP ?? result.session.xpAwarded,
            dailyXPSoFar: result.xpResult?.dailyXPSoFar ?? viewModel.dailyScore,
            dailyXPCap: GamificationTokens.dailyXPCap,
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            },
            onContinueMomentum: { [weak self] in
                self?.viewModel?.setQuickView(.today)
                self?.dismiss(animated: true)
            }
        )
        let host = UIHostingController(rootView: summaryView)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(host, animated: true)
    }

    private func handleNotificationRoute(_ route: TaskerNotificationRoute) {
        guard let viewModel else { return }
        switch route {
        case .homeToday(let taskID):
            if isUsingIPadNativeShell {
                iPadShellState.destination = .tasks
            }
            viewModel.setQuickView(.today)
            pendingNotificationFocusTaskID = taskID
        case .homeDone:
            if isUsingIPadNativeShell {
                iPadShellState.destination = .tasks
            }
            viewModel.setQuickView(.done)
            pendingNotificationFocusTaskID = nil
        case .taskDetail(let taskID):
            if isUsingIPadNativeShell {
                iPadShellState.destination = .tasks
            }
            viewModel.setQuickView(.today)
            pendingNotificationFocusTaskID = taskID
            resolveAndPresentTaskDetail(taskID: taskID)
        case .weeklyPlanner:
            handleWeeklyPlannerDeepLink()
        case .weeklyReview:
            handleWeeklyReviewDeepLink()
        case .dailySummary(let kind, let dateStamp):
            if kind == .nightly {
                presentReflectPlanFlow(preferredReflectionDate: dateFromStamp(dateStamp))
            } else {
                presentDailySummaryModal(kind: kind, dateStamp: dateStamp)
            }
        }
    }

    private func resolveAndPresentTaskDetail(taskID: UUID, attemptsRemaining: Int = 2) {
        if let task = viewModel?.taskSnapshot(for: taskID) {
            if isUsingIPadNativeShell {
                iPadShellState.destination = .tasks
                if currentLayoutClass == .padExpanded {
                    iPadShellState.selectedTask = task
                } else {
                    presentTaskDetailView(for: task)
                }
            } else {
                presentTaskDetailView(for: task)
            }
            return
        }
        guard attemptsRemaining > 0 else { return }
        viewModel?.loadTodayTasks()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.resolveAndPresentTaskDetail(taskID: taskID, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private func presentDailySummaryModal(kind: TaskerDailySummaryKind, dateStamp: String?) {
        guard let viewModel else { return }

        let presentSummary: (DailySummaryModalData) -> Void = { [weak self] summary in
            guard let self else { return }
            let dismissSummary: (@escaping () -> Void) -> Void = { [weak self] completion in
                self?.dismiss(animated: true) {
                    self?.scheduleOnboardingEvaluationIfNeeded()
                    self?.onboardingCoordinator?.drainPendingPresentationIfPossible()
                    completion()
                }
            }

            let summaryView = DailySummaryModalView(
                summary: summary,
                onDismiss: {
                    dismissSummary {}
                },
                onStartToday: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "start_today", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.trackDailySummaryActionResult(cta: "start_today", success: true, error: nil)
                    dismissSummary {}
                },
                onCompleteMorningRoutine: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "complete_morning_routine", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.completeMorningRoutine { result in
                        switch result {
                        case .success:
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "complete_morning_routine",
                                success: true,
                                error: nil
                            )
                        case .failure(let error):
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "complete_morning_routine",
                                success: false,
                                error: error
                            )
                        }
                    }
                    dismissSummary {}
                },
                onStartTriage: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "start_triage", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.startTriage(scope: .visible)
                    self.viewModel.trackDailySummaryActionResult(cta: "start_triage", success: true, error: nil)
                    dismissSummary {}
                },
                onRescueOverdue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "rescue_overdue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.openRescue()
                    self.viewModel.trackDailySummaryActionResult(cta: "rescue_overdue", success: true, error: nil)
                    dismissSummary {}
                },
                onAddTask: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "add_task", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.trackDailySummaryActionResult(cta: "add_task", success: true, error: nil)
                    dismissSummary {
                        self.AddTaskAction()
                    }
                },
                onPlanTomorrow: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "plan_tomorrow", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.performEndOfDayCleanup { result in
                        switch result {
                        case .success:
                            self.viewModel.trackDailySummaryActionResult(cta: "plan_tomorrow", success: true, error: nil)
                        case .failure(let error):
                            self.viewModel.trackDailySummaryActionResult(cta: "plan_tomorrow", success: false, error: error)
                        }
                    }
                    dismissSummary {}
                },
                onReviewDone: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "review_done", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.done)
                    self.viewModel.trackDailySummaryActionResult(cta: "review_done", success: true, error: nil)
                    dismissSummary {}
                },
                onRescheduleOverdue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "reschedule_overdue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.rescheduleOverdueTasks { result in
                        switch result {
                        case .success:
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "reschedule_overdue",
                                success: true,
                                error: nil
                            )
                        case .failure(let error):
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "reschedule_overdue",
                                success: false,
                                error: error
                            )
                        }
                    }
                    dismissSummary {}
                },
                onOpenRescue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "open_rescue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.openRescue()
                    self.viewModel.trackDailySummaryActionResult(cta: "open_rescue", success: true, error: nil)
                    dismissSummary {}
                }
            )

            let hostingController = UIHostingController(rootView: summaryView)
            hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
            hostingController.view.accessibilityIdentifier = "home.dailySummaryModal"
            hostingController.modalPresentationStyle = .pageSheet
            hostingController.presentationController?.delegate = self

            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }

            self.present(hostingController, animated: true)
        }

        viewModel.loadDailySummaryModal(kind: kind, dateStamp: dateStamp) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                presentSummary(self.fallbackDailySummary(kind: kind, dateStamp: dateStamp))
            case .success(let summary):
                presentSummary(summary)
            }
        }
    }

    private func presentReflectPlanFlow(preferredReflectionDate: Date?) {
        guard let viewModel else { return }

        let reflectPlanViewModel = PresentationDependencyContainer.shared.makeDailyReflectPlanViewModel(
            preferredReflectionDate: preferredReflectionDate,
            analyticsTracker: { [weak self] action, metadata in
                self?.viewModel?.trackHomeInteraction(
                    action: action,
                    metadata: metadata.reduce(into: [String: Any]()) { partialResult, item in
                        partialResult[item.key] = item.value
                    }
                )
            },
            onComplete: { [weak self] result in
                self?.viewModel?.refreshAfterDailyReflectPlanSave(planningDate: result.target.planningDate)
                self?.dismiss(animated: true)
            }
        )

        let hostingController = UIHostingController(
            rootView: ReflectPlanScreen(
                viewModel: reflectPlanViewModel,
                onClose: { [weak self] in
                    self?.dismiss(animated: true)
                }
            )
        )

        if traitCollection.horizontalSizeClass == .compact {
            hostingController.modalPresentationStyle = .fullScreen
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }

        present(hostingController, animated: true)
        viewModel.trackHomeInteraction(
            action: "reflection_opened",
            metadata: ["source": "notification_nightly"]
        )
    }

    private func fallbackDailySummary(kind: TaskerDailySummaryKind, dateStamp: String?) -> DailySummaryModalData {
        let date = fallbackSummaryDate(from: dateStamp)
        switch kind {
        case .morning:
            return .morning(
                MorningPlanSummary(
                    date: date,
                    openTodayCount: 0,
                    highPriorityCount: 0,
                    overdueCount: 0,
                    potentialXP: 0,
                    focusTasks: [],
                    blockedCount: 0,
                    longTaskCount: 0,
                    morningPlannedCount: 0,
                    eveningPlannedCount: 0
                )
            )
        case .nightly:
            return .nightly(
                NightlyRetrospectiveSummary(
                    date: date,
                    completedCount: 0,
                    totalCount: 0,
                    xpEarned: 0,
                    completionRate: 0,
                    streakCount: 0,
                    biggestWins: [],
                    carryOverDueTodayCount: 0,
                    carryOverOverdueCount: 0,
                    tomorrowPreview: [],
                    morningCompletedCount: 0,
                    eveningCompletedCount: 0
                )
            )
        }
    }

    private func dateFromStamp(_ stamp: String?) -> Date? {
        guard let stamp, stamp.isEmpty == false else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        return formatter.date(from: stamp)
    }

    private func fallbackSummaryDate(from dateStamp: String?) -> Date {
        guard let dateStamp, dateStamp.count == 8 else { return Date() }
        var components = DateComponents()
        components.year = Int(dateStamp.prefix(4))
        components.month = Int(dateStamp.dropFirst(4).prefix(2))
        components.day = Int(dateStamp.suffix(2))
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Chart Refresh Contract

    /// Executes refreshChartsAfterTaskCompletion.
    func refreshChartsAfterTaskCompletion() {
        refreshChartsAfterTaskMutation(reason: .completed)
    }

    /// Executes refreshChartsAfterTaskMutation.
    func refreshChartsAfterTaskMutation(reason: HomeTaskMutationEvent? = nil) {
        if let reason {
            logDebug("🎯 HomeViewController chart refresh reason=\(reason.rawValue)")
        }
        chartCardViewModel?.load(referenceDate: nil, force: true)
        radarChartCardViewModel?.load(referenceDate: nil, force: true)
    }

    @objc private func homeTaskMutationReceived(_ notification: Notification) {
        let payload = HomeTaskMutationPayload(notification: notification)
        let reason = payload?.reason ?? (notification.userInfo?["reason"] as? String).flatMap(HomeTaskMutationEvent.init(rawValue:))

        if let payload, HomeSearchInvalidationPolicy.shouldRefreshSearch(for: payload) {
            faceCoordinator.recordSearchMutation()
        }

        pendingChartRefreshWorkItem?.cancel()
        let refreshWorkItem = DispatchWorkItem { [weak self] in
            self?.refreshChartsAfterTaskMutation(reason: reason)
        }
        pendingChartRefreshWorkItem = refreshWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + chartRefreshDebounceSeconds, execute: refreshWorkItem)
    }

    // MARK: - Theme

    /// Executes applyTheme.
    private func applyTheme() {
        view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
    }
}

private final class RescheduleViewController: UIViewController {
    private let taskTitle: String
    private let onDateSelected: (Date) -> Void
    private let datePicker = UIDatePicker()

    /// Initializes a new instance.
    init(taskTitle: String, currentDueDate: Date?, onDateSelected: @escaping (Date) -> Void) {
        self.taskTitle = taskTitle
        self.onDateSelected = onDateSelected
        super.init(nibName: nil, bundle: nil)
        datePicker.date = currentDueDate ?? Date()
    }

    /// Initializes a new instance.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        title = "Reschedule"

        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .inline
        view.addSubview(datePicker)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )

        NSLayoutConstraint.activate([
            datePicker.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        onDateSelected(datePicker.date)
        dismiss(animated: true)
    }
}

// MARK: - Snackbar Support

extension HomeViewController {
    /// Executes observeTaskCreatedForSnackbar.
    func observeTaskCreatedForSnackbar() {
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated"))
            .receive(on: RunLoop.main)
            .compactMap { $0.object as? TaskDefinition }
            .sink { [weak self] createdTask in
                self?.showTaskCreatedSnackbar(for: createdTask)
            }
            .store(in: &cancellables)
    }

    private func observeOnboardingRequests() {
        notificationCenter.publisher(for: .taskerStartOnboardingRequested)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.onboardingCoordinator?.restartOnboarding()
                self?.onboardingCoordinator?.drainPendingPresentationIfPossible()
            }
            .store(in: &cancellables)
    }

    /// Executes showTaskCreatedSnackbar.
    private func showTaskCreatedSnackbar(for task: TaskDefinition) {
        let taskID = task.id
        showHomeSnackbar(
            data: SnackbarData(
                message: "Task added.",
                actions: [
                    SnackbarAction(title: "Undo") { [weak self] in
                        self?.viewModel?.deleteTask(taskID: taskID) { _ in }
                    }
                ]
            )
        )
    }

    private func showHomeSnackbar(message: String) {
        showHomeSnackbar(data: SnackbarData(message: message, actions: []))
    }

    private func showHomeSnackbar(data: SnackbarData) {
        guard homeHostingController != nil else { return }

        let snackbar = TaskerSnackbar(data: data, onDismiss: {})
        let snackbarVC = UIHostingController(rootView: snackbar)
        snackbarVC.view.backgroundColor = .clear
        snackbarVC.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(snackbarVC)
        view.addSubview(snackbarVC.view)
        NSLayoutConstraint.activate([
            snackbarVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            snackbarVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            snackbarVC.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
        snackbarVC.didMove(toParent: self)

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            snackbarVC.willMove(toParent: nil)
            snackbarVC.view.removeFromSuperview()
            snackbarVC.removeFromParent()
        }
    }
}

private struct DailySummaryModalView: View {
    let summary: DailySummaryModalData
    let onDismiss: () -> Void
    let onStartToday: () -> Void
    let onCompleteMorningRoutine: () -> Void
    let onStartTriage: () -> Void
    let onRescueOverdue: () -> Void
    let onAddTask: () -> Void
    let onPlanTomorrow: () -> Void
    let onReviewDone: () -> Void
    let onRescheduleOverdue: () -> Void
    let onOpenRescue: () -> Void

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            headerCard
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .background(Color.tasker.strokeHairline)

            ScrollView {
                scrollableContent
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }

            Divider()
                .background(Color.tasker.strokeHairline)

            ctaBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(Color.tasker.surfacePrimary)
        }
        .background(Color.tasker.bgCanvas)
        .accessibilityIdentifier("home.dailySummaryModal")
    }

    @ViewBuilder
    private var scrollableContent: some View {
        switch summary {
        case .morning(let value):
            morningContent(value)
        case .nightly(let value):
            nightlyContent(value)
        }
    }

    private var headerCard: some View {
        let title: String
        let subtitle: String
        switch summary {
        case .morning(let value):
            title = "Morning Plan"
            subtitle = headerDateText(value.date)
        case .nightly(let value):
            title = "Day Retrospective"
            subtitle = headerDateText(value.date)
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.tasker(.title3))
                            .foregroundStyle(Color.tasker.textPrimary)
                        TaskerStatusPill(
                            text: summaryBadgeText,
                            systemImage: summaryBadgeSymbol,
                            tone: summaryBadgeTone
                        )
                    }
                    Text(summaryNarrative)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                    Text(subtitle)
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker.textTertiary)
                }
                Spacer(minLength: 8)
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            summaryHeroMetrics
        }
        .padding(16)
        .taskerPremiumSurface(
            cornerRadius: 16,
            fillColor: Color.tasker.surfacePrimary,
            accentColor: headerAccentColor,
            level: .e2
        )
    }

    private var summaryHeroMetrics: some View {
        switch summary {
        case .morning(let value):
            return AnyView(
                HStack(spacing: 10) {
                    metricChip(
                        title: "Open",
                        value: "\(value.openTodayCount)",
                        id: "home.dailySummary.hero.openCount",
                        numericValue: value.openTodayCount
                    )
                    metricChip(
                        title: "High",
                        value: "\(value.highPriorityCount)",
                        id: "home.dailySummary.hero.highCount",
                        numericValue: value.highPriorityCount
                    )
                    metricChip(
                        title: "Overdue",
                        value: "\(value.overdueCount)",
                        id: "home.dailySummary.hero.overdueCount",
                        numericValue: value.overdueCount
                    )
                    metricChip(
                        title: "XP",
                        value: "\(value.potentialXP)",
                        id: "home.dailySummary.hero.potentialXP",
                        numericValue: value.potentialXP
                    )
                }
            )
        case .nightly(let value):
            return AnyView(
                HStack(spacing: 10) {
                    metricChip(
                        title: "Done",
                        value: "\(value.completedCount)/\(value.totalCount)",
                        id: "home.dailySummary.hero.completed",
                        detail: value.totalCount > 0 ? "\(Int((value.completionRate * 100).rounded()))% completion" : "No schedule recorded"
                    )
                    metricChip(
                        title: "XP",
                        value: "\(value.xpEarned)",
                        id: "home.dailySummary.hero.xp",
                        numericValue: value.xpEarned
                    )
                    metricChip(
                        title: "Rate",
                        value: "\(Int((value.completionRate * 100).rounded()))%",
                        id: "home.dailySummary.hero.rate",
                        numericValue: Int((value.completionRate * 100).rounded()),
                        numericSuffix: "%"
                    )
                    metricChip(
                        title: "Streak",
                        value: "\(value.streakCount)d",
                        id: "home.dailySummary.hero.streak",
                        numericValue: value.streakCount,
                        numericSuffix: "d"
                    )
                }
            )
        }
    }

    private func morningContent(_ summary: MorningPlanSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(title: "Focus Now") {
                if summary.focusTasks.isEmpty {
                    Text("No tasks queued. Capture one meaningful win.")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textSecondary)
                } else {
                    ForEach(summary.focusTasks) { row in
                        taskRow(row)
                    }
                }
            }

            sectionCard(title: "Risk & Friction") {
                VStack(alignment: .leading, spacing: 8) {
                    riskLine(title: "Overdue tasks", value: summary.overdueCount)
                    riskLine(title: "Blocked tasks", value: summary.blockedCount)
                    riskLine(title: "Long tasks (60m+)", value: summary.longTaskCount)
                }
            }

            sectionCard(title: "Agenda Split") {
                HStack(spacing: 12) {
                    agendaPill(title: "Morning", value: summary.morningPlannedCount)
                    agendaPill(title: "Evening", value: summary.eveningPlannedCount)
                }
            }
        }
    }

    private func nightlyContent(_ summary: NightlyRetrospectiveSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(title: "Biggest Wins") {
                if summary.biggestWins.isEmpty {
                    Text("No completions today. Pick one tiny restart for tomorrow.")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textSecondary)
                } else {
                    ForEach(summary.biggestWins) { row in
                        taskRow(row)
                    }
                }
            }

            sectionCard(title: "Carry-over") {
                VStack(alignment: .leading, spacing: 8) {
                    riskLine(title: "Open due today", value: summary.carryOverDueTodayCount)
                    riskLine(title: "Still overdue", value: summary.carryOverOverdueCount)
                }
            }

            sectionCard(title: "Tomorrow Preview") {
                if summary.tomorrowPreview.isEmpty {
                    Text("No tasks due tomorrow yet.")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textSecondary)
                } else {
                    ForEach(summary.tomorrowPreview) { row in
                        taskRow(row)
                    }
                }
            }

            sectionCard(title: "Reflection Insight") {
                HStack(spacing: 12) {
                    agendaPill(title: "Morning Done", value: summary.morningCompletedCount)
                    agendaPill(title: "Evening Done", value: summary.eveningCompletedCount)
                }
            }
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
            content()
        }
        .padding(14)
        .taskerDenseSurface(
            cornerRadius: 14,
            fillColor: Color.tasker.surfaceSecondary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.72)
        )
    }

    private func taskRow(_ row: SummaryTaskRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(priorityColor(row.priority))
                .frame(width: 8, height: 8)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    priorityBadge(row.priority)
                    if row.isOverdue {
                        statusBadge(
                            text: "Overdue",
                            foreground: Color.tasker.statusDanger,
                            background: Color.tasker.statusDanger.opacity(0.14)
                        )
                    }
                    if row.isBlocked {
                        statusBadge(
                            text: "Blocked",
                            foreground: Color.tasker.statusWarning,
                            background: Color.tasker.statusWarning.opacity(0.16)
                        )
                    }
                }
                HStack(spacing: 8) {
                    if let dueLabel = dueLabel(for: row) {
                        Text(dueLabel)
                            .font(.tasker(.caption2))
                            .foregroundColor(row.isOverdue ? Color.tasker.statusDanger : Color.tasker.textSecondary)
                    }
                    if let estimatedDuration = row.estimatedDuration {
                        Text(durationLabel(seconds: estimatedDuration))
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.textTertiary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("home.dailySummary.taskRow.\(row.taskID.uuidString)")
    }

    private func riskLine(title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textSecondary)
            Spacer()
            Text("\(value)")
                .font(.tasker(.bodyEmphasis))
                .foregroundColor(Color.tasker.textPrimary)
        }
    }

    private func agendaPill(title: String, value: Int) -> some View {
        TaskerHeroMetricTile(
            title: title,
            value: "\(value)",
            detail: value == 0 ? "Quiet" : "Visible progress",
            tone: value == 0 ? .neutral : .accent
        )
    }

    private func metricChip(
        title: String,
        value: String,
        id: String,
        numericValue: Int? = nil,
        numericSuffix: String = "",
        detail: String? = nil
    ) -> some View {
        return TaskerHeroMetricTile(
            title: title,
            value: numericValue != nil ? "\(numericValue ?? 0)\(numericSuffix)" : value,
            detail: detail,
            tone: title == "Overdue" ? .warning : (title == "XP" ? .accent : .neutral),
            accessibilityIdentifier: id
        )
    }

    private var ctaBar: some View {
        let primaryCTAIdentifier = TaskerCTABezelResolver.dailySummaryPrimaryCTAIdentifier(for: summary)

        return VStack(alignment: .leading, spacing: 10) {
            switch summary {
            case .morning(let value):
                Button("Start Today") { onStartToday() }
                    .buttonStyle(.borderedProminent)
                    .taskerCTABezel(
                        style: .summaryPrimary,
                        idleMotion: .slowLoop,
                        isEnabled: primaryCTAIdentifier == "home.dailySummary.cta.startToday"
                    )
                    .taskerSuccessPulse(isActive: primaryCTAIdentifier == "home.dailySummary.cta.startToday")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.startToday")

                HStack(spacing: 10) {
                    Button("Complete Morning Routine") { onCompleteMorningRoutine() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.completeMorning")
                    Button("Start Triage") { onStartTriage() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.startTriage")
                }

                if value.overdueCount > 0 {
                    Button("Rescue Overdue") { onRescueOverdue() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.rescueOverdue")
                }

                Button("Add Task") { onAddTask() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.addTask")

            case .nightly(let value):
                Button("Plan Tomorrow") { onPlanTomorrow() }
                    .buttonStyle(.borderedProminent)
                    .taskerCTABezel(
                        style: .summaryPrimary,
                        idleMotion: .slowLoop,
                        isEnabled: primaryCTAIdentifier == "home.dailySummary.cta.planTomorrow"
                    )
                    .taskerSuccessPulse(isActive: primaryCTAIdentifier == "home.dailySummary.cta.planTomorrow")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.planTomorrow")

                Button("Review Done") { onReviewDone() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.reviewDone")

                if value.carryOverOverdueCount > 0 {
                    Button("Reschedule Overdue") { onRescheduleOverdue() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.rescheduleOverdue")
                }

                if value.carryOverOverdueCount > 0 {
                    Button("Open Rescue") { onOpenRescue() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.openRescue")
                }
            }
        }
    }

    private var summaryBadgeText: String {
        switch summary {
        case .morning:
            return "Plan"
        case .nightly:
            return "Reflect"
        }
    }

    private var summaryBadgeSymbol: String {
        switch summary {
        case .morning:
            return "sun.max.fill"
        case .nightly:
            return "moon.stars.fill"
        }
    }

    private var summaryBadgeTone: TaskerStatusPillTone {
        switch summary {
        case .morning:
            return .accent
        case .nightly:
            return .success
        }
    }

    private var summaryNarrative: String {
        switch summary {
        case .morning(let value):
            return value.openTodayCount == 0
                ? "You can start with one meaningful win."
                : "Shape the day before the backlog sets the agenda."
        case .nightly(let value):
            return value.completedCount == 0
                ? "Close the loop with a realistic reset for tomorrow."
                : "Notice what moved today before deciding what rolls forward."
        }
    }

    private var headerAccentColor: Color {
        switch summary {
        case .morning:
            return Color.tasker.accentSecondary
        case .nightly:
            return Color.tasker.statusSuccess
        }
    }

    private func dueLabel(for row: SummaryTaskRow) -> String? {
        guard let dueDate = row.dueDate else { return nil }
        return relativeFormatter.localizedString(for: dueDate, relativeTo: Date())
    }

    private func durationLabel(seconds: TimeInterval) -> String {
        let minutes = Int(round(seconds / 60))
        if minutes >= 60 {
            if minutes % 60 == 0 {
                return "\(minutes / 60)h"
            }
            return String(format: "%.1fh", Double(minutes) / 60.0)
        }
        return "\(minutes)m"
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        if priority == .max {
            return Color.tasker.statusDanger
        }
        if priority == .high {
            return Color.tasker.statusWarning
        }
        if priority == .low {
            return Color.tasker.accentPrimary
        }
        return Color.tasker.textTertiary
    }

    private func priorityBadge(_ priority: TaskPriority) -> some View {
        statusBadge(
            text: priority.displayName,
            foreground: priorityColor(priority),
            background: priorityColor(priority).opacity(0.14)
        )
    }

    private func statusBadge(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.tasker(.caption2))
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(background)
            )
    }

    private func headerDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

extension HomeViewController {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if presentationController.presentedViewController === presentedCalendarScheduleController {
            presentedCalendarScheduleController = nil
            faceCoordinator.bottomBarState.select(faceCoordinator.activeFace.selectedBottomBarItem)
        } else if presentationController.presentedViewController === presentedEvaChatController {
            resetHomeSelectionAfterEvaChatDismissal()
        }
        resetPendingIPadModalWaitState()
        processPendingIPadModalRequest()
        scheduleOnboardingEvaluationIfNeeded()
        onboardingCoordinator?.drainPendingPresentationIfPossible()
    }
}

#if DEBUG
extension HomeViewController {
    func testingSetAnalyticsVisible(with insightsViewModel: InsightsViewModel?) {
        self.insightsViewModel = insightsViewModel
        faceCoordinator.insightsViewModel = insightsViewModel
        faceCoordinator.setActiveFace(.analytics)
        faceCoordinator.setAnalyticsSurfaceState(insightsViewModel == nil ? .placeholder : .ready)
    }

    func testingHandleInsightsLaunchRequest(_ request: InsightsLaunchRequest?) {
        handleInsightsLaunchRequest(request)
    }

    var testingPendingInsightsLaunchRequest: InsightsLaunchRequest? {
        pendingInsightsLaunchRequest
    }

    func testingSetPendingOnboardingEvaluationTask() {
        pendingOnboardingEvaluationTask = Task {}
    }

    var testingHasPendingOnboardingEvaluationTask: Bool {
        pendingOnboardingEvaluationTask != nil
    }

    func testingSetOnboardingEvaluationSceneToken(_ token: Int) {
        onboardingEvaluationSceneToken = token
    }
}
#endif
