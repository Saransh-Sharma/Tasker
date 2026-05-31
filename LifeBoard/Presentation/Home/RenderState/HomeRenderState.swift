//
//  HomeRenderState.swift
//  LifeBoard
//

import Foundation
import CoreGraphics

typealias HomeChromeState = HomeChromeSnapshot
typealias HomeTasksState = HomeTasksSnapshot
typealias HomeCalendarState = HomeCalendarSnapshot
typealias HomeOverlayState = HomeOverlaySnapshot

struct HomeTimelineRenderState: Equatable {
    let revision: UInt64

    static var empty: HomeTimelineRenderState {
        HomeTimelineRenderState(revision: 0)
    }

    func advanced() -> HomeTimelineRenderState {
        HomeTimelineRenderState(revision: revision &+ 1)
    }
}

struct HomeRenderTransaction: Equatable {
    let chrome: HomeChromeState
    let tasks: HomeTasksState
    let habits: HomeHabitsSnapshot
    let calendar: HomeCalendarState
    let timeline: HomeTimelineRenderState
    let overlay: HomeOverlayState

    init(
        chrome: HomeChromeState,
        tasks: HomeTasksState,
        habits: HomeHabitsSnapshot,
        calendar: HomeCalendarState = .empty,
        timeline: HomeTimelineRenderState = .empty,
        overlay: HomeOverlayState
    ) {
        self.chrome = chrome
        self.tasks = tasks
        self.habits = habits
        self.calendar = calendar
        self.timeline = timeline
        self.overlay = overlay
    }

    static var empty: HomeRenderTransaction {
        HomeRenderTransaction(
            chrome: .empty,
            tasks: .empty,
            habits: .empty,
            calendar: .empty,
            timeline: .empty,
            overlay: .empty
        )
    }

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
        if timeline != previous.timeline {
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

    static var empty: HomeChromeSnapshot {
        HomeChromeSnapshot(
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

    static var empty: HomeTasksSnapshot {
        HomeTasksSnapshot(
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
    }

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

    static var empty: HomeHabitsSnapshot {
        HomeHabitsSnapshot(
            habitHomeSectionState: HabitHomeSectionState(primaryRows: [], recoveryRows: []),
            quietTrackingSummaryState: QuietTrackingSummaryState(stableRows: []),
            errorMessage: nil
        )
    }
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
    let authorizationStatus: LifeBoardCalendarAuthorizationStatus
    let accessAction: CalendarAccessAction
    let selectedCalendarCount: Int
    let availableCalendarCount: Int
    let nextMeeting: LifeBoardNextMeetingSummary?
    let busyBlocks: [LifeBoardCalendarBusyBlock]
    let freeUntil: Date?
    let selectedDayEvents: [LifeBoardCalendarEventSnapshot]
    let selectedDayTimelineEvents: [LifeBoardCalendarEventSnapshot]
    let eventsTodayCount: Int
    let isLoading: Bool
    let errorMessage: String?

    static var empty: HomeCalendarSnapshot {
        HomeCalendarSnapshot(
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
    let sunriseAnchor: SunriseAnchor
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

    static var empty: HomeOverlaySnapshot {
        HomeOverlaySnapshot(
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
    }

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
