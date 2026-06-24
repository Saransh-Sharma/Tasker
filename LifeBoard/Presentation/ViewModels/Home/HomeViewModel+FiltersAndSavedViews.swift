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

        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Sets the pinned lens life areas directly (used by the Manage Life Areas sheet).
    public func setPinnedLifeAreas(_ lifeAreaIDs: [UUID]) {
        var unique: [UUID] = []
        for id in lifeAreaIDs where unique.contains(id) == false {
            unique.append(id)
        }
        let capped = Array(unique.prefix(5))
        guard activeFilterState.pinnedLifeAreaIDs != capped else { return }
        activeFilterState.pinnedLifeAreaIDs = capped
        persistLastFilterState()
        trackFeatureUsage(action: "home_lens_life_areas_pinned", metadata: ["count": "\(capped.count)"])
        scheduleHomeRenderStateRefresh()
    }

    public func createLifeArea(
        name: String,
        completion: @escaping @Sendable (Result<LifeArea, Error>) -> Void
    ) {
        let generation = reloadGeneration
        useCaseCoordinator.manageLifeAreas.create(name: name, color: nil, icon: "square.grid.2x2") { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let area):
                    self.loadLifeAreas(generation: generation)
                    completion(.success(area))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
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
        var restoredState = saved.asFilterState(pinnedLifeAreaIDs: activeFilterState.pinnedLifeAreaIDs)
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

    public func loadSavedViews(completion: (@Sendable () -> Void)? = nil) {
        savedHomeViewRepository.fetchAll { [weak self] result in
            Task { @MainActor in
                defer { completion?() }
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

// MARK: - Home lenses

extension HomeViewModel {
    /// Apply a Home lens. Today returns to the day timeline; Upcoming and project lenses switch the
    /// content region to a forward time-horizon stream (all open tasks across time).
    public func applyHomeLens(_ lens: HomeLens) {
        focusEngineEnabled = true
        switch lens {
        case .today:
            var state = activeFilterState
            state.streamsAllForward = false
            state.selectedProjectIDs = []
            state.selectedLifeAreaIDs = []
            state.quickView = .today
            state.selectedSavedViewID = nil
            activeFilterState = state
            persistLastFilterState()
            trackFeatureUsage(action: "home_lens_selected", metadata: ["lens": "today"])
            applySelectedDay(Date(), source: .datePicker, trackAnalytics: true)
        case .upcoming:
            applyStreamLens(lifeAreaIDs: [], analyticsLens: "upcoming")
        case .lifeArea(let lifeAreaID):
            bumpPinnedLifeArea(lifeAreaID)
            applyStreamLens(lifeAreaIDs: [lifeAreaID], analyticsLens: "lifeArea")
        }
    }

    private func applyStreamLens(lifeAreaIDs: [UUID], analyticsLens: String) {
        activeScope = .upcoming
        var state = activeFilterState
        state.streamsAllForward = true
        state.selectedLifeAreaIDs = lifeAreaIDs
        state.selectedProjectIDs = []
        state.quickView = .upcoming
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        trackFeatureUsage(action: "home_lens_selected", metadata: ["lens": analyticsLens])
        applyFocusFilters(trackAnalytics: true)
    }
}
