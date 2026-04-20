import Foundation

public enum DailyReflectionUseCaseError: LocalizedError {
    case unavailableTarget
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailableTarget:
            return "No open reflection is available right now."
        case .persistenceFailed(let message):
            return message
        }
    }
}

public struct SaveDailyReflectionAndPlanResult {
    public let target: DailyReflectionTarget
    public let reflectionPayload: ReflectionPayload?
    public let planDraft: DailyPlanDraft?
    public let xpResult: XPEventResult
    public let preservedExistingManualDraft: Bool

    public init(
        target: DailyReflectionTarget,
        reflectionPayload: ReflectionPayload?,
        planDraft: DailyPlanDraft?,
        xpResult: XPEventResult,
        preservedExistingManualDraft: Bool
    ) {
        self.target = target
        self.reflectionPayload = reflectionPayload
        self.planDraft = planDraft
        self.xpResult = xpResult
        self.preservedExistingManualDraft = preservedExistingManualDraft
    }
}

public final class ResolveDailyReflectionTargetUseCase {
    private let reflectionStore: DailyReflectionStoreProtocol
    private let calendar: Calendar
    private let nowProvider: () -> Date

    public init(
        reflectionStore: DailyReflectionStoreProtocol,
        calendar: Calendar = .autoupdatingCurrent,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.reflectionStore = reflectionStore
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    public func execute(preferredReflectionDate _: Date? = nil) -> DailyReflectionTarget? {
        let today = calendar.startOfDay(for: nowProvider())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return nil
        }

        if reflectionStore.isCompleted(on: yesterday) == false {
            return DailyReflectionTarget(
                mode: .catchUpYesterday,
                reflectionDate: yesterday,
                planningDate: today
            )
        }

        if reflectionStore.isCompleted(on: today) == false {
            return DailyReflectionTarget(
                mode: .sameDay,
                reflectionDate: today,
                planningDate: tomorrow
            )
        }

        return nil
    }
}

public final class BuildNextDayPlanSuggestionUseCase {
    public struct CalendarContext: Equatable {
        public let events: [TaskerCalendarEventSnapshot]
        public let busyBlocks: [TaskerCalendarBusyBlock]
        public let bestFocusWindow: DateInterval?
        public let firstHardStop: Date?
        public let meetingMinutes: Int

        public init(
            events: [TaskerCalendarEventSnapshot],
            busyBlocks: [TaskerCalendarBusyBlock],
            bestFocusWindow: DateInterval?,
            firstHardStop: Date?,
            meetingMinutes: Int
        ) {
            self.events = events
            self.busyBlocks = busyBlocks
            self.bestFocusWindow = bestFocusWindow
            self.firstHardStop = firstHardStop
            self.meetingMinutes = meetingMinutes
        }
    }

    public struct CalendarContextLoadResult: Equatable {
        public let context: CalendarContext?
        public let status: DailyReflectionOptionalLoadStatus

        public init(context: CalendarContext?, status: DailyReflectionOptionalLoadStatus) {
            self.context = context
            self.status = status
        }
    }

    private let calendarEventsProvider: CalendarEventsProviderProtocol?
    private let buildCalendarBusyBlocks: BuildCalendarBusyBlocksUseCase
    private let calendar: Calendar

