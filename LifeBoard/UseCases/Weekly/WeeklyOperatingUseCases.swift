import Foundation

private enum WeeklyUseCaseCalendar {
    static func configuredWeekStartDay(
        preferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) -> Weekday {
        preferencesStore.load().weekStartsOn
    }

    static func normalizedWeekStart(
        for date: Date,
        preferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) -> Date {
        XPCalculationEngine.startOfWeek(
            for: date,
            startingOn: configuredWeekStartDay(preferencesStore: preferencesStore)
        )
    }

    static func normalizedWeekEnd(
        for weekStartDate: Date,
        preferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) -> Date {
        XPCalculationEngine.endOfWeek(
            for: weekStartDate,
            startingOn: configuredWeekStartDay(preferencesStore: preferencesStore)
        )
    }

    static func nextWeekStart(
        after date: Date,
        preferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) -> Date {
        XPCalculationEngine.upcomingWeekStart(
            after: date,
            startingOn: configuredWeekStartDay(preferencesStore: preferencesStore)
        )
    }

    static func isInUpcomingPlanningWindow(
        referenceDate: Date,
        preferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) -> Bool {
        let weekStartsOn = configuredWeekStartDay(preferencesStore: preferencesStore)
        let calendar = XPCalculationEngine.weekCalendar(startingOn: weekStartsOn)
        let currentWeekStart = XPCalculationEngine.startOfWeek(
            for: referenceDate,
            startingOn: weekStartsOn,
            calendar: calendar
        )
        let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
        let planningWindowStart = calendar.date(byAdding: .day, value: -2, to: nextWeekStart) ?? currentWeekStart
        let day = calendar.startOfDay(for: referenceDate)
        return day >= planningWindowStart && day < nextWeekStart
    }
}

private final class WeeklyPlanSnapshotBuildState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedError: Error?
    private var outcomes: [WeeklyOutcome] = []
    private var review: WeeklyReview?
    private var thisWeekTasks: [TaskDefinition] = []
    private var nextWeekTasks: [TaskDefinition] = []
    private var laterTasks: [TaskDefinition] = []
    private var reflectionNotes: [ReflectionNote] = []

    func recordError(_ error: Error) {
        lock.lock()
        if storedError == nil {
            storedError = error
        }
        lock.unlock()
    }

    func setOutcomes(_ value: [WeeklyOutcome]) {
        lock.lock()
        outcomes = value
        lock.unlock()
    }

    func setReview(_ value: WeeklyReview?) {
        lock.lock()
        review = value
        lock.unlock()
    }

    func setTasks(_ value: [TaskDefinition], bucket: TaskPlanningBucket) {
        lock.lock()
        switch bucket {
        case .thisWeek:
            thisWeekTasks = value
        case .nextWeek:
            nextWeekTasks = value
        case .later:
            laterTasks = value
        case .today, .someday:
            break
        }
        lock.unlock()
    }

    func setReflectionNotes(_ value: [ReflectionNote]) {
        lock.lock()
        reflectionNotes = value
        lock.unlock()
    }

    func result(weekStart: Date, plan: WeeklyPlan?) -> Result<WeeklyPlanSnapshot, Error> {
        lock.lock()
        let error = storedError
        let snapshot = WeeklyPlanSnapshot(
            weekStartDate: weekStart,
            plan: plan,
            outcomes: outcomes,
            review: review,
            thisWeekTasks: thisWeekTasks,
            nextWeekTasks: nextWeekTasks,
            laterTasks: laterTasks,
            reflectionNotes: reflectionNotes
        )
        lock.unlock()

        if let error {
            return .failure(error)
        }
        return .success(snapshot)
    }
}

public enum WeeklyHomeCTAState: String, Equatable, Sendable {
    case planThisWeek
    case planUpcomingWeek
    case reviewWeek
}

public enum WeeklyPlannerPresentationMode: String, Equatable, Sendable {
    case thisWeek
    case upcomingWeek
}

public struct HomeWeeklySummary: Equatable, Sendable {
    public let weekStartDate: Date
    public let ctaState: WeeklyHomeCTAState
    public let plannerPresentation: WeeklyPlannerPresentationMode
    public let outcomeCount: Int
    public let thisWeekTaskCount: Int
    public let completedThisWeekTaskCount: Int
    public let overCapacityCount: Int
    public let reviewCompleted: Bool

