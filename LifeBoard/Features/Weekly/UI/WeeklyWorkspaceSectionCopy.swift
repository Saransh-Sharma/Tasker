import SwiftUI

/// Every derivation the workspace's sections share.
///
/// `@MainActor` because all of it reads `PlanStore`, which is a `@MainActor`
/// `@Observable`. Static rather than computed properties on the view so that a
/// section struct can answer the same question the root used to.
@MainActor
enum WeeklyWorkspaceSectionCopy {
    // MARK: Meetings

    static func meetings(
        store: PlanStore,
        overrides: [String: WeeklyMeetingIntent],
        on day: PlanningDay
    ) -> [WeeklyWorkspaceDayMeeting] {
        store.commitments(on: day).compactMap { commitment in
            let key = commitment.occurrenceKey(
                calendar: store.workspaceCalendar,
                timeZone: store.workspaceCalendar.timeZone
            )
            guard let intent = WeeklyMeetingPolicy.resolvedIntent(
                participation: commitment.participation ?? .unknown,
                state: commitment.eventState ?? .unspecified,
                isBusy: commitment.isBusy,
                override: overrides[key]
            ) else { return nil }
            return WeeklyWorkspaceDayMeeting(commitment: commitment, intent: intent, occurrenceKey: key)
        }
    }

    /// Meetings on a day the user has chosen to skip.
    ///
    /// Identified rather than summed: the store removes them from the capacity
    /// *calculation*, so the time handed back is exactly the time that was
    /// charged. Summing raw durations credited meetings that fell outside
    /// working hours, double-credited overlaps, and gave an overnight event's
    /// whole length back to both days it touched.
    static func skippedCommitmentIDs(
        store: PlanStore,
        overrides: [String: WeeklyMeetingIntent],
        on day: PlanningDay
    ) -> Set<String> {
        var result: Set<String> = []
        for commitment in store.commitments(on: day) {
            let key = commitment.occurrenceKey(
                calendar: store.workspaceCalendar,
                timeZone: store.workspaceCalendar.timeZone
            )
            if overrides[key] == .skipping { result.insert(commitment.id) }
        }
        return result
    }

    // MARK: Load and placement

    static func metrics(
        store: PlanStore,
        overrides: [String: WeeklyMeetingIntent],
        pendingPlacements: [UUID: PlanningDay],
        for day: PlanningDay
    ) -> WeeklyWorkspaceDayMetrics {
        let availability = store.workspaceAvailability(
            on: day,
            skippingCommitmentIDs: skippedCommitmentIDs(store: store, overrides: overrides, on: day)
        )
        let tasks = plannedTasks(store: store, pendingPlacements: pendingPlacements, on: day)
        let planned = tasks.reduce(0) { total, task in
            guard let estimate = task.estimatedDuration, estimate > 0 else {
                return total + WeeklyWorkspaceLoad.assumedTaskMinutes
            }
            return total + Int(estimate / 60)
        }
        return WeeklyWorkspaceDayMetrics(
            placedCount: tasks.count,
            plannedMinutes: planned,
            usableMinutes: availability.usableMinutes,
            isToday: day == store.todayPlanningDay()
        )
    }

    static func selectedDayAvailability(
        store: PlanStore,
        overrides: [String: WeeklyMeetingIntent]
    ) -> WeeklyWorkspaceAvailability {
        store.workspaceAvailability(
            on: store.selectedDay,
            skippingCommitmentIDs: skippedCommitmentIDs(store: store, overrides: overrides, on: store.selectedDay)
        )
    }

    static func plannedTasks(
        store: PlanStore,
        pendingPlacements: [UUID: PlanningDay],
        on day: PlanningDay
    ) -> [PlanningTaskSummary] {
        let movingAway = Set(pendingPlacements.compactMap { id, destination in
            destination == day ? nil : id
        })
        var result = store.orderedPlannedTasks(on: day).filter { movingAway.contains($0.id) == false }
        let existing = Set(result.map(\.id))
        let arriving = pendingPlacements.compactMap { id, destination -> PlanningTaskSummary? in
            guard destination == day, existing.contains(id) == false, var task = store.task(for: id) else {
                return nil
            }
            task.metadata.planningDay = day
            return task
        }
        result.append(contentsOf: arriving.sorted { $0.title < $1.title })
        return result
    }

    // MARK: Days

    static func allDays(store: PlanStore) -> [PlanningDay] {
        store.weekDays(containing: store.selectedDay)
    }

    static func visibleDays(store: PlanStore, showsSoftDays: Bool) -> [PlanningDay] {
        let days = allDays(store: store)
        guard showsSoftDays == false else { return days }
        let today = store.todayPlanningDay()
        let past = WeeklyPlanningHorizon.pastDays(in: days, today: today)
        let concrete = WeeklyPlanningHorizon.concreteDays(in: days, today: today)
        return past + concrete
    }

    static func softDays(store: PlanStore) -> [PlanningDay] {
        WeeklyPlanningHorizon.softDays(in: allDays(store: store), today: store.todayPlanningDay())
    }

