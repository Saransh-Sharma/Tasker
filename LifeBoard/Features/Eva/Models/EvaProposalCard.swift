import Foundation

enum EvaProposalKind: String, Codable, Equatable, Hashable, Sendable {
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

enum EvaProposalTone: String, Codable, Equatable, Hashable, Sendable {
    case create
    case edit
    case neutral
    case warning
    case destructive
}

enum EvaProposalRisk: String, Codable, Equatable, Hashable, Sendable {
    case safe
    case needsReview
    case destructive
}

enum EvaProposalAction: String, Codable, Equatable, Hashable, Sendable {
    case add = "Add"
    case save = "Save"
    case edit = "Edit"
    case discard = "Discard"
    case show = "Show"
    /// Leaves the card out without judgement; nothing changes, nothing is
    /// called wrong. Recorded, never scolded.
    case notNow = "Not now"
}

/// A person's edit to one proposed line before it is applied: when, how
/// long, what it is called. Applied to the commands the card points at;
/// the apply gate sees the rewritten envelope like any other.
struct EvaProposalCardOverride: Codable, Equatable, Hashable, Sendable {
    var cardID: UUID
    var scheduledStartAt: Date?
    var estimatedDuration: TimeInterval?
    var title: String?

    var isEmpty: Bool { scheduledStartAt == nil && estimatedDuration == nil && (title?.isEmpty ?? true) }

    /// "3:00 PM · 45 min" for the card's badge.
    var badgeText: String? {
        var parts: [String] = []
        if let start = scheduledStartAt { parts.append(start.formatted(date: .omitted, time: .shortened)) }
        if let duration = estimatedDuration { parts.append("\(Int((duration / 60).rounded())) min") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func apply(to command: AssistantCommand) -> AssistantCommand {
        switch command {
        case let .updateTaskSchedule(taskID, start, end, duration, dueDate):
            let newStart = scheduledStartAt ?? start
            let newDuration = estimatedDuration ?? duration
            let newEnd: Date? = {
                guard let newStart else { return end }
                if let newDuration { return newStart.addingTimeInterval(newDuration) }
                if let start, let end { return newStart.addingTimeInterval(end.timeIntervalSince(start)) }
                return end
            }()
            return .updateTaskSchedule(taskID: taskID, scheduledStartAt: newStart, scheduledEndAt: newEnd, estimatedDuration: newDuration, dueDate: dueDate)
        case let .createScheduledTask(projectID, oldTitle, start, end, duration, lifeAreaID, priority, energy, category, context, details, tagIDs):
            let newStart = scheduledStartAt ?? start
            let newDuration = estimatedDuration ?? duration
            let newEnd = newDuration.map { newStart.addingTimeInterval($0) } ?? newStart.addingTimeInterval(end.timeIntervalSince(start))
            return .createScheduledTask(
                projectID: projectID, title: title?.isEmpty == false ? title! : oldTitle,
                scheduledStartAt: newStart, scheduledEndAt: newEnd, estimatedDuration: newDuration,
                lifeAreaID: lifeAreaID, priority: priority, energy: energy, category: category, context: context, details: details, tagIDs: tagIDs
            )
        case let .createInboxTask(projectID, oldTitle, duration, lifeAreaID, priority, category, details, tagIDs):
            return .createInboxTask(
                projectID: projectID, title: title?.isEmpty == false ? title! : oldTitle,
                estimatedDuration: estimatedDuration ?? duration,
                lifeAreaID: lifeAreaID, priority: priority, category: category, details: details, tagIDs: tagIDs
            )
        default:
            return command
        }
    }
}

struct EvaContextReceipt: Codable, Equatable, Hashable, Sendable {
    var sources: [String]

    static let empty = EvaContextReceipt(sources: [])

    var collapsedText: String {
        guard sources.isEmpty == false else { return String(localized: "Based on your tasks") }
        return String(localized: "Based on: \(sources.joined(separator: ", "))")
    }

    var compactSourceText: String {
        let labels = compactSourceLabels
        guard labels.isEmpty == false else { return String(localized: "your tasks") }
        return labels.joined(separator: ", ")
    }

    var compactReviewText: String {
        String(localized: "Based on: \(compactSourceText)")
    }

    private var compactSourceLabels: [String] {
        var labels: [String] = []
        for source in sources {
            let normalized = source.lowercased()
            appendCompactLabel(String(localized: "Today"), if: normalized.contains("today"), to: &labels)
            appendCompactLabel(String(localized: "from earlier"), if: normalized.contains("overdue"), to: &labels)
            appendCompactLabel(String(localized: "upcoming"), if: normalized.contains("upcoming"), to: &labels)
            appendCompactLabel(String(localized: "habits"), if: normalized.contains("habit"), to: &labels)
        }
        return labels
    }

    private func appendCompactLabel(_ label: String, if condition: Bool, to labels: inout [String]) {
        guard condition, labels.contains(label) == false else { return }
        labels.append(label)
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

struct EvaProposalCard: Identifiable, Codable, Equatable, Hashable, Sendable {
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

struct EvaProposalGroup: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String { title }
    var title: String
    var cards: [EvaProposalCard]
}

struct EvaProposalReviewPayload: Codable, Equatable, Sendable {
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
            return .blocked(message: String(localized: "Select a change to apply."))
        }
        if selectedCards.contains(where: { $0.kind == .drop || $0.kind == .delete || $0.riskLevel == .destructive }) {
            return .blocked(message: String(localized: "Deletes can’t be applied here. Deselect them."))
        }
        if selectedCards.contains(where: { $0.riskLevel != .safe }) {
            return .blocked(message: String(localized: "Some changes need review. Deselect them to apply."))
        }
        if selectedCards.count >= 5 && isHomogeneousSafeRescheduleSelection(selectedCards) == false {
            return .blocked(message: String(localized: "Select up to 4 changes at a time."))
        }
        return .allowed(appliedCount: selectedCards.count)
    }

    private static func isHomogeneousSafeRescheduleSelection(_ cards: [EvaProposalCard]) -> Bool {
        guard cards.isEmpty == false else { return false }
        return cards.count <= 20
            && cards.allSatisfy { card in
                card.riskLevel == .safe && (card.kind == .edit || card.kind == .deferred)
            }
    }
}

enum EvaProposalApplyButtonTitleResolver {
    static func title(cards: [EvaProposalCard], selectedCardIDs: Set<UUID>) -> String {
        let defaultIDs = Set(cards.filter(\.isSelectedByDefault).map(\.id))
        return selectedCardIDs == defaultIDs ? String(localized: "Apply all") : String(localized: "Apply selected")
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

final class EvaAppliedRunHistoryStore: @unchecked Sendable {
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