    public init(
        weekStartDate: Date,
        ctaState: WeeklyHomeCTAState,
        plannerPresentation: WeeklyPlannerPresentationMode,
        outcomeCount: Int,
        thisWeekTaskCount: Int,
        completedThisWeekTaskCount: Int,
        overCapacityCount: Int,
        reviewCompleted: Bool
    ) {
        self.weekStartDate = weekStartDate
        self.ctaState = ctaState
        self.plannerPresentation = plannerPresentation
        self.outcomeCount = outcomeCount
        self.thisWeekTaskCount = thisWeekTaskCount
        self.completedThisWeekTaskCount = completedThisWeekTaskCount
        self.overCapacityCount = overCapacityCount
        self.reviewCompleted = reviewCompleted
    }
}

public struct WeeklyPlanSnapshot: Equatable, Sendable {
    public let weekStartDate: Date
    public let plan: WeeklyPlan?
    public let outcomes: [WeeklyOutcome]
    public let review: WeeklyReview?
    public let thisWeekTasks: [TaskDefinition]
    public let nextWeekTasks: [TaskDefinition]
    public let laterTasks: [TaskDefinition]
    public let reflectionNotes: [ReflectionNote]

    public init(
        weekStartDate: Date,
        plan: WeeklyPlan?,
        outcomes: [WeeklyOutcome],
        review: WeeklyReview?,
        thisWeekTasks: [TaskDefinition],
        nextWeekTasks: [TaskDefinition],
        laterTasks: [TaskDefinition],
        reflectionNotes: [ReflectionNote]
    ) {
        self.weekStartDate = weekStartDate
        self.plan = plan
        self.outcomes = outcomes
        self.review = review
        self.thisWeekTasks = thisWeekTasks
        self.nextWeekTasks = nextWeekTasks
        self.laterTasks = laterTasks
        self.reflectionNotes = reflectionNotes
    }
}

public struct RecoveryInsights: Equatable, Sendable {
    public let headline: String
    public let carryForwardCount: Int
    public let laterCount: Int
    public let droppedCount: Int
    public let narrative: String

    public init(
        headline: String,
        carryForwardCount: Int,
        laterCount: Int,
        droppedCount: Int,
        narrative: String
    ) {
        self.headline = headline
        self.carryForwardCount = carryForwardCount
        self.laterCount = laterCount
        self.droppedCount = droppedCount
        self.narrative = narrative
    }
}

public enum WeeklyReviewTaskDisposition: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case carry
    case later
    case drop
}

public struct WeeklyReviewTaskDecision: Codable, Equatable, Hashable, Sendable {
    public let taskID: UUID
    public let disposition: WeeklyReviewTaskDisposition

    public init(taskID: UUID, disposition: WeeklyReviewTaskDisposition) {
        self.taskID = taskID
        self.disposition = disposition
    }
}

public struct CompleteWeeklyReviewRequest: Equatable, Sendable {
    public let weeklyPlanID: UUID
    public let wins: String?
    public let blockers: String?
    public let lessons: String?
    public let nextWeekPrepNotes: String?
    public let perceivedWeekRating: Int?
    public let taskDecisions: [WeeklyReviewTaskDecision]
    public let outcomeStatusesByOutcomeID: [UUID: WeeklyOutcomeStatus]
    public let completedAt: Date

    public init(
        weeklyPlanID: UUID,
        wins: String? = nil,
        blockers: String? = nil,
        lessons: String? = nil,
        nextWeekPrepNotes: String? = nil,
        perceivedWeekRating: Int? = nil,
        taskDecisions: [WeeklyReviewTaskDecision] = [],
        outcomeStatusesByOutcomeID: [UUID: WeeklyOutcomeStatus] = [:],
        completedAt: Date = Date()
    ) {
        self.weeklyPlanID = weeklyPlanID
        self.wins = wins
        self.blockers = blockers
        self.lessons = lessons
        self.nextWeekPrepNotes = nextWeekPrepNotes
        self.perceivedWeekRating = perceivedWeekRating
        self.taskDecisions = taskDecisions
        self.outcomeStatusesByOutcomeID = outcomeStatusesByOutcomeID
        self.completedAt = completedAt
    }
}

