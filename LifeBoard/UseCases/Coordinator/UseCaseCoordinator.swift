//
//  UseCaseCoordinator.swift
//  LifeBoard
//
//  Coordinates complex workflows involving multiple use cases
//

import Foundation

/// Coordinates complex business workflows involving multiple use cases
/// Acts as a facade for the presentation layer
public final class UseCaseCoordinator: @unchecked Sendable {

    public struct V2Dependencies {
        public let projectRepository: ProjectRepositoryProtocol
        public let lifeAreaRepository: LifeAreaRepositoryProtocol
        public let sectionRepository: SectionRepositoryProtocol
        public let tagRepository: TagRepositoryProtocol
        public let taskDefinitionRepository: TaskDefinitionRepositoryProtocol
        public let taskTagLinkRepository: TaskTagLinkRepositoryProtocol?
        public let taskDependencyRepository: TaskDependencyRepositoryProtocol?
        public let habitRepository: HabitRepositoryProtocol
        public let habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol
        public let scheduleRepository: ScheduleRepositoryProtocol
        public let scheduleEngine: SchedulingEngineProtocol
        public let occurrenceRepository: OccurrenceRepositoryProtocol
        public let tombstoneRepository: TombstoneRepositoryProtocol
        public let reminderRepository: ReminderRepositoryProtocol
        public let weeklyPlanRepository: WeeklyPlanRepositoryProtocol
        public let weeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol
        public let weeklyReviewRepository: WeeklyReviewRepositoryProtocol
        public let weeklyReviewMutationRepository: WeeklyReviewMutationRepositoryProtocol
        public let weeklyReviewDraftStore: WeeklyReviewDraftStoreProtocol
        public let reflectionNoteRepository: ReflectionNoteRepositoryProtocol
        public let frictionFindingRepository: FrictionFindingRepositoryProtocol?
        public let gamificationRepository: GamificationRepositoryProtocol
        public let assistantActionRepository: AssistantActionRepositoryProtocol
        public let externalSyncRepository: ExternalSyncRepositoryProtocol
        public let remindersProvider: AppleRemindersRepositoryProtocol?
        public let calendarEventsProvider: CalendarEventsRepositoryProtocol?
        public let workspacePreferencesStore: WorkspacePreferencesStore

        /// Initializes a new instance.
        public init(
            projectRepository: ProjectRepositoryProtocol,
            lifeAreaRepository: LifeAreaRepositoryProtocol,
            sectionRepository: SectionRepositoryProtocol,
            tagRepository: TagRepositoryProtocol,
            taskDefinitionRepository: TaskDefinitionRepositoryProtocol,
            taskTagLinkRepository: TaskTagLinkRepositoryProtocol? = nil,
            taskDependencyRepository: TaskDependencyRepositoryProtocol? = nil,
            habitRepository: HabitRepositoryProtocol,
            habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol,
            scheduleRepository: ScheduleRepositoryProtocol,
            scheduleEngine: SchedulingEngineProtocol,
            occurrenceRepository: OccurrenceRepositoryProtocol,
            tombstoneRepository: TombstoneRepositoryProtocol,
            reminderRepository: ReminderRepositoryProtocol,
            weeklyPlanRepository: WeeklyPlanRepositoryProtocol,
            weeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol,
            weeklyReviewRepository: WeeklyReviewRepositoryProtocol,
            weeklyReviewMutationRepository: WeeklyReviewMutationRepositoryProtocol,
            weeklyReviewDraftStore: WeeklyReviewDraftStoreProtocol,
            reflectionNoteRepository: ReflectionNoteRepositoryProtocol,
            frictionFindingRepository: FrictionFindingRepositoryProtocol? = nil,
            gamificationRepository: GamificationRepositoryProtocol,
            assistantActionRepository: AssistantActionRepositoryProtocol,
            externalSyncRepository: ExternalSyncRepositoryProtocol,
            remindersProvider: AppleRemindersRepositoryProtocol? = nil,
            calendarEventsProvider: CalendarEventsRepositoryProtocol? = nil,
            workspacePreferencesStore: WorkspacePreferencesStore = .shared
        ) {
            self.projectRepository = projectRepository
            self.lifeAreaRepository = lifeAreaRepository
            self.sectionRepository = sectionRepository
            self.tagRepository = tagRepository
            self.taskDefinitionRepository = taskDefinitionRepository
            self.taskTagLinkRepository = taskTagLinkRepository
            self.taskDependencyRepository = taskDependencyRepository
            self.habitRepository = habitRepository
            self.habitRuntimeReadRepository = habitRuntimeReadRepository
            self.scheduleRepository = scheduleRepository
            self.scheduleEngine = scheduleEngine
            self.occurrenceRepository = occurrenceRepository
            self.tombstoneRepository = tombstoneRepository
            self.reminderRepository = reminderRepository
            self.weeklyPlanRepository = weeklyPlanRepository
            self.weeklyOutcomeRepository = weeklyOutcomeRepository
            self.weeklyReviewRepository = weeklyReviewRepository
            self.weeklyReviewMutationRepository = weeklyReviewMutationRepository
            self.weeklyReviewDraftStore = weeklyReviewDraftStore
            self.reflectionNoteRepository = reflectionNoteRepository
            self.frictionFindingRepository = frictionFindingRepository
            self.gamificationRepository = gamificationRepository
            self.assistantActionRepository = assistantActionRepository
            self.externalSyncRepository = externalSyncRepository
            self.remindersProvider = remindersProvider
            self.calendarEventsProvider = calendarEventsProvider
            self.workspacePreferencesStore = workspacePreferencesStore
        }
    }

