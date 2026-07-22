//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

extension SunriseAppShellView {
    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).corner }

    var forcedFaceValue: HomeSunriseFace? { forcedFace?.wrappedValue }

    var chromeSnapshot: HomeChromeSnapshot { chromeStore.snapshot }

    var tasksSnapshot: HomeTasksSnapshot { tasksStore.snapshot }

    var habitsSnapshot: HomeHabitsSnapshot { habitsStore.snapshot }

    var calendarSnapshot: HomeCalendarSnapshot { calendarStore.snapshot }

    var timelineRenderState: HomeTimelineRenderState { timelineStore.state }

    var overlaySnapshot: HomeOverlaySnapshot { overlayStore.snapshot }

    var activeFace: HomeSunriseFace { faceCoordinator.activeFace }

    var shellPhase: HomeShellPhase { faceCoordinator.shellPhase }

    var analyticsSurfaceState: HomeAnalyticsSurfaceState { faceCoordinator.analyticsSurfaceState }

    var searchSurfaceState: HomeSearchSurfaceState { faceCoordinator.searchSurfaceState }

    var layoutMetrics: HomeLayoutMetrics { faceCoordinator.layoutMetrics }

    var isUITesting: Bool {
        Self.launchArguments.contains("-UI_TESTING") || Self.launchArguments.contains("-DISABLE_ANIMATIONS")
    }

    var shouldPresentHabitBoardForUITests: Bool {
        Self.launchArguments.contains("-LIFEBOARD_TEST_PRESENT_HABIT_BOARD")
    }

    var isSunriseHintAnimationEnabled: Bool {
        Self.launchArguments.contains("-ENABLE_FOREDROP_HINT_ANIMATION")
    }

    var sunriseAnchorForHint: SunriseAnchor {
        activeFace == .tasks ? timelineViewModel.sunriseAnchor : .fullReveal
    }

    var isSearchOpen: Bool { activeFace == .search }

    var isInsightsOpen: Bool { activeFace == .analytics }

    var isChatOpen: Bool { activeFace == .chat }

    var shouldAttachSecondaryFaceToTop: Bool { isSearchOpen || isInsightsOpen }

    var isBackFaceVisible: Bool { activeFace.isBackFace }

    var isScheduleFaceVisible: Bool { activeFace == .schedule }

    var isTodayTimelineVisible: Bool {
        activeFace == .tasks && tasksSnapshot.activeQuickView == .today
    }

    var isTaskFaceVisible: Bool { activeFace == .tasks }

    var isDaySwipeChromeAvailable: Bool {
        isTaskFaceVisible || isScheduleFaceVisible
    }

    var isRescueEnabled: Bool { V2FeatureFlags.evaRescueEnabled }

    var visibleAgendaTailItems: [HomeAgendaTailItem] {
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
            ? String(localized: "home.rescue.subtitle.singular")
            : String.localizedStringWithFormat(
                String(localized: "home.rescue.subtitle.plural"),
                rescueRows.count
            )
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

    func isTimelineRescueEligibleTask(_ task: TaskDefinition) -> Bool {
        OverdueRescueEligibilityPolicy.isStaleOverdueTask(
            task,
            referenceDate: chromeSnapshot.selectedDate
        )
    }

    func compareTimelineRescueRows(_ lhs: HomeTodayRow, _ rhs: HomeTodayRow) -> Bool {
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

    var lifeAreasByID: [UUID: LifeArea] {
        Dictionary(viewModel.lifeAreas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var agendaTailExpansionResetKey: String {
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

    var habitRenderSignature: String {
        let primary = habitsSnapshot.habitHomeSectionState.primaryRows.map { "\($0.id):\($0.state.rawValue)" }.joined(separator: "|")
        let recovery = habitsSnapshot.habitHomeSectionState.recoveryRows.map { "\($0.id):\($0.state.rawValue)" }.joined(separator: "|")
        let quiet = habitsSnapshot.quietTrackingSummaryState.stableRows.map { "\($0.id):\($0.state.rawValue)" }.joined(separator: "|")
        return "\(primary)#\(recovery)#\(quiet)"
    }

    var timelineLayoutMetrics: HomeSunriseLayoutMetrics {
        HomeSunriseLayoutMetrics(
            calendarExpandedHeight: measuredCalendarCardHeight,
            timelineHeaderHeight: measuredTimelineHeaderHeight,
            weeklyBackdropHeight: measuredWeekBackdropHeight,
            geometryHeight: layoutMetrics.height
        )
    }

    var timelineSnapshot: HomeTimelineSnapshot {
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

    var isDaySwipeGestureEnabled: Bool {
        guard isTaskFaceVisible || isScheduleFaceVisible else { return false }
        guard showDatePicker == false, showAdvancedFilters == false, showManageLensLifeAreas == false else { return false }
        guard overlaySnapshot.replanState.isApplying == false else { return false }
        if case .placement = overlaySnapshot.replanState.phase {
            return false
        }
        return true
    }

    var isDaySwipeInteractionEnabled: Bool {
        isDaySwipeGestureEnabled && isDaySunriseSwipeChromeVisible
    }

    var daySwipeAnimation: Animation {
        if reduceMotion || isUITesting {
            return .easeOut(duration: 0.12)
        }
        return .snappy(duration: 0.22)
    }

    var daySwipeTransition: AnyTransition {
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

    var passiveTrackingRailFallbackHeight: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 72 : 56
    }

    var needsReplanTrayFallbackHeight: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 120 : 88
    }

    var isNeedsReplanTrayVisible: Bool {
        if case .trayVisible = overlaySnapshot.replanState.phase {
            return true
        }
        return false
    }

    var daySunriseSwipeRestingCenterY: CGFloat {
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
    var needsReplanFloatingOverlay: some View {
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

    var sunriseInteractiveOffset: CGFloat {
        guard isTodayTimelineVisible else { return 0 }
        return timelineViewModel.interactiveOffset(metrics: timelineLayoutMetrics)
    }

    var secondaryFaceTopContentInset: CGFloat {
        max(0, layoutMetrics.safeAreaTop + spacing.s8 - 8)
    }

    var sunriseSurfaceCornerRadius: CGFloat {
        shouldAttachSecondaryFaceToTop ? 0 : corner.modal
    }

    var sunriseFlipAnimation: Animation {
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

    var sunriseDatePickerDropdown: some View {
        ZStack(alignment: .top) {
            Color.lifeboard(.textPrimary).opacity(0.001)
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

    var sunriseDatePickerTopPadding: CGFloat {
        let safeHeaderTop = max(layoutMetrics.safeAreaTop, 54)
        return safeHeaderTop + (dynamicTypeSize.isAccessibilitySize ? 204 : 158)
    }
}
