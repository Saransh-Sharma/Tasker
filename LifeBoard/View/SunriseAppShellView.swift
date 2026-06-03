//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

private extension TimeInterval {
    var nanoseconds: UInt64 {
        UInt64((self * 1_000_000_000).rounded())
    }
}


private enum HomePerformanceSignposts {
    private static let habitMutationIntervalName: StaticString = "HomeHabitMutationLatency"
    private static let lastCellTapIntervalName: StaticString = "HomeHabitLastCellTap"
    private static let habitsSectionRenderEventName: StaticString = "home.habitsSection.render"

    // Points-of-interest signposts emit automatically while profiling with
    // Instruments. The verbose performance log still honors the explicit
    // LifeBoard performance flags.

    static func lastCellTapAccepted() {
        LifeBoardPerformanceTrace.event("home.lastCellTap.accepted")
    }

    static func beginLastCellTap() -> LifeBoardPerformanceInterval {
        LifeBoardPerformanceTrace.event("home.lastCellTap.begin")
        return LifeBoardPerformanceTrace.begin(lastCellTapIntervalName)
    }

    static func endLastCellTap(_ interval: LifeBoardPerformanceInterval?) {
        guard let interval else { return }
        LifeBoardPerformanceTrace.end(interval)
        LifeBoardPerformanceTrace.event("home.lastCellTap.end")
    }

    static func beginHabitMutation() -> LifeBoardPerformanceInterval {
        LifeBoardPerformanceTrace.event("home.habitMutation.begin")
        return LifeBoardPerformanceTrace.begin(habitMutationIntervalName)
    }

    static func endHabitMutation(_ interval: LifeBoardPerformanceInterval?) {
        guard let interval else { return }
        LifeBoardPerformanceTrace.end(interval)
        LifeBoardPerformanceTrace.event("home.habitMutation.end")
    }

    static func openDetailTap() {
        LifeBoardPerformanceTrace.event("home.openDetail.tap")
    }

    static func habitsSectionRendered(rowCount: Int) {
        LifeBoardPerformanceTrace.event(habitsSectionRenderEventName, value: rowCount)
    }
}

private struct HomeHabitSectionCardHost: View, Equatable {
    let title: String
    let summaryLine: String
    let rows: [HomeHabitRow]
    let accessibilityIdentifier: String
    let onOpenBoard: () -> Void
    let onPrimaryAction: (HomeHabitRow) -> Void
    let onSecondaryAction: (HomeHabitRow) -> Void
    let onRowAction: (HomeHabitRow) -> Void
    let onLastCellAction: (HomeHabitRow) -> Void
    let onOpenHabit: (HomeHabitRow) -> Void
    let showsAddHabitCTA: Bool
    let onAddHabit: (() -> Void)?

    nonisolated static func == (lhs: HomeHabitSectionCardHost, rhs: HomeHabitSectionCardHost) -> Bool {
        lhs.title == rhs.title
            && lhs.summaryLine == rhs.summaryLine
            && lhs.rows == rhs.rows
            && lhs.accessibilityIdentifier == rhs.accessibilityIdentifier
            && lhs.showsAddHabitCTA == rhs.showsAddHabitCTA
    }

    var body: some View {
        let _ = HomePerformanceSignposts.habitsSectionRendered(rowCount: rows.count)
        return HabitHomeSectionCard(
            title: title,
            summaryLine: summaryLine,
            rows: rows,
            onOpenBoard: onOpenBoard,
            onPrimaryAction: onPrimaryAction,
            onSecondaryAction: onSecondaryAction,
            onRowAction: onRowAction,
            onLastCellAction: onLastCellAction,
            onOpenHabit: onOpenHabit,
            onAddHabit: showsAddHabitCTA ? onAddHabit : nil
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct HomeCalendarEventDetailSelection: Identifiable, Equatable {
    let eventID: String
    let selectedDate: Date
    let allowsTimelineHide: Bool

    var id: String {
        "\(eventID):\(HomeTimelineHiddenCalendarEventKey.dayStamp(for: selectedDate)):\(allowsTimelineHide)"
    }
}

private struct HomeCalendarEventDetailSheet: View {
    let selection: HomeCalendarEventDetailSelection
    let onDismiss: () -> Void
    let onHideFromTimeline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Label(String(localized: "Close"), systemImage: "xmark")
                        .labelStyle(.titleAndIcon)
                        .font(.lifeboard(.body).weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.lifeboard.textPrimary)
                .background(Color.lifeboard.surfaceSecondary.opacity(0.82), in: Capsule())
                .accessibilityIdentifier("schedule.detail.close")

                Spacer(minLength: 12)

                if selection.allowsTimelineHide {
                    Button(action: onHideFromTimeline) {
                        Label(String(localized: "Hide"), systemImage: "eye.slash")
                            .labelStyle(.titleAndIcon)
                            .font(.lifeboard(.body).weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lifeboard.statusDanger)
                    .background(Color.lifeboard.statusDanger.opacity(0.12), in: Capsule())
                    .accessibilityLabel(String(localized: "Hide from Timeline"))
                    .accessibilityHint(String(localized: "Hides this event from the Home timeline for this day."))
                    .accessibilityIdentifier("schedule.detail.hideFromTimeline")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color.lifeboard(.bgElevated))

            Divider()

            EventKitEventDetailView(
                eventID: selection.eventID,
                onDismiss: onDismiss,
                showsCloseButton: false,
                onHideFromTimeline: nil
            )
        }
        .background(Color.lifeboard(.bgElevated))
    }
}

private struct SunriseHomeDatePickerPopover: View {
    @Binding var draftDate: Date
    let selectedDate: Date
    let onToday: () -> Void
    let onCancel: () -> Void
    let onApply: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            HStack(spacing: LBSpacingTokens.md) {
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LBColorTokens.violetDeep)
                    .frame(width: 38, height: 38)
                    .background(LBColorTokens.violetSoft.opacity(0.86), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose day")
                        .font(LBTypographyTokens.cardTitle)
                        .foregroundStyle(LBColorTokens.navy)
                    Text(Self.relativeDateText(for: draftDate, selectedDate: selectedDate))
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(LBColorTokens.navyMuted)
                }

                Spacer(minLength: LBSpacingTokens.sm)

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .frame(width: 32, height: 32)
                        .background(LBColorTokens.glassStrong, in: Circle())
                        .overlay { Circle().stroke(LBColorTokens.glassBorder, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close date picker")
            }

            DatePicker(
                "Select date",
                selection: $draftDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(LBColorTokens.violetDeep)
            .accessibilityIdentifier("home.datePicker.calendar")

            HStack(spacing: LBSpacingTokens.sm) {
                dateActionButton(
                    title: "Today",
                    systemImage: "sun.max",
                    isPrimary: false,
                    action: onToday
                )
                dateActionButton(
                    title: "Cancel",
                    systemImage: "xmark",
                    isPrimary: false,
                    action: onCancel
                )
                dateActionButton(
                    title: "Apply",
                    systemImage: "checkmark",
                    isPrimary: true,
                    action: onApply
                )
            }
        }
        .padding(LBSpacingTokens.lg)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 420 : 366)
        .background { popoverSurface }
        .shadow(color: LBColorTokens.navy.opacity(0.16), radius: 28, x: 0, y: 16)
        .accessibilityIdentifier("home.datePicker")
    }

    private var popoverSurface: some View {
        let shape = RoundedRectangle(cornerRadius: LBRadiusTokens.largeCard, style: .continuous)
        return shape
            .fill(.ultraThinMaterial)
            .overlay { shape.fill(LBColorTokens.glassStrong.opacity(0.88)) }
            .overlay { shape.stroke(LBColorTokens.glassBorder, lineWidth: 1) }
    }

    private func dateActionButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(LBTypographyTokens.meta.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .foregroundStyle(isPrimary ? Color.white : LBColorTokens.navy)
                .frame(maxWidth: .infinity, minHeight: 38)
                .padding(.horizontal, LBSpacingTokens.sm)
                .background {
                    Capsule()
                        .fill(isPrimary ? LBColorTokens.violetDeep : LBColorTokens.glass)
                        .overlay {
                            Capsule()
                                .stroke(isPrimary ? LBColorTokens.violet.opacity(0.35) : LBColorTokens.glassBorder, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    private static func relativeDateText(for draftDate: Date, selectedDate: Date) -> String {
        let calendar = Calendar.current
        let selectedPrefix = calendar.isDate(draftDate, inSameDayAs: selectedDate) ? "Selected" : "Preview"
        if calendar.isDateInToday(draftDate) {
            return "\(selectedPrefix) today"
        }
        let formatted = draftDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return "\(selectedPrefix) \(formatted)"
    }
}

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
    @ObservedObject private var themeManager = LifeBoardThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    @State private var showAdvancedFilters = false
    @State private var showDatePicker = false
    @State private var draftDate = Date()
    @State private var showDailyReflectPlan = false
    @State private var dailyReflectPlanViewModel: DailyReflectPlanViewModel?
    @State private var activeNextActionFocusSession: FocusSessionDefinition?
    @State private var showNextActionFocusTimer = false
    @State private var nextActionFocusSummaryResult: FocusSessionResult?
    @State private var showNextActionFocusSummary = false
    @State private var activeFocusTimerSource = "next_action_module_15min_focus"
    @State private var isNextActionFocusRequestInFlight = false
    @State private var isNextActionFocusEnding = false
    @State private var sunriseHintOffset: CGFloat = 0
    @State private var hintAnimationTask: _Concurrency.Task<Void, Never>?
    @State private var lastHintTriggerAt: Date?
    @State private var isHomeVisible = false
    @State private var snackbar: SnackbarData?
    @State private var lastSearchQueryTelemetryAt: Date?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var hasAutoFocusedSearchField = false
    @State private var searchDraftQuery = ""
    @State private var pendingSearchCommitTask: Task<Void, Never>?
    @State private var hasMountedSearchSurface = false
    @State private var hasMountedAnalyticsSurface = false
    @State private var chatNavigationChromeState = EvaChatNavigationChromeState.empty
    @State private var expandedAgendaTailItemIDs = Set<String>()
    @State private var selectedHomeCalendarEventDetail: HomeCalendarEventDetailSelection?
    @State private var suppressNextCalendarScheduleOpen = false
    @State private var showHabitBoardPresented = false
    @State private var showHabitLibraryPresented = false
    @State private var selectedHomeHabitRow: HabitLibraryRow?
    @State private var showHomeAddHabitPresented = false
    @StateObject private var homeHabitComposerViewModel = PresentationDependencyContainer.shared.makeNewAddHabitViewModel()
    @State private var hasPresentedUITestHabitBoard = false
    @State private var isSchedulingUITestHabitBoardPresentation = false
    @State private var passiveTrackingRailViewportWidth: CGFloat = 0
    @State private var pendingFocusPromotionTask: TaskDefinition?
    @State private var focusReplacementOptions: [TaskDefinition] = []
    @State private var activeHabitMutationInterval: LifeBoardPerformanceInterval?
    @State private var activeLastCellTapInterval: LifeBoardPerformanceInterval?
    @State private var measuredTimelineHeaderHeight: CGFloat = 0
    @State private var measuredCalendarCardHeight: CGFloat = 0
    @State private var measuredWeekBackdropHeight: CGFloat = 0
    @State private var measuredPassiveTrackingRailHeight: CGFloat = 0
    @State private var measuredNeedsReplanTrayHeight: CGFloat = 0
    @State private var committedDaySwipeDirection: HomeDayNavigationDirection?
    @State private var isDaySwipeTracingActive = false
    @State private var leadingDaySunriseSwipeData = SunriseDaySwipeData(side: .leading)
    @State private var trailingDaySunriseSwipeData = SunriseDaySwipeData(side: .trailing)
    @State private var topDaySunriseSwipeSide: SunriseDaySwipeSide = .trailing
    @State private var activeDaySunriseSwipeSide: SunriseDaySwipeSide?
    @State private var isDaySunriseSwipeChromeVisible = true
    @State private var timelineScrollChromeStateTracker = HomeScrollChromeStateTracker()
    @State private var lastTimelineScrollOffsetY: CGFloat?
    @StateObject private var timelineViewModel = HomeTimelineViewModel()
    @StateObject private var timelineSnapshotRenderCache = HomeTimelineSnapshotRenderCache()
    private static let daySunriseSwipeCoordinateSpaceName = "home.daySunriseSwipe"
    private static let sunriseHintLaunchDelay: TimeInterval = 0.10
    private static let sunriseHintPeekDistance: CGFloat = 24
    private static let sunriseHintPeekDuration: TimeInterval = 0.10
    private static let sunriseHintReturnResponse: TimeInterval = 0.22
    private static let sunriseHintReturnDampingFraction: CGFloat = 0.86
    private static let sunriseHintSettleDuration: TimeInterval = 0.16
    private static let launchArguments = Set(ProcessInfo.processInfo.arguments)
    private static let searchCommitDebounceNanoseconds: UInt64 = 250_000_000
    private static let nextActionFocusDurationSeconds = 15 * 60

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).corner }
    private var forcedFaceValue: HomeSunriseFace? { forcedFace?.wrappedValue }
    private var chromeSnapshot: HomeChromeSnapshot { chromeStore.snapshot }
    private var tasksSnapshot: HomeTasksSnapshot { tasksStore.snapshot }
    private var habitsSnapshot: HomeHabitsSnapshot { habitsStore.snapshot }
    private var calendarSnapshot: HomeCalendarSnapshot { calendarStore.snapshot }
    private var timelineRenderState: HomeTimelineRenderState { timelineStore.state }
    private var overlaySnapshot: HomeOverlaySnapshot { overlayStore.snapshot }
    private var activeFace: HomeSunriseFace { faceCoordinator.activeFace }
    private var shellPhase: HomeShellPhase { faceCoordinator.shellPhase }
    private var analyticsSurfaceState: HomeAnalyticsSurfaceState { faceCoordinator.analyticsSurfaceState }
    private var searchSurfaceState: HomeSearchSurfaceState { faceCoordinator.searchSurfaceState }
    private var layoutMetrics: HomeLayoutMetrics { faceCoordinator.layoutMetrics }
    private var isUITesting: Bool {
        Self.launchArguments.contains("-UI_TESTING") || Self.launchArguments.contains("-DISABLE_ANIMATIONS")
    }
    private var shouldPresentHabitBoardForUITests: Bool {
        Self.launchArguments.contains("-LIFEBOARD_TEST_PRESENT_HABIT_BOARD")
    }
    private var isSunriseHintAnimationEnabled: Bool {
        Self.launchArguments.contains("-ENABLE_FOREDROP_HINT_ANIMATION")
    }
    private var sunriseAnchorForHint: SunriseAnchor {
        activeFace == .tasks ? timelineViewModel.sunriseAnchor : .fullReveal
    }
    private var isSearchOpen: Bool { activeFace == .search }
    private var isInsightsOpen: Bool { activeFace == .analytics }
    private var isChatOpen: Bool { activeFace == .chat }
    private var shouldAttachSecondaryFaceToTop: Bool { isSearchOpen || isInsightsOpen }
    private var isBackFaceVisible: Bool { activeFace.isBackFace }
    private var isScheduleFaceVisible: Bool { activeFace == .schedule }
    private var isTodayTimelineVisible: Bool {
        activeFace == .tasks && tasksSnapshot.activeQuickView == .today
    }
    private var isTaskFaceVisible: Bool { activeFace == .tasks }
    private var isDaySwipeChromeAvailable: Bool {
        isTaskFaceVisible || isScheduleFaceVisible
    }
    private var isRescueEnabled: Bool { V2FeatureFlags.evaRescueEnabled }
    private var visibleAgendaTailItems: [HomeAgendaTailItem] {
        guard isRescueEnabled else { return [] }
        if tasksSnapshot.agendaTailItems.isEmpty == false {
            return tasksSnapshot.agendaTailItems
        }
        guard tasksSnapshot.activeQuickView == .today else { return [] }
        let rescueRows = tasksSnapshot.overdueTasks
            .filter { isTimelineRescueEligibleTask($0) }
            .map(HomeTodayRow.task)
            .sorted(by: compareTimelineRescueRows(_:_:))
        guard rescueRows.isEmpty == false else { return [] }
        let mode: RescueTailMode = rescueRows.count <= 3 ? .compact : .expanded
        let subtitle = rescueRows.count == 1
            ? "1 task is 2+ weeks overdue"
            : "\(rescueRows.count) tasks are 2+ weeks overdue"
        return [
            .rescue(
                RescueTailState(
                    rows: rescueRows,
                    mode: mode,
                    isInlineExpanded: mode == .expanded,
                    subtitle: subtitle
                )
            )
        ]
    }

    private func isTimelineRescueEligibleTask(_ task: TaskDefinition) -> Bool {
        guard !task.isComplete, let dueDate = task.dueDate else { return false }
        let anchorDay = Calendar.current.startOfDay(for: chromeSnapshot.selectedDate)
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: anchorDay) else {
            return false
        }
        return dueDate < cutoff
    }

    private func compareTimelineRescueRows(_ lhs: HomeTodayRow, _ rhs: HomeTodayRow) -> Bool {
        guard case .task(let leftTask) = lhs, case .task(let rightTask) = rhs else {
            return lhs.id < rhs.id
        }
        let leftDueDate = leftTask.dueDate ?? Date.distantFuture
        let rightDueDate = rightTask.dueDate ?? Date.distantFuture
        if leftDueDate != rightDueDate {
            return leftDueDate < rightDueDate
        }
        if leftTask.priority.scorePoints != rightTask.priority.scorePoints {
            return leftTask.priority.scorePoints > rightTask.priority.scorePoints
        }
        return leftTask.title.localizedStandardCompare(rightTask.title) == .orderedAscending
    }
    private var lifeAreasByID: [UUID: LifeArea] {
        Dictionary(viewModel.lifeAreas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    private var agendaTailExpansionResetKey: String {
        let selectedDay = Calendar.current.startOfDay(for: chromeSnapshot.selectedDate).timeIntervalSince1970
        let compactTailSignature = visibleAgendaTailItems.compactMap { item -> String? in
            switch item {
            case .rescue(let state):
                guard state.mode == .compact else { return nil }
                let rowIDs = state.rows.map(\.id).joined(separator: ",")
                return "\(item.id):\(rowIDs):\(state.subtitle)"
            }
        }.joined(separator: "|")

        return [String(Int(selectedDay)), compactTailSignature, isRescueEnabled ? "1" : "0"].joined(separator: ":")
    }
    private var habitRenderSignature: String {
        let primary = habitsSnapshot.habitHomeSectionState.primaryRows.map { "\($0.id):\($0.state.rawValue)" }.joined(separator: "|")
        let recovery = habitsSnapshot.habitHomeSectionState.recoveryRows.map { "\($0.id):\($0.state.rawValue)" }.joined(separator: "|")
        let quiet = habitsSnapshot.quietTrackingSummaryState.stableRows.map { "\($0.id):\($0.state.rawValue)" }.joined(separator: "|")
        return "\(primary)#\(recovery)#\(quiet)"
    }
    private var timelineLayoutMetrics: HomeSunriseLayoutMetrics {
        HomeSunriseLayoutMetrics(
            calendarExpandedHeight: measuredCalendarCardHeight,
            timelineHeaderHeight: measuredTimelineHeaderHeight,
            weeklyBackdropHeight: measuredWeekBackdropHeight,
            geometryHeight: layoutMetrics.height
        )
    }
    private var timelineSnapshot: HomeTimelineSnapshot {
        let key = HomeTimelineSnapshotRenderCache.Key(
            timelineRevision: timelineRenderState.revision,
            calendarSnapshot: calendarSnapshot,
            selectedDate: chromeSnapshot.selectedDate,
            sunriseAnchor: timelineViewModel.sunriseAnchor
        )
        return timelineSnapshotRenderCache.snapshot(for: key) {
            viewModel.buildTimelineSnapshot(
                calendarSnapshot: calendarSnapshot,
                sunriseAnchor: timelineViewModel.sunriseAnchor
            )
        }
    }
    private var isDaySwipeGestureEnabled: Bool {
        guard isTaskFaceVisible || isScheduleFaceVisible else { return false }
        guard showDatePicker == false, showAdvancedFilters == false else { return false }
        guard overlaySnapshot.replanState.isApplying == false else { return false }
        if case .placement = overlaySnapshot.replanState.phase {
            return false
        }
        return true
    }
    private var isDaySwipeInteractionEnabled: Bool {
        isDaySwipeGestureEnabled && isDaySunriseSwipeChromeVisible
    }
    private var daySwipeAnimation: Animation {
        if reduceMotion || isUITesting {
            return .easeOut(duration: 0.12)
        }
        return .snappy(duration: 0.22)
    }
    private var daySwipeTransition: AnyTransition {
        guard reduceMotion == false, isUITesting == false else {
            return .opacity
        }

        switch committedDaySwipeDirection {
        case .previous:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .next:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case nil:
            return .opacity
        }
    }
    private var passiveTrackingRailFallbackHeight: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 72 : 56
    }
    private var needsReplanTrayFallbackHeight: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 120 : 88
    }
    private var isNeedsReplanTrayVisible: Bool {
        if case .trayVisible = overlaySnapshot.replanState.phase {
            return true
        }
        return false
    }
    private var daySunriseSwipeRestingCenterY: CGFloat {
        guard isScheduleFaceVisible == false else {
            return SunriseDaySwipeData.timelineHandleCenterY
        }
        return SunriseDaySwipeRestingPosition.centerY(
            defaultCenterY: SunriseDaySwipeData.timelineHandleCenterY,
            showsQuietTrackingRail: habitsSnapshot.quietTrackingSummaryState.isVisible,
            measuredQuietTrackingRailHeight: measuredPassiveTrackingRailHeight,
            quietTrackingRailFallbackHeight: passiveTrackingRailFallbackHeight,
            showsNeedsReplanTray: isNeedsReplanTrayVisible,
            measuredNeedsReplanTrayHeight: measuredNeedsReplanTrayHeight,
            needsReplanTrayFallbackHeight: needsReplanTrayFallbackHeight,
            topPadding: spacing.s8,
            interModuleSpacing: spacing.s12,
            buttonRadius: SunriseDaySwipeData.buttonRadius,
            clearance: spacing.s4
        )
    }
    @ViewBuilder
    private var needsReplanFloatingOverlay: some View {
        switch overlaySnapshot.replanState.phase {
        case .card:
            NeedsReplanCardOverlay(
                state: overlaySnapshot.replanState,
                onUndo: { viewModel.undoLastReplanAction() },
                onSkip: { viewModel.skipCurrentReplanCandidate() },
                onMoveToInbox: { viewModel.moveCurrentReplanCandidateToInbox() },
                onReschedule: { viewModel.beginCurrentReplanPlacement() },
                onCheckOff: { viewModel.checkOffCurrentReplanCandidate() },
                onDelete: { viewModel.deleteCurrentReplanCandidate() },
                onClearError: { viewModel.clearReplanError() },
                onFeedback: { message in
                    snackbar = SnackbarData(message: message, autoDismissSeconds: 2)
                }
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, layoutMetrics.safeAreaBottom + spacing.s20)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .summary:
            NeedsReplanSummaryOverlay(
                state: overlaySnapshot.replanState,
                onReviewSkipped: { viewModel.reviewSkippedReplanCandidates() },
                onViewToday: {
                    timelineViewModel.syncSelectedDate(Date())
                    viewModel.returnToToday(source: .backToToday)
                    viewModel.dismissNeedsReplanSessionUI()
                },
                onDone: { viewModel.dismissNeedsReplanSessionUI() }
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, layoutMetrics.safeAreaBottom + spacing.s20)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        default:
            EmptyView()
        }
    }
    private var sunriseInteractiveOffset: CGFloat {
        guard isTodayTimelineVisible else { return 0 }
        return timelineViewModel.interactiveOffset(metrics: timelineLayoutMetrics)
    }
    private var secondaryFaceTopContentInset: CGFloat {
        max(0, layoutMetrics.safeAreaTop + spacing.s8 - 8)
    }
    private var sunriseSurfaceCornerRadius: CGFloat {
        shouldAttachSecondaryFaceToTop ? 0 : corner.modal
    }
    private var sunriseFlipAnimation: Animation {
        let duration: TimeInterval
        if reduceMotion || isUITesting {
            duration = 0.2
        } else if layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled {
            duration = 0.12
        } else if layoutClass == .phone {
            duration = 0.16
        } else {
            duration = 0.42
        }
        return .easeInOut(duration: duration)
    }

    private var sunriseDatePickerDropdown: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    showDatePicker = false
                }

