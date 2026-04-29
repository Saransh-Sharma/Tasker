//
//  GetHomeFilteredTasksUseCase.swift
//  Tasker
//
//  Unified filtering for Home "Focus Engine" quick views + facets + advanced filters
//

import Foundation

public struct HomeFilteredTasksResult {
    public let visibleOpenTasks: [TaskDefinition]
    public let visibleDoneTimelineTasks: [TaskDefinition]
    public let matchingOpenTasks: [TaskDefinition]
    public let quickViewCounts: [HomeQuickView: Int]
    public let pointsPotential: Int

    public var openTasks: [TaskDefinition] { visibleOpenTasks }
    public var doneTimelineTasks: [TaskDefinition] { visibleDoneTimelineTasks }

    public init(
        visibleOpenTasks: [TaskDefinition],
        visibleDoneTimelineTasks: [TaskDefinition],
        matchingOpenTasks: [TaskDefinition],
        quickViewCounts: [HomeQuickView: Int],
        pointsPotential: Int
    ) {
        self.visibleOpenTasks = visibleOpenTasks
        self.visibleDoneTimelineTasks = visibleDoneTimelineTasks
        self.matchingOpenTasks = matchingOpenTasks
        self.quickViewCounts = quickViewCounts
        self.pointsPotential = pointsPotential
    }
}

public enum GetHomeFilteredTasksError: LocalizedError {
    case repositoryError(Error)

    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Failed to load home filters: \(error.localizedDescription)"
        }
    }
}

public final class GetHomeFilteredTasksUseCase {

    private let readModelRepository: TaskReadModelRepositoryProtocol?
    private let cacheLock = NSLock()
    private var resultCache: [String: HomeFilteredTasksResult] = [:]
    private var resultCacheOrder: [String] = []
    private let exactProjectionPageSize = 400
    private let maxResultCacheEntries = 32

    private struct ProjectionAccumulator {
        let scope: HomeListScope
        let state: HomeFilterState
        let windowLimit: Int
        var quickViewCounts = Dictionary(uniqueKeysWithValues: HomeQuickView.allCases.map { ($0, 0) })
        var pointsPotential = 0
        var matchingOpenTasks: [TaskDefinition] = []
        var openTasks: [TaskDefinition] = []
        var doneTimelineTasks: [TaskDefinition] = []
    }

    /// Initializes a new instance.
    public init(
        readModelRepository: TaskReadModelRepositoryProtocol? = nil
    ) {
        self.readModelRepository = readModelRepository
    }

    public func invalidateCaches() {
        cacheLock.lock()
        resultCache.removeAll()
        resultCacheOrder.removeAll()
        cacheLock.unlock()
    }

    public func hasCachedResult(
        state: HomeFilterState,
        scope: HomeListScope,
        revision: HomeDataRevision = .zero
    ) -> Bool {
        let cacheKey = makeCacheKey(state: state, scope: scope, revision: revision)
        cacheLock.lock()
        let isCached = resultCache[cacheKey] != nil
        cacheLock.unlock()
        return isCached
    }

