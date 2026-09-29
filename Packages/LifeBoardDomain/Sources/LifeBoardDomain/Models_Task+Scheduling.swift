import Foundation

public struct TaskScheduleNormalizationResult: Equatable {
    public let dueDate: Date?
    public let scheduledStartAt: Date?
    public let scheduledEndAt: Date?
    public let isAllDay: Bool
    public let explicitAllDayIntent: Bool?
    public let clearScheduledStartAt: Bool
    public let clearScheduledEndAt: Bool

    // Memberwise init written out: a public struct's implicit one is
    // internal, and this type is constructed from outside the package.
    // Optional `var`s keep the `= nil` default the implicit init gives them.
    public init(dueDate: Date?, scheduledStartAt: Date?, scheduledEndAt: Date?, isAllDay: Bool, explicitAllDayIntent: Bool?, clearScheduledStartAt: Bool, clearScheduledEndAt: Bool) {
        self.dueDate = dueDate
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.isAllDay = isAllDay
        self.explicitAllDayIntent = explicitAllDayIntent
        self.clearScheduledStartAt = clearScheduledStartAt
        self.clearScheduledEndAt = clearScheduledEndAt
    }
}

public enum TaskScheduleNormalizer {
    private static let defaultDuration: TimeInterval = 30 * 60

    public static func normalize(
        deadlineDate: Date?,
        existingScheduledStartAt: Date?,
        existingScheduledEndAt: Date?,
        estimatedDuration: TimeInterval?,
        preserveExistingDuration: Bool,
        allDayIntent: Bool? = nil,
        calendar: Calendar = .current
    ) -> TaskScheduleNormalizationResult {
        guard let deadlineDate else {
            return TaskScheduleNormalizationResult(
                dueDate: nil,
                scheduledStartAt: nil,
                scheduledEndAt: nil,
                isAllDay: false,
                explicitAllDayIntent: allDayIntent,
                clearScheduledStartAt: true,
                clearScheduledEndAt: true
            )
        }

        if allDayIntent == true {
            return TaskScheduleNormalizationResult(
                dueDate: calendar.startOfDay(for: deadlineDate),
                scheduledStartAt: nil,
                scheduledEndAt: nil,
                isAllDay: true,
                explicitAllDayIntent: true,
                clearScheduledStartAt: true,
                clearScheduledEndAt: true
            )
        }

        if allDayIntent != false, isDateOnly(deadlineDate, calendar: calendar) {
            return TaskScheduleNormalizationResult(
                dueDate: calendar.startOfDay(for: deadlineDate),
                scheduledStartAt: nil,
                scheduledEndAt: nil,
                isAllDay: true,
                explicitAllDayIntent: allDayIntent,
                clearScheduledStartAt: true,
                clearScheduledEndAt: true
            )
        }

        let resolvedDuration: TimeInterval
        if preserveExistingDuration,
           let existingScheduledStartAt,
           let existingScheduledEndAt,
           existingScheduledEndAt > existingScheduledStartAt {
            resolvedDuration = existingScheduledEndAt.timeIntervalSince(existingScheduledStartAt)
        } else if let estimatedDuration, estimatedDuration > 0 {
            resolvedDuration = estimatedDuration
        } else {
            resolvedDuration = defaultDuration
        }

        return TaskScheduleNormalizationResult(
            dueDate: deadlineDate,
            scheduledStartAt: deadlineDate,
            scheduledEndAt: deadlineDate.addingTimeInterval(resolvedDuration),
            isAllDay: false,
            explicitAllDayIntent: allDayIntent,
            clearScheduledStartAt: false,
            clearScheduledEndAt: false
        )
    }

    public static func isDateOnly(_ date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) == 0
            && (components.minute ?? 0) == 0
            && (components.second ?? 0) == 0
    }

    public static func hasAllDaySemantics(_ task: TaskDefinition, calendar: Calendar = .current) -> Bool {
        task.isAllDay || task.dueDate.map { isDateOnly($0, calendar: calendar) } == true
    }

    public static func timelinePlacementDate(
        for task: TaskDefinition,
        calendar: Calendar = .current
    ) -> Date? {
        guard hasAllDaySemantics(task, calendar: calendar) == false else { return nil }
        return task.scheduledStartAt ?? task.dueDate
    }

    public static func timelineAllDayDate(
        for task: TaskDefinition,
        calendar: Calendar = .current
    ) -> Date? {
        guard hasAllDaySemantics(task, calendar: calendar) else { return nil }
        return task.dueDate ?? task.scheduledStartAt
    }
}

