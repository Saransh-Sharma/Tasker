import Foundation

public enum XPDisplayEstimate: Equatable {
    case exact(Int)
    case range(min: Int, max: Int)
    case capped(Int)

    public var shortLabel: String {
        switch self {
        case .exact(let value):
            return "Est. +\(value) XP"
        case .range(let min, let max):
            return "Est. +\(min)-\(max) XP"
        case .capped(let value):
            return "Est. +\(value) XP (cap)"
        }
    }

    public var compactLabel: String {
        switch self {
        case .exact(let value):
            return "~+\(value)"
        case .range(let min, let max):
            return "~+\(min)-\(max)"
        case .capped(let value):
            return "~+\(value) cap"
        }
    }
}

public struct XPCompletionPreview: Equatable {
    public let awardedXP: Int
    public let isCapped: Bool

    public init(awardedXP: Int, isCapped: Bool) {
        self.awardedXP = awardedXP
        self.isCapped = isCapped
    }

    public var shortLabel: String {
        isCapped ? "+\(awardedXP) XP (cap)" : "+\(awardedXP) XP"
    }

    public var compactLabel: String {
        isCapped ? "+\(awardedXP) cap" : "+\(awardedXP)"
    }
}

public struct XPCalculationEngine {

    public static let dailyCap: Int = 250
    public static let focusMinimumSeconds: Int = 300 // 5 minutes
    public static let focusXPPerMinute: Int = 1
    private static let earlyLevelThresholds: [Int64] = [0, 40, 100, 180, 280, 400, 550, 730, 940, 1_180]

    // MARK: - Base XP

    public static func baseXP(for category: XPActionCategory) -> Int {
        switch category {
        case .complete: return 10
        case .start: return 3
        case .decompose: return 2
        case .recoverReschedule: return 2
        case .reflection: return 10
        case .reflectionCapture: return 4
        case .focus: return 0 // calculated from duration
        case .weeklyPlan: return 8
        case .weeklyReview: return 10
        case .weeklyCarryCleanup: return 4
        case .habitPositiveComplete: return 8
        case .habitNegativeSuccess: return 8
        case .habitNegativeLapse: return 0
        case .habitPositiveCompleteUndo: return -8
        case .habitNegativeSuccessUndo: return -8
        case .habitRecovery: return 6
        case .habitStreakMilestone: return 25
        }
    }

    public static func onTimeBonusXP() -> Int { 5 }

    // MARK: - Quality Weight

    public static func qualityWeight(
        priority: Int,
        estimatedDuration: TimeInterval?,
        isFocusSessionActive: Bool,
        isPinnedInFocusStrip: Bool
    ) -> Double {
        var weight = 1.0
        weight += priorityBonus(priority: priority)
        weight += effortBonus(estimatedDuration: estimatedDuration)
        weight += focusBonus(isFocusSessionActive: isFocusSessionActive, isPinnedInFocusStrip: isPinnedInFocusStrip)
        return weight
    }

    public static func priorityBonus(priority: Int) -> Double {
        switch priority {
        case 0: return 0.10  // none
        case 1: return 0.20  // low
        case 2: return 0.40  // high
        case 3: return 0.60  // max
        default: return 0.10
        }
    }

    public static func effortBonus(estimatedDuration: TimeInterval?) -> Double {
        guard let duration = estimatedDuration else { return 0.0 }
        let minutes = duration / 60.0
        switch minutes {
        case ..<30: return 0.00
        case 30..<60: return 0.10
        case 60..<120: return 0.25
        default: return 0.40
        }
    }

    public static func focusBonus(isFocusSessionActive: Bool, isPinnedInFocusStrip: Bool) -> Double {
        if isFocusSessionActive { return 0.20 }
        if isPinnedInFocusStrip { return 0.10 }
        return 0.0
    }

    // MARK: - Final XP Calculation

