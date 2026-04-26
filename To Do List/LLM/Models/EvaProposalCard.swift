import Foundation

enum EvaProposalKind: String, Codable, Equatable, Hashable {
    case create
    case edit
    case move
    case shorten
    case deferred = "defer"
    case drop
    case delete
    case unchanged
    case noOp
    case needsReview
}

enum EvaProposalTone: String, Codable, Equatable, Hashable {
    case create
    case edit
    case neutral
    case warning
    case destructive
}

enum EvaProposalRisk: String, Codable, Equatable, Hashable {
    case safe
    case needsReview
    case destructive
}

enum EvaProposalAction: String, Codable, Equatable, Hashable {
    case add = "Add"
    case save = "Save"
    case edit = "Edit"
    case discard = "Discard"
    case show = "Show"
}

struct EvaContextReceipt: Codable, Equatable, Hashable {
    var sources: [String]

    static let empty = EvaContextReceipt(sources: [])

    var collapsedText: String {
        guard sources.isEmpty == false else { return "EVA used task context" }
        return "EVA used \(sources.joined(separator: ", "))"
    }
}

struct EvaTaskCardSnapshot: Codable, Equatable, Hashable {
    var taskID: UUID?
    var title: String
    var iconSymbolName: String?
    var placement: String
    var dueDate: Date?
    var scheduledStartAt: Date?
    var scheduledEndAt: Date?
    var estimatedDuration: TimeInterval?
}

struct EvaProposalCard: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var runID: UUID?
    var commandIndexes: [Int]
    var kind: EvaProposalKind
    var title: String
    var subtitle: String
    var before: EvaTaskCardSnapshot?
    var after: EvaTaskCardSnapshot?
    var badgeText: String
    var tone: EvaProposalTone
    var primaryAction: EvaProposalAction
    var secondaryActions: [EvaProposalAction]
    var riskLevel: EvaProposalRisk
    var contextExplanation: String?
    var isSelectedByDefault: Bool
}

struct EvaProposalGroup: Identifiable, Codable, Equatable, Hashable {
    var id: String { title }
    var title: String
    var cards: [EvaProposalCard]
}

struct EvaProposalReviewPayload: Codable, Equatable {
    var prompt: String
    var summary: String
    var contextReceipt: EvaContextReceipt
    var cards: [EvaProposalCard]
    var appliedCardIDs: [UUID]
    var discardedCardCount: Int

    init(
        prompt: String,
        summary: String,
        contextReceipt: EvaContextReceipt,
        cards: [EvaProposalCard],
        appliedCardIDs: [UUID] = [],
        discardedCardCount: Int = 0
    ) {
        self.prompt = prompt
        self.summary = summary
        self.contextReceipt = contextReceipt
        self.cards = cards
        self.appliedCardIDs = appliedCardIDs
        self.discardedCardCount = discardedCardCount
    }
}

enum EvaProposalApplyGate: Equatable {
    enum Decision: Equatable {
        case allowed(appliedCount: Int)
        case blocked(message: String)
    }

    static func validate(selectedCards: [EvaProposalCard]) -> Decision {
        guard selectedCards.isEmpty == false else {
            return .blocked(message: "Select at least one card to apply.")
        }
        if selectedCards.contains(where: { $0.kind == .drop || $0.kind == .delete || $0.riskLevel == .destructive }) {
            return .blocked(message: "Drop and delete changes need a separate confirmation before EVA can apply them.")
        }
        if selectedCards.contains(where: { $0.riskLevel != .safe }) {
            return .blocked(message: "This plan includes high-impact changes. Deselect those cards before applying selected changes.")
        }
        if selectedCards.count >= 5 {
            return .blocked(message: "This plan changes 5 or more tasks. Apply a smaller selection first.")
        }
        return .allowed(appliedCount: selectedCards.count)
    }
}

enum EvaProposalApplyButtonTitleResolver {
    static func title(cards: [EvaProposalCard], selectedCardIDs: Set<UUID>) -> String {
        let defaultIDs = Set(cards.filter(\.isSelectedByDefault).map(\.id))
        return selectedCardIDs == defaultIDs ? "Apply all" : "Apply selected"
    }
}

struct EvaAppliedRunHistoryEntry: Codable, Equatable, Identifiable {
    var id: UUID { runID }
    let runID: UUID
    let threadID: String
    let prompt: String
    let summary: String
    let appliedCards: [EvaProposalCard]
    let discardedCardCount: Int
    let contextReceipt: EvaContextReceipt
    let appliedAt: Date
    let undoExpiresAt: Date
    let status: String
    let undoStatus: String
}

final class EvaAppliedRunHistoryStore {
    static let shared = EvaAppliedRunHistoryStore()

