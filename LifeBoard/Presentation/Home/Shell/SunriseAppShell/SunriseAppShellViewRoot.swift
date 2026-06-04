//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct SunriseAppShellView: View {


    let viewModel: HomeViewModel

    @ObservedObject var chromeStore: HomeChromeStore

    @ObservedObject var tasksStore: HomeTasksStore

    @ObservedObject var habitsStore: HomeHabitsStore

    @ObservedObject var calendarStore: HomeCalendarStore

    @ObservedObject var timelineStore: HomeTimelineStore

    let calendarIntegrationService: CalendarIntegrationService?

    let chatAppManager: AppManager

    @ObservedObject var overlayStore: HomeOverlayStore

    @ObservedObject var faceCoordinator: HomeFaceCoordinator

    @ObservedObject var searchState: HomeSearchState

    let layoutClass: LifeBoardLayoutClass

    let forcedFace: Binding<HomeSunriseFace>?

    @ObservedObject var themeManager = LifeBoardThemeManager.shared

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let onTaskTap: (TaskDefinition) -> Void

    let onToggleComplete: (TaskDefinition) -> Void

    let onTimelineAnchorTap: (TimelineAnchorItem) -> Void

    let onDeleteTask: (TaskDefinition) -> Void

    let onRescheduleTask: (TaskDefinition) -> Void

    let onReorderCustomProjects: ([UUID]) -> Void

    let onAddTask: (Date?) -> Void

    let onOpenChat: () -> Void

    let onOpenProjectCreator: () -> Void

    let onOpenSettings: () -> Void

    let onOpenWeeklyPlanner: () -> Void

    let onOpenWeeklyReview: () -> Void

    let onRetryWeeklySummary: () -> Void

    let onOpenAnalytics: (String, Bool) -> Void

    let onCloseAnalytics: (String) -> Void

    let onOpenSearch: (String) -> Void

    let onCloseSearch: (String) -> Void

    let onReturnToTasks: (String) -> Void

    let onTaskListScrollChromeStateChange: (HomeScrollChromeState) -> Void

    let onStartFocus: (TaskDefinition) -> Void

    let onRequestCalendarPermission: () -> Void

    let onOpenCalendarChooser: () -> Void

    let onOpenCalendarSchedule: () -> Void

    let onRetryCalendarContext: () -> Void

    let onPerformChatDayTaskAction: EvaDayTaskActionHandler

    let onPerformChatDayHabitAction: EvaDayHabitActionHandler

    let onChatPromptFocusChange: (Bool) -> Void

    @State var showAdvancedFilters = false

    @State var showDatePicker = false

    @State var draftDate = Date()

    @State var showDailyReflectPlan = false

    @State var dailyReflectPlanViewModel: DailyReflectPlanViewModel?

    @State var activeNextActionFocusSession: FocusSessionDefinition?

    @State var showNextActionFocusTimer = false

    @State var nextActionFocusSummaryResult: FocusSessionResult?

    @State var showNextActionFocusSummary = false

    @State var activeFocusTimerSource = "next_action_module_15min_focus"

    @State var isNextActionFocusRequestInFlight = false

    @State var isNextActionFocusEnding = false

    @State var sunriseHintOffset: CGFloat = 0

    @State var hintAnimationTask: _Concurrency.Task<Void, Never>?

    @State var lastHintTriggerAt: Date?

    @State var isHomeVisible = false

    @State var snackbar: SnackbarData?

    @State var lastSearchQueryTelemetryAt: Date?

    @FocusState var isSearchFieldFocused: Bool

    @State var hasAutoFocusedSearchField = false

    @State var searchDraftQuery = ""

    @State var pendingSearchCommitTask: Task<Void, Never>?

    @State var hasMountedSearchSurface = false

    @State var hasMountedAnalyticsSurface = false

    @State var chatNavigationChromeState = EvaChatNavigationChromeState.empty

    @State var expandedAgendaTailItemIDs = Set<String>()

    @State var selectedHomeCalendarEventDetail: HomeCalendarEventDetailSelection?

    @State var suppressNextCalendarScheduleOpen = false

    @State var showHabitBoardPresented = false

    @State var showHabitLibraryPresented = false

    @State var selectedHomeHabitRow: HabitLibraryRow?

    @State var showHomeAddHabitPresented = false

    @StateObject var homeHabitComposerViewModel = PresentationDependencyContainer.shared.makeNewAddHabitViewModel()

    @State var hasPresentedUITestHabitBoard = false

    @State var isSchedulingUITestHabitBoardPresentation = false

    @State var passiveTrackingRailViewportWidth: CGFloat = 0

    @State var pendingFocusPromotionTask: TaskDefinition?

    @State var focusReplacementOptions: [TaskDefinition] = []

    @State var activeHabitMutationInterval: LifeBoardPerformanceInterval?

    @State var activeLastCellTapInterval: LifeBoardPerformanceInterval?

    @State var measuredTimelineHeaderHeight: CGFloat = 0

    @State var measuredCalendarCardHeight: CGFloat = 0

    @State var measuredWeekBackdropHeight: CGFloat = 0

    @State var measuredPassiveTrackingRailHeight: CGFloat = 0

    @State var measuredNeedsReplanTrayHeight: CGFloat = 0

    @State var committedDaySwipeDirection: HomeDayNavigationDirection?

    @State var isDaySwipeTracingActive = false

    @State var leadingDaySunriseSwipeData = SunriseDaySwipeData(side: .leading)

    @State var trailingDaySunriseSwipeData = SunriseDaySwipeData(side: .trailing)

    @State var topDaySunriseSwipeSide: SunriseDaySwipeSide = .trailing

    @State var activeDaySunriseSwipeSide: SunriseDaySwipeSide?

    @State var isDaySunriseSwipeChromeVisible = true

    @State var timelineScrollChromeStateTracker = HomeScrollChromeStateTracker()

    @State var lastTimelineScrollOffsetY: CGFloat?

    @StateObject var timelineViewModel = HomeTimelineViewModel()

    @StateObject var timelineSnapshotRenderCache = HomeTimelineSnapshotRenderCache()

    static let daySunriseSwipeCoordinateSpaceName = "home.daySunriseSwipe"

    static let sunriseHintLaunchDelay: TimeInterval = 0.10

    static let sunriseHintPeekDistance: CGFloat = 24

    static let sunriseHintPeekDuration: TimeInterval = 0.10

    static let sunriseHintReturnResponse: TimeInterval = 0.22

    static let sunriseHintReturnDampingFraction: CGFloat = 0.86

    static let sunriseHintSettleDuration: TimeInterval = 0.16

    static let launchArguments = Set(ProcessInfo.processInfo.arguments)

    static let searchCommitDebounceNanoseconds: UInt64 = 250_000_000

    static let nextActionFocusDurationSeconds = 15 * 60

    var body: some View {
        let _ = themeManager.currentTheme.index

        homeScreenBody
    }

    func loadTaskIDFromDrop(
        providers: [NSItemProvider],
        completion: @escaping @MainActor @Sendable (UUID?) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            completion(nil)
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            let rawValue = (object as? NSString)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let taskID = rawValue.flatMap(UUID.init(uuidString:))
            Task { @MainActor in
                completion(taskID)
            }
        }
        return true
    }

    /// Executes focusScopeMetadata.
}
