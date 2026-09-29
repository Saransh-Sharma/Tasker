//
//  TaskCaptureParser.swift
//  LifeBoard
//
//  Lightweight, on-device natural-language date extraction for task capture.
//  Pure and synchronous: no I/O, no network. Used by lightning capture, the
//  headless AddTaskIntent, and the Share Extension so every capture entry point
//  understands phrases like "call mom tomorrow 3pm" without hidden magic — the
//  caller is expected to surface the inferred date as a correctable chip.
//

import Foundation

/// Result of parsing a raw capture string into a clean title and structured metadata.
///
/// Every field is a *proposal*. The caller is expected to render each one as a
/// correctable chip and commit nothing the user has not seen — see
/// `InboxStore.proposal(for:)`, which is the only production reader.
public struct ParsedCapture: Codable, Equatable, Hashable, Sendable {
    /// The title with any recognized tokens removed and whitespace collapsed.
    public let cleanTitle: String
    /// The resolved due date, if a date or time phrase was recognized.
    public let dueDate: Date?
    /// True when only a calendar day (no time of day) was recognized.
    public let isAllDay: Bool
    /// The substring(s) that were recognized and stripped, for display/undo. Nil when nothing matched.
    public let matchedText: String?
    /// Estimated work, from "for 45 min" / "for 1h30". Distinct from `dueDate`:
    /// "in 45 minutes" is when it is due, "for 45 minutes" is how long it takes.
    public let duration: TimeInterval?
    /// From `+name`. The name only — resolving it to a project ID needs the task
    /// repository, which this pure parser deliberately does not have.
    public let projectName: String?
    /// From `#tag`, in the order written, de-duplicated case-insensitively.
    public let tags: [String]
    /// From `@place`. Requires a letter after `@` so it can never swallow `@3pm`.
    public let context: String?
    /// From "every monday", "daily", "weekdays", "every 2 weeks".
    public let repeatPattern: TaskRepeatPattern?
    /// From `!high` / `p2`. Absent is not `.none` — `.none` is a priority the
    /// user chose, absent means they did not say.
    public let priority: TaskPriorityConfig.Priority?

    public init(
        cleanTitle: String,
        dueDate: Date?,
        isAllDay: Bool,
        matchedText: String?,
        duration: TimeInterval? = nil,
        projectName: String? = nil,
        tags: [String] = [],
        context: String? = nil,
        repeatPattern: TaskRepeatPattern? = nil,
        priority: TaskPriorityConfig.Priority? = nil
    ) {
        self.cleanTitle = cleanTitle
        self.dueDate = dueDate
        self.isAllDay = isAllDay
        self.matchedText = matchedText
        self.duration = duration
        self.projectName = projectName
        self.tags = tags
        self.context = context
        self.repeatPattern = repeatPattern
        self.priority = priority
    }

    /// Whether anything at all was recognized. Used to decide whether a review
    /// chip row is worth showing.
    public var hasProposals: Bool {
        dueDate != nil || duration != nil || projectName != nil
            || tags.isEmpty == false || context != nil
            || repeatPattern != nil || priority != nil
    }
}

public enum TaskCaptureParser {

    /// Parses a raw capture string. `now`/`calendar` are injectable for deterministic tests.
    public static func parse(
        _ raw: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ParsedCapture {
        parseWithPieces(raw, now: now, calendar: calendar).capture
    }

    /// The recognized pieces behind `parse`, in reading order. Empty when the
    /// parse claimed nothing (including when stripping would empty the title).
    public static func pieces(
        _ raw: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CaptureTokenPiece] {
        parseWithPieces(raw, now: now, calendar: calendar).pieces
    }

    private static func parseWithPieces(
        _ raw: String,
        now: Date,
        calendar: Calendar
    ) -> (capture: ParsedCapture, pieces: [CaptureTokenPiece]) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return (ParsedCapture(cleanTitle: trimmed, dueDate: nil, isAllDay: false, matchedText: nil), [])
        }
        var pieceKinds: [Range<String.Index>: CaptureTokenPiece.Kind] = [:]

        var removalRanges: [Range<String.Index>] = []
        var matchedPieces: [(Range<String.Index>, String)] = []