    // MARK: - Use Cases

    // Task Query Use Cases
    public let getTasks: GetTasksUseCase
    public let getHomeFilteredTasks: GetHomeFilteredTasksUseCase
    public let computeEvaHomeInsights: ComputeEvaHomeInsightsUseCase
    public let getInboxTriageQueue: GetInboxTriageQueueUseCase
    public let getOverdueRescuePlan: GetOverdueRescuePlanUseCase
    public let buildEvaBatchProposal: BuildEvaBatchProposalUseCase

    // Project Use Cases
    public let manageProjects: ManageProjectsUseCase
    public let filterProjects: FilterProjectsUseCase
    public let getProjectStatistics: GetProjectStatisticsUseCase

    // Analytics Use Cases
    public let calculateAnalytics: CalculateAnalyticsUseCase
    public let generateProductivityReport: GenerateProductivityReportUseCase

    // V2 Use Cases
    public let manageLifeAreas: ManageLifeAreasUseCase
    public let manageSections: ManageSectionsUseCase
    public let manageTags: ManageTagsUseCase
    public let createTaskDefinition: CreateTaskDefinitionUseCase
    public let updateTaskDefinition: UpdateTaskDefinitionUseCase
    public let deleteTaskDefinition: DeleteTaskDefinitionUseCase
    public let rescheduleTaskDefinition: RescheduleTaskDefinitionUseCase
    public let getTaskChildren: GetTaskChildrenUseCase
    public let completeTaskDefinition: CompleteTaskDefinitionUseCase
    public let manageHabits: ManageHabitsUseCase
    public let createHabit: CreateHabitUseCase
    public let updateHabit: UpdateHabitUseCase
    public let pauseHabit: PauseHabitUseCase
    public let archiveHabit: ArchiveHabitUseCase
    public let setHabitArchived: SetHabitArchivedUseCase
    public let deleteHabit: DeleteHabitUseCase
    public let lifeManagementDestructiveFlow: LifeManagementDestructiveFlowCoordinator
    public let syncHabitSchedule: SyncHabitScheduleUseCase
    public let maintainHabitRuntime: MaintainHabitRuntimeUseCase
    public let resolveHabitOccurrence: ResolveHabitOccurrenceUseCase
    public let resetHabitOccurrence: ResetHabitOccurrenceUseCase
    public let logHabitAmount: LogHabitAmountUseCase
    public let getDueHabitsForDate: GetDueHabitsForDateUseCase
    public let getHabitHistory: GetHabitHistoryUseCase
    public let getHabitSignalsInRange: GetHabitSignalsInRangeUseCase
    public let getHabitLibrary: GetHabitLibraryUseCase
    public let recomputeHabitStreaks: RecomputeHabitStreaksUseCase
    public let buildHabitHomeProjection: BuildHabitHomeProjectionUseCase
    public let generateOccurrences: GenerateOccurrencesUseCase
    public let resolveOccurrence: ResolveOccurrenceUseCase
    public let maintainOccurrences: MaintainOccurrencesUseCase
    public let purgeExpiredTombstones: PurgeExpiredTombstonesUseCase
    public let scheduleReminder: ScheduleReminderUseCase
    public let buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase
    public let estimateWeeklyCapacity: EstimateWeeklyCapacityUseCase
    public let getWeeklySummary: GetWeeklySummaryUseCase
    public let saveWeeklyPlan: SaveWeeklyPlanUseCase
    public let calculateWeeklyMomentum: CalculateWeeklyMomentumUseCase
    public let buildRecoveryInsights: BuildRecoveryInsightsUseCase
    public let completeWeeklyReview: CompleteWeeklyReviewUseCase
    public let recordXP: RecordXPUseCase
    public let gamificationEngine: GamificationService
    public let assistantActionPipeline: AssistantActionPipelineUseCase
    public let linkExternalReminders: LinkExternalRemindersUseCase
    public let reconcileExternalReminders: ReconcileExternalRemindersUseCase
    public let calendarIntegrationService: CalendarIntegrationService