    /// Executes execute.
    public func execute(
        state: HomeFilterState,
        scope: HomeListScope,
        revision: HomeDataRevision = .zero,
        completion: @escaping (Result<HomeFilteredTasksResult, GetHomeFilteredTasksError>) -> Void
    ) {
        guard let readModel = readModelRepository else {
            completion(.failure(.repositoryError(NSError(
                domain: "GetHomeFilteredTasksUseCase",
                code: 503,
                userInfo: [NSLocalizedDescriptionKey: "TaskDefinition read-model repository is not configured"]
            ))))
            return
        }

        let cacheKey = makeCacheKey(state: state, scope: scope, revision: revision)
        cacheLock.lock()
        if let cached = resultCache[cacheKey] {
            markCacheKeyRecentlyUsed(cacheKey)
            cacheLock.unlock()
            completion(.success(cached))
            return
        }
        cacheLock.unlock()

        let interval = TaskerPerformanceTrace.begin("HomeFilterQuery")
        let projectionInterval = TaskerPerformanceTrace.begin("HomeFilterExactProjection")

        fetchHomeProjection(
            state: state,
            scope: scope,
            readModel: readModel
        ) { [weak self] result in
            guard let self else { return }
            defer {
                TaskerPerformanceTrace.end(projectionInterval)
                TaskerPerformanceTrace.end(interval)
            }

            switch result {
            case .success(let accumulator):
                let visibleTasks = self.makeVisibleTaskWindow(
                    state: state,
                    openTasks: accumulator.openTasks,
                    doneTimelineTasks: accumulator.doneTimelineTasks,
                    scope: scope
                )
                let payload = HomeFilteredTasksResult(
                    visibleOpenTasks: visibleTasks.openTasks,
                    visibleDoneTimelineTasks: visibleTasks.doneTimelineTasks,
                    matchingOpenTasks: accumulator.matchingOpenTasks,
                    quickViewCounts: accumulator.quickViewCounts,
                    pointsPotential: accumulator.pointsPotential
                )
                self.cacheLock.lock()
                self.storeCachedResult(payload, for: cacheKey)
                self.cacheLock.unlock()
                completion(.success(payload))

            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }

    /// Executes execute.
    public func execute(
        state: HomeFilterState,
        completion: @escaping (Result<HomeFilteredTasksResult, GetHomeFilteredTasksError>) -> Void
    ) {
        execute(state: state, scope: .fromQuickView(state.quickView), revision: .zero, completion: completion)
    }

    private func markCacheKeyRecentlyUsed(_ cacheKey: String) {
        resultCacheOrder.removeAll { $0 == cacheKey }
        resultCacheOrder.append(cacheKey)
    }

    private func storeCachedResult(_ result: HomeFilteredTasksResult, for cacheKey: String) {
        resultCache[cacheKey] = result
        markCacheKeyRecentlyUsed(cacheKey)
        while resultCacheOrder.count > maxResultCacheEntries {
            let evicted = resultCacheOrder.removeFirst()
            resultCache.removeValue(forKey: evicted)
        }
    }

    private func fetchHomeProjection(
        state: HomeFilterState,
        scope: HomeListScope,
        readModel: TaskReadModelRepositoryProtocol,
        completion: @escaping (Result<ProjectionAccumulator, Error>) -> Void
    ) {
        var accumulator = ProjectionAccumulator(
            scope: scope,
            state: state,
            windowLimit: homeWindowLimit(for: state, scope: scope)
        )

        func loadPage(offset: Int) {
            readModel.fetchHomeProjection(
                query: HomeProjectionQuery(
                    state: state,
                    scope: scope,
                    limit: exactProjectionPageSize,
                    offset: offset
                )
            ) { result in
                switch result {
                case .success(let slice):
                    let facetedBatch = self.applyResidualAdvancedFacets(slice.tasks, state: state)
                    for task in facetedBatch {
                        self.updateQuickViewCounts(&accumulator.quickViewCounts, for: task, scope: scope)
                        guard self.matchesScope(scope, task: task) else { continue }
                        if task.isComplete {
                            self.insertBoundedSortedTask(
                                task,
                                into: &accumulator.doneTimelineTasks,
                                limit: accumulator.windowLimit,
                                by: self.sortDoneTimeline
                            )
                        } else {
                            accumulator.pointsPotential += task.priority.scorePoints
                            self.insertSortedTask(
                                task,
                                into: &accumulator.matchingOpenTasks,
                                by: self.sortByPriorityThenSchedule
                            )
                            self.insertBoundedSortedTask(
                                task,
                                into: &accumulator.openTasks,
                                limit: accumulator.windowLimit,
                                by: self.sortByPriorityThenSchedule
                            )
                        }
                    }

                    let nextOffset = offset + slice.tasks.count
                    let loadedAllTasks = nextOffset >= slice.totalCount || slice.tasks.isEmpty
                    if loadedAllTasks {
                        completion(.success(accumulator))
                    } else {
                        loadPage(offset: nextOffset)
                    }

                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        loadPage(offset: 0)
    }

    private func updateQuickViewCounts(
        _ counts: inout [HomeQuickView: Int],
        for task: TaskDefinition,
        scope: HomeListScope
    ) {
        let anchorDate = scope.referenceDate
        let calendar = Calendar.current
        let startOfAnchorDay = calendar.startOfDay(for: anchorDate)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay) ?? anchorDate
        let endOfUpcomingWindow = calendar.date(byAdding: .day, value: 14, to: startOfAnchorDay) ?? anchorDate
        let doneWindowStart = calendar.date(byAdding: .day, value: -30, to: startOfAnchorDay) ?? Date.distantPast
        let doneWindowEnd = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay) ?? anchorDate

        if matchesToday(task, startOfAnchorDay: startOfAnchorDay, startOfNextDay: startOfNextDay) {
            counts[.today, default: 0] += 1
        }
        if let dueDate = task.dueDate,
           dueDate >= startOfNextDay,
           dueDate <= endOfUpcomingWindow {
            counts[.upcoming, default: 0] += 1
        }
        if task.isComplete == false,
           let dueDate = task.dueDate,
           dueDate < startOfAnchorDay {
            counts[.overdue, default: 0] += 1
        }
        if task.isComplete,
           let completionDate = task.dateCompleted,
           completionDate >= doneWindowStart,
           completionDate < doneWindowEnd {
            counts[.done, default: 0] += 1
        }
        if isMorningTaskHybrid(task) {
            counts[.morning, default: 0] += 1
        }
        if isEveningTaskHybrid(task) {
            counts[.evening, default: 0] += 1
        }
    }

    private func matchesToday(
        _ task: TaskDefinition,
        startOfAnchorDay: Date,
        startOfNextDay: Date
    ) -> Bool {
        if task.isComplete {
            guard let completionDate = task.dateCompleted else { return false }
            return completionDate >= startOfAnchorDay && completionDate < startOfNextDay
        }

        let dueDate = task.dueDate
        let dueOnAnchorDay = dueDate.map { $0 >= startOfAnchorDay && $0 < startOfNextDay } ?? false
        let overdue = dueDate.map { $0 < startOfAnchorDay } ?? false
        let scheduledCarryOver = dueDate == nil
            && (task.scheduledStartAt.map { $0 < startOfNextDay } ?? false)
        return dueOnAnchorDay || overdue || scheduledCarryOver
    }

    private func homeWindowLimit(for state: HomeFilterState, scope: HomeListScope) -> Int {
        switch scope.quickView {
        case .done:
            return 640
        case .upcoming:
            return 420
        case .overdue:
            return 320
        case .morning, .evening:
            return state.showCompletedInline ? 420 : 320
        case .today:
            return state.showCompletedInline ? 480 : 360
        }
    }

    private func makeVisibleTaskWindow(
        state: HomeFilterState,
        openTasks: [TaskDefinition],
        doneTimelineTasks: [TaskDefinition],
        scope: HomeListScope
    ) -> (openTasks: [TaskDefinition], doneTimelineTasks: [TaskDefinition]) {
        let windowLimit = homeWindowLimit(for: state, scope: scope)
        guard windowLimit > 0 else {
            return ([], [])
        }

        let shouldReserveInlineDoneWindow = scope.quickView != .done
            && state.showCompletedInline
            && openTasks.isEmpty == false
            && doneTimelineTasks.isEmpty == false
        let doneReservation = shouldReserveInlineDoneWindow ? min(doneTimelineTasks.count, max(12, windowLimit / 4)) : 0
        let openLimit = max(0, windowLimit - doneReservation)

        let visibleOpenTasks = Array(openTasks.prefix(max(1, openLimit)))
        let remainingSlots = max(0, windowLimit - visibleOpenTasks.count)
        let doneLimit = visibleOpenTasks.isEmpty ? windowLimit : remainingSlots
        let visibleDoneTimelineTasks = Array(doneTimelineTasks.prefix(doneLimit))
        return (visibleOpenTasks, visibleDoneTimelineTasks)
    }

    private func makeCacheKey(
        state: HomeFilterState,
        scope: HomeListScope,
        revision: HomeDataRevision
    ) -> String {
        struct Payload: Codable {
            let state: HomeFilterState
            let scope: HomeListScope
            let revision: UInt64
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = Payload(state: state, scope: scope, revision: revision.rawValue)
        let data = (try? encoder.encode(payload)) ?? Data()
        return data.base64EncodedString()
    }

    private func matchesScope(_ scope: HomeListScope, task: TaskDefinition) -> Bool {
        let calendar = Calendar.current
        let anchorDate = scope.referenceDate
        let startOfAnchorDay = calendar.startOfDay(for: anchorDate)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay) ?? anchorDate
        let endOfUpcomingWindow = calendar.date(byAdding: .day, value: 14, to: startOfAnchorDay) ?? anchorDate
        let doneWindowStart = calendar.date(byAdding: .day, value: -30, to: startOfAnchorDay) ?? Date.distantPast
        let doneWindowEnd = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay) ?? anchorDate

        switch scope.quickView {
        case .today:
            return matchesToday(task, startOfAnchorDay: startOfAnchorDay, startOfNextDay: startOfNextDay)
        case .upcoming:
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfNextDay && dueDate <= endOfUpcomingWindow
        case .overdue:
            guard task.isComplete == false, let dueDate = task.dueDate else { return false }
            return dueDate < startOfAnchorDay
        case .done:
            guard task.isComplete, let completionDate = task.dateCompleted else { return false }
            return completionDate >= doneWindowStart && completionDate < doneWindowEnd
        case .morning:
            return isMorningTaskHybrid(task)
        case .evening:
            return isEveningTaskHybrid(task)
        }
    }

    private func insertBoundedSortedTask(
        _ task: TaskDefinition,
        into tasks: inout [TaskDefinition],
        limit: Int,
        by areInIncreasingOrder: (TaskDefinition, TaskDefinition) -> Bool
    ) {
        guard limit > 0 else { return }
        let insertionIndex = tasks.firstIndex { !areInIncreasingOrder($0, task) } ?? tasks.endIndex
        if insertionIndex < limit {
            tasks.insert(task, at: insertionIndex)
            if tasks.count > limit {
                tasks.removeLast(tasks.count - limit)
            }
        } else if tasks.count < limit {
            tasks.append(task)
        }
    }

    private func insertSortedTask(
        _ task: TaskDefinition,
        into tasks: inout [TaskDefinition],
        by areInIncreasingOrder: (TaskDefinition, TaskDefinition) -> Bool
    ) {
        let insertionIndex = tasks.firstIndex { !areInIncreasingOrder($0, task) } ?? tasks.endIndex
        tasks.insert(task, at: insertionIndex)
    }

    /// Executes applyResidualAdvancedFacets.
    private func applyResidualAdvancedFacets(_ tasks: [TaskDefinition], state: HomeFilterState) -> [TaskDefinition] {
        let projectIDs = Set(state.selectedProjectIDs)
        let projectFilteredTasks = projectIDs.isEmpty
            ? tasks
            : tasks.filter { projectIDs.contains($0.projectID) }

        guard let advanced = state.advancedFilter, !advanced.isEmpty else {
            return projectFilteredTasks
        }

        return projectFilteredTasks.filter { task in
            if !advanced.tags.isEmpty {
                let requestedTagIDs = Set(
                    advanced.tags.compactMap { rawValue in
                        UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                )
                if requestedTagIDs.isEmpty {
                    return false
                }
                let taskTagIDs = Set(task.tagIDs)
                switch advanced.tagMatchMode {
                case .any:
                    if taskTagIDs.isDisjoint(with: requestedTagIDs) {
                        return false
                    }
                case .all:
                    if !requestedTagIDs.isSubset(of: taskTagIDs) {
                        return false
                    }
                }
            }

            if let hasDependencies = advanced.hasDependencies {
                if hasDependencies && task.dependencies.isEmpty {
                    return false
                }
                if !hasDependencies && !task.dependencies.isEmpty {
                    return false
                }
            }

            return true
        }
    }

    /// Executes applyScope.
    private func applyScope(_ scope: HomeListScope, to tasks: [TaskDefinition]) -> [TaskDefinition] {
        switch scope {
        case .today:
            return applyQuickView(.today, to: tasks, anchorDate: Date())
        case .customDate(let date):
            return applyQuickView(.today, to: tasks, anchorDate: date)
        case .upcoming:
            return applyQuickView(.upcoming, to: tasks, anchorDate: Date())
        case .overdue:
            return applyQuickView(.overdue, to: tasks, anchorDate: Date())
        case .done:
            return applyQuickView(.done, to: tasks, anchorDate: Date())
        case .morning:
            return applyQuickView(.morning, to: tasks, anchorDate: Date())
        case .evening:
            return applyQuickView(.evening, to: tasks, anchorDate: Date())
        }
    }

    /// Executes applyQuickView.
    private func applyQuickView(_ view: HomeQuickView, to tasks: [TaskDefinition], anchorDate: Date) -> [TaskDefinition] {
        let calendar = Calendar.current
        let startOfAnchorDay = calendar.startOfDay(for: anchorDate)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay) ?? anchorDate
        let endOfUpcomingWindow = calendar.date(byAdding: .day, value: 14, to: startOfAnchorDay) ?? anchorDate
        let doneWindowStart = calendar.date(byAdding: .day, value: -30, to: startOfAnchorDay) ?? Date.distantPast
        let doneWindowEnd = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay) ?? anchorDate

        switch view {
        case .today:
            return tasks.filter { task in
                if task.isComplete {
                    guard let completionDate = task.dateCompleted else { return false }
                    return completionDate >= startOfAnchorDay && completionDate < startOfNextDay
                }

                let dueDate = task.dueDate
                let dueOnAnchorDay = dueDate.map { $0 >= startOfAnchorDay && $0 < startOfNextDay } ?? false
                let overdue = dueDate.map { $0 < startOfAnchorDay } ?? false
                return dueOnAnchorDay || overdue
            }

        case .upcoming:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= startOfNextDay && dueDate <= endOfUpcomingWindow
            }

        case .overdue:
            return tasks.filter { task in
                guard task.isComplete == false,
                      let dueDate = task.dueDate else {
                    return false
                }
                return dueDate < startOfAnchorDay
            }

        case .done:
            return tasks.filter { task in
                guard task.isComplete, let completionDate = task.dateCompleted else { return false }
                return completionDate >= doneWindowStart && completionDate < doneWindowEnd
            }

        case .morning:
            return tasks.filter { task in
                return isMorningTaskHybrid(task)
            }

        case .evening:
            return tasks.filter { task in
                return isEveningTaskHybrid(task)
            }
        }
    }

