import Foundation
import Observation

enum PlanLens: String, CaseIterable, Identifiable, Codable, Sendable {
    case day = "Day"
    case week = "Week"
    case backlog = "Backlog"

    var id: String { rawValue }
}

struct BacklogDeletionUndoState: Equatable, Sendable {
    let receiptID: UUID
    let deletedCount: Int
}

enum PlanLensRestoration {
    static let key = "lifeboard.plan.selectedLens.v1"

    static func load(from defaults: UserDefaults = .standard) -> PlanLens {
        guard let rawValue = defaults.string(forKey: key),
              let lens = PlanLens(rawValue: rawValue) else {
            return .day
        }
        return lens
    }

    static func save(_ lens: PlanLens, to defaults: UserDefaults = .standard) {
        defaults.set(lens.rawValue, forKey: key)
    }
}

@MainActor
@Observable
final class PlanStore {
    private(set) var tasks: [PlanningTaskSummary] = []
    private(set) var daySnapshot: PlanDaySnapshot?
    private(set) var weekSnapshot: PlanWeekSnapshot?
    private(set) var backlogSnapshot: PlanBacklogSnapshot?
    private(set) var repairProposals: [PlanRepairProposal] = []
    private(set) var activeFocusSession: FocusSessionV2?
    private(set) var normalizedEvents: [NormalizedLifeEvent] = []
    private(set) var lastMutationReceiptID: UUID?
    private(set) var backlogDeletionUndoState: BacklogDeletionUndoState?
    private(set) var isLoading = false
    var errorMessage: String?
    var selectedDay: PlanningDay

    private let planningRepository: any PlanningRepository & PlanningProjectionRepository & PlanningMutationRepository & FocusExecutionCoordinator
    private let blockRepository: any InternalTimeBlockRepository
    private let calendarRepository: any PlanningCalendarContextRepository
    private let repairService: any PlanRepairService
    private var allBlocks: [InternalTimeBlock] = []
    private(set) var workingProfile: WorkingHoursProfile?
    private var calendarContext = PlanningCalendarContext(authorization: .notDetermined)
    private var calendar: Calendar

