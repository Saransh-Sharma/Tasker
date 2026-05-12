//
//  UseCaseCoordinator.swift
//  LifeBoard
//
//  Coordinates complex workflows involving multiple use cases
//

import Foundation

private final class UseCaseCoordinatorAccumulator<State: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State

    init(_ state: State) {
        self.state = state
    }

    func update(_ body: (inout State) -> Void) {
        lock.lock()
        body(&state)
        lock.unlock()
    }

    func snapshot() -> State {
        lock.lock()
        let state = state
        lock.unlock()
        return state
    }
}

private struct MorningRoutineWorkflowState: Sendable {
    var completedCount = 0
    var totalScore = 0
}

private struct DailyDashboardWorkflowState: Sendable {
    var todayTasks: TodayTasksResult?
    var todayAnalytics: DailyAnalytics?
    var streak: StreakInfo?
    var productivityScore: ProductivityScore?
}

private struct EndOfDayCleanupWorkflowState: Sendable {
    var incompleteTasks: [TaskDefinition] = []
    var tasksToReschedule: [TaskDefinition] = []
}

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
        public let dailyReflectionStore: DailyReflectionStoreProtocol
        public let reflectionNoteRepository: ReflectionNoteRepositoryProtocol
        public let gamificationRepository: GamificationRepositoryProtocol
        public let assistantActionRepository: AssistantActionRepositoryProtocol
        public let externalSyncRepository: ExternalSyncRepositoryProtocol
        public let remindersProvider: AppleRemindersProviderProtocol?
        public let calendarEventsProvider: CalendarEventsProviderProtocol?
        public let workspacePreferencesStore: LifeBoardWorkspacePreferencesStore

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
            dailyReflectionStore: DailyReflectionStoreProtocol,
            reflectionNoteRepository: ReflectionNoteRepositoryProtocol,
            gamificationRepository: GamificationRepositoryProtocol,
            assistantActionRepository: AssistantActionRepositoryProtocol,
            externalSyncRepository: ExternalSyncRepositoryProtocol,
            remindersProvider: AppleRemindersProviderProtocol? = nil,
            calendarEventsProvider: CalendarEventsProviderProtocol? = nil,
            workspacePreferencesStore: LifeBoardWorkspacePreferencesStore = .shared
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
            self.dailyReflectionStore = dailyReflectionStore
            self.reflectionNoteRepository = reflectionNoteRepository
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
    public let gamificationEngine: GamificationEngine
    public let focusSession: FocusSessionUseCase
    public let markDailyReflection: MarkDailyReflectionCompleteUseCase
    public let resolveDailyReflectionTarget: ResolveDailyReflectionTargetUseCase
    public let dailyReflectionLoadCoordinator: DailyReflectionLoadCoordinatorProtocol
    public let buildNextDayPlanSuggestion: BuildNextDayPlanSuggestionUseCase
    public let saveDailyReflectionAndPlan: SaveDailyReflectionAndPlanUseCase
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
    public let dailyReflectionStore: DailyReflectionStoreProtocol
    public let reflectionNoteRepository: ReflectionNoteRepositoryProtocol
    public let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    public let cacheService: CacheServiceProtocol?

    // MARK: - Initialization

    /// Initializes a new instance.
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
        self.dailyReflectionStore = v2Dependencies.dailyReflectionStore
        self.reflectionNoteRepository = v2Dependencies.reflectionNoteRepository
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
        let engine = GamificationEngine(repository: v2Dependencies.gamificationRepository)
        self.gamificationEngine = engine
        self.focusSession = FocusSessionUseCase(repository: v2Dependencies.gamificationRepository, engine: engine)
        self.markDailyReflection = MarkDailyReflectionCompleteUseCase(
            engine: engine,
            reflectionStore: v2Dependencies.dailyReflectionStore
        )
        let buildNextDayPlanSuggestion = BuildNextDayPlanSuggestionUseCase(
            calendarEventsProvider: v2Dependencies.calendarEventsProvider,
            workspacePreferencesStore: v2Dependencies.workspacePreferencesStore
        )
        self.buildNextDayPlanSuggestion = buildNextDayPlanSuggestion
        self.resolveDailyReflectionTarget = ResolveDailyReflectionTargetUseCase(
            reflectionStore: v2Dependencies.dailyReflectionStore
        )
        self.dailyReflectionLoadCoordinator = DailyReflectionLoadCoordinator(
            resolveTargetUseCase: self.resolveDailyReflectionTarget,
            taskReadModelRepository: taskReadModelRepository ?? NullTaskReadModelRepository(),
            habitRuntimeReadRepository: v2Dependencies.habitRuntimeReadRepository,
            buildNextDayPlanSuggestionUseCase: buildNextDayPlanSuggestion
        )
        self.saveDailyReflectionAndPlan = SaveDailyReflectionAndPlanUseCase(
            reflectionStore: v2Dependencies.dailyReflectionStore,
            markDailyReflection: self.markDailyReflection
        )
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

    // MARK: - Complex Workflows

    /// Complete morning routine - marks all morning tasks as complete
    public func completeMorningRoutine(completion: @escaping @Sendable (Result<MorningRoutineResult, WorkflowError>) -> Void) {
        getTasks.getTodayTasks { [weak self] result in
            switch result {
            case .success(let todayTasks):
                let morningTasks = todayTasks.morningTasks.filter { !$0.isComplete }

                guard !morningTasks.isEmpty else {
                    completion(.success(MorningRoutineResult(
                        tasksCompleted: 0,
                        totalScore: 0,
                        message: "No morning tasks to complete"
                    )))
                    return
                }

                let state = UseCaseCoordinatorAccumulator(MorningRoutineWorkflowState())
                let group = DispatchGroup()

                for task in morningTasks {
                    group.enter()
                    self?.completeTaskDefinition.setCompletion(taskID: task.id, to: true) { result in
                        if case .success(let updatedTask) = result {
                            state.update {
                                $0.completedCount += 1
                                $0.totalScore += updatedTask.priority.scorePoints
                            }
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    let state = state.snapshot()
                    let workflowResult = MorningRoutineResult(
                        tasksCompleted: state.completedCount,
                        totalScore: state.totalScore,
                        message: "Morning routine completed!"
                    )
                    completion(.success(workflowResult))
                }

            case .failure(let error):
                completion(.failure(.useCaseError(error.localizedDescription)))
            }
        }
    }

    /// Reschedule all overdue tasks to today
    public func rescheduleAllOverdueTasks(completion: @escaping @Sendable (Result<RescheduleAllResult, WorkflowError>) -> Void) {
        getTasks.getOverdueTasks { [weak self] result in
            switch result {
            case .success(let overdueTasks):
                guard !overdueTasks.isEmpty else {
                    completion(.success(RescheduleAllResult(
                        tasksRescheduled: 0,
                        message: "No overdue tasks to reschedule"
                    )))
                    return
                }

                let rescheduledCount = UseCaseCoordinatorAccumulator(0)
                let group = DispatchGroup()
                let targetDate = Date()

                for task in overdueTasks {
                    group.enter()
                    self?.rescheduleTaskDefinition.execute(taskID: task.id, newDate: targetDate) { result in
                        if case .success = result {
                            rescheduledCount.update { $0 += 1 }
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    let rescheduledCount = rescheduledCount.snapshot()
                    let workflowResult = RescheduleAllResult(
                        tasksRescheduled: rescheduledCount,
                        message: "\(rescheduledCount) tasks rescheduled to today"
                    )
                    completion(.success(workflowResult))
                }

            case .failure(let error):
                completion(.failure(.useCaseError(error.localizedDescription)))
            }
        }
    }

    /// Create a new project with initial tasks
    public func createProjectWithTasks(
        projectName: String,
        projectDescription: String?,
        initialTasks: [CreateTaskDefinitionRequest],
        completion: @escaping @Sendable (Result<ProjectCreationResult, WorkflowError>) -> Void
    ) {
        // Step 1: Create the project
        let projectRequest = CreateProjectRequest(name: projectName, description: projectDescription)

        manageProjects.createProject(request: projectRequest) { result in
            switch result {
            case .success(let project):
                // Step 2: Create tasks for the project
                let createdTasks = UseCaseCoordinatorAccumulator([TaskDefinition]())
                let group = DispatchGroup()

                for taskRequest in initialTasks {
                    group.enter()

                    // Update task request with resolved project identity
                    let updatedRequest = CreateTaskDefinitionRequest(
                        id: taskRequest.id,
                        title: taskRequest.title,
                        details: taskRequest.details,
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: taskRequest.lifeAreaID,
                        sectionID: taskRequest.sectionID,
                        dueDate: taskRequest.dueDate,
                        parentTaskID: taskRequest.parentTaskID,
                        tagIDs: taskRequest.tagIDs,
                        dependencies: taskRequest.dependencies,
                        priority: taskRequest.priority,
                        type: taskRequest.type,
                        energy: taskRequest.energy,
                        category: taskRequest.category,
                        context: taskRequest.context,
                        isEveningTask: taskRequest.isEveningTask,
                        alertReminderTime: taskRequest.alertReminderTime,
                        createdAt: taskRequest.createdAt
                    )

                    self.createTaskDefinition.execute(request: updatedRequest) { taskResult in
                        if case .success(let task) = taskResult {
                            createdTasks.update { $0.append(task) }
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    let createdTasks = createdTasks.snapshot()
                    let workflowResult = ProjectCreationResult(
                        project: project,
                        tasksCreated: createdTasks,
                        message: "Project '\(project.name)' created with \(createdTasks.count) tasks"
                    )
                    completion(.success(workflowResult))
                }

            case .failure(let error):
                completion(.failure(.useCaseError(error.localizedDescription)))
            }
        }
    }

    /// Get daily dashboard data
    public func getDailyDashboard(completion: @escaping @Sendable (Result<DailyDashboard, WorkflowError>) -> Void) {
        let group = DispatchGroup()
        let state = UseCaseCoordinatorAccumulator(DailyDashboardWorkflowState())

        // Fetch today's tasks
        group.enter()
        getTasks.getTodayTasks { result in
            if case .success(let tasks) = result {
                state.update { $0.todayTasks = tasks }
            }
            group.leave()
        }

        // Fetch today's analytics
        group.enter()
        calculateAnalytics.calculateTodayAnalytics { result in
            if case .success(let analytics) = result {
                state.update { $0.todayAnalytics = analytics }
            }
            group.leave()
        }

        // Fetch streak
        group.enter()
        calculateAnalytics.calculateStreak { result in
            if case .success(let streakInfo) = result {
                state.update { $0.streak = streakInfo }
            }
            group.leave()
        }

        // Fetch productivity score
        group.enter()
        calculateAnalytics.calculateProductivityScore { result in
            if case .success(let score) = result {
                state.update { $0.productivityScore = score }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            let state = state.snapshot()
            guard let tasks = state.todayTasks,
                  let analytics = state.todayAnalytics,
                  let streakInfo = state.streak,
                  let score = state.productivityScore else {
                completion(.failure(.incompleteData))
                return
            }

            let dashboard = DailyDashboard(
                date: Date(),
                todayTasks: tasks,
                analytics: analytics,
                streak: streakInfo,
                productivityScore: score
            )

            completion(.success(dashboard))
        }
    }

    /// Perform end-of-day cleanup
    public func performEndOfDayCleanup(completion: @escaping @Sendable (Result<CleanupResult, WorkflowError>) -> Void) {
        let group = DispatchGroup()
        let state = UseCaseCoordinatorAccumulator(EndOfDayCleanupWorkflowState())

        // Get today's incomplete tasks
        group.enter()
        getTasks.getTodayTasks { result in
            if case .success(let todayTasks) = result {
                let incompleteTasks = todayTasks.morningTasks.filter { !$0.isComplete } +
                    todayTasks.eveningTasks.filter { !$0.isComplete }
                state.update {
                    $0.incompleteTasks = incompleteTasks
                    $0.tasksToReschedule = incompleteTasks.filter { task in
                        task.priority == .max || task.priority == .high
                    }
                }
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            let state = state.snapshot()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let rescheduledCount = UseCaseCoordinatorAccumulator(0)
            let rescheduleGroup = DispatchGroup()

            for task in state.tasksToReschedule {
                rescheduleGroup.enter()
                self?.rescheduleTaskDefinition.execute(taskID: task.id, newDate: tomorrow) { result in
                    if case .success = result {
                        rescheduledCount.update { $0 += 1 }
                    }
                    rescheduleGroup.leave()
                }
            }

            rescheduleGroup.notify(queue: .main) {
                self?.cacheService?.clearAll()
                let rescheduledCount = rescheduledCount.snapshot()

                let workflowResult = CleanupResult(
                    incompleteTasks: state.incompleteTasks.count,
                    tasksRescheduled: rescheduledCount,
                    message: "End of day cleanup completed"
                )

                completion(.success(workflowResult))
            }
        }
    }
}

private final class NullTaskReadModelRepository: TaskReadModelRepositoryProtocol {
    private func unavailable<T>(_ completion: @escaping @Sendable (Result<T, Error>) -> Void) {
        completion(.failure(DailyReflectionUseCaseError.unavailableTarget))
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

    func fetchDailyReflectionProjection(
        query _: DailyReflectionTaskProjectionQuery,
        completion: @escaping @Sendable (Result<DailyReflectionTaskProjection, Error>) -> Void
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
            return "Use case error: \(message)"
        case .incompleteData:
            return "Could not fetch all required data"
        case .syncError(let message):
            return "Sync error: \(message)"
        }
    }
}