    /// Executes isMorningTaskHybrid.
    private func isMorningTaskHybrid(_ task: TaskDefinition) -> Bool {
        if task.type == .morning { return true }
        if task.type == .evening { return false }

        guard let dueDate = task.dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour >= 4 && hour <= 11
    }

    /// Executes isEveningTaskHybrid.
    private func isEveningTaskHybrid(_ task: TaskDefinition) -> Bool {
        if task.type == .evening { return true }
        if task.type == .morning { return false }

        guard let dueDate = task.dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour >= 17 && hour <= 23
    }

    /// Executes sortByPriorityThenDue.
    private func sortByPriorityThenDue(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        let lhsDate = lhs.dueDate ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? Date.distantFuture
        return lhsDate < rhsDate
    }

    private func sortByPriorityThenSchedule(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        let lhsDate = lhs.dueDate ?? lhs.scheduledStartAt ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? rhs.scheduledStartAt ?? Date.distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    /// Executes sortDoneTimeline.
    private func sortDoneTimeline(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        let calendar = Calendar.current
        let lhsDay = lhs.dateCompleted.map { calendar.startOfDay(for: $0) } ?? Date.distantPast
        let rhsDay = rhs.dateCompleted.map { calendar.startOfDay(for: $0) } ?? Date.distantPast

        if lhsDay != rhsDay {
            return lhsDay > rhsDay
        }

        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        let lhsCompletion = lhs.dateCompleted ?? Date.distantPast
        let rhsCompletion = rhs.dateCompleted ?? Date.distantPast
        return lhsCompletion > rhsCompletion
    }
}

// MARK: - Eva Home Models

public enum EvaPromptLevel: String, Codable, Equatable, Hashable {
    case none
    case microcopy
    case chip
    case banner
}

public enum EvaDebtLevel: String, Codable, Equatable, Hashable {
    case none
    case low
    case medium
    case high
}

public enum EvaDueBucket: String, Codable, Equatable, Hashable, CaseIterable {
    case today
    case tomorrow
    case thisWeek
    case someday
}

public struct EvaRationaleFactor: Codable, Equatable, Hashable {
    public let factor: String
    public let label: String
    public let contribution: Double

    /// Initializes a new instance.
    public init(factor: String, label: String, contribution: Double) {
        self.factor = factor
        self.label = label
        self.contribution = contribution
    }
}

public struct EvaFocusTaskInsight: Codable, Equatable, Hashable {
    public let taskID: UUID
    public let score: Double
    public let badge: String?
    public let rationale: [EvaRationaleFactor]

    /// Initializes a new instance.
    public init(
        taskID: UUID,
        score: Double,
        badge: String?,
        rationale: [EvaRationaleFactor]
    ) {
        self.taskID = taskID
        self.score = score
        self.badge = badge
        self.rationale = rationale
    }
}

public struct EvaFocusInsights: Codable, Equatable, Hashable {
    public let taskInsights: [EvaFocusTaskInsight]
    public let summaryLine: String?
    public let candidatePoolSize: Int

