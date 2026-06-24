//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

extension HomeViewModel {
    public func selectDate(_ date: Date, source: HomeDateNavigationSource = .datePicker) {
        applySelectedDay(date, source: source, trackAnalytics: source == .swipe)
    }

    public func shiftSelectedDay(
        byDays days: Int,
        source: HomeDateNavigationSource = .swipe
    ) {
        guard days != 0 else { return }
        let baseDay = normalizedDay(selectedDate)
        let targetDay = Calendar.current.date(byAdding: .day, value: days, to: baseDay) ?? baseDay
        selectDate(targetDay, source: source)
    }

    public func returnToToday(source: HomeDateNavigationSource = .backToToday) {
        applySelectedDay(Date(), source: source, trackAnalytics: source == .backToToday, forceReload: true)
    }

    func applySelectedDay(
        _ day: Date,
        source: HomeDateNavigationSource,
        trackAnalytics: Bool,
        forceReload: Bool = false
    ) {
        applySelectedDay(
            day,
            source: source,
            trackAnalytics: trackAnalytics,
            generation: nextReloadGeneration(),
            forceReload: forceReload
        )
    }

    func applySelectedDay(
        _ day: Date,
        source: HomeDateNavigationSource,
        trackAnalytics: Bool,
        generation: Int,
        forceReload: Bool = false
    ) {
        scheduleRecurringTopUpIfNeeded()

        let targetDay = normalizedDay(day)
        let targetScope: HomeListScope = Calendar.current.isDateInToday(targetDay) ? .today : .customDate(targetDay)
        let currentDay = normalizedDay(selectedDate)
        let isSameDay = Calendar.current.isDate(currentDay, inSameDayAs: targetDay)
        let alreadySelected = isSameDay && activeScope == targetScope && activeFilterState.quickView == .today

        guard alreadySelected == false || forceReload else {
            LifeBoardPerformanceTrace.event("HomeDaySwipeCancelled")
            return
        }

        performHomeRenderStateBatch {
            focusEngineEnabled = true
            activeScope = targetScope
            selectedDate = targetDay
            var state = activeFilterState
            state.quickView = .today
            state.selectedSavedViewID = nil
            // Returning to a day timeline always exits a forward "stream" lens
            // (Upcoming / per-project), so picking a date or swiping days never
            // strands the user in the stream view.
            if state.streamsAllForward {
                state.streamsAllForward = false
                state.selectedProjectIDs = []
                state.selectedLifeAreaIDs = []
            }
            activeFilterState = state
        }

        persistLastFilterState()
        if isSameDay {
            calendarIntegrationService.refreshContext(
                referenceDate: targetDay,
                reason: "home_selected_date_changed_\(source.rawValue)"
            )
        }
        if source == .swipe {
            LifeBoardPerformanceTrace.event("HomeDaySwipeCommitted")
        }
        applyFocusFilters(trackAnalytics: trackAnalytics, generation: generation)
        if Calendar.current.isDateInToday(targetDay) {
            loadDailyAnalytics()
        }
    }

    /// Change selected project filter (legacy path).

    public func selectProject(_ projectName: String) {
        selectedProject = projectName

        if projectName == "All" {
            focusEngineEnabled = true
            applyFocusFilters(trackAnalytics: false)
        } else {
            focusEngineEnabled = true
            if let project = projects.first(where: { $0.name.caseInsensitiveCompare(projectName) == .orderedSame }) {
                setProjectFilters([project.id])
            } else {
                applyFocusFilters(trackAnalytics: false)
            }
        }
    }

    /// Focus Engine: set quick view.

    public func setQuickView(_ quickView: HomeQuickView) {
        if quickView == .today {
            applySelectedDay(Date(), source: .datePicker, trackAnalytics: true)
            return
        }

        focusEngineEnabled = true
        activeScope = .fromQuickView(quickView)
        var state = activeFilterState
        state.quickView = quickView
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

}
