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
    public func performEndOfDayCleanup(completion: @escaping @Sendable (Result<CleanupResult, Error>) -> Void) {
        useCaseCoordinator.performEndOfDayCleanup { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let cleanup):
                    self?.enqueueReload(
                        source: "end_of_day_cleanup",
                        reason: .bulkChanged,
                        invalidateCaches: true,
                        includeAnalytics: true,
                        repostEvent: true
                    )
                    completion(.success(cleanup))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Focus Engine: set Today grouping mode.

    public func setProjectGroupingMode(_ mode: HomeProjectGroupingMode) {
        focusEngineEnabled = true
        var state = activeFilterState
        guard state.projectGroupingMode != mode else { return }
        state.projectGroupingMode = mode
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: set explicit custom project section order (Inbox excluded).

    public func setCustomProjectOrder(_ orderedProjectIDs: [UUID]) {
        focusEngineEnabled = true
        var state = activeFilterState
        let normalizedOrder = normalizedCustomProjectOrder(
            from: orderedProjectIDs,
            currentOrder: state.customProjectOrderIDs,
            availableProjects: projects
        )
        guard state.customProjectOrderIDs != normalizedOrder else { return }
        state.customProjectOrderIDs = normalizedOrder
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: toggle a project facet chip (OR across selected IDs).

    public func toggleProjectFilter(_ projectID: UUID) {
        focusEngineEnabled = true
        var ids = activeFilterState.selectedProjectIDs

        if let index = ids.firstIndex(of: projectID) {
            ids.remove(at: index)
        } else {
            ids.append(projectID)
        }

        var state = activeFilterState
        state.selectedProjectIDs = ids
        state.selectedSavedViewID = nil
        activeFilterState = state

        bumpPinnedProject(projectID)
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: set explicit selected project IDs.

    public func setProjectFilters(_ projectIDs: [UUID]) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.selectedProjectIDs = Array(Set(projectIDs))
        state.selectedSavedViewID = nil
        activeFilterState = state

        for id in projectIDs {
            bumpPinnedProject(id)
        }

        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: clear project filter facets.

    public func clearProjectFilters() {
        focusEngineEnabled = true
        var state = activeFilterState
        state.selectedProjectIDs = []
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        trackFeatureUsage(action: "home_filter_cleared", metadata: ["scope": "projects"])
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: apply advanced composable filter.

    public func applyAdvancedFilter(_ filter: HomeAdvancedFilter?, showCompletedInline: Bool? = nil) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.advancedFilter = filter?.isEmpty == false ? filter : nil
        if let showCompletedInline {
            state.showCompletedInline = showCompletedInline
        }
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: set show completed inline flag.

    public func setShowCompletedInline(_ value: Bool) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.showCompletedInline = value
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: save current filter state as a reusable view.

    public func saveCurrentFilterAsView(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Saved view name cannot be empty"
            return
        }

        if savedHomeViews.count >= 20 {
            errorMessage = "You can save up to 20 Home views"
            return
        }

        let now = Date()
        let saved = SavedHomeView(
            name: trimmedName,
            quickView: activeFilterState.quickView,
            selectedProjectIDs: activeFilterState.selectedProjectIDs,
            advancedFilter: activeFilterState.advancedFilter,
            showCompletedInline: activeFilterState.showCompletedInline,
            createdAt: now,
            updatedAt: now
        )

        savedHomeViewRepository.save(saved) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let views):
                    self?.savedHomeViews = views.sorted { $0.updatedAt > $1.updatedAt }
                    self?.trackFeatureUsage(action: "home_filter_saved_view_created", metadata: ["name": trimmedName])
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Focus Engine: apply a previously saved filter state.

    public func applySavedView(id: UUID) {
        guard let saved = savedHomeViews.first(where: { $0.id == id }) else {
            return
        }

        focusEngineEnabled = true
        activeScope = .fromQuickView(saved.quickView)
        var restoredState = saved.asFilterState(pinnedProjectIDs: activeFilterState.pinnedProjectIDs)
        restoredState.projectGroupingMode = activeFilterState.projectGroupingMode
        restoredState.customProjectOrderIDs = activeFilterState.customProjectOrderIDs
        activeFilterState = restoredState
        persistLastFilterState()
        trackFeatureUsage(action: "home_filter_saved_view_used", metadata: ["id": id.uuidString])
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: delete a saved filter view.

    public func deleteSavedView(id: UUID) {
        savedHomeViewRepository.delete(id: id) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let views):
                    self?.savedHomeViews = views.sorted { $0.updatedAt > $1.updatedAt }
                    if self?.activeFilterState.selectedSavedViewID == id {
                        self?.activeFilterState.selectedSavedViewID = nil
                        self?.persistLastFilterState()
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Focus Engine: reset all filters to default state.

    public func resetAllFilters() {
        focusEngineEnabled = true
        activeScope = .today
        selectedDate = Date()
        activeFilterState = .default
        persistLastFilterState()
        trackFeatureUsage(action: "home_filter_reset", metadata: [:])
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: load saved views from persistence.

    public func loadSavedViews() {
        savedHomeViewRepository.fetchAll { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let views):
                    self?.savedHomeViews = views.sorted { $0.updatedAt > $1.updatedAt }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Focus Engine: restore last persisted filter state.

    public func restoreLastFilterState() {
        guard let data = userDefaults.data(forKey: Self.lastFilterStateKey) else {
            activeFilterState = .default
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decoded = try decoder.decode(HomeFilterState.self, from: data)
            guard decoded.version == HomeFilterState.schemaVersion else {
                activeFilterState = .default
                return
            }
            activeFilterState = sanitizeFilterState(decoded, availableProjects: projects)
        } catch {
            activeFilterState = .default
        }
    }

    /// Load all projects.

    public func loadProjects() {
        loadProjects(generation: nextReloadGeneration())
    }

    /// Executes loadProjects.

    func loadProjects(generation: Int) {
        let interval = LifeBoardPerformanceTrace.begin("HomeLoadProjects")
        useCaseCoordinator.manageProjects.getAllProjects { [weak self] result in
            let preparedResult = result.map { projectsWithStats in
                projectsWithStats.map { $0.project }
            }
            Task { @MainActor in
                defer { LifeBoardPerformanceTrace.end(interval) }
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=projects generation=\(generation)")
                    return
                }
                switch preparedResult {
                case .success(let loadedProjects):
                    self.assignIfChanged(\.projects, loadedProjects)
                    self.seedPinnedProjectsIfNeeded(from: loadedProjects)
                    self.normalizeCustomProjectOrderIfNeeded(from: loadedProjects)

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadLifeAreas.

    func loadLifeAreas(generation: Int) {
        useCaseCoordinator.manageLifeAreas.list { [weak self] result in
            let preparedResult = result.map { loadedLifeAreas in
                loadedLifeAreas
                    .filter { !$0.isArchived }
                    .sorted {
                        if $0.sortOrder != $1.sortOrder {
                            return $0.sortOrder < $1.sortOrder
                        }
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
            }
            Task { @MainActor in
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else { return }

                switch preparedResult {
                case .success(let sortedLifeAreas):
                    self.assignIfChanged(\.lifeAreas, sortedLifeAreas)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadTags.

    func loadTags(generation: Int) {
        let interval = LifeBoardPerformanceTrace.begin("HomeLoadTags")
        useCaseCoordinator.manageTags.list { [weak self] result in
            let preparedResult = result.map { loadedTags in
                loadedTags.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }
            Task { @MainActor in
                defer { LifeBoardPerformanceTrace.end(interval) }
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=tags generation=\(generation)")
                    return
                }

                switch preparedResult {
                case .success(let sortedTags):
                    self.assignIfChanged(\.tags, sortedTags)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Clears task-related cache entries to force fresh reads.

    public func invalidateTaskCaches() {
        useCaseCoordinator.cacheService?.clearAll()
        useCaseCoordinator.calculateAnalytics.invalidateCaches()
        homeFilteredTasksUseCase.invalidateCaches()
        dataRevision.advance()
        cachedGlobalReplanRevision = nil
        LifeBoardPerformanceTrace.event("HomeDataInvalidated")
        logDebug("HOME_CACHE invalidated scope=all")
    }

    /// Executes completionOverride.

    func completionOverride(for taskID: UUID) -> Bool? {
        completionOverrides[taskID]
    }

    /// Load upcoming tasks for legacy upcoming mode.

    public func loadUpcomingTasks() {
        focusEngineEnabled = true
        setQuickView(.upcoming)
    }

    /// Load completed tasks for legacy history mode.

    public func loadCompletedTasks() {
        focusEngineEnabled = true
        setQuickView(.done)
    }

    /// Complete morning routine.

    public func completeMorningRoutine(completion: (@Sendable (Result<MorningRoutineResult, Error>) -> Void)? = nil) {
        useCaseCoordinator.completeMorningRoutine { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let routineResult):
                    self?.dailyScore += routineResult.totalScore
                    self?.refreshProgressState()
                    self?.loadTodayTasks()
                    completion?(.success(routineResult))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }
    }

    /// Reschedule all overdue tasks.
}
