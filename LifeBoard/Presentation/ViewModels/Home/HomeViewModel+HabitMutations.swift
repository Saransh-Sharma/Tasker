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
    func resetHabit(
        _ row: HomeHabitRow,
        source: String
    ) {
        performHabitMutation(
            row,
            request: .reset,
            on: selectedDate,
            source: source
        )
    }

    func performHabitMutation(
        _ row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date,
        source: String
    ) {
        let key = habitMutationKey(for: row, on: date)
        guard !isHabitMutationPending(for: key) else {
            logDebug("HOME_HABIT_STATE vm.mutation_ignored_pending id=\(row.habitID.uuidString)")
            return
        }

        habitMutationErrorMessage = nil
        pendingHabitMutationKeys.insert(key)
        pendingHabitMutationIntervals[key] = LifeBoardPerformanceTrace.begin("HomeUserMutation")
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) {
            pendingHabitMutationSnapshots[key] = captureHabitMutationSnapshot()

            let applyInterval = LifeBoardPerformanceTrace.begin("HomeHabitOptimisticApply")
            let didApplyOptimisticUpdate = applyOptimisticHabitMutation(
                row,
                request: request,
                on: date
            )
            LifeBoardPerformanceTrace.end(applyInterval)

            guard didApplyOptimisticUpdate else {
                if let interval = pendingHabitMutationIntervals.removeValue(forKey: key) {
                    LifeBoardPerformanceTrace.end(interval)
                }
                pendingHabitMutationKeys.remove(key)
                pendingHabitMutationSnapshots.removeValue(forKey: key)
                return
            }
            habitMutationFeedback = makeHabitMutationFeedback(for: request, row: row, date: date)
            LifeBoardPerformanceTrace.event("HomeUserMutationOptimisticApplied")
        }

        let mutationContext = HabitMutationContext(source: source)
        registerSelfOriginatedHabitMutationContext(mutationContext)
        let recoveryReflectionPrompt = recoveryReflectionPromptIfNeeded(for: row, request: request, on: date)

        switch request {
        case .resolve(let action):
            useCaseCoordinator.resolveHabitOccurrence.execute(
                habitID: row.habitID,
                occurrenceID: row.occurrenceID,
                action: action,
                on: date,
                mutationContext: mutationContext
            ) { [weak self] result in
                Task { @MainActor in
                    self?.handleHabitMutationResult(
                        result,
                        key: key,
                        habitID: row.habitID,
                        date: date,
                        mutationContext: mutationContext,
                        recoveryReflectionPrompt: recoveryReflectionPrompt
                    )
                }
            }

        case .reset:
            resetHabitOccurrenceUseCase.execute(
                habitID: row.habitID,
                occurrenceID: row.occurrenceID,
                on: date,
                mutationContext: mutationContext
            ) { [weak self] result in
                Task { @MainActor in
                    self?.handleHabitMutationResult(
                        result,
                        key: key,
                        habitID: row.habitID,
                        date: date,
                        mutationContext: mutationContext,
                        recoveryReflectionPrompt: recoveryReflectionPrompt
                    )
                }
            }
        }
    }

    func handleHabitMutationResult(
        _ result: Result<Void, Error>,
        key: HomeHabitMutationKey,
        habitID: UUID,
        date: Date,
        mutationContext: HabitMutationContext,
        recoveryReflectionPrompt: HabitRecoveryReflectionPrompt?
    ) {
        defer {
            if let interval = pendingHabitMutationIntervals.removeValue(forKey: key) {
                LifeBoardPerformanceTrace.end(interval)
            }
        }

        switch result {
        case .failure(let error):
            removeSelfOriginatedHabitMutationContext(mutationContext)
            if let snapshot = pendingHabitMutationSnapshots[key] {
                restoreHabitMutationSnapshot(snapshot)
            }
            pendingHabitMutationSnapshots.removeValue(forKey: key)
            pendingHabitMutationKeys.remove(key)
            habitMutationErrorMessage = error.localizedDescription
            errorMessage = error.localizedDescription

        case .success:
            LifeBoardPerformanceTrace.event("HomeUserMutationPersistenceComplete")
            pendingHabitMutationSnapshots.removeValue(forKey: key)
            pendingHabitMutationKeys.remove(key)
            habitMutationErrorMessage = nil
            let isSelectedDayMutation = Calendar.current.isDate(date, inSameDayAs: selectedDate)
            if isSelectedDayMutation {
                habitRecoveryReflectionPrompt = recoveryReflectionPrompt
            }
            guard isSelectedDayMutation else { return }
            reconcileHabitMutation(habitID: habitID, on: date)
        }
    }

    func recoveryReflectionPromptIfNeeded(
        for row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date
    ) -> HabitRecoveryReflectionPrompt? {
        guard Calendar.current.isDate(date, inSameDayAs: selectedDate) else { return nil }
        guard isRecoveryHabitRow(row) else { return nil }
        switch request {
        case .reset:
            return nil
        case .resolve(let action):
            switch action {
            case .complete, .abstained:
                return HabitRecoveryReflectionPrompt(
                    habitID: row.habitID,
                    habitTitle: row.title,
                    date: date
                )
            case .skip, .lapsed:
                return nil
            }
        }
    }

    func makeHabitMutationFeedback(
        for request: HomeHabitMutationRequest,
        row: HomeHabitRow,
        date: Date,
        calendar: Calendar = .current
    ) -> HomeHabitMutationFeedback {
        let stateLabel: String
        let haptic: HomeHabitMutationFeedbackHaptic

        switch request {
        case .resolve(.complete):
            stateLabel = "Marked done"
            haptic = .success
        case .resolve(.abstained):
            stateLabel = row.kind == .negative ? "Marked clean" : "Marked done"
            haptic = .success
        case .resolve(.skip):
            stateLabel = "Marked skipped"
            haptic = .selection
        case .resolve(.lapsed):
            stateLabel = "Marked lapsed"
            haptic = .warning
        case .reset:
            stateLabel = row.trackingMode == .lapseOnly ? "Cleared to tracking" : "Cleared to empty"
            haptic = .selection
        }

        let dayLabel = Self.makeHabitMutationFeedbackDateFormatter().string(from: calendar.startOfDay(for: date))
        return HomeHabitMutationFeedback(message: "\(dayLabel): \(stateLabel)", haptic: haptic)
    }

    @MainActor
    public func consumeHabitMutationFeedback(id: UUID) {
        guard habitMutationFeedback?.id == id else { return }
        habitMutationFeedback = nil
    }

    func isRecoveryHabitRow(_ row: HomeHabitRow) -> Bool {
        row.state == .overdue || row.state == .lapsedToday || row.riskState != .stable
    }

    func applyOptimisticHabitMutation(
        _ row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date
    ) -> Bool {
        guard let updatedRow = optimisticHabitRow(from: row, request: request, on: date) else {
            return false
        }

        let patch = buildHabitMutationSectionPatch(
            habitID: row.habitID,
            canonicalRow: updatedRow
        )

        performHomeRenderStateBatch {
            applyHabitMutationSectionPatch(patch)
        }

        logDebug(
            "HOME_HABIT_STATE vm.local_apply id=\(row.habitID.uuidString) " +
            "state=\(updatedRow.state.rawValue) rows=\(patch.affectedRowCount) sections=\(patch.affectedSectionCount)"
        )
        LifeBoardPerformanceTrace.event("HomeUserMutationRecomputedRows", value: patch.affectedRowCount)
        LifeBoardPerformanceTrace.event("HomeUserMutationRecomputedSections", value: patch.affectedSectionCount)
        return true
    }

    func currentAllHabitRows() -> [HomeHabitRow] {
        if let cachedMergedHabitRows,
           cachedMergedHabitRows.revision == habitRowsDerivationRevision {
            return cachedMergedHabitRows.rows
        }

        var rowsByHabitID: [UUID: HomeHabitRow] = [:]
        let rowsInDisplayOrder =
            habitHomeSectionState.primaryRows
            + habitHomeSectionState.recoveryRows
            + quietTrackingSummaryState.stableRows
        for row in rowsInDisplayOrder {
            rowsByHabitID[row.habitID] = row
        }
        let rows = rowsInDisplayOrder.filter { row in
            rowsByHabitID[row.habitID]?.id == row.id
        }
        cachedMergedHabitRows = HomeDerivedHabitRowsCache(
            revision: habitRowsDerivationRevision,
            rows: rows
        )
        return rows
    }

    func splitRescueEligibleTasks(
        from openTaskRows: [TaskDefinition],
        on date: Date
    ) -> (agendaTaskRows: [TaskDefinition], focusTaskRows: [TaskDefinition], rescueEligibleTasks: [TaskDefinition]) {
        let rescueEligibleTaskIDs = V2FeatureFlags.evaRescueEnabled
            ? Set(
                openTaskRows
                    .filter { isRescueEligibleTask($0, on: date) }
                    .map(\.id)
            )
            : Set<UUID>()
        let rescueEligibleTasks = openTaskRows.filter { rescueEligibleTaskIDs.contains($0.id) }
        let remainingTaskRows = openTaskRows.filter { !rescueEligibleTaskIDs.contains($0.id) }
        return (
            agendaTaskRows: remainingTaskRows,
            focusTaskRows: remainingTaskRows,
            rescueEligibleTasks: rescueEligibleTasks
        )
    }

    func refreshTodayAgendaForCurrentFocusSelection() {
        guard activeScope.quickView == .today else { return }
        refreshDueTodayAgenda(
            openTaskRows: focusOpenTasksForCurrentState(),
            generation: reloadGeneration,
            targetDay: normalizedDay(selectedDate),
            scope: activeScope,
            includeAnalyticsRefresh: false
        )
    }

    static func excludingVisibleFocusTasks(
        from agendaTaskRows: [TaskDefinition],
        focusRows: [HomeTodayRow]
    ) -> [TaskDefinition] {
        let visibleFocusTaskIDs = Set(
            focusRows.compactMap { row -> UUID? in
                guard case .task(let task) = row else { return nil }
                return task.id
            }
        )
        guard visibleFocusTaskIDs.isEmpty == false else { return agendaTaskRows }
        return agendaTaskRows.filter { !visibleFocusTaskIDs.contains($0.id) }
    }

    static func openTaskID(for row: HomeTodayRow) -> UUID? {
        guard case .task(let task) = row, !task.isComplete else { return nil }
        return task.id
    }

    func isEligibleForHabitFocusFallback(_ row: HomeHabitRow) -> Bool {
        row.trackingMode == .dailyCheckIn
            && row.kind == .positive
            && (row.state == .overdue || row.riskState == .atRisk)
    }

    func isShowingHabitBackedFocusFallback() -> Bool {
        let rows = focusNowSectionState.rows
        guard rows.isEmpty == false else { return false }
        guard focusTasks.isEmpty else { return false }
        return rows.allSatisfy(\.isHabit)
    }

    func shouldRecomputeHabitFocusFallback(for habitID: UUID) -> Bool {
        guard focusTasks.isEmpty else { return false }
        guard focusNowSectionState.rows.isEmpty == false else { return true }

        let displayedHabitRows = focusNowSectionState.rows.compactMap { row -> HomeHabitRow? in
            guard case .habit(let habitRow) = row else { return nil }
            return habitRow
        }
        guard displayedHabitRows.count == focusNowSectionState.rows.count else { return false }
        return displayedHabitRows.contains(where: { $0.habitID == habitID })
    }

    func currentHabitRowPlacementMap() -> [UUID: HomeHabitRowPlacement] {
        var placements: [UUID: HomeHabitRowPlacement] = [:]

        for (index, row) in habitHomeSectionState.primaryRows.enumerated() {
            placements[row.habitID] = HomeHabitRowPlacement(bucket: .primary, index: index)
        }
        for (index, row) in habitHomeSectionState.recoveryRows.enumerated() {
            placements[row.habitID] = HomeHabitRowPlacement(bucket: .recovery, index: index)
        }
        for (index, row) in quietTrackingSummaryState.stableRows.enumerated() {
            placements[row.habitID] = HomeHabitRowPlacement(bucket: .quiet, index: index)
        }

        return placements
    }

    func placementBucket(for row: HomeHabitRow) -> HomeHabitRowPlacementBucket {
        if row.trackingMode == .lapseOnly, row.state == .tracking, row.riskState == .stable {
            return .quiet
        }
        if row.state == .overdue || row.state == .lapsedToday || row.riskState != .stable {
            return .recovery
        }
        return .primary
    }

    func replacingHabitRow(
        habitID: UUID,
        with canonicalRow: HomeHabitRow?
    ) -> (primary: [HomeHabitRow], recovery: [HomeHabitRow], quiet: [HomeHabitRow]) {
        var primaryRows = habitHomeSectionState.primaryRows.filter { $0.habitID != habitID }
        var recoveryRows = habitHomeSectionState.recoveryRows.filter { $0.habitID != habitID }
        var quietRows = quietTrackingSummaryState.stableRows.filter { $0.habitID != habitID }

        guard let canonicalRow else {
            return (primaryRows, recoveryRows, quietRows)
        }

        let placementMap = currentHabitRowPlacementMap()
        let targetPlacement = placementMap[habitID]
            ?? HomeHabitRowPlacement(
                bucket: placementBucket(for: canonicalRow),
                index: Int.max
            )

        switch targetPlacement.bucket {
        case .primary:
            primaryRows.insert(canonicalRow, at: min(targetPlacement.index, primaryRows.count))
        case .recovery:
            recoveryRows.insert(canonicalRow, at: min(targetPlacement.index, recoveryRows.count))
        case .quiet:
            quietRows.insert(canonicalRow, at: min(targetPlacement.index, quietRows.count))
        }

        return (primaryRows, recoveryRows, quietRows)
    }

    func patchAgendaRowsForHabitMutation(
        habitID: UUID,
        canonicalRow: HomeHabitRow?
    ) -> [HomeTodayRow] {
        var patchedRows = dueTodayRows
        let existingIndex = patchedRows.firstIndex { row in
            guard case .habit(let habitRow) = row else { return false }
            return habitRow.habitID == habitID
        }

        switch (existingIndex, canonicalRow.map(includeHabitInAgenda(_:)) ?? false, canonicalRow) {
        case let (.some(index), true, .some(updatedRow)):
            patchedRows[index] = .habit(updatedRow)
        case (.some, true, .none):
            break
        case let (.some(index), false, _):
            patchedRows.remove(at: index)
        case let (.none, true, .some(updatedRow)):
            patchedRows.append(.habit(updatedRow))
        case (.none, false, _),
             (.none, true, .none):
            break
        }

        return patchedRows
    }
}
