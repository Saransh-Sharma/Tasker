//
//  ArchiveCompletedTasksUseCase.swift
//  Tasker
//
//  Use case for comprehensive task lifecycle management and archival
//

import Foundation

/// Use case for managing task lifecycle and archival process
/// Provides intelligent archival strategies for completed tasks
public final class ArchiveCompletedTasksUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let eventPublisher: DomainEventPublisher?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        eventPublisher: DomainEventPublisher? = nil
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.eventPublisher = eventPublisher
    }
    
    // MARK: - Archive Methods
    
    /// Archive all completed tasks older than specified days
    public func archiveCompletedTasks(
        olderThanDays days: Int = 30,
        completion: @escaping (Result<ArchiveResult, ArchiveError>) -> Void
    ) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        taskRepository.fetchCompletedTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                let tasksToArchive = tasks.filter { task in
                    guard let completionDate = task.dateCompleted else { return false }
                    return completionDate < cutoffDate
                }
                
                self?.performArchival(tasks: tasksToArchive, strategy: .moveToArchiveProject, completion: completion)
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Archive completed tasks for a specific project
    public func archiveProjectCompletedTasks(
        projectName: String,
        strategy: ArchivalStrategy = .moveToArchiveProject,
        completion: @escaping (Result<ArchiveResult, ArchiveError>) -> Void
    ) {
        taskRepository.fetchTasks(for: projectName) { [weak self] result in
            switch result {
            case .success(let tasks):
                let completedTasks = tasks.filter { $0.isComplete }
                self?.performArchival(tasks: completedTasks, strategy: strategy, completion: completion)
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Smart archive - Archives tasks based on intelligent criteria
    public func smartArchive(
        completion: @escaping (Result<SmartArchiveResult, ArchiveError>) -> Void
    ) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                self?.performSmartArchival(allTasks: tasks, completion: completion)
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Archive tasks by priority (cleanup low priority completed tasks)
    public func archiveByPriority(
        priorities: [TaskPriority],
        olderThanDays days: Int = 7,
        completion: @escaping (Result<ArchiveResult, ArchiveError>) -> Void
    ) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        taskRepository.fetchCompletedTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                let tasksToArchive = tasks.filter { task in
                    priorities.contains(task.priority) &&
                    (task.dateCompleted ?? Date()) < cutoffDate
                }
                
                self?.performArchival(tasks: tasksToArchive, strategy: .moveToArchiveProject, completion: completion)
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Restore archived tasks back to their original projects
    public func restoreArchivedTasks(
        taskIds: [UUID],
        targetProject: String? = nil,
        completion: @escaping (Result<RestoreResult, ArchiveError>) -> Void
    ) {
        var restoredCount = 0
        var failedIds: [UUID] = []
        let dispatchGroup = DispatchGroup()
        
        for taskId in taskIds {
            dispatchGroup.enter()
            
            taskRepository.fetchTask(withId: taskId) { [weak self] fetchResult in
                switch fetchResult {
                case .success(let task):
                    guard let originalTask = task else {
                        failedIds.append(taskId)
                        dispatchGroup.leave()
                        return
                    }
                    
                    var restoredTask = originalTask
                    restoredTask.project = targetProject ?? "Inbox" // Default restoration target
                    
                    self?.taskRepository.updateTask(restoredTask) { updateResult in
                        switch updateResult {
                        case .success:
                            restoredCount += 1
                            self?.eventPublisher?.publish(TaskRestored(task: restoredTask))
                        case .failure:
                            failedIds.append(taskId)
                        }
                        dispatchGroup.leave()
                    }
                    
                case .failure:
                    failedIds.append(taskId)
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let result = RestoreResult(
                totalRequested: taskIds.count,
                restoredCount: restoredCount,
                failedIds: failedIds
            )
            completion(.success(result))
        }
    }
    
    /// Clean up archived tasks permanently
    public func permanentlyDeleteArchived(
        olderThanDays days: Int = 90,
        requireConfirmation: Bool = true,
        completion: @escaping (Result<DeletionResult, ArchiveError>) -> Void
    ) {
        guard !requireConfirmation else {
            completion(.failure(.confirmationRequired))
            return
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        taskRepository.fetchTasks(for: "Archived") { [weak self] result in
            switch result {
            case .success(let archivedTasks):
                let tasksToDelete = archivedTasks.filter { task in
                    (task.dateCompleted ?? Date()) < cutoffDate
                }
                
                let taskIds = tasksToDelete.map { $0.id }
                self?.taskRepository.deleteTasks(withIds: taskIds) { deleteResult in
                    switch deleteResult {
                    case .success:
                        let result = DeletionResult(
                            deletedCount: taskIds.count,
                            freedSpace: self?.calculateFreedSpace(tasks: tasksToDelete) ?? 0
                        )
                        completion(.success(result))
                        
                    case .failure(let error):
                        completion(.failure(.repositoryError(error)))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func performArchival(
        tasks: [Task],
        strategy: ArchivalStrategy,
        completion: @escaping (Result<ArchiveResult, ArchiveError>) -> Void
    ) {
        guard !tasks.isEmpty else {
            completion(.success(ArchiveResult(
                archivedCount: 0,
                strategy: strategy,
                freedActiveSpace: 0
            )))
            return
        }
        
        var archivedCount = 0
        let dispatchGroup = DispatchGroup()
        
        for task in tasks {
            dispatchGroup.enter()
            
            switch strategy {
            case .moveToArchiveProject:
                var archivedTask = task
                archivedTask.project = "Archived"
                
                taskRepository.updateTask(archivedTask) { result in
                    if case .success = result {
                        archivedCount += 1
                    }
                    dispatchGroup.leave()
                }
                
            case .markAsArchived:
                var archivedTask = task
                archivedTask.tags.append("archived")
                
                taskRepository.updateTask(archivedTask) { result in
                    if case .success = result {
                        archivedCount += 1
                    }
                    dispatchGroup.leave()
                }
                
            case .delete:
                taskRepository.deleteTask(withId: task.id) { result in
                    if case .success = result {
                        archivedCount += 1
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let result = ArchiveResult(
                archivedCount: archivedCount,
                strategy: strategy,
                freedActiveSpace: self.calculateFreedSpace(tasks: Array(tasks.prefix(archivedCount)))
            )
            
            // Publish events
            for task in tasks.prefix(archivedCount) {
                self.eventPublisher?.publish(TaskArchived(task: task, strategy: strategy))
            }
            
            completion(.success(result))
        }
    }
    
    private func performSmartArchival(
        allTasks: [Task],
        completion: @escaping (Result<SmartArchiveResult, ArchiveError>) -> Void
    ) {
        let completedTasks = allTasks.filter { $0.isComplete }
        let now = Date()
        
        // Smart archival criteria
        var lowPriorityOld: [Task] = []
        var mediumPriorityOld: [Task] = []
        var highPriorityOld: [Task] = []
        var duplicateTasks: [Task] = []
        
        for task in completedTasks {
            guard let completionDate = task.dateCompleted else { continue }
            
            let daysSinceCompletion = Calendar.current.dateComponents([.day], from: completionDate, to: now).day ?? 0
            
            switch task.priority {
            case .none, .low:
                if daysSinceCompletion > 7 {
                    lowPriorityOld.append(task)
                }
            case .high:
                if daysSinceCompletion > 30 {
                    mediumPriorityOld.append(task)
                }
            case .max:
                if daysSinceCompletion > 60 {
                    highPriorityOld.append(task)
                }
            }
        }
        
        // Find duplicate completed tasks
        let tasksByName = Dictionary(grouping: completedTasks, by: { $0.name.lowercased() })
        for (_, tasks) in tasksByName where tasks.count > 1 {
            // Keep the most recent, archive the rest
            let sorted = tasks.sorted { ($0.dateCompleted ?? Date()) > ($1.dateCompleted ?? Date()) }
            duplicateTasks.append(contentsOf: Array(sorted.dropFirst()))
        }
        
        let totalToArchive = lowPriorityOld + mediumPriorityOld + highPriorityOld + duplicateTasks
        
        performArchival(tasks: totalToArchive, strategy: .moveToArchiveProject) { result in
            switch result {
            case .success(let archiveResult):
                let smartResult = SmartArchiveResult(
                    lowPriorityArchived: lowPriorityOld.count,
                    mediumPriorityArchived: mediumPriorityOld.count,
                    highPriorityArchived: highPriorityOld.count,
                    duplicatesArchived: duplicateTasks.count,
                    totalArchived: archiveResult.archivedCount,
                    freedSpace: archiveResult.freedActiveSpace
                )
                completion(.success(smartResult))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func calculateFreedSpace(tasks: [Task]) -> Int {
        // Rough calculation based on task data size
        return tasks.reduce(0) { total, task in
            let nameSize = task.name.utf8.count
            let detailsSize = task.details?.utf8.count ?? 0
            let tagsSize = task.tags.joined().utf8.count
            return total + nameSize + detailsSize + tagsSize + 200 // Base overhead
        }
    }
}

// MARK: - Supporting Models

public enum ArchivalStrategy {
    case moveToArchiveProject
    case markAsArchived
    case delete
    
    public var displayName: String {
        switch self {
        case .moveToArchiveProject: return "Move to Archive Project"
        case .markAsArchived: return "Mark as Archived"
        case .delete: return "Permanently Delete"
        }
    }
}

public struct ArchiveResult {
    public let archivedCount: Int
    public let strategy: ArchivalStrategy
    public let freedActiveSpace: Int
    
    public var successRate: Double { return 1.0 } // For consistency with other results
}

public struct SmartArchiveResult {
    public let lowPriorityArchived: Int
    public let mediumPriorityArchived: Int
    public let highPriorityArchived: Int
    public let duplicatesArchived: Int
    public let totalArchived: Int
    public let freedSpace: Int
    
    public var summary: String {
        var components: [String] = []
        if lowPriorityArchived > 0 { components.append("\(lowPriorityArchived) low priority") }
        if mediumPriorityArchived > 0 { components.append("\(mediumPriorityArchived) medium priority") }
        if highPriorityArchived > 0 { components.append("\(highPriorityArchived) high priority") }
        if duplicatesArchived > 0 { components.append("\(duplicatesArchived) duplicates") }
        
        return "Archived: " + components.joined(separator: ", ")
    }
}

public struct RestoreResult {
    public let totalRequested: Int
    public let restoredCount: Int
    public let failedIds: [UUID]
    
    public var successRate: Double {
        return totalRequested > 0 ? Double(restoredCount) / Double(totalRequested) : 0
    }
}

public struct DeletionResult {
    public let deletedCount: Int
    public let freedSpace: Int
}

// MARK: - Events

public struct TaskArchived: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "TaskArchived"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let task: Task
    public let strategy: ArchivalStrategy
    
    public init(task: Task, strategy: ArchivalStrategy) {
        self.task = task
        self.strategy = strategy
        self.aggregateId = task.id
        self.metadata = [
            "taskId": task.id.uuidString,
            "strategy": "\(strategy)"
        ]
    }
}

public struct TaskRestored: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "TaskRestored"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let task: Task
    
    public init(task: Task) {
        self.task = task
        self.aggregateId = task.id
        self.metadata = ["taskId": task.id.uuidString]
    }
}

// MARK: - Error Types

public enum ArchiveError: LocalizedError {
    case repositoryError(Error)
    case confirmationRequired
    case invalidStrategy
    case noTasksToArchive
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .confirmationRequired:
            return "Confirmation required for permanent deletion"
        case .invalidStrategy:
            return "Invalid archival strategy specified"
        case .noTasksToArchive:
            return "No tasks found matching archival criteria"
        }
    }
}