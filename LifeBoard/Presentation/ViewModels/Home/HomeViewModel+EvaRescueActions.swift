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

/// The mutation boundary for Rescue batches.
///
/// Resolution and staleness checks happen before a proposal exists; proposal,
/// confirmation, and apply remain sequential; the pipeline's transactional
/// rollback remains authoritative on apply failure. Plan-metadata compensation
/// and user Undo both call the same `undo` boundary.
@MainActor
final class RescueBatchApplier {
    private let taskRepository: TaskDefinitionRepositoryProtocol
    private let proposalBuilder: BuildEvaBatchProposalUseCase
    private let pipeline: AssistantActionPipelineUseCase

    init(
        taskRepository: TaskDefinitionRepositoryProtocol,
        proposalBuilder: BuildEvaBatchProposalUseCase,
        pipeline: AssistantActionPipelineUseCase
    ) {
        self.taskRepository = taskRepository
        self.proposalBuilder = proposalBuilder
        self.pipeline = pipeline
    }

    func apply(
        source: EvaBatchSource,
        mutations: [EvaBatchMutationInstruction],
        rescueReferenceDate: Date,
        completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        guard mutations.isEmpty == false else {
            completion(.failure(NSError(
                domain: "RescueBatchApplier",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "No assistant mutations to apply"]
            )))
            return
        }

        resolveTasks(for: mutations) { [weak self] resolution in
            Task { @MainActor in
                guard let self else { return }
                let tasksByID: [UUID: TaskDefinition]
                switch resolution {
                case .success(let resolved): tasksByID = resolved
                case .failure(let error):
                    completion(.failure(error))
                    return
                }

                if source == .rescue,
                   let stale = mutations.first(where: { mutation in
                       guard let task = tasksByID[mutation.taskID] else { return true }
                       return OverdueRescueEligibilityPolicy.isStaleOverdueTask(
                           task,
                           referenceDate: rescueReferenceDate
                       ) == false
                   }) {
                    completion(.failure(EvaBatchProposalError.staleTask(stale.taskID)))
                    return
                }

                let proposal: (threadID: String, envelope: AssistantCommandEnvelope)
                do {
                    proposal = try self.proposalBuilder.executeValidated(
                        source: source,
                        tasksByID: tasksByID,
                        mutations: mutations,
                        now: Date()
                    )
                } catch {
                    completion(.failure(error))
                    return
                }

                self.pipeline.propose(threadID: proposal.threadID, envelope: proposal.envelope) { proposeResult in
                    switch proposeResult {
                    case .failure(let error): completion(.failure(error))
                    case .success(let proposedRun):
                        self.pipeline.confirm(runID: proposedRun.id) { confirmResult in
                            switch confirmResult {
                            case .failure(let error): completion(.failure(error))
                            case .success:
                                self.pipeline.applyConfirmedRun(id: proposedRun.id, completion: completion)
                            }
                        }
                    }
                }
            }
        }
    }

    func undo(
        runID: UUID,
        completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        pipeline.undoAppliedRun(id: runID, completion: completion)
    }

    func compensate(
        runID: UUID,
        completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        undo(runID: runID, completion: completion)
    }

    private func resolveTasks(
        for mutations: [EvaBatchMutationInstruction],
        completion: @escaping @Sendable (Result<[UUID: TaskDefinition], Error>) -> Void
    ) {
        let ids = Array(Set(mutations.map(\.taskID)))
        let group = DispatchGroup()
        let store = EvaBatchTaskResolutionStore()

        for id in ids {
            group.enter()
            taskRepository.fetchTaskDefinition(id: id) { result in
                switch result {
                case .success(let task):
                    if let task { store.record(task: task, id: id) }
                    else { store.recordMissing(id: id) }
                case .failure(let error): store.record(error: error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { completion(store.result()) }
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
        launchOverdueRescue(.home(referenceDate: Date()), action: action)
    }

    public func openRescue() {
        launchOverdueRescue(.home(referenceDate: Date()))
    }

    func launchOverdueRescue(
        _ context: OverdueRescueLaunchContext,
        source: String? = nil,
        action: String = "overdue_rescue_launch_requested"
    ) {
        setQuickView(.overdue)
        trackHomeInteraction(action: action, metadata: [
            "source": source ?? context.source
        ])
        let coordinator = overdueRescueLaunchCoordinator
        let dayTasks = context.origin == .universalInputDayRescue ? dayRescueTasksByID : [:]
        coordinator.begin(context, dayRescueTasksByID: dayTasks)
        scheduleHomeRenderStateRefresh(.overlay)

        guard V2FeatureFlags.evaRescueEnabled else {
            coordinator.fail("Overdue Rescue is currently unavailable.")
            scheduleHomeRenderStateRefresh(.overlay)
            return
        }

        if context.origin == .universalInputDayRescue {
            coordinator.present(plan: nil, tasksByID: dayTasks, context: context)
            scheduleHomeRenderStateRefresh(.overlay)
            trackHomeInteraction(action: "rescue_open", metadata: [
                "scope": "day_rescue",
                "overdue_count": dayTasks.count
            ])
            return
        }

        if overdueTasks.isEmpty == false {
            presentRescuePlan(overdueTasks: overdueTasks, context: context)
            return
        }

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
                        coordinator.fail(error.localizedDescription)
                        self.scheduleHomeRenderStateRefresh(.overlay)
                        self.errorMessage = error.localizedDescription
                        return
                    }
                }
                self.presentRescuePlan(overdueTasks: tasks, context: context)
            }
        }
    }

    private func presentRescuePlan(
        overdueTasks: [TaskDefinition],
        context: OverdueRescueLaunchContext
    ) {
        let referenceDate = context.referenceDate
        let rescueEligibleTasks = overdueTasks.filter {
            OverdueRescueEligibilityPolicy.isStaleOverdueTask($0, referenceDate: referenceDate)
        }
        let tasksByID = Dictionary(uniqueKeysWithValues: rescueEligibleTasks.map { ($0.id, $0) })
        let plan = getOverdueRescuePlanUseCase.execute(
            overdueTasks: rescueEligibleTasks,
            now: referenceDate
        )
        overdueRescueLaunchCoordinator.present(plan: plan, tasksByID: tasksByID, context: context)
        scheduleHomeRenderStateRefresh(.overlay)
        trackHomeInteraction(action: "rescue_open", metadata: [
            "scope": "all_overdue",
            "overdue_count": rescueEligibleTasks.count
        ])
    }

    public func applyEvaBatchPlan(
        source: EvaBatchSource,
        mutations: [EvaBatchMutationInstruction],
        completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        let referenceDate = evaRescueReferenceDate ?? Date()
        rescueBatchApplier.apply(
            source: source,
            mutations: mutations,
            rescueReferenceDate: referenceDate
        ) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if case .success(let run) = result {
                    self.evaLastBatchRunID = run.id
                    self.enqueueReload(
                        source: "eva_batch_apply",
                        reason: .bulkChanged,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    self.trackHomeInteraction(
                        action: source == .triage ? "triage_bulk_apply" : "rescue_apply_confirmed",
                        metadata: [
                            "mutation_count": mutations.count,
                            "command_count": mutations.count,
                            "resolved_task_count": Set(mutations.map(\.taskID)).count
                        ]
                    )
                }
                completion(result)
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
        rescueBatchApplier.undo(runID: runID) { [weak self] result in
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