        /// Claims a range unless it collides with one already taken. Ordering
        /// below is therefore precedence: the first pass to claim a substring
        /// owns it.
        func claim(_ range: Range<String.Index>, as kind: CaptureTokenPiece.Kind) -> Bool {
            guard removalRanges.contains(where: { $0.overlaps(range) }) == false else { return false }
            pieceKinds[range] = kind
            removalRanges.append(range)
            matchedPieces.append((range, String(trimmed[range])))
            return true
        }

        // 1) Explicit tokens. First because they are unambiguous punctuation the
        //    user typed deliberately, and because `@place` must be claimed before
        //    anything else can look at an `@`.
        let tokens = tokenMatches(in: trimmed)
        for token in tokens.tags where claim(token.range, as: .tag) { }
        if let project = tokens.project { _ = claim(project.range, as: .project) }
        if let context = tokens.context { _ = claim(context.range, as: .context) }

        // 2) Recurrence, before the date pass: "every monday" would otherwise be
        //    consumed by the weekday matcher and become a one-off due date, which
        //    silently turns a repeating commitment into a single task.
        let recurrenceMatch = firstRecurrenceMatch(in: trimmed)
        if let recurrenceMatch { _ = claim(recurrenceMatch.range, as: .repeatPattern) }

        // 3) Duration, before the date pass so "for 45 min" cannot be misread by
        //    the "in N units" instant rule. The two are genuinely different
        //    claims: when it is due versus how long it takes.
        let durationMatch = firstDurationMatch(in: trimmed)
        if let durationMatch { _ = claim(durationMatch.range, as: .duration) }

        // 4) Priority.
        let priorityMatch = firstPriorityMatch(in: trimmed)
        if let priorityMatch { _ = claim(priorityMatch.range, as: .priority) }

        // 5) Date phrase (relative words, weekdays, "in N units", or absolute via NSDataDetector).
        var dateMatch = firstDateMatch(in: trimmed, now: now, calendar: calendar)
        if let resolved = dateMatch, claim(resolved.range, as: .date) == false { dateMatch = nil }

        // 6) Time phrase — only if it doesn't overlap anything already claimed.
        var timeMatch = firstTimeMatch(in: trimmed)
        if let resolved = timeMatch, claim(resolved.range, as: .time) == false { timeMatch = nil }

        // Resolve the final due date from the date/time parts.
        let resolution = resolveDueDate(
            date: dateMatch?.phrase,
            time: timeMatch.map { ($0.hour, $0.minute) },
            now: now,
            calendar: calendar
        )

        // A date phrase that matched but could not be resolved into an instant
        // (an invalid component combination, a DST gap) must not still cost the
        // user those words. Give them back rather than stripping text and having
        // no date to show for it.
        if resolution.dueDate == nil {
            let dateRanges = [dateMatch?.range, timeMatch?.range].compactMap { $0 }
            removalRanges.removeAll { range in dateRanges.contains { $0 == range } }
            matchedPieces.removeAll { piece in dateRanges.contains { $0 == piece.0 } }
        }

        let strippedCandidate = strippedTitle(from: trimmed, removing: removalRanges)
        // If stripping consumed the entire input, what looked like metadata was
        // really the whole title ("tomorrow", "#groceries"). Keep the original
        // text and claim nothing — a task called "" helps nobody.
        guard strippedCandidate.isEmpty == false else {
            return (ParsedCapture(cleanTitle: trimmed, dueDate: nil, isAllDay: false, matchedText: nil), [])
        }

        let orderedPieces = matchedPieces
            .sorted { $0.0.lowerBound < $1.0.lowerBound }
            .compactMap { piece in
                pieceKinds[piece.0].map { kind in
                    let base = raw.range(of: trimmed)?.lowerBound ?? raw.startIndex
                    let offset = raw[..<base].utf16.count
                    let range = NSRange(piece.0, in: trimmed)
                    return CaptureTokenPiece(kind: kind, text: piece.1.trimmingCharacters(in: .whitespaces),
                        sourceRange: NSRange(location: range.location + offset, length: range.length))
                }
            }

        let matchedText = matchedPieces
            .sorted { $0.0.lowerBound < $1.0.lowerBound }
            .map(\.1)
            .joined(separator: " ")

