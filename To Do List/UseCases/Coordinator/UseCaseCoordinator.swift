//
//  UseCaseCoordinator.swift
//  Tasker
//
//  Coordinates complex workflows involving multiple use cases
//

import Foundation

/// Coordinates complex business workflows involving multiple use cases
/// Acts as a facade for the presentation layer
public final class UseCaseCoordinator {

    public struct V2Dependencies {
        public let lifeAreaRepository: LifeAreaRepositoryProtocol
        public let sectionRepository: SectionRepositoryProtocol
        public let tagRepository: TagRepositoryProtocol
        public let taskDefinitionRepository: TaskDefinitionRepositoryProtocol
        public let taskTagLinkRepository: TaskTagLinkRepositoryProtocol?
        public let taskDependencyRepository: TaskDependencyRepositoryProtocol?
        public let habitRepository: HabitRepositoryProtocol
        public let scheduleEngine: SchedulingEngineProtocol
        public let occurrenceRepository: OccurrenceRepositoryProtocol
        public let tombstoneRepository: TombstoneRepositoryProtocol
        public let reminderRepository: ReminderRepositoryProtocol
        public let gamificationRepository: GamificationRepositoryProtocol
        public let assistantActionRepository: AssistantActionRepositoryProtocol
        public let externalSyncRepository: ExternalSyncRepositoryProtocol
        public let remindersProvider: AppleRemindersProviderProtocol?

