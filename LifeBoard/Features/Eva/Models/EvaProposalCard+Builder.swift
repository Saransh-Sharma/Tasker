import Foundation

enum EvaProposalCardBuilder {
    static func build(
        commands: [AssistantCommand],
        taskTitleByID: [UUID: String] = [:],
        runID: UUID? = nil
    ) -> [EvaProposalCard] {
        commands.enumerated().map { index, command in
            card(for: command, commandIndex: index, taskTitleByID: taskTitleByID, runID: runID)
        }
    }

    static func groups(for cards: [EvaProposalCard]) -> [EvaProposalGroup] {
        let ordered: [(String, (EvaProposalCard) -> Bool)] = [
            (String(localized: "New tasks"), { $0.kind == .create }),
            (String(localized: "Schedule changes"), { [.edit, .move, .shorten].contains($0.kind) }),
            (String(localized: "Moved later"), { $0.kind == .deferred }),
            (String(localized: "Removals"), { [.drop, .delete].contains($0.kind) }),
            (String(localized: "Needs review"), { [.needsReview, .noOp].contains($0.kind) }),
            (String(localized: "Unchanged"), { $0.kind == .unchanged })
        ]
        return ordered.compactMap { title, predicate in
            let filtered = cards.filter(predicate)
            return filtered.isEmpty ? nil : EvaProposalGroup(title: title, cards: filtered)
        }
    }

    static func selectedEnvelope(
        from envelope: AssistantCommandEnvelope,
        selectedCardIDs: Set<UUID>,
        cards: [EvaProposalCard],
        overrides: [UUID: EvaProposalCardOverride] = [:]
    ) -> AssistantCommandEnvelope {
        let selectedIndexes = Set(
            cards
                .filter { selectedCardIDs.contains($0.id) }
                .flatMap(\.commandIndexes)
        )
        // Which card owns each command index, so a per-line edit lands on
        // exactly the commands that line stands for.
        var overrideByIndex: [Int: EvaProposalCardOverride] = [:]
        for card in cards {
            guard let override = overrides[card.id], override.isEmpty == false else { continue }
            for index in card.commandIndexes { overrideByIndex[index] = override }
        }
        let selectedCommands = envelope.commands.enumerated().compactMap { index, command -> AssistantCommand? in
            guard selectedIndexes.contains(index) else { return nil }
            return overrideByIndex[index]?.apply(to: command) ?? command
        }
        let selectedUndoCommands = envelope.undoCommands.map { undoCommands in
            undoCommands.enumerated().compactMap { index, command in
                selectedIndexes.contains(index) ? command : nil
            }
        }
        return AssistantCommandEnvelope(
            schemaVersion: envelope.schemaVersion,
            commands: selectedCommands,
            undoCommands: selectedUndoCommands,
            rationaleText: envelope.rationaleText
        )
    }

    static func noOpCard(title: String, subtitle: String, contextExplanation: String? = nil) -> EvaProposalCard {
        EvaProposalCard(
            id: UUID(),
            runID: nil,
            commandIndexes: [],
            kind: .noOp,
            title: title,
            subtitle: subtitle,
            before: nil,
            after: nil,
            badgeText: String(localized: "Review"),
            tone: .neutral,
            primaryAction: .edit,
            secondaryActions: [.discard],
            riskLevel: .needsReview,
            contextExplanation: contextExplanation,
            isSelectedByDefault: false
        )
    }