        let capture = ParsedCapture(
            cleanTitle: strippedCandidate,
            dueDate: resolution.dueDate,
            isAllDay: resolution.dueDate == nil ? false : resolution.isAllDay,
            matchedText: matchedText.isEmpty ? nil : matchedText,
            duration: durationMatch?.seconds,
            projectName: tokens.project?.value,
            tags: tokens.tagValues,
            context: tokens.context?.value,
            repeatPattern: recurrenceMatch?.pattern,
            priority: priorityMatch?.priority
        )
        return (capture, orderedPieces)
    }

    // MARK: - Date resolution

    private enum DatePhrase {
        case day(Date)          // a calendar day, all-day unless a time is also present
        case instant(Date)      // a precise instant (e.g. "in 2 hours") — time already known
        case eveningDay(Date)   // "tonight" — this day, default evening time unless time given
    }

    private struct DateMatch {
        let phrase: DatePhrase
        let range: Range<String.Index>
    }

    private struct TimeMatch {
        let hour: Int
        let minute: Int
        let range: Range<String.Index>
    }

    private static func resolveDueDate(
        date: DatePhrase?,
        time: (hour: Int, minute: Int)?,
        now: Date,
        calendar: Calendar
    ) -> (dueDate: Date?, isAllDay: Bool) {
        switch date {
        case .instant(let instant):
            return (instant, false)
        case .eveningDay(let day):
            let h = time?.hour ?? 19
            let m = time?.minute ?? 0
            return (calendar.date(bySettingHour: h, minute: m, second: 0, of: day), false)
        case .day(let day):
            if let time {
                return (calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day), false)
            }
            return (calendar.startOfDay(for: day), true)
        case .none:
            guard let time else { return (nil, false) }
            // Time only: today at h:m, rolling to tomorrow if already past.
            let today = calendar.startOfDay(for: now)
            guard let candidate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: today) else {
                return (nil, false)
            }
            if candidate <= now {
                return (calendar.date(byAdding: .day, value: 1, to: candidate), false)
            }
            return (candidate, false)
        }
    }

    // MARK: - Date matching

    private static func firstDateMatch(in text: String, now: Date, calendar: Calendar) -> DateMatch? {
        // "in N days/weeks/hours/minutes"
        if let m = regexMatch(#"\b(?:in)\s+(\d{1,3})\s+(day|days|week|weeks|hour|hours|min|mins|minute|minutes)\b"#, in: text),
           let value = Int(captured(m.groups, 1, in: text) ?? "") {
            let unit = (captured(m.groups, 2, in: text) ?? "").lowercased()
            switch unit {
            case "hour", "hours":
                if let d = calendar.date(byAdding: .hour, value: value, to: now) { return DateMatch(phrase: .instant(d), range: m.range) }
            case "min", "mins", "minute", "minutes":
                if let d = calendar.date(byAdding: .minute, value: value, to: now) { return DateMatch(phrase: .instant(d), range: m.range) }
            case "week", "weeks":
                if let d = calendar.date(byAdding: .day, value: value * 7, to: now) { return DateMatch(phrase: .day(d), range: m.range) }
            default:
                if let d = calendar.date(byAdding: .day, value: value, to: now) { return DateMatch(phrase: .day(d), range: m.range) }
            }
        }

        // "tonight"
        if let m = regexMatch(#"\btonight\b"#, in: text) {
            return DateMatch(phrase: .eveningDay(calendar.startOfDay(for: now)), range: m.range)
        }
        // "today"
        if let m = regexMatch(#"\btoday\b"#, in: text) {
            return DateMatch(phrase: .day(calendar.startOfDay(for: now)), range: m.range)
        }
        // "tomorrow" / "tmrw" / "tmr"
        if let m = regexMatch(#"\b(?:tomorrow|tmrw|tmr)\b"#, in: text),
           let d = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            return DateMatch(phrase: .day(d), range: m.range)
        }
        // "next weekend" / "this weekend" / "weekend" → upcoming Saturday
        if let m = regexMatch(#"\b(?:next\s+|this\s+)?weekend\b"#, in: text),
           let sat = nextWeekday(7, after: now, calendar: calendar, addWeek: text.lowercased().contains("next weekend")) {
            return DateMatch(phrase: .day(sat), range: m.range)
        }
        // "next week"
        if let m = regexMatch(#"\bnext\s+week\b"#, in: text),
           let d = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) {
            return DateMatch(phrase: .day(d), range: m.range)
        }
        // Weekday names, optionally prefixed with this/next/on/by
        if let m = regexMatch(
            #"\b(?:(this|next|on|by)\s+)?(monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thu|friday|fri|saturday|sat|sunday|sun)\b"#,
            in: text
        ) {
            let prefix = (captured(m.groups, 1, in: text) ?? "").lowercased()
            let dayWord = (captured(m.groups, 2, in: text) ?? "").lowercased()
            // "next friday" is treated as the upcoming friday (not the one after) to match common intent.
            _ = prefix
            if let weekday = weekdayIndex(for: dayWord),
               let d = nextWeekday(weekday, after: now, calendar: calendar, addWeek: false) {
                return DateMatch(phrase: .day(d), range: m.range)
            }
        }

        // Absolute dates ("Sept 3", "12/25", "March 5 at 4pm") via NSDataDetector.
        if let m = dataDetectorDateMatch(in: text) {
            return m
        }

        return nil
    }

    private static func weekdayIndex(for word: String) -> Int? {
        // Gregorian: 1 = Sunday ... 7 = Saturday
        switch word {
        case "sunday", "sun": return 1
        case "monday", "mon": return 2
        case "tuesday", "tue", "tues": return 3
        case "wednesday", "wed": return 4
        case "thursday", "thu", "thurs": return 5
        case "friday", "fri": return 6
        case "saturday", "sat": return 7
        default: return nil
        }
    }

    private static func nextWeekday(_ weekday: Int, after now: Date, calendar: Calendar, addWeek: Bool) -> Date? {
        let components = DateComponents(weekday: weekday)
        guard let next = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return nil }
        let day = calendar.startOfDay(for: next)
        return addWeek ? calendar.date(byAdding: .day, value: 7, to: day) : day
    }

    private static func dataDetectorDateMatch(in text: String) -> DateMatch? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, options: [], range: nsRange),
              let date = match.date,
              let range = Range(match.range, in: text) else { return nil }

        // A bare time ("3pm", "at 15:30") must not be claimed here.
        //
        // NSDataDetector has no reference-date parameter: it resolves against the
        // real current date in the device time zone and hands back a fully
        // resolved instant, which `resolveDueDate` then returns verbatim. That
        // silently bypassed this parser's injected `now`/`calendar` for every
        // time-only capture — so a capture queued from a widget yesterday and
        // drained today resolved to *today* at that time, and the resulting due
        // date was committed without review.
        //
        // The explicit time path below already resolves a bare time against the
        // injected clock and rolls it to tomorrow when it has passed, so the
        // correct fix is to let it own this input rather than to re-derive the
        // detector's answer. Dates carrying a real day component ("Sept 3",
        // "12/25", "March 5 at 4pm") still belong to the detector.
        if isTimeOnly(String(text[range])) { return nil }

        let matchedSubstring = String(text[range]).lowercased()
        // Treat as a precise instant only if the matched text carried a time component.
        let hasTime = matchedSubstring.contains(":")
            || matchedSubstring.contains("am")
            || matchedSubstring.contains("pm")
        return DateMatch(phrase: hasTime ? .instant(date) : .day(date), range: range)
    }

    /// Whether a detector match is nothing but a clock time.
    ///
    /// Decided by reusing `firstTimeMatch` rather than by pattern-matching the
    /// substring again: if the time expression covers the whole match once
    /// surrounding whitespace and a leading "at"/"by"/"@" are accounted for,
    /// there is no day component and the time-only path should own it.
    private static func isTimeOnly(_ matched: String) -> Bool {
        let trimmed = matched.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let time = firstTimeMatch(in: trimmed) else { return false }
        let remainder = trimmed
            .replacingCharacters(in: time.range, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return remainder.isEmpty
    }

    // MARK: - Time matching

    private static func firstTimeMatch(in text: String) -> TimeMatch? {
        // 12-hour with meridiem: "3pm", "3:30 pm", "at 3pm"
        if let m = regexMatch(#"\b(?:at|by|@)?\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#, in: text),
           let rawHour = Int(captured(m.groups, 1, in: text) ?? "") {
            let minute = Int(captured(m.groups, 2, in: text) ?? "") ?? 0
            let meridiem = (captured(m.groups, 3, in: text) ?? "").lowercased()
            var hour = rawHour % 12
            if meridiem == "pm" { hour += 12 }
            if (0...23).contains(hour), (0...59).contains(minute) {
                return TimeMatch(hour: hour, minute: minute, range: m.range)
            }
        }
        // 24-hour explicit: "15:00", "at 9:30"
        if let m = regexMatch(#"\b(?:at|by|@)?\s*(\d{1,2}):(\d{2})\b"#, in: text),
           let hour = Int(captured(m.groups, 1, in: text) ?? ""),
           let minute = Int(captured(m.groups, 2, in: text) ?? ""),
           (0...23).contains(hour), (0...59).contains(minute) {
            return TimeMatch(hour: hour, minute: minute, range: m.range)
        }
        // "noon" / "midday" / "midnight"
        if let m = regexMatch(#"\b(?:noon|midday)\b"#, in: text) {
            return TimeMatch(hour: 12, minute: 0, range: m.range)
        }
        if let m = regexMatch(#"\bmidnight\b"#, in: text) {
            return TimeMatch(hour: 0, minute: 0, range: m.range)
        }
        // Bare "at H" with no meridiem — heuristic: 1–6 → afternoon/evening, 7–11 → morning, 12 → noon.
        if let m = regexMatch(#"\b(?:at|@)\s*(\d{1,2})\b"#, in: text),
           let rawHour = Int(captured(m.groups, 1, in: text) ?? "") {
            let hour: Int
            switch rawHour {
            case 1...6: hour = rawHour + 12
            case 7...11: hour = rawHour
            case 12: hour = 12
            case 0: hour = 0
            case 13...23: hour = rawHour
            default: return nil
            }
            return TimeMatch(hour: hour, minute: 0, range: m.range)
        }
        return nil
    }

    // MARK: - Recurrence

    private struct RecurrenceMatch {
        let pattern: TaskRepeatPattern
        let range: Range<String.Index>
    }

    private static func firstRecurrenceMatch(in text: String) -> RecurrenceMatch? {
        // "every weekday" / "weekdays"
        if let m = regexMatch(#"\b(?:every\s+weekday|weekdays|every\s+week\s?day)\b"#, in: text) {
            return RecurrenceMatch(pattern: .weekdays, range: m.range)
        }
        // "every N weeks" — 2 is biweekly; anything else has no representable
        // pattern here, so it is left unclaimed rather than rounded to weekly.
        if let m = regexMatch(#"\bevery\s+(\d{1,2})\s+weeks?\b"#, in: text),
           let value = Int(captured(m.groups, 1, in: text) ?? ""), value == 2 {
            return RecurrenceMatch(pattern: .biweekly(.allDays), range: m.range)
        }
        // "every monday" / "every mon"
        if let m = regexMatch(
            #"\bevery\s+(monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thu|friday|fri|saturday|sat|sunday|sun)\b"#,
            in: text
        ), let word = captured(m.groups, 1, in: text)?.lowercased(),
           let days = daysOfWeek(for: word) {
            return RecurrenceMatch(pattern: .weekly(days), range: m.range)
        }
        // "daily" / "every day"
        if let m = regexMatch(#"\b(?:daily|every\s+day)\b"#, in: text) {
            return RecurrenceMatch(pattern: .daily, range: m.range)
        }
        // "weekly" / "every week"
        if let m = regexMatch(#"\b(?:weekly|every\s+week)\b"#, in: text) {
            return RecurrenceMatch(pattern: .weekly(.allDays), range: m.range)
        }
        return nil
    }

    private static func daysOfWeek(for word: String) -> TaskRepeatPattern.DaysOfWeek? {
        switch word {
        case "sunday", "sun": return .sunday
        case "monday", "mon": return .monday
        case "tuesday", "tue", "tues": return .tuesday
        case "wednesday", "wed": return .wednesday
        case "thursday", "thu", "thurs": return .thursday
        case "friday", "fri": return .friday
        case "saturday", "sat": return .saturday
        default: return nil
        }
    }

    // MARK: - Duration

    private struct DurationMatch {
        let seconds: TimeInterval
        let range: Range<String.Index>
    }

    /// Estimated effort, always introduced by "for".
    ///
    /// The keyword is required rather than inferred. A bare "45 min" in a
    /// capture is far more often part of the thing being described ("45 min
    /// yoga video") than an estimate, and guessing wrong writes a number into a
    /// field the user never filled in.
    private static func firstDurationMatch(in text: String) -> DurationMatch? {
        // "for 1h30" / "for 1h 30m" — the trailing "m" is optional, because
        // "1h30" is the commonest spelling and requiring it silently dropped the
        // whole match rather than the minutes.
        if let m = regexMatch(#"\bfor\s+(\d{1,2})\s*h(?:ours?|rs?)?\s*(\d{1,2})\s*(?:m(?:in(?:ute)?s?)?)?\b"#, in: text),
           let hours = Int(captured(m.groups, 1, in: text) ?? ""),
           let minutes = Int(captured(m.groups, 2, in: text) ?? ""),
           minutes < 60 {
            return DurationMatch(seconds: TimeInterval(hours * 3600 + minutes * 60), range: m.range)
        }
        // "for 2 hours" / "for 2h"
        if let m = regexMatch(#"\bfor\s+(\d{1,2})(?:\.(\d))?\s*h(?:ours?|rs?)?\b"#, in: text),
           let hours = Int(captured(m.groups, 1, in: text) ?? "") {
            let tenths = Int(captured(m.groups, 2, in: text) ?? "") ?? 0
            return DurationMatch(seconds: TimeInterval(hours * 3600 + tenths * 360), range: m.range)
        }
        // "for 45 minutes" / "for 45m"
        if let m = regexMatch(#"\bfor\s+(\d{1,3})\s*m(?:in(?:ute)?s?)?\b"#, in: text),
           let minutes = Int(captured(m.groups, 1, in: text) ?? ""), minutes > 0 {
            return DurationMatch(seconds: TimeInterval(minutes * 60), range: m.range)
        }
        return nil
    }

    // MARK: - Priority

    private struct PriorityMatch {
        let priority: TaskPriorityConfig.Priority
        let range: Range<String.Index>
    }

    /// `!high` / `!max` / `!low` / `!none`, or `p1`–`p4` with p1 the highest.
    private static func firstPriorityMatch(in text: String) -> PriorityMatch? {
        if let m = regexMatch(#"(?<![\w])!(max|high|urgent|low|none)\b"#, in: text),
           let word = captured(m.groups, 1, in: text)?.lowercased() {
            let priority: TaskPriorityConfig.Priority
            switch word {
            case "max", "urgent": priority = .max
            case "high": priority = .high
            case "low": priority = .low
            default: priority = TaskPriorityConfig.Priority.none
            }
            return PriorityMatch(priority: priority, range: m.range)
        }
        // The Todoist/Linear convention people already type: p1 is the most
        // urgent. The old mapping followed the internal storage order, so
        // "p1" filed a task as Low. p4 (and a legacy p0) mean no priority.
        if let m = regexMatch(#"(?<![\w])p([0-4])\b"#, in: text),
           let raw = Int(captured(m.groups, 1, in: text) ?? "") {
            let priority: TaskPriorityConfig.Priority
            switch raw {
            case 1: priority = .max
            case 2: priority = .high
            case 3: priority = .low
            default: priority = TaskPriorityConfig.Priority.none
            }
            return PriorityMatch(priority: priority, range: m.range)
        }
        return nil
    }

    // MARK: - Regex helpers

    private struct RegexMatch {
        let range: Range<String.Index>
        let groups: [NSRange]
    }

    private static func regexMatch(_ pattern: String, in text: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let range = Range(match.range, in: text) else { return nil }
        let groups = (0..<match.numberOfRanges).map { match.range(at: $0) }
        return RegexMatch(range: range, groups: groups)
    }

    private static func captured(_ groups: [NSRange], _ index: Int, in text: String) -> String? {
        guard index < groups.count, let range = Range(groups[index], in: text) else { return nil }
        return String(text[range])
    }

    // MARK: - Title stripping

    private static func strippedTitle(from text: String, removing ranges: [Range<String.Index>]) -> String {
        var result = text
        // Remove from the back so earlier indices stay valid.
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            result.removeSubrange(range)
        }
        // Collapse whitespace and trim dangling connector words left behind ("at", "on", "by").
        let collapsed = result
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutDanglingConnector = collapsed
            .replacingOccurrences(of: #"\s+(?:at|on|by|for|every)$"#, with: "", options: [.regularExpression, .caseInsensitive])
        // Orphaned sigils. The time grammar accepts a leading "@" but its match
        // range covers only the digits, so "call mom @3pm" used to strip "3pm"
        // and leave a trailing "@" in the title. Same for a "#" or "+" whose
        // word was claimed by another pass.
        let withoutOrphanSigil = withoutDanglingConnector
            .replacingOccurrences(of: #"\s*[@#+]\s*$"#, with: "", options: .regularExpression)
        return withoutOrphanSigil.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
