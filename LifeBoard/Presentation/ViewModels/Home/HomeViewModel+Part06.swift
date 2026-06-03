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
    public func rescheduleOverdueTasks(completion: (@Sendable (Result<RescheduleAllResult, Error>) -> Void)? = nil) {
        useCaseCoordinator.rescheduleAllOverdueTasks { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let rescheduleResult):
                    self?.loadTodayTasks()
                    completion?(.success(rescheduleResult))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }
    }

    public func evaFocusInsight(for taskID: UUID) -> EvaFocusTaskInsight? {
        evaHomeInsights?.focus.taskInsights.first(where: { $0.taskID == taskID })
    }

    public func setEvaFocusWhyPresented(_ value: Bool) {
        evaFocusWhySheetPresented = value
        if value == false {
            assignIfChanged(\.focusWhyShuffleCandidates, [])
        }
    }

    public func setEvaRescuePresented(_ value: Bool) {
        evaRescueSheetPresented = value
        if value == false, evaRescueLauncherState != .loading {
            evaRescueLauncherState = .idle
        }
    }

    public func openFocusWhy() {
        guard V2FeatureFlags.evaFocusEnabled else { return }
        refreshFocusWhyShuffleCandidates()
        evaFocusWhySheetPresented = true
        trackHomeInteraction(action: "focus_now_why_open", metadata: [:])
    }

    @discardableResult
    public func refreshFocusWhyShuffleCandidates() -> [TaskDefinition] {
        let candidates = computeFocusWhyShuffleCandidates()
        assignIfChanged(\.focusWhyShuffleCandidates, candidates)
        return candidates
    }

    func refreshFocusWhyCandidatesIfPresented() {
        guard evaFocusWhySheetPresented else { return }
        assignIfChanged(\.focusWhyShuffleCandidates, computeFocusWhyShuffleCandidates())
    }

    public func shuffleFocusNow() {
        guard V2FeatureFlags.evaFocusEnabled else { return }
        guard activeScope.quickView == .today else { return }
        guard activeScope.quickView != .done else { return }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.count > 1 else { return }
        let pinnedSet = Set(pinnedFocusTaskIDs)
        let candidates = openTasks.filter { !pinnedSet.contains($0.id) }
        guard candidates.isEmpty == false else { return }

        let excluded = Set(recentShuffledFocusTaskIDs.suffix(shuffleExclusionWindow))
        let preferred = candidates.filter { !excluded.contains($0.id) }
        let effective = preferred.isEmpty ? candidates : preferred
        let ranked = rankedFocusTasks(from: effective, relativeTo: activeScope)
        let autoFill = Array(ranked.prefix(max(0, Self.maxPinnedFocusTasks - pinnedFocusTaskIDs.count)))
        let pinned = pinnedFocusTaskIDs.compactMap { id in openTasks.first(where: { $0.id == id }) }
        let newSelection = Array((pinned + autoFill).prefix(Self.maxPinnedFocusTasks))
        guard newSelection.isEmpty == false else { return }

        updateFocusSelection(newSelection)
        for task in newSelection {
            recentShuffledFocusTaskIDs.append(task.id)
        }
        recentShuffledFocusTaskIDs = Array(recentShuffledFocusTaskIDs.suffix(Self.maxShuffleHistorySize))
        persistRecentShuffleTaskIDs()
        refreshEvaInsights()
        trackHomeInteraction(action: "focus_now_shuffle_tap", metadata: [
            "result_count": newSelection.count
        ])
    }

    public func startTriage() {
        startTriage(scope: .visible)
    }

    public func startFocusSession(
        taskID: UUID?,
        targetDurationSeconds: Int = 25 * 60,
        completion: @escaping @Sendable (Result<FocusSessionDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.focusSession.startSession(
            taskID: taskID,
            targetDurationSeconds: targetDurationSeconds,
            completion: { result in
                Task { @MainActor in
                    completion(result)
                }
            }
        )
    }

    public func endFocusSession(
        sessionID: UUID,
        completion: @escaping @Sendable (Result<FocusSessionResult, Error>) -> Void
    ) {
        useCaseCoordinator.focusSession.endSession(sessionID: sessionID) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let focusResult):
                    if focusResult.xpResult?.awardedXP ?? 0 > 0 {
                        self?.scheduleLedgerMutationWatchdog(trigger: "focus_session_end")
                    }
                    self?.loadDailyAnalytics(includeGamificationRefresh: false)
                    completion(.success(focusResult))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func fetchActiveFocusSession(
        completion: @escaping @Sendable (Result<FocusSessionDefinition?, Error>) -> Void
    ) {
        useCaseCoordinator.focusSession.fetchActiveSession { result in
            Task { @MainActor in
                completion(result)
            }
        }
    }

    public func completeDailyReflection(
        completion: @escaping @Sendable (Result<XPEventResult, Error>) -> Void
    ) {
        useCaseCoordinator.markDailyReflection.execute { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let xpResult):
                    if xpResult.awardedXP > 0 {
                        self?.scheduleLedgerMutationWatchdog(trigger: "daily_reflection_complete")
                    }
                    self?.loadDailyAnalytics(includeGamificationRefresh: false)
                    completion(.success(xpResult))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func isDailyReflectionCompletedToday() -> Bool {
        useCaseCoordinator.markDailyReflection.isCompletedToday()
    }

    public func refreshAfterDailyReflectPlanSave(planningDate: Date) {
        refreshWeeklySummary()
        loadDailyAnalytics(includeGamificationRefresh: false)
        selectDate(planningDate, source: .dailyReflection)
    }

    public func launchInsights(_ request: InsightsLaunchRequest = .default) {
        let resolved = InsightsLaunchRequest(
            targetTab: request.targetTab,
            highlightedAchievementKey: request.highlightedAchievementKey
        )
        insightsLaunchRequest = resolved
        insightsLaunchToken = resolved.token
        trackHomeInteraction(
            action: "insights_launch_requested",
            metadata: [
                "target_tab": resolved.targetTab.rawValue.lowercased(),
                "has_highlighted_achievement": resolved.highlightedAchievementKey == nil ? "false" : "true"
            ]
        )
    }

    public func dispatchCelebration(_ result: XPEventResult?) {
        guard let result else { return }
        lastXPResult = result
    }

    public func makeInsightsViewModel() -> InsightsViewModel {
        if let retainedInsightsViewModel {
            return retainedInsightsViewModel
        }

        let resolvedViewModel = InsightsViewModel(
            engine: useCaseCoordinator.gamificationEngine,
            repository: useCaseCoordinator.gamificationRepository,
            taskReadModelRepository: useCaseCoordinator.taskReadModelRepository,
            reminderRepository: useCaseCoordinator.reminderRepository,
            analyticsUseCase: useCaseCoordinator.calculateAnalytics,
            buildWeeklyPlanSnapshotUseCase: useCaseCoordinator.buildWeeklyPlanSnapshot,
            calculateWeeklyMomentumUseCase: useCaseCoordinator.calculateWeeklyMomentum,
            buildRecoveryInsightsUseCase: useCaseCoordinator.buildRecoveryInsights,
            weeklyReviewDraftStore: useCaseCoordinator.weeklyReviewDraftStore
        )
        retainedInsightsViewModel = resolvedViewModel
        return resolvedViewModel
    }

    func makeHomeSearchViewModel() -> HomeSearchViewModel {
        if let retainedHomeSearchViewModel {
            return retainedHomeSearchViewModel
        }

        let resolvedViewModel = HomeSearchViewModel(useCaseCoordinator: useCaseCoordinator)
        retainedHomeSearchViewModel = resolvedViewModel
        return resolvedViewModel
    }

    func releaseInsightsViewModel() {
        retainedInsightsViewModel = nil
    }

    func releaseHomeSearchViewModel() {
        retainedHomeSearchViewModel?.purgeCaches()
        retainedHomeSearchViewModel = nil
    }

    public func startTriage(scope: EvaTriageScope) {
        routeLegacyEvaActionToRescue(action: "triage_redirected_to_rescue", scope: scope)
    }

    public func startNextDecision(scope: EvaTriageScope = .visible) {
        routeLegacyEvaActionToRescue(action: "next_decision_redirected_to_rescue", scope: scope)
    }

    func routeLegacyEvaActionToRescue(action: String, scope: EvaTriageScope) {
        trackHomeInteraction(action: action, metadata: [
            "scope": scope.rawValue
        ])
        openRescue()
    }

    public func openRescue() {
        guard V2FeatureFlags.evaRescueEnabled else { return }
        let referenceDate = selectedDate
        evaRescueLauncherState = .loading
        useCaseCoordinator.getTasks.getOverdueTasks { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                let tasks: [TaskDefinition]
                switch result {
                case .success(let overdue):
                    tasks = overdue
                case .failure(let error):
                    tasks = self.overdueTasks
                    if tasks.isEmpty {
                        self.evaRescueLauncherState = .failed(error.localizedDescription)
                        self.errorMessage = error.localizedDescription
                        return
                    }
                }
                let rescueEligibleTasks = tasks.filter {
                    self.isOverdueRescueDeckEligibleTask($0, on: referenceDate)
                }
                self.evaRescuePlan = self.getOverdueRescuePlanUseCase.execute(
                    overdueTasks: rescueEligibleTasks,
                    now: referenceDate
                )
                self.evaRescueLauncherState = .ready
                self.evaRescueSheetPresented = true
                self.trackHomeInteraction(action: "rescue_open", metadata: [
                    "scope": "all_overdue",
                    "overdue_count": rescueEligibleTasks.count
                ])
            }
        }
    }

    public func applyEvaBatchPlan(
        source: EvaBatchSource,
        mutations: [EvaBatchMutationInstruction],
        completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        guard mutations.isEmpty == false else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "No assistant mutations to apply"]
            )))
            return
        }
        let openTasks = focusOpenTasksForCurrentState()
            + overdueTasks
            + completedTasks
            + doneTimelineTasks
        let tasksByID = openTasks.reduce(into: [UUID: TaskDefinition]()) { partialResult, task in
            partialResult[task.id] = task
        }
        let proposal = buildEvaBatchProposalUseCase.execute(
            source: source,
            tasksByID: tasksByID,
            mutations: mutations
        )

        let pipeline = useCaseCoordinator.assistantActionPipeline
        pipeline.propose(threadID: proposal.threadID, envelope: proposal.envelope) { proposeResult in
            switch proposeResult {
            case .failure(let error):
                Task { @MainActor in
                    completion(.failure(error))
                }
            case .success(let proposedRun):
                pipeline.confirm(runID: proposedRun.id) { confirmResult in
                    switch confirmResult {
                    case .failure(let error):
                        Task { @MainActor in
                            completion(.failure(error))
                        }
                    case .success:
                        pipeline.applyConfirmedRun(id: proposedRun.id) { applyResult in
                            Task { @MainActor in
                                switch applyResult {
                                case .success(let run):
                                    self.evaLastBatchRunID = run.id
                                    self.enqueueReload(
                                        source: "eva_batch_apply",
                                        reason: .bulkChanged,
                                        invalidateCaches: true,
                                        includeAnalytics: false,
                                        repostEvent: true
                                    )
                                    self.trackHomeInteraction(action: source == .triage ? "triage_bulk_apply" : "rescue_apply_confirmed", metadata: [
                                        "mutation_count": mutations.count
                                    ])
                                    completion(.success(run))
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public func applyRescuePlan(
        mutations: [EvaBatchMutationInstruction],
        completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        trackHomeInteraction(action: "rescue_apply_tap", metadata: [
            "mutation_count": mutations.count
        ])
        applyEvaBatchPlan(source: .rescue, mutations: mutations) { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success(let run):
                    self?.trackHomeInteraction(action: "rescue_apply_success", metadata: [
                        "run_id": run.id.uuidString,
                        "mutation_count": mutations.count
                    ])
                    completion(.success(run))
                case .failure(let error):
                    self?.trackHomeInteraction(action: "rescue_apply_error", metadata: [
                        "error": error.localizedDescription
                    ])
                    completion(.failure(error))
                }
            }
        }
    }

    public func undoEvaBatchPlan(
        completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        guard let runID = evaLastBatchRunID else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No assistant batch run available to undo"]
            )))
            return
        }
        useCaseCoordinator.assistantActionPipeline.undoAppliedRun(id: runID) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let run):
                    self?.enqueueReload(
                        source: "eva_batch_undo",
                        reason: .bulkChanged,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    self?.trackHomeInteraction(action: "rescue_undo", metadata: [
                        "run_id": run.id.uuidString
                    ])
                    completion(.success(run))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
