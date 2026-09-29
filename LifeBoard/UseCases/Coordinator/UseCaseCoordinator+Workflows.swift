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

extension UseCaseCoordinator {
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
                        message: String(localized: "No morning tasks")
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
                        message: String(localized: "Morning tasks done")
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
                        message: String(localized: "Nothing from earlier")
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
                        message: String(localized: "Created ‘\(project.name)’ · \(createdTasks.count) tasks")
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
                    message: String(localized: "Day closed")
                )

                completion(.success(workflowResult))
            }
        }
    }
}