            SunriseHomeDatePickerPopover(
                draftDate: $draftDate,
                selectedDate: chromeSnapshot.selectedDate,
                onToday: {
                    draftDate = Date()
                    viewModel.returnToToday(source: .datePicker)
                    showDatePicker = false
                },
                onCancel: {
                    showDatePicker = false
                },
                onApply: {
                    viewModel.selectDate(draftDate, source: .datePicker)
                    showDatePicker = false
                }
            )
            .padding(.horizontal, LBSpacingTokens.screenMargin)
            .padding(.top, sunriseDatePickerTopPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("home.sunrise.datePicker.backdrop")
    }

    private var sunriseDatePickerTopPadding: CGFloat {
        let safeHeaderTop = max(layoutMetrics.safeAreaTop, 54)
        return safeHeaderTop + (dynamicTypeSize.isAccessibilitySize ? 204 : 158)
    }

    @ViewBuilder
    private var rescueLauncherOverlay: some View {
        switch overlaySnapshot.rescueLauncherState {
        case .loading:
            OverdueRescueLauncherOverlayView(
                title: "Preparing rescue",
                message: "Finding tasks that still need a decision.",
                showsProgress: true,
                primaryTitle: nil,
                secondaryTitle: nil,
                onPrimary: nil,
                onSecondary: nil
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .zIndex(45)
        case .failed(let message):
            OverdueRescueLauncherOverlayView(
                title: "Rescue could not start",
                message: message,
                showsProgress: false,
                primaryTitle: "Try again",
                secondaryTitle: "Dismiss",
                onPrimary: {
                    viewModel.openRescue()
                },
                onSecondary: {
                    viewModel.setEvaRescuePresented(false)
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .zIndex(45)
        case .idle, .ready:
            EmptyView()
        }
    }

    @ViewBuilder
    private var rescueDeckOverlay: some View {
        if overlaySnapshot.rescuePresented {
            EvaOverdueRescueSheetV2(
                plan: overlaySnapshot.rescuePlan,
                tasksByID: rescueTasksByID,
                projectsByID: tasksSnapshot.projectsByID,
                referenceDate: chromeSnapshot.selectedDate,
                lastBatchRunID: overlaySnapshot.lastBatchRunID,
                bottomInset: layoutMetrics.taskListBottomInset,
                onClose: {
                    viewModel.setEvaRescuePresented(false)
                },
                onExit: {
                    viewModel.setEvaRescuePresented(false)
                },
                onUpdate: { request, completion in
                    Task { @MainActor in
                        viewModel.updateTask(taskID: request.id, request: request, completion: completion)
                    }
                },
                onDelete: { taskID, completion in
                    Task { @MainActor in
                        viewModel.deleteTask(taskID: taskID, scope: .single, completion: completion)
                    }
                },
                onRestore: { task, completion in
                    Task { @MainActor in
                        viewModel.restoreDeletedTaskSnapshot(task, completion: completion)
                    }
                },
                onApply: { mutations, completion in
                    Task { @MainActor in
                        viewModel.applyRescuePlan(mutations: mutations, completion: completion)
                    }
                },
                onUndo: { completion in
                    Task { @MainActor in
                        viewModel.undoRescueRun(completion: completion)
                    }
                },
                onTrack: { action, metadata in
                    viewModel.trackHomeInteraction(action: action, metadata: metadata)
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .zIndex(46)
            .accessibilityIdentifier("home.rescue.overlay")
        }
    }

    var body: some View {
        let _ = themeManager.currentTheme.index

        homeScreenBody
    }

    private var homeScreenBody: some View {
        let baseHomeScreen = ZStack {
            ZStack(alignment: .top) {
                if activeFace == .tasks {
                    SunriseHomeScreen(
                        chrome: chromeSnapshot,
                        tasks: tasksSnapshot,
                        habits: habitsSnapshot,
                        calendar: calendarSnapshot,
                        timeline: timelineSnapshot,
                        bottomInset: layoutMetrics.taskListBottomInset,
                        safeAreaTop: layoutMetrics.safeAreaTop,
                        isShellInteractive: shellPhase == .interactive,
                        isDaySwipeEnabled: isDaySwipeChromeAvailable,
                        isDaySwipeInteractive: isDaySwipeGestureEnabled,
                        onSelectQuickView: { viewModel.setQuickView($0) },
                        onShowDatePicker: {
                            draftDate = chromeSnapshot.selectedDate
                            showDatePicker = true
                        },
                        onShiftSelectedDay: { dayOffset, source in
                            guard dayOffset != 0 else { return }
                            if source == .datePicker {
                                shiftSunriseSelectedDay(by: dayOffset)
                            } else {
                                viewModel.shiftSelectedDay(byDays: dayOffset, source: source)
                            }
                        },
                        onShowAdvancedFilters: {
                            showAdvancedFilters = true
                        },
                        onOpenSettings: {
                            onOpenSettings()
                        },
                        onOpenSearch: {
                            openSearch(source: "sunrise_home")
                        },
                        onOpenChat: {
                            onOpenChat()
                        },
                        onOpenHabitBoard: {
                            showHabitBoardPresented = true
                        },
                        onCycleHabit: { habit in
                            performHabitRowAction(habit, source: "sunrise_habits_row_tap")
                        },
                        onAddHabit: presentHomeAddHabitComposer,
                        onAddTask: onAddTask,
                        onRequestCalendarPermission: onRequestCalendarPermission,
                        onOpenCalendarChooser: onOpenCalendarChooser,
                        onRetryCalendar: onRetryCalendarContext,
                        onTimelineItemTap: { item in
                            if let eventID = item.eventID {
                                handleHomeCalendarEventSelection(eventID: eventID, allowsTimelineHide: true)
                                return
                            }
                            if let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) {
                                onTaskTap(task)
                            }
                        },
                        onTimelineItemToggleComplete: { item in
                            guard let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) else { return }
                            trackTaskToggle(task, source: "sunrise_timeline")
                            onToggleComplete(task)
                        },
                        onAnchorTap: onTimelineAnchorTap,
                        onScrollStateChange: { state in
                            updateDaySunriseSwipeChromeVisibility(for: state)
                            onTaskListScrollChromeStateChange(state)
                        }
                    )
                } else if activeFace == .schedule {
                    sunriseScheduleSurface()
                } else {
                    Color.lifeboard.bgCanvas
                        .ignoresSafeArea()

                    if shouldAttachSecondaryFaceToTop {
                        ZStack(alignment: .top) {
                            backdropLayer()

                            sunriseLayer(taskListBottomInset: layoutMetrics.taskListBottomInset)
                                .offset(y: sunriseHintOffset + sunriseInteractiveOffset)
                                .animation(sunriseFlipAnimation, value: activeFace)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: .top)
                    } else {
                        VStack(spacing: 0) {
                            topNavigationBar()
                                .padding(.top, layoutMetrics.safeAreaTop + spacing.s8)
                                .accessibilityIdentifier("home.topNav.container")

                            ZStack(alignment: .top) {
                                backdropLayer()

                                sunriseLayer(taskListBottomInset: layoutMetrics.taskListBottomInset)
                                    .offset(y: sunriseHintOffset + sunriseInteractiveOffset)
                                    .animation(sunriseFlipAnimation, value: activeFace)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                    }
                }
            }

        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityIdentifier("home.view")
        .lifeboardSnackbar($snackbar)
        .overlay(alignment: .bottom) {
            needsReplanFloatingOverlay
        }
        .overlay(alignment: .topLeading) {
            if shouldShowHomeDebugCountsMarker {
                Text(homeDebugCountsValue)
                    .font(.caption2)
                    .foregroundStyle(Color.lifeboard.textPrimary.opacity(0.01))
                    .lineLimit(1)
                    .frame(width: 240, height: 24, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Home debug counts")
                    .accessibilityValue(homeDebugCountsValue)
                    .accessibilityIdentifier("home.debug.counts")
            }
        }
        .overlay(alignment: .topTrailing) {
            rootTimelineRescueLauncher
        }
        .overlay(alignment: .center) {
            rescueLauncherOverlay
        }
        .overlay {
            rescueDeckOverlay
        }
        .overlay(alignment: .top) {
            if showDatePicker {
                sunriseDatePickerDropdown
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .animation(.snappy(duration: reduceMotion || isUITesting ? 0.01 : 0.24), value: showDatePicker)
        .onPreferenceChange(TimelineHeaderHeightPreferenceKey.self) { measuredTimelineHeaderHeight = $0 }
        .onPreferenceChange(TimelineCalendarCardHeightPreferenceKey.self) { measuredCalendarCardHeight = $0 }
        .onPreferenceChange(TimelineBackdropWeekHeightPreferenceKey.self) { measuredWeekBackdropHeight = $0 }
        .onChange(of: daySunriseSwipeRestingCenterY) { _, newValue in
            resetIdleDaySunriseSwipeHandles(restingCenterY: newValue)
        }
        .onChange(of: isTodayTimelineVisible) { _, isVisible in
            guard isVisible else { return }
            resetDaySunriseSwipeChromeVisibility()
        }
        .onChange(of: isScheduleFaceVisible) { _, isVisible in
            guard isVisible else { return }
            resetDaySunriseSwipeChromeVisibility()
            resetIdleDaySunriseSwipeHandles(restingCenterY: daySunriseSwipeRestingCenterY)
        }
        .onChange(of: habitRenderSignature) { _, _ in
            HomePerformanceSignposts.endHabitMutation(activeHabitMutationInterval)
            activeHabitMutationInterval = nil
            HomePerformanceSignposts.endLastCellTap(activeLastCellTapInterval)
            activeLastCellTapInterval = nil
        }
        .confirmationDialog(
            "Replace a Focus Now item",
            isPresented: Binding(
                get: { pendingFocusPromotionTask != nil && focusReplacementOptions.isEmpty == false },
                set: { isPresented in
                    if !isPresented {
                        clearPendingFocusReplacement()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            ForEach(focusReplacementOptions, id: \.id) { focusTask in
                Button("Replace \(focusTask.title)") {
                    if let promotedTask = pendingFocusPromotionTask {
                        replaceFocusTask(promotedTask, replacing: focusTask, source: "today_agenda_replace")
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                clearPendingFocusReplacement()
            }
        } message: {
            Text("Focus Now already has 3 items. Choose which one to swap out.")
        }
        .fullScreenCover(isPresented: $showNextActionFocusTimer, onDismiss: {
            if isNextActionFocusEnding == false {
                activeNextActionFocusSession = nil
            }
        }) {
            if let session = activeNextActionFocusSession {
                SunriseFocusTimerView(
                    taskTitle: resolveTaskForFocusSession(taskID: session.taskID)?.title,
                    taskPriority: resolveTaskForFocusSession(taskID: session.taskID)?.priority.displayName,
                    targetDurationSeconds: session.targetDurationSeconds,
                    onComplete: { _ in
                        finishNextActionFocusSession(sessionID: session.id, source: activeFocusTimerSource)
                    },
                    onCancel: {
                        finishNextActionFocusSession(sessionID: session.id, source: "\(activeFocusTimerSource)_cancel")
                    }
                )
            } else {
                Color.clear
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showNextActionFocusSummary, onDismiss: {
            nextActionFocusSummaryResult = nil
        }) {
            if let result = nextActionFocusSummaryResult {
                SunriseFocusSessionSummaryView(
                    durationSeconds: result.session.durationSeconds,
                    xpAwarded: result.xpResult?.awardedXP ?? result.session.xpAwarded,
                    dailyXPSoFar: result.xpResult?.dailyXPSoFar ?? viewModel.dailyScore,
                    onDismiss: {
                        dismissNextActionFocusSummary()
                    },
                    onContinueMomentum: {
                        viewModel.setQuickView(.today)
                        dismissNextActionFocusSummary()
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAdvancedFilters) {
            SunriseAdvancedFilterSheetView(
                initialFilter: viewModel.activeFilterState.advancedFilter,
                initialShowCompletedInline: viewModel.activeFilterState.showCompletedInline,
                savedViews: chromeSnapshot.savedHomeViews,
                activeSavedViewID: viewModel.activeFilterState.selectedSavedViewID,
                onApply: { filter, showCompletedInline in
                    viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                },
                onClear: {
                    viewModel.applyAdvancedFilter(nil, showCompletedInline: false)
                    viewModel.clearProjectFilters()
                    viewModel.setQuickView(.today)
                },
                onSaveNamedView: { filter, showCompletedInline, name in
                    viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                    viewModel.saveCurrentFilterAsView(name: name)
                },
                onApplySavedView: { id in
                    viewModel.applySavedView(id: id)
                },
                onDeleteSavedView: { id in
                    viewModel.deleteSavedView(id: id)
                }
            )
        }
        .sheet(item: $selectedHomeCalendarEventDetail) { selection in
            HomeCalendarEventDetailSheet(
                selection: selection,
                onDismiss: {
                    selectedHomeCalendarEventDetail = nil
                },
                onHideFromTimeline: {
                    viewModel.hideCalendarEventFromTimeline(
                        eventID: selection.eventID,
                        on: selection.selectedDate
                    )
                    selectedHomeCalendarEventDetail = nil
                    snackbar = SnackbarData(message: "Hidden from Home timeline for this day.", autoDismissSeconds: 2)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.lifeboard(.bgElevated))
        }
        .onAppear {
            if let forcedFaceValue {
                setActiveFace(forcedFaceValue, animated: false)
            }
            isHomeVisible = true
            timelineViewModel.syncSelectedDate(viewModel.selectedDate)
            hasAutoFocusedSearchField = false
            searchDraftQuery = searchState.query
            hasMountedSearchSurface = activeFace == .search
            hasMountedAnalyticsSurface = activeFace == .analytics
            triggerSunriseHintIfEligible()
            presentHabitBoardIfRequestedForUITests()
        }
        .onChange(of: habitRenderSignature) { _, _ in
            presentHabitBoardIfRequestedForUITests()
        }
        .onDisappear {
            HomePerformanceSignposts.endHabitMutation(activeHabitMutationInterval)
            activeHabitMutationInterval = nil
            HomePerformanceSignposts.endLastCellTap(activeLastCellTapInterval)
            activeLastCellTapInterval = nil
            isHomeVisible = false
            cancelSunriseHintAnimation()
            cancelPendingSearchCommit()
            searchState.deactivate()
            isSearchFieldFocused = false
        }
        .overlay(alignment: .topTrailing) {
            if shouldPresentHabitBoardForUITests {
                Button {
                    showHabitBoardPresented = true
                } label: {
                    Text("Board")
                        .font(.lifeboard(.caption2).weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, layoutMetrics.safeAreaTop + spacing.s12)
                .padding(.trailing, spacing.s8)
                .contentShape(Rectangle())
                .accessibilityIdentifier("home.habits.openBoard")
                .accessibilityLabel("Open Habit Board")
                .opacity(0.16)
            }
        }

        let routedHomeScreen = AnyView(applyHabitPresentationRouting(to: baseHomeScreen))
        let observedHomeScreen = applyHomeStateObservers(to: routedHomeScreen)

        return observedHomeScreen
        .sheet(isPresented: Binding(
            get: { overlaySnapshot.focusWhyPresented },
            set: { viewModel.setEvaFocusWhyPresented($0) }
        )) {
            SunriseEvaFocusWhySheet(
                focusTasks: tasksSnapshot.focusTasks,
                shuffleCandidates: viewModel.focusWhyShuffleCandidates,
                insightProvider: { taskID in
                    viewModel.evaFocusInsight(for: taskID)
                },
                isStartingFocus: isNextActionFocusRequestInFlight,
                onToggleComplete: { task in
                    trackTaskToggle(task, source: "focus_why_sheet")
                    onToggleComplete(task)
                },
                onStartFocus: { draftTasks, task, durationSeconds in
                    startFocusNowTimer(draftTasks: draftTasks, task: task, durationSeconds: durationSeconds)
                },
                onShuffleCandidates: {
                    refreshFocusWhyShuffleCandidates()
                },
                onReplaceFocusTask: { candidate, replacing in
                    replaceFocusTaskFromWhySheet(candidate, replacing: replacing)
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { overlaySnapshot.replanState.launcherSummary != nil },
            set: { isPresented in
                if isPresented == false,
                   overlaySnapshot.replanState.launcherSummary != nil {
                    viewModel.dismissNeedsReplanLater()
                }
            }
        )) {
            NeedsReplanLauncherSheet(
                summary: overlaySnapshot.replanState.launcherSummary ?? .empty,
                onStart: {
                    if overlaySnapshot.replanState.launcherSummary?.count == 0 {
                        viewModel.dismissNeedsReplanSessionUI()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAddTask(nil)
                        }
                    } else {
                        viewModel.startNeedsReplanSession()
                    }
                },
                onLater: {
                    viewModel.dismissNeedsReplanLater()
                }
            )
        }
        .sheet(item: Binding(
            get: { viewModel.habitRecoveryReflectionPrompt },
            set: { if $0 == nil { viewModel.clearHabitRecoveryReflectionPrompt() } }
        )) { prompt in
            SunriseReflectionNoteComposerView(
                viewModel: SunriseReflectionNoteComposerViewModel(
                    title: "Recovery note",
                    kind: .habitRecovery,
                    linkedHabitID: prompt.habitID,
                    prompt: "What helped \(prompt.habitTitle) recover today?",
                    saveNoteHandler: { note, completion in
                        viewModel.saveReflectionNote(note) { result in
                            Task { @MainActor in
                                completion(result)
                            }
                        }
                    }
                )
            )
        }
        .sheet(isPresented: Binding(
            get: { layoutClass.isPad && showDailyReflectPlan },
            set: { showDailyReflectPlan = $0 }
        ), onDismiss: {
            dailyReflectPlanViewModel = nil
        }) {
            reflectPlanPresentation
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !layoutClass.isPad && showDailyReflectPlan },
            set: { showDailyReflectPlan = $0 }
        ), onDismiss: {
            dailyReflectPlanViewModel = nil
        }) {
            reflectPlanPresentation
        }
    }

    private func applyHomeStateObservers(to content: AnyView) -> AnyView {
        let withActiveFace = AnyView(
            content.onChange(of: activeFace) { _, newValue in
                forcedFace?.wrappedValue = newValue
                if newValue == .search {
                    hasMountedSearchSurface = true
                } else if newValue == .analytics {
                    hasMountedAnalyticsSurface = true
                }
                if newValue != .chat {
                    chatNavigationChromeState = .empty
                }
                if newValue != .search {
                    isSearchFieldFocused = false
                    cancelPendingSearchCommit()
                } else {
                    searchDraftQuery = searchState.query
                }
            }
        )

        let withSearchState = AnyView(
            withActiveFace
                .onChange(of: searchSurfaceState) { _, newValue in
                    switch newValue {
                    case .idle:
                        hasAutoFocusedSearchField = false
                        isSearchFieldFocused = false
                        cancelPendingSearchCommit()
                        searchDraftQuery = searchState.query
                        searchState.deactivate()
                    case .presenting, .preparing:
                        isSearchFieldFocused = false
                    case .ready:
                        guard activeFace == .search else { return }
                        hasAutoFocusedSearchField = false
                    }
                }
                .onChange(of: searchState.query) { _, newValue in
                    guard newValue != searchDraftQuery else { return }
                    guard isSearchFieldFocused == false else { return }
                    searchDraftQuery = newValue
                }
                .onChange(of: overlaySnapshot.guidanceState) { _, state in
                    guard state != nil, activeFace != .tasks else { return }
                    setActiveFace(.tasks, animated: true)
                }
                .onChange(of: agendaTailExpansionResetKey) { _, _ in
                    expandedAgendaTailItemIDs.removeAll()
                }
        )

        return AnyView(
            withSearchState
                .onChange(of: forcedFaceValue) { _, newValue in
                    guard let newValue, newValue != activeFace else { return }
                    setActiveFace(newValue, animated: true)
                }
                .onChange(of: chromeSnapshot.selectedDate) { _, newValue in
                    timelineViewModel.syncSelectedDate(newValue)
                }
                .onReceive(overlayStore.$snapshot.map(\.lastXPResult).receive(on: RunLoop.main)) { result in
                    handleXPResult(result)
                }
        )
    }

    private func applyHabitPresentationRouting<Content: View>(to content: Content) -> some View {
        content
            .sheet(isPresented: $showHabitBoardPresented) {
                HabitBoardScreen(
                    viewModel: PresentationDependencyContainer.shared.makeHabitBoardViewModel()
                )
            }
            .sheet(isPresented: $showHabitLibraryPresented) {
                SunriseHabitLibraryView(
                    viewModel: PresentationDependencyContainer.shared.makeNewHabitLibraryViewModel()
                )
            }
            .sheet(isPresented: $showHomeAddHabitPresented) {
                SunriseAddHabitSheetView(
                    viewModel: homeHabitComposerViewModel,
                    onHabitCreated: { _ in
                        showHomeAddHabitPresented = false
                        viewModel.refreshCurrentScopeContent(source: "home_add_habit_created")
                    },
                    onDismissWithoutHabit: {
                        showHomeAddHabitPresented = false
                    }
                )
            }
            .sheet(item: $selectedHomeHabitRow) { row in
                SunriseHabitDetailScreen(
                    viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                    onMutation: {
                        viewModel.refreshCurrentScopeContent(source: "habit_detail_sheet_mutation")
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .lifeboardPresentHabitBoard)) { _ in
                presentHabitBoardFromDeepLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lifeboardPresentHabitLibrary)) { _ in
                presentHabitLibraryFromDeepLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lifeboardPresentHabitDetail)) { notification in
                guard let rawHabitID = notification.userInfo?["habitID"] as? String,
                      let habitID = UUID(uuidString: rawHabitID) else {
                    return
                }
                presentHabitDetailFromDeepLink(habitID: habitID)
            }
            .onChange(of: habitsSnapshot.errorMessage) { _, message in
                guard let message, message.isEmpty == false else { return }
                snackbar = SnackbarData(
                    message: message,
                    actions: [
                        SnackbarAction(title: "Open board") {
                            showHabitBoardPresented = true
                        }
                    ]
                )
                viewModel.clearHabitMutationErrorMessage()
            }
            .onReceive(viewModel.$habitMutationFeedback.compactMap { $0 }) { feedback in
                snackbar = SnackbarData(id: feedback.id, message: feedback.message, autoDismissSeconds: 2)
                playHabitMutationFeedbackHaptic(feedback.haptic)
                viewModel.consumeHabitMutationFeedback(id: feedback.id)
            }
    }

    /// Executes triggerSunriseHintIfEligible.
    private func triggerSunriseHintIfEligible(now: Date = Date()) {
        guard isSunriseHintAnimationEnabled else {
            cancelSunriseHintAnimation()
            return
        }
        if layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled {
            logWarning(
                event: "ipadSunriseHintSuppressed",
                message: "Suppressed decorative sunrise hint animation on iPad"
            )
            return
        }

        let canTrigger = HomeSunriseHintEligibility.canTrigger(
            isHomeVisible: isHomeVisible && shellPhase == .interactive,
            sunriseAnchor: sunriseAnchorForHint,
            reduceMotionEnabled: reduceMotion,
            isUITesting: isUITesting,
            hasRunningAnimation: hintAnimationTask != nil,
            lastTriggerDate: lastHintTriggerAt,
            now: now
        )
        guard canTrigger else { return }

        startSunriseHintAnimation(triggeredAt: now)
    }

    /// Executes startSunriseHintAnimation.
    private func startSunriseHintAnimation(triggeredAt timestamp: Date) {
        cancelSunriseHintAnimation()
        lastHintTriggerAt = timestamp

        hintAnimationTask = _Concurrency.Task { @MainActor in
            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.sunriseHintLaunchDelay.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(.easeOut(duration: Self.sunriseHintPeekDuration)) {
                sunriseHintOffset = Self.sunriseHintPeekDistance
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.sunriseHintPeekDuration.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(
                .spring(
                    response: Self.sunriseHintReturnResponse,
                    dampingFraction: Self.sunriseHintReturnDampingFraction
                )
            ) {
                sunriseHintOffset = 0
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.sunriseHintSettleDuration.nanoseconds)
            } catch {
                return
            }

            hintAnimationTask = nil
        }
    }

    /// Executes cancelSunriseHintAnimation.
    private func cancelSunriseHintAnimation() {
        hintAnimationTask?.cancel()
        hintAnimationTask = nil
        sunriseHintOffset = 0
    }

    private func scheduleSearchCommit(for newValue: String) {
        pendingSearchCommitTask?.cancel()
        let pendingValue = newValue
        pendingSearchCommitTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.searchCommitDebounceNanoseconds)
            } catch {
                pendingSearchCommitTask = nil
                return
            }
            guard !Task.isCancelled else { return }
            commitDraftSearchQuery(pendingValue)
            pendingSearchCommitTask = nil
        }
    }

    private func commitDraftSearchQueryImmediately() {
        cancelPendingSearchCommit()
        commitDraftSearchQuery(searchDraftQuery)
    }

    private func commitDraftSearchQuery(_ newValue: String) {
        let committedQuery = searchState.trimmedQuery
        let nextCommittedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard committedQuery != nextCommittedQuery else { return }
        LifeBoardPerformanceTrace.event("HomeSearchQueryCommitted")
        searchState.updateQuery(newValue)
        searchState.submitCurrentQuery()
    }

    private func runSearchSuggestedCommand(_ command: HomeSearchSuggestedCommand) {
        cancelPendingSearchCommit()
        searchDraftQuery = ""
        let result = HomeSearchCommandResultBuilder.build(
            command: command,
            tasksSnapshot: tasksSnapshot,
            habitsSnapshot: habitsSnapshot,
            calendarSnapshot: calendarSnapshot
        )
        searchState.runSuggestedCommand(result)
        trackSearchChipToggled(kind: "suggested_command", value: command.rawValue, isSelected: true)
    }

    private func cancelPendingSearchCommit() {
        pendingSearchCommitTask?.cancel()
        pendingSearchCommitTask = nil
    }

    /// Executes backdropLayer.
    private func backdropLayer() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: max(480, layoutMetrics.height * 0.65))
                .overlay(alignment: .topLeading) {
                    TimelineBackdropWeekView(
                        snapshot: timelineSnapshot,
                        onSelectDate: { date in
                            timelineViewModel.syncSelectedDate(date)
                            viewModel.selectDate(date, source: .weekStrip)
                            withAnimation(sunriseFlipAnimation) {
                                timelineViewModel.snap(to: .collapsed)
                            }
                        },
                        onStartReplanForDate: { date in
                            viewModel.openNeedsReplanLauncher(for: date)
                        },
                        onPlaceReplanAllDay: { candidate, date in
                            timelineViewModel.syncSelectedDate(date)
                            viewModel.selectDate(date, source: .replan)
                            LifeBoardFeedback.success()
                            viewModel.placeReplanCandidateAllDay(taskID: candidate.taskID, on: date)
                            snackbar = SnackbarData(
                                message: "Added to \(date.formatted(.dateTime.weekday(.abbreviated).month().day()))",
                                actions: [
                                    SnackbarAction(title: "Undo") {
                                        viewModel.undoLastReplanAction()
                                    }
                                ],
                                autoDismissSeconds: 3
                            )
                        }
                    )
                    .padding(.horizontal, spacing.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isBackFaceVisible ? 0.001 : 1)
                    .allowsHitTesting(!isBackFaceVisible)
                    .accessibilityHidden(isBackFaceVisible)
                }
            Spacer(minLength: 0)
        }
    }

    /// Executes sunriseLayer.
    private func sunriseLayer(taskListBottomInset: CGFloat) -> some View {
        ZStack {
            persistentFace(.tasks) {
                sunriseFrontFace(taskListBottomInset: taskListBottomInset)
            }

            if hasMountedAnalyticsSurface || activeFace == .analytics {
                persistentFace(.analytics) {
                    sunriseAnalyticsFace()
                }
            }

            if hasMountedSearchSurface || activeFace == .search {
                persistentFace(.search) {
                    sunriseSearchFace(taskListBottomInset: taskListBottomInset)
                }
            }

            if activeFace == .chat {
                persistentFace(.chat) {
                    sunriseChatFace()
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .modifier(HomeDenseSurfaceModifier(cornerRadius: sunriseSurfaceCornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.sunrise.surface")
        .accessibilityValue(activeFace == .tasks ? timelineViewModel.sunriseAnchor.accessibilityValue : activeFace.surfaceAccessibilityValue)
        .animation(sunriseFlipAnimation, value: activeFace)
    }

    private func persistentFace<Content: View>(
        _ face: HomeSunriseFace,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isVisible = activeFace == face
        return content()
            .opacity(isVisible ? 1 : 0.001)
            .offset(x: isVisible ? 0 : (layoutClass.isPad ? 0 : (face == .tasks ? 0 : 10)))
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .zIndex(isVisible ? 1 : 0)
    }

    private func sunriseFrontFace(taskListBottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            if tasksSnapshot.activeQuickView == .today {
                todayTimelineSurface(taskListBottomInset: taskListBottomInset)
            } else {
                SunriseTaskListView(
                    headerContent: AnyView(taskListScrollHeader),
                    footerContent: taskListFooterContent,
                    footerContentCountsAsContentForEmptyState: false,
                    morningTasks: tasksSnapshot.morningTasks,
                    eveningTasks: tasksSnapshot.eveningTasks,
                    overdueTasks: tasksSnapshot.overdueTasks,
                    inlineCompletedTasks: tasksSnapshot.inlineCompletedTasks,
                    projects: tasksSnapshot.projects,
                    lifeAreas: viewModel.lifeAreas,
                    doneTimelineTasks: tasksSnapshot.doneTimelineTasks,
                    tagNameByID: tasksSnapshot.tagNameByID,
                    activeQuickView: tasksSnapshot.activeQuickView,
                    todayXPSoFar: tasksSnapshot.todayXPSoFar,
                    isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
                    projectGroupingMode: tasksSnapshot.projectGroupingMode,
                    customProjectOrderIDs: tasksSnapshot.customProjectOrderIDs,
                    emptyStateMessage: tasksSnapshot.emptyStateMessage,
                    emptyStateActionTitle: tasksSnapshot.emptyStateActionTitle,
                    isTaskDragEnabled: false,
                    todaySections: tasksSnapshot.todayAgendaSectionState.sections,
                    agendaTailItems: visibleAgendaTailItems,
                    expandedAgendaTailItemIDs: expandedAgendaTailItemIDs,
                    layoutStyle: .edgeToEdgeHome,
                    onTaskTap: onTaskTap,
                    onToggleComplete: { task in
                        trackTaskToggle(task, source: "task_list")
                        onToggleComplete(task)
                    },
                    onDeleteTask: onDeleteTask,
                    onRescheduleTask: onRescheduleTask,
                    onPromoteTaskToFocus: { task in
                        promoteAgendaTaskToFocus(task)
                    },
                    onCompleteHabit: { habit in
                        viewModel.completeHabit(habit, source: "task_list")
                    },
                    onSkipHabit: { habit in
                        viewModel.skipHabit(habit, source: "task_list")
                    },
                    onLapseHabit: { habit in
                        viewModel.lapseHabit(habit, source: "task_list")
                    },
                    onCycleHabit: { habit in
                        performHabitRowAction(habit, source: "task_list_row_tap")
                    },
                    onOpenHabit: { habit in
                        openHabitDetail(habit)
                    },
                    onReorderCustomProjects: onReorderCustomProjects,
                    onInboxHeaderAction: shouldShowInboxTriageAction ? {
                        viewModel.openRescue()
                    } : nil,
                    inboxHeaderActionTitle: shouldShowInboxTriageAction ? "Start rescue" : nil,
                    onCompletedSectionToggle: { sectionID, collapsed, count in
                        viewModel.trackHomeInteraction(
                            action: "home_completed_group_toggled",
                            metadata: [
                                "section_id": sectionID.uuidString,
                                "collapsed": collapsed,
                                "count": count
                            ]
                        )
                    },
                    onEmptyStateAction: { onAddTask(nil) },
                    onToggleAgendaTailItemExpansion: { itemID in
                        if expandedAgendaTailItemIDs.contains(itemID) {
                            expandedAgendaTailItemIDs.remove(itemID)
                        } else {
                            expandedAgendaTailItemIDs.insert(itemID)
                        }
                    },
                    onOpenRescue: isRescueEnabled ? {
                        viewModel.openRescue()
                    } : nil,
                    onTaskDragStarted: { task in
                        trackTaskDragStarted(task, source: "task_list")
                    },
                    onScrollChromeStateChange: { state in
                        updateDaySunriseSwipeChromeVisibility(for: state)
                        onTaskListScrollChromeStateChange(state)
                    },
                    onPullToSearch: {
                        openSearch(source: "task_list_pull")
                    },
                    highlightedTaskID: overlaySnapshot.guidanceState?.taskID,
                    scrollResetKey: taskListScrollResetKey,
                    bottomContentInset: taskListBottomInset
                )
                .padding(.top, spacing.s4)
                .onDrop(of: ["public.text"], isTargeted: nil, perform: handleListDrop)
                .accessibilityIdentifier("home.list.dropzone")
            }
        }
    }

    private func sunriseScheduleSurface() -> some View {
        ZStack {
            if let calendarIntegrationService {
                SunriseScheduleScreen(
                    service: calendarIntegrationService,
                    weekStartsOn: calendarIntegrationService.weekStartsOn,
                    presentationMode: .embedded,
                    selectedDate: Binding(
                        get: { viewModel.selectedDate },
                        set: { date in
                            viewModel.selectDate(date, source: .datePicker)
                        }
                    ),
                    bottomInset: layoutMetrics.taskListBottomInset
                )
            } else {
                Text("Schedule unavailable")
                    .font(.lifeboard(.body))
                    .foregroundColor(Color.lifeboard.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .coordinateSpace(name: Self.daySunriseSwipeCoordinateSpaceName)
    }

    private func sunriseAnalyticsFace() -> some View {
        Group {
            if let insightsViewModel = faceCoordinator.insightsViewModel,
               analyticsSurfaceState == .ready {
                InsightsTabView(
                    viewModel: insightsViewModel,
                    homeProgress: chromeSnapshot.progressState,
                    homeCompletionRate: chromeSnapshot.completionRate,
                    reflectionEligible: false,
                    dailyReflectionEntryState: chromeSnapshot.dailyReflectionEntryState,
                    momentumGuidanceText: momentumGuidanceText,
                    animateMomentumCard: shellPhase == .interactive && !reduceMotion,
                    onOpenReflection: {
                        openDailyReflectPlan()
                    },
                    onPerformInsightAction: { intent in
                        performInsightAction(intent)
                    },
                    bottomInset: layoutMetrics.taskListBottomInset,
                    topContentInset: secondaryFaceTopContentInset,
                    onBackToTasks: {
                        onReturnToTasks("back_chip")
                    },
                    onOpenSettings: {
                        onOpenSettings()
                    }
                )
            } else {
                SunriseDestinationScaffold(
                    title: "Insights",
                    subtitle: "Your progress at a glance.",
                    headerSymbolName: "chart.bar.xaxis",
                    leadingSystemImage: "line.3.horizontal",
                    leadingAccessibilityLabel: "Back to tasks",
                    leadingAccessibilityIdentifier: "home.sunrise.collapseHint",
                    leadingAction: { onReturnToTasks("back_chip") },
                    trailingSystemImage: "gearshape",
                    trailingAccessibilityLabel: "Settings",
                    trailingAction: { onOpenSettings() },
                    topContentInset: secondaryFaceTopContentInset
                ) {
                    VStack(spacing: spacing.s8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text(analyticsSurfaceState == .placeholder ? "Opening insights…" : "Loading insights…")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(LBColorTokens.navyMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func presentHabitBoardIfRequestedForUITests() {
        guard shouldPresentHabitBoardForUITests else { return }
        let hasVisibleHabits =
            habitsSnapshot.habitHomeSectionState.primaryRows.isEmpty == false
            || habitsSnapshot.habitHomeSectionState.recoveryRows.isEmpty == false
        guard hasVisibleHabits else { return }
        guard hasPresentedUITestHabitBoard == false, showHabitBoardPresented == false else { return }
        guard isSchedulingUITestHabitBoardPresentation == false else { return }
        isSchedulingUITestHabitBoardPresentation = true

        Task { @MainActor in
            setActiveFace(.tasks, animated: false)
            await Task.yield()
            await Task.yield()
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard showHabitBoardPresented == false else {
                isSchedulingUITestHabitBoardPresentation = false
                return
            }
            showHabitBoardPresented = true
            hasPresentedUITestHabitBoard = true
            isSchedulingUITestHabitBoardPresentation = false
        }
    }

    private func sunriseSearchFace(taskListBottomInset: CGFloat) -> some View {
        let effectiveSearchBottomInset = max(
            taskListBottomInset,
            layoutMetrics.keyboardOverlapHeight + spacing.s16
        )

        return SunriseSearchFaceView(
            query: $searchDraftQuery,
            commandMode: Binding(
                get: { searchState.commandMode },
                set: { searchState.setCommandMode($0) }
            ),
            isFocused: $isSearchFieldFocused,
            bottomInset: effectiveSearchBottomInset,
            topContentInset: secondaryFaceTopContentInset,
            quickChips: searchQuickChipDescriptors,
            advancedStatusChips: searchStatusChipDescriptors,
            advancedPriorityChips: searchPriorityChipDescriptors,
            advancedProjectChips: searchProjectChipDescriptors,
            recentSearches: searchState.recentSearches,
            activeFilterCount: searchState.activeFilterCount,
            resultCount: searchState.activeSuggestedCommandResult?.resultCount ?? searchState.sections.reduce(0) { $0 + $1.tasks.count },
            isLoading: isSearchLoadingContentVisible,
            loadingMessage: searchLoadingMessage,
            showsNoResults: searchState.shouldShowNoResultsMessage,
            hasActiveSuggestedCommand: searchState.hasActiveSuggestedCommand,
            emptyTitle: searchState.emptyStateTitle,
            emptySubtitle: searchState.emptyStateSubtitle,
            emptyPrimaryTitle: searchState.emptyPrimaryTitle,
            hasActiveFilters: searchState.hasActiveFilters,
            onBack: {
                onReturnToTasks("back_chip")
            },
            onQueryChanged: { newValue in
                trackSearchQueryChanged(newValue)
                scheduleSearchCommit(for: newValue)
            },
            onSubmit: {
                commitDraftSearchQueryImmediately()
            },
            onClear: {
                cancelPendingSearchCommit()
                searchDraftQuery = ""
                searchState.clearQuery()
                trackSearchQueryChanged("")
            },
            onClearFilters: {
                searchState.clearFilters()
            },
            onEmptyPrimaryAction: {
                if let fallbackCommand = searchState.emptyFallbackCommand {
                    runSearchSuggestedCommand(fallbackCommand)
                }
            },
            onRunSuggestedCommand: { command in
                runSearchSuggestedCommand(command)
            },
            onAskEvaPrompt: { prompt in
                searchState.recordRecentSearch(prompt)
                onOpenChat()
            }
        ) {
            searchResultsContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.view")
    }

    @ViewBuilder
    private func sunriseChatFace() -> some View {
        if let container = LLMDataController.shared {
            let chatContent = ChatContainerView(
                promptFocusRequestID: faceCoordinator.chatPromptFocusRequestID,
                onNavigationChromeChange: { state in
                    chatNavigationChromeState = state
                },
                onPromptFocusChange: onChatPromptFocusChange,
                onOpenTaskDetail: { task in
                    onTaskTap(task)
                },
                onOpenHabitDetail: { habitID in
                    openHabitDetail(habitID: habitID)
                },
                onPerformDayTaskAction: onPerformChatDayTaskAction,
                onPerformDayHabitAction: { action, card, completion in
                    if action == .open {
                        openHabitDetail(habitID: card.habitID)
                        completion(.success(()))
                        return
                    }
                    onPerformChatDayHabitAction(action, card, completion)
                }
            )
            .environmentObject(chatAppManager)
            .environment(LLMRuntimeCoordinator.shared.evaluator)
            .modelContainer(container)

            if layoutMetrics.keyboardOverlapHeight > 0.5 {
                chatContent
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear
                            .frame(height: layoutMetrics.chatComposerBottomInset)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
            } else {
                chatContent
                    .padding(.bottom, layoutMetrics.chatComposerBottomInset + spacing.s16)
            }
        } else {
            LLMStoreUnavailableView()
        }
    }

    private var searchFaceHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: spacing.s8) {
                Text("Search")
                    .font(.lifeboard(.headline))
                    .foregroundColor(Color.lifeboard.textPrimary)
                Spacer()
                Button {
                    onReturnToTasks("back_chip")
                } label: {
                    HStack(spacing: spacing.s4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back to tasks")
                            .font(.lifeboard(.caption2))
                    }
                    .foregroundColor(Color.lifeboard.textQuaternary.opacity(0.92))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search.backChip")
                .accessibilityLabel("Back to tasks")
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s8)

            VStack(alignment: .leading, spacing: spacing.s8) {
                LifeBoardSearchFilterChipsView(chips: searchStatusChipDescriptors)
                LifeBoardSearchFilterChipsView(chips: searchPriorityChipDescriptors)
                if !searchProjectChipDescriptors.isEmpty {
                    LifeBoardSearchFilterChipsView(chips: searchProjectChipDescriptors)
                }
            }
            .padding(.horizontal, spacing.s12)
            .padding(.bottom, spacing.s8)

            Divider()
                .overlay(Color.lifeboard.strokeHairline)
        }
    }

    @ViewBuilder
    private func searchFaceContentBody(
        availableHeight: CGFloat,
        contentBottomInset: CGFloat
    ) -> some View {
        if isSearchLoadingContentVisible {
            VStack(spacing: spacing.s8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text(searchLoadingMessage)
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textSecondary)
            }
        } else if searchState.shouldShowNoResultsMessage {
            VStack(spacing: spacing.s8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color.lifeboard.textTertiary)
                Text(searchState.emptyStateTitle)
                    .font(.lifeboard(.headline))
                    .foregroundColor(Color.lifeboard.textPrimary)
                    .accessibilityIdentifier("search.emptyStateLabel")
                Text(searchState.emptyStateSubtitle)
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(availableHeight - contentBottomInset, 0),
                alignment: .center
            )
        } else {
            LazyVStack(alignment: .leading, spacing: spacing.s12) {
                Color.clear
                    .frame(height: 0)
                    .accessibilityIdentifier("search.resultsList")

                ForEach(searchState.sections) { section in
                    SunriseTaskSectionView(
                        project: searchProject(for: section.projectName),
                        tasks: section.tasks,
                        tagNameByID: tasksSnapshot.tagNameByID,
                        completedCollapsed: false,
                        isTaskDragEnabled: false,
                        onTaskTap: { task in
                            trackSearchResultOpened(task, projectName: section.projectName)
                            onTaskTap(task)
                        },
                        onToggleComplete: { task in
                            trackTaskToggle(task, source: "search_results")
                            onToggleComplete(task)
                        },
                        onDeleteTask: { task in
                            onDeleteTask(task)
                        },
                        onRescheduleTask: { task in
                            onRescheduleTask(task)
                        }
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(availableHeight - contentBottomInset, 0),
                alignment: .topLeading
            )
        }
    }

    private var searchResultsContent: some View {
        SunriseSearchResultsSurface {
            if let commandResult = searchState.activeSuggestedCommandResult {
                HomeSearchCommandResultHeader(result: commandResult)

                ForEach(commandResult.taskSections) { section in
                    searchTaskSection(section)
                }

                if commandResult.habitRows.isEmpty == false {
                    LazyVStack(spacing: LBSpacingTokens.sm) {
                        ForEach(commandResult.habitRows) { habit in
                            HomeSearchHabitResultRow(row: habit) {
                                openHabitDetail(habit)
                            }
                        }
                    }
                }
            } else {
                ForEach(searchState.sections) { section in
                    searchTaskSection(section)
                }
            }
        }
    }

    private func searchTaskSection(_ section: HomeSearchSection) -> some View {
        SunriseTaskSectionView(
            project: searchProject(for: section.projectName),
            tasks: section.tasks,
            tagNameByID: tasksSnapshot.tagNameByID,
            completedCollapsed: searchCompletedResultsCollapsed,
            isTaskDragEnabled: false,
            layoutStyle: .sunriseSearch,
            onTaskTap: { task in
                trackSearchResultOpened(task, projectName: section.projectName)
                onTaskTap(task)
            },
            onToggleComplete: { task in
                trackTaskToggle(task, source: "search_results")
                onToggleComplete(task)
            },
            onDeleteTask: { task in
                onDeleteTask(task)
            },
            onRescheduleTask: { task in
                onRescheduleTask(task)
            },
            onCompletedCollapsedChange: { _, _ in
                searchState.toggleCompletedExpansion()
            }
        )
    }

    private var searchCompletedResultsCollapsed: Bool {
        if searchState.selectedStatus == .completed { return false }
        if searchState.trimmedQuery.localizedCaseInsensitiveContains("completed") { return false }
        return searchState.isCompletedExpanded == false
    }

    private var isSearchLoadingContentVisible: Bool {
        if searchState.hasActiveSuggestedCommand {
            return false
        }
        return (searchSurfaceState != .ready && !searchState.hasLoaded) || (searchState.isLoading && !searchState.hasLoaded)
    }

    private var searchLoadingMessage: String {
        if searchSurfaceState != .ready && !searchState.hasLoaded {
            return searchSurfaceState == .presenting ? "Opening search…" : "Loading tasks…"
        }
        return "Loading tasks…"
    }

    private var searchContentAlignment: Alignment {
        (isSearchLoadingContentVisible || searchState.shouldShowNoResultsMessage) ? .center : .topLeading
    }

    private var searchContentHorizontalPadding: CGFloat {
        searchState.shouldShowNoResultsMessage ? spacing.s20 : spacing.s16
    }

    @ViewBuilder
    private func topNavigationBar() -> some View {
        if isSearchOpen || isInsightsOpen {
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
        } else if isChatOpen {
            HomeEvaChatTopChromeView(
                chromeState: chatNavigationChromeState,
                onBack: {
                    returnToTasks(source: "chat_top_chrome_back")
                },
                onSettings: {
                    NotificationCenter.default.post(name: .requestEvaChatSettings, object: nil)
                },
                onHistory: {
                    NotificationCenter.default.post(name: .toggleChatHistory, object: nil)
                },
                onNewChat: {
                    NotificationCenter.default.post(name: .requestEvaChatNewThread, object: nil)
                }
            )
            .padding(.top, layoutClass.isPad ? 18 : 0)
        } else {
            VStack(alignment: .leading, spacing: spacing.s12) {
                let headerPresentation = chromeSnapshot.homeHeaderPresentation(
                    tasks: tasksSnapshot,
                    habits: habitsSnapshot
                )

                SunriseCompactHeaderChrome(
                    presentation: headerPresentation,
                    selectedQuickView: chromeSnapshot.activeScope.quickView,
                    taskCounts: chromeSnapshot.quickViewCounts,
                    extraTopPadding: layoutClass.isPad ? 18 : 0,
                    reduceMotion: reduceMotion,
                    onSelectQuickView: { viewModel.setQuickView($0) },
                    onBackToToday: {
                        viewModel.returnToToday(source: .backToToday)
                    },
                    onShowDatePicker: {
                        draftDate = chromeSnapshot.selectedDate
                        showDatePicker = true
                    },
                    onShowAdvancedFilters: {
                        showAdvancedFilters = true
                    },
                    onResetFilters: {
                        viewModel.resetAllFilters()
                    },
                    onOpenMenuSearch: {
                        openSearch(source: "scope_menu_search")
                    },
                    onOpenReflection: {
                        openDailyReflectPlan()
                    },
                    onOpenSettings: {
                        onOpenSettings()
                    }
                )
            }
        }
    }

    private var searchQuickChipDescriptors: [LifeBoardSearchFilterChipDescriptor] {
        let p0 = TaskPriorityConfig.Priority.allCases.first?.rawValue ?? 0
        let hasProjectFilter = searchState.selectedProjects.isEmpty == false
        return [
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-ask-eva",
                title: "Ask Eva",
                systemImage: "sparkles",
                isSelected: searchState.commandMode == .askEva,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: "search.quick.askEva"
            ) {
                searchState.setCommandMode(searchState.commandMode == .askEva ? .search : .askEva)
            },
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-today",
                title: "Today",
                systemImage: "calendar",
                isSelected: searchState.selectedStatus == .today,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: "search.quick.today"
            ) {
                searchState.setStatus(searchState.selectedStatus == .today ? .all : .today)
                trackSearchChipToggled(kind: "status", value: "today", isSelected: searchState.selectedStatus == .today)
            },
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-overdue",
                title: "Rescue",
                systemImage: "lifepreserver",
                isSelected: searchState.selectedStatus == .overdue,
                tintColor: LBColorTokens.role(.warning).base,
                accessibilityIdentifier: "search.quick.overdue"
            ) {
                searchState.setStatus(searchState.selectedStatus == .overdue ? .all : .overdue)
                trackSearchChipToggled(kind: "status", value: "overdue", isSelected: searchState.selectedStatus == .overdue)
            },
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-p0",
                title: "P0",
                systemImage: "flag.fill",
                isSelected: searchState.selectedPriorities.contains(p0),
                tintColor: Color.lifeboard.priorityMax,
                accessibilityIdentifier: "search.quick.p0"
            ) {
                if let priority = TaskPriorityConfig.Priority.allCases.first {
                    searchState.togglePriority(priority)
                    trackSearchChipToggled(kind: "priority", value: priority.code.lowercased(), isSelected: searchState.selectedPriorities.contains(priority.rawValue))
                }
            },
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-projects",
                title: "Projects",
                systemImage: "folder",
                count: searchState.selectedProjects.isEmpty ? nil : searchState.selectedProjects.count,
                isSelected: hasProjectFilter,
                tintColor: Color.lifeboard.accentSecondary,
                accessibilityIdentifier: "search.quick.projects"
            ) {
                if let firstProject = searchState.availableProjects.first {
                    searchState.toggleProject(firstProject)
                    trackSearchChipToggled(kind: "project", value: firstProject, isSelected: searchState.selectedProjects.contains(firstProject))
                } else {
                    LifeBoardFeedback.selection()
                }
            }
        ]
    }

    private var searchStatusChipDescriptors: [LifeBoardSearchFilterChipDescriptor] {
        HomeSearchStatusFilter.allCases.map { status in
            LifeBoardSearchFilterChipDescriptor(
                id: "status-\(status.rawValue)",
                title: status.title,
                systemImage: searchStatusSystemImage(status),
                isSelected: searchState.selectedStatus == status,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: status.accessibilityIdentifier
            ) {
                searchState.setStatus(status)
                trackSearchChipToggled(kind: "status", value: status.analyticsName, isSelected: true)
            }
        }
    }

    private func searchStatusSystemImage(_ status: HomeSearchStatusFilter) -> String {
        switch status {
        case .all:
            return "square.grid.2x2"
        case .today:
            return "calendar"
        case .overdue:
            return "exclamationmark.triangle"
        case .completed:
            return "checkmark.circle"
        }
    }

    private var searchPriorityChipDescriptors: [LifeBoardSearchFilterChipDescriptor] {
        TaskPriorityConfig.Priority.allCases.map { priority in
            let isSelected = searchState.selectedPriorities.contains(priority.rawValue)
            return LifeBoardSearchFilterChipDescriptor(
                id: "priority-\(priority.rawValue)",
                title: priority.code,
                isSelected: isSelected,
                tintColor: Color(uiColor: priority.color),
                accessibilityIdentifier: "search.priority.\(priority.code.lowercased())"
            ) {
                searchState.togglePriority(priority)
                trackSearchChipToggled(
                    kind: "priority",
                    value: priority.code.lowercased(),
                    isSelected: !isSelected
                )
            }
        }
    }

    private var searchProjectChipDescriptors: [LifeBoardSearchFilterChipDescriptor] {
        searchState.availableProjects.map { projectName in
            let isSelected = searchState.selectedProjects.contains(projectName)
            return LifeBoardSearchFilterChipDescriptor(
                id: "project-\(projectName)",
                title: projectName,
                isSelected: isSelected,
                tintColor: Color.lifeboard.accentSecondary,
                accessibilityIdentifier: "search.project.\(searchIdentifierToken(projectName))"
            ) {
                searchState.toggleProject(projectName)
                trackSearchChipToggled(
                    kind: "project",
                    value: projectName,
                    isSelected: !isSelected
                )
            }
        }
    }

    private func searchProject(for name: String) -> Project {
        if let resolved = tasksSnapshot.projects.first(where: { $0.name == name }) {
            return resolved
        }
        if name == ProjectConstants.inboxProjectName {
            return Project.createInbox()
        }
        return Project(name: name)
    }

    private var rescueTasksByID: [UUID: TaskDefinition] {
        Dictionary(
            uniqueKeysWithValues: (
                tasksSnapshot.overdueTasks
                + tasksSnapshot.morningTasks
                + tasksSnapshot.eveningTasks
            ).map { ($0.id, $0) }
        )
    }

    private func searchIdentifierToken(_ rawValue: String) -> String {
        rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private func trackSearchQueryChanged(_ query: String) {
        let now = Date()
        if let lastSearchQueryTelemetryAt, now.timeIntervalSince(lastSearchQueryTelemetryAt) < 0.7 {
            return
        }
        lastSearchQueryTelemetryAt = now
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.trackHomeInteraction(
            action: "home_search_query_changed",
            metadata: [
                "length": trimmed.count,
                "has_query": trimmed.isEmpty ? "false" : "true"
            ]
        )
    }

    private func trackSearchChipToggled(kind: String, value: String, isSelected: Bool) {
        viewModel.trackHomeInteraction(
            action: "home_search_chip_toggled",
            metadata: [
                "kind": kind,
                "value": value,
                "selected": isSelected ? "true" : "false"
            ]
        )
    }

    private func trackSearchResultOpened(_ task: TaskDefinition, projectName: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_result_opened",
            metadata: [
                "task_id": task.id.uuidString,
                "project": projectName
            ]
        )
    }

    private var shouldShowInboxTriageAction: Bool {
        V2FeatureFlags.evaRescueEnabled && chromeSnapshot.activeScope.quickView == .today
    }

    private var taskListHorizontalGutter: CGFloat {
        LifeBoardTheme.Spacing.lg
    }

    private func fullBleedTaskListHeaderModule<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, -taskListHorizontalGutter)
    }

    @ViewBuilder
    private var taskListScrollHeader: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            if let guidanceState = overlaySnapshot.guidanceState {
                HomeOnboardingGuidanceBanner(state: guidanceState)
                    .padding(.top, spacing.s8)
                    .modifier(HomeStaggerModifier(isEnabled: shellPhase == .interactive, index: 3))
            }
        }
    }

    private var timelineColumnMaxWidth: CGFloat? {
        HomeTimelineColumnLayout.maxWidth(for: layoutClass)
    }

    private var timelineHasNextHomeWidget: Bool {
        true
    }

    @ViewBuilder
    private func timelineColumnContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if let maxWidth = timelineColumnMaxWidth {
            content()
                .frame(maxWidth: maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content()
        }
    }

    private func beginDaySwipeTrace() {
        guard isDaySwipeTracingActive == false else { return }
        isDaySwipeTracingActive = true
        LifeBoardPerformanceTrace.event("HomeDaySwipeStarted")
    }

    private func cancelDaySwipeTraceIfNeeded() {
        guard isDaySwipeTracingActive else { return }
        LifeBoardPerformanceTrace.event("HomeDaySwipeCancelled")
        isDaySwipeTracingActive = false
    }

    private var daySunriseSwipeContainerSize: CGSize {
        CGSize(
            width: max(layoutMetrics.width, 1),
            height: max(layoutMetrics.height - measuredTimelineHeaderHeight, 1)
        )
    }

    private func normalizedDaySunriseSwipeSize(_ size: CGSize) -> CGSize {
        let fallback = daySunriseSwipeContainerSize
        return CGSize(
            width: max(size.width, fallback.width, 1),
            height: max(size.height, fallback.height, 1)
        )
    }

    private func daySunriseSwipeData(for side: SunriseDaySwipeSide, size: CGSize) -> SunriseDaySwipeData {
        let data = side == .leading ? leadingDaySunriseSwipeData : trailingDaySunriseSwipeData
        return data
            .resting(at: daySunriseSwipeRestingCenterY)
            .sized(to: size)
    }

    private func setDaySunriseSwipeData(_ data: SunriseDaySwipeData) {
        switch data.side {
        case .leading:
            leadingDaySunriseSwipeData = data
        case .trailing:
            trailingDaySunriseSwipeData = data
        }
    }

    private func handleTimelineScrollOffsetChange(_ newOffset: CGFloat) {
        guard newOffset.isFinite else { return }
        let normalizedOffset = max(0, newOffset)
        if let lastTimelineScrollOffsetY,
           normalizedOffset >= 40,
           abs(normalizedOffset - lastTimelineScrollOffsetY) < 4 {
            return
        }
        lastTimelineScrollOffsetY = normalizedOffset

        if let nextState = timelineScrollChromeStateTracker.consume(offset: normalizedOffset) {
            updateDaySunriseSwipeChromeVisibility(for: nextState)
        }
    }

    private func updateDaySunriseSwipeChromeVisibility(for state: HomeScrollChromeState) {
        let nextVisibility = SunriseDaySwipeChromeVisibilityPolicy.nextVisibility(
            currentVisibility: isDaySunriseSwipeChromeVisible,
            for: state,
            restoresOnExpanded: false
        )
        guard nextVisibility != isDaySunriseSwipeChromeVisible else { return }
        if reduceMotion || isUITesting {
            isDaySunriseSwipeChromeVisible = nextVisibility
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                isDaySunriseSwipeChromeVisible = nextVisibility
            }
        }
        if nextVisibility == false {
            activeDaySunriseSwipeSide = nil
            cancelDaySwipeTraceIfNeeded()
        }
    }

    private func resetDaySunriseSwipeChromeVisibility() {
        timelineScrollChromeStateTracker = HomeScrollChromeStateTracker()
        lastTimelineScrollOffsetY = nil
        isDaySunriseSwipeChromeVisible = true
    }

    private func updateDaySunriseSwipe(
        side: SunriseDaySwipeSide,
        translation: CGSize,
        location: CGPoint,
        size: CGSize
    ) {
        guard isDaySwipeGestureEnabled else { return }
        let containerSize = normalizedDaySunriseSwipeSize(size)
        activeDaySunriseSwipeSide = side
        topDaySunriseSwipeSide = side
        setDaySunriseSwipeData(
            daySunriseSwipeData(for: side, size: containerSize)
                .drag(translation: translation, location: location)
        )
    }

    private func endDaySunriseSwipe(
        side: SunriseDaySwipeSide,
        translation: CGSize,
        predictedEndTranslation: CGSize,
        size: CGSize
    ) {
        activeDaySunriseSwipeSide = nil
        let containerSize = normalizedDaySunriseSwipeSize(size)

        guard isDaySwipeGestureEnabled else {
            resetDaySunriseSwipe(side, size: containerSize)
            return
        }

        guard let direction = HomeDaySwipeResolver.default.resolvedDirection(
            translation: translation,
            predictedEndTranslation: predictedEndTranslation
        ), direction == side.direction else {
            cancelDaySwipeTraceIfNeeded()
            resetDaySunriseSwipe(side, size: containerSize)
            return
        }

        commitDaySunriseSwipe(side, size: containerSize)
    }

    private func cancelDaySunriseSwipe(side: SunriseDaySwipeSide, size: CGSize) {
        activeDaySunriseSwipeSide = nil
        cancelDaySwipeTraceIfNeeded()
        resetDaySunriseSwipe(side, size: normalizedDaySunriseSwipeSize(size))
    }

    private func resetDaySunriseSwipe(_ side: SunriseDaySwipeSide, size: CGSize) {
        let data = daySunriseSwipeData(for: side, size: size).initial()
        if reduceMotion || isUITesting {
            setDaySunriseSwipeData(data)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                setDaySunriseSwipeData(data)
            }
        }
    }

    private func resetIdleDaySunriseSwipeHandles(restingCenterY: CGFloat) {
        guard activeDaySunriseSwipeSide == nil else { return }
        let size = normalizedDaySunriseSwipeSize(daySunriseSwipeContainerSize)
        leadingDaySunriseSwipeData = leadingDaySunriseSwipeData
            .resting(at: restingCenterY)
            .sized(to: size)
            .initial()
        trailingDaySunriseSwipeData = trailingDaySunriseSwipeData
            .resting(at: restingCenterY)
            .sized(to: size)
            .initial()
    }

    private func commitDaySunriseSwipe(_ side: SunriseDaySwipeSide, size: CGSize) {
        topDaySunriseSwipeSide = side
        if reduceMotion || isUITesting {
            commitDaySwipe(side.direction)
            resetDaySunriseSwipe(side, size: size)
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            setDaySunriseSwipeData(daySunriseSwipeData(for: side, size: size).final())
        } completion: {
            commitDaySwipe(side.direction)
            resetDaySunriseSwipe(side, size: size)
        }
    }

    private func commitDaySwipe(_ direction: HomeDayNavigationDirection) {
        guard isDaySwipeGestureEnabled else { return }
        isDaySwipeTracingActive = false
        committedDaySwipeDirection = direction
        let dayOffset = direction == .previous ? -1 : 1
        LifeBoardFeedback.selection()
        withAnimation(daySwipeAnimation) {
            viewModel.shiftSelectedDay(byDays: dayOffset, source: .swipe)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if committedDaySwipeDirection == direction {
                committedDaySwipeDirection = nil
            }
        }
    }

    private func shiftSunriseSelectedDay(by dayOffset: Int) {
        guard dayOffset != 0 else { return }
        LifeBoardFeedback.selection()
        withAnimation(daySwipeAnimation) {
            viewModel.shiftSelectedDay(byDays: dayOffset, source: .datePicker)
        }
    }

    private func todayTimelineSurface(taskListBottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            SunriseTimelineBar(
                onSnapAnchor: { anchor in
                    withAnimation(sunriseFlipAnimation) {
                        timelineViewModel.snap(to: anchor)
                    }
                },
                onDragChanged: { translation in
                    timelineViewModel.updateDrag(translation, metrics: timelineLayoutMetrics)
                },
                onDragEnded: { translation in
                    timelineViewModel.endDrag(predictedTranslation: translation, metrics: timelineLayoutMetrics)
                }
            )
            .reportHeight(to: TimelineHeaderHeightPreferenceKey.self)
            .padding(.horizontal, spacing.s16)

            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        if showsFullTimelineQuietTrackingUITestMarker {
                            Text("Quiet tracking seeded")
                                .font(.caption2)
                                .foregroundStyle(Color.lifeboard.textPrimary.opacity(0.01))
                                .lineLimit(1)
                                .frame(width: 1, height: 1)
                                .clipped()
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Quiet tracking seeded")
                                .accessibilityIdentifier("home.passiveTracking.rail")
                        }

                        if habitsSnapshot.quietTrackingSummaryState.isVisible {
                            passiveTrackingRail
                                .padding(.horizontal, passiveTrackingRailHorizontalInset)
                        }

                        if case .trayVisible(let summary) = overlaySnapshot.replanState.phase {
                            timelineColumnContent {
                                NeedsReplanTrayView(
                                    title: summary.title,
                                    subtitle: summary.subtitle,
                                    callToAction: summary.callToAction,
                                    accessibilityHint: "Opens Plan the Day.",
                                    accessibilityIdentifier: "home.needsReplan.tray",
                                    isProminent: true
                                ) {
                                    viewModel.openNeedsReplanLauncher()
                                }
                                .padding(.horizontal, spacing.s16)
                                .onGeometryChange(for: CGFloat.self) { proxy in
                                    proxy.size.height
                                } action: { newHeight in
                                    guard abs(newHeight - measuredNeedsReplanTrayHeight) > 0.5 else { return }
                                    measuredNeedsReplanTrayHeight = newHeight
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        timelineRescueTail

                        timelineColumnContent {
                            let snapshot = timelineSnapshot
                            let selectedDayKey = Int(Calendar.current.startOfDay(for: snapshot.selectedDate).timeIntervalSince1970)
                            SunriseTimelineSurface(
                                snapshot: snapshot,
                                layoutClass: layoutClass,
                                showsRevealHandle: false,
                                hasNextHomeWidget: timelineHasNextHomeWidget,
                                onSelectDate: { date in
                                    timelineViewModel.syncSelectedDate(date)
                                    viewModel.selectDate(date, source: .weekStrip)
                                },
                                onSnapAnchor: { anchor in
                                    withAnimation(sunriseFlipAnimation) {
                                        timelineViewModel.snap(to: anchor)
                                    }
                                },
                                onDragChanged: { translation in
                                    timelineViewModel.updateDrag(translation, metrics: timelineLayoutMetrics)
                                },
                                onDragEnded: { translation in
                                    timelineViewModel.endDrag(predictedTranslation: translation, metrics: timelineLayoutMetrics)
                                },
                                onTaskTap: { item in
                                    if let eventID = item.eventID {
                                        handleHomeCalendarEventSelection(eventID: eventID, allowsTimelineHide: true)
                                        return
                                    }
                                    if let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) {
                                        onTaskTap(task)
                                    }
                                },
                                onToggleComplete: { item in
                                    guard let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) else { return }
                                    trackTaskToggle(task, source: "timeline")
                                    onToggleComplete(task)
                                },
                                onAnchorTap: onTimelineAnchorTap,
                                onAddTask: onAddTask,
                                onScheduleInbox: {
                                    viewModel.openRescue()
                                },
                                onShowCalendarInTimeline: {
                                    viewModel.showCalendarEventsInTimelineFromHome()
                                },
                                onPlaceReplanAtTime: { candidate, date in
                                    LifeBoardFeedback.success()
                                    viewModel.placeReplanCandidate(taskID: candidate.taskID, at: date)
                                    snackbar = SnackbarData(
                                        message: "Scheduled for \(date.formatted(date: .omitted, time: .shortened))",
                                        actions: [
                                            SnackbarAction(title: "Undo") {
                                                viewModel.undoLastReplanAction()
                                            }
                                        ],
                                        autoDismissSeconds: 3
                                    )
                                },
                                onPlaceReplanAllDay: { candidate, date in
                                    LifeBoardFeedback.success()
                                    viewModel.placeReplanCandidateAllDay(taskID: candidate.taskID, on: date)
                                    snackbar = SnackbarData(
                                        message: "Added to \(date.formatted(.dateTime.weekday(.abbreviated).month().day()))",
                                        actions: [
                                            SnackbarAction(title: "Undo") {
                                                viewModel.undoLastReplanAction()
                                            }
                                        ],
                                        autoDismissSeconds: 3
                                    )
                                },
                                onCancelReplanPlacement: {
                                    viewModel.cancelCurrentReplanPlacement()
                                },
                                onSkipReplanPlacement: {
                                    viewModel.skipCurrentReplanCandidate()
                                },
                                onClearReplanError: {
                                    viewModel.clearReplanError()
                                }
                            )
                            .id(selectedDayKey)
                            .transition(daySwipeTransition)
                            .animation(daySwipeAnimation, value: selectedDayKey)
                            .padding(.horizontal, spacing.s16)
                            .accessibilityAction(named: Text("Previous Day")) {
                                beginDaySwipeTrace()
                                commitDaySwipe(.previous)
                            }
                            .accessibilityAction(named: Text("Next Day")) {
                                beginDaySwipeTrace()
                                commitDaySwipe(.next)
                            }
                        }

                        if let entryState = chromeSnapshot.dailyReflectionEntryState {
                            timelineColumnContent {
                                HomeDailyReflectionEntryCard(
                                    state: entryState,
                                    mode: .compact
                                ) {
                                    openDailyReflectPlan(preferredReflectionDate: entryState.reflectionDate)
                                }
                                .padding(.horizontal, spacing.s16)
                            }
                        }

                        if let footerContent = timelineFooterModules {
                            footerContent
                        }

                        if let guidanceState = overlaySnapshot.guidanceState {
                            HomeOnboardingGuidanceBanner(state: guidanceState)
                                .padding(.horizontal, spacing.s16)
                        }

                        timelineColumnContent {
                            persistentReplanDayEntry
                                .padding(.horizontal, spacing.s16)
                        }

                        timelineBottomContentSpacer(taskListBottomInset: taskListBottomInset)
                    }
                    .padding(.top, spacing.s8)
                    .contentShape(Rectangle())
                    .lifeboardScrollOptimizedRendering()
                    .background {
                        SunriseDaySwipeGestureSurface(
                            isEnabled: isDaySwipeInteractionEnabled,
                            containerSize: daySunriseSwipeContainerSize,
                            restingCenterY: daySunriseSwipeRestingCenterY,
                            resolver: .default,
                            onInteractionStarted: beginDaySwipeTrace,
                            onChanged: { side, translation, location in
                                updateDaySunriseSwipe(
                                    side: side,
                                    translation: translation,
                                    location: location,
                                    size: daySunriseSwipeContainerSize
                                )
                            },
                            onEnded: { side, translation, predictedEndTranslation, _ in
                                endDaySunriseSwipe(
                                    side: side,
                                    translation: translation,
                                    predictedEndTranslation: predictedEndTranslation,
                                    size: daySunriseSwipeContainerSize
                                )
                            },
                            onCancelled: { side in
                                cancelDaySunriseSwipe(
                                    side: side,
                                    size: daySunriseSwipeContainerSize
                                )
                            }
                        )
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    }
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(
                    for: CGFloat.self,
                    of: { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    },
                    action: { _, newOffset in
                        handleTimelineScrollOffsetChange(max(0, newOffset))
                    }
                )

                if visibleAgendaTailItems.isEmpty == false {
                    pinnedTimelineRescueLauncher
                        .zIndex(6)
                }

                if activeFace != .tasks {
                    daySunriseSwipeOverlay
                }
            }
            .coordinateSpace(name: Self.daySunriseSwipeCoordinateSpaceName)
        }
        .accessibilityIdentifier("home.timeline.surface")
    }

    @ViewBuilder
    private var timelineRescueTail: some View {
        if isRescueEnabled {
            ForEach(visibleAgendaTailItems) { item in
                switch item {
                case .rescue(let state):
                    timelineColumnContent {
                        timelineRescueTailItem(state)
                            .padding(.horizontal, spacing.s16)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pinnedTimelineRescueLauncher: some View {
        if isRescueEnabled,
           let item = visibleAgendaTailItems.first,
           case .rescue(let state) = item {
            VStack(spacing: 0) {
                timelineColumnContent {
                    timelineRescueTailItem(state)
                        .padding(.horizontal, spacing.s16)
                }
                .padding(.top, spacing.s8)
                .background(Color.lifeboard.surfacePrimary.opacity(0.96))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(true)
        }
    }

    private func timelineRescueTailItem(_ state: RescueTailState) -> some View {
        HStack(alignment: .center, spacing: spacing.s12) {
            Button {
                viewModel.openRescue()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rescue")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .accessibilityIdentifier("home.rescue.header")

                    Text(state.subtitle)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.rescue.open")

            if state.mode == .expanded {
                Button("Start rescue") {
                    viewModel.openRescue()
                }
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.rescue.start")
            }
        }
        .padding(.vertical, spacing.s12)
        .padding(.horizontal, spacing.s16)
        .background(Color.lifeboard.surfaceSecondary.opacity(0.22))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.55), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("home.rescue.section")
    }

    private var daySunriseSwipeOverlay: some View {
        SunriseDaySwipeOverlay(
            isEnabled: isDaySwipeGestureEnabled,
            isChromeVisible: isDaySunriseSwipeChromeVisible,
            reduceMotion: reduceMotion || isUITesting,
            restingCenterY: daySunriseSwipeRestingCenterY,
            onInteractionStarted: beginDaySwipeTrace,
            onInteractionCancelled: cancelDaySwipeTraceIfNeeded,
            onCommit: commitDaySwipe,
            onHandleDragChanged: { side, translation, location, size in
                updateDaySunriseSwipe(
                    side: side,
                    translation: translation,
                    location: location,
                    size: size
                )
            },
            onHandleDragEnded: { side, translation, predictedEndTranslation, _, size in
                endDaySunriseSwipe(
                    side: side,
                    translation: translation,
                    predictedEndTranslation: predictedEndTranslation,
                    size: size
                )
            },
            leadingData: $leadingDaySunriseSwipeData,
            trailingData: $trailingDaySunriseSwipeData,
            topSide: $topDaySunriseSwipeSide
        )
    }

    private func timelineBottomContentSpacer(taskListBottomInset: CGFloat) -> some View {
        Color.clear
            .frame(height: timelineBottomContentClearance(taskListBottomInset: taskListBottomInset))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func timelineBottomContentClearance(taskListBottomInset: CGFloat) -> CGFloat {
        HomeTimelineColumnLayout.bottomContentClearance(
            taskListBottomInset: taskListBottomInset,
            layoutClass: layoutClass,
            spacing: spacing
        )
    }

    @ViewBuilder
    private var calendarScheduleModuleCard: some View {
        if calendarSnapshot.moduleState == .permissionRequired {
            calendarCardChrome {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    calendarSummaryHeader
                    calendarModuleBody
                    calendarPermissionCTA
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            calendarCardChrome {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    calendarSummaryHeader
                    calendarModuleBody
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.card, style: .continuous))
            .gesture(
                TapGesture().onEnded {
                    handleOpenScheduleAction()
                },
                including: .gesture
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(calendarCardAccessibilityLabel)
            .accessibilityHint(String(localized: "Opens the full calendar schedule"))
        }
    }

    @ViewBuilder
    private func calendarCardChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .modifier(CalendarCardChromeModifier())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.calendar.card")
    }

    @ViewBuilder
    private var calendarPermissionCTA: some View {
        if shouldShowCalendarPermissionCTA {
            Button(action: onRequestCalendarPermission) {
                Text(calendarPermissionButtonTitle)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard.textInverse)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.lifeboard.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.calendar.connect")
        }
    }

    private var calendarSummaryHeader: some View {
        Text(calendarSummaryLine)
            .font(.lifeboard(.bodyStrong))
            .foregroundStyle(Color.lifeboard.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("home.calendar.nextMeeting")
    }

    private var calendarSummaryLine: String {
        let dateText = LifeBoardCalendarPresentation.compactDateText(for: calendarSnapshot.selectedDate)

        if let nextMeeting = calendarSnapshot.nextMeeting {
            let timeText = LifeBoardCalendarPresentation.timeRangeText(for: nextMeeting.event)
            return "\(dateText) · Next up: \(nextMeeting.event.title) · \(timeText)"
        }

        if let freeUntil = calendarSnapshot.freeUntil {
            return "\(dateText) · Next up: Clear · Free until \(freeUntil.formatted(date: .omitted, time: .shortened))"
        }

        return "\(dateText) · Next up: Clear"
    }

    private var calendarCardAccessibilityLabel: String {
        let spokenLine = calendarSummaryLine.replacingOccurrences(of: " - ", with: " to ")
        return String(localized: "Open schedule, \(spokenLine)")
    }

    @ViewBuilder
    private var calendarModuleBody: some View {
        switch calendarSnapshot.moduleState {
        case .permissionRequired:
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(calendarPermissionBodyText)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .accessibilityIdentifier(calendarPermissionStateAccessibilityID)
            }
            .accessibilityLabel(calendarPermissionBodyText)
            .accessibilityIdentifier("home.calendar.state.permission")
        case .noCalendarsSelected:
            Text(String(localized: "No calendars selected. Choose at least one calendar for schedule insights."))
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityIdentifier("home.calendar.state.noCalendars")
        case .allDayOnly:
            Text(String(localized: "Only all-day events are scheduled. No timed blocks for this day."))
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityIdentifier("home.calendar.state.allDayOnly")
        case .empty:
            Text(String(localized: "No events are scheduled. Use this open window for focused work."))
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityIdentifier("home.calendar.state.empty")
        case .error(let message):
            Text(message)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.statusWarning)
                .accessibilityIdentifier("home.calendar.state.error")
        case .active:
            VStack(alignment: .leading, spacing: spacing.s8) {
                calendarTimelinePreview
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.calendar.state.active")
        }
    }

    @ViewBuilder
    private var calendarTimelinePreview: some View {
        if calendarSnapshot.selectedDayTimelineEvents.isEmpty == false {
            LifeBoardCalendarTimelineView(
                date: calendarSnapshot.selectedDate,
                events: calendarSnapshot.selectedDayEvents,
                density: .compact,
                showsDateLabel: false,
                accessibilityIdentifier: "home.calendar.timelinePreview",
                accessibilityLabelText: String(localized: "Home calendar timeline preview."),
                eventAccessibilityIdentifierPrefix: "home.calendar.event",
                onSelectEvent: handleHomeCalendarEventSelection
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var shouldShowCalendarPermissionCTA: Bool {
        guard calendarSnapshot.moduleState == .permissionRequired else { return false }
        switch calendarSnapshot.accessAction {
        case .requestPermission, .openSystemSettings:
            return true
        case .unavailable, .noneNeeded:
            return false
        }
    }

    private var calendarPermissionButtonTitle: String {
        switch calendarSnapshot.accessAction {
        case .openSystemSettings:
            return String(localized: "Open Settings")
        case .requestPermission:
            return String(localized: "Allow Full Calendar Access")
        case .unavailable, .noneNeeded:
            return String(localized: "Connect")
        }
    }

    private var calendarPermissionBodyText: String {
        switch calendarSnapshot.authorizationStatus {
        case .notDetermined:
            return String(localized: "Connect Calendar to surface next meetings and free windows.")
        case .denied:
            return String(localized: "Calendar access is denied by iOS. Enable LifeBoard in Settings > Privacy & Security > Calendars. If LifeBoard is missing, restart your device, reinstall LifeBoard, or reset Location & Privacy.")
        case .restricted:
            return String(localized: "Calendar access is restricted by system policy.")
        case .writeOnly:
            return String(localized: "LifeBoard has write-only access. Allow full calendar access so schedule events can appear.")
        case .authorized:
            return String(localized: "Connect Calendar to surface next meetings and free windows.")
        }
    }

    private var calendarPermissionStateAccessibilityID: String {
        switch calendarSnapshot.authorizationStatus {
        case .notDetermined:
            return "home.calendar.state.permission.notDetermined"
        case .denied:
            return "home.calendar.state.permission.denied"
        case .restricted:
            return "home.calendar.state.permission.restricted"
        case .writeOnly:
            return "home.calendar.state.permission.writeOnly"
        case .authorized:
            return "home.calendar.state.permission"
        }
    }

    private func handleHomeCalendarEventSelection(_ event: LifeBoardCalendarEventSnapshot) {
        handleHomeCalendarEventSelection(eventID: event.id, allowsTimelineHide: false)
    }

    private func handleHomeCalendarEventSelection(eventID: String, allowsTimelineHide: Bool) {
        suppressNextCalendarScheduleOpen = true
        selectedHomeCalendarEventDetail = HomeCalendarEventDetailSelection(
            eventID: eventID,
            selectedDate: viewModel.selectedDate,
            allowsTimelineHide: allowsTimelineHide
        )
        Task { @MainActor in
            suppressNextCalendarScheduleOpen = false
        }
    }

    private func handleOpenScheduleAction() {
        if suppressNextCalendarScheduleOpen {
            suppressNextCalendarScheduleOpen = false
            return
        }
        onOpenCalendarSchedule()
    }

    private var weeklySummaryCard: some View {
        HomeWeeklySummaryCard(
            summary: chromeSnapshot.weeklySummary,
            isLoading: chromeSnapshot.weeklySummaryIsLoading,
            errorMessage: chromeSnapshot.weeklySummaryErrorMessage,
            onPrimaryAction: {
                guard let summary = chromeSnapshot.weeklySummary else { return }
                switch summary.ctaState {
                case .planThisWeek, .planUpcomingWeek:
                    onOpenWeeklyPlanner()
                case .reviewWeek:
                    onOpenWeeklyReview()
                }
            },
            onRetryAction: onRetryWeeklySummary
        )
        .accessibilityIdentifier("home.weeklySummary.card")
    }

    private var taskListFooterContent: AnyView? {
        guard tasksSnapshot.activeQuickView != .today else { return nil }
        return AnyView(
            persistentReplanDayEntry
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
        )
    }

    private var timelineFooterModules: AnyView? {
        guard tasksSnapshot.activeQuickView == .today else { return nil }

        let hasWeeklySummary = chromeSnapshot.weeklySummary != nil
            || chromeSnapshot.weeklySummaryIsLoading
            || chromeSnapshot.weeklySummaryErrorMessage != nil
        let hasPrimaryHabits = habitsSnapshot.habitHomeSectionState.primaryRows.isEmpty == false
        let hasRecoveryHabits = habitsSnapshot.habitHomeSectionState.recoveryRows.isEmpty == false

        guard hasWeeklySummary || hasPrimaryHabits || hasRecoveryHabits else { return nil }

        return AnyView(
            VStack(alignment: .leading, spacing: spacing.s12) {
                if hasPrimaryHabits {
                    habitsSectionCard
                }

                if hasRecoveryHabits {
                    recoveryHabitsSectionCard
                }

                if hasWeeklySummary {
                    weeklySummaryCard
                }
            }
        )
    }

    private var persistentReplanDayEntry: some View {
        let summary = overlaySnapshot.replanState.persistentSummary
        return NeedsReplanTrayView(
            title: summary.persistentTitle,
            subtitle: summary.persistentSubtitle,
            callToAction: summary.persistentCallToAction,
            accessibilityHint: "Opens Replan Day.",
            accessibilityIdentifier: "home.replanDay.entry",
            isProminent: false
        ) {
            viewModel.openNeedsReplanLauncher()
        }
    }

    private var shouldShowDueTodayAgenda: Bool {
        chromeSnapshot.activeScope.quickView == .today && tasksSnapshot.dueTodaySection?.rows.isEmpty == false
    }

    @ViewBuilder
    private var rootTimelineRescueLauncher: some View {
        if isTodayTimelineVisible,
           isRescueEnabled,
           let item = visibleAgendaTailItems.first,
           case .rescue(let state) = item {
            HStack {
                Button {
                    viewModel.openRescue()
                } label: {
                    HStack(spacing: spacing.s8) {
                        Image(systemName: "lifepreserver")
                            .font(.system(size: 13, weight: .semibold))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Rescue")
                                .font(.lifeboard(.caption1).weight(.semibold))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                            Text(state.subtitle)
                                .font(.lifeboard(.caption2))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, spacing.s8)
                    .padding(.horizontal, spacing.s12)
                    .background(Color.lifeboard.surfacePrimary.opacity(0.96))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.lifeboard.strokeHairline.opacity(0.65), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rescue")
                .accessibilityValue(state.subtitle)
                .accessibilityIdentifier("home.rescue.open")
            }
            .padding(.top, layoutMetrics.safeAreaTop + spacing.s8)
            .padding(.trailing, spacing.s16)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.openRescue()
            }
            .zIndex(30)
        }
    }

    private var passiveTrackingRailCards: [QuietTrackingRailCardPresentation] {
        habitsSnapshot.quietTrackingSummaryState.railCards
    }

    private var showsFullTimelineQuietTrackingUITestMarker: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-UI_TESTING")
            && arguments.contains("-LIFEBOARD_TEST_SEED_FULL_TIMELINE_WORKSPACE")
    }

    private var shouldShowHomeDebugCountsMarker: Bool {
        Self.launchArguments.contains("-UI_TESTING")
            && Self.launchArguments.contains("-ENABLE_DEBUG_LOGGING")
    }

    private var homeDebugCountsValue: String {
        [
            "quick=\(tasksSnapshot.activeQuickView.rawValue)",
            "morning=\(tasksSnapshot.morningTasks.count)",
            "evening=\(tasksSnapshot.eveningTasks.count)",
            "overdue=\(tasksSnapshot.overdueTasks.count)",
            "tail=\(tasksSnapshot.agendaTailItems.count)",
            "visibleTail=\(visibleAgendaTailItems.count)",
            "focus=\(tasksSnapshot.focusRows.count)",
            "todayRows=\(tasksSnapshot.todayAgendaSectionState.totalCount)"
        ].joined(separator: " ")
    }

    private var passiveTrackingRailHorizontalInset: CGFloat {
        5
    }

    private var passiveTrackingRailLayout: QuietTrackingRailLayoutSpec {
        QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: passiveTrackingRailViewportWidth,
            totalCardCount: passiveTrackingRailCards.count,
            historyCellCount: passiveTrackingRailCards.map(\.historyCells.count).max() ?? 0,
            interItemSpacing: spacing.s8
        )
    }

    private var passiveTrackingRail: some View {
        let layout = passiveTrackingRailLayout
        let horizontalPadding = spacing.s16 * 2

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(passiveTrackingRailCards) { card in
                    passiveTrackingRailButton(for: card, layout: layout)
                        .frame(width: layout.slotWidth, alignment: .leading)
                }
            }
            .padding(.horizontal, spacing.s16)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            max(proxy.size.width - horizontalPadding, 0)
        } action: { newWidth in
            guard abs(newWidth - passiveTrackingRailViewportWidth) > 0.5 else { return }
            passiveTrackingRailViewportWidth = newWidth
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            guard abs(newHeight - measuredPassiveTrackingRailHeight) > 0.5 else { return }
            measuredPassiveTrackingRailHeight = newHeight
        }
        .accessibilityIdentifier("home.passiveTracking.rail")
    }

    private func passiveTrackingRailButton(
        for card: QuietTrackingRailCardPresentation,
        layout: QuietTrackingRailLayoutSpec
    ) -> some View {
        let visibleDayCount = min(layout.visibleDayCount, card.historyCells.count)

        return Button {
            openHabitDetail(habitID: card.habitID)
        } label: {
            QuietTrackingRailStreakWidget(
                card: card,
                slotWidth: layout.slotWidth,
                visibleDayCount: visibleDayCount
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityIdentifier("home.passiveTracking.card.\(card.id)")
        .accessibilityHint("Opens habit details for \(card.title)")
    }

    private var todayAgendaHeader: some View {
        HStack(alignment: .center, spacing: spacing.s8) {
            Label("Today Agenda", systemImage: "list.bullet.rectangle.portrait")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
            Spacer(minLength: 0)
            Text("\(tasksSnapshot.todayAgendaSectionState.totalCount)")
                .font(.lifeboard(.caption2).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .padding(.horizontal, spacing.s8)
                .padding(.vertical, spacing.s4)
                .background(Color.lifeboard.surfaceSecondary)
                .clipShape(Capsule())
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s4)
        .accessibilityIdentifier("home.todayAgenda.header")
    }

    private var habitsSectionCard: some View {
        HomeHabitSectionCardHost(
            title: "Habits",
            summaryLine: "\(habitsSnapshot.habitHomeSectionState.totalCount) active · \(habitsSnapshot.habitHomeSectionState.onStreakCount) in rhythm · \(habitsSnapshot.habitHomeSectionState.atRiskCount) need care",
            rows: habitsSnapshot.habitHomeSectionState.primaryRows,
            accessibilityIdentifier: "home.habits.section",
            onOpenBoard: { showHabitBoardPresented = true },
            onPrimaryAction: handleHabitPrimaryAction(_:),
            onSecondaryAction: handleHabitSecondaryAction(_:),
            onRowAction: handleHabitRowAction(_:),
            onLastCellAction: handleHabitLastCellAction(_:),
            onOpenHabit: openHabitDetail,
            showsAddHabitCTA: true,
            onAddHabit: presentHomeAddHabitComposer
        )
        .equatable()
    }

    private var recoveryHabitsSectionCard: some View {
        HomeHabitSectionCardHost(
            title: "Recovery",
            summaryLine: "\(habitsSnapshot.habitHomeSectionState.recoveryRows.count) in recovery",
            rows: habitsSnapshot.habitHomeSectionState.recoveryRows,
            accessibilityIdentifier: "home.habits.recovery",
            onOpenBoard: { showHabitBoardPresented = true },
            onPrimaryAction: handleHabitPrimaryAction(_:),
            onSecondaryAction: handleHabitSecondaryAction(_:),
            onRowAction: handleHabitRowAction(_:),
            onLastCellAction: handleHabitLastCellAction(_:),
            onOpenHabit: openHabitDetail,
            showsAddHabitCTA: false,
            onAddHabit: nil
        )
        .equatable()
    }

    private func presentHomeAddHabitComposer() {
        selectedHomeHabitRow = nil
        showHabitBoardPresented = false
        showHabitLibraryPresented = false
        homeHabitComposerViewModel.resetForm()
        showHomeAddHabitPresented = true
    }

    private func handleHabitPrimaryAction(_ habit: HomeHabitRow) {
        performHabitPrimaryAction(habit, source: "habit_home")
    }

    private func handleHabitSecondaryAction(_ habit: HomeHabitRow) {
        performHabitSecondaryAction(habit, source: "habit_home")
    }

    private func handleHabitRowAction(_ habit: HomeHabitRow) {
        performHabitRowAction(habit, source: "habit_home_row_tap")
    }

    private func handleHabitLastCellAction(_ habit: HomeHabitRow) {
        performHabitLastCellAction(habit, source: "habit_home_last_cell")
    }

    private var habitDetailFallbackRows: [HomeHabitRow] {
        habitsSnapshot.habitHomeSectionState.primaryRows
        + habitsSnapshot.habitHomeSectionState.recoveryRows
        + habitsSnapshot.quietTrackingSummaryState.stableRows
    }

    private func makeFallbackHabitLibraryRow(from habit: HomeHabitRow) -> HabitLibraryRow {
        HabitLibraryRow(
            habitID: habit.habitID,
            title: habit.title,
            kind: habit.kind,
            trackingMode: habit.trackingMode,
            cadence: habit.cadence,
            lifeAreaID: habit.lifeAreaID,
            lifeAreaName: habit.lifeAreaName,
            projectID: habit.projectID,
            projectName: habit.projectName,
            icon: HabitIconMetadata(symbolName: habit.iconSymbolName, categoryKey: "home_fallback"),
            colorHex: habit.accentHex,
            isPaused: false,
            isArchived: false,
            currentStreak: habit.currentStreak,
            bestStreak: habit.bestStreak,
            last14Days: habit.last14Days,
            nextDueAt: habit.dueAt,
            lastCompletedAt: nil,
            reminderWindowStart: nil,
            reminderWindowEnd: nil,
            notes: habit.helperText
        )
    }

    private func openHabitDetail(_ habit: HomeHabitRow) {
        HomePerformanceSignposts.openDetailTap()
        LifeBoardPerformanceTrace.event("HabitDetailTapReceived")
        if let row = viewModel.habitLibraryRow(for: habit.habitID) {
            selectedHomeHabitRow = row
            return
        }

        // Fallback keeps detail navigation available when Home rows are ready
        // before the library cache hydrates.
        selectedHomeHabitRow = makeFallbackHabitLibraryRow(from: habit)
    }

    private func openHabitDetail(habitID: UUID) {
        HomePerformanceSignposts.openDetailTap()
        LifeBoardPerformanceTrace.event("HabitDetailTapReceived")

        if let row = viewModel.habitLibraryRow(for: habitID) {
            selectedHomeHabitRow = row
            return
        }

        if let fallback = habitDetailFallbackRows.first(where: { $0.habitID == habitID }) {
            selectedHomeHabitRow = makeFallbackHabitLibraryRow(from: fallback)
            return
        }
    }

    private func presentHabitBoardFromDeepLink() {
        showHomeAddHabitPresented = false
        showHabitLibraryPresented = false
        selectedHomeHabitRow = nil
        showHabitBoardPresented = true
    }

    private func presentHabitLibraryFromDeepLink() {
        showHomeAddHabitPresented = false
        selectedHomeHabitRow = nil
        showHabitBoardPresented = false
        showHabitLibraryPresented = true
    }

    private func presentHabitDetailFromDeepLink(habitID: UUID) {
        showHomeAddHabitPresented = false
        showHabitLibraryPresented = false
        showHabitBoardPresented = false
        selectedHomeHabitRow = nil
        if let row = viewModel.habitLibraryRow(for: habitID) {
            selectedHomeHabitRow = row
            return
        }

        if let fallback = habitDetailFallbackRows.first(where: { $0.habitID == habitID }) {
            selectedHomeHabitRow = makeFallbackHabitLibraryRow(from: fallback)
            return
        }

        snackbar = SnackbarData(message: "Couldn't find that habit. Opening Habit Board.")
        showHabitBoardPresented = true
    }

    private func beginHabitMutationSignpost(trackLastCellTap: Bool = false) {
        HomePerformanceSignposts.endHabitMutation(activeHabitMutationInterval)
        activeHabitMutationInterval = HomePerformanceSignposts.beginHabitMutation()

        if trackLastCellTap {
            HomePerformanceSignposts.endLastCellTap(activeLastCellTapInterval)
            activeLastCellTapInterval = HomePerformanceSignposts.beginLastCellTap()
        }
    }

    private func performHabitPrimaryAction(_ habit: HomeHabitRow, source: String) {
        beginHabitMutationSignpost()
        switch (habit.kind, habit.trackingMode) {
        case (_, .lapseOnly):
            viewModel.lapseHabit(habit, source: source)
        case (.positive, _):
            viewModel.completeHabit(habit, source: source)
        case (.negative, .dailyCheckIn):
            viewModel.completeHabit(habit, source: source)
        }
    }

    private func performHabitSecondaryAction(_ habit: HomeHabitRow, source: String) {
        beginHabitMutationSignpost()
        switch (habit.kind, habit.trackingMode) {
        case (.positive, _):
            viewModel.skipHabit(habit, source: source)
        case (.negative, .dailyCheckIn):
            viewModel.lapseHabit(habit, source: source)
        case (.negative, .lapseOnly):
            break
        }
    }

    private func performHabitRowAction(_ habit: HomeHabitRow, source: String) {
        LifeBoardPerformanceTrace.event("home.habitRowTap.accepted")
        HomePerformanceSignposts.lastCellTapAccepted()
        beginHabitMutationSignpost(trackLastCellTap: true)
        viewModel.performHabitLastCellAction(habit, source: source)
    }

    private func performHabitLastCellAction(_ habit: HomeHabitRow, source: String) {
        HomePerformanceSignposts.lastCellTapAccepted()
        beginHabitMutationSignpost(trackLastCellTap: true)
        viewModel.performHabitLastCellAction(habit, source: source)
    }

    @ViewBuilder
    private var dueTodayAgendaSection: some View {
        let rows = Array((tasksSnapshot.dueTodaySection?.rows ?? []).prefix(5))
        let hasHabitRows = rows.contains { row in
            if case .habit = row { return true }
            return false
        }

        fullBleedTaskListHeaderModule {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                    Label("Due today", systemImage: "calendar.badge.clock")
                        .font(.lifeboard(.headline))
                        .foregroundColor(Color.lifeboard.textPrimary)

                    Spacer(minLength: 0)

                    Text("\(tasksSnapshot.dueTodaySection?.rows.count ?? 0)")
                        .font(.lifeboard(.caption2).weight(.semibold))
                        .foregroundColor(Color.lifeboard.textSecondary)
                        .padding(.horizontal, spacing.s8)
                        .padding(.vertical, spacing.s4)
                        .background(Color.lifeboard.surfaceSecondary)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, spacing.s16)
                .padding(.bottom, spacing.s8)

                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        dueTodayAgendaRow(row, showTypeBadge: hasHabitRows)

                        if index < rows.count - 1 {
                            HomeTaskRowDivider()
                        }
                    }
                }
            }
            .padding(.vertical, spacing.s12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.dueTodayAgenda.section")
        }
    }

    @ViewBuilder
    private func dueTodayAgendaRow(_ row: HomeTodayRow, showTypeBadge: Bool) -> some View {
        switch row {
        case .task(let task):
            let fallbackIconSymbolName = projectIconSymbolName(for: task.projectID)
            SunriseTaskRowView(
                task: task,
                fallbackIconSymbolName: fallbackIconSymbolName,
                accentHex: HomeTaskTintResolver.rowAccentHex(
                    for: row,
                    projectsByID: tasksSnapshot.projectsByID,
                    lifeAreasByID: lifeAreasByID
                ),
                showTypeBadge: showTypeBadge,
                isInOverdueSection: task.isOverdue,
                tagNameByID: tasksSnapshot.tagNameByID,
                todayXPSoFar: tasksSnapshot.todayXPSoFar,
                isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
                isTaskDragEnabled: false,
                metadataPolicy: .homeUnifiedList,
                chromeStyle: .flatHomeList,
                onTap: { onTaskTap(task) },
                onToggleComplete: {
                    trackTaskToggle(task, source: "due_today_agenda")
                    onToggleComplete(task)
                },
                onDelete: { onDeleteTask(task) },
                onReschedule: { onRescheduleTask(task) },
                onPromoteToFocus: { promoteAgendaTaskToFocus(task) }
            )
            .equatable()

        case .habit(let habit):
            HomeHabitRowView(
                row: habit,
                onPrimaryAction: {
                    performHabitPrimaryAction(habit, source: "due_today_agenda")
                },
                onSecondaryAction: {
                    performHabitSecondaryAction(habit, source: "due_today_agenda")
                },
                onRowAction: {
                    performHabitRowAction(habit, source: "due_today_agenda_row_tap")
                },
                onOpenDetail: {
                    openHabitDetail(habit)
                },
                onLastCellAction: {
                    performHabitLastCellAction(habit, source: "due_today_agenda_last_cell")
                }
            )
        }
    }

    private func projectIconSymbolName(for projectID: UUID) -> String? {
        tasksSnapshot.projectsByID[projectID]?.icon.systemImageName
    }

    private var focusStrip: some View {
        SunriseFocusZone(
            rows: tasksSnapshot.focusNowSectionState.rows,
            maxVisibleRows: 3,
            canDrag: false,
            pinnedTaskIDs: tasksSnapshot.focusNowSectionState.pinnedTaskIDs,
            shellPhase: shellPhase,
            insightForTaskID: { taskID in
                viewModel.evaFocusInsight(for: taskID)
            },
            onWhy: {
                viewModel.openFocusWhy()
            },
            onPinTask: { task in
                pinFocusTask(task)
            },
            onUnpinTask: { task in
                unpinFocusTask(task)
            },
            onTaskTap: { task in
                onTaskTap(task)
            },
            onToggleComplete: { task in
                trackTaskToggle(task, source: "focus_strip")
                onToggleComplete(task)
            },
            onStartFocus: { task in
                onStartFocus(task)
            },
            onTaskDragStarted: { task in
                trackTaskDragStarted(task, source: "focus_strip")
            },
            onCompleteHabit: { habit in
                viewModel.completeHabit(habit, source: "focus_strip")
            },
            onSkipHabit: { habit in
                viewModel.skipHabit(habit, source: "focus_strip")
            },
            onLapseHabit: { habit in
                viewModel.lapseHabit(habit, source: "focus_strip")
            },
            onCycleHabit: { habit in
                performHabitRowAction(habit, source: "focus_strip_row_tap")
            },
            onOpenHabit: { habit in
                openHabitDetail(habit)
            },
            onDrop: handleFocusDrop
        )
    }

    /// Executes trackTaskToggle.
    private func trackTaskToggle(_ task: TaskDefinition, source: String) {
        viewModel.trackHomeInteraction(
            action: "home_task_toggle",
            metadata: [
                "source": source,
                "task_id": task.id.uuidString,
                "current_state": task.isComplete ? "done" : "open"
            ]
        )
    }

    /// Executes trackTaskDragStarted.
    private func trackTaskDragStarted(_ task: TaskDefinition, source: String) {
        var metadata = focusScopeMetadata(source: source, taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
        viewModel.trackHomeInteraction(
            action: "home_focus_drag_started",
            metadata: metadata
        )
    }

    /// Executes pinFocusTask.
    private func pinFocusTask(_ task: TaskDefinition) {
        let result = viewModel.pinTaskToFocus(task.id)
        var metadata = focusScopeMetadata(source: "focus_strip_pin", taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

        switch result {
        case .pinned:
            LifeBoardFeedback.success()
            viewModel.trackHomeInteraction(action: "home_focus_pin", metadata: metadata)
        case .alreadyPinned:
            LifeBoardFeedback.selection()
        case .capacityReached(let limit):
            LifeBoardFeedback.light()
            metadata["limit"] = limit
            viewModel.trackHomeInteraction(action: "home_focus_pin_rejected_capacity", metadata: metadata)
        case .taskIneligible:
            LifeBoardFeedback.selection()
        }
    }

    private func promoteAgendaTaskToFocus(_ task: TaskDefinition) {
        let result = viewModel.promoteTaskToFocus(task.id)
        var metadata = focusScopeMetadata(source: "today_agenda_promote", taskID: task.id)
        metadata["visible_count"] = viewModel.focusNowSectionState.visibleCount
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

        switch result {
        case .promoted:
            LifeBoardFeedback.success()
            viewModel.trackHomeInteraction(action: "home_focus_promote", metadata: metadata)
        case .alreadyPinned:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_promote_already_pinned", metadata: metadata)
        case .alreadyVisible:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_promote_already_visible", metadata: metadata)
        case .replacementRequired(let currentFocusTaskIDs):
            pendingFocusPromotionTask = task
            focusReplacementOptions = currentFocusTaskIDs.compactMap(viewModel.taskSnapshot(for:))
            LifeBoardFeedback.light()
            metadata["replacement_count"] = focusReplacementOptions.count
            viewModel.trackHomeInteraction(action: "home_focus_promote_replace_prompt", metadata: metadata)
        case .taskIneligible:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_promote_rejected_ineligible", metadata: metadata)
        }
    }

    private func replaceFocusTask(
        _ promotedTask: TaskDefinition,
        replacing focusTask: TaskDefinition,
        source: String
    ) {
        let result = viewModel.replaceFocusTask(with: promotedTask.id, replacing: focusTask.id)
        var metadata = focusScopeMetadata(source: source, taskID: promotedTask.id)
        metadata["replaced_task_id"] = focusTask.id.uuidString

        switch result {
        case .promoted:
            LifeBoardFeedback.success()
            viewModel.trackHomeInteraction(action: "home_focus_replace", metadata: metadata)
        case .alreadyVisible:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_replace_already_visible", metadata: metadata)
        case .alreadyPinned:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_replace_already_pinned", metadata: metadata)
        case .replacementRequired:
            LifeBoardFeedback.light()
        case .taskIneligible:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_replace_rejected_ineligible", metadata: metadata)
        }

        clearPendingFocusReplacement()
    }

    private func clearPendingFocusReplacement() {
        pendingFocusPromotionTask = nil
        focusReplacementOptions = []
    }

    private func refreshFocusWhyShuffleCandidates() {
        _ = viewModel.refreshFocusWhyShuffleCandidates()
        LifeBoardFeedback.selection()
    }

    private func replaceFocusTaskFromWhySheet(_ candidate: TaskDefinition, replacing focusTask: TaskDefinition) {
        replaceFocusTask(candidate, replacing: focusTask, source: "focus_why_replace")
        _ = viewModel.refreshFocusWhyShuffleCandidates()
    }

    /// Executes unpinFocusTask.
    private func unpinFocusTask(_ task: TaskDefinition) {
        guard viewModel.pinnedFocusTaskIDs.contains(task.id) else { return }
        viewModel.unpinTaskFromFocus(task.id)
        LifeBoardFeedback.selection()

        var metadata = focusScopeMetadata(source: "focus_strip_unpin", taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
        viewModel.trackHomeInteraction(action: "home_focus_unpin", metadata: metadata)
    }

    /// Executes handleFocusDrop.
    private func handleFocusDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }

            let pinResult = viewModel.pinTaskToFocus(taskID)
            var metadata = focusScopeMetadata(source: "task_list", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

            switch pinResult {
            case .pinned:
                LifeBoardFeedback.success()
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .alreadyPinned:
                LifeBoardFeedback.selection()
                metadata["result"] = "already_pinned"
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .capacityReached(let limit):
                LifeBoardFeedback.light()
                metadata["limit"] = limit
                viewModel.trackHomeInteraction(action: "home_focus_drop_rejected_capacity", metadata: metadata)
            case .taskIneligible:
                LifeBoardFeedback.selection()
            }
        }
    }

    /// Executes handleListDrop.
    private func handleListDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }
            let wasPinned = viewModel.pinnedFocusTaskIDs.contains(taskID)
            guard wasPinned else { return }

            viewModel.unpinTaskFromFocus(taskID)
            LifeBoardFeedback.selection()

            var metadata = focusScopeMetadata(source: "focus_strip", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
            viewModel.trackHomeInteraction(action: "home_focus_dropped_out", metadata: metadata)
        }
    }

    /// Executes loadTaskIDFromDrop.
    private func loadTaskIDFromDrop(
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
    private func focusScopeMetadata(source: String, taskID: UUID) -> [String: Any] {
        [
            "source": source,
            "task_id": taskID.uuidString,
            "quick_view": viewModel.activeScope.quickView.analyticsAction,
            "scope": scopeAnalyticsName
        ]
    }

    private var scopeAnalyticsName: String {
        switch viewModel.activeScope {
        case .today:
            return "today"
        case .customDate:
            return "custom_date"
        case .upcoming:
            return "upcoming"
        case .overdue:
            return "overdue"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }

    private var momentumGuidanceText: String {
        chromeSnapshot.momentumGuidanceText
    }

    private func handleXPResult(_ result: XPEventResult?) {
        guard let result else { return }

        if result.awardedXP >= 7 {
            LifeBoardFeedback.success()
        } else if result.awardedXP >= 4 {
            LifeBoardFeedback.medium()
        } else {
            LifeBoardFeedback.light()
        }

        viewModel.trackHomeInteraction(
            action: "home_progress_feedback",
            metadata: ["delta": result.awardedXP, "new_score": viewModel.dailyScore]
        )
    }

    private func toggleInsights(source: String) {
        let shouldOpenInsights = activeFace != .analytics
        if shouldOpenInsights {
            openAnalytics(source: source, launchDefaultInsights: true)
        } else {
            closeAnalytics(source: source)
        }
    }

    private func setActiveFace(_ face: HomeSunriseFace, animated: Bool) {
        if animated {
            withAnimation(sunriseFlipAnimation) {
                faceCoordinator.setActiveFace(face)
            }
        } else {
            faceCoordinator.setActiveFace(face)
        }
    }

    private func openAnalytics(source: String, launchDefaultInsights: Bool) {
        onOpenAnalytics(source, launchDefaultInsights)
    }

    private func closeAnalytics(source: String) {
        onCloseAnalytics(source)
    }

    private func toggleSearch(source: String) {
        let shouldOpenSearch = activeFace != .search
        if shouldOpenSearch {
            openSearch(source: source)
        } else {
            closeSearch(source: source)
        }
    }

    private func openSearch(source: String) {
        onOpenSearch(source)
    }

    private var taskListScrollResetKey: String {
        switch chromeSnapshot.activeScope {
        case .today:
            return "today"
        case .customDate(let date):
            return "customDate-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)"
        case .upcoming:
            return "upcoming"
        case .overdue:
            return "overdue"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }

    private func closeSearch(source: String) {
        onCloseSearch(source)
    }

    private func returnToTasks(source: String) {
        onReturnToTasks(source)
    }

    private func performInsightAction(_ intent: InsightsActionIntent) {
        LifeBoardFeedback.selection()
        viewModel.trackHomeInteraction(
            action: "insights_cta_tap",
            metadata: ["intent": intent.telemetryName]
        )

        switch intent {
        case .addTask:
            onAddTask(nil)

        case .openToday:
            viewModel.setQuickView(.today)
            returnToTasks(source: "insights_open_today")

        case .startNextDecision:
            viewModel.setQuickView(.today)
            returnToTasks(source: "insights_next_decision")
            DispatchQueue.main.async {
                viewModel.startNextDecision(scope: .visible)
            }

        case .protectFocus:
            performInsightsFocusAction()

        case .openYesterdayReview:
            openDailyReflectPlan(preferredReflectionDate: yesterdayDate())

        case .openHabitCheck:
            showHabitBoardPresented = true
            LifeBoardFeedback.success()

        case .openBacklogRecovery:
            viewModel.setQuickView(.overdue)
            returnToTasks(source: "insights_backlog_recovery")
            DispatchQueue.main.async {
                viewModel.openRescue()
            }

        case .openProjectMix:
            onOpenProjectCreator()

        case .openWeeklyReview:
            onOpenWeeklyReview()

        case .openWeeklyPlanner:
            onOpenWeeklyPlanner()

        case .openReminderSettings:
            snackbar = SnackbarData(
                message: "Opening Notifications & Focus settings.",
                autoDismissSeconds: 2
            )
            returnToTasks(source: "insights_reminder_settings")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onOpenSettings()
            }

        case .expandDetails:
            break
        }
    }

    private func performInsightsFocusAction() {
        let hasFocusCandidates = tasksSnapshot.focusNowSectionState.rows.isEmpty == false
            || viewModel.focusTasks.isEmpty == false
        if V2FeatureFlags.evaFocusEnabled, hasFocusCandidates {
            viewModel.openFocusWhy()
            LifeBoardFeedback.success()
            return
        }

        snackbar = SnackbarData(
            message: "Starting a short protected focus block.",
            autoDismissSeconds: 2
        )
        startNextActionFocusTimer()
    }

    private func yesterdayDate() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: chromeSnapshot.selectedDate) ?? Date().addingTimeInterval(-86_400)
    }

    private func trackSearchFlipOpen(source: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_flip_open",
            metadata: ["source": source]
        )
    }

    private func trackSearchFlipClose(source: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_flip_close",
            metadata: ["source": source]
        )
    }

    private func playHabitMutationFeedbackHaptic(_ haptic: HomeHabitMutationFeedbackHaptic) {
        switch haptic {
        case .selection:
            LifeBoardFeedback.selection()
        case .success:
            LifeBoardFeedback.success()
        case .warning:
            LifeBoardFeedback.warning()
        }
    }

    private func startNextActionFocusTimer() {
        guard isNextActionFocusRequestInFlight == false else { return }
        activeFocusTimerSource = "next_action_module_15min_focus"
        isNextActionFocusRequestInFlight = true
        LifeBoardFeedback.selection()
        viewModel.trackHomeInteraction(
            action: "home_next_action_focus_start_tapped",
            metadata: [
                "source": "next_action_module_15min_focus",
                "target_duration_seconds": Self.nextActionFocusDurationSeconds
            ]
        )
        viewModel.startFocusSession(taskID: nil, targetDurationSeconds: Self.nextActionFocusDurationSeconds) { result in
            Task { @MainActor in
                isNextActionFocusRequestInFlight = false
                switch result {
                case .success(let session):
                    activeNextActionFocusSession = session
                    showNextActionFocusTimer = true
                case .failure(let error):
                    if let focusError = error as? FocusSessionError, case .alreadyActive = focusError {
                        resumeNextActionFocusSession(source: "next_action_module_15min_focus")
                    } else {
                        logWarning(
                            event: "focus_session_start_failed",
                            message: "Failed to start focus session from next action module",
                            fields: [
                                "source": "next_action_module_15min_focus",
                                "error": error.localizedDescription
                            ]
                        )
                        snackbar = SnackbarData(message: "Couldn't start focus timer")
                    }
                }
            }
        }
    }

    private func startFocusNowTimer(
        draftTasks: [TaskDefinition],
        task: TaskDefinition,
        durationSeconds: Int
    ) {
        guard isNextActionFocusRequestInFlight == false else { return }
        activeFocusTimerSource = "focus_now"
        isNextActionFocusRequestInFlight = true
        LifeBoardFeedback.selection()
        viewModel.trackHomeInteraction(
            action: "focus_now_timer_start_tapped",
            metadata: [
                "task_id": task.id.uuidString,
                "target_duration_seconds": durationSeconds
            ]
        )

        viewModel.startFocusSession(taskID: task.id, targetDurationSeconds: durationSeconds) { result in
            Task { @MainActor in
                isNextActionFocusRequestInFlight = false
                switch result {
                case .success(let session):
                    guard viewModel.commitFocusNowSet(taskIDs: draftTasks.map(\.id), source: "focus_now_timer_start") else {
                        snackbar = SnackbarData(message: "Couldn't start focus. Try again.")
                        return
                    }
                    viewModel.setEvaFocusWhyPresented(false)
                    activeNextActionFocusSession = session
                    showNextActionFocusTimer = true
                case .failure(let error):
                    if let focusError = error as? FocusSessionError, case .alreadyActive = focusError {
                        viewModel.setEvaFocusWhyPresented(false)
                        resumeNextActionFocusSession(source: "focus_now")
                    } else {
                        logWarning(
                            event: "focus_session_start_failed",
                            message: "Failed to start focus session from Focus Now",
                            fields: [
                                "source": "focus_now",
                                "error": error.localizedDescription
                            ]
                        )
                        snackbar = SnackbarData(message: "Couldn't start focus. Try again.")
                    }
                }
            }
        }
    }

    private func resumeNextActionFocusSession(source: String) {
        activeFocusTimerSource = source
        viewModel.fetchActiveFocusSession { result in
            Task { @MainActor in
                switch result {
                case .success(let session):
                    guard let session else {
                        viewModel.setQuickView(.today)
                        logWarning(
                            event: "focus_session_resume_missing",
                            message: "Expected an active focus session to resume, but none was found",
                            fields: ["source": source]
                        )
                        snackbar = SnackbarData(message: "No active focus timer was found")
                        return
                    }
                    activeNextActionFocusSession = session
                    showNextActionFocusTimer = true
                case .failure(let error):
                    logWarning(
                        event: "focus_session_resume_failed",
                        message: "Failed to resume active focus session",
                        fields: [
                            "source": source,
                            "error": error.localizedDescription
                        ]
                    )
                    snackbar = SnackbarData(message: "Couldn't resume focus timer")
                }
            }
        }
    }

    private func finishNextActionFocusSession(sessionID: UUID, source: String) {
        guard isNextActionFocusEnding == false else { return }
        isNextActionFocusEnding = true
        viewModel.endFocusSession(sessionID: sessionID) { result in
            Task { @MainActor in
                isNextActionFocusEnding = false
                switch result {
                case .success(let focusResult):
                    showNextActionFocusTimer = false
                    activeNextActionFocusSession = nil
                    viewModel.trackHomeInteraction(
                        action: "focus_session_finished",
                        metadata: [
                            "source": source,
                            "duration_seconds": focusResult.session.durationSeconds,
                            "awarded_xp": focusResult.xpResult?.awardedXP ?? 0
                        ]
                    )
                    nextActionFocusSummaryResult = focusResult
                    showNextActionFocusSummary = true
                case .failure(let error):
                    logWarning(
                        event: "focus_session_end_failed",
                        message: "Failed to end focus session from next action module",
                        fields: [
                            "source": source,
                            "error": error.localizedDescription
                        ]
                    )
                    snackbar = SnackbarData(message: "Couldn't finish focus timer")
                    showNextActionFocusTimer = false
                    activeNextActionFocusSession = nil
                }
            }
        }
    }

    private func dismissNextActionFocusSummary() {
        showNextActionFocusSummary = false
        nextActionFocusSummaryResult = nil
    }

    private func resolveTaskForFocusSession(taskID: UUID?) -> TaskDefinition? {
        guard let taskID else { return nil }
        var candidates: [TaskDefinition] = []
        candidates.append(contentsOf: viewModel.focusTasks)
        candidates.append(contentsOf: viewModel.morningTasks)
        candidates.append(contentsOf: viewModel.eveningTasks)
        candidates.append(contentsOf: viewModel.overdueTasks)
        return candidates.first(where: { $0.id == taskID })
    }

    @ViewBuilder
    private var reflectPlanPresentation: some View {
        if let dailyReflectPlanViewModel {
            SunriseReflectPlanScreen(
                viewModel: dailyReflectPlanViewModel,
                onClose: {
                    showDailyReflectPlan = false
                }
            )
        } else {
            Color.clear
                .ignoresSafeArea()
                .onAppear {
                    showDailyReflectPlan = false
                }
        }
    }

    private func openDailyReflectPlan(preferredReflectionDate: Date? = nil) {
        dailyReflectPlanViewModel = PresentationDependencyContainer.shared.makeDailyReflectPlanViewModel(
            preferredReflectionDate: preferredReflectionDate,
            analyticsTracker: { action, metadata in
                viewModel.trackHomeInteraction(action: action, metadata: metadata.reduce(into: [String: Any]()) { partialResult, item in
                    partialResult[item.key] = item.value
                })
            },
            onComplete: { result in
                viewModel.refreshAfterDailyReflectPlanSave(planningDate: result.target.planningDate)
                showDailyReflectPlan = false
            }
        )
        showDailyReflectPlan = true
    }
}

private struct CalendarCardChromeModifier: ViewModifier {
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, spacing.s16)
            .padding(.vertical, spacing.s12)
            .background(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.lifeboard.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.card, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)
            )
    }
}

private extension InsightsActionIntent {
    var telemetryName: String {
        switch self {
        case .addTask:
            return "add_task"
        case .openToday:
            return "open_today"
        case .startNextDecision:
            return "start_next_decision"
        case .protectFocus:
            return "protect_focus"
        case .openYesterdayReview:
            return "open_yesterday_review"
        case .openHabitCheck:
            return "open_habit_check"
        case .openBacklogRecovery:
            return "open_backlog_recovery"
        case .openProjectMix:
            return "open_project_mix"
        case .openWeeklyReview:
            return "open_weekly_review"
        case .openWeeklyPlanner:
            return "open_weekly_planner"
        case .openReminderSettings:
            return "open_reminder_settings"
        case .expandDetails(let anchor):
            return "expand_details_\(anchor.rawValue)"
        }
    }
}

private struct HomeStaggerModifier: ViewModifier {
    let isEnabled: Bool
    let index: Int

    func body(content: Content) -> some View {
        if isEnabled {
            content.enhancedStaggeredAppearance(index: index)
        } else {
            content
        }
    }
}

private struct HomeDenseSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: cornerRadius
                )
                .fill(Color.lifeboard.surfaceTertiary)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: cornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: cornerRadius
                    )
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.35), lineWidth: 1)
                )
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: cornerRadius
                )
            )
    }
}

private struct QuietTrackingRailStreakWidget: View {
    let card: QuietTrackingRailCardPresentation
    let slotWidth: CGFloat
    let visibleDayCount: Int

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    private var isExpandedType: Bool {
        dynamicTypeSize >= .accessibility1
    }

