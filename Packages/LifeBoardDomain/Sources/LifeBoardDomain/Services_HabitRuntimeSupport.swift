import Foundation

// Occurrence-ordering helpers used by the default implementations in
// `Domain/Interfaces/V2RepositoryProtocols.swift`, which is why they cannot stay
// in the use-case layer.
public enum HabitRuntimeSupport {
    public static func normalizedTrackingMode(
        kind: HabitKind,
        trackingMode: HabitTrackingMode
    ) -> HabitTrackingMode {
        kind == .positive ? .dailyCheckIn : trackingMode
    }

    public static func normalizedReminderWindow(
        start: String?,
        end: String?
    ) -> (start: String?, end: String?) {
        let normalizedStart = normalizeHHmm(start)
        let normalizedEnd = normalizeHHmm(end)
        guard let startMinutes = minutesSinceMidnight(normalizedStart),
              let endMinutes = minutesSinceMidnight(normalizedEnd) else {
            return (normalizedStart, normalizedEnd)
        }
        guard endMinutes >= startMinutes else {
            return (normalizedStart, normalizedStart)
        }
        return (normalizedStart, normalizedEnd)
    }

    public static func buildScheduleTemplate(
        templateID: UUID = UUID(),
        habitID: UUID,
        cadence: HabitCadenceDraft,
        windowStart: String?,
        windowEnd: String?,
        anchorAt: Date,
        isActive: Bool
    ) -> ScheduleTemplateDefinition {
        ScheduleTemplateDefinition(
            id: templateID,
            sourceType: .habit,
            sourceID: habitID,
            timezoneID: TimeZone.current.identifier,
            temporalReference: .anchored,
            anchorAt: anchorAt,
            windowStart: windowStart,
            windowEnd: windowEnd,
            isActive: isActive,
            createdAt: anchorAt,
            updatedAt: Date()
        )
    }

    public static func buildScheduleRules(
        templateID: UUID,
        cadence: HabitCadenceDraft,
        createdAt: Date
    ) -> [ScheduleRuleDefinition] {
        switch cadence {
        case .daily(let hour, let minute):
            return [
                ScheduleRuleDefinition(
                    id: UUID(),
                    scheduleTemplateID: templateID,
                    ruleType: "daily",
                    interval: 1,
                    byDayMask: nil,
                    byMonthDay: nil,
                    byHour: hour,
                    byMinute: minute,
                    rawRuleData: nil,
                    createdAt: createdAt
                )
            ]
        case .weekly(let daysOfWeek, let hour, let minute):
            return [
                ScheduleRuleDefinition(
                    id: UUID(),
                    scheduleTemplateID: templateID,
                    ruleType: "weekly",
                    interval: 1,
                    byDayMask: weekdayMask(for: daysOfWeek),
                    byMonthDay: nil,
                    byHour: hour,
                    byMinute: minute,
                    rawRuleData: nil,
                    createdAt: createdAt
                )
            ]
        case .interval(let days, let hour, let minute):
            return [
                ScheduleRuleDefinition(
                    id: UUID(),
                    scheduleTemplateID: templateID,
                    ruleType: "daily",
                    interval: max(1, days),
                    byDayMask: nil,
                    byMonthDay: nil,
                    byHour: hour,
                    byMinute: minute,
                    rawRuleData: nil,
                    createdAt: createdAt
                )
            ]
        }
    }

    public static func weekdayMask(for weekdays: [Int]) -> Int? {
        guard weekdays.isEmpty == false else { return nil }
        return weekdays.reduce(into: 0) { partial, weekday in
            guard (1...7).contains(weekday) else { return }
            partial |= (1 << (weekday - 1))
        }
    }

    public static func weekdays(from mask: Int?) -> [Int] {
        guard let mask else { return [] }
        return (1...7).filter { weekday in
            (mask & (1 << (weekday - 1))) != 0
        }
    }

    public static func cadence(
        from template: ScheduleTemplateDefinition?,
        rules: [ScheduleRuleDefinition]
    ) -> HabitCadenceDraft {
        let primaryRule = rules.sorted {
            ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
        }.first
        let hour = primaryRule?.byHour
        let minute = primaryRule?.byMinute
        let fallbackMinutes = normalizeHHmm(template?.windowStart).flatMap(minutesSinceMidnight(_:))

        switch primaryRule?.ruleType {
        case "weekly":
            let days = weekdays(from: primaryRule?.byDayMask)
            return .weekly(
                daysOfWeek: days.isEmpty ? [2, 3, 4, 5, 6] : days,
                hour: hour,
                minute: minute
            )
        case "daily" where (primaryRule?.interval ?? 1) > 1:
            return .interval(
                days: max(1, primaryRule?.interval ?? 1),
                hour: hour ?? fallbackMinutes.map { $0 / 60 },
                minute: minute ?? fallbackMinutes.map { $0 % 60 }
            )
        default:
            return .daily(
                hour: hour ?? fallbackMinutes.map { $0 / 60 },
                minute: minute ?? fallbackMinutes.map { $0 % 60 }
            )
        }
    }

