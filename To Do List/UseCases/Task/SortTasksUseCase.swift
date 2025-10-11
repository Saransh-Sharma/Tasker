//
//  SortTasksUseCase.swift
//  Tasker
//
//  Use case for sorting tasks with multiple criteria and advanced options
//  Replaces sorting logic scattered across ViewControllers
//

import Foundation

/// Use case for sorting tasks with complex criteria
/// This replaces direct sorting logic in ViewControllers and provides consistent sorting across the app
public final class SortTasksUseCase {
    
    // MARK: - Dependencies
    
    private let cacheService: CacheServiceProtocol?
    
    // MARK: - Initialization
    
    public init(cacheService: CacheServiceProtocol? = nil) {
        self.cacheService = cacheService
    }
    
    // MARK: - Sort Methods
    
    /// Sort tasks with comprehensive criteria
    public func sortTasks(
        _ tasks: [Task],
        criteria: SortCriteria,
        completion: @escaping (Result<SortedTasksResult, SortError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let sortedTasks = try self?.performSort(tasks: tasks, criteria: criteria) ?? []
                let result = SortedTasksResult(
                    tasks: sortedTasks,
                    criteria: criteria,
                    sortTime: Date()
                )
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.sortingFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Sort by priority (most common sorting)
    public func sortByPriority(
        _ tasks: [Task],
        order: SortOrder = .ascending,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = SortCriteria(
            primarySort: .priority(order),
            secondarySort: .dueDate(.ascending),
            tertiarySort: .name(.ascending)
        )
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sort by due date
    public func sortByDueDate(
        _ tasks: [Task],
        order: SortOrder = .ascending,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = SortCriteria(
            primarySort: .dueDate(order),
            secondarySort: .priority(.ascending),
            tertiarySort: .name(.ascending)
        )
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sort by name (alphabetical)
    public func sortByName(
        _ tasks: [Task],
        order: SortOrder = .ascending,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = SortCriteria(
            primarySort: .name(order),
            secondarySort: .priority(.ascending),
            tertiarySort: .dueDate(.ascending)
        )
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sort by creation date
    public func sortByCreationDate(
        _ tasks: [Task],
        order: SortOrder = .descending,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = SortCriteria(
            primarySort: .dateAdded(order),
            secondarySort: .priority(.ascending),
            tertiarySort: .name(.ascending)
        )
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sort by completion date
    public func sortByCompletionDate(
        _ tasks: [Task],
        order: SortOrder = .descending,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = SortCriteria(
            primarySort: .dateCompleted(order),
            secondarySort: .priority(.ascending),
            tertiarySort: .name(.ascending)
        )
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sort by project
    public func sortByProject(
        _ tasks: [Task],
        order: SortOrder = .ascending,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = SortCriteria(
            primarySort: .project(order),
            secondarySort: .priority(.ascending),
            tertiarySort: .dueDate(.ascending)
        )
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sort by category
    public func sortByCategory(
        _ tasks: [Task],
        order: SortOrder = .ascending,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = SortCriteria(
            primarySort: .category(order),
            secondarySort: .priority(.ascending),
            tertiarySort: .name(.ascending)
        )
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sort by energy level
    public func sortByEnergyLevel(
        _ tasks: [Task],
        order: SortOrder = .ascending,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = SortCriteria(
            primarySort: .energy(order),
            secondarySort: .priority(.ascending),
            tertiarySort: .dueDate(.ascending)
        )
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sort by estimated duration
    public func sortByEstimatedDuration(
        _ tasks: [Task],
        order: SortOrder = .ascending,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = SortCriteria(
            primarySort: .estimatedDuration(order),
            secondarySort: .priority(.ascending),
            tertiarySort: .name(.ascending)
        )
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Smart sort - context-aware sorting based on current time and user behavior
    public func smartSort(
        _ tasks: [Task],
        context: SortContext = .general,
        completion: @escaping (Result<[Task], SortError>) -> Void
    ) {
        let criteria = determineSmartSortCriteria(for: context)
        
        sortTasks(tasks, criteria: criteria) { result in
            switch result {
            case .success(let sortedResult):
                completion(.success(sortedResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Group and sort tasks by category or project
    public func groupAndSort(
        _ tasks: [Task],
        groupBy: GroupingCriteria,
        sortWithinGroups: SortField = .priority(.ascending),
        completion: @escaping (Result<GroupedTasksResult, SortError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let groupedTasks = self.groupTasks(tasks, by: groupBy, sortedBy: sortWithinGroups)
            let result = GroupedTasksResult(
                groups: groupedTasks,
                groupingCriteria: groupBy,
                sortCriteria: sortWithinGroups
            )
            
            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func performSort(tasks: [Task], criteria: SortCriteria) throws -> [Task] {
        return tasks.sorted { task1, task2 in
            // Primary sort
            let primaryResult = compareTasksBy(task1, task2, field: criteria.primarySort)
            if primaryResult != ComparisonResult.orderedSame {
                return primaryResult == ComparisonResult.orderedAscending
            }
            
            // Secondary sort
            if let secondarySort = criteria.secondarySort {
                let secondaryResult = compareTasksBy(task1, task2, field: secondarySort)
                if secondaryResult != ComparisonResult.orderedSame {
                    return secondaryResult == ComparisonResult.orderedAscending
                }
            }
            
            // Tertiary sort
            if let tertiarySort = criteria.tertiarySort {
                let tertiaryResult = compareTasksBy(task1, task2, field: tertiarySort)
                return tertiaryResult == ComparisonResult.orderedAscending
            }
            
            return false
        }
    }
    
    private func compareTasksBy(_ task1: Task, _ task2: Task, field: SortField) -> ComparisonResult {
        switch field {
        case .priority(let order):
            let comparison = compareInts(Int(task1.priority.rawValue), Int(task2.priority.rawValue))
            return order == .ascending ? comparison : invertComparison(comparison)
            
        case .dueDate(let order):
            let date1 = task1.dueDate ?? Date.distantFuture
            let date2 = task2.dueDate ?? Date.distantFuture
            let comparison = date1.compare(date2)
            return order == .ascending ? comparison : invertComparison(comparison)
            
        case .name(let order):
            let comparison = task1.name.localizedCaseInsensitiveCompare(task2.name)
            return order == .ascending ? comparison : invertComparison(comparison)
            
        case .dateAdded(let order):
            let comparison = task1.dateAdded.compare(task2.dateAdded)
            return order == .ascending ? comparison : invertComparison(comparison)
            
        case .dateCompleted(let order):
            let date1 = task1.dateCompleted ?? Date.distantPast
            let date2 = task2.dateCompleted ?? Date.distantPast
            let comparison = date1.compare(date2)
            return order == .ascending ? comparison : invertComparison(comparison)
            
        case .project(let order):
            let project1 = task1.project ?? ""
            let project2 = task2.project ?? ""
            let comparison = project1.localizedCaseInsensitiveCompare(project2)
            return order == .ascending ? comparison : invertComparison(comparison)
            
        case .category(let order):
            let comparison = task1.category.rawValue.localizedCompare(task2.category.rawValue)
            return order == .ascending ? comparison : invertComparison(comparison)
            
        case .energy(let order):
            let comparison = task1.energy.rawValue.localizedCompare(task2.energy.rawValue)
            return order == .ascending ? comparison : invertComparison(comparison)
            
        case .estimatedDuration(let order):
            let duration1 = task1.estimatedDuration ?? 0
            let duration2 = task2.estimatedDuration ?? 0
            let comparison = duration1 < duration2 ? ComparisonResult.orderedAscending : 
                           duration1 > duration2 ? ComparisonResult.orderedDescending : ComparisonResult.orderedSame
            return order == .ascending ? comparison : invertComparison(comparison)
            
        case .complexity(let order):
            let complexity1 = task1.complexityScore ?? 0
            let complexity2 = task2.complexityScore ?? 0
            let comparison = complexity1 < complexity2 ? ComparisonResult.orderedAscending :
                           complexity1 > complexity2 ? ComparisonResult.orderedDescending : ComparisonResult.orderedSame
            return order == .ascending ? comparison : invertComparison(comparison)
        }
    }
    
    private func invertComparison(_ comparison: ComparisonResult) -> ComparisonResult {
        switch comparison {
        case .orderedAscending: return .orderedDescending
        case .orderedDescending: return .orderedAscending
        case .orderedSame: return .orderedSame
        }
    }
    
    private func compareInts(_ int1: Int, _ int2: Int) -> ComparisonResult {
        if int1 < int2 {
            return .orderedAscending
        } else if int1 > int2 {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
    
    private func determineSmartSortCriteria(for context: SortContext) -> SortCriteria {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        switch context {
        case .general:
            // General smart sorting: priority first, then due date
            return SortCriteria(
                primarySort: .priority(.ascending),
                secondarySort: .dueDate(.ascending),
                tertiarySort: .name(.ascending)
            )
            
        case .morning:
            // Morning focus: energy level first (high energy tasks first)
            return SortCriteria(
                primarySort: .energy(.descending),
                secondarySort: .priority(.ascending),
                tertiarySort: .estimatedDuration(.ascending)
            )
            
        case .evening:
            // Evening focus: quick wins first (low duration, high priority)
            return SortCriteria(
                primarySort: .estimatedDuration(.ascending),
                secondarySort: .priority(.ascending),
                tertiarySort: .energy(.ascending)
            )
            
        case .urgent:
            // Urgent mode: overdue first, then by priority
            return SortCriteria(
                primarySort: .dueDate(.ascending),
                secondarySort: .priority(.ascending),
                tertiarySort: .estimatedDuration(.ascending)
            )
            
        case .planning:
            // Planning mode: project-based organization
            return SortCriteria(
                primarySort: .project(.ascending),
                secondarySort: .category(.ascending),
                tertiarySort: .priority(.ascending)
            )
        }
    }
    
    private func groupTasks(_ tasks: [Task], by criteria: GroupingCriteria, sortedBy sortField: SortField) -> [TaskGroup] {
        var groups: [String: [Task]] = [:]
        
        // Group tasks
        for task in tasks {
            let key: String
            switch criteria {
            case .project:
                key = task.project ?? "No Project"
            case .category:
                key = task.category.displayName
            case .priority:
                key = task.priority.displayName
            case .context:
                key = task.context.displayName
            case .energy:
                key = task.energy.displayName
            case .dueDate:
                if let dueDate = task.dueDate {
                    if Calendar.current.isDateInToday(dueDate) {
                        key = "Today"
                    } else if Calendar.current.isDateInTomorrow(dueDate) {
                        key = "Tomorrow"
                    } else if dueDate < Date() {
                        key = "Overdue"
                    } else {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        key = formatter.string(from: dueDate)
                    }
                } else {
                    key = "No Due Date"
                }
            case .completion:
                key = task.isComplete ? "Completed" : "Incomplete"
            }
            
            if groups[key] == nil {
                groups[key] = []
            }
            groups[key]?.append(task)
        }
        
        // Sort within each group and create TaskGroup objects
        return groups.map { (groupName, groupTasks) in
            let sortedTasks = groupTasks.sorted { task1, task2 in
                compareTasksBy(task1, task2, field: sortField) == .orderedAscending
            }
            return TaskGroup(name: groupName, tasks: sortedTasks)
        }.sorted { $0.name < $1.name }
    }
}

// MARK: - Supporting Models

public struct SortCriteria {
    public let primarySort: SortField
    public let secondarySort: SortField?
    public let tertiarySort: SortField?
    
    public init(
        primarySort: SortField,
        secondarySort: SortField? = nil,
        tertiarySort: SortField? = nil
    ) {
        self.primarySort = primarySort
        self.secondarySort = secondarySort
        self.tertiarySort = tertiarySort
    }
}

public enum SortField {
    case priority(SortOrder)
    case dueDate(SortOrder)
    case name(SortOrder)
    case dateAdded(SortOrder)
    case dateCompleted(SortOrder)
    case project(SortOrder)
    case category(SortOrder)
    case energy(SortOrder)
    case estimatedDuration(SortOrder)
    case complexity(SortOrder)
}

public enum SortOrder {
    case ascending
    case descending
}

public enum SortContext {
    case general
    case morning
    case evening
    case urgent
    case planning
}

public enum GroupingCriteria {
    case project
    case category
    case priority
    case context
    case energy
    case dueDate
    case completion
}

public struct SortedTasksResult {
    public let tasks: [Task]
    public let criteria: SortCriteria
    public let sortTime: Date
}

public struct TaskGroup {
    public let name: String
    public let tasks: [Task]
    
    public var count: Int { tasks.count }
    public var completedCount: Int { tasks.filter { $0.isComplete }.count }
    public var incompleteCount: Int { tasks.filter { !$0.isComplete }.count }
}

public struct GroupedTasksResult {
    public let groups: [TaskGroup]
    public let groupingCriteria: GroupingCriteria
    public let sortCriteria: SortField
    
    public var totalTasks: Int { groups.reduce(0) { $0 + $1.count } }
    public var totalGroups: Int { groups.count }
}

// MARK: - Error Types

public enum SortError: LocalizedError {
    case sortingFailed(String)
    case invalidCriteria
    case emptyTaskList
    
    public var errorDescription: String? {
        switch self {
        case .sortingFailed(let message):
            return "Sorting failed: \(message)"
        case .invalidCriteria:
            return "Invalid sorting criteria specified"
        case .emptyTaskList:
            return "Cannot sort an empty task list"
        }
    }
}