    static func placeableDays(store: PlanStore) -> [PlanningDay] {
        let today = store.todayPlanningDay()
        return allDays(store: store).filter { WeeklyPlanningHorizon.canReceivePlacement($0, today: today) }
    }

    // MARK: Tray

    static func trayTasks(
        store: PlanStore,
        lane: WeeklyWorkspaceLane,
        search: String,
        pendingPlacements: [UUID: PlanningDay]
    ) -> [PlanningTaskSummary] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.workspaceTasks(in: lane)
            .filter { pendingPlacements[$0.id] == nil }
            .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }

    static func trayTitle(store: PlanStore, _ value: WeeklyWorkspaceLane) -> String {
        let count = store.workspaceTasks(in: value).count
        return count > 0 ? "\(value.title) \(count)" : value.title
    }

    static func emptyTrayMessage(_ lane: WeeklyWorkspaceLane) -> String {
        switch lane {
        case .overdue: "Nothing is overdue. "
        case .inbox: "The inbox is clear."
        case .anytime: "Everything open already has a day."
        }
    }

    static func meetingDecisionLabel(_ intent: WeeklyMeetingIntent) -> String {
        switch intent {
        case .attending: "In my week"
        case .skipping: "Skip this week"
        case .undecided: "Decide"
        }
    }

    static func meetingDecisionSymbol(_ intent: WeeklyMeetingIntent) -> String {
        switch intent {
        case .attending: "checkmark.circle"
        case .skipping: "minus.circle"
        case .undecided: "circle.dashed"
        }
    }

    static func weekStart(store: PlanStore) -> Date {
        store.selectedDay.startDate(calendar: store.workspaceCalendar).map {
            store.workspaceCalendar.dateInterval(of: .weekOfYear, for: $0)?.start ?? $0
        } ?? Date()
    }

    static func headerSubtitle(store: PlanStore) -> String {
        let toPlace = store.workspaceTasks(in: .anytime).count
        let briefing = store.overdueBriefing()
        var parts: [String] = []
        parts.append(toPlace == 1 ? "1 waiting for a home" : "\(toPlace) waiting for a home")
        if briefing.count > 0 {
            parts.append(briefing.count == 1 ? "1 carried forward" : "\(briefing.count) carried forward")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Formatting

    static func weekRangeLabel(store: PlanStore) -> String {
        let days = allDays(store: store)
        guard let first = days.first?.startDate(calendar: store.workspaceCalendar),
              let last = days.last?.startDate(calendar: store.workspaceCalendar) else {
            return WeeklyWorkspaceCopy.title
        }
        let formatter = DateFormatter()
        formatter.calendar = store.workspaceCalendar
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: first)
        let end = formatter.string(from: last)
        return "\(start) – \(end)"
    }

    static func weekdayInitial(store: PlanStore, _ day: PlanningDay) -> String {
        guard let date = day.startDate(calendar: store.workspaceCalendar) else { return "" }
        let index = store.workspaceCalendar.component(.weekday, from: date) - 1
        let symbols = store.workspaceCalendar.veryShortStandaloneWeekdaySymbols
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    static func shortDayName(store: PlanStore, _ day: PlanningDay) -> String {
        if day == store.todayPlanningDay() { return "Today" }
        guard let date = day.startDate(calendar: store.workspaceCalendar) else { return "that day" }
        let formatter = DateFormatter()
        formatter.calendar = store.workspaceCalendar
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    static func longDayLabel(store: PlanStore, _ day: PlanningDay) -> String {
        guard let date = day.startDate(calendar: store.workspaceCalendar) else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = store.workspaceCalendar
        formatter.dateFormat = "EEEE d"
        let base = formatter.string(from: date)
        return day == store.todayPlanningDay() ? "\(base) · Today" : base
    }

    static func timeLabel(store: PlanStore, _ commitment: CalendarCommitment) -> String {
        guard commitment.isAllDay == false else { return "All day" }
        let formatter = DateFormatter()
        formatter.calendar = store.workspaceCalendar
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: commitment.startAt)
    }

    static func waitingLabel(
        store: PlanStore,
        lane: WeeklyWorkspaceLane,
        _ task: PlanningTaskSummary
    ) -> String? {
        guard lane == .overdue, let date = store.workspaceOverdueDate(task) else { return nil }
        let days = store.workspaceCalendar.dateComponents(
            [.day],
            from: store.workspaceCalendar.startOfDay(for: date),
            to: store.workspaceCalendar.startOfDay(for: Date())
        ).day ?? 0
        guard days > 0 else { return nil }
        return days == 1 ? "Waiting since yesterday" : "Waiting \(days) days"
    }

    static func dayAccessibilityLabel(
        store: PlanStore,
        _ day: PlanningDay,
        metrics: WeeklyWorkspaceDayMetrics
    ) -> String {
        "\(longDayLabel(store: store, day)). \(metrics.summary)"
    }
}
