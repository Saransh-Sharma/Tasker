//
//  FilterTasksUseCase.swift
//  Tasker
//
//  Use case for filtering tasks with complex criteria
//  Replaces filtering logic scattered across ViewControllers
//

import Foundation

/// Use case for filtering tasks with advanced criteria
/// This replaces direct filtering logic in ViewControllers
public final class FilterTasksUseCase {
    
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
    
    // MARK: - Filter Methods
    
    /// Filter tasks by multiple criteria
    public func filterTasks(
        criteria: FilterCriteria,
        completion: @escaping (Result<FilteredTasksResult, FilterError>) -> Void
    ) {
        // Generate cache key based on criteria
        let cacheKey = criteria.cacheKey
        
        // Check cache first
        if let cached = cacheService?.getCachedFilterResult(key: cacheKey) {
            completion(.success(cached))
            return
        }
        
        // Fetch base tasks based on scope
        fetchBaseTasks(for: criteria.scope) { [weak self] result in
            switch result {
            case .success(let tasks):
                let filteredTasks = self?.applyFilters(to: tasks, criteria: criteria) ?? []
                let result = FilteredTasksResult(
                    tasks: filteredTasks,
                    criteria: criteria,
                    totalCount: filteredTasks.count,
                    appliedFilters: criteria.activeFilters
                )
                
                // Cache the result
                self?.cacheService?.cacheFilterResult(result, key: cacheKey)
                
                completion(.success(result))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Filter tasks by project
    public func filterByProject(
        _ projectName: String,
        includeCompleted: Bool = false,
        completion: @escaping (Result<[Task], FilterError>) -> Void
    ) {
        let criteria = FilterCriteria(
            scope: .project(projectName),
            completionStatus: includeCompleted ? .all : .incomplete,
            priorities: [],
            categories: [],
            contexts: [],
            energyLevels: [],
            dateRange: nil,
            tags: [],
            hasEstimate: nil,
            hasDependencies: nil
        )
        
        filterTasks(criteria: criteria) { result in
            switch result {
            case .success(let filteredResult):
                completion(.success(filteredResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Filter tasks by priority
    public func filterByPriority(
        _ priorities: [TaskPriority],
        in scope: FilterScope = .all,
        completion: @escaping (Result<[Task], FilterError>) -> Void
    ) {
        let criteria = FilterCriteria(
            scope: scope,
            completionStatus: .incomplete,
            priorities: priorities,
            categories: [],
            contexts: [],
            energyLevels: [],
            dateRange: nil,
            tags: [],
            hasEstimate: nil,
            hasDependencies: nil
        )
        
        filterTasks(criteria: criteria) { result in
            switch result {
            case .success(let filteredResult):
                completion(.success(filteredResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Filter tasks by category
    public func filterByCategory(
        _ categories: [TaskCategory],
        completion: @escaping (Result<[Task], FilterError>) -> Void
    ) {
        let criteria = FilterCriteria(
            scope: .all,
            completionStatus: .incomplete,
            priorities: [],
            categories: categories,
            contexts: [],
            energyLevels: [],
            dateRange: nil,
            tags: [],
            hasEstimate: nil,
            hasDependencies: nil
        )
        
        filterTasks(criteria: criteria) { result in
            switch result {
            case .success(let filteredResult):
                completion(.success(filteredResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Filter tasks by context
    public func filterByContext(
        _ contexts: [TaskContext],
        completion: @escaping (Result<[Task], FilterError>) -> Void
    ) {
        let criteria = FilterCriteria(
            scope: .all,
            completionStatus: .incomplete,
            priorities: [],
            categories: [],
            contexts: contexts,
            energyLevels: [],
            dateRange: nil,
            tags: [],
            hasEstimate: nil,
            hasDependencies: nil
        )
        
        filterTasks(criteria: criteria) { result in
            switch result {
            case .success(let filteredResult):
                completion(.success(filteredResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Filter tasks by energy level
    public func filterByEnergyLevel(
        _ energyLevels: [TaskEnergy],
        completion: @escaping (Result<[Task], FilterError>) -> Void
    ) {
        let criteria = FilterCriteria(
            scope: .all,
            completionStatus: .incomplete,
            priorities: [],
            categories: [],
            contexts: [],
            energyLevels: energyLevels,
            dateRange: nil,
            tags: [],
            hasEstimate: nil,
            hasDependencies: nil
        )
        
        filterTasks(criteria: criteria) { result in
            switch result {
            case .success(let filteredResult):
                completion(.success(filteredResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Filter tasks by date range
    public func filterByDateRange(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[Task], FilterError>) -> Void
    ) {
        let criteria = FilterCriteria(
            scope: .all,
            completionStatus: .all,
            priorities: [],
            categories: [],
            contexts: [],
            energyLevels: [],
            dateRange: DateRange(start: startDate, end: endDate),
            tags: [],
            hasEstimate: nil,
            hasDependencies: nil
        )
        
        filterTasks(criteria: criteria) { result in
            switch result {
            case .success(let filteredResult):
                completion(.success(filteredResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Filter tasks by tags
    public func filterByTags(
        _ tags: [String],
        matchMode: TagMatchMode = .any,
        completion: @escaping (Result<[Task], FilterError>) -> Void
    ) {
        let criteria = FilterCriteria(
            scope: .all,
            completionStatus: .incomplete,
            priorities: [],
            categories: [],
            contexts: [],
            energyLevels: [],
            dateRange: nil,
            tags: tags,
            hasEstimate: nil,
            hasDependencies: nil,
            tagMatchMode: matchMode
        )
        
        filterTasks(criteria: criteria) { result in
            switch result {
            case .success(let filteredResult):
                completion(.success(filteredResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchBaseTasks(
        for scope: FilterScope,
        completion: @escaping (Result<[Task], Error>) -> Void
    ) {
        switch scope {
        case .all:
            taskRepository.fetchAllTasks(completion: completion)
        case .today:
            taskRepository.fetchTodayTasks(completion: completion)
        case .upcoming:
            taskRepository.fetchUpcomingTasks(completion: completion)
        case .overdue:
            taskRepository.fetchOverdueTasks(completion: completion)
        case .project(let name):
            taskRepository.fetchTasks(for: name, completion: completion)
        case .dateRange(let start, let end):
            taskRepository.fetchTasks(from: start, to: end, completion: completion)
        }
    }
    
    private func applyFilters(to tasks: [Task], criteria: FilterCriteria) -> [Task] {
        return tasks.filter { task in
            // Completion status filter
            switch criteria.completionStatus {
            case .complete:
                if !task.isComplete { return false }
            case .incomplete:
                if task.isComplete { return false }
            case .all:
                break
            }
            
            // Priority filter
            if !criteria.priorities.isEmpty && !criteria.priorities.contains(task.priority) {
                return false
            }
            
            // Category filter
            if !criteria.categories.isEmpty && !criteria.categories.contains(task.category) {
                return false
            }
            
            // Context filter
            if !criteria.contexts.isEmpty && !criteria.contexts.contains(task.context) {
                return false
            }
            
            // Energy level filter
            if !criteria.energyLevels.isEmpty && !criteria.energyLevels.contains(task.energy) {
                return false
            }
            
            // Date range filter
            if let dateRange = criteria.dateRange {
                if let dueDate = task.dueDate {
                    if dueDate < dateRange.start || dueDate > dateRange.end {
                        return false
                    }
                } else if criteria.requireDueDate {
                    return false
                }
            }
            
            // Tags filter
            if !criteria.tags.isEmpty {
                switch criteria.tagMatchMode {
                case .any:
                    let hasAnyTag = criteria.tags.contains { tag in
                        task.tags.contains(tag)
                    }
                    if !hasAnyTag { return false }
                case .all:
                    let hasAllTags = criteria.tags.allSatisfy { tag in
                        task.tags.contains(tag)
                    }
                    if !hasAllTags { return false }
                }
            }
            
            // Has estimate filter
            if let requiresEstimate = criteria.hasEstimate {
                if requiresEstimate && task.estimatedDuration == nil {
                    return false
                }
                if !requiresEstimate && task.estimatedDuration != nil {
                    return false
                }
            }
            
            // Has dependencies filter
            if let requiresDependencies = criteria.hasDependencies {
                if requiresDependencies && task.dependencies.isEmpty {
                    return false
                }
                if !requiresDependencies && !task.dependencies.isEmpty {
                    return false
                }
            }
            
            return true
        }
    }
}

// MARK: - Supporting Models

public struct FilterCriteria {
    public let scope: FilterScope
    public let completionStatus: CompletionStatusFilter
    public let priorities: [TaskPriority]
    public let categories: [TaskCategory]
    public let contexts: [TaskContext]
    public let energyLevels: [TaskEnergy]
    public let dateRange: DateRange?
    public let tags: [String]
    public let hasEstimate: Bool?
    public let hasDependencies: Bool?
    public let tagMatchMode: TagMatchMode
    public let requireDueDate: Bool
    
    public init(
        scope: FilterScope,
        completionStatus: CompletionStatusFilter,
        priorities: [TaskPriority],
        categories: [TaskCategory],
        contexts: [TaskContext],
        energyLevels: [TaskEnergy],
        dateRange: DateRange?,
        tags: [String],
        hasEstimate: Bool? = nil,
        hasDependencies: Bool? = nil,
        tagMatchMode: TagMatchMode = .any,
        requireDueDate: Bool = false
    ) {
        self.scope = scope
        self.completionStatus = completionStatus
        self.priorities = priorities
        self.categories = categories
        self.contexts = contexts
        self.energyLevels = energyLevels
        self.dateRange = dateRange
        self.tags = tags
        self.hasEstimate = hasEstimate
        self.hasDependencies = hasDependencies
        self.tagMatchMode = tagMatchMode
        self.requireDueDate = requireDueDate
    }
    
    /// Generate cache key for this criteria
    var cacheKey: String {
        var components: [String] = []
        components.append("scope:\(scope)")
        components.append("status:\(completionStatus)")
        if !priorities.isEmpty { components.append("priorities:\(priorities.map(\.rawValue))") }
        if !categories.isEmpty { components.append("categories:\(categories.map(\.rawValue))") }
        if !contexts.isEmpty { components.append("contexts:\(contexts.map(\.rawValue))") }
        if !energyLevels.isEmpty { components.append("energy:\(energyLevels.map(\.rawValue))") }
        if let dateRange = dateRange { components.append("dates:\(dateRange.start)-\(dateRange.end)") }
        if !tags.isEmpty { components.append("tags:\(tags.joined(separator:","))") }
        if let hasEstimate = hasEstimate { components.append("estimate:\(hasEstimate)") }
        if let hasDependencies = hasDependencies { components.append("deps:\(hasDependencies)") }
        
        return components.joined(separator:"|")
    }
    
    /// Get list of active filters for display
    var activeFilters: [String] {
        var filters: [String] = []
        
        if completionStatus != .all {
            filters.append(completionStatus.displayName)
        }
        if !priorities.isEmpty {
            filters.append("Priorities: \(priorities.map(\.displayName).joined(separator: ", "))")
        }
        if !categories.isEmpty {
            filters.append("Categories: \(categories.map(\.displayName).joined(separator: ", "))")
        }
        if !contexts.isEmpty {
            filters.append("Contexts: \(contexts.map(\.displayName).joined(separator: ", "))")
        }
        if !energyLevels.isEmpty {
            filters.append("Energy: \(energyLevels.map(\.displayName).joined(separator: ", "))")
        }
        if let dateRange = dateRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            filters.append("Date: \(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))")
        }
        if !tags.isEmpty {
            filters.append("Tags: \(tags.joined(separator: ", "))")
        }
        
        return filters
    }
}

public enum FilterScope {
    case all
    case today
    case upcoming
    case overdue
    case project(String)
    case dateRange(Date, Date)
}

public enum CompletionStatusFilter {
    case all
    case complete
    case incomplete
    
    var displayName: String {
        switch self {
        case .all: return "All Tasks"
        case .complete: return "Completed"
        case .incomplete: return "Incomplete"
        }
    }
}

public enum TagMatchMode {
    case any // Task must have at least one of the specified tags
    case all // Task must have all specified tags
}

public struct DateRange {
    public let start: Date
    public let end: Date
    
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public struct FilteredTasksResult {
    public let tasks: [Task]
    public let criteria: FilterCriteria
    public let totalCount: Int
    public let appliedFilters: [String]
}

// MARK: - Error Types

public enum FilterError: LocalizedError {
    case repositoryError(Error)
    case invalidCriteria(String)
    case invalidDateRange
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .invalidCriteria(let message):
            return "Invalid filter criteria: \(message)"
        case .invalidDateRange:
            return "Invalid date range specified"
        }
    }
}