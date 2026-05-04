//
//  HomeAIActionCoordinator.swift
//  LifeBoard
//
//  Coordinates Home-specific AI propose/confirm/apply/undo actions.
//

import Foundation

enum HomeWeeklyProposalMode: String, Equatable {
    case ask
    case suggest
    case apply
}

struct HomeWeeklyTaskProposalChange: Equatable {
    let task: TaskDefinition
    let targetPlanningBucket: TaskPlanningBucket
    let targetWeeklyOutcomeID: UUID?
    let deferredFromWeekStart: Date?
    let deferredCount: Int

    init(
        task: TaskDefinition,
        targetPlanningBucket: TaskPlanningBucket,
        targetWeeklyOutcomeID: UUID? = nil,
        deferredFromWeekStart: Date? = nil,
        deferredCount: Int? = nil
    ) {
        self.task = task
        self.targetPlanningBucket = targetPlanningBucket
        self.targetWeeklyOutcomeID = targetPlanningBucket == .thisWeek ? targetWeeklyOutcomeID : nil
        self.deferredFromWeekStart = deferredFromWeekStart
        self.deferredCount = deferredCount ?? task.deferredCount
    }

    var hasMeaningfulChange: Bool {
        task.planningBucket != targetPlanningBucket
            || task.weeklyOutcomeID != targetWeeklyOutcomeID
            || task.deferredFromWeekStart != deferredFromWeekStart
            || task.deferredCount != deferredCount
    }

    var proposedTask: TaskDefinition {
        var updated = task
        updated.planningBucket = targetPlanningBucket
        updated.weeklyOutcomeID = targetWeeklyOutcomeID
        updated.deferredFromWeekStart = deferredFromWeekStart
        updated.deferredCount = deferredCount
        updated.updatedAt = Date()
        return updated
    }
}

struct HomeWeeklyProposalPreview {
    let mode: HomeWeeklyProposalMode
    let weekStartDate: Date
    let commands: [AssistantCommand]
    let diffLines: [AssistantDiffLine]
    let affectedTaskCount: Int
    let destructiveCount: Int
    let rationale: String
    let contextJSON: String?
    let run: AssistantActionRunDefinition?
}

final class HomeAIActionCoordinator {
    private struct WeeklyDraftContext: Encodable {
        struct TaskChange: Encodable {
            let taskID: UUID
            let title: String
            let fromBucket: String
            let toBucket: String
            let fromOutcomeID: UUID?
            let toOutcomeID: UUID?
        }

        let contextType: String
        let mode: String
        let weekStartDate: Date
        let proposedChangeCount: Int
        let taskChanges: [TaskChange]
        let todayContextJSON: String?
    }

    typealias ContextServiceFactory = () -> LLMContextProjectionService?

    private let pipeline: AssistantActionPipelineUseCase
    private let contextServiceFactory: ContextServiceFactory

    /// Initializes a new instance.
    init(
        pipeline: AssistantActionPipelineUseCase,
        contextServiceFactory: @escaping ContextServiceFactory = { LLMContextRepositoryProvider.makeService() }
    ) {
        self.pipeline = pipeline
        self.contextServiceFactory = contextServiceFactory
    }

    /// Proposes an AI command envelope that marks the provided task as complete.
    func proposeCompletion(
        task: TaskDefinition,
        threadID: String,
        rationale: @escaping (String?) -> String,
        completion: @escaping @Sendable (Result<(run: AssistantActionRunDefinition, contextJSON: String?), Error>) -> Void
    ) {
        let proposeWithContext: (String?) -> Void = { [weak self] contextJSON in
            guard let self else { return }

            let envelope = AssistantCommandEnvelope(
                schemaVersion: 2,
                commands: [.completeTask(taskID: task.id)],
                rationaleText: rationale(contextJSON)
            )

            self.pipeline.propose(threadID: threadID, envelope: envelope) { result in
                switch result {
                case .success(let run):
                    completion(.success((run, contextJSON)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        if let contextService = contextServiceFactory() {
            contextService.buildTodayJSON { contextJSON in
                proposeWithContext(contextJSON)
            }
        } else {
            proposeWithContext(nil)
        }
    }

    /// Builds a read-only or confirmation-gated weekly planning proposal without mutating tasks directly.
    func proposeWeeklyPlan(
        mode: HomeWeeklyProposalMode,
        weekStartDate: Date,
        taskChanges: [HomeWeeklyTaskProposalChange],
        threadID: String,
        weeklyOutcomeTitlesByID: [UUID: String] = [:],
        rationale: @escaping (String?) -> String,
        completion: @escaping @Sendable (Result<HomeWeeklyProposalPreview, Error>) -> Void
    ) {
        let normalizedChanges = taskChanges.filter(\.hasMeaningfulChange)
        guard normalizedChanges.isEmpty == false else {
            completion(.failure(NSError(
                domain: "HomeAIActionCoordinator",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "No weekly draft changes to propose."]
            )))
            return
        }

        let completeWithContext: (String?) -> Void = { [weak self] todayContextJSON in
            guard let self else { return }

            let contextJSON = self.buildWeeklyDraftContextJSON(
                mode: mode,
                weekStartDate: weekStartDate,
                taskChanges: normalizedChanges,
                todayContextJSON: todayContextJSON
            )
            let commands = normalizedChanges.map { change in
                AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: change.proposedTask))
            }
            let diffLines = self.buildWeeklyDiffLines(
                taskChanges: normalizedChanges,
                weeklyOutcomeTitlesByID: weeklyOutcomeTitlesByID
            )
            let preview = HomeWeeklyProposalPreview(
                mode: mode,
                weekStartDate: weekStartDate,
                commands: commands,
                diffLines: diffLines,
                affectedTaskCount: Set(normalizedChanges.map(\.task.id)).count,
                destructiveCount: diffLines.filter(\.isDestructive).count,
                rationale: rationale(contextJSON),
                contextJSON: contextJSON,
                run: nil
            )

            guard mode != .ask else {
                completion(.success(preview))
                return
            }

            let envelope = AssistantCommandEnvelope(
                schemaVersion: 2,
                commands: commands,
                rationaleText: preview.rationale
            )

            self.pipeline.propose(threadID: threadID, envelope: envelope) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let run):
                    completion(.success(HomeWeeklyProposalPreview(
                        mode: mode,
                        weekStartDate: weekStartDate,
                        commands: commands,
                        diffLines: diffLines,
                        affectedTaskCount: preview.affectedTaskCount,
                        destructiveCount: preview.destructiveCount,
                        rationale: preview.rationale,
                        contextJSON: contextJSON,
                        run: run
                    )))
                }
            }
        }