public struct CompleteWeeklyReviewResult: Equatable, Sendable {
    public let review: WeeklyReview
    public let skippedTaskIDs: [UUID]
    public let skippedOutcomeIDs: [UUID]

    public init(
        review: WeeklyReview,
        skippedTaskIDs: [UUID] = [],
        skippedOutcomeIDs: [UUID] = []
    ) {
        self.review = review
        self.skippedTaskIDs = skippedTaskIDs
        self.skippedOutcomeIDs = skippedOutcomeIDs
    }
}

public struct SaveWeeklyPlanOutcomeInput: Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var sourceProjectID: UUID?
    public var whyItMatters: String?
    public var successDefinition: String?

    public init(
        id: UUID = UUID(),
        title: String,
        sourceProjectID: UUID? = nil,
        whyItMatters: String? = nil,
        successDefinition: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceProjectID = sourceProjectID
        self.whyItMatters = whyItMatters
        self.successDefinition = successDefinition
    }
}

public struct SaveWeeklyPlanTaskAssignment: Equatable, Hashable, Sendable {
    public let task: TaskDefinition
    public let planningBucket: TaskPlanningBucket
    public let weeklyOutcomeID: UUID?

    public init(
        task: TaskDefinition,
        planningBucket: TaskPlanningBucket,
        weeklyOutcomeID: UUID? = nil
    ) {
        self.task = task
        self.planningBucket = planningBucket
        self.weeklyOutcomeID = planningBucket == .thisWeek ? weeklyOutcomeID : nil
    }
}

public struct SaveWeeklyPlanRequest: Equatable, Sendable {
    public let weekStartDate: Date
    public let focusStatement: String?
    public let selectedHabitIDs: [UUID]
    public let targetCapacity: Int?
    public let minimumViableWeekEnabled: Bool
    public let outcomes: [SaveWeeklyPlanOutcomeInput]
    public let taskAssignments: [SaveWeeklyPlanTaskAssignment]
    public let savedAt: Date

    public init(
        weekStartDate: Date,
        focusStatement: String? = nil,
        selectedHabitIDs: [UUID] = [],
        targetCapacity: Int? = nil,
        minimumViableWeekEnabled: Bool = false,
        outcomes: [SaveWeeklyPlanOutcomeInput] = [],
        taskAssignments: [SaveWeeklyPlanTaskAssignment] = [],
        savedAt: Date = Date()
    ) {
        self.weekStartDate = weekStartDate
        self.focusStatement = focusStatement
        self.selectedHabitIDs = selectedHabitIDs
        self.targetCapacity = targetCapacity
        self.minimumViableWeekEnabled = minimumViableWeekEnabled
        self.outcomes = outcomes
        self.taskAssignments = taskAssignments
        self.savedAt = savedAt
    }
}

private struct WeeklyHomeSurfaceResolution {
    let weekStartDate: Date
    let ctaState: WeeklyHomeCTAState
    let plannerPresentation: WeeklyPlannerPresentationMode
}

public final class BuildWeeklyPlanSnapshotUseCase: @unchecked Sendable {
    private let weeklyPlanRepository: WeeklyPlanRepositoryProtocol
    private let weeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol
    private let weeklyReviewRepository: WeeklyReviewRepositoryProtocol
    private let reflectionNoteRepository: ReflectionNoteRepositoryProtocol
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    private let taskDefinitionRepository: TaskDefinitionRepositoryProtocol
    private let workspacePreferencesStore: LifeBoardWorkspacePreferencesStore

    public init(
        weeklyPlanRepository: WeeklyPlanRepositoryProtocol,
        weeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol,
        weeklyReviewRepository: WeeklyReviewRepositoryProtocol,
        reflectionNoteRepository: ReflectionNoteRepositoryProtocol,
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        taskDefinitionRepository: TaskDefinitionRepositoryProtocol,
        workspacePreferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) {
        self.weeklyPlanRepository = weeklyPlanRepository
        self.weeklyOutcomeRepository = weeklyOutcomeRepository
        self.weeklyReviewRepository = weeklyReviewRepository
        self.reflectionNoteRepository = reflectionNoteRepository
        self.taskReadModelRepository = taskReadModelRepository
        self.taskDefinitionRepository = taskDefinitionRepository
        self.workspacePreferencesStore = workspacePreferencesStore
    }