    public init(
        calendarEventsProvider: CalendarEventsProviderProtocol?,
        buildCalendarBusyBlocks: BuildCalendarBusyBlocksUseCase = BuildCalendarBusyBlocksUseCase(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.calendarEventsProvider = calendarEventsProvider
        self.buildCalendarBusyBlocks = buildCalendarBusyBlocks
        self.calendar = calendar
    }

    public func execute(
        planningDate: Date,
        carryoverTasks: [TaskDefinition],
        planningDateTasks: [TaskDefinition],
        atRiskHabit: HabitOccurrenceSummary?,
        completion: @escaping (Result<DailyPlanSuggestion, Error>) -> Void
    ) {
        Task {
            if Task.isCancelled {
                completion(.failure(CancellationError()))
                return
            }
            let loadResult = await loadCalendarContext(for: planningDate)
            let suggestion = buildSuggestion(
                planningDate: planningDate,
                carryoverTasks: carryoverTasks,
                planningDateTasks: planningDateTasks,
                atRiskHabit: atRiskHabit,
                calendarContext: loadResult.context
            )
            completion(.success(suggestion))
        }
    }

    public func buildCalendarSummary(
        for planningDate: Date,
        completion: @escaping (Result<CalendarReflectionSummary?, Error>) -> Void
    ) {
        Task {
            if Task.isCancelled {
                completion(.failure(CancellationError()))
                return
            }
            let loadResult = await loadCalendarContext(for: planningDate)
            completion(.success(makeCalendarSummary(from: loadResult.context)))
        }
    }

    public func loadCalendarContext(
        for planningDate: Date,
        timeoutSeconds: TimeInterval = 2.0
    ) async -> CalendarContextLoadResult {
        guard let calendarEventsProvider,
              calendarEventsProvider.authorizationStatus().isAuthorizedForRead else {
            return CalendarContextLoadResult(
                context: nil,
                status: .degraded("Calendar context unavailable. Suggestions use tasks and habits only.")
            )
        }

        let interval = TaskerPerformanceTrace.begin("ReflectionOptionalLoad")
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var didFinish = false

            func finish(_ result: CalendarContextLoadResult) {
                lock.lock()
                defer { lock.unlock() }
                guard didFinish == false else { return }
                didFinish = true
                TaskerPerformanceTrace.end(interval)
                continuation.resume(returning: result)
            }

            let timeoutNanoseconds = UInt64(max(0.25, timeoutSeconds) * 1_000_000_000)
            let timeoutTask = _Concurrency.Task {
                try? await _Concurrency.Task.sleep(nanoseconds: timeoutNanoseconds)
                finish(
                    CalendarContextLoadResult(
                        context: nil,
                        status: .degraded("Calendar context timed out. Suggestions use tasks and habits only.")
                    )
                )
            }

            let dayStart = calendar.startOfDay(for: planningDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let fetchInterval = TaskerPerformanceTrace.begin("ReflectionCalendarFetch")
            calendarEventsProvider.fetchEvents(startDate: dayStart, endDate: dayEnd, calendarIDs: []) { result in
                DispatchQueue.global(qos: .userInitiated).async {
                    defer { TaskerPerformanceTrace.end(fetchInterval) }
                    timeoutTask.cancel()
                    switch result {
                    case .failure:
                        finish(
                            CalendarContextLoadResult(
                                context: nil,
                                status: .degraded("Calendar context unavailable. Suggestions use tasks and habits only.")
                            )
                        )
                    case .success(let events):
                        let context = self.buildCalendarContext(
                            events: events,
                            dayStart: dayStart,
                            dayEnd: dayEnd
                        )
                        finish(CalendarContextLoadResult(context: context, status: .loaded))
                    }
                }
            }
        }
    }

    public func buildSuggestion(
        planningDate _: Date,
        carryoverTasks: [TaskDefinition],
        planningDateTasks: [TaskDefinition],
        atRiskHabit: HabitOccurrenceSummary?,
        calendarContext: CalendarContext?
    ) -> DailyPlanSuggestion {
        let planInterval = TaskerPerformanceTrace.begin("ReflectionPlanBuild")
        defer { TaskerPerformanceTrace.end(planInterval) }

        let ranked = rankCandidates(
            carryoverTasks: carryoverTasks,
            planningDateTasks: planningDateTasks
        )
        let selected = selectTopTasks(from: ranked)
        let selectedIDs = Set(selected.map(\.id))
        let swapPool = ranked.filter { !selectedIDs.contains($0.id) }
        let swapPools = Dictionary(
            uniqueKeysWithValues: selected.indices.map { index in
                (EditableDailyPlan.swapPoolKey(for: index), swapPool)
            }
        )

        let risk = resolvePrimaryRisk(
            carryoverTasks: carryoverTasks,
            planningDateTasks: planningDateTasks,
            calendarContext: calendarContext,
            atRiskHabit: atRiskHabit
        )

        return DailyPlanSuggestion(
            topTasks: selected,
            swapPoolsBySlot: swapPools,
            focusWindow: calendarContext?.bestFocusWindow,
            protectedHabitID: atRiskHabit?.habitID,
            protectedHabitTitle: atRiskHabit?.title,
            protectedHabitStreak: atRiskHabit?.currentStreak,
            primaryRisk: risk.0,
            primaryRiskDetail: risk.1
        )
    }

    public func makeCalendarSummary(from context: CalendarContext?) -> CalendarReflectionSummary? {
        guard let context,
              context.events.isEmpty == false || context.bestFocusWindow != nil else {
            return nil
        }
        return CalendarReflectionSummary(
            eventCount: context.events.count,
            meetingMinutes: context.meetingMinutes,
            bestFocusWindow: context.bestFocusWindow,
            firstHardStop: context.firstHardStop
        )
    }

    private func buildCalendarContext(
        events: [TaskerCalendarEventSnapshot],
        dayStart: Date,
        dayEnd: Date
    ) -> CalendarContext {
        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif

        let busyBlocks = buildCalendarBusyBlocks.execute(
            events: events,
            includeAllDayEvents: false,
            referenceStart: dayStart,
            referenceEnd: dayEnd
        )
        let firstHardStop = events
            .filter { !$0.isAllDay && $0.isBusy }
            .map(\.startDate)
            .sorted()
            .first
        let bestFocusWindow = resolveBestFocusWindow(
            start: dayStart,
            end: dayEnd,
            busyBlocks: busyBlocks,
            firstHardStop: firstHardStop
        )
        let meetingMinutes = events
            .filter { !$0.isAllDay && $0.isBusy }
            .reduce(0) { partialResult, event in
                partialResult + max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60.0))
            }

