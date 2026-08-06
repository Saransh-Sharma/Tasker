import Foundation

/// Store operations the weekly planning workspace needs.
///
/// Every one of these routes through the same `commit` / receipt path the rest
/// of `PlanStore` uses, which is what makes each of them a single Undo rather
/// than a pile of individually-reversible writes. That is the whole reason the
/// workspace needs no staged draft: the durable receipt already *is* the
/// "review before it's real" affordance, offered after the fact instead of
/// before, where it costs nothing to ignore.
extension PlanStore {

    // MARK: Reading

    /// Days of the week containing `day`, in the user's week order.
    func weekDays(containing day: PlanningDay) -> [PlanningDay] {
        weekSnapshot?.days.map(\.day) ?? []
    }

    /// Open tasks with no day, split by how they got there.
    func workspaceTasks(in lane: WeeklyWorkspaceLane, now: Date = Date()) -> [PlanningTaskSummary] {
        let today = startOfToday(now)
        switch lane {
        case .overdue:
            // Overdue means "the day it was put on has passed", not "past its
            // deadline". A task placed on Monday and untouched is the thing
            // this surface exists to rescue, whether or not it had a due date.
            return tasks
                .filter { task in
                    guard task.metadata.unscheduledDisposition != .deleted,
                          task.metadata.availability == .actionable else { return false }
                    if let placed = task.metadata.planningDay?.startDate(calendar: workspaceCalendar) {
                        return placed < today
                    }
                    if let due = task.dueDate { return due < today }
                    return false
                }
                .sorted { lhs, rhs in
                    let left = workspaceOverdueDate(lhs) ?? .distantFuture
                    let right = workspaceOverdueDate(rhs) ?? .distantFuture
                    return left == right ? lhs.title < rhs.title : left < right
                }
        case .inbox:
            return tasks.filter {
                $0.metadata.unscheduledDisposition == .inbox
                    && $0.metadata.planningDay == nil
                    && $0.metadata.availability == .actionable
            }
        case .anytime:
            // Everything open and unplaced, including Someday. This is the lane
            // you go to when you *want* to pull something forward rather than
            // when something is nagging you.
            return tasks.filter {
                $0.metadata.planningDay == nil
                    && $0.metadata.unscheduledDisposition != .deleted
                    && $0.metadata.unscheduledDisposition != .archived
                    && $0.metadata.availability == .actionable
            }
        }
    }

    func workspaceOverdueDate(_ task: PlanningTaskSummary) -> Date? {
        task.metadata.planningDay?.startDate(calendar: workspaceCalendar) ?? task.dueDate
    }

    func overdueBriefing(now: Date = Date()) -> WeeklyOverdueBriefing {
        let overdue = workspaceTasks(in: .overdue, now: now)
        return WeeklyOverdueBriefing(
            count: overdue.count,
            oldestDate: overdue.compactMap(workspaceOverdueDate).min()
        )
    }

    /// Minutes already claimed on a day by placed tasks.
    func plannedMinutes(on day: PlanningDay) -> Int {
        plannedTasks(on: day).reduce(0) { total, task in
            guard let estimate = task.estimatedDuration, estimate > 0 else {
                return total + WeeklyWorkspaceLoad.assumedTaskMinutes
            }
            return total + Int(estimate / 60)
        }
    }

    /// Usable minutes on a day, after meetings the user is actually keeping.
    ///
    /// Skipped meetings are removed from the capacity *calculation* rather than
    /// credited back afterwards, so the time handed back is exactly the time
    /// that was charged — clipped to working hours and unioned across overlaps.
    /// See `PlanStore.workspaceCapacity(on:skippingCommitmentIDs:)`.
    func usableMinutes(on day: PlanningDay, skippingCommitmentIDs: Set<String> = []) -> Int {
        let capacity = workspaceCapacity(on: day, skippingCommitmentIDs: skippingCommitmentIDs)
        return max(0, Int(capacity.usableDuration / 60))
    }

    func commitments(on day: PlanningDay) -> [CalendarCommitment] {
        guard let start = day.startDate(calendar: workspaceCalendar),
              let end = workspaceCalendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return workspaceCommitments(from: start, to: end)
    }

    /// Capacity and free windows resolved from the same skipped-meeting set.
    func workspaceAvailability(
        on day: PlanningDay,
        skippingCommitmentIDs: Set<String> = []
    ) -> WeeklyWorkspaceAvailability {
        WeeklyWorkspaceAvailability(
            day: day,
            skippedCommitmentIDs: skippingCommitmentIDs,
            usableMinutes: usableMinutes(
                on: day,
                skippingCommitmentIDs: skippingCommitmentIDs
            ),
            plannedMinutes: plannedMinutes(on: day),
            freeWindows: freeWindows(
                on: day,
                skippingCommitmentIDs: skippingCommitmentIDs
            )
        )
    }

    // MARK: Writing