    public static func calculateFinalXP(
        base: Int,
        bonus: Int,
        qualityWeight: Double,
        dailyEarnedSoFar: Int,
        cap: Int = dailyCap
    ) -> Int {
        let raw = Int(round(Double(base + bonus) * qualityWeight))
        let remaining = max(0, cap - dailyEarnedSoFar)
        return min(raw, remaining)
    }

    public static func focusSessionXP(durationSeconds: Int) -> Int {
        guard durationSeconds >= focusMinimumSeconds else { return 0 }
        let minutes = durationSeconds / 60
        return minutes * focusXPPerMinute
    }

    public static func completionXPIfCompletedNow(
        priorityRaw: Int32,
        estimatedDuration: TimeInterval?,
        dueDate: Date?,
        completedAt: Date = Date(),
        dailyEarnedSoFar: Int,
        cap: Int = dailyCap,
        isGamificationV2Enabled: Bool,
        isFocusSessionActive: Bool = false,
        isPinnedInFocusStrip: Bool = false
    ) -> XPCompletionPreview {
        // Legacy path awards a fixed +10 without V2 quality weighting or cap semantics.
        guard isGamificationV2Enabled else {
            return XPCompletionPreview(awardedXP: baseXP(for: .complete), isCapped: false)
        }

        let priority = max(0, Int(priorityRaw) - 1)
        let safeDailyEarned = max(0, dailyEarnedSoFar)
        let quality = qualityWeight(
            priority: priority,
            estimatedDuration: estimatedDuration,
            isFocusSessionActive: isFocusSessionActive,
            isPinnedInFocusStrip: isPinnedInFocusStrip
        )
        let bonus = isOnTimeCompletion(dueDate: dueDate, completedAt: completedAt) ? onTimeBonusXP() : 0
        let raw = Int(round(Double(baseXP(for: .complete) + bonus) * quality))
        let remaining = max(0, cap - safeDailyEarned)
        let awardedXP = min(raw, remaining)
        return XPCompletionPreview(awardedXP: awardedXP, isCapped: awardedXP < raw)
    }

    @available(*, deprecated, message: "Use completionXPIfCompletedNow(...) for precise XP rewards.")
    public static func completionEstimate(
        priorityRaw: Int32,
        estimatedDuration: TimeInterval?,
        isFocusSessionActive: Bool = false,
        isPinnedInFocusStrip: Bool = false,
        dailyEarnedSoFar: Int? = nil,
        cap: Int = dailyCap
    ) -> XPDisplayEstimate {
        let priority = max(0, Int(priorityRaw) - 1)
        let quality = qualityWeight(
            priority: priority,
            estimatedDuration: estimatedDuration,
            isFocusSessionActive: isFocusSessionActive,
            isPinnedInFocusStrip: isPinnedInFocusStrip
        )

        let minRaw = Int(round(Double(baseXP(for: .complete)) * quality))
        let maxRaw = Int(round(Double(baseXP(for: .complete) + onTimeBonusXP()) * quality))

        let minXP: Int
        let maxXP: Int
        if let dailyEarnedSoFar {
            let remaining = max(0, cap - dailyEarnedSoFar)
            minXP = min(minRaw, remaining)
            maxXP = min(maxRaw, remaining)
        } else {
            minXP = minRaw
            maxXP = maxRaw
        }

        if minXP == maxXP {
            if maxXP < maxRaw {
                return .capped(maxXP)
            }
            return .exact(maxXP)
        }
        return .range(min: minXP, max: maxXP)
    }

    public static func estimateReasonHints(
        estimatedDuration: TimeInterval?,
        isFocusSessionActive: Bool,
        isPinnedInFocusStrip: Bool
    ) -> String {
        _ = estimatedDuration
        _ = isFocusSessionActive
        _ = isPinnedInFocusStrip
        return "priority · on-time · focus · effort · cap"
    }

    // MARK: - Level Curve

    public static func xpForLevel(_ level: Int) -> Int64 {
        guard level > 1 else { return 0 }
        if level <= earlyLevelThresholds.count {
            return earlyLevelThresholds[level - 1]
        }
        let anchor = earlyLevelThresholds.last ?? 0
        let overflowLevels = Double(level - earlyLevelThresholds.count)
        let tail = Int64(round(240.0 * pow(overflowLevels + 1.0, 1.35)))
        return anchor + tail
    }