        return CalendarContext(
            events: events,
            busyBlocks: busyBlocks,
            bestFocusWindow: bestFocusWindow,
            firstHardStop: firstHardStop,
            meetingMinutes: meetingMinutes
        )
    }

    private func resolveBestFocusWindow(
        start: Date,
        end: Date,
        busyBlocks: [TaskerCalendarBusyBlock],
        firstHardStop: Date?
    ) -> DateInterval? {
        let windows = freeWindows(start: start, end: end, busyBlocks: busyBlocks)
        guard windows.isEmpty == false else { return nil }

        let minimumUsefulDuration: TimeInterval = 45 * 60
        if let firstHardStop {
            let preHardStop = windows
                .compactMap { interval -> DateInterval? in
                    guard interval.start < firstHardStop else { return nil }
                    let clampedEnd = min(interval.end, firstHardStop)
                    guard clampedEnd > interval.start else { return nil }
                    let candidate = DateInterval(start: interval.start, end: clampedEnd)
                    return candidate.duration >= minimumUsefulDuration ? candidate : nil
                }
                .sorted { $0.duration > $1.duration }
                .first
            if let preHardStop {
                return preHardStop
            }
        }

        return windows
            .filter { $0.duration >= minimumUsefulDuration }
            .sorted { $0.duration > $1.duration }
            .first ?? windows.sorted { $0.duration > $1.duration }.first
    }

    private func freeWindows(
        start: Date,
        end: Date,
        busyBlocks: [TaskerCalendarBusyBlock]
    ) -> [DateInterval] {
        var cursor = start
        var intervals: [DateInterval] = []

        for block in busyBlocks.sorted(by: { $0.startDate < $1.startDate }) {
            let clampedStart = max(start, block.startDate)
            let clampedEnd = min(end, block.endDate)
            if clampedStart > cursor {
                intervals.append(DateInterval(start: cursor, end: clampedStart))
            }
            cursor = max(cursor, clampedEnd)
        }

        if cursor < end {
            intervals.append(DateInterval(start: cursor, end: end))
        }

        return intervals.filter { $0.duration > 0 }
    }

    private func rankCandidates(
        carryoverTasks: [TaskDefinition],
        planningDateTasks: [TaskDefinition]
    ) -> [DailyPlanTaskOption] {
        let carryovers = carryoverTasks
            .filter { !$0.isComplete }
            .sorted(by: taskSort)
            .map { makeOption(from: $0, isCarryover: true) }

        let dueAndPriority = planningDateTasks
            .filter { !$0.isComplete }
            .sorted(by: taskSort)
            .map { task -> DailyPlanTaskOption in
                makeOption(
                    from: task,
                    isCarryover: false,
                    isQuickStabilizer: isQuickStabilizer(task)
                )
            }

        var seen = Set<UUID>()
        return (carryovers + dueAndPriority).filter { option in
            seen.insert(option.id).inserted
        }
    }

    private func selectTopTasks(from ranked: [DailyPlanTaskOption]) -> [DailyPlanTaskOption] {
        var selected: [DailyPlanTaskOption] = []
        var deepCount = 0
        var quickStabilizerCount = 0

        for option in ranked {
            let isDeep = isDeepWork(option)
            if option.isQuickStabilizer && quickStabilizerCount >= 1 {
                continue
            }
            if isDeep && deepCount >= 2 && selected.count >= 2 {
                continue
            }

            selected.append(option)
            if option.isQuickStabilizer {
                quickStabilizerCount += 1
            }
            if isDeep {
                deepCount += 1
            }

            if selected.count == 3 {
                break
            }
        }

        return selected
    }

    private func resolvePrimaryRisk(
        carryoverTasks: [TaskDefinition],
        planningDateTasks: [TaskDefinition],
        calendarContext: CalendarContext?,
        atRiskHabit: HabitOccurrenceSummary?
    ) -> (DailyPlanRisk?, String?) {
        if carryoverTasks.isEmpty == false {
            return (.carryoverPressure, "Clear yesterday's carryover first so today doesn't stack.")
        }
        if planningDateTasks.contains(where: { $0.isOverdue }) {
            return (.overdueBacklogPressure, "An overdue task can steal the day early.")
        }
        if let calendarContext, calendarContext.meetingMinutes >= 180 {
            return (.meetingCongestion, "Calendar load is high, so protect a real focus window early.")
        }
        if let atRiskHabit {
            return (
                .habitContinuityRisk,
                "Protect \(atRiskHabit.title) before the streak slips further."
            )
        }
        return (nil, nil)
    }

    private func isQuickStabilizer(_ task: TaskDefinition) -> Bool {
        let shortDuration = (task.estimatedDuration ?? 0) > 0 && (task.estimatedDuration ?? 0) <= 30 * 60
        return task.energy == .low || shortDuration || task.priority == .none
    }

    private func isDeepWork(_ option: DailyPlanTaskOption) -> Bool {
        option.priority == .max || option.priority == .high
    }

    private func makeOption(
        from task: TaskDefinition,
        isCarryover: Bool,
        isQuickStabilizer: Bool = false
    ) -> DailyPlanTaskOption {
        DailyPlanTaskOption(
            id: task.id,
            title: task.title,
            projectName: task.projectName,
            dueDate: task.dueDate,
            priority: task.priority,
            isCarryover: isCarryover,
            isQuickStabilizer: isQuickStabilizer
        )
    }

    private func taskSort(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

public struct DailyReflectionCoreLoadBundle {
    public let target: DailyReflectionTarget
    public let coreSnapshot: DailyReflectionCoreSnapshot
    public let carryoverTasks: [TaskDefinition]
    public let planningTasks: [TaskDefinition]
    public let atRiskHabit: HabitOccurrenceSummary?

    public init(
        target: DailyReflectionTarget,
        coreSnapshot: DailyReflectionCoreSnapshot,
        carryoverTasks: [TaskDefinition],
        planningTasks: [TaskDefinition],
        atRiskHabit: HabitOccurrenceSummary?
    ) {
        self.target = target
        self.coreSnapshot = coreSnapshot
        self.carryoverTasks = carryoverTasks
        self.planningTasks = planningTasks
        self.atRiskHabit = atRiskHabit
    }
}

public protocol DailyReflectionLoadCoordinatorProtocol {
    func resolveTarget(preferredReflectionDate: Date?) async -> DailyReflectionTarget?
    func loadCore(target: DailyReflectionTarget) async throws -> DailyReflectionCoreLoadBundle
    func loadOptionalContext(target: DailyReflectionTarget, coreBundle: DailyReflectionCoreLoadBundle) async -> DailyReflectionOptionalContext
}

public actor DailyReflectionLoadCoordinator: DailyReflectionLoadCoordinatorProtocol {
    private let resolveTargetUseCase: ResolveDailyReflectionTargetUseCase
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol
    private let habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol
    private let buildNextDayPlanSuggestionUseCase: BuildNextDayPlanSuggestionUseCase
    private let calendar: Calendar

    public init(
        resolveTargetUseCase: ResolveDailyReflectionTargetUseCase,
        taskReadModelRepository: TaskReadModelRepositoryProtocol,
        habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol,
        buildNextDayPlanSuggestionUseCase: BuildNextDayPlanSuggestionUseCase,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.resolveTargetUseCase = resolveTargetUseCase
        self.taskReadModelRepository = taskReadModelRepository
        self.habitRuntimeReadRepository = habitRuntimeReadRepository
        self.buildNextDayPlanSuggestionUseCase = buildNextDayPlanSuggestionUseCase
        self.calendar = calendar
    }

    public func resolveTarget(preferredReflectionDate: Date?) async -> DailyReflectionTarget? {
        let interval = TaskerPerformanceTrace.begin("ReflectionResolveTarget")
        defer { TaskerPerformanceTrace.end(interval) }
        return resolveTargetUseCase.execute(preferredReflectionDate: preferredReflectionDate)
    }

    public func loadCore(target: DailyReflectionTarget) async throws -> DailyReflectionCoreLoadBundle {
        let interval = TaskerPerformanceTrace.begin("ReflectionCoreLoad")
        defer { TaskerPerformanceTrace.end(interval) }

        async let projectionTask = fetchTaskProjection(target: target)
        async let habitsTask = fetchHabits(for: target.reflectionDate)

        let projection = try await projectionTask
        let habits = try await habitsTask
        try Task.checkCancellation()

        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif

        let taskSummary = makeTaskSummary(from: projection, on: target.reflectionDate)
        let habitSummary = makeHabitSummary(from: habits)
        let atRiskHabit = habits
            .sorted { lhs, rhs in
                if lhs.riskState != rhs.riskState {
                    return lhs.riskState.rawValue > rhs.riskState.rawValue
                }
                return lhs.currentStreak > rhs.currentStreak
            }
            .first(where: { $0.riskState != .stable })

        let carryoverTasks = projection.reflectionOpenTasks.filter { task in
            guard let dueDate = task.dueDate else { return true }
            return calendar.startOfDay(for: dueDate) <= calendar.startOfDay(for: target.reflectionDate)
        }
        let planningTasks = projection.planningOpenTasks

        let coreSnapshot = DailyReflectionCoreSnapshot(
            reflectionDate: target.reflectionDate,
            planningDate: target.planningDate,
            mode: target.mode,
            pulseNote: makePulseNote(
                taskSummary: taskSummary,
                habitSummary: habitSummary,
                calendarSummary: nil
            ),
            biggestWins: makeBiggestWins(
                completedTasks: projection.reflectionCompletedTasks,
                habits: habits,
                taskSummary: taskSummary
            ),
            tasksSummary: taskSummary,
            habitsSummary: habitSummary
        )

        return DailyReflectionCoreLoadBundle(
            target: target,
            coreSnapshot: coreSnapshot,
            carryoverTasks: carryoverTasks,
            planningTasks: planningTasks,
            atRiskHabit: atRiskHabit
        )
    }

    public func loadOptionalContext(target: DailyReflectionTarget, coreBundle: DailyReflectionCoreLoadBundle) async -> DailyReflectionOptionalContext {
        let loadResult = await buildNextDayPlanSuggestionUseCase.loadCalendarContext(for: target.planningDate)
        let suggestion = buildNextDayPlanSuggestionUseCase.buildSuggestion(
            planningDate: target.planningDate,
            carryoverTasks: coreBundle.carryoverTasks,
            planningDateTasks: coreBundle.planningTasks,
            atRiskHabit: coreBundle.atRiskHabit,
            calendarContext: loadResult.context
        )
        return DailyReflectionOptionalContext(
            calendarSummary: buildNextDayPlanSuggestionUseCase.makeCalendarSummary(from: loadResult.context),
            suggestedPlan: suggestion,
            status: loadResult.status
        )
    }

    private func fetchTaskProjection(target: DailyReflectionTarget) async throws -> DailyReflectionTaskProjection {
        try await withCheckedThrowingContinuation { continuation in
            taskReadModelRepository.fetchDailyReflectionProjection(
                query: DailyReflectionTaskProjectionQuery(
                    reflectionDate: target.reflectionDate,
                    planningDate: target.planningDate
                )
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func fetchHabits(for reflectionDate: Date) async throws -> [HabitOccurrenceSummary] {
        try await withCheckedThrowingContinuation { continuation in
            habitRuntimeReadRepository.fetchAgendaHabits(for: reflectionDate) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func makeTaskSummary(from projection: DailyReflectionTaskProjection, on date: Date) -> TaskReflectionSummary {
        let scheduledCount = projection.reflectionCompletedTasks.count + projection.reflectionOpenTasks.count
        let carryOverCount = projection.reflectionOpenTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.startOfDay(for: dueDate) <= calendar.startOfDay(for: date)
            }
            .count

        return TaskReflectionSummary(
            completedCount: projection.reflectionCompletedTasks.count,
            scheduledCount: scheduledCount,
            carryOverCount: carryOverCount,
            overdueOpenCount: projection.reflectionOpenTasks.filter { $0.isOverdue }.count
        )
    }

    private func makeHabitSummary(from habits: [HabitOccurrenceSummary]) -> HabitReflectionSummary? {
        guard habits.isEmpty == false else { return nil }
        let keptCount = habits.filter { $0.state == .completed }.count
        let missedCount = habits.filter { $0.state == .missed || $0.state == .skipped }.count
        let atRisk = habits
            .filter { $0.riskState != .stable }
            .sorted { lhs, rhs in
                if lhs.currentStreak != rhs.currentStreak {
                    return lhs.currentStreak > rhs.currentStreak
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .first

        return HabitReflectionSummary(
            keptCount: keptCount,
            targetCount: habits.count,
            missedCount: missedCount,
            atRiskHabitID: atRisk?.habitID,
            atRiskHabitTitle: atRisk?.title,
            currentStreak: atRisk?.currentStreak
        )
    }

    private func makePulseNote(
        taskSummary: TaskReflectionSummary,
        habitSummary: HabitReflectionSummary?,
        calendarSummary: CalendarReflectionSummary?
    ) -> String {
        if taskSummary.completedCount >= max(1, taskSummary.scheduledCount / 2) {
            return "Strong close. Keep the next day tight and protect the first real focus window."
        }
        if let habitSummary, let habitTitle = habitSummary.atRiskHabitTitle {
            return "Reset the day by protecting \(habitTitle) early and shrinking the task list."
        }
        if let calendarSummary, calendarSummary.meetingMinutes >= 180 {
            return "Your calendar is doing damage tomorrow. Start with one important task before meetings spread."
        }
        return "Keep the next day deliberate: one clear priority, one protected habit, one smaller stabilizer."
    }

    private func makeBiggestWins(
        completedTasks: [TaskDefinition],
        habits: [HabitOccurrenceSummary],
        taskSummary: TaskReflectionSummary
    ) -> [ReflectionHighlight] {
        var wins: [ReflectionHighlight] = completedTasks
            .sorted { lhs, rhs in
                if lhs.priority.scorePoints != rhs.priority.scorePoints {
                    return lhs.priority.scorePoints > rhs.priority.scorePoints
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(2)
            .map {
                ReflectionHighlight(title: $0.title, detail: $0.projectName)
            }

        if wins.count < 2, taskSummary.carryOverCount == 0, taskSummary.completedCount > 0 {
            wins.append(ReflectionHighlight(title: "Cleared the day without carryover", detail: nil))
        }

        if wins.count < 2,
           let rescuedHabit = habits.first(where: { $0.riskState != .stable && $0.state == .completed }) {
            wins.append(
                ReflectionHighlight(
                    title: "Protected \(rescuedHabit.title)",
                    detail: "Streak at \(rescuedHabit.currentStreak)"
                )
            )
        }

        return Array(wins.prefix(2))
    }
}

public final class SaveDailyReflectionAndPlanUseCase {
    private let reflectionStore: DailyReflectionStoreProtocol
    private let markDailyReflection: MarkDailyReflectionCompleteUseCase
    private let notificationCenter: NotificationCenter
    private let calendar: Calendar

    public init(
        reflectionStore: DailyReflectionStoreProtocol,
        markDailyReflection: MarkDailyReflectionCompleteUseCase,
        notificationCenter: NotificationCenter = .default,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.reflectionStore = reflectionStore
        self.markDailyReflection = markDailyReflection
        self.notificationCenter = notificationCenter
        self.calendar = calendar
    }

    public func execute(
        snapshot: DailyReflectionSnapshot,
        input: DailyReflectionInput,
        plan: EditableDailyPlan,
        replaceExistingManualDraft: Bool = false,
        completion: @escaping (Result<SaveDailyReflectionAndPlanResult, Error>) -> Void
    ) {
        let payload = ReflectionPayload(
            reflectionDate: snapshot.reflectionDate,
            planningDate: snapshot.planningDate,
            mode: snapshot.mode,
            mood: input.mood,
            energy: input.energy,
            frictionTags: input.frictionTags,
            note: input.note
        )

        markDailyReflection.execute(on: snapshot.reflectionDate, payload: payload) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let xpResult):
                do {
                    let existingDraft = self.reflectionStore.fetchPlanDraft(on: plan.planningDate)
                    let preservedManualDraft = existingDraft?.source == .manual && replaceExistingManualDraft == false
                    let savedDraft: DailyPlanDraft?
                    if preservedManualDraft {
                        savedDraft = existingDraft
                    } else {
                        var draft = plan.makeDraft(updatedAt: Date())
                        draft = DailyPlanDraft(
                            date: draft.date,
                            topTasks: draft.topTasks,
                            suggestedFocusBlock: draft.suggestedFocusBlock,
                            protectedHabitID: draft.protectedHabitID,
                            protectedHabitTitle: draft.protectedHabitTitle,
                            protectedHabitStreak: draft.protectedHabitStreak,
                            primaryRisk: draft.primaryRisk,
                            primaryRiskDetail: draft.primaryRiskDetail,
                            source: .reflection,
                            updatedAt: draft.updatedAt
                        )
                        savedDraft = try self.reflectionStore.savePlanDraft(draft, replaceExisting: true)
                    }

                    let dateKey = self.dateStamp(for: snapshot.reflectionDate)

                    TaskerNotificationRuntime.orchestrator?.reconcile(reason: "daily_reflection_saved")
                    self.notificationCenter.post(
                        name: .dailyReflectionCompleted,
                        object: nil,
                        userInfo: [
                            "dateKey": dateKey,
                            "planningDateKey": self.dateStamp(for: snapshot.planningDate),
                            "planningDate": self.calendar.startOfDay(for: snapshot.planningDate),
                            "preservedManualDraft": preservedManualDraft
                        ]
                    )

                    completion(
                        .success(
                            SaveDailyReflectionAndPlanResult(
                                target: DailyReflectionTarget(
                                    mode: snapshot.mode,
                                    reflectionDate: snapshot.reflectionDate,
                                    planningDate: snapshot.planningDate
                                ),
                                reflectionPayload: self.reflectionStore.fetchReflectionPayload(on: snapshot.reflectionDate),
                                planDraft: savedDraft,
                                xpResult: xpResult,
                                preservedExistingManualDraft: preservedManualDraft
                            )
                        )
                    )
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func dateStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: calendar.startOfDay(for: date))
    }
}