    private var widgetVerticalPadding: CGFloat {
        isExpandedType ? 6 : spacing.s4
    }

    private var visibleCells: [HabitBoardCell] {
        card.visibleCells(dayCount: visibleDayCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HabitBoardStripView(
                cells: visibleCells,
                family: card.colorFamily,
                mode: .compact
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: card.iconSymbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.lifeboard.textSecondary.opacity(0.82))
                    .accessibilityHidden(true)

                Text(card.title)
                    .font(.lifeboard(.caption2).weight(.medium))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(isExpandedType ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: slotWidth, alignment: .leading)
        .frame(minHeight: 44, alignment: .topLeading)
        .padding(.vertical, widgetVerticalPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityValue(card.accessibilityValue(visibleDayCount: visibleDayCount))
    }
}

private struct OverdueRescueLauncherOverlayView: View {
    let title: String
    let message: String
    let showsProgress: Bool
    let primaryTitle: String?
    let secondaryTitle: String?
    let onPrimary: (() -> Void)?
    let onSecondary: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.94, blue: 0.82),
                                    Color(red: 0.92, green: 0.88, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)

                    Image(systemName: showsProgress ? "lifepreserver" : "exclamationmark.triangle")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.lifeboard(.title3).weight(.bold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showsProgress {
                    ProgressView()
                        .tint(Color.lifeboard.accentPrimary)
                        .accessibilityLabel("Preparing rescue")
                } else if primaryTitle != nil || secondaryTitle != nil {
                    HStack(spacing: 12) {
                        if let secondaryTitle, let onSecondary {
                            Button(action: onSecondary) {
                                Text(secondaryTitle)
                                    .font(.lifeboard(.callout).weight(.semibold))
                                    .foregroundStyle(Color.lifeboard.accentPrimary)
                                    .frame(minWidth: 96, minHeight: 44)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .stroke(Color.lifeboard.accentPrimary.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if let primaryTitle, let onPrimary {
                            Button(action: onPrimary) {
                                Text(primaryTitle)
                                    .font(.lifeboard(.callout).weight(.semibold))
                                    .foregroundStyle(Color.white)
                                    .frame(minWidth: 112, minHeight: 44)
                                    .padding(.horizontal, 14)
                                    .background(
                                        Capsule()
                                            .fill(Color.lifeboard.accentPrimary)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.985, blue: 0.955).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 28, x: 0, y: 18)
            )
            .padding(.horizontal, 28)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
            .accessibilityHint(message)
        }
    }
}