    public static func levelForXP(_ xp: Int64) -> (level: Int, currentThreshold: Int64, nextThreshold: Int64) {
        var level = 1
        while xpForLevel(level + 1) <= xp {
            level += 1
        }
        return (level, xpForLevel(level), xpForLevel(level + 1))
    }

    // MARK: - On-Time Check

    public static func isOnTimeCompletion(dueDate: Date?, completedAt: Date) -> Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.startOfDay(for: completedAt) <= Calendar.current.startOfDay(for: dueDate)
    }

    // MARK: - Period Key

    public static func periodKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    public static func weekCalendar(
        startingOn weekStartsOn: Weekday,
        using calendar: Calendar = .current
    ) -> Calendar {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = weekStartsOn.number
        weekCalendar.minimumDaysInFirstWeek = 4
        return weekCalendar
    }

    public static func startOfWeek(
        for date: Date,
        startingOn weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> Date {
        let weekCalendar = weekCalendar(startingOn: weekStartsOn, using: calendar)
        let startOfDay = weekCalendar.startOfDay(for: date)
        let weekday = weekCalendar.component(.weekday, from: startOfDay)
        let daysFromWeekStart = (weekday - weekCalendar.firstWeekday + 7) % 7
        return weekCalendar.date(byAdding: .day, value: -daysFromWeekStart, to: startOfDay) ?? startOfDay
    }

    public static func endOfWeek(
        for weekStart: Date,
        startingOn weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> Date {
        let weekCalendar = weekCalendar(startingOn: weekStartsOn, using: calendar)
        return weekCalendar.date(byAdding: .day, value: 6, to: startOfWeek(for: weekStart, startingOn: weekStartsOn, calendar: calendar))
            ?? startOfWeek(for: weekStart, startingOn: weekStartsOn, calendar: calendar)
    }

    public static func upcomingWeekStart(
        after date: Date,
        startingOn weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> Date {
        let weekCalendar = weekCalendar(startingOn: weekStartsOn, using: calendar)
        let currentWeekStart = startOfWeek(for: date, startingOn: weekStartsOn, calendar: calendar)
        return weekCalendar.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
    }

    public static func mondayCalendar(using calendar: Calendar = .current) -> Calendar {
        weekCalendar(startingOn: .monday, using: calendar)
    }

    public static func mondayStartOfWeek(for date: Date, calendar: Calendar = .current) -> Date {
        startOfWeek(for: date, startingOn: .monday, calendar: calendar)
    }

    // MARK: - Idempotency Keys

    public static func idempotencyKey(
        category: XPActionCategory,
        taskID: UUID? = nil,
        habitID: UUID? = nil,
        parentTaskID: UUID? = nil,
        childTaskID: UUID? = nil,
        sessionID: UUID? = nil,
        fromDay: String? = nil,
        toDay: String? = nil,
        periodKey: String? = nil
    ) -> String {
        switch category {
        case .complete:
            guard let taskID = taskID else { return "complete:unknown" }
            return "complete:\(taskID.uuidString)"
        case .start:
            guard let taskID = taskID else { return "start:unknown" }
            return "start:\(taskID.uuidString)"
        case .decompose:
            guard let parentID = parentTaskID, let childID = childTaskID else { return "decompose:unknown" }
            return "decompose:\(parentID.uuidString):\(childID.uuidString)"
        case .recoverReschedule:
            guard let taskID = taskID else { return "recover_reschedule:unknown" }
            return "recover_reschedule:\(taskID.uuidString):\(fromDay ?? ""):\(toDay ?? "")"
        case .reflection:
            return "reflection:\(periodKey ?? self.periodKey())"
        case .reflectionCapture:
            let identifier = taskID ?? habitID
            if let identifier {
                return "reflection_capture:\(identifier.uuidString):\(periodKey ?? self.periodKey())"
            }
            return "reflection_capture:\(periodKey ?? self.periodKey())"
        case .focus:
            guard let sessionID = sessionID else { return "focus:unknown" }
            return "focus:\(sessionID.uuidString)"
        case .weeklyPlan:
            return "weekly_plan:\(fromDay ?? periodKey ?? self.periodKey())"
        case .weeklyReview:
            return "weekly_review:\(fromDay ?? periodKey ?? self.periodKey())"
        case .weeklyCarryCleanup:
            return "weekly_carry_cleanup:\(fromDay ?? periodKey ?? self.periodKey())"
        case .habitPositiveComplete:
            let identifier = habitID ?? taskID
            guard let identifier else { return "habit_positive_complete:unknown" }
            return "habit_positive_complete:\(identifier.uuidString):\(periodKey ?? self.periodKey())"
        case .habitNegativeSuccess:
            let identifier = habitID ?? taskID
            guard let identifier else { return "habit_negative_success:unknown" }
            return "habit_negative_success:\(identifier.uuidString):\(periodKey ?? self.periodKey())"
        case .habitNegativeLapse:
            let identifier = habitID ?? taskID
            guard let identifier else { return "habit_negative_lapse:unknown" }
            return "habit_negative_lapse:\(identifier.uuidString):\(periodKey ?? self.periodKey())"
        case .habitPositiveCompleteUndo:
            let identifier = habitID ?? taskID
            guard let identifier else { return "habit_positive_complete_undo:unknown" }
            return "habit_positive_complete_undo:\(identifier.uuidString):\(periodKey ?? self.periodKey())"
        case .habitNegativeSuccessUndo:
            let identifier = habitID ?? taskID
            guard let identifier else { return "habit_negative_success_undo:unknown" }
            return "habit_negative_success_undo:\(identifier.uuidString):\(periodKey ?? self.periodKey())"
        case .habitRecovery:
            let identifier = habitID ?? taskID
            guard let identifier else { return "habit_recovery:unknown" }
            return "habit_recovery:\(identifier.uuidString):\(periodKey ?? self.periodKey())"
        case .habitStreakMilestone:
            let identifier = habitID ?? taskID
            guard let identifier else { return "habit_streak_milestone:unknown" }
            return "habit_streak_milestone:\(identifier.uuidString):\(periodKey ?? self.periodKey())"
        }
    }

    public static func isHabitCategory(_ category: XPActionCategory) -> Bool {
        switch category {
        case .habitPositiveComplete,
             .habitNegativeSuccess,
             .habitNegativeLapse,
             .habitPositiveCompleteUndo,
             .habitNegativeSuccessUndo,
             .habitRecovery,
             .habitStreakMilestone:
            return true
        case .complete,
             .start,
             .decompose,
             .recoverReschedule,
             .reflection,
             .reflectionCapture,
             .focus:
            return false
        case .weeklyPlan,
             .weeklyReview,
             .weeklyCarryCleanup:
            return false
        }
    }

    // MARK: - Milestones

    public struct Milestone {
        public let xpThreshold: Int64
        public let name: String
        public let sfSymbol: String
    }

    public static let milestones: [Milestone] = [
        Milestone(xpThreshold: 1_000, name: "Spark", sfSymbol: "sparkles"),
        Milestone(xpThreshold: 5_000, name: "Flywheel", sfSymbol: "gearshape.2.fill"),
        Milestone(xpThreshold: 10_000, name: "Flow State", sfSymbol: "wind"),
        Milestone(xpThreshold: 25_000, name: "Systems Builder", sfSymbol: "building.2.fill"),
        Milestone(xpThreshold: 50_000, name: "Unshakeable", sfSymbol: "mountain.2.fill"),
    ]

    public static func nextMilestone(for xp: Int64) -> Milestone? {
        milestones.first { $0.xpThreshold > xp }
    }

    public static func milestoneCrossed(previousXP: Int64, newXP: Int64) -> Milestone? {
        milestones.first { $0.xpThreshold > previousXP && $0.xpThreshold <= newXP }
    }
}