    /// Initializes a new instance.
    public init(taskInsights: [EvaFocusTaskInsight], summaryLine: String?, candidatePoolSize: Int) {
        self.taskInsights = taskInsights
        self.summaryLine = summaryLine
        self.candidatePoolSize = candidatePoolSize
    }
}

public struct EvaTriageSignal: Codable, Equatable, Hashable {
    public let promptLevel: EvaPromptLevel
    public let estimatedMinutes: Int
    public let untriagedCount: Int
    public let oldestAgeHours: Int

    /// Initializes a new instance.
    public init(promptLevel: EvaPromptLevel, estimatedMinutes: Int, untriagedCount: Int, oldestAgeHours: Int) {
        self.promptLevel = promptLevel
        self.estimatedMinutes = estimatedMinutes
        self.untriagedCount = untriagedCount
        self.oldestAgeHours = oldestAgeHours
    }
}

public struct EvaRescueSignal: Codable, Equatable, Hashable {
    public let promptLevel: EvaPromptLevel
    public let debtLevel: EvaDebtLevel
    public let debtScore: Double
    public let staleOverdueCount: Int

    /// Initializes a new instance.
    public init(
        promptLevel: EvaPromptLevel,
        debtLevel: EvaDebtLevel,
        debtScore: Double,
        staleOverdueCount: Int
    ) {
        self.promptLevel = promptLevel
        self.debtLevel = debtLevel
        self.debtScore = debtScore
        self.staleOverdueCount = staleOverdueCount
    }
}

public struct EvaHomeInsights: Codable, Equatable, Hashable {
    public let focus: EvaFocusInsights
    public let triage: EvaTriageSignal
    public let rescue: EvaRescueSignal
    public let generatedAt: Date

    /// Initializes a new instance.
    public init(focus: EvaFocusInsights, triage: EvaTriageSignal, rescue: EvaRescueSignal, generatedAt: Date) {
        self.focus = focus
        self.triage = triage
        self.rescue = rescue
        self.generatedAt = generatedAt
    }
}

public struct EvaTriageSuggestion: Codable, Equatable, Hashable {
    public let projectID: UUID?
    public let projectConfidence: Double
    public let dueBucket: EvaDueBucket?
    public let dueConfidence: Double
    public let durationSeconds: TimeInterval?
    public let durationConfidence: Double
    public let stateHint: String?

    /// Initializes a new instance.
    public init(
        projectID: UUID?,
        projectConfidence: Double,
        dueBucket: EvaDueBucket?,
        dueConfidence: Double,
        durationSeconds: TimeInterval?,
        durationConfidence: Double,
        stateHint: String?
    ) {
        self.projectID = projectID
        self.projectConfidence = projectConfidence
        self.dueBucket = dueBucket
        self.dueConfidence = dueConfidence
        self.durationSeconds = durationSeconds
        self.durationConfidence = durationConfidence
        self.stateHint = stateHint
    }
}

public struct EvaTriageQueueItem: Codable, Equatable, Hashable {
    public let task: TaskDefinition
    public let suggestions: EvaTriageSuggestion

    /// Initializes a new instance.
    public init(task: TaskDefinition, suggestions: EvaTriageSuggestion) {
        self.task = task
        self.suggestions = suggestions
    }
}

public enum EvaTriageScope: String, Codable, Equatable, Hashable, CaseIterable {
    case visible
    case allInbox
}

public enum EvaTriageDeferPreset: String, Codable, Equatable, Hashable, CaseIterable {
    case tomorrow
    case hours72
    case weekendSaturday

    /// Resolves deterministic defer date at local start-of-day.
    public func resolveDueDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        switch self {
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        case .hours72:
            let plus72 = calendar.date(byAdding: .hour, value: 72, to: now) ?? now
            return calendar.startOfDay(for: plus72)
        case .weekendSaturday:
            let weekday = calendar.component(.weekday, from: startOfToday)
            // Calendar weekday is 1=Sunday ... 7=Saturday.
            let daysUntilSaturday = (7 - weekday + 7) % 7
            let offset = daysUntilSaturday == 0 ? 7 : daysUntilSaturday
            return calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
        }
    }
}

public struct EvaTriageDecision: Codable, Equatable, Hashable {
    public var selectedProjectID: UUID?
    public var useSuggestedProject: Bool
    public var selectedDueDate: Date?
    public var clearDueDate: Bool
    public var useSuggestedDue: Bool
    public var selectedDurationSeconds: TimeInterval?
    public var clearDuration: Bool
    public var useSuggestedDuration: Bool
    public var stateHint: String?
    public var useSuggestedState: Bool
    public var deferPreset: EvaTriageDeferPreset?

    /// Initializes a new instance.
    public init(
        selectedProjectID: UUID? = nil,
        useSuggestedProject: Bool = false,
        selectedDueDate: Date? = nil,
        clearDueDate: Bool = false,
        useSuggestedDue: Bool = false,
        selectedDurationSeconds: TimeInterval? = nil,
        clearDuration: Bool = false,
        useSuggestedDuration: Bool = false,
        stateHint: String? = nil,
        useSuggestedState: Bool = false,
        deferPreset: EvaTriageDeferPreset? = nil
    ) {
        self.selectedProjectID = selectedProjectID
        self.useSuggestedProject = useSuggestedProject
        self.selectedDueDate = selectedDueDate
        self.clearDueDate = clearDueDate
        self.useSuggestedDue = useSuggestedDue
        self.selectedDurationSeconds = selectedDurationSeconds
        self.clearDuration = clearDuration
        self.useSuggestedDuration = useSuggestedDuration
        self.stateHint = stateHint
        self.useSuggestedState = useSuggestedState
        self.deferPreset = deferPreset
    }
}

public enum EvaSplitCreateStatus: String, Codable, Equatable, Hashable {
    case idle
    case creating
    case succeeded
    case failed
}

public struct EvaSplitDraftChild: Codable, Equatable, Hashable {
    public var title: String

    /// Initializes a new instance.
    public init(title: String) {
        self.title = title
    }
}

public struct EvaSplitDraft: Codable, Equatable, Hashable {
    public var parentTaskID: UUID
    public var children: [EvaSplitDraftChild]
    public var childDuePreset: EvaTriageDeferPreset?
    public var createStatus: EvaSplitCreateStatus
    public var createdChildIDs: [UUID]

    /// Initializes a new instance.
    public init(
        parentTaskID: UUID,
        children: [EvaSplitDraftChild] = [],
        childDuePreset: EvaTriageDeferPreset? = nil,
        createStatus: EvaSplitCreateStatus = .idle,
        createdChildIDs: [UUID] = []
    ) {
        self.parentTaskID = parentTaskID
        self.children = children
        self.childDuePreset = childDuePreset
        self.createStatus = createStatus
        self.createdChildIDs = createdChildIDs
    }
}

public enum EvaRescueActionType: String, Codable, Equatable, Hashable {
    case doToday
    case move
    case split
    case dropCandidate
}

public struct EvaRescueRecommendation: Codable, Equatable, Hashable {
    public let taskID: UUID
    public let action: EvaRescueActionType
    public let toDate: Date?
    public let reasons: [String]
    public let confidence: Double

    /// Initializes a new instance.
    public init(taskID: UUID, action: EvaRescueActionType, toDate: Date?, reasons: [String], confidence: Double) {
        self.taskID = taskID
        self.action = action
        self.toDate = toDate
        self.reasons = reasons
        self.confidence = confidence
    }
}

