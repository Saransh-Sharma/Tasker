import Foundation

/// Day Close writes its reflection to the `ReflectionNote` store (the weekly
/// review reads it there) *and* into that day's journal, so the journal is
/// the one place a person's own words live. The dual write is deliberate:
/// the review's reader stays untouched, and the journal block carries the
/// note's id in `promptID` so closing a day twice never duplicates it.
enum JournalDayCloseWriter {
    static let promptPrefix = "dayClose:"

    static func promptID(for noteID: UUID) -> String {
        promptPrefix + noteID.uuidString
    }

    /// The day with the close appended, or `nil` when it already carries
    /// this note (or the note has nothing to say and no energy).
    static func merged(day: JournalDayValue, noteID: UUID, text: String, energy: Int?, at now: Date = Date()) -> JournalDayValue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false || energy != nil else { return nil }
        let id = promptID(for: noteID)
        guard day.blocks.contains(where: { $0.promptID == id }) == false else { return nil }
        var updated = day
        updated.blocks.append(JournalBlockValue(
            dayID: day.id,
            kind: .dayClose,
            text: trimmed.isEmpty ? nil : trimmed,
            energy: energy,
            promptID: id,
            createdAt: now,
            updatedAt: now,
            ordinal: day.blocks.count
        ))
        updated.updatedAt = now
        return updated
    }
}