        /// Initializes a new instance.
        public init(
            lifeAreaRepository: LifeAreaRepositoryProtocol,
            sectionRepository: SectionRepositoryProtocol,
            tagRepository: TagRepositoryProtocol,
            taskDefinitionRepository: TaskDefinitionRepositoryProtocol,
            taskTagLinkRepository: TaskTagLinkRepositoryProtocol? = nil,
            taskDependencyRepository: TaskDependencyRepositoryProtocol? = nil,
            habitRepository: HabitRepositoryProtocol,
            scheduleEngine: SchedulingEngineProtocol,
            occurrenceRepository: OccurrenceRepositoryProtocol,
            tombstoneRepository: TombstoneRepositoryProtocol,
            reminderRepository: ReminderRepositoryProtocol,
            gamificationRepository: GamificationRepositoryProtocol,
            assistantActionRepository: AssistantActionRepositoryProtocol,
            externalSyncRepository: ExternalSyncRepositoryProtocol,
            remindersProvider: AppleRemindersProviderProtocol? = nil
        ) {
            self.lifeAreaRepository = lifeAreaRepository
            self.sectionRepository = sectionRepository
            self.tagRepository = tagRepository
            self.taskDefinitionRepository = taskDefinitionRepository
            self.taskTagLinkRepository = taskTagLinkRepository
            self.taskDependencyRepository = taskDependencyRepository
            self.habitRepository = habitRepository
            self.scheduleEngine = scheduleEngine
            self.occurrenceRepository = occurrenceRepository
            self.tombstoneRepository = tombstoneRepository
            self.reminderRepository = reminderRepository
            self.gamificationRepository = gamificationRepository
            self.assistantActionRepository = assistantActionRepository
            self.externalSyncRepository = externalSyncRepository
            self.remindersProvider = remindersProvider
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
    public let generateOccurrences: GenerateOccurrencesUseCase
    public let resolveOccurrence: ResolveOccurrenceUseCase
    public let maintainOccurrences: MaintainOccurrencesUseCase
    public let purgeExpiredTombstones: PurgeExpiredTombstonesUseCase
    public let scheduleReminder: ScheduleReminderUseCase
    public let recordXP: RecordXPUseCase
    public let gamificationEngine: GamificationEngine
    public let focusSession: FocusSessionUseCase
    public let markDailyReflection: MarkDailyReflectionCompleteUseCase
    public let assistantActionPipeline: AssistantActionPipelineUseCase
    public let linkExternalReminders: LinkExternalRemindersUseCase
    public let reconcileExternalReminders: ReconcileExternalRemindersUseCase

    // MARK: - Dependencies

    public let projectRepository: ProjectRepositoryProtocol
    public let lifeAreaRepository: LifeAreaRepositoryProtocol
    public let taskDefinitionRepository: TaskDefinitionRepositoryProtocol
    public let gamificationRepository: GamificationRepositoryProtocol
    public let reminderRepository: ReminderRepositoryProtocol
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
        self.taskReadModelRepository = taskReadModelRepository
        self.cacheService = cacheService

        // Query-centric use cases
        self.getTasks = GetTasksUseCase(
            readModelRepository: taskReadModelRepository,
            cacheService: cacheService
        )
        self.getHomeFilteredTasks = GetHomeFilteredTasksUseCase(
            readModelRepository: taskReadModelRepository
        )
        self.computeEvaHomeInsights = ComputeEvaHomeInsightsUseCase()
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
        self.markDailyReflection = MarkDailyReflectionCompleteUseCase(engine: engine)
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
            updateTaskDefinition: updateTaskDefinitionUseCase
        )
        self.getTaskChildren = GetTaskChildrenUseCase(repository: v2Dependencies.taskDefinitionRepository)
        self.completeTaskDefinition = CompleteTaskDefinitionUseCase(
            repository: v2Dependencies.taskDefinitionRepository,
            gamification: xp,
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
    public func completeMorningRoutine(completion: @escaping (Result<MorningRoutineResult, WorkflowError>) -> Void) {
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

                var completedCount = 0
                var totalScore = 0
                let group = DispatchGroup()

                for task in morningTasks {
                    group.enter()
                    self?.completeTaskDefinition.setCompletion(taskID: task.id, to: true) { result in
                        if case .success(let updatedTask) = result {
                            completedCount += 1
                            totalScore += updatedTask.priority.scorePoints
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    let workflowResult = MorningRoutineResult(
                        tasksCompleted: completedCount,
                        totalScore: totalScore,
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
    public func rescheduleAllOverdueTasks(completion: @escaping (Result<RescheduleAllResult, WorkflowError>) -> Void) {
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

                var rescheduledCount = 0
                let group = DispatchGroup()
                let targetDate = Date()

                for task in overdueTasks {
                    group.enter()
                    self?.rescheduleTaskDefinition.execute(taskID: task.id, newDate: targetDate) { result in
                        if case .success = result {
                            rescheduledCount += 1
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
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
        completion: @escaping (Result<ProjectCreationResult, WorkflowError>) -> Void
    ) {
        // Step 1: Create the project
        let projectRequest = CreateProjectRequest(name: projectName, description: projectDescription)

        manageProjects.createProject(request: projectRequest) { result in
            switch result {
            case .success(let project):
                // Step 2: Create tasks for the project
                var createdTasks: [TaskDefinition] = []
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
                            createdTasks.append(task)
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
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
    public func getDailyDashboard(completion: @escaping (Result<DailyDashboard, WorkflowError>) -> Void) {
        let group = DispatchGroup()

        var todayTasks: TodayTasksResult?
        var todayAnalytics: DailyAnalytics?
        var streak: StreakInfo?
        var productivityScore: ProductivityScore?

        // Fetch today's tasks
        group.enter()
        getTasks.getTodayTasks { result in
            if case .success(let tasks) = result {
                todayTasks = tasks
            }
            group.leave()
        }

        // Fetch today's analytics
        group.enter()
        calculateAnalytics.calculateTodayAnalytics { result in
            if case .success(let analytics) = result {
                todayAnalytics = analytics
            }
            group.leave()
        }

        // Fetch streak
        group.enter()
        calculateAnalytics.calculateStreak { result in
            if case .success(let streakInfo) = result {
                streak = streakInfo
            }
            group.leave()
        }

        // Fetch productivity score
        group.enter()
        calculateAnalytics.calculateProductivityScore { result in
            if case .success(let score) = result {
                productivityScore = score
            }
            group.leave()
        }

        group.notify(queue: .main) {
            guard let tasks = todayTasks,
                  let analytics = todayAnalytics,
                  let streakInfo = streak,
                  let score = productivityScore else {
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
    public func performEndOfDayCleanup(completion: @escaping (Result<CleanupResult, WorkflowError>) -> Void) {
        let group = DispatchGroup()

        var incompleteTasks: [TaskDefinition] = []
        var tasksToReschedule: [TaskDefinition] = []

        // Get today's incomplete tasks
        group.enter()
        getTasks.getTodayTasks { result in
            if case .success(let todayTasks) = result {
                incompleteTasks = todayTasks.morningTasks.filter { !$0.isComplete } +
                    todayTasks.eveningTasks.filter { !$0.isComplete }

                // Reschedule high-priority tasks to tomorrow
                tasksToReschedule = incompleteTasks.filter { task in
                    task.priority == .max || task.priority == .high
                }
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            var rescheduledCount = 0
            let rescheduleGroup = DispatchGroup()

            for task in tasksToReschedule {
                rescheduleGroup.enter()
                self?.rescheduleTaskDefinition.execute(taskID: task.id, newDate: tomorrow) { result in
                    if case .success = result {
                        rescheduledCount += 1
                    }
                    rescheduleGroup.leave()
                }
            }

            rescheduleGroup.notify(queue: .main) {
                self?.cacheService?.clearAll()

                let workflowResult = CleanupResult(
                    incompleteTasks: incompleteTasks.count,
                    tasksRescheduled: rescheduledCount,
                    message: "End of day cleanup completed"
                )

                completion(.success(workflowResult))
            }
        }
    }
}

// MARK: - Result Models

public struct MorningRoutineResult {
    public let tasksCompleted: Int
    public let totalScore: Int
    public let message: String
}

public struct RescheduleAllResult {
    public let tasksRescheduled: Int
    public let message: String
}

public struct ProjectCreationResult {
    public let project: Project
    public let tasksCreated: [TaskDefinition]
    public let message: String
}

public struct DailyDashboard {
    public let date: Date
    public let todayTasks: TodayTasksResult
    public let analytics: DailyAnalytics
    public let streak: StreakInfo
    public let productivityScore: ProductivityScore
}

public struct CleanupResult {
    public let incompleteTasks: Int
    public let tasksRescheduled: Int
    public let message: String
}

// MARK: - Error Types

public enum WorkflowError: LocalizedError {
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
