//
//  GetTaskStatisticsUseCase.swift
//  Tasker
//
//  Use case for generating comprehensive task statistics and analytics
//

import Foundation

/// Use case for generating task statistics and analytics
public final class GetTaskStatisticsUseCase {
    
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
    
    // MARK: - Statistics Methods
    
    /// Get comprehensive task statistics
    public func getTaskStatistics(
        scope: StatisticsScope = .all,
        completion: @escaping (Result<TaskStatistics, StatisticsError>) -> Void
    ) {
        fetchTasksForScope(scope) { [weak self] result in
            switch result {
            case .success(let tasks):
                let statistics = self?.calculateStatistics(for: tasks, scope: scope) ?? TaskStatistics()
                completion(.success(statistics))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get daily statistics for today
    public func getDailyStatistics(
        for date: Date = Date(),
        completion: @escaping (Result<DailyStatistics, StatisticsError>) -> Void
    ) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        taskRepository.fetchTasks(from: startOfDay, to: endOfDay) { [weak self] result in
            switch result {
            case .success(let tasks):
                let dailyStats = self?.calculateDailyStatistics(for: tasks, date: date) ?? DailyStatistics(date: date)
                completion(.success(dailyStats))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get project statistics
    public func getProjectStatistics(
        for projectName: String,
        completion: @escaping (Result<ProjectStatistics, StatisticsError>) -> Void
    ) {
        taskRepository.fetchTasks(for: projectName) { [weak self] result in
            switch result {
            case .success(let tasks):
                let projectStats = self?.calculateProjectStatistics(for: tasks, projectName: projectName) ?? ProjectStatistics(projectName: projectName)
                completion(.success(projectStats))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchTasksForScope(
        _ scope: StatisticsScope,
        completion: @escaping (Result<[Task], Error>) -> Void
    ) {
        switch scope {
        case .all:
            taskRepository.fetchAllTasks(completion: completion)
        case .today:
            taskRepository.fetchTodayTasks(completion: completion)
        case .completed:
            taskRepository.fetchCompletedTasks(completion: completion)
        case .project(let name):
            taskRepository.fetchTasks(for: name, completion: completion)
        }
    }
    
    private func calculateStatistics(for tasks: [Task], scope: StatisticsScope) -> TaskStatistics {
        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.isComplete }.count
        let incompleteTasks = totalTasks - completedTasks
        let overdueTasks = tasks.filter { $0.isOverdue }.count
        let completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        
        let priorityBreakdown = TaskPriority.allCases.reduce(into: [TaskPriority: Int]()) { result, priority in
            result[priority] = tasks.filter { $0.priority == priority }.count
        }
        
        return TaskStatistics(
            scope: scope,
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            incompleteTasks: incompleteTasks,
            overdueTasks: overdueTasks,
            completionRate: completionRate,
            priorityBreakdown: priorityBreakdown
        )
    }
    
    private func calculateDailyStatistics(for tasks: [Task], date: Date) -> DailyStatistics {
        let completedToday = tasks.filter { task in
            guard let completionDate = task.dateCompleted else { return false }
            return Calendar.current.isDate(completionDate, inSameDayAs: date)
        }
        
        let morningTasks = tasks.filter { $0.type == .morning }
        let eveningTasks = tasks.filter { $0.type == .evening }
        let totalScore = completedToday.reduce(0) { $0 + $1.score }
        
        return DailyStatistics(
            date: date,
            totalTasks: tasks.count,
            completedTasks: completedToday.count,
            morningTasks: morningTasks.count,
            eveningTasks: eveningTasks.count,
            totalScore: totalScore
        )
    }
    
    private func calculateProjectStatistics(for tasks: [Task], projectName: String) -> ProjectStatistics {
        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.isComplete }.count
        let overdueTasks = tasks.filter { $0.isOverdue }.count
        let totalScore = tasks.filter { $0.isComplete }.reduce(0) { $0 + $1.score }
        let completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        
        return ProjectStatistics(
            projectName: projectName,
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            overdueTasks: overdueTasks,
            totalScore: totalScore,
            completionRate: completionRate
        )
    }
}

// MARK: - Supporting Models

public enum StatisticsScope: Codable {
    case all
    case today
    case completed
    case project(String)
}

public struct TaskStatistics: Codable {
    public let scope: StatisticsScope
    public let totalTasks: Int
    public let completedTasks: Int
    public let incompleteTasks: Int
    public let overdueTasks: Int
    public let completionRate: Double
    public let priorityBreakdown: [TaskPriority: Int]

    init(
        scope: StatisticsScope = .all,
        totalTasks: Int = 0,
        completedTasks: Int = 0,
        incompleteTasks: Int = 0,
        overdueTasks: Int = 0,
        completionRate: Double = 0,
        priorityBreakdown: [TaskPriority: Int] = [:]
    ) {
        self.scope = scope
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.incompleteTasks = incompleteTasks
        self.overdueTasks = overdueTasks
        self.completionRate = completionRate
        self.priorityBreakdown = priorityBreakdown
    }

    // Custom Codable implementation for dictionary with enum key
    enum CodingKeys: String, CodingKey {
        case scope, totalTasks, completedTasks, incompleteTasks, overdueTasks, completionRate, priorityBreakdown
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scope = try container.decode(StatisticsScope.self, forKey: .scope)
        totalTasks = try container.decode(Int.self, forKey: .totalTasks)
        completedTasks = try container.decode(Int.self, forKey: .completedTasks)
        incompleteTasks = try container.decode(Int.self, forKey: .incompleteTasks)
        overdueTasks = try container.decode(Int.self, forKey: .overdueTasks)
        completionRate = try container.decode(Double.self, forKey: .completionRate)

        // Decode dictionary with string keys and convert to TaskPriority
        let stringKeyedDict = try container.decode([String: Int].self, forKey: .priorityBreakdown)
        var breakdown: [TaskPriority: Int] = [:]
        for (key, value) in stringKeyedDict {
            guard let rawValue = Int32(key) else { continue }
            // Validate rawValue before creating TaskPriority to avoid silently mapping invalid values to .none
            guard TaskPriorityConfig.isValidPriority(rawValue) else {
                continue
            }
            let priority = TaskPriority(rawValue: rawValue)
            breakdown[priority] = value
        }
        priorityBreakdown = breakdown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scope, forKey: .scope)
        try container.encode(totalTasks, forKey: .totalTasks)
        try container.encode(completedTasks, forKey: .completedTasks)
        try container.encode(incompleteTasks, forKey: .incompleteTasks)
        try container.encode(overdueTasks, forKey: .overdueTasks)
        try container.encode(completionRate, forKey: .completionRate)

        // Encode dictionary with string keys
        var stringKeyedDict: [String: Int] = [:]
        for (key, value) in priorityBreakdown {
            stringKeyedDict[String(key.rawValue)] = value
        }
        try container.encode(stringKeyedDict, forKey: .priorityBreakdown)
    }
}

public struct DailyStatistics {
    public let date: Date
    public let totalTasks: Int
    public let completedTasks: Int
    public let morningTasks: Int
    public let eveningTasks: Int
    public let totalScore: Int
    
    init(
        date: Date,
        totalTasks: Int = 0,
        completedTasks: Int = 0,
        morningTasks: Int = 0,
        eveningTasks: Int = 0,
        totalScore: Int = 0
    ) {
        self.date = date
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.morningTasks = morningTasks
        self.eveningTasks = eveningTasks
        self.totalScore = totalScore
    }
}

public struct ProjectStatistics {
    public let projectName: String
    public let totalTasks: Int
    public let completedTasks: Int
    public let overdueTasks: Int
    public let totalScore: Int
    public let completionRate: Double
    
    init(
        projectName: String,
        totalTasks: Int = 0,
        completedTasks: Int = 0,
        overdueTasks: Int = 0,
        totalScore: Int = 0,
        completionRate: Double = 0
    ) {
        self.projectName = projectName
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.overdueTasks = overdueTasks
        self.totalScore = totalScore
        self.completionRate = completionRate
    }
}

// MARK: - Error Types

public enum StatisticsError: LocalizedError {
    case repositoryError(Error)
    case invalidDateRange
    case noDataAvailable
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .invalidDateRange:
            return "Invalid date range specified"
        case .noDataAvailable:
            return "No data available for statistics"
        }
    }
}
