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

private final class EvaBatchTaskResolutionStore: @unchecked Sendable {
    private let lock = NSLock()
    private var tasksByID: [UUID: TaskDefinition] = [:]
    private var firstError: Error?

    func record(task: TaskDefinition, id: UUID) {
        lock.lock()
        tasksByID[id] = task
        lock.unlock()
    }

    func recordMissing(id: UUID) {
        lock.lock()
        if firstError == nil {
            firstError = EvaBatchProposalError.missingTask(id)
        }
        lock.unlock()
    }

    func record(error: Error) {
        lock.lock()
        if firstError == nil {
            firstError = error
        }
        lock.unlock()
    }

    func result() -> Result<[UUID: TaskDefinition], Error> {
        lock.lock()
        let tasksByID = tasksByID
        let firstError = firstError
        lock.unlock()

        if let firstError {
            return .failure(firstError)
        }
        return .success(tasksByID)
    }
}

extension HomeViewModel {
    public func startTriage() {
        startTriage(scope: .visible)
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
        let referenceDate = Date()
        evaRescueLauncherState = .loading
        evaRescueReferenceDate = nil
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
                        self.evaRescueReferenceDate = nil
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
                self.evaRescueReferenceDate = referenceDate
                self.evaRescueLauncherState = .ready
                self.evaRescueSheetPresented = true
                self.trackHomeInteraction(action: "rescue_open", metadata: [
                    "scope": "all_overdue",
                    "overdue_count": rescueEligibleTasks.count
                ])
            }
        }
    }

    public func openOverdueRescueFromHome(
        source: String,
        action: String = "overdue_rescue_launch_requested"
    ) {
        setQuickView(.overdue)
        trackHomeInteraction(action: action, metadata: [
            "source": source
        ])
        DispatchQueue.main.async { [weak self] in
            self?.openRescue()
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
        resolveEvaBatchTasks(for: mutations) { [weak self] resolution in
            Task { @MainActor in
                guard let self else { return }
                let tasksByID: [UUID: TaskDefinition]
                switch resolution {
                case .success(let resolved):
                    tasksByID = resolved
                case .failure(let error):
                    completion(.failure(error))
                    return
                }

                let now = Date()
                let rescueReferenceDate = self.evaRescueReferenceDate ?? now
                if source == .rescue,
                   let ineligible = mutations.first(where: { mutation in
                       guard let task = tasksByID[mutation.taskID] else { return true }
                       return self.isOverdueRescueDeckEligibleTask(task, on: rescueReferenceDate) == false
                   }) {
                    completion(.failure(EvaBatchProposalError.staleTask(ineligible.taskID)))
                    return
                }

                let proposal: (threadID: String, envelope: AssistantCommandEnvelope)
                do {
                    proposal = try self.buildEvaBatchProposalUseCase.executeValidated(
                        source: source,
                        tasksByID: tasksByID,
                        mutations: mutations,
                        now: now
                    )
                } catch {
                    completion(.failure(error))
                    return
                }

                let pipeline = self.useCaseCoordinator.assistantActionPipeline
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
                                                "mutation_count": mutations.count,
                                                "command_count": proposal.envelope.commands.count,
                                                "resolved_task_count": tasksByID.count
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
        }
    }

    private func resolveEvaBatchTasks(
        for mutations: [EvaBatchMutationInstruction],
        completion: @escaping @Sendable (Result<[UUID: TaskDefinition], Error>) -> Void
    ) {
        let ids = Array(Set(mutations.map(\.taskID)))
        let group = DispatchGroup()
        let store = EvaBatchTaskResolutionStore()
        let repository = useCaseCoordinator.taskDefinitionRepository

        for id in ids {
            group.enter()
            repository.fetchTaskDefinition(id: id) { result in
                switch result {
                case .success(let task):
                    if let task {
                        store.record(task: task, id: id)
                    } else {
                        store.recordMissing(id: id)
                    }
                case .failure(let error):
                    store.record(error: error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(store.result())
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
