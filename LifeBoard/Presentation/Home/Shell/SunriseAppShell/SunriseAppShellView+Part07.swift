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
    func trackSearchResultOpened(_ task: TaskDefinition, projectName: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_result_opened",
            metadata: [
                "task_id": task.id.uuidString,
                "project": projectName
            ]
        )
    }

    var shouldShowInboxTriageAction: Bool {
        V2FeatureFlags.evaRescueEnabled && chromeSnapshot.activeScope.quickView == .today
    }

    var taskListHorizontalGutter: CGFloat {
        LifeBoardTheme.Spacing.lg
    }

    func fullBleedTaskListHeaderModule<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, -taskListHorizontalGutter)
    }

    @ViewBuilder
    var taskListScrollHeader: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            if let guidanceState = overlaySnapshot.guidanceState {
                HomeOnboardingGuidanceBanner(state: guidanceState)
                    .padding(.top, spacing.s8)
                    .modifier(HomeStaggerModifier(isEnabled: shellPhase == .interactive, index: 3))
            }
        }
    }

    var timelineColumnMaxWidth: CGFloat? {
        HomeTimelineColumnLayout.maxWidth(for: layoutClass)
    }

    var timelineHasNextHomeWidget: Bool {
        true
    }

    @ViewBuilder
    func timelineColumnContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if let maxWidth = timelineColumnMaxWidth {
            content()
                .frame(maxWidth: maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content()
        }
    }

    func beginDaySwipeTrace() {
        guard isDaySwipeTracingActive == false else { return }
        isDaySwipeTracingActive = true
        LifeBoardPerformanceTrace.event("HomeDaySwipeStarted")
    }

    func cancelDaySwipeTraceIfNeeded() {
        guard isDaySwipeTracingActive else { return }
        LifeBoardPerformanceTrace.event("HomeDaySwipeCancelled")
        isDaySwipeTracingActive = false
    }

    var daySunriseSwipeContainerSize: CGSize {
        CGSize(
            width: max(layoutMetrics.width, 1),
            height: max(layoutMetrics.height - measuredTimelineHeaderHeight, 1)
        )
    }

    func normalizedDaySunriseSwipeSize(_ size: CGSize) -> CGSize {
        let fallback = daySunriseSwipeContainerSize
        return CGSize(
            width: max(size.width, fallback.width, 1),
            height: max(size.height, fallback.height, 1)
        )
    }

    func daySunriseSwipeData(for side: SunriseDaySwipeSide, size: CGSize) -> SunriseDaySwipeData {
        let data = side == .leading ? leadingDaySunriseSwipeData : trailingDaySunriseSwipeData
        return data
            .resting(at: daySunriseSwipeRestingCenterY)
            .sized(to: size)
    }

    func setDaySunriseSwipeData(_ data: SunriseDaySwipeData) {
        switch data.side {
        case .leading:
            leadingDaySunriseSwipeData = data
        case .trailing:
            trailingDaySunriseSwipeData = data
        }
    }

    func handleTimelineScrollOffsetChange(_ newOffset: CGFloat) {
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

    func updateDaySunriseSwipeChromeVisibility(for state: HomeScrollChromeState) {
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

    func resetDaySunriseSwipeChromeVisibility() {
        timelineScrollChromeStateTracker = HomeScrollChromeStateTracker()
        lastTimelineScrollOffsetY = nil
        isDaySunriseSwipeChromeVisible = true
    }

    func updateDaySunriseSwipe(
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

    func endDaySunriseSwipe(
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

    func cancelDaySunriseSwipe(side: SunriseDaySwipeSide, size: CGSize) {
        activeDaySunriseSwipeSide = nil
        cancelDaySwipeTraceIfNeeded()
        resetDaySunriseSwipe(side, size: normalizedDaySunriseSwipeSize(size))
    }

    func resetDaySunriseSwipe(_ side: SunriseDaySwipeSide, size: CGSize) {
        let data = daySunriseSwipeData(for: side, size: size).initial()
        if reduceMotion || isUITesting {
            setDaySunriseSwipeData(data)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                setDaySunriseSwipeData(data)
            }
        }
    }

    func resetIdleDaySunriseSwipeHandles(restingCenterY: CGFloat) {
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

    func commitDaySunriseSwipe(_ side: SunriseDaySwipeSide, size: CGSize) {
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

    func commitDaySwipe(_ direction: HomeDayNavigationDirection) {
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

    func shiftSunriseSelectedDay(by dayOffset: Int) {
        guard dayOffset != 0 else { return }
        LifeBoardFeedback.selection()
        withAnimation(daySwipeAnimation) {
            viewModel.shiftSelectedDay(byDays: dayOffset, source: .datePicker)
        }
    }
}