public struct EvaRescuePlan: Codable, Equatable, Hashable {
    public let debtScore: Double
    public let debtLevel: EvaDebtLevel
    public let doToday: [EvaRescueRecommendation]
    public let move: [EvaRescueRecommendation]
    public let split: [EvaRescueRecommendation]
    public let dropCandidate: [EvaRescueRecommendation]
    public let doTodayCap: Int

    /// Initializes a new instance.
    public init(
        debtScore: Double,
        debtLevel: EvaDebtLevel,
        doToday: [EvaRescueRecommendation],
        move: [EvaRescueRecommendation],
        split: [EvaRescueRecommendation],
        dropCandidate: [EvaRescueRecommendation],
        doTodayCap: Int
    ) {
        self.debtScore = debtScore
        self.debtLevel = debtLevel
        self.doToday = doToday
        self.move = move
        self.split = split
        self.dropCandidate = dropCandidate
        self.doTodayCap = doTodayCap
    }
}

public enum EvaBatchSource: String, Codable, Equatable, Hashable {
    case triage
    case rescue
}

public struct EvaBatchMutationInstruction: Codable, Equatable, Hashable {
    public let taskID: UUID
    public var projectID: UUID?
    public var dueDate: Date?
    public var clearDueDate: Bool
    public var estimatedDuration: TimeInterval?
    public var clearEstimatedDuration: Bool
    public var isComplete: Bool?

    /// Initializes a new instance.
    public init(
        taskID: UUID,
        projectID: UUID? = nil,
        dueDate: Date? = nil,
        clearDueDate: Bool = false,
        estimatedDuration: TimeInterval? = nil,
        clearEstimatedDuration: Bool = false,
        isComplete: Bool? = nil
    ) {
        self.taskID = taskID
        self.projectID = projectID
        self.dueDate = dueDate
        self.clearDueDate = clearDueDate
        self.estimatedDuration = estimatedDuration
        self.clearEstimatedDuration = clearEstimatedDuration
        self.isComplete = isComplete
    }
}

// MARK: - Eva Use Cases

private enum EvaHeuristicDebugOverride {
    static func double(_ key: String, fallback: Double) -> Double {
        #if DEBUG
        if let number = UserDefaults.standard.object(forKey: key) as? NSNumber {
            return number.doubleValue
        }
        #endif
        return fallback
    }

    static func int(_ key: String, fallback: Int) -> Int {
        #if DEBUG
        if UserDefaults.standard.object(forKey: key) != nil {
            return UserDefaults.standard.integer(forKey: key)
        }
        #endif
        return fallback
    }
}

public final class ComputeEvaHomeInsightsUseCase {
    private static let overdueWeightPerDay: Double = 1.4
    private static let dueTodayBoost: Double = 2.0
    private static let blockedPenalty: Double = 1.2
    private static let stalePenalty: Double = 0.8
    private static let quickWinBoost: Double = 1.0
    private static let staleDayThreshold: Int = 14

    private let habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol?

    /// Initializes a new instance.
    public init(habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol? = nil) {
        self.habitRuntimeReadRepository = habitRuntimeReadRepository
    }

