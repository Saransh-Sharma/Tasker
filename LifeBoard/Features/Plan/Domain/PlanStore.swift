import Foundation
import Observation

enum PlanLens: String, CaseIterable, Identifiable, Codable, Sendable {
    /// First because triage precedes planning: deciding what a capture *is*
    /// comes before deciding when to do it.
    case inbox = "Inbox"
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
    private(set) var focusCompanion: FocusSessionCompanion?
    private(set) var pendingFocusReflection: FocusExecutionReceipt?
    private(set) var focusCommitPhase: AsyncActionPhase<FocusExecutionReceipt> = .idle
    private(set) var focusReflectionCommitPhase: AsyncActionPhase<FocusExecutionReceipt> = .idle
    private(set) var normalizedEvents: [NormalizedLifeEvent] = []
    private(set) var lastMutationReceiptID: UUID?
    private(set) var backlogDeletionUndoState: BacklogDeletionUndoState?
    private(set) var pendingScenario: PlanningScenario?
    private(set) var scenarioRefreshResult: PlanningScenarioRefreshResult?
    private(set) var minimumViableDaySelection = MinimumViableDaySelection()
    private(set) var calibrationSuggestions: [UUID: EstimateCalibrationSuggestion] = [:]
    private(set) var calendarState: PlanningCalendarState = .notRequested
    private(set) var isLoading = false
    /// Set when a reload is requested while one is already running. See `load()`.
    private var hasPendingReload = false
    var errorMessage: String?
    var selectedDay: PlanningDay

    private let planningRepository: any PlanningRepository & PlanningProjectionRepository & PlanningMutationRepository & FocusExecutionCoordinator
    private let blockRepository: any InternalTimeBlockRepository
    private let calendarRepository: any PlanningCalendarContextRepository
    private let repairService: any PlanRepairService
    private let scenarioCoordinator: (any PlanningScenarioCoordinating)?
    private let focusCompanionStore: FocusSessionCompanionStore
    private let focusCommands: FocusSessionCommands?
    private let taskDefinitionRepository: (any TaskDefinitionRepositoryProtocol)?
    private var allBlocks: [InternalTimeBlock] = []
    private(set) var workingProfile: WorkingHoursProfile?
    private var calendarContext = PlanningCalendarContext(authorization: .notDetermined)
    private var hasCalendarCache = false
    private var calendar: Calendar
    private var pendingRepairSelection: (
        proposal: PlanRepairProposal,
        action: PlanRepairAction
    )?
    private var pendingMultiItemSelection: (
        taskIDs: Set<UUID>,
        day: PlanningDay
    )?

    init(
        planningRepository: any PlanningRepository & PlanningProjectionRepository & PlanningMutationRepository & FocusExecutionCoordinator,
        blockRepository: any InternalTimeBlockRepository,
        calendarRepository: any PlanningCalendarContextRepository = SystemPlanningCalendarContextRepository(),
        repairService: any PlanRepairService = DeterministicPlanRepairService(),
        scenarioCoordinator: (any PlanningScenarioCoordinating)? = nil,
        taskDefinitionRepository: (any TaskDefinitionRepositoryProtocol)? = nil,
        focusCompanionStore: FocusSessionCompanionStore = .shared,
        focusCommands: FocusSessionCommands? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.planningRepository = planningRepository
        self.blockRepository = blockRepository
        self.calendarRepository = calendarRepository
        self.repairService = repairService
        self.scenarioCoordinator = scenarioCoordinator
        self.taskDefinitionRepository = taskDefinitionRepository
        self.focusCompanionStore = focusCompanionStore
        self.focusCommands = focusCommands
        self.calendar = calendar
        selectedDay = PlanningDay(date: now, timeZone: calendar.timeZone, calendar: calendar)
    }

    func previewMinimumViableDay(
        selection: MinimumViableDaySelection? = nil
    ) {
        guard let daySnapshot else { return }
        if let selection {
            minimumViableDaySelection = selection
        }
        pendingRepairSelection = nil
        pendingMultiItemSelection = nil
        pendingScenario = MinimumViableDayScenarioBuilder.make(
            from: daySnapshot,
            selection: minimumViableDaySelection
        )
        scenarioRefreshResult = nil
    }

    func dismissScenario() {
        pendingScenario = nil
        scenarioRefreshResult = nil
        minimumViableDaySelection = .init()
        pendingRepairSelection = nil
        pendingMultiItemSelection = nil
    }