    // MARK: - Dependencies

    public let projectRepository: ProjectRepositoryProtocol
    public let lifeAreaRepository: LifeAreaRepositoryProtocol
    public let taskDefinitionRepository: TaskDefinitionRepositoryProtocol
    public let gamificationRepository: GamificationRepositoryProtocol
    public let reminderRepository: ReminderRepositoryProtocol
    public let weeklyPlanRepository: WeeklyPlanRepositoryProtocol
    public let weeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol
    public let weeklyReviewRepository: WeeklyReviewRepositoryProtocol
    public let weeklyReviewMutationRepository: WeeklyReviewMutationRepositoryProtocol
    public let weeklyReviewDraftStore: WeeklyReviewDraftStoreProtocol
    public let reflectionNoteRepository: ReflectionNoteRepositoryProtocol
    public let frictionFindingRepository: FrictionFindingRepositoryProtocol?
    public let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    public let cacheService: CacheServiceProtocol?

    // MARK: - Initialization

    /// Initializes a new instance.
    @MainActor
    public init(
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        projectRepository: ProjectRepositoryProtocol,
        cacheService: CacheServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil,
        v2Dependencies: V2Dependencies
    ) {
        self.projectRepository = projectRepository
        self.lifeAreaRepository = v2Dependencies.lifeAreaRepository
        self.taskDefinitionRepository = v2Dependencies.taskDefinitionRepository
        self.gamificationRepository = v2Dependencies.gamificationRepository
        self.reminderRepository = v2Dependencies.reminderRepository
        self.weeklyPlanRepository = v2Dependencies.weeklyPlanRepository
        self.weeklyOutcomeRepository = v2Dependencies.weeklyOutcomeRepository
        self.weeklyReviewRepository = v2Dependencies.weeklyReviewRepository
        self.weeklyReviewMutationRepository = v2Dependencies.weeklyReviewMutationRepository
        self.weeklyReviewDraftStore = v2Dependencies.weeklyReviewDraftStore
        self.reflectionNoteRepository = v2Dependencies.reflectionNoteRepository
        self.frictionFindingRepository = v2Dependencies.frictionFindingRepository
        self.taskReadModelRepository = taskReadModelRepository
        self.cacheService = cacheService
        self.calendarIntegrationService = CalendarIntegrationService(
            provider: v2Dependencies.calendarEventsProvider,
            workspacePreferencesStore: v2Dependencies.workspacePreferencesStore
        )

        // Query-centric use cases
        self.getTasks = GetTasksUseCase(
            readModelRepository: taskReadModelRepository,
            cacheService: cacheService
        )
        self.getHomeFilteredTasks = GetHomeFilteredTasksUseCase(
            readModelRepository: taskReadModelRepository
        )
        self.computeEvaHomeInsights = ComputeEvaHomeInsightsUseCase(
            habitRuntimeReadRepository: v2Dependencies.habitRuntimeReadRepository
        )
        self.getInboxTriageQueue = GetInboxTriageQueueUseCase()
        self.getOverdueRescuePlan = GetOverdueRescuePlanUseCase()
        self.buildEvaBatchProposal = BuildEvaBatchProposalUseCase()

        // Project use cases
        self.manageProjects = ManageProjectsUseCase(projectRepository: projectRepository)
        self.filterProjects = FilterProjectsUseCase(projectRepository: projectRepository)
        self.getProjectStatistics = GetProjectStatisticsUseCase(projectRepository: projectRepository)

        // Analytics use cases
        let scoringService: TaskScoringServiceProtocol = DefaultTaskScoringService()
        self.calculateAnalytics = CalculateAnalyticsUseCase(
            taskReadModelRepository: taskReadModelRepository,
            habitRuntimeReadRepository: v2Dependencies.habitRuntimeReadRepository,
            scoringService: scoringService,
            cacheService: cacheService
        )
        self.generateProductivityReport = GenerateProductivityReportUseCase(
            taskReadModelRepository: taskReadModelRepository
        )

        // V2 use cases
        let xp = RecordXPUseCase(repository: v2Dependencies.gamificationRepository)
        let engine = GamificationService(repository: v2Dependencies.gamificationRepository)
        self.gamificationEngine = engine
        self.manageLifeAreas = ManageLifeAreasUseCase(repository: v2Dependencies.lifeAreaRepository)
        self.manageSections = ManageSectionsUseCase(repository: v2Dependencies.sectionRepository)
        self.manageTags = ManageTagsUseCase(repository: v2Dependencies.tagRepository)
        self.createTaskDefinition = CreateTaskDefinitionUseCase(
            repository: v2Dependencies.taskDefinitionRepository,
            taskTagLinkRepository: v2Dependencies.taskTagLinkRepository,
            taskDependencyRepository: v2Dependencies.taskDependencyRepository
        )
        let updateTaskDefinitionUseCase = UpdateTaskDefinitionUseCase(
            repository: v2Dependencies.taskDefinitionRepository,
            taskTagLinkRepository: v2Dependencies.taskTagLinkRepository,
            taskDependencyRepository: v2Dependencies.taskDependencyRepository
        )
        self.updateTaskDefinition = updateTaskDefinitionUseCase
        self.deleteTaskDefinition = DeleteTaskDefinitionUseCase(
            repository: v2Dependencies.taskDefinitionRepository,
            tombstoneRepository: v2Dependencies.tombstoneRepository
        )
        self.rescheduleTaskDefinition = RescheduleTaskDefinitionUseCase(
            updateTaskDefinition: updateTaskDefinitionUseCase,
            repository: v2Dependencies.taskDefinitionRepository
        )
        self.getTaskChildren = GetTaskChildrenUseCase(repository: v2Dependencies.taskDefinitionRepository)
        self.completeTaskDefinition = CompleteTaskDefinitionUseCase(
            repository: v2Dependencies.taskDefinitionRepository,
            gamification: xp,
            gamificationEngine: engine
        )
        let buildWeeklyPlanSnapshot = BuildWeeklyPlanSnapshotUseCase(
            weeklyPlanRepository: v2Dependencies.weeklyPlanRepository,
            weeklyOutcomeRepository: v2Dependencies.weeklyOutcomeRepository,
            weeklyReviewRepository: v2Dependencies.weeklyReviewRepository,
            reflectionNoteRepository: v2Dependencies.reflectionNoteRepository,
            taskReadModelRepository: taskReadModelRepository,
            taskDefinitionRepository: v2Dependencies.taskDefinitionRepository
        )
        self.buildWeeklyPlanSnapshot = buildWeeklyPlanSnapshot
        let estimateWeeklyCapacity = EstimateWeeklyCapacityUseCase(
            taskReadModelRepository: taskReadModelRepository,
            taskDefinitionRepository: v2Dependencies.taskDefinitionRepository
        )
        self.estimateWeeklyCapacity = estimateWeeklyCapacity
        self.getWeeklySummary = GetWeeklySummaryUseCase(
            buildWeeklyPlanSnapshot: buildWeeklyPlanSnapshot,
            estimateWeeklyCapacity: estimateWeeklyCapacity
        )
        self.saveWeeklyPlan = SaveWeeklyPlanUseCase(
            weeklyPlanRepository: v2Dependencies.weeklyPlanRepository,
            weeklyOutcomeRepository: v2Dependencies.weeklyOutcomeRepository,
            updateTaskDefinitionUseCase: updateTaskDefinitionUseCase,
            taskDefinitionRepository: v2Dependencies.taskDefinitionRepository
        )
        self.calculateWeeklyMomentum = CalculateWeeklyMomentumUseCase(
            buildWeeklyPlanSnapshot: buildWeeklyPlanSnapshot
        )
        self.buildRecoveryInsights = BuildRecoveryInsightsUseCase()
        self.completeWeeklyReview = CompleteWeeklyReviewUseCase(
            reviewMutationRepository: v2Dependencies.weeklyReviewMutationRepository
        )
        let recomputeHabitStreaks = RecomputeHabitStreaksUseCase(
            habitRepository: v2Dependencies.habitRepository,
            occurrenceRepository: v2Dependencies.occurrenceRepository
        )
        self.recomputeHabitStreaks = recomputeHabitStreaks
        let syncHabitSchedule = SyncHabitScheduleUseCase(
            habitRepository: v2Dependencies.habitRepository,
            scheduleRepository: v2Dependencies.scheduleRepository,
            scheduleEngine: v2Dependencies.scheduleEngine,
            occurrenceRepository: v2Dependencies.occurrenceRepository,
            recomputeHabitStreaksUseCase: recomputeHabitStreaks
        )
        self.syncHabitSchedule = syncHabitSchedule
        let maintainHabitRuntime = MaintainHabitRuntimeUseCase(
            syncHabitScheduleUseCase: syncHabitSchedule
        )
        self.maintainHabitRuntime = maintainHabitRuntime
        self.createHabit = CreateHabitUseCase(
            habitRepository: v2Dependencies.habitRepository,
            lifeAreaRepository: v2Dependencies.lifeAreaRepository,
            projectRepository: v2Dependencies.projectRepository,
            scheduleRepository: v2Dependencies.scheduleRepository,
            maintainHabitRuntimeUseCase: maintainHabitRuntime
        )
        self.updateHabit = UpdateHabitUseCase(
            habitRepository: v2Dependencies.habitRepository,
            scheduleRepository: v2Dependencies.scheduleRepository,
            scheduleEngine: v2Dependencies.scheduleEngine,
            projectRepository: v2Dependencies.projectRepository,
            lifeAreaRepository: v2Dependencies.lifeAreaRepository,
            maintainHabitRuntimeUseCase: maintainHabitRuntime
        )
        let pauseHabit = PauseHabitUseCase(
            habitRepository: v2Dependencies.habitRepository,
            scheduleRepository: v2Dependencies.scheduleRepository,
            maintainHabitRuntimeUseCase: maintainHabitRuntime
        )
        self.pauseHabit = pauseHabit
        self.archiveHabit = ArchiveHabitUseCase(
            habitRepository: v2Dependencies.habitRepository,
            pauseHabitUseCase: pauseHabit,
            maintainHabitRuntimeUseCase: maintainHabitRuntime
        )
        self.setHabitArchived = SetHabitArchivedUseCase(
            habitRepository: v2Dependencies.habitRepository,
            pauseHabitUseCase: pauseHabit,
            maintainHabitRuntimeUseCase: maintainHabitRuntime
        )
        self.deleteHabit = DeleteHabitUseCase(
            habitRepository: v2Dependencies.habitRepository,
            scheduleRepository: v2Dependencies.scheduleRepository,
            maintainHabitRuntimeUseCase: maintainHabitRuntime
        )
        self.lifeManagementDestructiveFlow = LifeManagementDestructiveFlowCoordinator(
            manageProjectsUseCase: self.manageProjects,
            updateHabitUseCase: self.updateHabit,
            projectRepository: v2Dependencies.projectRepository,
            taskDefinitionRepository: v2Dependencies.taskDefinitionRepository,
            lifeAreaRepository: v2Dependencies.lifeAreaRepository,
            habitRuntimeReadRepository: v2Dependencies.habitRuntimeReadRepository
        )
        self.getDueHabitsForDate = GetDueHabitsForDateUseCase(
            readRepository: v2Dependencies.habitRuntimeReadRepository
        )
        self.getHabitHistory = GetHabitHistoryUseCase(
            readRepository: v2Dependencies.habitRuntimeReadRepository
        )
        self.getHabitSignalsInRange = GetHabitSignalsInRangeUseCase(
            readRepository: v2Dependencies.habitRuntimeReadRepository
        )
        self.getHabitLibrary = GetHabitLibraryUseCase(
            readRepository: v2Dependencies.habitRuntimeReadRepository
        )
        self.buildHabitHomeProjection = BuildHabitHomeProjectionUseCase(
            getDueHabitsForDateUseCase: self.getDueHabitsForDate
        )
        self.resolveHabitOccurrence = ResolveHabitOccurrenceUseCase(
            habitRepository: v2Dependencies.habitRepository,
            scheduleRepository: v2Dependencies.scheduleRepository,
            occurrenceRepository: v2Dependencies.occurrenceRepository,
            scheduleEngine: v2Dependencies.scheduleEngine,
            recomputeHabitStreaksUseCase: recomputeHabitStreaks,
            gamificationEngine: engine
        )
        self.resetHabitOccurrence = ResetHabitOccurrenceUseCase(
            habitRepository: v2Dependencies.habitRepository,
            occurrenceRepository: v2Dependencies.occurrenceRepository,
            recomputeHabitStreaksUseCase: recomputeHabitStreaks,
            gamificationEngine: engine
        )
        self.logHabitAmount = LogHabitAmountUseCase(
            habitRepository: v2Dependencies.habitRepository,
            occurrenceRepository: v2Dependencies.occurrenceRepository,
            resolveUseCase: self.resolveHabitOccurrence,
            resetUseCase: self.resetHabitOccurrence
        )
        self.manageHabits = ManageHabitsUseCase(repository: v2Dependencies.habitRepository)
        self.generateOccurrences = GenerateOccurrencesUseCase(engine: v2Dependencies.scheduleEngine)
        self.resolveOccurrence = ResolveOccurrenceUseCase(engine: v2Dependencies.scheduleEngine)
        self.maintainOccurrences = MaintainOccurrencesUseCase(
            occurrenceRepository: v2Dependencies.occurrenceRepository,
            tombstoneRepository: v2Dependencies.tombstoneRepository
        )
        self.purgeExpiredTombstones = PurgeExpiredTombstonesUseCase(
            tombstoneRepository: v2Dependencies.tombstoneRepository
        )
        self.scheduleReminder = ScheduleReminderUseCase(
            repository: v2Dependencies.reminderRepository,
            notificationService: notificationService
        )
        self.recordXP = xp

        let assistantCommandExecutor = AssistantCommandExecutor()
        self.assistantActionPipeline = AssistantActionPipelineUseCase(
            repository: v2Dependencies.assistantActionRepository,
            taskRepository: v2Dependencies.taskDefinitionRepository,
            commandExecutor: assistantCommandExecutor
        )
        self.linkExternalReminders = LinkExternalRemindersUseCase(
            externalRepository: v2Dependencies.externalSyncRepository,
            remindersProvider: v2Dependencies.remindersProvider,
            taskRepository: v2Dependencies.taskDefinitionRepository
        )
        self.reconcileExternalReminders = ReconcileExternalRemindersUseCase(
            externalRepository: v2Dependencies.externalSyncRepository,
            remindersProvider: v2Dependencies.remindersProvider,
            taskRepository: v2Dependencies.taskDefinitionRepository
        )
    }
}