    /// Executes execute.
    public func execute(
        openTasks: [TaskDefinition],
        focusTasks: [TaskDefinition],
        anchorDate: Date = Date(),
        now: Date = Date(),
        completion: @escaping (Result<EvaHomeInsights, Error>) -> Void
    ) {
        guard let habitRuntimeReadRepository else {
            completion(.success(
                buildInsights(
                    openTasks: openTasks,
                    focusTasks: focusTasks,
                    habitSignals: [],
                    anchorDate: anchorDate,
                    now: now
                )
            ))
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: anchorDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? anchorDate
        habitRuntimeReadRepository.fetchSignals(start: startOfDay, end: endOfDay) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let summaries):
                let signals = summaries.map {
                    TaskerHabitSignal(summary: $0, referenceDate: anchorDate)
                }
                completion(.success(
                    self.buildInsights(
                        openTasks: openTasks,
                        focusTasks: focusTasks,
                        habitSignals: signals,
                        anchorDate: anchorDate,
                        now: now
                    )
                ))
            }
        }
    }

    /// Executes execute.
    public func execute(
        openTasks: [TaskDefinition],
        focusTasks: [TaskDefinition],
        habitSignals: [TaskerHabitSignal] = [],
        anchorDate: Date = Date(),
        now: Date = Date()
    ) -> EvaHomeInsights {
        buildInsights(
            openTasks: openTasks,
            focusTasks: focusTasks,
            habitSignals: habitSignals,
            anchorDate: anchorDate,
            now: now
        )
    }

    private func buildInsights(
        openTasks: [TaskDefinition],
        focusTasks: [TaskDefinition],
        habitSignals: [TaskerHabitSignal],
        anchorDate: Date,
        now: Date
    ) -> EvaHomeInsights {
        let overdueWeightPerDay = EvaHeuristicDebugOverride.double(
            "debug.eva.focus.overdueWeightPerDay",
            fallback: Self.overdueWeightPerDay
        )
        let dueTodayBoost = EvaHeuristicDebugOverride.double(
            "debug.eva.focus.dueTodayBoost",
            fallback: Self.dueTodayBoost
        )
        let blockedPenalty = EvaHeuristicDebugOverride.double(
            "debug.eva.focus.blockedPenalty",
            fallback: Self.blockedPenalty
        )
        let stalePenalty = EvaHeuristicDebugOverride.double(
            "debug.eva.focus.stalePenalty",
            fallback: Self.stalePenalty
        )
        let quickWinBoost = EvaHeuristicDebugOverride.double(
            "debug.eva.focus.quickWinBoost",
            fallback: Self.quickWinBoost
        )
        let staleDayThreshold = EvaHeuristicDebugOverride.int(
            "debug.eva.focus.staleDayThreshold",
            fallback: Self.staleDayThreshold
        )

        let calendar = Calendar.current
        let startOfAnchorDay = calendar.startOfDay(for: anchorDate)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay) ?? startOfAnchorDay
        let inboxOpen = openTasks.filter { $0.projectID == ProjectConstants.inboxProjectID }
        let overdueOpen = openTasks.filter { ($0.dueDate ?? Date.distantFuture) < startOfAnchorDay }

        let focusInsights = focusTasks.map { task in
            let overdueDays = task.dueDate.map { max(0, calendar.dateComponents([.day], from: $0, to: startOfAnchorDay).day ?? 0) } ?? 0
            let dueToday = task.dueDate.map { $0 >= startOfAnchorDay && $0 < startOfNextDay } ?? false
            let urgency = Double(overdueDays) * overdueWeightPerDay + (dueToday ? dueTodayBoost : 0)
            let quickWin = (task.estimatedDuration ?? 0) > 0 && (task.estimatedDuration ?? 0) <= 1_800 ? quickWinBoost : 0
            let unblocked = task.dependencies.isEmpty ? 1.0 : -blockedPenalty
            let importance = Double(task.priority.scorePoints) * 0.6
            let staleDays = max(0, calendar.dateComponents([.day], from: task.updatedAt, to: now).day ?? 0)
            let freshness = staleDays >= staleDayThreshold ? -stalePenalty : 0.3
            let score = urgency + quickWin + unblocked + importance + freshness

            var factors: [EvaRationaleFactor] = [
                EvaRationaleFactor(
                    factor: "priority",
                    label: task.priority.isHighPriority ? "High priority" : "Priority \(task.priority.displayName)",
                    contribution: importance
                ),
                EvaRationaleFactor(
                    factor: "blocked",
                    label: task.dependencies.isEmpty ? "Unblocked" : "Has dependencies",
                    contribution: unblocked
                )
            ]
            if overdueDays > 0 {
                factors.append(EvaRationaleFactor(
                    factor: "overdue_days",
                    label: "Overdue by \(overdueDays)d",
                    contribution: Double(overdueDays) * overdueWeightPerDay
                ))
            } else if dueToday {
                factors.append(EvaRationaleFactor(
                    factor: "due_today",
                    label: "Due today",
                    contribution: dueTodayBoost
                ))
            }
            if quickWin > 0 {
                factors.append(EvaRationaleFactor(
                    factor: "quick_win",
                    label: "Quick win",
                    contribution: quickWin
                ))
            }
            factors.sort { $0.contribution > $1.contribution }
            factors = Array(factors.prefix(3))

            return EvaFocusTaskInsight(
                taskID: task.id,
                score: score,
                badge: focusBadge(for: task, anchorStart: startOfAnchorDay, anchorEnd: startOfNextDay),
                rationale: factors
            )
        }

        let summaryLine = focusSummaryLine(from: focusInsights, habitSignals: habitSignals)
        let triageSignal = buildTriageSignal(inboxOpen: inboxOpen, now: now)
        let rescueSignal = buildRescueSignal(overdueOpen: overdueOpen, now: now, anchorStart: startOfAnchorDay)

        return EvaHomeInsights(
            focus: EvaFocusInsights(taskInsights: focusInsights, summaryLine: summaryLine, candidatePoolSize: openTasks.count),
            triage: triageSignal,
            rescue: rescueSignal,
            generatedAt: now
        )
    }

    /// Executes focusBadge.
    private func focusBadge(for task: TaskDefinition, anchorStart: Date, anchorEnd: Date) -> String? {
        if let dueDate = task.dueDate, dueDate < anchorStart {
            return "Overdue"
        }
        if let dueDate = task.dueDate, dueDate >= anchorStart, dueDate < anchorEnd {
            return "Today"
        }
        if let estimated = task.estimatedDuration, estimated <= 1_800 {
            return "Quick win"
        }
        return task.dependencies.isEmpty ? "Unblocked" : nil
    }

    /// Executes focusSummaryLine.
    private func focusSummaryLine(from insights: [EvaFocusTaskInsight], habitSignals: [TaskerHabitSignal]) -> String? {
        var tagCounts: [String: Int] = [:]
        for insight in insights {
            for factor in insight.rationale {
                tagCounts[factor.label, default: 0] += 1
            }
        }
        let top = tagCounts.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key < $1.key
        }.prefix(3).map(\.key)
        var sections: [String] = []
        if top.isEmpty == false {
            sections.append("Eva picked for: " + top.joined(separator: " · "))
        }
        if let habitSummary = habitSummaryLine(from: habitSignals) {
            sections.append(habitSummary)
        }
        guard sections.isEmpty == false else { return nil }
        return sections.joined(separator: " | ")
    }

    private func habitSummaryLine(from habitSignals: [TaskerHabitSignal]) -> String? {
        guard habitSignals.isEmpty == false else { return nil }
        let dueCount = habitSignals.filter { $0.isDueToday || $0.isOverdue }.count
        let atRiskCount = habitSignals.filter {
            ($0.riskStateRaw?.lowercased().contains("risk") ?? false) || $0.isOverdue
        }.count
        let lapseCount = habitSignals.filter {
            guard let outcome = $0.outcomeRaw?.lowercased() else { return false }
            return outcome == "lapsed"
        }.count
        return "Habits: \(dueCount) due, \(atRiskCount) at risk, \(lapseCount) lapsed"
    }

    /// Executes buildTriageSignal.
    private func buildTriageSignal(inboxOpen: [TaskDefinition], now: Date) -> EvaTriageSignal {
        let bannerCountThreshold = EvaHeuristicDebugOverride.int("debug.eva.triage.bannerCountThreshold", fallback: 8)
        let bannerOldestHoursThreshold = EvaHeuristicDebugOverride.int("debug.eva.triage.bannerOldestHoursThreshold", fallback: 72)
        let microcopyCountThreshold = EvaHeuristicDebugOverride.int("debug.eva.triage.microcopyCountThreshold", fallback: 5)
        let microcopyOldestHoursThreshold = EvaHeuristicDebugOverride.int("debug.eva.triage.microcopyOldestHoursThreshold", fallback: 24)

        guard inboxOpen.isEmpty == false else {
            return EvaTriageSignal(promptLevel: .none, estimatedMinutes: 0, untriagedCount: 0, oldestAgeHours: 0)
        }
        let calendar = Calendar.current
        let untriagedCount = inboxOpen.filter { $0.dueDate == nil || $0.estimatedDuration == nil }.count
        let oldestCreatedAt = inboxOpen.map(\.createdAt).min() ?? now
        let oldestAgeHours = max(0, calendar.dateComponents([.hour], from: oldestCreatedAt, to: now).hour ?? 0)
        let estimatedMinutes = max(1, Int(ceil(Double(max(untriagedCount, inboxOpen.count)) * 0.35)))

        let promptLevel: EvaPromptLevel
        if inboxOpen.count >= bannerCountThreshold || (oldestAgeHours >= bannerOldestHoursThreshold && inboxOpen.count >= 3) {
            promptLevel = .banner
        } else if (inboxOpen.count >= 2 && untriagedCount >= 2) || oldestAgeHours >= microcopyOldestHoursThreshold || inboxOpen.count >= microcopyCountThreshold {
            promptLevel = .microcopy
        } else {
            promptLevel = .none
        }

        return EvaTriageSignal(
            promptLevel: promptLevel,
            estimatedMinutes: estimatedMinutes,
            untriagedCount: untriagedCount,
            oldestAgeHours: oldestAgeHours
        )
    }

    /// Executes buildRescueSignal.
    private func buildRescueSignal(overdueOpen: [TaskDefinition], now: Date, anchorStart: Date) -> EvaRescueSignal {
        let highDebtThreshold = EvaHeuristicDebugOverride.double("debug.eva.rescue.highDebtThreshold", fallback: 12)
        let mediumDebtThreshold = EvaHeuristicDebugOverride.double("debug.eva.rescue.mediumDebtThreshold", fallback: 6)

        guard overdueOpen.isEmpty == false else {
            return EvaRescueSignal(promptLevel: .none, debtLevel: .none, debtScore: 0, staleOverdueCount: 0)
        }
        let calendar = Calendar.current
        let staleOverdueCount = overdueOpen.filter {
            let staleDays = max(0, calendar.dateComponents([.day], from: $0.updatedAt, to: now).day ?? 0)
            return staleDays >= 7
        }.count

        let debt = overdueOpen.reduce(0.0) { partial, task in
            guard let dueDate = task.dueDate else { return partial }
            let overdueDays = max(0, calendar.dateComponents([.day], from: dueDate, to: anchorStart).day ?? 0)
            let base = min(10, overdueDays)
            let priorityWeight: Double
            switch task.priority {
            case .none: priorityWeight = 1.0
            case .low: priorityWeight = 1.1
            case .high: priorityWeight = 1.3
            case .max: priorityWeight = 1.5
            }
            let blockedPenalty = task.dependencies.isEmpty ? 0.0 : -0.5
            let durationPenalty = (task.estimatedDuration ?? 0) >= 3_600 ? 0.5 : 0
            let staleDays = max(0, calendar.dateComponents([.day], from: task.updatedAt, to: now).day ?? 0)
            let stalePenalty = staleDays >= 14 ? 0.5 : 0
            return partial + (Double(base) * priorityWeight) + blockedPenalty + durationPenalty + stalePenalty
        }

        let debtLevel: EvaDebtLevel
        if debt > highDebtThreshold {
            debtLevel = .high
        } else if debt >= mediumDebtThreshold {
            debtLevel = .medium
        } else {
            debtLevel = .low
        }

        let promptLevel: EvaPromptLevel
        if overdueOpen.count >= 3 || staleOverdueCount >= 1 || debtLevel == .high {
            promptLevel = .microcopy
        } else {
            promptLevel = .chip
        }

        return EvaRescueSignal(
            promptLevel: promptLevel,
            debtLevel: debtLevel,
            debtScore: debt,
            staleOverdueCount: staleOverdueCount
        )
    }
}

