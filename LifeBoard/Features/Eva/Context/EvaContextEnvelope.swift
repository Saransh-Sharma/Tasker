import Foundation
import LifeBoardDomain

/// The typed context envelope EVA sends to the cloud.
///
/// Contract v1 sent one plain-text blob: six task titles reduced to
/// `title | due | project`, chosen by substring matching under a 450 ms deadline
/// over a 32-task slice, then truncated with `String.prefix` — which could cut a
/// UUID in half. Everything that makes a task interesting to reason about was
/// dropped on the floor: priority, energy, estimates, how many times it had been
/// pushed.
///
/// Two rules shape what follows:
///
/// - **Records, not prose.** A model asked to plan needs fields it can compare,
///   not a rendered list. `deferredCount` and `replanCount` matter most: they are
///   the difference between reading someone's list back to them and being able
///   to say "you have moved this four times; it is not going to happen this week."
/// - **Whole records or none.** Overflow drops the lowest-value record entirely
///   rather than truncating mid-object, so the envelope is always well-formed and
///   an identifier is never half-present.
///
/// This type is cloud-only by construction. The offline path never builds one —
/// see `EvaContextEnvelopeBuilder.RenderMode`.
struct EvaContextEnvelope: Sendable {
    var sections: [EvaCloudContextSection]

    /// Sections ordered slowest-moving first.
    ///
    /// The Worker sets an explicit prompt-cache breakpoint after the developer
    /// message, and OpenAI caches on a shared prefix. Goals and capacity barely
    /// change between turns while the planning roster changes constantly, so
    /// emitting them in this order keeps the cacheable prefix as long as
    /// possible. Reordering this list silently raises cost per turn.
    static let cacheFriendlyOrder: [EvaCloudContextSection.Category] = [
        .personalMemory, .goals, .retrospective, .habits, .dayLoop,
        .capacity, .calendar, .planning, .conversationSummary,
        .journal, .health, .lifeMoments,
    ]

    func ordered() -> [EvaCloudContextSection] {
        let rank = Dictionary(
            uniqueKeysWithValues: Self.cacheFriendlyOrder.enumerated().map { ($1, $0) }
        )
        return sections.sorted { (rank[$0.category] ?? .max) < (rank[$1.category] ?? .max) }
    }
}

extension TaskPriority {
    /// The contract's spelling of a priority.
    ///
    /// `rawValue` is an `Int32` storage code, so interpolating it into JSON
    /// produces `"priority":"3"` — which the schema rejects and a model cannot
    /// interpret. `AISuggestionService.parseTaskPriority` already reads these
    /// names on the way in; this is the missing way out.
    var evaWireName: String {
        switch self {
        case .none: "none"
        case .low: "low"
        case .high: "high"
        case .max: "max"
        }
    }
}

/// One task as EVA sees it. Mirrors `EvaTaskRecordSchema` in
/// `Shared/EVACloudContracts/src/context.ts`; the Worker rejects the request
/// when the two drift, which is the point of typing it at all.
struct EvaTaskRecord: Encodable, Sendable {
    enum Bucket: String, Encodable, Sendable {
        case overdue, today, tomorrow, thisWeek, unscheduled, completed
    }

    let id: UUID
    let title: String
    let project: String?
    let projectID: UUID?
    let lifeArea: String?
    let priority: String
    let energy: String?
    let estimatedMinutes: Int?
    let actualMinutes: Int?
    let due: Date?
    let scheduledStart: Date?
    let scheduledEnd: Date?
    let bucket: Bucket
    let deferredCount: Int
    let replanCount: Int
    let ageDays: Int
    let notesExcerpt: String?
    let blockedBy: [UUID]
    let rankReasons: [String]

    /// Ranks how much a record is worth keeping when the envelope overflows.
    ///
    /// Overdue and repeatedly-deferred work is what a person most needs help
    /// with, so it survives longest; unscheduled backlog goes first.
    var retentionScore: Int {
        var score = 0
        switch bucket {
        case .overdue: score += 100
        case .today: score += 80
        case .tomorrow: score += 50
        case .thisWeek: score += 30
        case .unscheduled: score += 5
        case .completed: score += 1
        }
        score += min(40, (deferredCount + replanCount) * 8)
        switch priority {
        case "max": score += 25
        case "high": score += 15
        case "low": score += 2
        default: break
        }
        return score
    }
}

extension EvaTaskRecord {
    init(
        task: TaskDefinition,
        bucket: Bucket,
        projectName: String?,
        lifeAreaName: String?,
        rankReasons: [String] = [],
        now: Date
    ) {
        self.id = task.id
        self.title = String(task.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        self.project = projectName?.isEmpty == false ? projectName : nil
        self.projectID = task.projectID
        self.lifeArea = lifeAreaName?.isEmpty == false ? lifeAreaName : nil
        self.priority = task.priority.evaWireName
        self.energy = task.energy.rawValue
        self.estimatedMinutes = task.estimatedDuration.map { max(0, Int($0 / 60)) }
        self.actualMinutes = task.actualDuration.map { max(0, Int($0 / 60)) }
        self.due = task.dueDate
        self.scheduledStart = task.scheduledStartAt
        self.scheduledEnd = task.scheduledEndAt
        self.bucket = bucket
        self.deferredCount = max(0, task.deferredCount)
        self.replanCount = max(0, task.replanCount)
        self.ageDays = max(0, Calendar.current.dateComponents([.day], from: task.dateAdded, to: now).day ?? 0)
        let details = task.details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.notesExcerpt = details.isEmpty ? nil : String(details.prefix(400))
        self.blockedBy = Array(task.dependencies.map(\.dependsOnTaskID).prefix(8))
        self.rankReasons = Array(rankReasons.prefix(4))
    }
}

/// A habit with the shape of its recent history, not just a due flag.
struct EvaHabitRecord: Encodable, Sendable {
    let id: UUID
    let title: String
    let lifeArea: String?
    let dueToday: Bool
    let isOverdue: Bool
    let currentStreak: Int
    let bestStreak: Int
    let adherenceFraction: Double?
    let last14Days: [String]
    let bestTimeMinutesFromMidnight: Int?

    init(signal: LifeBoardHabitSignal) {
        self.id = signal.habitID
        self.title = String(signal.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        self.lifeArea = signal.lifeAreaName?.isEmpty == false ? signal.lifeAreaName : nil
        self.dueToday = signal.isDueToday
        self.isOverdue = signal.isOverdue
        self.currentStreak = max(0, signal.currentStreak)
        self.bestStreak = max(0, signal.bestStreak)
        // Oldest day first, so index order reads as chronological.
        let marks = signal.last14Days.sorted { $0.date < $1.date }
        self.last14Days = marks.map { mark in
            switch mark.state {
            case .success: "hit"
            case .failure: "miss"
            case .skipped: "skip"
            case .none, .future: "unknown"
            }
        }
        // Days that have not happened yet are not misses, so they are excluded
        // from the denominator rather than counted against the person.
        let resolved = marks.filter { $0.state == .success || $0.state == .failure }
        self.adherenceFraction = resolved.isEmpty
            ? nil
            : Double(resolved.filter { $0.state == .success }.count) / Double(resolved.count)
        self.bestTimeMinutesFromMidnight = nil
    }
}
