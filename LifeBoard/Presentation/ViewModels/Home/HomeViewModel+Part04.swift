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
    public func createTaskDefinition(
        request: CreateTaskDefinitionRequest,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.createTaskDefinition.execute(request: request) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let createdTask):
                    self?.enqueueReload(
                        source: "create_task_definition",
                        reason: .created,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(createdTask))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes createTagForTaskDetail.

    public func createTagForTaskDetail(
        name: String,
        completion: @escaping @Sendable (Result<TagDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.manageTags.create(name: name, color: nil, icon: nil) { [weak self] result in
            Task { @MainActor in
                if case .success(let createdTag) = result {
                    self?.upsertTag(createdTag)
                }
                completion(result)
            }
        }
    }

    /// Executes createProjectForTaskDetail.

    public func createProjectForTaskDetail(
        name: String,
        completion: @escaping @Sendable (Result<Project, Error>) -> Void
    ) {
        useCaseCoordinator.manageProjects.createProject(request: CreateProjectRequest(name: name)) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let project):
                    self?.loadProjects()
                    completion(.success(project))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// Track Home interactions from view-layer events (animations, collapse toggles, etc.).

    public func trackHomeInteraction(action: String, metadata: [String: Any] = [:]) {
        trackFeatureUsage(action: action, metadata: metadata)
    }

    public var canUseManualFocusDrag: Bool {
        false
    }

    /// Executes pinTaskToFocus.

    @discardableResult
    public func pinTaskToFocus(_ taskID: UUID) -> FocusPinResult {
        guard activeScope.quickView == .today else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        if pinnedFocusTaskIDs.contains(taskID) {
            return .alreadyPinned
        }

        if pinnedFocusTaskIDs.count >= Self.maxPinnedFocusTasks {
            return .capacityReached(limit: Self.maxPinnedFocusTasks)
        }

        pinnedFocusTaskIDs.append(taskID)
        persistPinnedFocusTaskIDs()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshTodayAgendaForCurrentFocusSelection()
        refreshEvaInsights(openTasks: openTasks)
        return .pinned
    }

    /// Executes unpinTaskFromFocus.

    public func unpinTaskFromFocus(_ taskID: UUID) {
        guard pinnedFocusTaskIDs.contains(taskID) else { return }
        pinnedFocusTaskIDs.removeAll { $0 == taskID }
        persistPinnedFocusTaskIDs()
        let openTasks = focusOpenTasksForCurrentState()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshTodayAgendaForCurrentFocusSelection()
        refreshEvaInsights(openTasks: openTasks)
    }

    public func promoteTaskToFocus(_ taskID: UUID) -> FocusPromotionResult {
        guard activeScope.quickView == .today else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        if pinnedFocusTaskIDs.contains(taskID) {
            return .alreadyPinned
        }

        let currentFocus = composedFocusTasks(from: openTasks)
        if currentFocus.contains(where: { $0.id == taskID }) {
            if pinnedFocusTaskIDs.count >= Self.maxPinnedFocusTasks {
                return .alreadyVisible
            }

            pinnedFocusTaskIDs.append(taskID)
            persistPinnedFocusTaskIDs()
            updateFocusSelection(composedFocusTasks(from: openTasks))
            refreshTodayAgendaForCurrentFocusSelection()
            refreshEvaInsights(openTasks: openTasks)
            return .promoted
        }

        if pinnedFocusTaskIDs.count < Self.maxPinnedFocusTasks {
            pinnedFocusTaskIDs.append(taskID)
            persistPinnedFocusTaskIDs()
            updateFocusSelection(composedFocusTasks(from: openTasks))
            refreshTodayAgendaForCurrentFocusSelection()
            refreshEvaInsights(openTasks: openTasks)
            return .promoted
        }

        return .replacementRequired(currentFocusTaskIDs: Array(currentFocus.prefix(Self.maxPinnedFocusTasks).map(\.id)))
    }

    public func replaceFocusTask(with taskID: UUID, replacing replacedTaskID: UUID) -> FocusPromotionResult {
        guard activeScope.quickView == .today else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        let currentFocus = composedFocusTasks(from: openTasks)
        guard currentFocus.contains(where: { $0.id == replacedTaskID }) else {
            return .taskIneligible
        }

        if taskID == replacedTaskID {
            return .alreadyVisible
        }

        let curatedFocusIDs = [taskID] + currentFocus
            .map(\.id)
            .filter { $0 != taskID && $0 != replacedTaskID }
        pinnedFocusTaskIDs = normalizedPinnedFocusTaskIDs(curatedFocusIDs)
        persistPinnedFocusTaskIDs()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshTodayAgendaForCurrentFocusSelection()
        refreshEvaInsights(openTasks: openTasks)
        return .promoted
    }

    @discardableResult
    public func commitFocusNowSet(taskIDs: [UUID], source: String) -> Bool {
        guard activeScope.quickView == .today else { return false }

        let openTasks = focusOpenTasksForCurrentState()
        let openByID = Dictionary(uniqueKeysWithValues: openTasks.map { ($0.id, $0) })
        var seen = Set<UUID>()
        let committedIDs = Array(taskIDs.filter { id in
            openByID[id] != nil && seen.insert(id).inserted
        }.prefix(Self.maxPinnedFocusTasks))
        guard committedIDs.isEmpty == false else { return false }

        pinnedFocusTaskIDs = normalizedPinnedFocusTaskIDs(committedIDs)
        persistPinnedFocusTaskIDs()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshTodayAgendaForCurrentFocusSelection()
        refreshEvaInsights(openTasks: openTasks)
        reloadTaskListWidgetTimelines()
        trackHomeInteraction(action: "focus_now_set_committed", metadata: [
            "source": source,
            "focus_count": committedIDs.count
        ])
        return true
    }

    /// Change selected date.

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

    public func taskSnapshot(for taskID: UUID) -> TaskDefinition? {
        currentTaskSnapshot(for: taskID)
    }

    public func loadDailySummaryModal(
        kind: LifeBoardDailySummaryKind,
        dateStamp: String?,
        completion: @escaping @Sendable (Result<DailySummaryModalData, Error>) -> Void
    ) {
        let date = Self.summaryDate(from: dateStamp) ?? Date()
        let normalizedDateStamp = Self.summaryDateStamp(from: date)

        getDailySummaryModalUseCase.execute(kind: kind, date: date) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let summary):
                    self?.trackHomeInteraction(
                        action: "daily_summary_modal_opened",
                        metadata: [
                            "kind": kind.rawValue,
                            "date_stamp": normalizedDateStamp,
                            "source": "notification",
                            "snapshot": summary.analyticsSnapshot.metadataValue
                        ]
                    )
                    completion(.success(summary))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func trackDailySummaryCTA(
        kind: LifeBoardDailySummaryKind,
        cta: String,
        countsSnapshot: DailySummaryAnalyticsSnapshot
    ) {
        trackHomeInteraction(
            action: "daily_summary_cta_tapped",
            metadata: [
                "kind": kind.rawValue,
                "cta": cta,
                "counts_snapshot": countsSnapshot.metadataValue
            ]
        )
    }

    public func trackDailySummaryActionResult(cta: String, success: Bool, error: Error?) {
        trackDailySummaryActionResult(cta: cta, success: success, errorDescription: error?.localizedDescription)
    }

    public func trackDailySummaryActionResult(cta: String, success: Bool, errorDescription: String?) {
        var metadata: [String: Any] = [
            "cta": cta,
            "success": success
        ]
        if let errorDescription {
            metadata["error"] = errorDescription
        }
        trackHomeInteraction(
            action: "daily_summary_action_result",
            metadata: metadata
        )
    }
}
