import Foundation

public final class BuildEvaBatchProposalUseCase: @unchecked Sendable {
    /// Initializes a new instance.
    public init() {}

    /// Executes execute.
    public func execute(
        source: EvaBatchSource,
        tasksByID: [UUID: TaskDefinition],
        mutations: [EvaBatchMutationInstruction],
        now: Date = Date()
    ) -> (threadID: String, envelope: AssistantCommandEnvelope) {
        var commands: [AssistantCommand] = []
        commands.reserveCapacity(mutations.count)

        for mutation in mutations {
            guard var task = tasksByID[mutation.taskID] else { continue }
            if let projectID = mutation.projectID {
                task.projectID = projectID
                if projectID == ProjectConstants.inboxProjectID {
                    task.projectName = ProjectConstants.inboxProjectName
                }
            }
            if mutation.clearDueDate {
                task.dueDate = nil
                if source == .rescue {
                    task.scheduledStartAt = nil
                    task.scheduledEndAt = nil
                    task.isAllDay = false
                }
            } else if let dueDate = mutation.dueDate {
                if source == .rescue {
                    var scheduleTask = task
                    if let estimatedDuration = mutation.estimatedDuration {
                        scheduleTask.estimatedDuration = estimatedDuration
                    }
                    let schedule = TaskRescueScheduleShifter.shift(task: scheduleTask, to: dueDate)
                    task.dueDate = schedule.dueDate
                    task.scheduledStartAt = schedule.scheduledStartAt
                    task.scheduledEndAt = schedule.scheduledEndAt
                    task.isAllDay = schedule.isAllDay
                } else {
                    task.dueDate = dueDate
                }
            }
            if mutation.clearEstimatedDuration {
                task.estimatedDuration = nil
            } else if let estimatedDuration = mutation.estimatedDuration {
                task.estimatedDuration = estimatedDuration
            }
            if let isComplete = mutation.isComplete {
                task.isComplete = isComplete
                task.dateCompleted = isComplete ? now : nil
            }
            task.updatedAt = now
            commands.append(.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task)))
        }

        let envelope = AssistantCommandEnvelope(
            schemaVersion: 2,
            commands: commands,
            // Shown as the proposal's summary and kept in chat history, so it
            // reads as a plain title rather than naming the source enum.
            rationaleText: Self.rationaleTitle(source: source, taskCount: commands.count)
        )
        let threadID = "eva_\(source.rawValue)_\(Int(now.timeIntervalSince1970))"
        return (threadID, envelope)
    }

    static func rationaleTitle(source: EvaBatchSource, taskCount: Int) -> String {
        switch source {
        case .triage:
            return taskCount == 1 ? String(localized: "Sort 1 task") : String(localized: "Sort \(taskCount) tasks")
        case .rescue:
            return taskCount == 1 ? String(localized: "Plan 1 task from earlier") : String(localized: "Plan \(taskCount) tasks from earlier")
        }
    }

    public func executeValidated(
        source: EvaBatchSource,
        tasksByID: [UUID: TaskDefinition],
        mutations: [EvaBatchMutationInstruction],
        now: Date = Date()
    ) throws -> (threadID: String, envelope: AssistantCommandEnvelope) {
        var seen = Set<UUID>()
        for mutation in mutations {
            guard seen.insert(mutation.taskID).inserted else {
                throw EvaBatchProposalError.duplicateTaskID(mutation.taskID)
            }
            guard let task = tasksByID[mutation.taskID] else {
                throw EvaBatchProposalError.missingTask(mutation.taskID)
            }
            if let expectedUpdatedAt = mutation.expectedUpdatedAt,
               abs(task.updatedAt.timeIntervalSince(expectedUpdatedAt)) > 0.001 {
                throw EvaBatchProposalError.staleTask(mutation.taskID)
            }
            guard task.isComplete == false else {
                throw EvaBatchProposalError.completedTask(mutation.taskID)
            }
            guard task.parentTaskID == nil else {
                throw EvaBatchProposalError.subtask(mutation.taskID)
            }
            guard mutation.clearDueDate == false || mutation.dueDate == nil,
                  mutation.clearEstimatedDuration == false || mutation.estimatedDuration == nil else {
                throw EvaBatchProposalError.invalidMutation(mutation.taskID)
            }
        }

        let proposal = execute(
            source: source,
            tasksByID: tasksByID,
            mutations: mutations,
            now: now
        )
        guard proposal.envelope.commands.count == mutations.count else {
            throw EvaBatchProposalError.commandCountMismatch(
                expected: mutations.count,
                actual: proposal.envelope.commands.count
            )
        }
        return proposal
    }
}
