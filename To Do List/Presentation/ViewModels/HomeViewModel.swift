//
//  HomeViewModel.swift
//  Tasker
//
//  ViewModel for Home screen - manages task display and interactions
//

import Foundation
import Combine

/// ViewModel for the Home screen
/// Manages all business logic and state for the home view
public final class HomeViewModel: ObservableObject {
    
    // MARK: - Published Properties (Observable State)
    
    @Published public private(set) var todayTasks: TodayTasksResult?
    @Published public private(set) var selectedDate: Date = Date()
    @Published public private(set) var selectedProject: String = "All"
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var dailyScore: Int = 0
    @Published public private(set) var streak: Int = 0
    @Published public private(set) var completionRate: Double = 0.0
    
    // Task lists by category
    @Published public private(set) var morningTasks: [Task] = []
    @Published public private(set) var eveningTasks: [Task] = []
    @Published public private(set) var overdueTasks: [Task] = []
    @Published public private(set) var upcomingTasks: [Task] = []
    
    // Projects
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var selectedProjectTasks: [Task] = []
    
    // MARK: - Dependencies
    
    private let useCaseCoordinator: UseCaseCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(useCaseCoordinator: UseCaseCoordinator) {
        self.useCaseCoordinator = useCaseCoordinator
        setupBindings()
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    /// Load tasks for the selected date
    public func loadTasksForSelectedDate() {
        isLoading = true
        errorMessage = nil
        
        useCaseCoordinator.getTasks.getTasksForDate(selectedDate) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let dateResult):
                    self?.morningTasks = dateResult.morningTasks
                    self?.eveningTasks = dateResult.eveningTasks
                    self?.overdueTasks = dateResult.overdueTasks
                    self?.updateCompletionRate(dateResult)
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Load tasks for today
    public func loadTodayTasks() {
        print("🔍 [VIEW MODEL] loadTodayTasks called")
        isLoading = true
        errorMessage = nil

        useCaseCoordinator.getTasks.getTodayTasks { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let todayResult):
                    print("🔍 [VIEW MODEL] Received today tasks result:")
                    print("🔍 [VIEW MODEL]   - Morning tasks: \(todayResult.morningTasks.count)")
                    print("🔍 [VIEW MODEL]   - Evening tasks: \(todayResult.eveningTasks.count)")
                    print("🔍 [VIEW MODEL]   - Overdue tasks: \(todayResult.overdueTasks.count)")
                    print("🔍 [VIEW MODEL]   - Completed tasks: \(todayResult.completedTasks.count)")

                    // Log overdue task details
                    for (index, task) in todayResult.overdueTasks.enumerated() {
                        print("🔍 [VIEW MODEL] Overdue task \(index + 1): '\(task.name)' | dueDate: \(task.dueDate?.description ?? "NIL")")
                    }

                    self?.todayTasks = todayResult
                    self?.morningTasks = todayResult.morningTasks
                    self?.eveningTasks = todayResult.eveningTasks
                    self?.overdueTasks = todayResult.overdueTasks
                    self?.updateCompletionRate(todayResult)

                    print("🔍 [VIEW MODEL] Published properties updated")
                    print("🔍 [VIEW MODEL]   - @Published morningTasks: \(self?.morningTasks.count ?? 0)")
                    print("🔍 [VIEW MODEL]   - @Published eveningTasks: \(self?.eveningTasks.count ?? 0)")
                    print("🔍 [VIEW MODEL]   - @Published overdueTasks: \(self?.overdueTasks.count ?? 0)")

                case .failure(let error):
                    print("❌ [VIEW MODEL] Error loading today tasks: \(error)")
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        // Load analytics
        loadDailyAnalytics()
    }
    
    /// Toggle task completion
    public func toggleTaskCompletion(_ task: Task) {
        useCaseCoordinator.completeTask.execute(taskId: task.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let completionResult):
                    // Update score
                    self?.dailyScore += completionResult.scoreEarned
                    
                    // Reload tasks to reflect changes
                    if Calendar.current.isDateInToday(self?.selectedDate ?? Date()) {
                        self?.loadTodayTasks()
                    } else {
                        self?.loadTasksForSelectedDate()
                    }
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Create a new task
    public func createTask(request: CreateTaskRequest) {
        useCaseCoordinator.createTask.execute(request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Reload tasks to show the new task
                    if Calendar.current.isDateInToday(self?.selectedDate ?? Date()) {
                        self?.loadTodayTasks()
                    } else {
                        self?.loadTasksForSelectedDate()
                    }
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Delete a task
    public func deleteTask(_ task: Task) {
        let deleteUseCase = DeleteTaskUseCase(
            taskRepository: useCaseCoordinator.taskRepository,
            notificationService: nil
        )
        
        deleteUseCase.execute(taskId: task.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Reload tasks to reflect deletion
                    if Calendar.current.isDateInToday(self?.selectedDate ?? Date()) {
                        self?.loadTodayTasks()
                    } else {
                        self?.loadTasksForSelectedDate()
                    }
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Reschedule a task
    public func rescheduleTask(_ task: Task, to newDate: Date) {
        useCaseCoordinator.rescheduleTask.execute(taskId: task.id, newDate: newDate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Reload tasks to reflect rescheduling
                    if Calendar.current.isDateInToday(self?.selectedDate ?? Date()) {
                        self?.loadTodayTasks()
                    } else {
                        self?.loadTasksForSelectedDate()
                    }
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Change selected date
    public func selectDate(_ date: Date) {
        selectedDate = date
        
        if Calendar.current.isDateInToday(date) {
            loadTodayTasks()
        } else {
            loadTasksForSelectedDate()
        }
    }
    
    /// Change selected project filter
    public func selectProject(_ projectName: String) {
        selectedProject = projectName
        
        if projectName == "All" {
            loadTasksForSelectedDate()
        } else {
            loadProjectTasks(projectName)
        }
    }
    
    /// Load all projects
    public func loadProjects() {
        useCaseCoordinator.manageProjects.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let projectsWithStats):
                    self?.projects = projectsWithStats.map { $0.project }
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Complete morning routine
    public func completeMorningRoutine() {
        useCaseCoordinator.completeMorningRoutine { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let routineResult):
                    self?.dailyScore += routineResult.totalScore
                    self?.loadTodayTasks()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Reschedule all overdue tasks
    public func rescheduleOverdueTasks() {
        useCaseCoordinator.rescheduleAllOverdueTasks { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadTodayTasks()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Listen for task-related notifications
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated"))
            .sink { [weak self] _ in
                self?.loadTasksForSelectedDate()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskUpdated"))
            .sink { [weak self] _ in
                self?.loadTasksForSelectedDate()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskDeleted"))
            .sink { [weak self] _ in
                self?.loadTasksForSelectedDate()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCompletionChanged"))
            .sink { [weak self] _ in
                self?.loadDailyAnalytics()
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        loadTodayTasks()
        loadProjects()
    }
    
    private func loadDailyAnalytics() {
        useCaseCoordinator.calculateAnalytics.calculateTodayAnalytics { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let analytics) = result {
                    self?.dailyScore = analytics.totalScore
                    self?.completionRate = analytics.completionRate
                }
            }
        }
        
        useCaseCoordinator.calculateAnalytics.calculateStreak { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let streakInfo) = result {
                    self?.streak = streakInfo.currentStreak
                }
            }
        }
    }
    
    private func loadProjectTasks(_ projectName: String) {
        isLoading = true
        
        useCaseCoordinator.getTasks.getTasksForProject(projectName) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let projectResult):
                    self?.selectedProjectTasks = projectResult.tasks
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func updateCompletionRate(_ result: TodayTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }
    
    private func updateCompletionRate(_ result: DateTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }
}

// MARK: - View State

extension HomeViewModel {
    
    /// Combined state for the view
    public var viewState: HomeViewState {
        return HomeViewState(
            isLoading: isLoading,
            errorMessage: errorMessage,
            selectedDate: selectedDate,
            selectedProject: selectedProject,
            morningTasks: morningTasks,
            eveningTasks: eveningTasks,
            overdueTasks: overdueTasks,
            upcomingTasks: upcomingTasks,
            projects: projects,
            dailyScore: dailyScore,
            streak: streak,
            completionRate: completionRate
        )
    }
}

/// State structure for the home view
public struct HomeViewState {
    public let isLoading: Bool
    public let errorMessage: String?
    public let selectedDate: Date
    public let selectedProject: String
    public let morningTasks: [Task]
    public let eveningTasks: [Task]
    public let overdueTasks: [Task]
    public let upcomingTasks: [Task]
    public let projects: [Project]
    public let dailyScore: Int
    public let streak: Int
    public let completionRate: Double
}