    public func execute(
        referenceDate: Date = Date(),
        completion: @escaping @Sendable (Result<WeeklyPlanSnapshot, Error>) -> Void
    ) {
        let weekStart = WeeklyUseCaseCalendar.normalizedWeekStart(
            for: referenceDate,
            preferencesStore: workspacePreferencesStore
        )
        weeklyPlanRepository.fetchPlan(forWeekStarting: weekStart) { planResult in
            switch planResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let plan):
                self.buildSnapshot(
                    weekStart: weekStart,
                    plan: plan,
                    completion: completion
                )
            }
        }
    }

    private func buildSnapshot(
        weekStart: Date,
        plan: WeeklyPlan?,
        completion: @escaping @Sendable (Result<WeeklyPlanSnapshot, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let state = WeeklyPlanSnapshotBuildState()

        if let plan {
            group.enter()
            weeklyOutcomeRepository.fetchOutcomes(weeklyPlanID: plan.id) { result in
                if case .success(let fetched) = result {
                    state.setOutcomes(fetched)
                } else if case .failure(let error) = result {
                    state.recordError(error)
                }
                group.leave()
            }

            group.enter()
            weeklyReviewRepository.fetchReview(weeklyPlanID: plan.id) { result in
                if case .success(let fetched) = result {
                    state.setReview(fetched)
                } else if case .failure(let error) = result {
                    state.recordError(error)
                }
                group.leave()
            }

            group.enter()
            reflectionNoteRepository.fetchNotes(
                query: ReflectionNoteQuery(linkedWeeklyPlanID: plan.id, limit: 12)
            ) { result in
                if case .success(let fetched) = result {
                    state.setReflectionNotes(fetched)
                } else if case .failure(let error) = result {
                    state.recordError(error)
                }
                group.leave()
            }
        }

        loadTasks(bucket: .thisWeek, state: state, group: group)
        loadTasks(bucket: .nextWeek, state: state, group: group)
        loadTasks(bucket: .later, state: state, group: group)

        group.notify(queue: .main) {
            completion(state.result(weekStart: weekStart, plan: plan))
        }
    }

    private func loadTasks(
        bucket: TaskPlanningBucket,
        state: WeeklyPlanSnapshotBuildState,
        group: DispatchGroup
    ) {
        group.enter()
        let completionBlock: @Sendable (Result<[TaskDefinition], Error>) -> Void = { result in
            if case .success(let tasks) = result {
                state.setTasks(tasks, bucket: bucket)
            } else if case .failure(let error) = result {
                state.recordError(error)
            }
            group.leave()
        }

        if let taskReadModelRepository {
            taskReadModelRepository.fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    planningBuckets: [bucket],
                    sortBy: .dueDateAscending,
                    limit: 400,
                    offset: 0
                )
            ) { result in
                completionBlock(result.map(\.tasks))
            }
            return
        }

        taskDefinitionRepository.fetchAll(
            query: TaskDefinitionQuery(
                includeCompleted: true,
                planningBuckets: [bucket]
            ),
            completion: completionBlock
        )
    }
}

public final class EstimateWeeklyCapacityUseCase: @unchecked Sendable {
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    private let taskDefinitionRepository: TaskDefinitionRepositoryProtocol
    private let workspacePreferencesStore: LifeBoardWorkspacePreferencesStore

    public init(
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        taskDefinitionRepository: TaskDefinitionRepositoryProtocol,
        workspacePreferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) {
        self.taskReadModelRepository = taskReadModelRepository
        self.taskDefinitionRepository = taskDefinitionRepository
        self.workspacePreferencesStore = workspacePreferencesStore
    }