    private static func card(
        for command: AssistantCommand,
        commandIndex: Int,
        taskTitleByID: [UUID: String],
        runID: UUID?
    ) -> EvaProposalCard {
        switch command {
        case .createTask(_, let title):
            return createCard(
                title: title,
                subtitle: "Inbox",
                commandIndex: commandIndex,
                runID: runID,
                after: EvaTaskCardSnapshot(taskID: nil, title: title, iconSymbolName: nil, placement: "Inbox", dueDate: nil, scheduledStartAt: nil, scheduledEndAt: nil, estimatedDuration: nil)
            )
        case .createScheduledTask(_, let title, let start, let end, let duration, _, _, _, _, _, _, _):
            return createCard(
                title: title,
                subtitle: "\(format(date: start)), \(format(time: start))-\(format(time: end)) (\(durationText(duration ?? end.timeIntervalSince(start))))",
                commandIndex: commandIndex,
                runID: runID,
                after: EvaTaskCardSnapshot(taskID: nil, title: title, iconSymbolName: nil, placement: "Timeline", dueDate: start, scheduledStartAt: start, scheduledEndAt: end, estimatedDuration: duration ?? end.timeIntervalSince(start))
            )
        case .createInboxTask(_, let title, let duration, _, _, _, _, _):
            return createCard(
                title: title,
                subtitle: duration.map { "Inbox (\(durationText($0)))" } ?? "Inbox",
                commandIndex: commandIndex,
                runID: runID,
                after: EvaTaskCardSnapshot(taskID: nil, title: title, iconSymbolName: nil, placement: "Inbox", dueDate: nil, scheduledStartAt: nil, scheduledEndAt: nil, estimatedDuration: duration)
            )
        case .updateTaskSchedule(let taskID, let start, let end, let duration, let dueDate):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            let subtitle: String
            if let start, let end {
                subtitle = "\(format(date: start)), \(format(time: start))-\(format(time: end)) (\(durationText(duration ?? end.timeIntervalSince(start))))"
            } else if let dueDate {
                subtitle = "Move to \(format(date: dueDate))"
            } else {
                subtitle = String(localized: "New time")
            }
            return editCard(
                kind: .edit,
                title: title,
                subtitle: subtitle,
                badgeText: String(localized: "Edit"),
                commandIndex: commandIndex,
                runID: runID,
                after: EvaTaskCardSnapshot(taskID: taskID, title: title, iconSymbolName: nil, placement: "Timeline", dueDate: dueDate ?? start, scheduledStartAt: start, scheduledEndAt: end, estimatedDuration: duration)
            )
        case .updateTaskFields(let taskID, let newTitle, _, _, _, _, _, _, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            let resolvedTitle = newTitle.setValue
            return editCard(
                kind: .edit,
                title: resolvedTitle ?? title,
                subtitle: resolvedTitle == nil ? String(localized: "Edit details") : String(localized: "Rename from \(title)"),
                badgeText: String(localized: "Edit"),
                commandIndex: commandIndex,
                runID: runID,
                after: EvaTaskCardSnapshot(taskID: taskID, title: resolvedTitle ?? title, iconSymbolName: nil, placement: "Task", dueDate: nil, scheduledStartAt: nil, scheduledEndAt: nil, estimatedDuration: nil)
            )
        case .deferTask(let taskID, let targetDate, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return riskCard(kind: .deferred, title: title, subtitle: "Move to \(format(date: targetDate))", badgeText: String(localized: "Later"), commandIndex: commandIndex, runID: runID)
        case .dropTaskFromToday(let taskID, let destination, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return riskCard(kind: .drop, title: title, subtitle: String(localized: "Move to \(destination.displayLabel)"), badgeText: String(localized: "Off today"), commandIndex: commandIndex, runID: runID)
        case .deleteTask(let taskID):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return riskCard(kind: .delete, title: title, subtitle: "Delete task", badgeText: String(localized: "Review"), commandIndex: commandIndex, runID: runID)
        case .moveTask(let taskID, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return editCard(kind: .move, title: title, subtitle: "Move project", badgeText: String(localized: "Edit"), commandIndex: commandIndex, runID: runID, after: nil)
        case .updateTask(let taskID, let title, let dueDate):
            let display = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            let subtitle = dueDate.map { "Move to \(format(date: $0))" } ?? "Rename to \(title ?? display)"
            return editCard(kind: .edit, title: title ?? display, subtitle: subtitle, badgeText: String(localized: "Edit"), commandIndex: commandIndex, runID: runID, after: nil)
        case .setTaskCompletion(let taskID, let isComplete, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return editCard(kind: .edit, title: title, subtitle: isComplete ? "Mark complete" : "Reopen task", badgeText: String(localized: "Edit"), commandIndex: commandIndex, runID: runID, after: nil)
        case .completeTask(let taskID):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return editCard(kind: .edit, title: title, subtitle: "Mark complete", badgeText: String(localized: "Edit"), commandIndex: commandIndex, runID: runID, after: nil)
        case .restoreTask(_, _, let title, _, _, _):
            return editCard(kind: .edit, title: title, subtitle: "Restore task", badgeText: String(localized: "Edit"), commandIndex: commandIndex, runID: runID, after: nil)
        case .restoreTaskSnapshot(let snapshot):
            return editCard(
                kind: .edit,
                title: snapshot.title,
                subtitle: snapshot.scheduledStartAt.map { "\(format(date: $0)), \(format(time: $0))" } ?? String(localized: "Restore task"),
                badgeText: String(localized: "Edit"),
                commandIndex: commandIndex,
                runID: runID,
                after: EvaTaskCardSnapshot(taskID: snapshot.id, title: snapshot.title, iconSymbolName: nil, placement: "Task", dueDate: snapshot.dueDate, scheduledStartAt: snapshot.scheduledStartAt, scheduledEndAt: snapshot.scheduledEndAt, estimatedDuration: snapshot.estimatedDuration)
            )
        }
    }

    private static func createCard(title: String, subtitle: String, commandIndex: Int, runID: UUID?, after: EvaTaskCardSnapshot?) -> EvaProposalCard {
        EvaProposalCard(
            id: UUID(),
            runID: runID,
            commandIndexes: [commandIndex],
            kind: .create,
            title: title,
            subtitle: subtitle,
            before: nil,
            after: after,
            badgeText: String(localized: "New"),
            tone: .create,
            primaryAction: .add,
            secondaryActions: [.edit, .discard, .show],
            riskLevel: .safe,
            contextExplanation: String(localized: "From your request."),
            isSelectedByDefault: true
        )
    }

    private static func editCard(kind: EvaProposalKind, title: String, subtitle: String, badgeText: String, commandIndex: Int, runID: UUID?, after: EvaTaskCardSnapshot?) -> EvaProposalCard {
        EvaProposalCard(
            id: UUID(),
            runID: runID,
            commandIndexes: [commandIndex],
            kind: kind,
            title: title,
            subtitle: subtitle,
            before: nil,
            after: after,
            badgeText: badgeText,
            tone: .edit,
            primaryAction: .save,
            secondaryActions: [.show, .edit, .discard],
            riskLevel: .safe,
            contextExplanation: String(localized: "From your request."),
            isSelectedByDefault: true
        )
    }

    private static func riskCard(kind: EvaProposalKind, title: String, subtitle: String, badgeText: String, commandIndex: Int, runID: UUID?) -> EvaProposalCard {
        let isDeferral = kind == .deferred
        return EvaProposalCard(
            id: UUID(),
            runID: runID,
            commandIndexes: [commandIndex],
            kind: kind,
            title: title,
            subtitle: subtitle,
            before: nil,
            after: nil,
            badgeText: badgeText,
            tone: isDeferral ? .edit : .destructive,
            primaryAction: .save,
            secondaryActions: [.show, .edit, .discard],
            riskLevel: isDeferral ? .safe : .destructive,
            contextExplanation: isDeferral ? String(localized: "From your request.") : String(localized: "Confirm before applying."),
            isSelectedByDefault: isDeferral
        )
    }

    private static func displayTitle(taskID: UUID, taskTitleByID: [UUID: String]) -> String {
        let title = taskTitleByID[taskID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "task" : title
    }

    private static func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func format(time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    private static func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hr" : "\(hours) hr"
        }
        return "\(minutes) min"
    }
}
