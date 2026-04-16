import Foundation

public struct FilterCalendarEventsUseCase {
    public init() {}

    public func execute(
        events: [TaskerCalendarEventSnapshot],
        selectedCalendarIDs: Set<String>,
        includeDeclined: Bool,
        includeCanceled: Bool,
        includeAllDayInAgenda: Bool
    ) -> [TaskerCalendarEventSnapshot] {
        events
            .filter { event in
                selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains(event.calendarID)
            }
            .filter { event in
                includeDeclined || !event.isDeclined
            }
            .filter { event in
                includeCanceled || !event.isCanceled
            }
            .filter { event in
                includeAllDayInAgenda || !event.isAllDay
            }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
    }
}

public struct BuildCalendarBusyBlocksUseCase {
    private let mergeGapThreshold: TimeInterval

    public init(mergeGapThreshold: TimeInterval = 5 * 60) {
        self.mergeGapThreshold = max(0, mergeGapThreshold)
    }

    public func execute(
        events: [TaskerCalendarEventSnapshot],
        includeAllDayEvents: Bool,
        referenceStart: Date,
        referenceEnd: Date
    ) -> [TaskerCalendarBusyBlock] {
        let intervals = events
            .filter { event in
                event.isBusy && (includeAllDayEvents || !event.isAllDay)
            }
            .map { event -> TaskerCalendarBusyBlock in
                let clampedStart = max(referenceStart, event.startDate)
                let clampedEnd = min(referenceEnd, event.endDate)
                return TaskerCalendarBusyBlock(startDate: clampedStart, endDate: clampedEnd)
            }
            .filter { $0.duration > 0 }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }

        guard var current = intervals.first else { return [] }
        var merged: [TaskerCalendarBusyBlock] = []

        for block in intervals.dropFirst() {
            if block.startDate <= current.endDate.addingTimeInterval(mergeGapThreshold) {
                current = TaskerCalendarBusyBlock(
                    startDate: current.startDate,
                    endDate: max(current.endDate, block.endDate)
                )
            } else {
                merged.append(current)
                current = block
            }
        }

        merged.append(current)
        return merged
    }
}

public struct ResolveNextMeetingUseCase {
    public init() {}

    public func execute(
        events: [TaskerCalendarEventSnapshot],
        now: Date
    ) -> TaskerNextMeetingSummary? {
        let candidate = events
            .filter { $0.endDate > now }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
            .first

        guard let candidate else { return nil }

        let isInProgress = candidate.startDate <= now && candidate.endDate > now
        let minutesUntilStart: Int
        if isInProgress {
            minutesUntilStart = 0
        } else {
            minutesUntilStart = max(0, Int(candidate.startDate.timeIntervalSince(now) / 60.0))
        }

        return TaskerNextMeetingSummary(
            event: candidate,
            isInProgress: isInProgress,
            minutesUntilStart: minutesUntilStart
        )
    }
}

public struct ComputeTaskFitHintUseCase {
    private let bufferMinutes: Int
    private let calendar: Calendar

    public init(bufferMinutes: Int = 15, calendar: Calendar = .current) {
        self.bufferMinutes = max(0, bufferMinutes)
        self.calendar = calendar
    }

    public func execute(
        now: Date,
        taskDueDate: Date?,
        estimatedDuration: TimeInterval?,
        busyBlocks: [TaskerCalendarBusyBlock]
    ) -> TaskerTaskFitHintResult {
        guard let dueDate = taskDueDate, let estimatedDuration else {
            return .unknown
        }

        let duration = max(0, estimatedDuration)
        guard duration > 0 else {
            return TaskerTaskFitHintResult(
                classification: .unknown,
                message: "Set an estimated duration to evaluate fit."
            )
        }

        let start = max(now, calendar.startOfDay(for: dueDate))
        let end = dueDate
        guard end > start else {
            return TaskerTaskFitHintResult(
                classification: .unknown,
                message: "Due time has already passed."
            )
        }

        let freeWindow = largestFreeWindow(
            busyBlocks: busyBlocks,
            rangeStart: start,
            rangeEnd: end
        )

        guard let freeWindow else {
            return TaskerTaskFitHintResult(
                classification: .conflict,
                message: "No free window before due time.",
                freeWindowStart: nil,
                freeWindowEnd: nil
            )
        }

        let freeDuration = freeWindow.1.timeIntervalSince(freeWindow.0)
        let durationWithBuffer = duration + TimeInterval(bufferMinutes * 60)

        if freeDuration >= durationWithBuffer {
            return TaskerTaskFitHintResult(
                classification: .fit,
                message: "Good fit before your next calendar block.",
                freeWindowStart: freeWindow.0,
                freeWindowEnd: freeWindow.1
            )
        }

        if freeDuration >= duration {
            return TaskerTaskFitHintResult(
                classification: .tight,
                message: "This fits, but your buffer is tight.",
                freeWindowStart: freeWindow.0,
                freeWindowEnd: freeWindow.1
            )
        }

        return TaskerTaskFitHintResult(
            classification: .conflict,
            message: "Likely conflict with calendar commitments.",
            freeWindowStart: freeWindow.0,
            freeWindowEnd: freeWindow.1
        )
    }

    private func largestFreeWindow(
        busyBlocks: [TaskerCalendarBusyBlock],
        rangeStart: Date,
        rangeEnd: Date
    ) -> (Date, Date)? {
        let relevant = busyBlocks
            .filter { $0.endDate > rangeStart && $0.startDate < rangeEnd }
            .sorted { $0.startDate < $1.startDate }

        var cursor = rangeStart
        var best: (Date, Date)?

        for block in relevant {
            let blockStart = max(rangeStart, block.startDate)
            if blockStart > cursor {
                let candidate = (cursor, blockStart)
                if best == nil || candidate.1.timeIntervalSince(candidate.0) > best!.1.timeIntervalSince(best!.0) {
                    best = candidate
                }
            }
            cursor = max(cursor, min(rangeEnd, block.endDate))
            if cursor >= rangeEnd {
                break
            }
        }

        if cursor < rangeEnd {
            let candidate = (cursor, rangeEnd)
            if best == nil || candidate.1.timeIntervalSince(candidate.0) > best!.1.timeIntervalSince(best!.0) {
                best = candidate
            }
        }

        return best
    }
}

public struct BuildCalendarWeekAgendaUseCase {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func execute(
        events: [TaskerCalendarEventSnapshot],
        weekStart: Date
    ) -> [TaskerCalendarDayAgenda] {
        var days: [TaskerCalendarDayAgenda] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let start = calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let dayEvents = events.filter { event in
                event.endDate > start && event.startDate < end
            }
            days.append(TaskerCalendarDayAgenda(date: start, events: dayEvents))
        }
        return days
    }
}