    public func execute(referenceDate: Date = Date(), completion: @escaping @Sendable (Result<Int, Error>) -> Void) {
        let weekStartsOn = WeeklyUseCaseCalendar.configuredWeekStartDay(preferencesStore: workspacePreferencesStore)
        let calendar = XPCalculationEngine.weekCalendar(startingOn: weekStartsOn)
        let currentWeekStart = XPCalculationEngine.startOfWeek(
            for: referenceDate,
            startingOn: weekStartsOn,
            calendar: calendar
        )
        let windowStart = calendar.date(byAdding: .day, value: -28, to: currentWeekStart) ?? currentWeekStart

        fetchRecentTasks(updatedAfter: windowStart) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let tasks):
                let recentCompleted = tasks.filter { task in
                    guard task.isComplete, let completedAt = task.dateCompleted else { return false }
                    return completedAt >= windowStart && completedAt < currentWeekStart
                }
                let windowDayCount = max(
                    1,
                    calendar.dateComponents([.day], from: windowStart, to: currentWeekStart).day ?? 0
                )
                let weekCount = max(1, Int(ceil(Double(windowDayCount) / 7.0)))
                let estimatedCapacity = max(3, Int(round(Double(recentCompleted.count) / Double(weekCount))))
                completion(.success(estimatedCapacity))
            }
        }
    }

    private func fetchRecentTasks(
        updatedAfter: Date,
        completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void
    ) {
        if let taskReadModelRepository {
            taskReadModelRepository.fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    updatedAfter: updatedAfter,
                    sortBy: .updatedAtDescending,
                    limit: 800,
                    offset: 0
                )
            ) { result in
                completion(result.map(\.tasks))
            }
            return
        }

        taskDefinitionRepository.fetchAll(
            query: TaskDefinitionQuery(
                includeCompleted: true,
                updatedAfter: updatedAfter
            ),
            completion: completion
        )
    }
}

public final class GetWeeklySummaryUseCase: @unchecked Sendable {
    private let buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase
    private let estimateWeeklyCapacity: EstimateWeeklyCapacityUseCase
    private let workspacePreferencesStore: LifeBoardWorkspacePreferencesStore

    public init(
        buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase,
        estimateWeeklyCapacity: EstimateWeeklyCapacityUseCase,
        workspacePreferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) {
        self.buildWeeklyPlanSnapshot = buildWeeklyPlanSnapshot
        self.estimateWeeklyCapacity = estimateWeeklyCapacity
        self.workspacePreferencesStore = workspacePreferencesStore
    }

    public func execute(
        referenceDate: Date = Date(),
        completion: @escaping @Sendable (Result<HomeWeeklySummary, Error>) -> Void
    ) {
        let currentWeekStart = WeeklyUseCaseCalendar.normalizedWeekStart(
            for: referenceDate,
            preferencesStore: workspacePreferencesStore
        )

        buildWeeklyPlanSnapshot.execute(referenceDate: currentWeekStart) { snapshotResult in
            switch snapshotResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let currentSnapshot):
                let resolution = self.resolveHomeSurface(
                    currentSnapshot: currentSnapshot,
                    referenceDate: referenceDate
                )

                self.buildWeeklyPlanSnapshot.execute(referenceDate: resolution.weekStartDate) { targetSnapshotResult in
                    switch targetSnapshotResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let targetSnapshot):
                        self.estimateWeeklyCapacity.execute(referenceDate: resolution.weekStartDate) { capacityResult in
                            switch capacityResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success(let estimatedCapacity):
                                let completedCount = targetSnapshot.thisWeekTasks.filter(\.isComplete).count
                                let openCount = targetSnapshot.thisWeekTasks.filter { !$0.isComplete }.count
                                let overCapacityCount = max(0, openCount - estimatedCapacity)
                                let reviewCompleted = targetSnapshot.review?.completedAt != nil
                                    || targetSnapshot.plan?.reviewStatus == .completed

                                completion(.success(HomeWeeklySummary(
                                    weekStartDate: targetSnapshot.weekStartDate,
                                    ctaState: resolution.ctaState,
                                    plannerPresentation: resolution.plannerPresentation,
                                    outcomeCount: targetSnapshot.outcomes.count,
                                    thisWeekTaskCount: openCount,
                                    completedThisWeekTaskCount: completedCount,
                                    overCapacityCount: overCapacityCount,
                                    reviewCompleted: reviewCompleted
                                )))
                            }
                        }
                    }
                }
            }
        }
    }

    private func resolveHomeSurface(
        currentSnapshot: WeeklyPlanSnapshot,
        referenceDate: Date
    ) -> WeeklyHomeSurfaceResolution {
        let reviewCompleted = currentSnapshot.review?.completedAt != nil
            || currentSnapshot.plan?.reviewStatus == .completed
        let inUpcomingPlanningWindow = WeeklyUseCaseCalendar.isInUpcomingPlanningWindow(
            referenceDate: referenceDate,
            preferencesStore: workspacePreferencesStore
        )

        if inUpcomingPlanningWindow {
            if currentSnapshot.plan != nil, reviewCompleted == false {
                return WeeklyHomeSurfaceResolution(
                    weekStartDate: currentSnapshot.weekStartDate,
                    ctaState: .reviewWeek,
                    plannerPresentation: .thisWeek
                )
            }

            return WeeklyHomeSurfaceResolution(
                weekStartDate: WeeklyUseCaseCalendar.nextWeekStart(
                    after: referenceDate,
                    preferencesStore: workspacePreferencesStore
                ),
                ctaState: .planUpcomingWeek,
                plannerPresentation: .upcomingWeek
            )
        }

        return WeeklyHomeSurfaceResolution(
            weekStartDate: currentSnapshot.weekStartDate,
            ctaState: .planThisWeek,
            plannerPresentation: .thisWeek
        )
    }
}