    init(
        planningRepository: any PlanningRepository & PlanningProjectionRepository & PlanningMutationRepository & FocusExecutionCoordinator,
        blockRepository: any InternalTimeBlockRepository,
        calendarRepository: any PlanningCalendarContextRepository = SystemPlanningCalendarContextRepository(),
        repairService: any PlanRepairService = DeterministicPlanRepairService(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.planningRepository = planningRepository
        self.blockRepository = blockRepository
        self.calendarRepository = calendarRepository
        self.repairService = repairService
        self.calendar = calendar
        selectedDay = PlanningDay(date: now, timeZone: calendar.timeZone, calendar: calendar)
    }

    func load() async {
        guard isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let bounds = weekBounds(containing: selectedDay)
            async let fetchedTasks = planningRepository.fetchOpenPlanningTasks()
            async let fetchedBlocks = blockRepository.fetchTimeBlocks(from: bounds.start, to: bounds.end)
            async let profiles = blockRepository.fetchWorkingHoursProfiles()
            async let fetchedCalendarContext = safeCalendarContext(from: bounds.start, to: bounds.end)
            tasks = try await fetchedTasks
            activeFocusSession = try await planningRepository.activeSession()
            if let session = activeFocusSession,
               let repair = FocusStartupRepairPolicy.commandKind(for: session, now: Date()) {
                let repaired = try await planningRepository.handle(.init(
                    sessionID: session.id,
                    kind: repair,
                    occurredAt: Date()
                ))
                activeFocusSession = repaired.state == .ended ? nil : repaired
            }
            await FocusLiveActivityCoordinator.shared.endOrphanedActivities(except: activeFocusSession?.id)
            if let activeFocusSession {
                await synchronizeFocusPresentation(activeFocusSession)
            } else {
                await FocusNotificationFallbackCoordinator.shared.cancelAll()
            }
            allBlocks = try await fetchedBlocks
            let availableProfiles = try await profiles
            calendarContext = await fetchedCalendarContext
            if let selected = availableProfiles.first(where: \.isDefault) ?? availableProfiles.first {
                workingProfile = selected
            } else {
                let profile = Self.defaultWorkingProfile()
                try await blockRepository.saveWorkingHoursProfile(profile)
                workingProfile = profile
            }
            rebuildSnapshots()
            repairProposals = try await suppressAcknowledgedRepairs(repairProposals)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestCalendarAccess() async {
        _ = await calendarRepository.requestAccess()
        await load()
    }

    func select(day: PlanningDay) async {
        selectedDay = day
        await load()
    }

    func moveSelection(by days: Int) async {
        guard let date = selectedDay.startDate(calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: days, to: date) else { return }
        selectedDay = PlanningDay(date: moved, timeZone: calendar.timeZone, calendar: calendar)
        await load()
    }

    func updateTask(
        _ task: PlanningTaskSummary,
        planningDay: PlanningDay? = nil,
        preserveDay: Bool = false,
        commitment: TaskCommitmentLevel? = nil,
        availability: TaskAvailability? = nil,
        context: PlanningContext? = nil
    ) async {
        var metadata = task.metadata
        metadata.planningDay = preserveDay ? metadata.planningDay : planningDay
        metadata.commitmentLevel = commitment ?? metadata.commitmentLevel
        metadata.availability = availability ?? metadata.availability
        metadata.planningContext = context ?? metadata.planningContext
        metadata.updatedAt = Date()
        do {
            try await commit(
                .saveTaskMetadata(before: task.metadata, after: metadata),
                source: "plan.task",
                summary: "Updated \(task.title)"
            )
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func bulkPlan(_ taskIDs: Set<UUID>, on day: PlanningDay) async {
        let values = tasks.filter { taskIDs.contains($0.id) }.map { task -> PlanningTaskMetadata in
            var metadata = task.metadata
            metadata.planningDay = day
            metadata.updatedAt = Date()
            return metadata
        }
        do {
            let beforeByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.metadata) })
            let mutations = values.compactMap { after -> PlanMutation? in
                guard let before = beforeByID[after.taskID] else { return nil }
                return .saveTaskMetadata(before: before, after: after)
            }
            try await commit(.batch(mutations), source: "plan.bulk", summary: "Planned \(mutations.count) tasks")
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func bulkUpdate(
        _ taskIDs: Set<UUID>,
        planningDay: PlanningDay? = nil,
        preserveDay: Bool = true,
        context: PlanningContext? = nil,
        availability: TaskAvailability? = nil,
        disposition: UnscheduledDisposition? = nil
    ) async {
        let selected = tasks.filter { taskIDs.contains($0.id) }
        let mutations = selected.map { task -> PlanMutation in
            var after = task.metadata
            if !preserveDay { after.planningDay = planningDay }
            if let context { after.planningContext = context }
            if let availability { after.availability = availability }
            if let disposition {
                after.unscheduledDisposition = disposition
                after.planningDay = nil
            }
            after.updatedAt = Date()
            return .saveTaskMetadata(before: task.metadata, after: after)
        }
        guard !mutations.isEmpty else { return }
        do {
            try await commit(.batch(mutations), source: "plan.bulk", summary: "Updated \(mutations.count) tasks")
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteBacklogTasks(_ taskIDs: Set<UUID>) async {
        let selected = tasks.filter {
            taskIDs.contains($0.id) && $0.metadata.unscheduledDisposition != .deleted
        }
        let mutations = selected.map { task -> PlanMutation in
            var after = task.metadata
            after.planningDay = nil
            after.unscheduledDisposition = .deleted
            after.updatedAt = Date()
            return .saveTaskMetadata(before: task.metadata, after: after)
        }
        guard mutations.isEmpty == false else { return }
        do {
            let receiptID = try await commit(
                .batch(mutations),
                source: "plan.backlog.delete",
                summary: "Deleted \(mutations.count) backlog item\(mutations.count == 1 ? "" : "s")"
            )
            backlogDeletionUndoState = BacklogDeletionUndoState(
                receiptID: receiptID,
                deletedCount: mutations.count
            )
            // Reflect the confirmed tombstone immediately. The authoritative reload below
            // reconciles CloudKit/Core Data, but must not hold the interaction behind Focus,
            // Calendar, or Live Activity restoration work.
            tasks.removeAll { taskIDs.contains($0.id) }
            rebuildSnapshots()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveWorkingHours(
        activeWeekdays: Set<Int>,
        startMinute: Int,
        endMinute: Int,
        bufferDuration: TimeInterval
    ) async {
        guard endMinute > startMinute else {
            errorMessage = "Working hours must end after they start."
            return
        }
        var value = workingProfile ?? Self.defaultWorkingProfile()
        value.intervalsByWeekday = Dictionary(uniqueKeysWithValues: activeWeekdays.map {
            ($0, [WorkingHoursInterval(startMinute: startMinute, endMinute: endMinute)])
        })
        value.bufferDuration = max(0, bufferDuration)
        value.updatedAt = Date()
        do {
            try await blockRepository.saveWorkingHoursProfile(value)
            workingProfile = value
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func applyRepair(_ proposal: PlanRepairProposal, action: PlanRepairAction) async {
        let source = repairReceiptSource(proposal.id)
        guard action != .askEva else { return }
        do {
            let targetTask = proposal.taskID.flatMap(task(for:))
                ?? daySnapshot?.plannedTasks.sorted(by: repairTaskOrder).last
            let targetBlock = proposal.timeBlockID.flatMap { id in allBlocks.first { $0.id == id } }
                ?? daySnapshot?.blocks.max(by: { $0.duration < $1.duration })
            let mutation: PlanMutation
            switch action {
            case .resume:
                mutation = .batch([])
            case .moveLaterToday:
                guard let block = targetBlock else { mutation = .batch([]); break }
                let start = daySnapshot?.freeWindows.first(where: { $0.endAt > Date() })?.startAt
                    ?? max(Date(), block.endAt).addingTimeInterval(15 * 60)
                var moved = block
                moved.startAt = start
                moved.endAt = start.addingTimeInterval(block.duration)
                moved.updatedAt = Date()
                mutation = .saveTimeBlock(before: block, after: moved)
            case .moveToAnotherDay:
                var values: [PlanMutation] = []
                if let task = targetTask,
                   let date = selectedDay.startDate(calendar: calendar),
                   let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
                    var metadata = task.metadata
                    metadata.planningDay = PlanningDay(date: tomorrow, timeZone: calendar.timeZone, calendar: calendar)
                    metadata.updatedAt = Date()
                    values.append(.saveTaskMetadata(before: task.metadata, after: metadata))
                }
                if let block = targetBlock {
                    var moved = block
                    moved.startAt = calendar.date(byAdding: .day, value: 1, to: block.startAt) ?? block.startAt.addingTimeInterval(86_400)
                    moved.endAt = calendar.date(byAdding: .day, value: 1, to: block.endAt) ?? block.endAt.addingTimeInterval(86_400)
                    moved.updatedAt = Date()
                    values.append(.saveTimeBlock(before: block, after: moved))
                }
                mutation = .batch(values)
            case .split:
                guard let block = targetBlock, block.duration >= 30 * 60 else { mutation = .batch([]); break }
                let midpoint = block.startAt.addingTimeInterval(block.duration / 2)
                var first = block
                first.endAt = midpoint
                first.updatedAt = Date()
                let second = InternalTimeBlock(
                    title: block.title, startAt: midpoint, endAt: block.endAt,
                    taskID: block.taskID, planningContext: block.planningContext, isFixed: block.isFixed
                )
                mutation = .batch([.saveTimeBlock(before: block, after: first), .saveTimeBlock(before: nil, after: second)])
            case .defer:
                guard let task = targetTask else { mutation = .batch([]); break }
                var metadata = task.metadata
                metadata.planningDay = nil
                metadata.unscheduledDisposition = .inbox
                metadata.updatedAt = Date()
                mutation = .saveTaskMetadata(before: task.metadata, after: metadata)
            case .leaveUnchanged:
                mutation = .batch([])
            case .askEva:
                return
            }
            try await commit(mutation, source: source, summary: "Plan repair: \(action.rawValue)")
            if action == .resume, let taskID = proposal.taskID {
                await startFocus(taskID: taskID, timeBlockID: proposal.timeBlockID, targetDuration: targetBlock?.duration ?? targetTask?.estimatedDuration ?? 25 * 60)
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func createBlock(title: String, start: Date, duration: TimeInterval, taskID: UUID? = nil) async {
        let value = InternalTimeBlock(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Focus block" : title,
            startAt: start,
            endAt: start.addingTimeInterval(max(15 * 60, duration)),
            taskID: taskID
        )
        do {
            try await commit(.saveTimeBlock(before: nil, after: value), source: "plan.block", summary: "Created \(value.title)")
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func resizeBlock(_ block: InternalTimeBlock, minutesDelta: Int) async {
        var value = block
        value.endAt = max(value.startAt.addingTimeInterval(15 * 60), value.endAt.addingTimeInterval(TimeInterval(minutesDelta * 60)))
        value.updatedAt = Date()
        do {
            try await commit(.saveTimeBlock(before: block, after: value), source: "plan.block", summary: "Resized \(block.title)")
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func moveBlock(_ block: InternalTimeBlock, minutesDelta: Int) async {
        var value = block
        let delta = TimeInterval(minutesDelta * 60)
        value.startAt = block.startAt.addingTimeInterval(delta)
        value.endAt = block.endAt.addingTimeInterval(delta)
        value.updatedAt = Date()
        do {
            try await commit(.saveTimeBlock(before: block, after: value), source: "plan.block", summary: "Moved \(block.title)")
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func splitBlock(_ block: InternalTimeBlock) async {
        guard block.duration >= 30 * 60 else { return }
        let midpoint = block.startAt.addingTimeInterval(block.duration / 2)
        var first = block
        first.endAt = midpoint
        first.updatedAt = Date()
        let second = InternalTimeBlock(
            title: block.title,
            startAt: midpoint,
            endAt: block.endAt,
            taskID: block.taskID,
            planningContext: block.planningContext,
            isFixed: block.isFixed
        )
        do {
            try await commit(
                .batch([
                    .saveTimeBlock(before: block, after: first),
                    .saveTimeBlock(before: nil, after: second)
                ]),
                source: "plan.block",
                summary: "Split \(block.title)"
            )
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteBlock(_ block: InternalTimeBlock) async {
        do {
            try await commit(.deleteTimeBlock(block), source: "plan.block", summary: "Removed \(block.title)")
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func task(for id: UUID) -> PlanningTaskSummary? { tasks.first { $0.id == id } }
    func plannedTasks(on day: PlanningDay) -> [PlanningTaskSummary] {
        tasks.filter {
            $0.metadata.unscheduledDisposition != .deleted
                && $0.metadata.planningDay == day
                && $0.metadata.availability == .actionable
        }
    }

    func undoLastMutation() async {
        guard let receiptID = lastMutationReceiptID else { return }
        do {
            try await planningRepository.undo(receiptID: receiptID)
            normalizedEvents = normalizedEvents.map { event in
                guard event.receipt?.receiptID == receiptID else { return event }
                var reversed = event
                reversed.reversal = .reversed(receiptID: receiptID)
                return reversed
            }
            lastMutationReceiptID = nil
            backlogDeletionUndoState = nil
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func startFocus(taskID: UUID?, timeBlockID: UUID?, targetDuration: TimeInterval) async {
        do {
            activeFocusSession = try await planningRepository.start(
                taskID: taskID,
                timeBlockID: timeBlockID,
                targetDuration: targetDuration,
                at: Date()
            )
            if let activeFocusSession {
                normalizedEvents.append(NormalizedLifeEventProjector().event(
                    sourceID: activeFocusSession.id,
                    domain: "focus",
                    kind: "started",
                    occurredAt: activeFocusSession.startedAt,
                    numericValue: activeFocusSession.targetDuration,
                    provenance: "LifeBoard Focus session",
                    evidenceDisplay: focusTitle(for: activeFocusSession)
                ))
                await synchronizeFocusPresentation(activeFocusSession)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func pauseFocus() async { await sendFocusCommand(.pause) }
    func resumeFocus() async { await sendFocusCommand(.resume) }
    func endFocus(outcome: FocusCompletionOutcome) async { await sendFocusCommand(.end(outcome)) }

    private func sendFocusCommand(_ kind: FocusSessionCommandKind) async {
        guard let session = activeFocusSession else { return }
        do {
            let command = FocusSessionCommand(sessionID: session.id, kind: kind, occurredAt: Date())
            let updated = try await planningRepository.handle(command)
            let eventKind: String = switch kind {
            case .pause: "paused"
            case .resume: "resumed"
            case .end(let outcome): "ended_\(outcome.rawValue)"
            }
            normalizedEvents.append(NormalizedLifeEventProjector().event(
                sourceID: updated.id,
                domain: "focus",
                kind: eventKind,
                occurredAt: command.occurredAt,
                numericValue: updated.focusedDuration(at: command.occurredAt),
                provenance: "LifeBoard Focus command",
                evidenceDisplay: focusTitle(for: updated),
                receipt: .init(receiptID: command.id, summary: eventKind.replacingOccurrences(of: "_", with: " "))
            ))
            await synchronizeFocusPresentation(updated)
            activeFocusSession = updated.state == .ended ? nil : updated
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    private func synchronizeFocusPresentation(_ session: FocusSessionV2) async {
        let title = focusTitle(for: session)
        let liveActivitiesAvailable = await FocusLiveActivityCoordinator.shared.synchronize(
            session: session,
            title: title
        )
        await FocusNotificationFallbackCoordinator.shared.synchronize(
            session: session,
            title: title,
            liveActivitiesAvailable: liveActivitiesAvailable
        )
    }

    private func rebuildSnapshots() {
        let visibleTasks = tasks.filter { $0.metadata.unscheduledDisposition != .deleted }
        daySnapshot = makeDaySnapshot(for: selectedDay)
        let weekDays = daysInWeek(containing: selectedDay)
        weekSnapshot = PlanWeekSnapshot(
            days: weekDays.map { day in
                let snapshot = makeDaySnapshot(for: day)
                return PlanWeekDaySummary(
                    day: day,
                    capacity: snapshot.capacity,
                    mustDoCount: snapshot.plannedTasks.filter { $0.metadata.commitmentLevel == .mustDo }.count,
                    deadlineCount: snapshot.plannedTasks.filter { task in
                        guard let due = task.dueDate, let end = dayEnd(day) else { return false }
                        return due < end
                    }.count
                )
            },
            unplannedTasks: visibleTasks.filter {
                $0.metadata.planningDay == nil && $0.metadata.unscheduledDisposition != .archived
            },
            generatedAt: Date()
        )
        backlogSnapshot = PlanBacklogSnapshot(groups: backlogGroups(), generatedAt: Date())
        repairProposals = daySnapshot.map { repairService.proposals(for: $0, now: Date()) } ?? []
    }

    private func makeDaySnapshot(for day: PlanningDay) -> PlanDaySnapshot {
        let bounds = dayBounds(day)
        let externalCommitments = externalCommitments(for: bounds)
        let blocks = allBlocks.filter { $0.startAt < bounds.end && $0.endAt > bounds.start }
        let planned = tasks.filter {
            $0.metadata.unscheduledDisposition != .deleted
                && $0.metadata.planningDay == day
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
        let occupied = externalCommitments.map { DateInterval(start: $0.startAt, end: $0.endAt) }
            + blocks.map { DateInterval(start: $0.startAt, end: $0.endAt) }
        return PlanDaySnapshot(
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
            freeWindows: FreeWindowService.calculate(workingIntervals: working, occupiedIntervals: occupied),
            blocks: blocks,
            plannedTasks: planned,
            unscheduledTasks: tasks.filter {
                $0.metadata.planningDay == nil
                    && $0.metadata.availability == .actionable
                    && $0.metadata.unscheduledDisposition == .inbox
            },
            generatedAt: Date()
        )
    }

    private func backlogGroups() -> [BacklogGroup: [PlanningTaskSummary]] {
        let start = calendar.startOfDay(for: Date())
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let nextWeekEnd = calendar.date(byAdding: .day, value: 14, to: start) ?? weekEnd
        var groups = Dictionary(uniqueKeysWithValues: BacklogGroup.allCases.map { ($0, [PlanningTaskSummary]()) })
        for task in tasks {
            guard task.metadata.unscheduledDisposition != .deleted else { continue }
            if task.metadata.availability == .waiting { groups[.waiting, default: []].append(task); continue }
            if task.metadata.availability == .paused { groups[.paused, default: []].append(task); continue }
            guard let date = task.metadata.planningDay?.startDate(calendar: calendar) else {
                let group: BacklogGroup = switch task.metadata.unscheduledDisposition {
                case .inbox: .inbox
                case .someday: .someday
                case .archived: .archived
                case .deleted: .inbox // Filtered by the tombstone guard above.
                }
                groups[group, default: []].append(task)
                continue
            }
            if date < weekEnd { groups[.thisWeek, default: []].append(task) }
            else if date < nextWeekEnd { groups[.nextWeek, default: []].append(task) }
            else { groups[.later, default: []].append(task) }
        }
        return groups
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

    private func safeCalendarContext(from: Date, to: Date) async -> PlanningCalendarContext {
        do {
            return try await calendarRepository.fetchCommitments(from: from, to: to)
        } catch {
            return PlanningCalendarContext(authorization: await calendarRepository.authorization())
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

    private func dayEnd(_ day: PlanningDay) -> Date? { dayBounds(day).end }

    private func daysInWeek(containing day: PlanningDay) -> [PlanningDay] {
        guard let date = day.startDate(calendar: calendar),
              let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [day] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start).map {
                PlanningDay(date: $0, timeZone: calendar.timeZone, calendar: calendar)
            }
        }
    }

    private func weekBounds(containing day: PlanningDay) -> (start: Date, end: Date) {
        let days = daysInWeek(containing: day)
        let start = days.first?.startDate(calendar: calendar) ?? calendar.startOfDay(for: Date())
        return (start, calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(604_800))
    }

    private static func defaultWorkingProfile() -> WorkingHoursProfile {
        var intervals: [Int: [WorkingHoursInterval]] = [:]
        for weekday in 2...6 { intervals[weekday] = [.init(startMinute: 8 * 60, endMinute: 18 * 60)] }
        intervals[1] = [.init(startMinute: 9 * 60, endMinute: 14 * 60)]
        intervals[7] = [.init(startMinute: 9 * 60, endMinute: 14 * 60)]
        return WorkingHoursProfile(name: "LifeBoard default", intervalsByWeekday: intervals, bufferDuration: 30 * 60)
    }

    @discardableResult
    private func commit(_ mutation: PlanMutation, source: String, summary: String) async throws -> UUID {
        let receipt = try await planningRepository.prepare(mutation, source: source, summary: summary)
        try await planningRepository.apply(receiptID: receipt.id)
        lastMutationReceiptID = receipt.id
        backlogDeletionUndoState = nil
        normalizedEvents.append(NormalizedLifeEventProjector().event(
            sourceID: sourceID(for: mutation),
            domain: "plan",
            kind: source,
            occurredAt: receipt.createdAt,
            provenance: "LifeBoard planning mutation",
            evidenceDisplay: summary,
            receipt: .init(receiptID: receipt.id, summary: summary),
            reversal: .reversible(receiptID: receipt.id)
        ))
        return receipt.id
    }

    private func sourceID(for mutation: PlanMutation) -> UUID {
        switch mutation {
        case .saveTaskMetadata(_, let after): after.taskID
        case .saveTimeBlock(_, let after): after.id
        case .deleteTimeBlock(let value): value.id
        case .batch(let values): values.first.map(sourceID(for:)) ?? UUID()
        }
    }

    private func suppressAcknowledgedRepairs(_ values: [PlanRepairProposal]) async throws -> [PlanRepairProposal] {
        var visible: [PlanRepairProposal] = []
        for value in values {
            if try await planningRepository.hasAppliedReceipt(source: repairReceiptSource(value.id)) == false {
                visible.append(value)
            }
        }
        return visible
    }

    private func repairReceiptSource(_ id: UUID) -> String { "plan.repair.\(id.uuidString)" }

    private func repairTaskOrder(_ lhs: PlanningTaskSummary, _ rhs: PlanningTaskSummary) -> Bool {
        if lhs.metadata.commitmentLevel != rhs.metadata.commitmentLevel {
            return lhs.metadata.commitmentLevel == .mustDo
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func focusTitle(for session: FocusSessionV2) -> String {
        if let taskID = session.taskID, let title = task(for: taskID)?.title { return title }
        if let blockID = session.timeBlockID, let title = allBlocks.first(where: { $0.id == blockID })?.title { return title }
        return "Focus session"
    }
}
