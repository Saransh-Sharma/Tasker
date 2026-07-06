import Foundation

public enum DayCompassFlow: String, Codable, CaseIterable, Sendable {
    case replan
    case morningPlan
    case eveningReview
    case rescue
    case inbox
    case resumeTask
}

struct DayCompassResumeSignal: Equatable, Sendable {
    let title: String
    let pausedMinutesAgo: Int
    let taskID: UUID
}

struct DayCompassSnoozeSnapshot: Equatable, Sendable {
    var snoozedUntil: [DayCompassFlow: Date] = [:]
    var resumeDismissedForSession = false

    func isSnoozed(_ flow: DayCompassFlow, at now: Date) -> Bool {
        if flow == .resumeTask, resumeDismissedForSession {
            return true
        }
        guard let until = snoozedUntil[flow] else { return false }
        return until > now
    }
}

struct DayCompassSignals: Equatable, Sendable {
    let now: Date
    let selectedDate: Date
    let calendar: Calendar
    let isViewingTodayLens: Bool
    let isAnotherFlowPresented: Bool
    let replanCandidateCount: Int
    let replanEarliestTitle: String?
    let hasCommittedDailyPlan: Bool
    let hasOpenReflectionTarget: Bool
    let todayOpenTaskCount: Int
    let todayDoneTaskCount: Int
    let rescueEligibleCount: Int
    let inboxReadyCount: Int
    let resume: DayCompassResumeSignal?
    let isQuietHours: Bool
    let snoozes: DayCompassSnoozeSnapshot
    let allClearFlow: DayCompassFlow?
    let allClearExpiresAt: Date?

    init(
        now: Date,
        selectedDate: Date,
        calendar: Calendar,
        isViewingTodayLens: Bool,
        isAnotherFlowPresented: Bool = false,
        replanCandidateCount: Int = 0,
        replanEarliestTitle: String? = nil,
        hasCommittedDailyPlan: Bool = false,
        hasOpenReflectionTarget: Bool = false,
        todayOpenTaskCount: Int = 0,
        todayDoneTaskCount: Int = 0,
        rescueEligibleCount: Int = 0,
        inboxReadyCount: Int = 0,
        resume: DayCompassResumeSignal? = nil,
        isQuietHours: Bool = false,
        snoozes: DayCompassSnoozeSnapshot = DayCompassSnoozeSnapshot(),
        allClearFlow: DayCompassFlow? = nil,
        allClearExpiresAt: Date? = nil
    ) {
        self.now = now
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.isViewingTodayLens = isViewingTodayLens
        self.isAnotherFlowPresented = isAnotherFlowPresented
        self.replanCandidateCount = replanCandidateCount
        self.replanEarliestTitle = replanEarliestTitle
        self.hasCommittedDailyPlan = hasCommittedDailyPlan
        self.hasOpenReflectionTarget = hasOpenReflectionTarget
        self.todayOpenTaskCount = todayOpenTaskCount
        self.todayDoneTaskCount = todayDoneTaskCount
        self.rescueEligibleCount = rescueEligibleCount
        self.inboxReadyCount = inboxReadyCount
        self.resume = resume
        self.isQuietHours = isQuietHours
        self.snoozes = snoozes
        self.allClearFlow = allClearFlow
        self.allClearExpiresAt = allClearExpiresAt
    }
}

enum DayCompassState: Equatable, Sendable {
    case replan(count: Int, earliestTitle: String?)
    case morningPlan(openCount: Int)
    case eveningReview(doneCount: Int, openCount: Int)
    case rescue(count: Int)
    case inbox(count: Int)
    case resumeTask(title: String, pausedMinutesAgo: Int, taskID: UUID)
    case allClear(after: DayCompassFlow)

    var flow: DayCompassFlow {
        switch self {
        case .replan:
            return .replan
        case .morningPlan:
            return .morningPlan
        case .eveningReview:
            return .eveningReview
        case .rescue:
            return .rescue
        case .inbox:
            return .inbox
        case .resumeTask:
            return .resumeTask
        case .allClear(let flow):
            return flow
        }
    }
}

struct DayCompassCardModel: Equatable, Sendable {
    let state: DayCompassState
}