public final class SaveWeeklyPlanUseCase: @unchecked Sendable {
    private let weeklyPlanRepository: WeeklyPlanRepositoryProtocol
    private let weeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol
    private let updateTaskDefinitionUseCase: UpdateTaskDefinitionUseCase
    private let taskDefinitionRepository: TaskDefinitionRepositoryProtocol
    private let workspacePreferencesStore: LifeBoardWorkspacePreferencesStore

    public init(
        weeklyPlanRepository: WeeklyPlanRepositoryProtocol,
        weeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol,
        updateTaskDefinitionUseCase: UpdateTaskDefinitionUseCase,
        taskDefinitionRepository: TaskDefinitionRepositoryProtocol,
        workspacePreferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) {
        self.weeklyPlanRepository = weeklyPlanRepository
        self.weeklyOutcomeRepository = weeklyOutcomeRepository
        self.updateTaskDefinitionUseCase = updateTaskDefinitionUseCase
        self.taskDefinitionRepository = taskDefinitionRepository
        self.workspacePreferencesStore = workspacePreferencesStore
    }

    public func execute(
        request: SaveWeeklyPlanRequest,
        completion: @escaping @Sendable (Result<WeeklyPlan, Error>) -> Void
    ) {
        let normalizedWeekStart = WeeklyUseCaseCalendar.normalizedWeekStart(
            for: request.weekStartDate,
            preferencesStore: workspacePreferencesStore
        )
        weeklyPlanRepository.fetchPlan(forWeekStarting: normalizedWeekStart) { planResult in
            switch planResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let existingPlan):
                self.persistPlan(
                    weekStartDate: normalizedWeekStart,
                    existingPlan: existingPlan,
                    request: request,
                    completion: completion
                )
            }
        }
    }

    private func persistPlan(
        weekStartDate: Date,
        existingPlan: WeeklyPlan?,
        request: SaveWeeklyPlanRequest,
        completion: @escaping @Sendable (Result<WeeklyPlan, Error>) -> Void
    ) {
        let normalizedWeekEnd = WeeklyUseCaseCalendar.normalizedWeekEnd(
            for: weekStartDate,
            preferencesStore: workspacePreferencesStore
        )
        let plan = WeeklyPlan(
            id: existingPlan?.id ?? UUID(),
            weekStartDate: weekStartDate,
            weekEndDate: normalizedWeekEnd,
            focusStatement: request.focusStatement,
            selectedHabitIDs: Array(Set(request.selectedHabitIDs)).sorted { $0.uuidString < $1.uuidString },
            targetCapacity: request.targetCapacity,
            minimumViableWeekEnabled: request.minimumViableWeekEnabled,
            reviewStatus: existingPlan?.reviewStatus == .completed ? .completed : .ready,
            createdAt: existingPlan?.createdAt ?? request.savedAt,
            updatedAt: request.savedAt
        )

        weeklyPlanRepository.savePlan(plan) { saveResult in
            switch saveResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let savedPlan):
                self.persistOutcomes(plan: savedPlan, request: request, completion: completion)
            }
        }
    }

    private func persistOutcomes(
        plan: WeeklyPlan,
        request: SaveWeeklyPlanRequest,
        completion: @escaping @Sendable (Result<WeeklyPlan, Error>) -> Void
    ) {
        weeklyOutcomeRepository.fetchOutcomes(weeklyPlanID: plan.id) { fetchResult in
            switch fetchResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let existingOutcomes):
                let existingStatusByID = Dictionary(uniqueKeysWithValues: existingOutcomes.map { ($0.id, $0.status) })
                let existingCreatedAtByID = Dictionary(uniqueKeysWithValues: existingOutcomes.map { ($0.id, $0.createdAt) })
                let outcomes = request.outcomes.enumerated().map { index, input in
                    WeeklyOutcome(
                        id: input.id,
                        weeklyPlanID: plan.id,
                        sourceProjectID: input.sourceProjectID,
                        title: input.title,
                        whyItMatters: input.whyItMatters,
                        successDefinition: input.successDefinition,
                        status: existingStatusByID[input.id] ?? .planned,
                        orderIndex: index,
                        createdAt: existingCreatedAtByID[input.id] ?? request.savedAt,
                        updatedAt: request.savedAt
                    )
                }

                self.weeklyOutcomeRepository.replaceOutcomes(
                    weeklyPlanID: plan.id,
                    outcomes: outcomes
                ) { replaceResult in
                    switch replaceResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let persistedOutcomes):
                        self.persistTaskAssignments(
                            assignments: request.taskAssignments,
                            validOutcomeIDs: Set(persistedOutcomes.map(\.id)),
                            completion: { assignmentResult in
                                switch assignmentResult {
                                case .failure(let error):
                                    completion(.failure(error))
                                case .success:
                                    completion(.success(plan))
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func persistTaskAssignments(
        assignments: [SaveWeeklyPlanTaskAssignment],
        validOutcomeIDs: Set<UUID>,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        let orderedAssignments = assignments.sorted { lhs, rhs in
            lhs.task.id.uuidString < rhs.task.id.uuidString
        }
        persistTaskAssignment(
            at: 0,
            assignments: orderedAssignments,
            validOutcomeIDs: validOutcomeIDs,
            completion: completion
        )
    }

    private func persistTaskAssignment(
        at index: Int,
        assignments: [SaveWeeklyPlanTaskAssignment],
        validOutcomeIDs: Set<UUID>,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard index < assignments.count else {
            completion(.success(()))
            return
        }

        let assignment = assignments[index]
        taskDefinitionRepository.fetchTaskDefinition(id: assignment.task.id) { fetchResult in
            switch fetchResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let maybeTask):
                guard let currentTask = maybeTask else {
                    completion(.failure(NSError(
                        domain: "SaveWeeklyPlanUseCase",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Task not found while saving the weekly plan."]
                    )))
                    return
                }

                let normalizedOutcomeID: UUID?
                if assignment.planningBucket == .thisWeek,
                   let weeklyOutcomeID = assignment.weeklyOutcomeID,
                   validOutcomeIDs.contains(weeklyOutcomeID) {
                    normalizedOutcomeID = weeklyOutcomeID
                } else {
                    normalizedOutcomeID = nil
                }
                let requiresUpdate = currentTask.planningBucket != assignment.planningBucket
                    || currentTask.weeklyOutcomeID != normalizedOutcomeID

                guard requiresUpdate else {
                    self.persistTaskAssignment(
                        at: index + 1,
                        assignments: assignments,
                        validOutcomeIDs: validOutcomeIDs,
                        completion: completion
                    )
                    return
                }

                self.updateTaskDefinitionUseCase.execute(
                    request: UpdateTaskDefinitionRequest(
                        id: currentTask.id,
                        planningBucket: assignment.planningBucket,
                        weeklyOutcomeID: normalizedOutcomeID,
                        clearWeeklyOutcomeLink: normalizedOutcomeID == nil,
                        updatedAt: Date()
                    )
                ) { updateResult in
                    switch updateResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        self.persistTaskAssignment(
                            at: index + 1,
                            assignments: assignments,
                            validOutcomeIDs: validOutcomeIDs,
                            completion: completion
                        )
                    }
                }
            }
        }
    }
}

