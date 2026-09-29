import Foundation

/// Read-time derivations for browsing the journal: what a calendar cell
/// carries, and which older days rhyme with today. All pure; the store's
/// loaded days are the only input, so no new query and no new schema.
enum JournalCalendarMarks {
    struct Mark: Equatable {
        let dayID: UUID
        let hasText: Bool
        let mood: JournalMood?
        let photoCount: Int
        let isStarred: Bool

        /// "2 photos, feeling calm, written" for VoiceOver.
        var accessibilityValue: String {
            var parts: [String] = []
            if hasText { parts.append("written") }
            if let mood, mood != .none { parts.append("feeling \(mood.title.lowercased())") }
            if photoCount > 0 { parts.append(photoCount == 1 ? "1 photo" : "\(photoCount) photos") }
            if isStarred { parts.append("starred") }
            return parts.isEmpty ? "Nothing written" : parts.joined(separator: ", ")
        }
    }

    /// Marks keyed by the start of day, for the given month only.
    static func marks(for days: [JournalDayValue], month: Date, calendar: Calendar = .current) -> [Date: Mark] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [:] }
        var result: [Date: Mark] = [:]
        for day in days where interval.contains(day.day) {
            let start = calendar.startOfDay(for: day.day)
            let photos = day.media.filter { $0.kind == .photo }.count
            let hasText = day.blocks.contains { ($0.text ?? "").isEmpty == false && $0.kind != .mood }
            result[start] = Mark(dayID: day.id, hasText: hasText, mood: day.latestMood, photoCount: photos, isStarred: day.isStarred)
        }
        return result
    }
}

/// "On this day": the same calendar day a year, six months, three months and
/// one month ago, when something was written. Not an AI surface, so it does
/// not consult `aiExclusion`; the person is looking at their own words.
enum JournalOnThisDay {
    struct Match: Identifiable, Equatable {
        let day: JournalDayValue
        let label: String
        var id: UUID { day.id }
    }

    static let offsets: [(months: Int, label: String)] = [
        (12, "A year ago today"),
        (6, "6 months ago today"),
        (3, "3 months ago today"),
        (1, "A month ago today"),
    ]

    static func matches(in days: [JournalDayValue], now: Date = Date(), calendar: Calendar = .current) -> [Match] {
        let byDay = Dictionary(days.map { (calendar.startOfDay(for: $0.day), $0) }, uniquingKeysWith: { first, _ in first })
        return offsets.compactMap { offset in
            guard let then = calendar.date(byAdding: .month, value: -offset.months, to: now) else { return nil }
            guard let day = byDay[calendar.startOfDay(for: then)], day.blocks.isEmpty == false else { return nil }
            return Match(day: day, label: offset.label)
        }
    }
}
