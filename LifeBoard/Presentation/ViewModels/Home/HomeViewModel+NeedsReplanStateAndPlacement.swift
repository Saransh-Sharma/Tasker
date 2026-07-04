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
    public func placeReplanCandidate(taskID: UUID, at startDate: Date) {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first(where: { $0.task.id == taskID }) else { return }
        let roundedStart = roundedToNearestQuarterHour(startDate)
        var updated = candidate.task
        updated.dueDate = roundedStart
        updated.scheduledStartAt = roundedStart
        updated.scheduledEndAt = roundedStart.addingTimeInterval(candidate.rescheduleDuration)
        updated.isAllDay = false
        updated.replanCount = max(0, updated.replanCount) + 1
        updated.updatedAt = Date()
        applyReplanCommand(
            .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: updated)),
            action: .rescheduled,
            candidate: candidate,
            reloadReason: .rescheduled
        )
    }

    public func placeReplanCandidateAllDay(taskID: UUID, on day: Date) {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first(where: { $0.task.id == taskID }) else { return }
        let normalizedDay = Calendar.current.startOfDay(for: day)
        var updated = candidate.task
        updated.dueDate = normalizedDay
        updated.scheduledStartAt = nil
        updated.scheduledEndAt = nil
        updated.isAllDay = true
        updated.replanCount = max(0, updated.replanCount) + 1
        updated.updatedAt = Date()
        applyReplanCommand(
            .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: updated)),
            action: .rescheduled,
            candidate: candidate,
            reloadReason: .rescheduled
        )
    }

    public func undoLastReplanAction() {
        guard replanApplyingAction == nil else { return }
        guard let entry = replanUndoStack.last else { return }
        beginReplanApplying(.undo)
        useCaseCoordinator.assistantActionPipeline.undoAppliedRun(id: entry.runID) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    let phase = self.needsReplanViewModel.restoreUndoEntry(entry)
                    self.enqueueReload(
                        source: "needs_replan_undo",
                        reason: .bulkChanged,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    self.updateReplanState(phase: phase)
                case .failure(let error):
                    self.recordReplanFailure(error)
                }
            }
        }
    }

    public func clearReplanError() {
        needsReplanViewModel.errorMessage = nil
        updateReplanState(phase: homeReplanState.phase)
    }

    func beginReplanLauncher(with candidates: [HomeReplanCandidate], scopedTo date: Date?) {
        needsReplanViewModel.beginSession(with: candidates, scopedTo: date)
        let summary = makeNeedsReplanSummary(for: candidates)
        updateReplanState(phase: .launcher(summary))
    }

    func refreshNeedsReplanCandidates() {
        guard let readModelRepository = useCaseCoordinator.taskReadModelRepository else {
            needsReplanCandidates = []
            cachedGlobalReplanRevision = dataRevision
            refreshPassiveNeedsReplanState()
            updateReplanState(phase: homeReplanState.phase)
            return
        }
        guard cachedGlobalReplanRevision != dataRevision else {
            refreshPassiveNeedsReplanState()
            updateReplanState(phase: homeReplanState.phase)
            return
        }
        if activeGlobalReplanFetchToken != nil {
            pendingGlobalReplanRefreshRevision = dataRevision
            return
        }

        let fetchToken = UUID()
        activeGlobalReplanFetchToken = fetchToken
        activeGlobalReplanFetchRevision = dataRevision
        let activeProjectIDs = projects
            .filter { $0.isArchived == false }
            .map(\.id)
        readModelRepository.fetchNeedsReplanCandidates(
            query: NeedsReplanCandidateQuery(
                referenceDate: Date(),
                scopedDate: nil,
                activeProjectIDs: activeProjectIDs,
                includeUnscheduledBacklog: true,
                limit: 400,
                offset: 0
            )
        ) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard self.activeGlobalReplanFetchToken == fetchToken else { return }
                let completedRevision = self.activeGlobalReplanFetchRevision
                let shouldRefreshAgain = self.pendingGlobalReplanRefreshRevision != nil &&
                    self.pendingGlobalReplanRefreshRevision != completedRevision
                self.pendingGlobalReplanRefreshRevision = nil
                self.activeGlobalReplanFetchToken = nil
                self.activeGlobalReplanFetchRevision = nil
                if shouldRefreshAgain {
                    self.cachedGlobalReplanRevision = nil
                    self.refreshNeedsReplanCandidates()
                    return
                }
                switch result {
                case .success(let projection):
                    self.needsReplanCandidates = self.deriveNeedsReplanCandidates(from: projection.tasks, scopedTo: nil)
                    self.cachedGlobalReplanRevision = self.dataRevision
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.needsReplanCandidates = []
                    self.cachedGlobalReplanRevision = nil
                }
                self.refreshPassiveNeedsReplanState()
                self.updateReplanState(phase: self.homeReplanState.phase)
            }
        }
    }

    func refreshPassiveNeedsReplanState() {
        switch homeReplanState.phase {
        case .launcher, .card, .placement, .summary, .skippedReview:
            return
        case .trayHidden, .trayVisible:
            break
        }

        updateReplanState(phase: .trayHidden)
    }

    func deriveNeedsReplanCandidates(
        from tasks: [TaskDefinition],
        scopedTo scopedDate: Date?
    ) -> [HomeReplanCandidate] {
        let projectsByID = Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return HomeNeedsReplanViewModel.buildCandidates(
            from: tasks,
            projectsByID: projectsByID,
            scopedTo: scopedDate
        )
    }

    func makeNeedsReplanSummary(for candidates: [HomeReplanCandidate]) -> NeedsReplanSummary {
        HomeNeedsReplanViewModel.summary(for: candidates)
    }

    func updateReplanState(phase: HomeReplanSessionPhase) {
        let nextState = needsReplanViewModel.makeState(phase: phase)
        guard homeReplanState != nextState else { return }
        homeReplanState = nextState
    }

    func advanceReplanSession(to phase: HomeReplanSessionPhase) {
        if let next = activeReplanCandidates.first {
            updateReplanState(phase: phase)
            trackHomeInteraction(action: "needs_replan_next", metadata: [
                "task_id": next.task.id.uuidString
            ])
            return
        }

        updateReplanState(phase: phase)
    }

    func applyReplanCommand(
        _ command: AssistantCommand,
        action: HomeReplanResolutionKind,
        candidate: HomeReplanCandidate,
        reloadReason: HomeTaskMutationEvent
    ) {
        beginReplanApplying(applyingAction(for: action))
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 2,
            commands: [command],
            rationaleText: "Needs Replan"
        )
        let threadID = "home-needs-replan-\(UUID().uuidString)"
        let pipeline = useCaseCoordinator.assistantActionPipeline
        pipeline.propose(threadID: threadID, envelope: envelope) { proposeResult in
            switch proposeResult {
            case .failure(let error):
                Task { @MainActor in self.recordReplanFailure(error) }
            case .success(let proposedRun):
                pipeline.confirm(runID: proposedRun.id) { confirmResult in
                    switch confirmResult {
                    case .failure(let error):
                        Task { @MainActor in self.recordReplanFailure(error) }
                    case .success:
                        pipeline.applyConfirmedRun(id: proposedRun.id) { applyResult in
                            Task { @MainActor in
                                switch applyResult {
                                case .failure(let error):
                                    self.recordReplanFailure(error)
                                case .success(let appliedRun):
                                    self.completeReplanResolution(
                                        action: action,
                                        candidate: candidate,
                                        runID: appliedRun.id,
                                        reloadReason: reloadReason
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func completeReplanResolution(
        action: HomeReplanResolutionKind,
        candidate: HomeReplanCandidate,
        runID: UUID,
        reloadReason: HomeTaskMutationEvent
    ) {
        let phase = needsReplanViewModel.completeResolution(
            action: action,
            candidate: candidate,
            runID: runID
        )
        enqueueReload(
            source: "needs_replan_resolution",
            reason: reloadReason,
            taskID: candidate.id,
            invalidateCaches: true,
            includeAnalytics: action == .completed,
            repostEvent: true
        )
        advanceReplanSession(to: phase)
    }

    func beginReplanApplying(_ action: HomeReplanApplyingAction) {
        needsReplanViewModel.beginApplying(action)
        updateReplanState(phase: homeReplanState.phase)
    }

    func recordReplanFailure(_ error: Error) {
        needsReplanViewModel.recordFailure(error)
        errorMessage = error.localizedDescription
        updateReplanState(phase: homeReplanState.phase)
    }

    func applyingAction(for action: HomeReplanResolutionKind) -> HomeReplanApplyingAction {
        switch action {
        case .rescheduled:
            return .reschedule
        case .movedToInbox:
            return .moveToInbox
        case .completed:
            return .checkOff
        case .deleted:
            return .delete
        }
    }

    func defaultReplanPlacementDay(now: Date = Date()) -> Date {
        HomeNeedsReplanViewModel.defaultPlacementDay(now: now)
    }

    func roundedToNearestQuarterHour(_ date: Date) -> Date {
        let interval = (date.timeIntervalSinceReferenceDate / 900).rounded() * 900
        return Date(timeIntervalSinceReferenceDate: interval)
    }

    /// Executes trackFirstCompletionLatencyIfNeeded.

    func trackFirstCompletionLatencyIfNeeded() {
        guard !didTrackFirstCompletionLatency else { return }
        didTrackFirstCompletionLatency = true

        let latency = Date().timeIntervalSince(homeOpenedAt)
        trackFeatureUsage(action: "home_filter_time_to_first_completion_sec", metadata: ["seconds": latency])
    }

    /// Executes updateCompletionRate.

    func updateCompletionRate(_ result: TodayTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }

    /// Executes updateCompletionRate.

    func updateCompletionRate(_ result: DateTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }

    /// Executes applyCompletionResultLocally.
}