public final class CalculateWeeklyMomentumUseCase: @unchecked Sendable {
    private let buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase

    public init(buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase) {
        self.buildWeeklyPlanSnapshot = buildWeeklyPlanSnapshot
    }

    public func execute(
        referenceDate: Date = Date(),
        completion: @escaping @Sendable (Result<WeeklyMomentumSummary, Error>) -> Void
    ) {
        buildWeeklyPlanSnapshot.execute(referenceDate: referenceDate) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let snapshot):
                let completedTasks = snapshot.thisWeekTasks.filter(\.isComplete)
                let openTasks = snapshot.thisWeekTasks.filter { !$0.isComplete }
                let completedOutcomes = snapshot.outcomes.filter { $0.status == .completed }.count
                let activeOutcomes = snapshot.outcomes.count
                let carryPressureCount = openTasks.filter { $0.deferredCount > 0 }.count
                let totalSignals = max(snapshot.thisWeekTasks.count + snapshot.outcomes.count, 1)
                let completionRate = Double(completedTasks.count + completedOutcomes) / Double(totalSignals)
                let score = min(
                    100,
                    Int(round((Double(completedTasks.count + (completedOutcomes * 2)) / Double(totalSignals)) * 100.0))
                )

                let headline: String
                switch score {
                case 75...:
                    headline = "Momentum is compounding."
                case 45...74:
                    headline = "Momentum is steady."
                default:
                    headline = "Momentum needs recovery."
                }

