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
    
    // MARK: - Use Cases

    // Task Use Cases
    public let createTask: CreateTaskUseCase
    public let completeTask: CompleteTaskUseCase
    public let deleteTask: DeleteTaskUseCase
    public let rescheduleTask: RescheduleTaskUseCase
    public let getTasks: GetTasksUseCase
    public let getHomeFilteredTasks: GetHomeFilteredTasksUseCase

    // New Task Use Cases (Phase 3)
    public let filterTasks: FilterTasksUseCase
    public let searchTasks: SearchTasksUseCase
    public let sortTasks: SortTasksUseCase
    public let getTaskStatistics: GetTaskStatisticsUseCase
    public let bulkUpdateTasks: BulkUpdateTasksUseCase
    
    // Project Use Cases
    public let manageProjects: ManageProjectsUseCase
    public let filterProjects: FilterProjectsUseCase
    public let getProjectStatistics: GetProjectStatisticsUseCase
    
    // Analytics Use Cases
    public let calculateAnalytics: CalculateAnalyticsUseCase
    public let generateProductivityReport: GenerateProductivityReportUseCase
    
    // MARK: - Dependencies

    public let taskRepository: TaskRepositoryProtocol
    public let projectRepository: ProjectRepositoryProtocol
    public let cacheService: CacheServiceProtocol?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        cacheService: CacheServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.cacheService = cacheService
        
        // Initialize use cases
        self.createTask = CreateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: notificationService
        )
        
        let scoringService: TaskScoringServiceProtocol = DefaultTaskScoringService()
        self.completeTask = CompleteTaskUseCase(
            taskRepository: taskRepository,
            scoringService: scoringService,
            analyticsService: nil as AnalyticsServiceProtocol?
        )
        
        self.deleteTask = DeleteTaskUseCase(
            taskRepository: taskRepository,
            notificationService: notificationService,
            analyticsService: nil
        )

        self.rescheduleTask = RescheduleTaskUseCase(
            taskRepository: taskRepository,
            notificationService: notificationService
        )

        self.getTasks = GetTasksUseCase(
            taskRepository: taskRepository,
            cacheService: cacheService
        )

        self.getHomeFilteredTasks = GetHomeFilteredTasksUseCase(
            taskRepository: taskRepository
        )
        
        // New Task Use Cases (Phase 3)
        self.filterTasks = FilterTasksUseCase(
            taskRepository: taskRepository,
            cacheService: cacheService
        )
        
        self.searchTasks = SearchTasksUseCase(
            taskRepository: taskRepository,
            cacheService: cacheService
        )
        
        self.sortTasks = SortTasksUseCase(
            cacheService: cacheService
        )
        
        self.getTaskStatistics = GetTaskStatisticsUseCase(
            taskRepository: taskRepository,
            cacheService: cacheService
        )
        
        self.bulkUpdateTasks = BulkUpdateTasksUseCase(
            taskRepository: taskRepository,
            eventPublisher: nil // TODO: Add event publisher dependency
        )
        
        // Project Use Cases
        self.manageProjects = ManageProjectsUseCase(
            projectRepository: projectRepository,
            taskRepository: taskRepository
        )
        
        self.filterProjects = FilterProjectsUseCase(
            projectRepository: projectRepository
        )
        
        self.getProjectStatistics = GetProjectStatisticsUseCase(
            projectRepository: projectRepository,
            taskRepository: taskRepository
        )
        
        // Analytics Use Cases
        self.calculateAnalytics = CalculateAnalyticsUseCase(
            taskRepository: taskRepository,
            scoringService: scoringService,
            cacheService: cacheService
        )
        
        self.generateProductivityReport = GenerateProductivityReportUseCase(
            taskRepository: taskRepository
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
                    self?.completeTask.completeTask(task.id) { result in
                        if case .success(let completionResult) = result {
                            completedCount += 1
                            totalScore += completionResult.scoreEarned
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    let result = MorningRoutineResult(
                        tasksCompleted: completedCount,
                        totalScore: totalScore,
                        message: "Morning routine completed!"
                    )
                    completion(.success(result))
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
                    self?.rescheduleTask.execute(taskId: task.id, newDate: targetDate) { result in
                        if case .success = result {
                            rescheduledCount += 1
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    let result = RescheduleAllResult(
                        tasksRescheduled: rescheduledCount,
                        message: "\(rescheduledCount) tasks rescheduled to today"
                    )
                    completion(.success(result))
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
        initialTasks: [CreateTaskRequest],
        completion: @escaping (Result<ProjectCreationResult, WorkflowError>) -> Void
    ) {
        // Step 1: Create the project
        let projectRequest = CreateProjectRequest(name: projectName, description: projectDescription)
        
        manageProjects.createProject(request: projectRequest) { [weak self] result in
            switch result {
            case .success(let project):
                // Step 2: Create tasks for the project
                var createdTasks: [Task] = []
                let group = DispatchGroup()
                
                for taskRequest in initialTasks {
                    group.enter()
                    
                    // Update task request with project name
                    let updatedRequest = CreateTaskRequest(
                        name: taskRequest.name,
                        details: taskRequest.details,
                        type: taskRequest.type,
                        priority: taskRequest.priority,
                        dueDate: taskRequest.dueDate,
                        project: project.name,
                        alertReminderTime: taskRequest.alertReminderTime
                    )
                    
                    self?.createTask.execute(request: updatedRequest) { taskResult in
                        if case .success(let task) = taskResult {
                            createdTasks.append(task)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    let result = ProjectCreationResult(
                        project: project,
                        tasksCreated: createdTasks,
                        message: "Project '\(project.name)' created with \(createdTasks.count) tasks"
                    )
                    completion(.success(result))
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
        
        var incompleteTasks: [Task] = []
        var tasksToReschedule: [Task] = []
        
        // Get today's incomplete tasks
        group.enter()
        getTasks.getTodayTasks { result in
            if case .success(let todayTasks) = result {
                incompleteTasks = todayTasks.morningTasks.filter { !$0.isComplete } +
                                todayTasks.eveningTasks.filter { !$0.isComplete }
                
                // Determine which tasks to reschedule
                tasksToReschedule = incompleteTasks.filter { task in
                    // Reschedule high priority tasks to tomorrow
                    task.priority == .max || task.priority == .high
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            // Reschedule high priority tasks
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            var rescheduledCount = 0
            let rescheduleGroup = DispatchGroup()
            
            for task in tasksToReschedule {
                rescheduleGroup.enter()
                self?.rescheduleTask.execute(taskId: task.id, newDate: tomorrow) { result in
                    if case .success = result {
                        rescheduledCount += 1
                    }
                    rescheduleGroup.leave()
                }
            }
            
            rescheduleGroup.notify(queue: .main) {
                // Clear cache for fresh start tomorrow
                self?.cacheService?.clearAll()
                
                let result = CleanupResult(
                    incompleteTasks: incompleteTasks.count,
                    tasksRescheduled: rescheduledCount,
                    message: "End of day cleanup completed"
                )
                
                completion(.success(result))
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
    public let tasksCreated: [Task]
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
