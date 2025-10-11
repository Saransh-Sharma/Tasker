//
//  GetTasksUseCase.swift
//  Tasker
//
//  Use case for retrieving tasks with various filters and sorting
//

import Foundation

/// Use case for retrieving tasks with complex filtering
/// Handles all task query operations with business logic
public final class GetTasksUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let cacheService: CacheServiceProtocol?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        cacheService: CacheServiceProtocol? = nil
    ) {
        self.taskRepository = taskRepository
        self.cacheService = cacheService
    }
    
    // MARK: - Task Retrieval Methods
    
    /// Get tasks for today's schedule
    public func getTodayTasks(completion: @escaping (Result<TodayTasksResult, GetTasksError>) -> Void) {
        print("🔍 [USE CASE] getTodayTasks called")

        // Check cache first
        if let cached = cacheService?.getCachedTasks(forDate: Date()) {
            print("🔍 [USE CASE] Using cached tasks: \(cached.count) tasks")
            let result = categorizeTodayTasks(cached)
            completion(.success(result))
            return
        }

        print("🔍 [USE CASE] No cache, fetching from repository")

        // Fetch from repository
        taskRepository.fetchTodayTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                print("🔍 [USE CASE] Repository returned \(tasks.count) tasks")

                // Cache the results
                self?.cacheService?.cacheTasks(tasks, forDate: Date())

                // Categorize and return
                let categorized = self?.categorizeTodayTasks(tasks) ?? TodayTasksResult()
                print("🔍 [USE CASE] Categorized tasks:")
                print("🔍 [USE CASE]   - Morning: \(categorized.morningTasks.count)")
                print("🔍 [USE CASE]   - Evening: \(categorized.eveningTasks.count)")
                print("🔍 [USE CASE]   - Overdue: \(categorized.overdueTasks.count)")
                print("🔍 [USE CASE]   - Completed: \(categorized.completedTasks.count)")
                print("🔍 [USE CASE]   - Total: \(categorized.totalCount)")

                completion(.success(categorized))

            case .failure(let error):
                print("❌ [USE CASE] Repository error: \(error)")
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get tasks for a specific date
    public func getTasksForDate(
        _ date: Date,
        completion: @escaping (Result<DateTasksResult, GetTasksError>) -> Void
    ) {
        // Check if requesting today
        if Calendar.current.isDateInToday(date) {
            getTodayTasks { result in
                switch result {
                case .success(let todayResult):
                    let dateResult = DateTasksResult(
                        date: date,
                        morningTasks: todayResult.morningTasks,
                        eveningTasks: todayResult.eveningTasks,
                        overdueTasks: todayResult.overdueTasks,
                        completedTasks: todayResult.completedTasks,
                        totalCount: todayResult.totalCount
                    )
                    completion(.success(dateResult))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return
        }
        
        // Fetch tasks for specific date
        taskRepository.fetchTasks(for: date) { [weak self] result in
            switch result {
            case .success(let tasks):
                let categorized = self?.categorizeTasksForDate(tasks, date: date) ?? DateTasksResult(date: date)
                completion(.success(categorized))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get tasks for a specific project
    public func getTasksForProject(
        _ projectName: String,
        includeCompleted: Bool = true,
        completion: @escaping (Result<ProjectTasksResult, GetTasksError>) -> Void
    ) {
        // Check cache
        if let cached = cacheService?.getCachedTasks(forProject: projectName) {
            let filtered = includeCompleted ? cached : cached.filter { !$0.isComplete }
            let result = ProjectTasksResult(
                projectName: projectName,
                tasks: filtered,
                openCount: cached.filter { !$0.isComplete }.count,
                completedCount: cached.filter { $0.isComplete }.count
            )
            completion(.success(result))
            return
        }
        
        // Fetch from repository
        taskRepository.fetchTasks(for: projectName) { [weak self] result in
            switch result {
            case .success(let tasks):
                // Cache the results
                self?.cacheService?.cacheTasks(tasks, forProject: projectName)
                
                // Filter and return
                let filtered = includeCompleted ? tasks : tasks.filter { !$0.isComplete }
                let projectResult = ProjectTasksResult(
                    projectName: projectName,
                    tasks: filtered,
                    openCount: tasks.filter { !$0.isComplete }.count,
                    completedCount: tasks.filter { $0.isComplete }.count
                )
                completion(.success(projectResult))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get overdue tasks
    public func getOverdueTasks(completion: @escaping (Result<[Task], GetTasksError>) -> Void) {
        taskRepository.fetchOverdueTasks { result in
            switch result {
            case .success(let tasks):
                // Sort by priority and due date
                let sorted = tasks.sorted { task1, task2 in
                    // First by priority (higher priority first)
                    if task1.priority.rawValue != task2.priority.rawValue {
                        return task1.priority.rawValue < task2.priority.rawValue
                    }
                    // Then by due date (older first)
                    return (task1.dueDate ?? Date()) < (task2.dueDate ?? Date())
                }
                completion(.success(sorted))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get upcoming tasks (future tasks beyond today)
    public func getUpcomingTasks(completion: @escaping (Result<UpcomingTasksResult, GetTasksError>) -> Void) {
        taskRepository.fetchUpcomingTasks { result in
            switch result {
            case .success(let tasks):
                let categorized = self.categorizeUpcomingTasks(tasks)
                completion(.success(categorized))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get tasks by type (morning, evening, upcoming)
    public func getTasksByType(
        _ type: TaskType,
        for date: Date? = nil,
        completion: @escaping (Result<[Task], GetTasksError>) -> Void
    ) {
        if let date = date {
            // Get tasks of specific type for a specific date
            taskRepository.fetchTasks(for: date) { result in
                switch result {
                case .success(let tasks):
                    let filtered = tasks.filter { $0.type == type }
                    completion(.success(filtered))
                case .failure(let error):
                    completion(.failure(.repositoryError(error)))
                }
            }
        } else {
            // Get all tasks of specific type
            taskRepository.fetchTasks(ofType: type, completion: { result in
                switch result {
                case .success(let tasks):
                    completion(.success(tasks))
                case .failure(let error):
                    completion(.failure(.repositoryError(error)))
                }
            })
        }
    }
    
    /// Search tasks by name or details
    public func searchTasks(
        query: String,
        in scope: GetTasksScope = .all,
        completion: @escaping (Result<[Task], GetTasksError>) -> Void
    ) {
        let fetchCompletion: (Result<[Task], Error>) -> Void = { result in
            switch result {
            case .success(let tasks):
                let filtered = tasks.filter { task in
                    let nameMatch = task.name.localizedCaseInsensitiveContains(query)
                    let detailsMatch = task.details?.localizedCaseInsensitiveContains(query) ?? false
                    return nameMatch || detailsMatch
                }
                completion(.success(filtered))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
        
        switch scope {
        case .all:
            taskRepository.fetchAllTasks(completion: fetchCompletion)
        case .today:
            taskRepository.fetchTodayTasks(completion: fetchCompletion)
        case .upcoming:
            taskRepository.fetchUpcomingTasks(completion: fetchCompletion)
        case .project(let name):
            taskRepository.fetchTasks(for: name, completion: fetchCompletion)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func categorizeTodayTasks(_ tasks: [Task]) -> TodayTasksResult {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        print("🔍 [USE CASE - CATEGORIZE] Categorizing \(tasks.count) tasks")
        print("🔍 [USE CASE - CATEGORIZE] Current time: \(now)")
        print("🔍 [USE CASE - CATEGORIZE] Start of day: \(startOfDay)")

        var morningTasks: [Task] = []
        var eveningTasks: [Task] = []
        var overdueTasks: [Task] = []
        var completedTasks: [Task] = []

        for (index, task) in tasks.enumerated() {
            print("🔍 [USE CASE - CATEGORIZE] Task \(index + 1): '\(task.name)'")
            print("   - isComplete: \(task.isComplete)")
            print("   - dueDate: \(task.dueDate?.description ?? "NIL")")
            print("   - type: \(task.type)")
            print("   - isOverdue: \(task.isOverdue)")

            if task.isComplete {
                print("   ➡️ CATEGORIZED AS: COMPLETED")
                completedTasks.append(task)
            } else if let dueDate = task.dueDate, dueDate < startOfDay {
                print("   ➡️ CATEGORIZED AS: OVERDUE (dueDate \(dueDate) < startOfDay \(startOfDay))")
                overdueTasks.append(task)
            } else if task.type == .morning {
                print("   ➡️ CATEGORIZED AS: MORNING")
                morningTasks.append(task)
            } else if task.type == .evening {
                print("   ➡️ CATEGORIZED AS: EVENING")
                eveningTasks.append(task)
            } else {
                print("   ⚠️ NOT CATEGORIZED! type: \(task.type)")
            }
        }

        print("🔍 [USE CASE - CATEGORIZE] Final counts:")
        print("   - Morning: \(morningTasks.count)")
        print("   - Evening: \(eveningTasks.count)")
        print("   - Overdue: \(overdueTasks.count)")
        print("   - Completed: \(completedTasks.count)")

        return TodayTasksResult(
            morningTasks: morningTasks.sorted { ($0.priority.rawValue, $0.dueDate ?? Date()) < ($1.priority.rawValue, $1.dueDate ?? Date()) },
            eveningTasks: eveningTasks.sorted { ($0.priority.rawValue, $0.dueDate ?? Date()) < ($1.priority.rawValue, $1.dueDate ?? Date()) },
            overdueTasks: overdueTasks.sorted { ($0.priority.rawValue, $0.dueDate ?? Date()) < ($1.priority.rawValue, $1.dueDate ?? Date()) },
            completedTasks: completedTasks.sorted { ($0.dateCompleted ?? Date()) > ($1.dateCompleted ?? Date()) },
            totalCount: tasks.count
        )
    }
    
    private func categorizeTasksForDate(_ tasks: [Task], date: Date) -> DateTasksResult {
        var morningTasks: [Task] = []
        var eveningTasks: [Task] = []
        var overdueTasks: [Task] = []
        var completedTasks: [Task] = []
        
        let startOfDate = Calendar.current.startOfDay(for: date)
        
        for task in tasks {
            if task.isComplete {
                completedTasks.append(task)
            } else if let dueDate = task.dueDate, dueDate < startOfDate {
                overdueTasks.append(task)
            } else if task.type == .morning {
                morningTasks.append(task)
            } else if task.type == .evening {
                eveningTasks.append(task)
            }
        }
        
        return DateTasksResult(
            date: date,
            morningTasks: morningTasks,
            eveningTasks: eveningTasks,
            overdueTasks: overdueTasks,
            completedTasks: completedTasks,
            totalCount: tasks.count
        )
    }
    
    private func categorizeUpcomingTasks(_ tasks: [Task]) -> UpcomingTasksResult {
        var thisWeek: [Task] = []
        var nextWeek: [Task] = []
        var thisMonth: [Task] = []
        var later: [Task] = []
        
        let calendar = Calendar.current
        let now = Date()
        
        guard let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end,
              let endOfNextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: endOfWeek),
              let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end else {
            return UpcomingTasksResult(thisWeek: tasks, nextWeek: [], thisMonth: [], later: [])
        }
        
        for task in tasks {
            guard let dueDate = task.dueDate else { continue }
            
            if dueDate <= endOfWeek {
                thisWeek.append(task)
            } else if dueDate <= endOfNextWeek {
                nextWeek.append(task)
            } else if dueDate <= endOfMonth {
                thisMonth.append(task)
            } else {
                later.append(task)
            }
        }
        
        return UpcomingTasksResult(
            thisWeek: thisWeek,
            nextWeek: nextWeek,
            thisMonth: thisMonth,
            later: later
        )
    }
}

// MARK: - Result Models

public struct TodayTasksResult {
    public let morningTasks: [Task]
    public let eveningTasks: [Task]
    public let overdueTasks: [Task]
    public let completedTasks: [Task]
    public let totalCount: Int
    
    init(
        morningTasks: [Task] = [],
        eveningTasks: [Task] = [],
        overdueTasks: [Task] = [],
        completedTasks: [Task] = [],
        totalCount: Int = 0
    ) {
        self.morningTasks = morningTasks
        self.eveningTasks = eveningTasks
        self.overdueTasks = overdueTasks
        self.completedTasks = completedTasks
        self.totalCount = totalCount
    }
}

public struct DateTasksResult {
    public let date: Date
    public let morningTasks: [Task]
    public let eveningTasks: [Task]
    public let overdueTasks: [Task]
    public let completedTasks: [Task]
    public let totalCount: Int
    
    init(
        date: Date,
        morningTasks: [Task] = [],
        eveningTasks: [Task] = [],
        overdueTasks: [Task] = [],
        completedTasks: [Task] = [],
        totalCount: Int = 0
    ) {
        self.date = date
        self.morningTasks = morningTasks
        self.eveningTasks = eveningTasks
        self.overdueTasks = overdueTasks
        self.completedTasks = completedTasks
        self.totalCount = totalCount
    }
}

public struct ProjectTasksResult {
    public let projectName: String
    public let tasks: [Task]
    public let openCount: Int
    public let completedCount: Int
}

public struct UpcomingTasksResult {
    public let thisWeek: [Task]
    public let nextWeek: [Task]
    public let thisMonth: [Task]
    public let later: [Task]
}

// MARK: - Supporting Types

public enum GetTasksScope {
    case all
    case today
    case upcoming
    case project(String)
}

public enum GetTasksError: LocalizedError {
    case repositoryError(Error)
    case invalidDateRange
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .invalidDateRange:
            return "Invalid date range specified"
        }
    }
}