public final class GetInboxTriageQueueUseCase {
    private static let durationPresets: [TimeInterval] = [
        15 * 60,
        30 * 60,
        60 * 60,
        2 * 60 * 60,
        4 * 60 * 60
    ]

    private static let durationKeywordMap: [(tokens: [String], seconds: TimeInterval)] = [
        (["call", "reply", "email", "text", "ping", "follow up"], 15 * 60),
        (["review", "check", "scan", "triage"], 30 * 60),
        (["draft", "write", "outline", "plan"], 60 * 60),
        (["workshop", "presentation", "design", "architecture"], 2 * 60 * 60)
    ]

    /// Initializes a new instance.
    public init() {}

    /// Executes execute.
    public func execute(
        inboxTasks: [TaskDefinition],
        allTasks: [TaskDefinition],
        projects: [Project],
        maxItems: Int = 20,
        now: Date = Date()
    ) -> [EvaTriageQueueItem] {
        let queue = inboxTasks
            .filter { !$0.isComplete }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(maxItems)

        return queue.map { task in
            let projectSuggestion = suggestProject(for: task, allTasks: allTasks, projects: projects)
            let dueSuggestion = suggestDueBucket(for: task, now: now)
            let durationSuggestion = suggestDuration(for: task)
            let stateSuggestion = suggestStateHint(for: task)

            let suggestion = EvaTriageSuggestion(
                projectID: projectSuggestion.projectID,
                projectConfidence: projectSuggestion.confidence,
                dueBucket: dueSuggestion.bucket,
                dueConfidence: dueSuggestion.confidence,
                durationSeconds: durationSuggestion.seconds,
                durationConfidence: durationSuggestion.confidence,
                stateHint: stateSuggestion
            )
            return EvaTriageQueueItem(task: task, suggestions: suggestion)
        }
    }

    private func suggestProject(
        for task: TaskDefinition,
        allTasks: [TaskDefinition],
        projects: [Project]
    ) -> (projectID: UUID?, confidence: Double) {
        let customProjects = projects.filter { !$0.isInbox && $0.id != ProjectConstants.inboxProjectID }
        guard customProjects.isEmpty == false else { return (nil, 0) }
        let tokens = tokenize(task.title + " " + (task.details ?? ""))
        guard tokens.isEmpty == false else { return (nil, 0) }

        var scoreByProject: [UUID: Double] = [:]
        for historical in allTasks where historical.projectID != ProjectConstants.inboxProjectID {
            let historicalTokens = Set(tokenize(historical.title + " " + (historical.details ?? "")))
            let overlap = Double(tokens.filter { historicalTokens.contains($0) }.count)
            if overlap > 0 {
                scoreByProject[historical.projectID, default: 0] += overlap
            }
        }

        for project in customProjects {
            let projectTokens = Set(tokenize(project.name))
            let overlap = Double(tokens.filter { projectTokens.contains($0) }.count)
            if overlap > 0 {
                scoreByProject[project.id, default: 0] += overlap * 1.3
            }
        }

        if let top = scoreByProject.max(by: { $0.value < $1.value }) {
            let second = scoreByProject.filter { $0.key != top.key }.max(by: { $0.value < $1.value })?.value ?? 0
            let margin = top.value - second
            let confidence = min(0.95, max(0.30, 0.45 + (margin * 0.08)))
            return (top.key, confidence)
        }

        let recentTasks = allTasks
            .filter { !$0.isComplete && $0.projectID != ProjectConstants.inboxProjectID }
            .sorted { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
        if let fallbackProjectID = recentTasks.first?.projectID {
            return (fallbackProjectID, 0.38)
        }

        if customProjects.count == 1, let only = customProjects.first {
            return (only.id, 0.34)
        }

        return (nil, 0)
    }

    private func suggestDueBucket(for task: TaskDefinition, now: Date) -> (bucket: EvaDueBucket?, confidence: Double) {
        let calendar = Calendar.current
        let text = (task.title + " " + (task.details ?? "")).lowercased()
        if text.contains("today") || text.contains("eod") {
            return (.today, 0.90)
        }
        if text.contains("tomorrow") {
            return (.tomorrow, 0.92)
        }
        if text.contains("this week") || text.contains("week") {
            return (.thisWeek, 0.80)
        }
        if text.contains("asap") || text.contains("urgent") || text.contains("now") {
            return (.today, 0.62)
        }

        if let dueDate = task.dueDate {
            let startOfToday = calendar.startOfDay(for: now)
            if dueDate < startOfToday {
                return (.today, 0.86)
            }
            if calendar.isDateInToday(dueDate) {
                return (.today, 0.95)
            }
            if calendar.isDateInTomorrow(dueDate) {
                return (.tomorrow, 0.95)
            }
            let withinWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
            if dueDate < withinWeek {
                return (.thisWeek, 0.78)
            }
        }

        let ageDays = max(0, calendar.dateComponents([.day], from: task.createdAt, to: now).day ?? 0)
        if task.priority == .high || task.priority == .max {
            return (.today, 0.56)
        }
        if task.dueDate == nil && ageDays >= 7 {
            return (.thisWeek, 0.58)
        }
        if task.dueDate == nil && ageDays >= 2 {
            return (.tomorrow, 0.42)
        }
        return (.thisWeek, 0.33)
    }

    private func suggestDuration(for task: TaskDefinition) -> (seconds: TimeInterval?, confidence: Double) {
        if let estimatedDuration = task.estimatedDuration, estimatedDuration > 0 {
            return (nearestDurationPreset(to: estimatedDuration), 0.95)
        }
        let text = (task.title + " " + (task.details ?? "")).lowercased()
        for entry in Self.durationKeywordMap where entry.tokens.contains(where: { text.contains($0) }) {
            return (nearestDurationPreset(to: entry.seconds), 0.72)
        }
        if task.priority == .high || task.priority == .max {
            return (30 * 60, 0.46)
        }
        if (task.details ?? "").count > 120 {
            return (60 * 60, 0.44)
        }
        return (15 * 60, 0.34)
    }

    private func suggestStateHint(for task: TaskDefinition) -> String? {
        if !task.dependencies.isEmpty {
            return "blocked"
        }
        let text = (task.title + " " + (task.details ?? "")).lowercased()
        if text.contains("waiting") || text.contains("awaiting") || text.contains("follow up") {
            return "waiting"
        }
        return nil
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }

    private func nearestDurationPreset(to duration: TimeInterval) -> TimeInterval {
        Self.durationPresets.min(by: { abs($0 - duration) < abs($1 - duration) }) ?? (15 * 60)
    }
}

public final class GetOverdueRescuePlanUseCase {
    /// Initializes a new instance.
    public init() {}