private final class NullTaskReadModelRepository: TaskReadModelRepositoryProtocol {
    private func unavailable<T>(_ completion: @escaping @Sendable (Result<T, Error>) -> Void) {
        completion(.failure(NSError(domain: "LifeBoard.TaskReadModel", code: 1)))
    }

    func fetchTasks(query _: TaskReadQuery, completion: @escaping @Sendable (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        unavailable(completion)
    }

    func searchTasks(query _: TaskSearchQuery, completion: @escaping @Sendable (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        unavailable(completion)
    }

    func searchTasks(query _: TaskRepositorySearchQuery, completion: @escaping @Sendable (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        unavailable(completion)
    }

    func fetchHomeProjection(query _: HomeProjectionQuery, completion: @escaping @Sendable (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        unavailable(completion)
    }

    func fetchInsightsTodayProjection(
        referenceDate _: Date,
        completion: @escaping @Sendable (Result<InsightsTodayTaskProjection, Error>) -> Void
    ) {
        unavailable(completion)
    }

    func fetchInsightsTodayProjection(
        query _: InsightsTodayProjectionQuery,
        completion: @escaping @Sendable (Result<InsightsTodayTaskProjection, Error>) -> Void
    ) {
        unavailable(completion)
    }

    func fetchInsightsWeekProjection(
        referenceDate _: Date,
        completion: @escaping @Sendable (Result<InsightsWeekTaskProjection, Error>) -> Void
    ) {
        unavailable(completion)
    }

    func fetchInsightsWeekProjection(
        query _: InsightsWeekProjectionQuery,
        completion: @escaping @Sendable (Result<InsightsWeekTaskProjection, Error>) -> Void
    ) {
        unavailable(completion)
    }

    func fetchWeekChartProjection(referenceDate _: Date, completion: @escaping @Sendable (Result<WeekChartProjection, Error>) -> Void) {
        unavailable(completion)
    }

    func fetchProjectTaskCounts(includeCompleted _: Bool, completion: @escaping @Sendable (Result<[UUID: Int], Error>) -> Void) {
        unavailable(completion)
    }

    func fetchProjectCompletionScoreTotals(
        from _: Date,
        to _: Date,
        completion: @escaping @Sendable (Result<[UUID: Int], Error>) -> Void
    ) {
        unavailable(completion)
    }
}

// MARK: - Result Models

public struct MorningRoutineResult: Sendable {
    public let tasksCompleted: Int
    public let totalScore: Int
    public let message: String
}

public struct RescheduleAllResult: Sendable {
    public let tasksRescheduled: Int
    public let message: String
}

public struct ProjectCreationResult: Sendable {
    public let project: Project
    public let tasksCreated: [TaskDefinition]
    public let message: String
}

public struct DailyDashboard: Sendable {
    public let date: Date
    public let todayTasks: TodayTasksResult
    public let analytics: DailyAnalytics
    public let streak: StreakInfo
    public let productivityScore: ProductivityScore
}

public struct CleanupResult: Sendable {
    public let incompleteTasks: Int
    public let tasksRescheduled: Int
    public let message: String
}

// MARK: - Error Types

public enum WorkflowError: LocalizedError, Sendable {
    case useCaseError(String)
    case incompleteData
    case syncError(String)

    public var errorDescription: String? {
        switch self {
        case .useCaseError(let message):
            return message
        case .incompleteData:
            return String(localized: "Couldn’t load everything.")
        case .syncError(let message):
            return String(localized: "Couldn’t sync. \(message)")
        }
    }
}
