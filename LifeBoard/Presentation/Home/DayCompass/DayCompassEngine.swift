import Foundation

struct DayCompassEngine: Sendable {
    var morningPlanStartHour = 5
    var morningPlanEndHour = 11
    var eveningReviewStartHour = 18
    var inboxMinimumCount = 2

    func resolve(signals: DayCompassSignals) -> DayCompassCardModel? {
        guard signals.isViewingTodayLens,
              signals.calendar.isDate(signals.selectedDate, inSameDayAs: signals.now) else {
            return nil
        }
        guard signals.isAnotherFlowPresented == false else {
            return nil
        }

        if let flow = signals.allClearFlow,
           let expiresAt = signals.allClearExpiresAt,
           expiresAt > signals.now {
            return DayCompassCardModel(state: .allClear(after: flow))
        }

        if signals.replanCandidateCount > 0,
           signals.snoozes.isSnoozed(.replan, at: signals.now) == false {
            return DayCompassCardModel(
                state: .replan(
                    count: signals.replanCandidateCount,
                    earliestTitle: signals.replanEarliestTitle
                )
            )
        }

        if isMorningPlanWindow(signals.now, calendar: signals.calendar),
           signals.hasCommittedDailyPlan == false,
           signals.todayOpenTaskCount > 0,
           signals.snoozes.isSnoozed(.morningPlan, at: signals.now) == false {
            return DayCompassCardModel(state: .morningPlan(openCount: signals.todayOpenTaskCount))
        }

        if isEveningReviewWindow(signals.now, calendar: signals.calendar),
           signals.hasOpenReflectionTarget,
           signals.todayDoneTaskCount + signals.todayOpenTaskCount > 0,
           signals.snoozes.isSnoozed(.eveningReview, at: signals.now) == false {
            return DayCompassCardModel(
                state: .eveningReview(
                    doneCount: signals.todayDoneTaskCount,
                    openCount: signals.todayOpenTaskCount
                )
            )
        }

        if signals.isQuietHours == false,
           signals.rescueEligibleCount > 0,
           signals.snoozes.isSnoozed(.rescue, at: signals.now) == false {
            return DayCompassCardModel(state: .rescue(count: signals.rescueEligibleCount))
        }

        if signals.isQuietHours == false,
           signals.inboxReadyCount >= inboxMinimumCount,
           signals.snoozes.isSnoozed(.inbox, at: signals.now) == false {
            return DayCompassCardModel(state: .inbox(count: signals.inboxReadyCount))
        }

        if let resume = signals.resume,
           signals.snoozes.isSnoozed(.resumeTask, at: signals.now) == false {
            return DayCompassCardModel(
                state: .resumeTask(
                    title: resume.title,
                    pausedMinutesAgo: resume.pausedMinutesAgo,
                    taskID: resume.taskID
                )
            )
        }

        return nil
    }

    func isMorningPlanWindow(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= morningPlanStartHour && hour < morningPlanEndHour
    }

    func isEveningReviewWindow(_ date: Date, calendar: Calendar) -> Bool {
        calendar.component(.hour, from: date) >= eveningReviewStartHour
    }
}