    /// Executes execute.
    public func execute(
        overdueTasks: [TaskDefinition],
        now: Date = Date(),
        doTodayCap: Int = 3
    ) -> EvaRescuePlan {
        let effectiveDoTodayCap = max(
            1,
            EvaHeuristicDebugOverride.int("debug.eva.rescue.doTodayCap", fallback: doTodayCap)
        )
        let openOverdue = overdueTasks.filter { !$0.isComplete && $0.isOverdue }
        guard openOverdue.isEmpty == false else {
            return EvaRescuePlan(
                debtScore: 0,
                debtLevel: .none,
                doToday: [],
                move: [],
                split: [],
                dropCandidate: [],
                doTodayCap: effectiveDoTodayCap
            )
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        var doToday: [EvaRescueRecommendation] = []
        var move: [EvaRescueRecommendation] = []
        var split: [EvaRescueRecommendation] = []
        var drop: [EvaRescueRecommendation] = []
        var debtTotal = 0.0

        for task in openOverdue {
            let overdueDays = max(0, calendar.dateComponents([.day], from: task.dueDate ?? startOfToday, to: startOfToday).day ?? 0)
            let staleDays = max(0, calendar.dateComponents([.day], from: task.updatedAt, to: now).day ?? 0)
            let isBlocked = !task.dependencies.isEmpty
            let isLong = (task.estimatedDuration ?? 0) >= 3_600
            let isQuick = (task.estimatedDuration ?? 0) > 0 && (task.estimatedDuration ?? 0) <= 1_800

            let priorityWeight: Double
            switch task.priority {
            case .none: priorityWeight = 1.0
            case .low: priorityWeight = 1.2
            case .high: priorityWeight = 1.35
            case .max: priorityWeight = 1.5
            }
            debtTotal += (Double(min(10, overdueDays)) * priorityWeight)
                + (isLong ? 0.5 : 0)
                + (staleDays >= 14 ? 0.5 : 0)
                + (isBlocked ? -0.5 : 0)

            if staleDays >= 14 {
                drop.append(EvaRescueRecommendation(
                    taskID: task.id,
                    action: .dropCandidate,
                    toDate: nil,
                    reasons: ["No updates for \(staleDays)d", "Overdue \(overdueDays)d"],
                    confidence: 0.60
                ))
                continue
            }

            if isBlocked {
                split.append(EvaRescueRecommendation(
                    taskID: task.id,
                    action: .split,
                    toDate: nil,
                    reasons: ["Blocked by dependencies", "Overdue \(overdueDays)d"],
                    confidence: 0.66
                ))
                continue
            }

            if overdueDays <= 1 && isQuick {
                doToday.append(EvaRescueRecommendation(
                    taskID: task.id,
                    action: .doToday,
                    toDate: task.dueDate ?? startOfToday,
                    reasons: ["Quick win", "Overdue \(overdueDays)d"],
                    confidence: 0.78
                ))
            } else if overdueDays >= 3 && isLong {
                let suggestedDate = calendar.date(byAdding: .day, value: 1, to: startOfToday)
                move.append(EvaRescueRecommendation(
                    taskID: task.id,
                    action: .move,
                    toDate: suggestedDate,
                    reasons: ["Long task", "Overdue \(overdueDays)d"],
                    confidence: 0.72
                ))
            } else {
                let suggestedDate = calendar.date(byAdding: .day, value: 1, to: startOfToday)
                move.append(EvaRescueRecommendation(
                    taskID: task.id,
                    action: .move,
                    toDate: suggestedDate,
                    reasons: ["Recover gradually", "Overdue \(overdueDays)d"],
                    confidence: 0.65
                ))
            }
        }

        if doToday.count > effectiveDoTodayCap {
            let overflow = doToday.dropFirst(effectiveDoTodayCap)
            doToday = Array(doToday.prefix(effectiveDoTodayCap))
            move.append(contentsOf: overflow.map {
                EvaRescueRecommendation(
                    taskID: $0.taskID,
                    action: .move,
                    toDate: Calendar.current.date(byAdding: .day, value: 1, to: startOfToday),
                    reasons: ["Daily cap", "Avoid overload"],
                    confidence: 0.62
                )
            })
        }

        let debtLevel: EvaDebtLevel
        if debtTotal > 12 {
            debtLevel = .high
        } else if debtTotal >= 6 {
            debtLevel = .medium
        } else {
            debtLevel = .low
        }

        doToday.sort { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.taskID.uuidString < rhs.taskID.uuidString
        }
        move.sort { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.taskID.uuidString < rhs.taskID.uuidString
        }
        split.sort { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.taskID.uuidString < rhs.taskID.uuidString
        }
        drop.sort { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.taskID.uuidString < rhs.taskID.uuidString
        }

        return EvaRescuePlan(
            debtScore: debtTotal,
            debtLevel: debtLevel,
            doToday: doToday,
            move: move,
            split: split,
            dropCandidate: drop,
            doTodayCap: effectiveDoTodayCap
        )
    }
}

public final class BuildEvaBatchProposalUseCase {
    /// Initializes a new instance.
    public init() {}

    /// Executes execute.
    public func execute(
        source: EvaBatchSource,
        tasksByID: [UUID: TaskDefinition],
        mutations: [EvaBatchMutationInstruction],
        now: Date = Date()
    ) -> (threadID: String, envelope: AssistantCommandEnvelope) {
        var commands: [AssistantCommand] = []
        commands.reserveCapacity(mutations.count)

        for mutation in mutations {
            guard var task = tasksByID[mutation.taskID] else { continue }
            if let projectID = mutation.projectID {
                task.projectID = projectID
                if projectID == ProjectConstants.inboxProjectID {
                    task.projectName = ProjectConstants.inboxProjectName
                }
            }
            if mutation.clearDueDate {
                task.dueDate = nil
            } else if let dueDate = mutation.dueDate {
                task.dueDate = dueDate
            }
            if mutation.clearEstimatedDuration {
                task.estimatedDuration = nil
            } else if let estimatedDuration = mutation.estimatedDuration {
                task.estimatedDuration = estimatedDuration
            }
            if let isComplete = mutation.isComplete {
                task.isComplete = isComplete
                task.dateCompleted = isComplete ? now : nil
            }
            task.updatedAt = now
            commands.append(.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task)))
        }

        let envelope = AssistantCommandEnvelope(
            schemaVersion: 2,
            commands: commands,
            rationaleText: "Eva \(source.rawValue) deterministic batch plan"
        )
        let threadID = "eva_\(source.rawValue)_\(Int(now.timeIntervalSince1970))"
        return (threadID, envelope)
    }
}