    public static func normalizeHHmm(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    public static func minutesSinceMidnight(_ value: String?) -> Int? {
        guard let value = normalizeHHmm(value) else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return (hour * 60) + minute
    }

    public static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    public static func occurrenceDate(_ occurrence: OccurrenceDefinition) -> Date {
        occurrence.dueAt ?? occurrence.scheduledAt
    }

    public static func dayMarks(
        from occurrences: [OccurrenceDefinition],
        endingOn date: Date,
        dayCount: Int,
        calendar: Calendar = .current
    ) -> [HabitDayMark] {
        guard dayCount > 0 else { return [] }
        let endDay = calendar.startOfDay(for: date)
        let startDay = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDay) ?? endDay
        let grouped = Dictionary(grouping: occurrences) { occurrence in
            calendar.startOfDay(for: occurrenceDate(occurrence))
        }

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let state: HabitDayState
            if day > endDay {
                state = .future
            } else if let latest = grouped[day]?.sorted(by: { occurrenceDate($0) < occurrenceDate($1) }).last {
                state = dayState(for: latest, day: day, referenceDay: endDay, calendar: calendar)
            } else {
                state = .none
            }
            return HabitDayMark(date: day, state: state)
        }
    }

    public static func dayState(
        for occurrence: OccurrenceDefinition,
        day _: Date,
        referenceDay _: Date,
        calendar _: Calendar = .current
    ) -> HabitDayState {
        switch occurrence.state {
        case .completed:
            return .success
        case .failed, .missed:
            return .failure
        case .skipped:
            return .skipped
        case .pending:
            // Pending days should remain visually neutral until the user explicitly resolves them.
            return .none
        }
    }

    public static func masks(from marks: [HabitDayMark]) -> (UInt16, UInt16) {
        var success: UInt16 = 0
        var failure: UInt16 = 0
        for (index, mark) in marks.prefix(14).enumerated() {
            let bit = UInt16(1 << index)
            switch mark.state {
            case .success:
                success |= bit
            case .failure:
                failure |= bit
            case .skipped, .none, .future:
                break
            }
        }
        return (success, failure)
    }

    public static func riskState(
        for marks: [HabitDayMark],
        dueAt: Date?,
        occurrenceState: OccurrenceState,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> HabitRiskState {
        if occurrenceState == .failed || occurrenceState == .missed {
            return .broken
        }
        if occurrenceState == .pending,
           let dueAt,
           dueAt < calendar.startOfDay(for: referenceDate) {
            return .atRisk
        }
        let recentFailures = marks.suffix(3).filter { $0.state == .failure }.count
        if recentFailures > 0 {
            return .atRisk
        }
        return .stable
    }

    public static func streaks(
        from occurrences: [OccurrenceDefinition],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> (current: Int, best: Int) {
        let latestByDay = Dictionary(grouping: occurrences.filter {
            occurrenceDate($0) <= referenceDate
        }) { occurrence in
            calendar.startOfDay(for: occurrenceDate(occurrence))
        }
        .compactMapValues { entries in
            entries.sorted(by: { occurrenceDate($0) < occurrenceDate($1) }).last
        }
        let ordered = latestByDay.values.sorted(by: { occurrenceDate($0) < occurrenceDate($1) })

        var best = 0
        var run = 0
        for occurrence in ordered {
            switch occurrence.state {
            case .completed:
                run += 1
                best = max(best, run)
            case .skipped:
                continue
            case .pending:
                if calendar.isDate(occurrenceDate(occurrence), inSameDayAs: referenceDate) {
                    continue
                }
                run = 0
            case .failed, .missed:
                run = 0
            }
        }

        // `break` inside a `switch` leaves the switch, not the loop.
        //
        // The `.failed`/`.missed`/past-`.pending` case therefore did nothing and
        // the walk kept counting completions *past* a broken day — a habit
        // failed today still reported a live streak, and the "failed" state had
        // no effect on the number it was supposed to break. The label makes the
        // intent explicit: stop at the first day that is not a completion.
        var current = 0
        walk: for occurrence in ordered.reversed() {
            if occurrence.state == .pending,
               calendar.isDate(occurrenceDate(occurrence), inSameDayAs: referenceDate) {
                // Today is still open; it neither extends nor breaks the streak.
                continue
            }
            switch occurrence.state {
            case .completed:
                current += 1
            case .skipped:
                // Deliberately set aside — preserves the streak without extending it.
                continue
            case .pending, .failed, .missed:
                break walk
            }
        }
        return (current, best)
    }

}