                let drivers = [
                    WeeklyMomentumDriver(
                        id: "completed_tasks",
                        label: "Completed tasks",
                        value: Double(completedTasks.count),
                        detail: "\(completedTasks.count) tasks closed"
                    ),
                    WeeklyMomentumDriver(
                        id: "finished_outcomes",
                        label: "Finished outcomes",
                        value: Double(completedOutcomes),
                        detail: activeOutcomes == 0
                            ? "No weekly outcomes defined"
                            : "\(completedOutcomes) of \(activeOutcomes) outcomes finished"
                    ),
                    WeeklyMomentumDriver(
                        id: "carry_pressure",
                        label: "Carry pressure",
                        value: Double(carryPressureCount),
                        detail: carryPressureCount == 0
                            ? "No deferred tasks pressuring next week"
                            : "\(carryPressureCount) deferred tasks are pushing forward"
                    )
                ]

                completion(.success(WeeklyMomentumSummary(
                    weekStartDate: snapshot.weekStartDate,
                    weekEndDate: Calendar.current.date(byAdding: .day, value: 6, to: snapshot.weekStartDate) ?? snapshot.weekStartDate,
                    score: score,
                    narrative: "\(headline) \(completedTasks.count) tasks closed and \(completedOutcomes) outcomes moved meaningfully this week.",
                    overloadDetected: snapshot.thisWeekTasks.filter { !$0.isComplete }.count > (snapshot.plan?.targetCapacity ?? max(snapshot.thisWeekTasks.count, 1)),
                    completionRate: completionRate,
                    habitContinuityScore: snapshot.plan?.selectedHabitIDs.isEmpty == false ? 1 : 0,
                    carryOverCount: carryPressureCount,
                    drivers: drivers
                )))
            }
        }
    }
}

public final class BuildRecoveryInsightsUseCase: @unchecked Sendable {
    public init() {}

    public func execute(decisions: [WeeklyReviewTaskDecision]) -> RecoveryInsights {
        let carryForwardCount = decisions.filter { $0.disposition == .carry }.count
        let laterCount = decisions.filter { $0.disposition == .later }.count
        let droppedCount = decisions.filter { $0.disposition == .drop }.count

        let headline: String
        if carryForwardCount > laterCount + droppedCount {
            headline = "Next week is inheriting some pressure."
        } else if droppedCount > 0 {
            headline = "You cleared drag, not just shuffled it."
        } else {
            headline = "The week closed cleanly."
        }

        let narrative = "\(carryForwardCount) carried, \(laterCount) moved later, \(droppedCount) consciously dropped."

        return RecoveryInsights(
            headline: headline,
            carryForwardCount: carryForwardCount,
            laterCount: laterCount,
            droppedCount: droppedCount,
            narrative: narrative
        )
    }
}

public final class CompleteWeeklyReviewUseCase: @unchecked Sendable {
    private let reviewMutationRepository: WeeklyReviewMutationRepositoryProtocol

    public init(
        reviewMutationRepository: WeeklyReviewMutationRepositoryProtocol
    ) {
        self.reviewMutationRepository = reviewMutationRepository
    }

    public func execute(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping @Sendable (Result<CompleteWeeklyReviewResult, Error>) -> Void
    ) {
        reviewMutationRepository.finalizeReview(request: request, completion: completion)
    }
}
