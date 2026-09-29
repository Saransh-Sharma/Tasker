import Foundation

public struct PlanningHomeContextCandidateSource: HomeContextCandidateSource {
    public let providerID = "planning"
    /// Widened to include `PlanningMutationRepository` so the carry can be read
    /// out of the close receipt. `CoreDataPlanningRepository` — the only
    /// production conformer — already satisfies all four.
    private let repository: any PlanningRepository & PlanningProjectionRepository & PlanningCalendarContextRepository & PlanningMutationRepository

    public init(repository: any PlanningRepository & PlanningProjectionRepository & PlanningCalendarContextRepository & PlanningMutationRepository) {
        self.repository = repository
    }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        let now = context.date
        let horizon = now.addingTimeInterval(24 * 60 * 60)
        async let tasksResult = try? repository.fetchOpenPlanningTasks()
        async let calendarResult = try? repository.fetchCommitments(from: now, to: horizon)
        let tasks = await tasksResult ?? []
        let calendar = await calendarResult
        var result: [HomeContextCandidate] = []

        if let next = calendar?.commitments
            .filter({ $0.endAt > now && !$0.isAllDay })
            .sorted(by: { $0.startAt < $1.startAt }).first {
            result.append(.init(
                id: "planning-commitment:\(next.id)",
                widgetKind: .compactTimeline,
                title: next.startAt <= now ? next.title : String(localized: "Next: \(next.title)"),
                reason: .init(
                    message: next.startAt <= now
                        ? String(localized: "Happening now")
                        : String(localized: "Next on your calendar"),
                    signal: String(localized: "your calendar")
                ),
                destination: .plan,
                priority: next.startAt <= now ? 520 : 420,
                relevantFrom: now,
                relevantUntil: next.endAt
            ))
        }

        // What last night's close chose as today's first thing.
        //
        // Ranked above the next commitment because a deliberate choice made with
        // a clear head outranks whatever merely happens to be next on a calendar.
        // Resolved from the close receipt rather than from `pinOrder`, which an
        // ordinary manual reorder in Plan also writes.
        if let anchor = await carriedAnchor(tasks: tasks, now: now) {
            result.append(.init(
                id: "planning-carry:\(anchor.id.uuidString)",
                widgetKind: .focusNow,
                title: anchor.title,
                reason: .init(
                    message: String(localized: "Picked when you closed yesterday."),
                    signal: String(localized: "Close the day")
                ),
                destination: .plan,
                priority: 560,
                relevantFrom: now,
                relevantUntil: Calendar.current.startOfDay(for: horizon)
            ))
        }

        // Overdue counts a task whose *planned day* has passed as well as one
        // past its deadline. A task put on Monday and never touched is exactly
        // what the weekly workspace exists to rescue, and counting only
        // `dueDate` made the commonest kind of backlog invisible on Home.
        let startOfToday = Calendar.current.startOfDay(for: now)
        let overdue = tasks.filter { task in
            guard task.metadata.unscheduledDisposition != .deleted,
                  task.metadata.availability == .actionable,
                  task.scheduledEndAt == nil else { return false }
            if let planned = task.metadata.planningDay?.startDate() {
                return planned < startOfToday
            }
            guard let due = task.dueDate else { return false }
            return due < now
        }.count
        if overdue > 0 {
            result.append(.init(
                id: "planning-overdue:\(startOfToday.timeIntervalSince1970)",
                widgetKind: .tasks,
                title: overdue == 1
                    ? String(localized: "1 task from earlier")
                    : String(localized: "\(overdue) tasks from earlier"),
                reason: .init(
                    message: String(localized: "Pick a new day for each."),
                    signal: String(localized: "tasks from earlier")
                ),
                destination: .plan,
                priority: 310,
                relevantFrom: now,
                // Lands on the workspace's overdue briefing rather than on
                // Plan's Day lens: the card is about a backlog, so the first
                // thing it opens should be the decision about that backlog.
                route: .weeklyPlanningWorkspace(.overdue)
            ))
        }
        return result
    }

    /// Yesterday's chosen first thing, if it is still open today.
    ///
    /// Returns `nil` the moment the task is finished — a carry that has been
    /// done is not still the thing to start with, and leaving it on Home would
    /// be the app failing to notice.
    private func carriedAnchor(
        tasks: [PlanningTaskSummary],
        now: Date
    ) async -> PlanningTaskSummary? {
        let calendar = Calendar.current
        guard let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        let today = PlanningDay(date: now)
        let yesterday = PlanningDay(date: yesterdayDate)

        let since = calendar.startOfDay(for: yesterdayDate)
        guard let records = try? await repository.fetchMutationReceipts(since: since) else { return nil }
        guard let anchorID = DayLoopLedger.anchorTaskID(
            in: records,
            closedOn: yesterday,
            targetDay: today
        ) else { return nil }

        return tasks.first { $0.id == anchorID && $0.metadata.planningDay == today }
    }
}