    func applyPendingScenario() async {
        guard let pendingScenario, let scenarioCoordinator else { return }
        guard pendingScenario.isReadyToApply else {
            errorMessage = pendingScenario.validationIssues.joined(separator: " ")
            return
        }
        do {
            let repairSelection = pendingRepairSelection
            let receipt = try await scenarioCoordinator.apply(pendingScenario)
            lastMutationReceiptID = receipt.id
            self.pendingScenario = nil
            scenarioRefreshResult = nil
            pendingRepairSelection = nil
            pendingMultiItemSelection = nil
            if repairSelection?.action == .resume {
                let proposal = repairSelection?.proposal
                let targetTask = proposal?.taskID.flatMap(task(for:))
                    ?? daySnapshot?.plannedTasks.sorted(by: repairTaskOrder).last
                let targetBlock = proposal?.timeBlockID.flatMap { id in
                    allBlocks.first { $0.id == id }
                }
                if let proposal {
                    await startFocus(
                        taskID: proposal.taskID ?? targetTask?.id,
                        timeBlockID: proposal.timeBlockID,
                        targetDuration: targetBlock?.duration
                            ?? targetTask?.estimatedDuration
                            ?? 25 * 60
                    )
                }
            }
            await load()
        } catch PlanningScenarioApplyError.versionConflict(let changedRecordIDs) {
            let original = pendingScenario
            await load()
            guard let refreshed = rebuildScenario(original, snapshot: daySnapshot) else {
                errorMessage = "Your plan changed while this preview was open. Rebuild the proposal and review it again."
                self.pendingScenario = nil
                return
            }
            scenarioRefreshResult = PlanningScenarioRefreshResult(
                source: original.source,
                changedRecordIDs: changedRecordIDs,
                previousDiff: original.diff,
                refreshedScenario: refreshed
            )
            self.pendingScenario = refreshed
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reloads canonical state, coalescing concurrent requests.
    ///
    /// This used to be `guard isLoading == false else { return }`, which
    /// *dropped* the second request rather than deferring it. Every mutation
    /// here is `commit` followed by `await load()`, so two quick taps meant the
    /// second reload silently no-opped and `tasks` stayed stale — and the next
    /// write then committed a stale `before`. `saveTaskMetadata` applies every
    /// field of `after`, so that is a full-record overwrite: it silently
    /// reverts whatever the dropped reload would have picked up, and its undo
    /// payload restores values that were never current.
    ///
    /// A request that arrives mid-flight now marks the pass dirty and the loop
    /// runs again. Callers still get "the store is current when this returns",
    /// which is the contract every mutation depends on.
    func load() async {
        if isLoading {
            hasPendingReload = true
            return
        }
        isLoading = true
        defer { isLoading = false }
        repeat {
            hasPendingReload = false
            await performLoad()
        } while hasPendingReload
    }

    private func performLoad() async {
        calendarState = .loading
        do {
            let bounds = weekBounds(containing: selectedDay)
            async let fetchedTasks = planningRepository.fetchOpenPlanningTasks()
            async let fetchedBlocks = blockRepository.fetchTimeBlocks(from: bounds.start, to: bounds.end)
            async let profiles = blockRepository.fetchWorkingHoursProfiles()
            async let fetchedCalendarResult = safeCalendarContext(
                from: bounds.start,
                to: bounds.end,
                cached: calendarContext,
                hasCache: hasCalendarCache
            )
            async let focusHistory = planningRepository.sessions(
                since: Calendar.current.date(
                    byAdding: .day,
                    value: -180,
                    to: Date()
                )
            )
            tasks = try await fetchedTasks
            let completedFocusHistory = try await focusHistory
            if let focusCommands {
                let recovery = try await focusCommands.activeRecovery()
                activeFocusSession = recovery?.session
                focusCompanion = recovery?.companion
            } else {
                activeFocusSession = try await planningRepository.activeSession()
                if let activeFocusSession {
                    focusCompanion = try? await focusCompanionStore.companion(sessionID: activeFocusSession.id)
                } else {
                    focusCompanion = nil
                }
            }
            if let session = activeFocusSession,
               let repair = FocusStartupRepairPolicy.commandKind(for: session, now: Date()) {
                if let focusCommands, repair == .pause {
                    let recovery = try await focusCommands.pause(sessionID: session.id)
                    activeFocusSession = recovery.session
                    focusCompanion = recovery.companion
                } else {
                    let repaired = try await planningRepository.handle(.init(
                        sessionID: session.id,
                        kind: repair,
                        occurredAt: Date()
                    ))
                    activeFocusSession = repaired.state == .ended ? nil : repaired
                }
            }
            await FocusLiveActivityCoordinator.shared.endOrphanedActivities(except: activeFocusSession?.id)
            if let activeFocusSession {
                await synchronizeFocusPresentation(activeFocusSession)
            } else {
                await FocusNotificationFallbackCoordinator.shared.cancelAll()
            }
            allBlocks = try await fetchedBlocks
            let availableProfiles = try await profiles
            let calendarResult = await fetchedCalendarResult
            calendarContext = calendarResult.context
            calendarState = calendarResult.state
            if case .fresh = calendarResult.state {
                hasCalendarCache = true
            }
            if let selected = availableProfiles.first(where: \.isDefault) ?? availableProfiles.first {
                workingProfile = selected
            } else {
                let profile = Self.defaultWorkingProfile()
                try await blockRepository.saveWorkingHoursProfile(profile)
                workingProfile = profile
            }
            rebuildSnapshots()
            rebuildCalibrationSuggestions(from: completedFocusHistory)
            repairProposals = try await suppressAcknowledgedRepairs(repairProposals)
            errorMessage = nil
        } catch {
            if case .loading = calendarState {
                calendarState = .failed(message: error.localizedDescription)
            }
            errorMessage = error.localizedDescription
        }
    }

    func requestCalendarAccess() async {
        calendarState = .loading
        _ = await calendarRepository.requestAccess()
        await load()
    }

    func select(day: PlanningDay) async {
        selectedDay = day
        // Staying inside the loaded week needs no repository round-trip:
        // `makeDaySnapshot` is pure over `tasks`, `allBlocks`, `calendarContext`
        // and `workingProfile`, all of which `load()` already fetched for the
        // whole week. Reloading here would put a Core Data + EventKit round-trip
        // behind every tap of a day chip in the weekly ribbon.
        if weekSnapshot?.days.contains(where: { $0.day == day }) == true {
            retargetDaySnapshot()
            return
        }
        await load()
    }

    /// Re-points `daySnapshot` at `selectedDay` without reloading.
    ///
    /// `daySnapshot` stays a stored property rather than becoming computed:
    /// `previewMinimumViableDay`, `repairProposals` and the Day lens all read it
    /// and depend on its nil-semantics.
    private func retargetDaySnapshot() {
        daySnapshot = makeDaySnapshot(for: selectedDay)
        repairProposals = daySnapshot.map { repairService.proposals(for: $0, now: Date()) } ?? []
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

    /// Completes or reopens a task.
    ///
    /// The Foundation shell had no completion path at all: every task row drew a
    /// decorative `circle` glyph, so the most repeated action in the product was
    /// only reachable from widgets, notifications, Eva and routine steps. This
    /// routes through the same prepare/apply receipt as every other planning
    /// mutation, so a completion is undoable with `undoLastMutation()` rather
    /// than being a one-way write.
    ///
    /// `tasks` is sourced from `fetchOpenPlanningTasks()`, which filters on
    /// `isComplete == NO`, so a completed row leaves the list on reload. The
    /// caller animates that removal; the store does not delay the write for it.
    func setCompletion(_ task: PlanningTaskSummary, to isComplete: Bool) async {
        do {
            _ = try await commit(
                .setTaskCompletion(taskID: task.id, before: !isComplete, after: isComplete),
                source: "plan.task.completion",
                summary: isComplete ? "Completed \(task.title)" : "Reopened \(task.title)"
            )
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func previewBulkPlan(_ taskIDs: Set<UUID>, on day: PlanningDay) {
        guard let scenario = multiItemScenario(taskIDs: taskIDs, day: day) else {
            return
        }
        pendingRepairSelection = nil
        pendingMultiItemSelection = (taskIDs, day)
        pendingScenario = scenario
        scenarioRefreshResult = nil
    }

    private func multiItemScenario(
        taskIDs: Set<UUID>,
        day: PlanningDay
    ) -> PlanningScenario? {
        guard let snapshot = daySnapshot, taskIDs.isEmpty == false else { return nil }
        let selectedTasks = tasks.filter { taskIDs.contains($0.id) }
        guard selectedTasks.count == taskIDs.count else { return nil }
        let values = selectedTasks.map { task -> PlanningTaskMetadata in
            var metadata = task.metadata
            metadata.planningDay = day
            metadata.updatedAt = Date()
            return metadata
        }
        let beforeByID = Dictionary(
            uniqueKeysWithValues: selectedTasks.map { ($0.id, $0.metadata) }
        )
        let mutations = values.compactMap { after -> PlanMutation? in
            guard let before = beforeByID[after.taskID] else { return nil }
            return .saveTaskMetadata(before: before, after: after)
        }
        var preview = snapshot
        applyPreview(.batch(mutations), to: &preview)
        return PlanningScenario(
            source: .multiItemReschedule,
            receiptSource: "plan.bulk",
            touchedRecords: selectedTasks.map {
                PlanningTouchedRecord(
                    kind: "task",
                    recordID: $0.id,
                    version: $0.metadata.updatedAt
                )
            },
            proposedMutations: mutations,
            diff: selectedTasks.map {
                PlanningScenarioDiff(
                    title: $0.title,
                    before: $0.metadata.planningDay.map(Self.dayLabel) ?? "Unscheduled",
                    after: Self.dayLabel(day)
                )
            },
            preview: preview,
            validationIssues: mutations.isEmpty
                ? ["Choose at least one task to reschedule."]
                : []
        )
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

    func previewRepair(_ proposal: PlanRepairProposal, action: PlanRepairAction) {
        guard action != .askEva else { return }
        guard let scenario = repairScenario(proposal, action: action) else { return }
        pendingRepairSelection = (proposal, action)
        pendingMultiItemSelection = nil
        pendingScenario = scenario
        scenarioRefreshResult = nil
    }

    func acceptCalibration(_ suggestion: EstimateCalibrationSuggestion) async {
        guard let taskDefinitionRepository else {
            errorMessage = "Task estimates are unavailable right now."
            return
        }
        do {
            guard var task = try await withCheckedThrowingContinuation({
                (continuation: CheckedContinuation<TaskDefinition?, any Error>) in
                taskDefinitionRepository.fetchTaskDefinition(id: suggestion.taskID) {
                    continuation.resume(with: $0)
                }
            }) else {
                errorMessage = "The task changed before its estimate could be updated."
                return
            }
            task.estimatedDuration = suggestion.suggestedDuration
            task.updatedAt = Date()
            _ = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<TaskDefinition, any Error>) in
                taskDefinitionRepository.update(task) {
                    continuation.resume(with: $0)
                }
            }
            calibrationSuggestions.removeValue(forKey: suggestion.taskID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
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
        await resizeBlockEdges(block, startMinutesDelta: 0, endMinutesDelta: minutesDelta)
    }

    func resizeBlockEdges(
        _ block: InternalTimeBlock,
        startMinutesDelta: Int,
        endMinutesDelta: Int
    ) async {
        var value = block
        let proposedStart = value.startAt.addingTimeInterval(TimeInterval(startMinutesDelta * 60))
        let proposedEnd = value.endAt.addingTimeInterval(TimeInterval(endMinutesDelta * 60))
        guard proposedEnd.timeIntervalSince(proposedStart) >= 15 * 60 else { return }
        value.startAt = proposedStart
        value.endAt = proposedEnd
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

    // MARK: Weekly workspace access
    //
    // `PlanStore+WeeklyWorkspace` lives in its own file to keep this one from
    // growing another feature's worth of methods. These four expose exactly
    // what it needs — the calendar, the commit path, the calendar cache, and
    // the task writer — rather than loosening the visibility of the stored
    // properties themselves.

    var workspaceCalendar: Calendar { calendar }

    var workspaceTaskRepository: (any TaskDefinitionRepositoryProtocol)? { taskDefinitionRepository }

    func workspaceCommitments(from start: Date, to end: Date) -> [CalendarCommitment] {
        externalCommitments(for: (start: start, end: end))
    }

    /// Open windows on any day of the loaded week.
    ///
    /// Computed on demand rather than read off `daySnapshot`. `daySnapshot` is
    /// only rebuilt by `load()`, so a surface that lets you change days without
    /// reloading — which is the whole point of the week ribbon — would ask it
    /// about Thursday and be answered about whatever day was loaded last. The
    /// workspace's time-boxing silently disappeared for every day but one, and
    /// came back only after an unrelated write happened to reload the store.
    func workspaceFreeWindows(
        on day: PlanningDay,
        skippingCommitmentIDs: Set<String> = []
    ) -> [FreeWindow] {
        let bounds = dayBounds(day)
        let commitments = externalCommitments(for: bounds)
            .filter { skippingCommitmentIDs.contains($0.id) == false }
        let blocks = allBlocks.filter { $0.startAt < bounds.end && $0.endAt > bounds.start }
        let occupied = commitments.map { DateInterval(start: $0.startAt, end: $0.endAt) }
            + blocks.map { DateInterval(start: $0.startAt, end: $0.endAt) }
        return FreeWindowService.calculate(
            workingIntervals: workingIntervals(for: day),
            occupiedIntervals: occupied
        )
    }

    /// A day's capacity with some meetings treated as not happening.
    ///
    /// The workspace used to model "I'm skipping this" by *adding the meeting's
    /// raw duration back* to `usableDuration`. That invents time:
    /// `CapacityBudgetService` subtracts commitments **clipped to working hours
    /// and unioned**, so a 07:00–09:00 meeting under 08:00–18:00 hours only ever
    /// cost 60 usable minutes, while crediting its raw duration handed back 120.
    /// Two overlapping meetings double-credited, and an overnight event — which
    /// overlaps two days — credited its whole length to both.
    ///
    /// Recomputing through the same service with the skipped commitments removed
    /// is the only way for the credit and the charge to agree by construction.
    func workspaceCapacity(
        on day: PlanningDay,
        skippingCommitmentIDs: Set<String> = []
    ) -> CapacityBudget {
        let bounds = dayBounds(day)
        let commitments = externalCommitments(for: bounds)
            .filter { skippingCommitmentIDs.contains($0.id) == false }
        let blocks = allBlocks.filter { $0.startAt < bounds.end && $0.endAt > bounds.start }
        let planned = tasks.filter {
            $0.metadata.unscheduledDisposition != .deleted
                && $0.metadata.planningDay == day
                && $0.metadata.availability == .actionable
        }
        return CapacityBudgetService.calculate(
            workingIntervals: workingIntervals(for: day),
            fixedCalendarCommitments: commitments.map { DateInterval(start: $0.startAt, end: $0.endAt) },
            internalFixedBlocks: blocks.filter(\.isFixed).map { DateInterval(start: $0.startAt, end: $0.endAt) },
            userBuffer: workingProfile?.bufferDuration ?? 30 * 60,
            plannedEstimates: planned.map(\.estimatedDuration)
        )
    }

    @discardableResult
    func workspaceCommit(
        _ mutation: PlanMutation,
        source: String,
        summary: String
    ) async throws -> UUID {
        try await commit(mutation, source: source, summary: summary)
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

    func startFocus(
        taskID: UUID?,
        timeBlockID: UUID?,
        targetDuration: TimeInterval,
        mode: FocusMode? = nil,
        intention: String = "",
        subtaskID: UUID? = nil
    ) async {
        focusCommitPhase = .idle
        focusReflectionCommitPhase = .idle
        do {
            let resolvedMode = mode ?? .countdown(duration: targetDuration)
            if let focusCommands {
                let recovery = try await focusCommands.start(.init(
                    taskID: taskID,
                    timeBlockID: timeBlockID,
                    mode: resolvedMode,
                    intention: intention,
                    subtaskID: subtaskID
                ))
                activeFocusSession = recovery.session
                // The same action taken by voice donates itself; taken in-app it
                // would otherwise be invisible to Siri and Spotlight.
                IntentDonations.focusSessionStarted()
                focusCompanion = recovery.companion
            } else {
                activeFocusSession = try await planningRepository.start(
                    taskID: taskID,
                    timeBlockID: timeBlockID,
                    targetDuration: targetDuration,
                    at: Date()
                )
            }
            if let activeFocusSession {
                if focusCommands == nil {
                    let companion = FocusSessionCompanion(
                        sessionID: activeFocusSession.id,
                        mode: resolvedMode,
                        intention: intention,
                        subtaskID: subtaskID
                    )
                    try await focusCompanionStore.save(companion)
                    focusCompanion = companion
                }
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
    func endFocus(outcome: FocusCompletionOutcome) async {
        guard activeFocusSession != nil else { return }
        focusCommitPhase = .running(progress: nil)
        let sessionID = activeFocusSession?.id
        let succeeded = await sendFocusCommand(.end(outcome))
        if succeeded, let sessionID {
            try? await focusCompanionStore.markCompleted(sessionID: sessionID)
        }
        if succeeded, let receipt = pendingFocusReflection {
            focusCommitPhase = .success(receipt: receipt)
        } else if succeeded == false {
            focusCommitPhase = .recoverableFailure(.init(
                message: errorMessage ?? "Focus could not be ended.",
                recovery: .retry
            ))
        }
    }

    func saveFocusReflection(energy: Int?, note: String?) async {
        guard let pendingFocusReflection else { return }
        focusReflectionCommitPhase = .running(progress: nil)
        do {
            let saved: FocusExecutionReceipt
            if let focusCommands {
                saved = try await focusCommands.saveReflection(
                    sessionID: pendingFocusReflection.sessionID,
                    energyAfter: energy,
                    note: note
                )
            } else {
                _ = try await planningRepository.updateReflection(
                    sessionID: pendingFocusReflection.sessionID,
                    energyAfter: energy,
                    reflection: note
                )
                var persistedReceipt = pendingFocusReflection
                persistedReceipt.energyAfter = energy
                persistedReceipt.reflection = note
                saved = persistedReceipt
            }
            focusReflectionCommitPhase = .success(receipt: saved)
            self.pendingFocusReflection = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
            focusReflectionCommitPhase = .recoverableFailure(.init(
                message: error.localizedDescription,
                recovery: .retry
            ))
        }
    }

    func dismissFocusReflection() {
        pendingFocusReflection = nil
    }

    func advancePomodoro() async {
        guard let sessionID = activeFocusSession?.id, let focusCommands else { return }
        do {
            focusCompanion = try await focusCommands.advancePomodoro(sessionID: sessionID)
        } catch FocusSessionCommandError.pomodoroComplete {
            await endFocus(outcome: .completed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recordInterruption(reason: String? = nil) async {
        guard let sessionID = activeFocusSession?.id else { return }
        if let focusCommands {
            do {
                let commandID = UUID()
                let recovery = try await focusCommands.pause(
                    sessionID: sessionID,
                    interruptionReason: reason,
                    commandID: commandID
                )
                activeFocusSession = recovery.session
                focusCompanion = recovery.companion
                appendFocusCommandEvent(
                    session: recovery.session,
                    kind: .pause,
                    commandID: commandID,
                    occurredAt: Date()
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }
        focusCompanion = try? await focusCompanionStore.recordInterruption(
            sessionID: sessionID,
            reason: reason
        )
        await pauseFocus()
    }

    @discardableResult
    private func sendFocusCommand(_ kind: FocusSessionCommandKind) async -> Bool {
        guard let session = activeFocusSession else { return false }
        do {
            let occurredAt = Date()
            let commandID = UUID()
            let updated: FocusSessionV2
            if let focusCommands {
                switch kind {
                case .pause:
                    updated = try await focusCommands.pause(
                        sessionID: session.id,
                        at: occurredAt,
                        commandID: commandID
                    ).session
                case .resume:
                    updated = try await focusCommands.resume(
                        sessionID: session.id,
                        at: occurredAt,
                        commandID: commandID
                    ).session
                case .end(let outcome):
                    pendingFocusReflection = try await focusCommands.end(
                        sessionID: session.id,
                        outcome: outcome,
                        at: occurredAt,
                        commandID: commandID
                    )
                    guard let ended = try await planningRepository.session(id: session.id) else {
                        throw FocusSessionCommandError.sessionNotFound(session.id)
                    }
                    updated = ended
                }
            } else {
                updated = try await planningRepository.handle(.init(
                    id: commandID,
                    sessionID: session.id,
                    kind: kind,
                    occurredAt: occurredAt
                ))
                if case .end = kind, let endedAt = updated.endedAt, let outcome = updated.outcome {
                    pendingFocusReflection = .init(
                        id: commandID,
                        sessionID: updated.id,
                        taskID: updated.taskID,
                        timeBlockID: updated.timeBlockID,
                        targetDuration: updated.targetDuration,
                        actualFocusedDuration: updated.focusedDuration(at: endedAt),
                        interruptionCount: updated.interruptionCount,
                        outcome: outcome,
                        energyAfter: updated.energyAfter,
                        reflection: updated.reflection,
                        startedAt: updated.startedAt,
                        endedAt: endedAt
                    )
                }
            }
            appendFocusCommandEvent(
                session: updated,
                kind: kind,
                commandID: commandID,
                occurredAt: occurredAt
            )
            await synchronizeFocusPresentation(updated)
            activeFocusSession = updated.state == .ended ? nil : updated
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func appendFocusCommandEvent(
        session: FocusSessionV2,
        kind: FocusSessionCommandKind,
        commandID: UUID,
        occurredAt: Date
    ) {
        let eventKind: String = switch kind {
        case .pause: "paused"
        case .resume: "resumed"
        case .end(let outcome): "ended_\(outcome.rawValue)"
        }
        normalizedEvents.append(NormalizedLifeEventProjector().event(
            sourceID: session.id,
            domain: "focus",
            kind: eventKind,
            occurredAt: occurredAt,
            numericValue: session.focusedDuration(at: occurredAt),
            provenance: "LifeBoard Focus command",
            evidenceDisplay: focusTitle(for: session),
            receipt: .init(
                receiptID: commandID,
                summary: eventKind.replacingOccurrences(of: "_", with: " ")
            )
        ))
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

    private func rebuildCalibrationSuggestions(from sessions: [FocusSessionV2]) {
        let grouped = Dictionary(
            grouping: sessions.filter {
                $0.state == .ended
                    && $0.outcome == .completed
                    && $0.taskID != nil
                    && $0.focusedDuration() >= 5 * 60
            },
            by: { $0.taskID! }
        )
        calibrationSuggestions = grouped.reduce(into: [:]) { result, entry in
            let (taskID, values) = entry
            if let suggestion = EstimateCalibrationService.suggestion(
                taskID: taskID,
                comparableDurations: values.map { $0.focusedDuration() }
            ) {
                result[taskID] = suggestion
            }
        }
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
        let freeWindows = FreeWindowService.calculate(
            workingIntervals: working,
            occupiedIntervals: occupied
        )
        let unscheduled = tasks.filter {
            $0.metadata.planningDay == nil
                && $0.metadata.availability == .actionable
                && $0.metadata.unscheduledDisposition == .inbox
        }
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
            calendarState: calendarState,
            freeWindows: freeWindows,
            fitsNextCandidates: FitsNextService.candidates(
                tasks: unscheduled,
                windows: freeWindows
            ),
            blocks: blocks,
            plannedTasks: planned,
            unscheduledTasks: unscheduled,
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
                case .reference: .reference
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

    private struct CalendarLoadResult: Sendable {
        let context: PlanningCalendarContext
        let state: PlanningCalendarState
    }

    private func safeCalendarContext(
        from: Date,
        to: Date,
        cached: PlanningCalendarContext,
        hasCache: Bool
    ) async -> CalendarLoadResult {
        let authorization = await calendarRepository.authorization()
        switch authorization {
        case .notDetermined:
            return CalendarLoadResult(
                context: PlanningCalendarContext(authorization: .notDetermined),
                state: .notRequested
            )
        case .denied, .restricted:
            return CalendarLoadResult(
                context: PlanningCalendarContext(authorization: authorization),
                state: .denied
            )
        case .unavailable:
            return CalendarLoadResult(
                context: PlanningCalendarContext(authorization: .unavailable),
                state: .failed(message: "Calendar context is unavailable on this device.")
            )
        case .authorized:
            break
        }

        do {
            let context = try await calendarRepository.fetchCommitments(from: from, to: to)
            return CalendarLoadResult(
                context: context,
                state: .fresh(fetchedAt: context.fetchedAt)
            )
        } catch {
            guard hasCache, cached.authorization == .authorized else {
                return CalendarLoadResult(
                    context: PlanningCalendarContext(authorization: .authorized),
                    state: .failed(message: error.localizedDescription)
                )
            }
            let nsError = error as NSError
            let offline = nsError.domain == NSURLErrorDomain
                && [
                    NSURLErrorNotConnectedToInternet,
                    NSURLErrorNetworkConnectionLost,
                    NSURLErrorDataNotAllowed
                ].contains(nsError.code)
            return CalendarLoadResult(
                context: cached,
                state: offline
                    ? .offlineCached(fetchedAt: cached.fetchedAt)
                    : .staleCached(
                        fetchedAt: cached.fetchedAt,
                        message: error.localizedDescription
                    )
            )
        }
    }

    private func rebuildScenario(
        _ scenario: PlanningScenario,
        snapshot: PlanDaySnapshot?
    ) -> PlanningScenario? {
        guard let snapshot else { return nil }
        switch scenario.source {
        case .minimumViableDay:
            return MinimumViableDayScenarioBuilder.make(
                from: snapshot,
                selection: minimumViableDaySelection
            )
        case .repair:
            guard let pendingRepairSelection else { return nil }
            return repairScenario(
                pendingRepairSelection.proposal,
                action: pendingRepairSelection.action
            )
        case .multiItemReschedule:
            guard let pendingMultiItemSelection else { return nil }
            return multiItemScenario(
                taskIDs: pendingMultiItemSelection.taskIDs,
                day: pendingMultiItemSelection.day
            )
        case .manual:
            return nil
        case .dayClose, .dayOpen:
            // Plan cannot rebuild either ritual: their selections live in the
            // ritual's own store, not here, and inventing a replacement from
            // today's snapshot would apply a decision the person never made.
            // `DayCloseStore` handles its own version conflicts.
            return nil
        }
    }

    private func repairScenario(
        _ proposal: PlanRepairProposal,
        action: PlanRepairAction
    ) -> PlanningScenario? {
        guard let snapshot = daySnapshot else { return nil }
        let targetTask = proposal.taskID.flatMap(task(for:))
            ?? snapshot.plannedTasks.sorted(by: repairTaskOrder).last
        let targetBlock = proposal.timeBlockID.flatMap { id in
            allBlocks.first { $0.id == id }
        } ?? snapshot.blocks.max(by: { $0.duration < $1.duration })
        let mutation = repairMutation(
            action: action,
            targetTask: targetTask,
            targetBlock: targetBlock
        )
        var preview = snapshot
        applyPreview(mutation, to: &preview)
        var touched: [PlanningTouchedRecord] = []
        if let targetTask {
            touched.append(
                PlanningTouchedRecord(
                    kind: "task",
                    recordID: targetTask.id,
                    version: targetTask.metadata.updatedAt
                )
            )
        }
        if let targetBlock {
            touched.append(
                PlanningTouchedRecord(
                    kind: "timeBlock",
                    recordID: targetBlock.id,
                    version: targetBlock.updatedAt
                )
            )
        }
        let permitsEmpty = action == .resume || action == .leaveUnchanged
        let issues = mutationHasEffect(mutation) || permitsEmpty
            ? []
            : ["This repair no longer has a matching task or time block."]
        return PlanningScenario(
            source: .repair,
            receiptSource: repairReceiptSource(proposal.id),
            touchedRecords: touched,
            proposedMutations: [mutation],
            diff: [
                PlanningScenarioDiff(
                    title: "Repair: \(action.rawValue)",
                    before: proposal.explanation,
                    after: repairSummary(action, task: targetTask, block: targetBlock)
                )
            ],
            preview: preview,
            validationIssues: issues
        )
    }

    private func repairMutation(
        action: PlanRepairAction,
        targetTask: PlanningTaskSummary?,
        targetBlock: InternalTimeBlock?
    ) -> PlanMutation {
        switch action {
        case .resume, .leaveUnchanged, .askEva:
            return .batch([])
        case .moveLaterToday:
            guard let block = targetBlock else { return .batch([]) }
            let start = daySnapshot?.freeWindows.first(where: { $0.endAt > Date() })?.startAt
                ?? max(Date(), block.endAt).addingTimeInterval(15 * 60)
            var moved = block
            moved.startAt = start
            moved.endAt = start.addingTimeInterval(block.duration)
            moved.updatedAt = Date()
            return .saveTimeBlock(before: block, after: moved)
        case .moveToAnotherDay:
            var values: [PlanMutation] = []
            if let task = targetTask,
               let date = selectedDay.startDate(calendar: calendar),
               let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
                var metadata = task.metadata
                metadata.planningDay = PlanningDay(
                    date: tomorrow,
                    timeZone: calendar.timeZone,
                    calendar: calendar
                )
                metadata.updatedAt = Date()
                values.append(.saveTaskMetadata(before: task.metadata, after: metadata))
            }
            if let block = targetBlock {
                var moved = block
                moved.startAt = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: block.startAt
                ) ?? block.startAt.addingTimeInterval(86_400)
                moved.endAt = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: block.endAt
                ) ?? block.endAt.addingTimeInterval(86_400)
                moved.updatedAt = Date()
                values.append(.saveTimeBlock(before: block, after: moved))
            }
            return .batch(values)
        case .split:
            guard let block = targetBlock, block.duration >= 30 * 60 else {
                return .batch([])
            }
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
            return .batch([
                .saveTimeBlock(before: block, after: first),
                .saveTimeBlock(before: nil, after: second)
            ])
        case .defer:
            guard let task = targetTask else { return .batch([]) }
            var metadata = task.metadata
            metadata.planningDay = nil
            metadata.unscheduledDisposition = .inbox
            metadata.updatedAt = Date()
            return .saveTaskMetadata(before: task.metadata, after: metadata)
        }
    }

    private func applyPreview(
        _ mutation: PlanMutation,
        to snapshot: inout PlanDaySnapshot
    ) {
        switch mutation {
        case let .saveTaskMetadata(_, after):
            let source = (
                snapshot.plannedTasks + snapshot.unscheduledTasks
            ).first { $0.id == after.taskID }
            guard var task = source else { return }
            task.metadata = after
            snapshot.plannedTasks.removeAll { $0.id == task.id }
            snapshot.unscheduledTasks.removeAll { $0.id == task.id }
            if after.planningDay == snapshot.day {
                snapshot.plannedTasks.append(task)
            } else if after.planningDay == nil {
                snapshot.unscheduledTasks.append(task)
            }
        case let .saveTimeBlock(before, after):
            if let before {
                snapshot.blocks.removeAll { $0.id == before.id }
            }
            snapshot.blocks.append(after)
        case let .deleteTimeBlock(block):
            snapshot.blocks.removeAll { $0.id == block.id }
        case let .batch(values):
            for value in values { applyPreview(value, to: &snapshot) }
        case .setTaskCompletion:
            break
        }
    }

    private func mutationHasEffect(_ mutation: PlanMutation) -> Bool {
        switch mutation {
        case .batch(let values):
            values.contains(where: mutationHasEffect)
        case .saveTaskMetadata, .saveTimeBlock, .deleteTimeBlock, .setTaskCompletion:
            true
        }
    }

    private func repairSummary(
        _ action: PlanRepairAction,
        task: PlanningTaskSummary?,
        block: InternalTimeBlock?
    ) -> String {
        switch action {
        case .resume:
            "Start focus for \(task?.title ?? block?.title ?? "the selected work")"
        case .moveLaterToday:
            "Move \(block?.title ?? "the block") into the next real opening"
        case .moveToAnotherDay:
            "Move the affected work to tomorrow"
        case .split:
            "Split \(block?.title ?? "the block") into two sessions"
        case .defer:
            "Return \(task?.title ?? "the task") to the unscheduled list"
        case .leaveUnchanged:
            "Keep the plan and acknowledge this repair"
        case .askEva:
            "Open Eva without changing the plan"
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

    private static func dayLabel(_ day: PlanningDay) -> String {
        "\(day.year)-\(day.month)-\(day.day)"
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
        case .setTaskCompletion(let taskID, _, _): taskID
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