        if let contextService = contextServiceFactory() {
            contextService.buildTodayJSON { todayContextJSON in
                completeWithContext(todayContextJSON)
            }
        } else {
            completeWithContext(nil)
        }
    }

    /// Confirms and applies a previously proposed run.
    func confirmAndApply(runID: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) {
        let pipeline = pipeline
        pipeline.confirm(runID: runID) { confirmResult in
            switch confirmResult {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                pipeline.applyConfirmedRun(id: runID, completion: completion)
            }
        }
    }

    /// Rejects a pending run.
    func reject(runID: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) {
        pipeline.reject(runID: runID, completion: completion)
    }

    /// Undoes an applied run.
    func undo(runID: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) {
        pipeline.undoAppliedRun(id: runID, completion: completion)
    }

    private func buildWeeklyDiffLines(
        taskChanges: [HomeWeeklyTaskProposalChange],
        weeklyOutcomeTitlesByID: [UUID: String]
    ) -> [AssistantDiffLine] {
        var lines: [AssistantDiffLine] = []

        for change in taskChanges {
            let taskTitle = displayTaskTitle(for: change.task)
            if change.task.planningBucket != change.targetPlanningBucket {
                let leavingThisWeek = change.task.planningBucket == .thisWeek && change.targetPlanningBucket != .thisWeek
                lines.append(AssistantDiffLine(
                    text: "Move '\(taskTitle)' to \(bucketDisplayName(change.targetPlanningBucket))",
                    isDestructive: leavingThisWeek
                ))
            }

            if change.task.weeklyOutcomeID != change.targetWeeklyOutcomeID {
                if let outcomeID = change.targetWeeklyOutcomeID {
                    let outcomeTitle = weeklyOutcomeTitlesByID[outcomeID]?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayName = (outcomeTitle?.isEmpty == false) ? outcomeTitle! : "selected weekly outcome"
                    lines.append(AssistantDiffLine(
                        text: "Link '\(taskTitle)' to outcome '\(displayName)'",
                        isDestructive: false
                    ))
                } else if change.task.weeklyOutcomeID != nil {
                    lines.append(AssistantDiffLine(
                        text: "Remove weekly outcome from '\(taskTitle)'",
                        isDestructive: true
                    ))
                }
            }

            if change.task.deferredCount != change.deferredCount && change.deferredCount > change.task.deferredCount {
                lines.append(AssistantDiffLine(
                    text: "Record carry-forward for '\(taskTitle)'",
                    isDestructive: false
                ))
            }
        }

        if lines.isEmpty {
            return taskChanges.map {
                AssistantDiffLine(
                    text: "Refresh weekly state for '\(displayTaskTitle(for: $0.task))'",
                    isDestructive: false
                )
            }
        }

        return lines
    }

    private func buildWeeklyDraftContextJSON(
        mode: HomeWeeklyProposalMode,
        weekStartDate: Date,
        taskChanges: [HomeWeeklyTaskProposalChange],
        todayContextJSON: String?
    ) -> String? {
        let context = WeeklyDraftContext(
            contextType: "weekly_draft",
            mode: mode.rawValue,
            weekStartDate: weekStartDate,
            proposedChangeCount: taskChanges.count,
            taskChanges: taskChanges.map { change in
                WeeklyDraftContext.TaskChange(
                    taskID: change.task.id,
                    title: change.task.title,
                    fromBucket: change.task.planningBucket.rawValue,
                    toBucket: change.targetPlanningBucket.rawValue,
                    fromOutcomeID: change.task.weeklyOutcomeID,
                    toOutcomeID: change.targetWeeklyOutcomeID
                )
            },
            todayContextJSON: todayContextJSON
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(context) else { return todayContextJSON }
        return String(data: data, encoding: .utf8) ?? todayContextJSON
    }

    private func bucketDisplayName(_ bucket: TaskPlanningBucket) -> String {
        switch bucket {
        case .today:
            return "Today"
        case .thisWeek:
            return "This Week"
        case .nextWeek:
            return "Next Week"
        case .later:
            return "Later"
        case .someday:
            return "Someday"
        }
    }

    private func displayTaskTitle(for task: TaskDefinition) -> String {
        let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "task" : trimmed
    }
}
