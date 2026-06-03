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
    func performDailyAnalyticsRefresh(
        includeGamificationRefresh: Bool,
        completions: [() -> Void]
    ) {
        let generation = nextAnalyticsGeneration()
        let completionGroup = DispatchGroup()
        if V2FeatureFlags.gamificationV2Enabled {
            guard includeGamificationRefresh else {
                completionGroup.enter()
                useCaseCoordinator.calculateAnalytics.calculateDailyAnalytics(
                    for: Date(),
                    habitSignals: self.currentHabitSignals
                ) { [weak self] _ in
                    Task { @MainActor in
                        defer { completionGroup.leave() }
                        guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    }
                }
                completionGroup.notify(queue: .main) {
                    completions.forEach { $0() }
                }
                return
            }
            let engine = useCaseCoordinator.gamificationEngine

            completionGroup.enter()
            engine.fetchTodayXP { [weak self] result in
                Task { @MainActor in
                    defer { completionGroup.leave() }
                    guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    if case .success(let todayXP) = result {
                        self.dailyScore = todayXP
                        self.refreshProgressState()
                    }
                }
            }

            completionGroup.enter()
            engine.fetchCurrentProfile { [weak self] result in
                Task { @MainActor in
                    defer { completionGroup.leave() }
                    guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    if case .success(let profile) = result {
                        self.currentLevel = profile.level
                        self.totalXP = profile.xpTotal
                        self.nextLevelXP = profile.nextLevelXP
                        self.streak = profile.currentStreak
                        self.refreshProgressState()
                    }
                }
            }
        } else {
            completionGroup.enter()
            refreshDailyScoreFromCompletedTasksToday(generation: generation) {
                completionGroup.leave()
            }
        }

        completionGroup.enter()
        useCaseCoordinator.calculateAnalytics.calculateDailyAnalytics(
            for: Date(),
            habitSignals: currentHabitSignals
        ) { [weak self] _ in
            Task { @MainActor in
                defer { completionGroup.leave() }
                guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
            }
        }

        if !V2FeatureFlags.gamificationV2Enabled {
            completionGroup.enter()
            useCaseCoordinator.calculateAnalytics.calculateStreak { [weak self] result in
                Task { @MainActor in
                    defer { completionGroup.leave() }
                    guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    if case .success(let streakInfo) = result {
                        self.streak = streakInfo.currentStreak
                        self.refreshProgressState()
                    }
                }
            }
        }

        completionGroup.notify(queue: .main) {
            completions.forEach { $0() }
        }
    }

    func openTaskRowsForHabitReconciliation() -> [TaskDefinition] {
        if let cachedOpenTaskRowsForHabitMutation,
           cachedOpenTaskRowsForHabitMutation.revision == taskRowsDerivationRevision,
           cachedOpenTaskRowsForHabitMutation.quickView == activeScope.quickView {
            return cachedOpenTaskRowsForHabitMutation.rows
        }

        let rows: [TaskDefinition]
        switch activeScope.quickView {
        case .done:
            rows = []
        case .upcoming:
            rows = upcomingTasks.filter { !$0.isComplete }
        case .overdue:
            rows = overdueTasks.filter { !$0.isComplete }
        case .morning:
            rows = morningTasks.filter { !$0.isComplete }
        case .evening:
            rows = eveningTasks.filter { !$0.isComplete }
        case .today:
            rows = uniqueTasks((morningTasks + eveningTasks + overdueTasks).filter { !$0.isComplete })
        }

        cachedOpenTaskRowsForHabitMutation = HomeDerivedTaskRowsCache(
            revision: taskRowsDerivationRevision,
            quickView: activeScope.quickView,
            rows: rows
        )
        return rows
    }

    func refreshDueTodayAgenda(
        openTaskRows: [TaskDefinition],
        generation: Int,
        targetDay: Date,
        scope: HomeListScope,
        includeAnalyticsRefresh: Bool = true,
        completion: (@Sendable () -> Void)? = nil
    ) {
        let day = normalizedDay(targetDay)
        let group = DispatchGroup()
        let accumulator = LockedResultAccumulator(HomeDueTodayAgendaLoadState())

        group.enter()
        buildHabitHomeProjectionUseCase.execute(date: day) { result in
            accumulator.update { $0.agendaHabitRows = (try? result.get()) ?? [] }
            group.leave()
        }

        group.enter()
        useCaseCoordinator.getHabitLibrary.execute(includeArchived: false) { [weak self] result in
            guard let self else {
                group.leave()
                return
            }
            switch result {
            case .failure:
                accumulator.update { $0.libraryRowsByID = [:] }
                group.leave()
            case .success(let libraryRows):
                accumulator.update {
                    $0.libraryRowsByID = Dictionary(uniqueKeysWithValues: libraryRows.map { ($0.habitID, $0) })
                }
                guard libraryRows.isEmpty == false else {
                    accumulator.update { state in
                        state.trackingHabitRows = Self.trackingHomeRows(
                            from: libraryRows,
                            historyByHabitID: state.historyByHabitID,
                            on: day
                        )
                    }
                    group.leave()
                    return
                }
                group.enter()
                self.useCaseCoordinator.getHabitHistory.execute(
                    habitIDs: libraryRows.map(\.habitID),
                    endingOn: day,
                    dayCount: 30
                ) { historyResult in
                    var resolvedHistoryByHabitID: [UUID: [HabitDayMark]] = [:]
                    if case .success(let windows) = historyResult {
                        resolvedHistoryByHabitID = windows.reduce(into: [:]) { partialResult, window in
                            partialResult[window.habitID] = window.marks
                        }
                    }
                    let resolvedTrackingRows = Self.trackingHomeRows(
                        from: libraryRows,
                        historyByHabitID: resolvedHistoryByHabitID,
                        on: day
                    )
                    let historyByHabitID = resolvedHistoryByHabitID
                    accumulator.update {
                        $0.historyByHabitID = historyByHabitID
                        $0.trackingHabitRows = resolvedTrackingRows
                    }
                    group.leave()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            defer { completion?() }
            guard let self, self.isCurrentReloadGeneration(generation) else {
                LifeBoardPerformanceTrace.event("HomeDaySwipeStaleDrop")
                return
            }
            guard self.selectedDayMatches(day, scope: scope) else {
                LifeBoardPerformanceTrace.event("HomeDaySwipeStaleDrop")
                return
            }

            let result = accumulator.result()
            guard case .success(let loadState) = result else { return }
            let resolvedAgendaHabitRows = loadState.agendaHabitRows
            let resolvedTrackingHabitRows = loadState.trackingHabitRows
            let resolvedLibraryRowsByID = loadState.libraryRowsByID

            let allHabitRows = self.mergeHabitRows(
                agenda: resolvedAgendaHabitRows,
                tracking: resolvedTrackingHabitRows
            )
            let splitHabitRows = HabitBoardPresentationBuilder.splitHomeRows(allHabitRows)
            self.currentHabitSignals = self.habitSignals(from: allHabitRows)
            self.habitLibraryRowsByID = resolvedLibraryRowsByID
            let rescueSplit = self.splitRescueEligibleTasks(from: openTaskRows, on: day)
            let rescueTailIDLimit = 5
            let rescueTailIDs = rescueSplit.rescueEligibleTasks.prefix(rescueTailIDLimit).map { $0.id.uuidString }.joined(separator: ",")
            let remainingRescueTailIDCount = max(0, rescueSplit.rescueEligibleTasks.count - rescueTailIDLimit)
            let rescueTailIDSuffix = remainingRescueTailIDCount > 0 ? ",(+\(remainingRescueTailIDCount) more)" : ""
            logDebug(
                "HOME_RESCUE_TAIL split quick=\(scope.quickView.rawValue) input=\(openTaskRows.count) " +
                "rescue=\(rescueSplit.rescueEligibleTasks.count) " +
                "ids=\(rescueTailIDs)\(rescueTailIDSuffix)"
            )

            let focusRows = self.composeFocusRows(taskRows: rescueSplit.focusTaskRows, habitRows: allHabitRows)
            let agendaTaskRows =
                scope.quickView == .today
                ? Self.excludingVisibleFocusTasks(from: rescueSplit.agendaTaskRows, focusRows: focusRows)
                : rescueSplit.agendaTaskRows

            let agenda = self.buildHomeAgendaUseCase.execute(
                date: day,
                taskRows: agendaTaskRows,
                habitRows: resolvedAgendaHabitRows
            )

            self.assignIfChanged(\.dueTodayRows, agenda.rows)
            self.assignIfChanged(\.dueTodaySection, nil)
            let todaySections = HomeMixedSectionBuilder.buildTodaySections(
                taskRows: agendaTaskRows,
                habitRows: [],
                projects: self.projects,
                lifeAreas: self.lifeAreas,
                useAdaptiveDayGrouping: true
            )
            self.assignIfChanged(\.todaySections, todaySections)

            self.assignIfChanged(\.focusRows, focusRows)
            self.assignIfChanged(
                \.focusNowSectionState,
                FocusNowSectionState(
                    rows: focusRows,
                    pinnedTaskIDs: self.pinnedFocusTaskIDs
                )
            )
            self.assignIfChanged(
                \.todayAgendaSectionState,
                TodayAgendaSectionState(sections: todaySections)
            )
            self.assignIfChanged(
                \.agendaTailItems,
                self.buildAgendaTailItems(
                    rescueEligibleTasks: rescueSplit.rescueEligibleTasks
                )
            )
            self.assignIfChanged(
                \.habitHomeSectionState,
                HabitHomeSectionState(
                    primaryRows: splitHabitRows.primary,
                    recoveryRows: splitHabitRows.recovery
                )
            )
            self.assignIfChanged(
                \.quietTrackingSummaryState,
                QuietTrackingSummaryState(
                    stableRows: splitHabitRows.quiet
                )
            )

            if includeAnalyticsRefresh,
               Calendar.current.isDate(day, inSameDayAs: Date()) {
                self.loadDailyAnalytics(includeGamificationRefresh: false)
            }
        }
    }

    struct CanonicalHabitMutationState {
        let row: HomeHabitRow?
        let libraryRow: HabitLibraryRow?
    }

    func fetchCanonicalHabitMutationState(
        habitID: UUID,
        on date: Date,
        completion: @escaping @Sendable (Result<CanonicalHabitMutationState, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let accumulator = LockedResultAccumulator(HomeCanonicalHabitMutationLoadState())

        group.enter()
        buildHabitHomeProjectionUseCase.execute(date: date, habitID: habitID) { result in
            switch result {
            case .failure(let error):
                accumulator.record(error)
            case .success(let row):
                accumulator.update { $0.projectionRow = row }
            }
            group.leave()
        }

        group.enter()
        useCaseCoordinator.getHabitLibrary.execute(habitIDs: [habitID], includeArchived: false) { [weak self] result in
            guard let self else {
                group.leave()
                return
            }
            switch result {
            case .failure(let error):
                accumulator.record(error)
                group.leave()
            case .success(let rows):
                let resolvedLibraryRow = rows.first
                accumulator.update { $0.libraryRow = resolvedLibraryRow }
                let hasLibraryRow = resolvedLibraryRow != nil
                guard hasLibraryRow else {
                    group.leave()
                    return
                }
                group.enter()
                self.useCaseCoordinator.getHabitHistory.execute(
                    habitIDs: [habitID],
                    endingOn: date,
                    dayCount: 30
                ) { historyResult in
                    switch historyResult {
                    case .failure(let error):
                        accumulator.record(error)
                    case .success(let windows):
                        let resolvedHistoryByHabitID = windows.reduce(into: [:]) { partialResult, window in
                            partialResult[window.habitID] = window.marks
                        }
                        accumulator.update { $0.historyByHabitID = resolvedHistoryByHabitID }
                    }
                    group.leave()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            let result = accumulator.result()
            if case .failure(let error) = result {
                completion(.failure(error))
                return
            }
            guard case .success(let loadState) = result else { return }
            let resolvedProjectionRow = loadState.projectionRow
            let resolvedLibraryRow = loadState.libraryRow
            let resolvedHistoryByHabitID = loadState.historyByHabitID

            let trackingRow: HomeHabitRow?
            if let resolvedLibraryRow {
                trackingRow = Self.trackingHomeRows(
                    from: [resolvedLibraryRow],
                    historyByHabitID: resolvedHistoryByHabitID,
                    on: date
                ).first
            } else {
                trackingRow = nil
            }

            let canonicalRow = self?.mergeHabitRows(
                agenda: resolvedProjectionRow.map { [$0] } ?? [],
                tracking: trackingRow.map { [$0] } ?? []
            ).first

            completion(.success(
                CanonicalHabitMutationState(
                    row: canonicalRow,
                    libraryRow: resolvedLibraryRow
                )
            ))
        }
    }
}
