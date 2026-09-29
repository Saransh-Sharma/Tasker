import Foundation
import LifeBoardDomain

/// "Try for a week": one small, reversible change taken from a correlation,
/// kept as a `ReflectionNote` of kind `.insightExperiment` (the note's text
/// is this record, JSON-encoded; the kind column is a free string, so no
/// schema version). The weekly review asks "Did it help?" after seven days,
/// the way Friction Detective's loop does.
struct InsightExperiment: Codable, Equatable, Identifiable, Sendable {
    enum Action: Codable, Equatable, Sendable {
        /// A habit created from a catalog template; `habitID` once it exists.
        case habit(templateID: String, habitID: UUID?)
    }

    enum Verdict: String, Codable, Sendable {
        case helped, didNotHelp, unsure
    }

    let id: UUID
    /// "On days with more focus, your energy tended to be higher …"
    let hypothesis: String
    let sourceCorrelationID: String
    let action: Action
    let startedAt: Date
    let endsAt: Date
    var verdict: Verdict?

    static let durationDays = 7

    init(id: UUID = UUID(), hypothesis: String, sourceCorrelationID: String, action: Action, startedAt: Date = Date(), calendar: Calendar = .current) {
        self.id = id
        self.hypothesis = hypothesis
        self.sourceCorrelationID = sourceCorrelationID
        self.action = action
        self.startedAt = startedAt
        self.endsAt = calendar.date(byAdding: .day, value: Self.durationDays, to: startedAt) ?? startedAt.addingTimeInterval(TimeInterval(Self.durationDays * 86_400))
        self.verdict = nil
    }

    var isDue: Bool { Date() >= endsAt && verdict == nil }

    var habitID: UUID? {
        if case let .habit(_, id) = action { return id }
        return nil
    }

    // MARK: Note round trip

    static let noteKind = ReflectionNoteKind.insightExperiment

    func note(existing: ReflectionNote? = nil) throws -> ReflectionNote {
        let data = try JSONEncoder().encode(self)
        var note = existing ?? ReflectionNote(id: id, kind: Self.noteKind, noteText: "", createdAt: startedAt)
        note.kind = Self.noteKind
        note.noteText = String(decoding: data, as: UTF8.self)
        note.prompt = hypothesis
        note.linkedHabitID = habitID
        note.updatedAt = Date()
        return note
    }

    static func experiment(from note: ReflectionNote) -> InsightExperiment? {
        guard note.kind == noteKind, let data = note.noteText.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(InsightExperiment.self, from: data)
    }
}

/// Which receipt may offer Undo for an experiment start.
///
/// Only the receipt whose id is the experiment that was actually started. A
/// failure receipt carries a fresh id, so it can never cancel an earlier,
/// successful experiment.
enum InsightsExperimentUndoPolicy {
    static func canUndo(receiptID: UUID, lastStartedID: UUID?) -> Bool {
        guard let lastStartedID else { return false }
        return receiptID == lastStartedID
    }
}

/// Which template a correlation suggests trying. The map is small and
/// explicit; a correlation with no sensible action offers nothing.
enum InsightExperimentSuggestion {
    static func templateID(for result: DailyCorrelationEngine.Result) -> String? {
        let metrics: Set<DailyMetric> = [result.first, result.second]
        if metrics.contains(.steps) { return "walk" }
        if metrics.contains(.sleepHours) { return "no-phone-after-ten" }
        if metrics.contains(.focusMinutes) { return "meditate" }
        if metrics.contains(.journalEnergy) { return "water" }
        return nil
    }
}
