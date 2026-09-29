import Foundation

/// Shared, side-effect-free day derivation used by Plan and Home.
struct PlanDayProjectionInputs: Sendable {
    let tasks: [PlanningTaskSummary]
    let allBlocks: [InternalTimeBlock]
    let workingProfile: WorkingHoursProfile?
    let calendarContext: PlanningCalendarContext
    let calendarState: PlanningCalendarState
    let calendar: Calendar
    let now: Date
    func snapshot(for day: PlanningDay) -> PlanDaySnapshot {
        let bounds = dayBounds(day)
        let externalCommitments = externalCommitments(for: bounds)
        let blocks = allBlocks.filter { $0.startAt < bounds.end && $0.endAt > bounds.start }
        let planned = tasks.filter {
            $0.metadata.unscheduledDisposition != .deleted
                && effectivePlanningDay(for: $0) == day
                && $0.metadata.availability == .actionable
        }
        let working = workingIntervals(for: day)
        let capacity = CapacityBudgetService.calculate(
            workingIntervals: working,
            fixedCalendarCommitments: externalCommitments.map { DateInterval(start: $0.startAt, end: $0.endAt) },
            internalFixedBlocks: blocks.filter(\.isFixed).map { DateInterval(start: $0.startAt, end: $0.endAt) },
            userBuffer: workingProfile?.bufferDuration ?? 30 * 60,
            plannedEstimates: planned.map(\.estimatedDuration)
        )
        let linkedTaskIDs = Set(blocks.compactMap(\.taskID))
        let timedIntervals = planned.compactMap { task -> DateInterval? in
            guard !linkedTaskIDs.contains(task.id), let start = task.scheduledStartAt else { return nil }
            return DateInterval(start: start, end: task.scheduledEndAt ?? start.addingTimeInterval(task.estimatedDuration ?? 30 * 60))
        }
        let occupied = timedIntervals + externalCommitments.map { DateInterval(start: $0.startAt, end: $0.endAt) }
            + blocks.map { DateInterval(start: $0.startAt, end: $0.endAt) }
        let freeWindows = FreeWindowService.calculate(
            workingIntervals: working,
            occupiedIntervals: occupied
        )
        let unscheduled = tasks.filter {
            effectivePlanningDay(for: $0) == nil
                && $0.metadata.availability == .actionable
                && $0.metadata.unscheduledDisposition == .inbox
        }
        return PlanDaySnapshot(
            workingIntervals: working,
            day: day,
            capacity: capacity,
            commitments: externalCommitments.map {
                PlanningFixedCommitment(
                    id: $0.id,
                    title: $0.title,
                    startAt: $0.startAt,
                    endAt: $0.endAt,
                    source: .externalCalendar
                )
            } + blocks.filter(\.isFixed).map {
                PlanningFixedCommitment(id: $0.id.uuidString, title: $0.title, startAt: $0.startAt, endAt: $0.endAt, source: .internalBlock)
            },
            calendarAuthorization: calendarContext.authorization,
            calendarState: calendarState,
            freeWindows: freeWindows,
            fitsNextCandidates: FitsNextService.candidates(
                tasks: unscheduled,
                windows: freeWindows
            ),
            blocks: blocks,
            plannedTasks: planned,
            unscheduledTasks: unscheduled,
            generatedAt: now
        )
    }

    private func effectivePlanningDay(for task: PlanningTaskSummary) -> PlanningDay? {
        Self.effectivePlanningDay(for: task, calendar: calendar)
    }

    /// The day a task is planned for: its planning day, or — for a task that was
    /// only ever given a start time — the day of that start. Every Plan surface
    /// (Day, Week, Backlog, capacity) must read this one rule, or a timed task
    /// is "planned" on Day while Week still lists it as unplanned.
    static func effectivePlanningDay(for task: PlanningTaskSummary, calendar: Calendar) -> PlanningDay? {
        task.metadata.planningDay ?? task.scheduledStartAt.map {
            PlanningDay(date: $0, timeZone: calendar.timeZone, calendar: calendar)
        }
    }

    private func workingIntervals(for day: PlanningDay) -> [DateInterval] {
        guard let start = day.startDate(calendar: calendar) else { return [] }
        let weekday = calendar.component(.weekday, from: start)
        return (workingProfile?.intervalsByWeekday[weekday] ?? []).compactMap { interval in
            guard let intervalStart = calendar.date(byAdding: .minute, value: interval.startMinute, to: start),
                  let intervalEnd = calendar.date(byAdding: .minute, value: interval.endMinute, to: start),
                  intervalEnd > intervalStart else { return nil }
            return DateInterval(start: intervalStart, end: intervalEnd)
        }
    }

    private func externalCommitments(for bounds: (start: Date, end: Date)) -> [CalendarCommitment] {
        calendarContext.commitments.filter {
            $0.isAllDay == false && $0.startAt < bounds.end && $0.endAt > bounds.start && $0.availability != "1"
        }
    }

    private func dayBounds(_ day: PlanningDay) -> (start: Date, end: Date) {
        let start = day.startDate(calendar: calendar) ?? calendar.startOfDay(for: Date())
        return (start, calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
    }

}