    private let defaults: UserDefaults
    private let key = "feature.eva.applied_run_history.entries"
    private let maxEntries = 50

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(_ entry: EvaAppliedRunHistoryEntry) {
        var current = entries()
        current.removeAll { $0.runID == entry.runID }
        current.insert(entry, at: 0)
        if current.count > maxEntries {
            current = Array(current.prefix(maxEntries))
        }
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: key)
        }
    }

    func entries() -> [EvaAppliedRunHistoryEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([EvaAppliedRunHistoryEntry].self, from: data)) ?? []
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

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
            ("Creates", { $0.kind == .create }),
            ("Schedule changes", { [.edit, .move, .shorten].contains($0.kind) }),
            ("Deferrals", { $0.kind == .deferred }),
            ("Drops / Deletes", { [.drop, .delete].contains($0.kind) }),
            ("Needs review", { [.needsReview, .noOp].contains($0.kind) }),
            ("Unchanged", { $0.kind == .unchanged })
        ]
        return ordered.compactMap { title, predicate in
            let filtered = cards.filter(predicate)
            return filtered.isEmpty ? nil : EvaProposalGroup(title: title, cards: filtered)
        }
    }

    static func selectedEnvelope(
        from envelope: AssistantCommandEnvelope,
        selectedCardIDs: Set<UUID>,
        cards: [EvaProposalCard]
    ) -> AssistantCommandEnvelope {
        let selectedIndexes = Set(
            cards
                .filter { selectedCardIDs.contains($0.id) }
                .flatMap(\.commandIndexes)
        )
        let selectedCommands = envelope.commands.enumerated().compactMap { index, command in
            selectedIndexes.contains(index) ? command : nil
        }
        return AssistantCommandEnvelope(
            schemaVersion: envelope.schemaVersion,
            commands: selectedCommands,
            undoCommands: nil,
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
            badgeText: "NEEDS REVIEW",
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
                subtitle = "Update schedule"
            }
            return editCard(
                kind: .edit,
                title: title,
                subtitle: subtitle,
                badgeText: "EDIT",
                commandIndex: commandIndex,
                runID: runID,
                after: EvaTaskCardSnapshot(taskID: taskID, title: title, iconSymbolName: nil, placement: "Timeline", dueDate: dueDate ?? start, scheduledStartAt: start, scheduledEndAt: end, estimatedDuration: duration)
            )
        case .updateTaskFields(let taskID, let newTitle, _, _, _, _, _, _, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return editCard(
                kind: .edit,
                title: newTitle ?? title,
                subtitle: newTitle == nil ? "Update task details" : "Rename from \(title)",
                badgeText: "EDIT",
                commandIndex: commandIndex,
                runID: runID,
                after: EvaTaskCardSnapshot(taskID: taskID, title: newTitle ?? title, iconSymbolName: nil, placement: "Task", dueDate: nil, scheduledStartAt: nil, scheduledEndAt: nil, estimatedDuration: nil)
            )
        case .deferTask(let taskID, let targetDate, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return riskCard(kind: .deferred, title: title, subtitle: "Move to \(format(date: targetDate))", badgeText: "DEFER", commandIndex: commandIndex, runID: runID)
        case .dropTaskFromToday(let taskID, let destination, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return riskCard(kind: .drop, title: title, subtitle: "Drop from today to \(destination.rawValue)", badgeText: "DROP", commandIndex: commandIndex, runID: runID)
        case .deleteTask(let taskID):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return riskCard(kind: .delete, title: title, subtitle: "Delete task", badgeText: "NEEDS REVIEW", commandIndex: commandIndex, runID: runID)
        case .moveTask(let taskID, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return editCard(kind: .move, title: title, subtitle: "Move project", badgeText: "EDIT", commandIndex: commandIndex, runID: runID, after: nil)
        case .updateTask(let taskID, let title, let dueDate):
            let display = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            let subtitle = dueDate.map { "Move to \(format(date: $0))" } ?? "Rename to \(title ?? display)"
            return editCard(kind: .edit, title: title ?? display, subtitle: subtitle, badgeText: "EDIT", commandIndex: commandIndex, runID: runID, after: nil)
        case .setTaskCompletion(let taskID, let isComplete, _):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return editCard(kind: .edit, title: title, subtitle: isComplete ? "Mark complete" : "Reopen task", badgeText: "EDIT", commandIndex: commandIndex, runID: runID, after: nil)
        case .completeTask(let taskID):
            let title = displayTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return editCard(kind: .edit, title: title, subtitle: "Mark complete", badgeText: "EDIT", commandIndex: commandIndex, runID: runID, after: nil)
        case .restoreTask(_, _, let title, _, _, _):
            return editCard(kind: .edit, title: title, subtitle: "Restore task", badgeText: "EDIT", commandIndex: commandIndex, runID: runID, after: nil)
        case .restoreTaskSnapshot(let snapshot):
            return editCard(
                kind: .edit,
                title: snapshot.title,
                subtitle: snapshot.scheduledStartAt.map { "\(format(date: $0)), \(format(time: $0))" } ?? "Restore task snapshot",
                badgeText: "EDIT",
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
            badgeText: "CREATE",
            tone: .create,
            primaryAction: .add,
            secondaryActions: [.edit, .discard, .show],
            riskLevel: .safe,
            contextExplanation: "Scheduled from your prompt.",
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
            contextExplanation: "You asked EVA to update this task.",
            isSelectedByDefault: true
        )
    }

    private static func riskCard(kind: EvaProposalKind, title: String, subtitle: String, badgeText: String, commandIndex: Int, runID: UUID?) -> EvaProposalCard {
        EvaProposalCard(
            id: UUID(),
            runID: runID,
            commandIndexes: [commandIndex],
            kind: kind,
            title: title,
            subtitle: subtitle,
            before: nil,
            after: nil,
            badgeText: badgeText,
            tone: kind == .deferred ? .warning : .destructive,
            primaryAction: .save,
            secondaryActions: [.show, .edit, .discard],
            riskLevel: kind == .deferred ? .needsReview : .destructive,
            contextExplanation: "EVA needs confirmation before applying this change.",
            isSelectedByDefault: false
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