    /// Places one task on one day.
    ///
    /// Writes `planningDay` — "the day I intend to do this" — and never
    /// `dueDate`, which means "when it must be finished". Conflating them is
    /// the classic planner defect: moving a task to Thursday to *work* on it
    /// silently rewrites a real deadline, and the user finds out when something
    /// ships late.
    @discardableResult
    func place(_ task: PlanningTaskSummary, on day: PlanningDay) async -> Bool {
        guard WeeklyPlanningHorizon.canReceivePlacement(day, today: todayPlanningDay()) else {
            errorMessage = "That day has already passed."
            return false
        }
        guard task.metadata.planningDay != day else { return false }
        var after = task.metadata
        after.planningDay = day
        // A task pulled out of Someday has to stop being Someday, or it lands on
        // Wednesday and stays invisible in every list that filters Someday out.
        if after.unscheduledDisposition != .inbox { after.unscheduledDisposition = .inbox }
        after.updatedAt = Date()
        do {
            try await workspaceCommit(
                .saveTaskMetadata(before: task.metadata, after: after),
                source: "plan.week.place",
                summary: "Moved \(task.title)"
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Takes a task off its day without deciding anything else about it.
    ///
    /// Distinct from `releaseToSomeday`: "not this Thursday after all" and "not
    /// in the foreseeable future" are different statements, and only one of them
    /// should hide the task from the Inbox.
    @discardableResult
    func unplace(_ task: PlanningTaskSummary) async -> Bool {
        guard task.metadata.planningDay != nil else { return false }
        var after = task.metadata
        after.planningDay = nil
        after.pinOrder = nil
        after.updatedAt = Date()
        do {
            try await workspaceCommit(
                .saveTaskMetadata(before: task.metadata, after: after),
                source: "plan.week.unplace",
                summary: "Unscheduled \(task.title)"
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Applies a spread plan as one batch, so the whole "bring it forward" act
    /// is a single receipt and a single Undo.
    @discardableResult
    func applySpread(_ plan: WeeklySpreadPlan) async -> Bool {
        guard plan.placements.isEmpty == false else { return false }
        // `uniqueKeysWithValues` traps on a duplicate key. A CloudKit merge that
        // briefly produces two rows for one id would crash the app on "Spread
        // across this week"; keeping the first occurrence degrades instead.
        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let mutations: [PlanMutation] = plan.placements.compactMap { placement in
            guard let task = byID[placement.taskID] else { return nil }
            var after = task.metadata
            after.planningDay = placement.day
            if after.unscheduledDisposition != .inbox { after.unscheduledDisposition = .inbox }
            after.updatedAt = Date()
            return .saveTaskMetadata(before: task.metadata, after: after)
        }
        guard mutations.isEmpty == false else { return false }
        do {
            try await workspaceCommit(
                .batch(mutations),
                source: "plan.week.spread",
                summary: plan.summary
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// The bankruptcy move: everything selected goes to Someday, in one batch.
    @discardableResult
    func releaseToSomeday(_ taskIDs: Set<UUID>) async -> Bool {
        let selected = tasks.filter { taskIDs.contains($0.id) }
        guard selected.isEmpty == false else { return false }
        let mutations = selected.map { task -> PlanMutation in
            var after = task.metadata
            after.planningDay = nil
            after.unscheduledDisposition = .someday
            after.updatedAt = Date()
            return .saveTaskMetadata(before: task.metadata, after: after)
        }
        do {
            try await workspaceCommit(
                .batch(mutations),
                source: "plan.week.release",
                summary: mutations.count == 1
                    ? "Moved 1 task to Someday"
                    : "Moved \(mutations.count) tasks to Someday"
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Places several already-loaded tasks on one day in a single batch.
    @discardableResult
    func placeAll(_ taskIDs: Set<UUID>, on day: PlanningDay) async -> Bool {
        guard WeeklyPlanningHorizon.canReceivePlacement(day, today: todayPlanningDay()) else {
            errorMessage = "That day has already passed."
            return false
        }
        let selected = tasks.filter { taskIDs.contains($0.id) && $0.metadata.planningDay != day }
        guard selected.isEmpty == false else { return false }
        let mutations = selected.map { task -> PlanMutation in
            var after = task.metadata
            after.planningDay = day
            if after.unscheduledDisposition != .inbox { after.unscheduledDisposition = .inbox }
            after.updatedAt = Date()
            return .saveTaskMetadata(before: task.metadata, after: after)
        }
        do {
            try await workspaceCommit(
                .batch(mutations),
                source: "plan.week.placeAll",
                summary: "Moved \(mutations.count) tasks"
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Creates a task straight onto a day.
    ///
    /// It persists on the first return key, before any placement is "committed"
    /// anywhere, because a composer that can lose what you typed is a composer
    /// people stop typing into.
    @discardableResult
    func createTask(
        titled title: String,
        on day: PlanningDay?,
        estimatedMinutes: Int? = nil
    ) async -> UUID? {
        guard let outcome = await createWorkspaceTask(
            titled: title,
            on: day,
            estimatedMinutes: estimatedMinutes
        ), outcome.wasPlaced || day == nil else { return nil }
        return outcome.taskID
    }

    /// Creates the canonical task once and reports a placement failure without
    /// discarding the new ID. The composer can then retry only the metadata
    /// placement instead of creating a duplicate task.
    func createWorkspaceTask(
        titled title: String,
        on day: PlanningDay?,
        estimatedMinutes: Int? = nil
    ) async -> WeeklyTaskCreationOutcome? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard let repository = workspaceTaskRepository else {
            errorMessage = "Tasks cannot be created from here yet."
            return nil
        }
        let request = CreateTaskDefinitionRequest(
            title: trimmed,
            projectID: ProjectConstants.inboxProjectID,
            projectName: ProjectConstants.inboxProjectName,
            estimatedDuration: estimatedMinutes.map { TimeInterval($0 * 60) }
        )
        let created: TaskDefinition
        do {
            created = try await withCheckedThrowingContinuation { continuation in
                repository.create(request: request) { continuation.resume(with: $0) }
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }

        if let day {
            do {
                var metadata = PlanningTaskMetadata(taskID: created.id)
                var after = metadata
                after.planningDay = day
                after.updatedAt = Date()
                metadata.updatedAt = after.updatedAt
                try await workspaceCommit(
                    .saveTaskMetadata(before: metadata, after: after),
                    source: "plan.week.create",
                    summary: "Added \(trimmed)"
                )
            } catch {
                errorMessage = error.localizedDescription
                await load()
                return WeeklyTaskCreationOutcome(taskID: created.id, wasPlaced: false)
            }
        }
        await load()
        return WeeklyTaskCreationOutcome(taskID: created.id, wasPlaced: true)
    }

    /// A day's work in the order the user arranged it.
    ///
    /// Separate from `plannedTasks(on:)` rather than sorting in place: that
    /// method feeds capacity maths and Day-lens surfaces that have never
    /// promised an order, and quietly changing it would move rows in views
    /// nobody touched.
    func orderedPlannedTasks(on day: PlanningDay) -> [PlanningTaskSummary] {
        WeeklyDayOrdering.sorted(
            plannedTasks(on: day),
            rank: { $0.metadata.pinOrder },
            tiebreak: { $0.title }
        )
    }

    /// Moves `moving` to sit directly before `target` within its day.
    ///
    /// Writes a dense rank for every task on the day in one batch, so the whole
    /// reorder is a single receipt and a single Undo — not one write per row
    /// that would need N undos to put back.
    @discardableResult
    func reorder(on day: PlanningDay, moving: UUID, before target: UUID?) async -> Bool {
        let current = orderedPlannedTasks(on: day)
        let ordered = WeeklyDayOrdering.reordered(current.map(\.id), moving: moving, before: target)
        guard ordered != current.map(\.id) else { return false }
        let ranks = WeeklyDayOrdering.ranks(for: ordered)
        let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        let mutations: [PlanMutation] = ordered.compactMap { id in
            guard let task = byID[id], let rank = ranks[id] else { return nil }
            guard task.metadata.pinOrder != rank else { return nil }
            var after = task.metadata
            after.pinOrder = rank
            after.updatedAt = Date()
            return .saveTaskMetadata(before: task.metadata, after: after)
        }
        guard mutations.isEmpty == false else { return false }
        do {
            try await workspaceCommit(
                .batch(mutations),
                source: "plan.week.reorder",
                summary: "Reordered \(Self.dayName(day, calendar: workspaceCalendar))"
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Open windows on a day, computed fresh for whichever day is asked about.
    func freeWindows(on day: PlanningDay, skippingCommitmentIDs: Set<String> = []) -> [FreeWindow] {
        workspaceFreeWindows(on: day, skippingCommitmentIDs: skippingCommitmentIDs)
    }

    /// Puts a placed task into the best-fitting gap in its day.
    ///
    /// Returns `nil` when nothing fits, so the caller can say so rather than
    /// silently creating a block at an hour the day cannot hold.
    @discardableResult
    func timeBox(
        _ task: PlanningTaskSummary,
        on day: PlanningDay,
        skippingCommitmentIDs: Set<String> = [],
        now: Date = Date()
    ) async -> Date? {
        let minutes = task.estimatedDuration.map { Int($0 / 60) } ?? WeeklyWorkspaceLoad.assumedTaskMinutes
        // Never box into a gap that has already gone by today.
        let earliest = day == todayPlanningDay(now: now) ? now : nil
        let availability = workspaceAvailability(
            on: day,
            skippingCommitmentIDs: skippingCommitmentIDs
        )
        guard let start = WeeklyTimeBox.bestFitStart(
            windows: availability.freeWindows,
            minutes: minutes,
            after: earliest
        ) else { return nil }
        await createBlock(
            title: task.title,
            start: start,
            duration: TimeInterval(minutes * 60),
            taskID: task.id
        )
        return start
    }

    // MARK: Helpers

    static func dayName(_ day: PlanningDay, calendar: Calendar) -> String {
        guard let date = day.startDate(calendar: calendar) else { return "that day" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    func todayPlanningDay(now: Date = Date()) -> PlanningDay {
        PlanningDay(date: now, timeZone: workspaceCalendar.timeZone, calendar: workspaceCalendar)
    }

    private func startOfToday(_ now: Date) -> Date {
        workspaceCalendar.startOfDay(for: now)
    }
}