public enum TaskRescueScheduleShifter {
    private static let defaultDuration: TimeInterval = 30 * 60

    public static func shift(
        task: TaskDefinition,
        to targetDay: Date,
        calendar: Calendar = .current
    ) -> TaskScheduleNormalizationResult {
        let targetStartOfDay = calendar.startOfDay(for: targetDay)
        let hasDateOnlyDueDate = task.dueDate.map { TaskScheduleNormalizer.isDateOnly($0, calendar: calendar) } ?? false
        let hasTimedDueDate = task.dueDate.map { TaskScheduleNormalizer.isDateOnly($0, calendar: calendar) == false } ?? false

        if task.isAllDay || hasDateOnlyDueDate {
            return TaskScheduleNormalizationResult(
                dueDate: targetStartOfDay,
                scheduledStartAt: nil,
                scheduledEndAt: nil,
                isAllDay: true,
                explicitAllDayIntent: true,
                clearScheduledStartAt: true,
                clearScheduledEndAt: true
            )
        }

        guard task.scheduledStartAt != nil || hasTimedDueDate else {
            return TaskScheduleNormalizationResult(
                dueDate: targetStartOfDay,
                scheduledStartAt: nil,
                scheduledEndAt: nil,
                isAllDay: true,
                explicitAllDayIntent: true,
                clearScheduledStartAt: true,
                clearScheduledEndAt: true
            )
        }

        if let originalStart = task.scheduledStartAt {
            let shiftedStart = date(on: targetStartOfDay, preservingTimeFrom: originalStart, calendar: calendar)
            let duration = resolvedDuration(for: task)
            let shiftedDueDate: Date
            if let originalDue = task.dueDate,
               TaskScheduleNormalizer.isDateOnly(originalDue, calendar: calendar) == false {
                shiftedDueDate = date(on: targetStartOfDay, preservingTimeFrom: originalDue, calendar: calendar)
            } else {
                shiftedDueDate = shiftedStart
            }

            return TaskScheduleNormalizationResult(
                dueDate: shiftedDueDate,
                scheduledStartAt: shiftedStart,
                scheduledEndAt: shiftedStart.addingTimeInterval(duration),
                isAllDay: false,
                explicitAllDayIntent: false,
                clearScheduledStartAt: false,
                clearScheduledEndAt: false
            )
        }

        guard let originalDue = task.dueDate else {
            return TaskScheduleNormalizationResult(
                dueDate: targetStartOfDay,
                scheduledStartAt: nil,
                scheduledEndAt: nil,
                isAllDay: true,
                explicitAllDayIntent: true,
                clearScheduledStartAt: true,
                clearScheduledEndAt: true
            )
        }

        let shiftedDue = date(on: targetStartOfDay, preservingTimeFrom: originalDue, calendar: calendar)
        return TaskScheduleNormalizer.normalize(
            deadlineDate: shiftedDue,
            existingScheduledStartAt: task.scheduledStartAt,
            existingScheduledEndAt: task.scheduledEndAt,
            estimatedDuration: task.estimatedDuration,
            preserveExistingDuration: true,
            allDayIntent: false,
            calendar: calendar
        )
    }

    private static func resolvedDuration(for task: TaskDefinition) -> TimeInterval {
        if let start = task.scheduledStartAt,
           let end = task.scheduledEndAt,
           end > start {
            return end.timeIntervalSince(start)
        }
        if let estimatedDuration = task.estimatedDuration, estimatedDuration > 0 {
            return estimatedDuration
        }
        return defaultDuration
    }

    private static func date(on targetStartOfDay: Date, preservingTimeFrom source: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute, .second], from: source)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: targetStartOfDay
        ) ?? targetStartOfDay
    }
}
