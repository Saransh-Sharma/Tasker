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

/// Result of parsing a raw capture string into a clean title and an optional due date.
public struct ParsedCapture: Equatable, Sendable {
    /// The title with any recognized date/time tokens removed and whitespace collapsed.
    public let cleanTitle: String
    /// The resolved due date, if a date or time phrase was recognized.
    public let dueDate: Date?
    /// True when only a calendar day (no time of day) was recognized.
    public let isAllDay: Bool
    /// The substring(s) that were recognized and stripped, for display/undo. Nil when nothing matched.
    public let matchedText: String?

    public init(cleanTitle: String, dueDate: Date?, isAllDay: Bool, matchedText: String?) {
        self.cleanTitle = cleanTitle
        self.dueDate = dueDate
        self.isAllDay = isAllDay
        self.matchedText = matchedText
    }
}

public enum TaskCaptureParser {

    /// Parses a raw capture string. `now`/`calendar` are injectable for deterministic tests.
    public static func parse(
        _ raw: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ParsedCapture {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return ParsedCapture(cleanTitle: trimmed, dueDate: nil, isAllDay: false, matchedText: nil)
        }

        var removalRanges: [Range<String.Index>] = []
        var matchedPieces: [(Range<String.Index>, String)] = []

        // 1) Date phrase (relative words, weekdays, "in N units", or absolute via NSDataDetector).
        let dateMatch = firstDateMatch(in: trimmed, now: now, calendar: calendar)
        if let dateMatch {
            removalRanges.append(dateMatch.range)
            matchedPieces.append((dateMatch.range, String(trimmed[dateMatch.range])))
        }

        // 2) Time phrase — only if it doesn't overlap the date token.
        var timeMatch = firstTimeMatch(in: trimmed)
        if let resolved = timeMatch, removalRanges.contains(where: { $0.overlaps(resolved.range) }) {
            timeMatch = nil
        }
        if let timeMatch {
            removalRanges.append(timeMatch.range)
            matchedPieces.append((timeMatch.range, String(trimmed[timeMatch.range])))
        }

        // Resolve the final due date from the date/time parts.
        let resolution = resolveDueDate(
            date: dateMatch?.phrase,
            time: timeMatch.map { ($0.hour, $0.minute) },
            now: now,
            calendar: calendar
        )

        guard let dueDate = resolution.dueDate else {
            return ParsedCapture(cleanTitle: trimmed, dueDate: nil, isAllDay: false, matchedText: nil)
        }

        let cleanTitle = strippedTitle(from: trimmed, removing: removalRanges)
        // If stripping consumed the entire title, the "date" was really the whole input — keep the original title.
        guard cleanTitle.isEmpty == false else {
            return ParsedCapture(cleanTitle: trimmed, dueDate: nil, isAllDay: false, matchedText: nil)
        }

        let matchedText = matchedPieces
            .sorted { $0.0.lowerBound < $1.0.lowerBound }
            .map(\.1)
            .joined(separator: " ")

        return ParsedCapture(
            cleanTitle: cleanTitle,
            dueDate: dueDate,
            isAllDay: resolution.isAllDay,
            matchedText: matchedText.isEmpty ? nil : matchedText
        )
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
        let matchedSubstring = String(text[range]).lowercased()
        // Treat as a precise instant only if the matched text carried a time component.
        let hasTime = matchedSubstring.contains(":")
            || matchedSubstring.contains("am")
            || matchedSubstring.contains("pm")
        return DateMatch(phrase: hasTime ? .instant(date) : .day(date), range: range)
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
            .replacingOccurrences(of: #"\s+(?:at|on|by)$"#, with: "", options: [.regularExpression, .caseInsensitive])
        return withoutDanglingConnector.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
