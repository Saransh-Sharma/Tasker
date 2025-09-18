//
//  RemoteDataSourceProtocol.swift
//  Tasker
//
//  Protocol defining remote data source operations (CloudKit)
//

import Foundation

/// Protocol for remote data synchronization operations
public protocol RemoteDataSourceProtocol {
    
    // MARK: - Connection Status
    
    /// Check if remote service is available
    var isAvailable: Bool { get }
    
    /// Check if currently syncing
    var isSyncing: Bool { get }
    
    /// Get current sync status
    var syncStatus: SyncStatus { get }
    
    // MARK: - Task Operations
    
    /// Fetch tasks from remote source
    func fetchTasks(since date: Date?, completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Push tasks to remote source
    func pushTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Delete tasks from remote source
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
    
    // MARK: - Project Operations
    
    /// Fetch projects from remote source
    func fetchProjects(since date: Date?, completion: @escaping (Result<[Project], Error>) -> Void)
    
    /// Push projects to remote source
    func pushProjects(_ projects: [Project], completion: @escaping (Result<[Project], Error>) -> Void)
    
    /// Delete projects from remote source
    func deleteProjects(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
    
    // MARK: - Sync Operations
    
    /// Perform full sync
    func performFullSync(completion: @escaping (Result<SyncResult, Error>) -> Void)
    
    /// Perform incremental sync
    func performIncrementalSync(since date: Date, completion: @escaping (Result<SyncResult, Error>) -> Void)
    
    /// Cancel ongoing sync
    func cancelSync()
    
    // MARK: - Conflict Resolution
    
    /// Resolve conflicts between local and remote data
    func resolveConflicts(_ conflicts: [SyncConflict], strategy: ConflictResolutionStrategy, completion: @escaping (Result<[SyncResolution], Error>) -> Void)
    
    // MARK: - Change Tracking
    
    /// Subscribe to remote changes
    func subscribeToChanges(handler: @escaping (RemoteChange) -> Void) -> SubscriptionToken
    
    /// Unsubscribe from remote changes
    func unsubscribe(token: SubscriptionToken)
}

// MARK: - Supporting Types

/// Sync status enumeration
public enum SyncStatus {
    case idle
    case syncing(progress: Double)
    case completed(date: Date)
    case failed(error: Error)
}

/// Sync result containing statistics
public struct SyncResult {
    public let tasksAdded: Int
    public let tasksUpdated: Int
    public let tasksDeleted: Int
    public let projectsAdded: Int
    public let projectsUpdated: Int
    public let projectsDeleted: Int
    public let conflicts: [SyncConflict]
    public let syncDate: Date
    
    public init(
        tasksAdded: Int = 0,
        tasksUpdated: Int = 0,
        tasksDeleted: Int = 0,
        projectsAdded: Int = 0,
        projectsUpdated: Int = 0,
        projectsDeleted: Int = 0,
        conflicts: [SyncConflict] = [],
        syncDate: Date = Date()
    ) {
        self.tasksAdded = tasksAdded
        self.tasksUpdated = tasksUpdated
        self.tasksDeleted = tasksDeleted
        self.projectsAdded = projectsAdded
        self.projectsUpdated = projectsUpdated
        self.projectsDeleted = projectsDeleted
        self.conflicts = conflicts
        self.syncDate = syncDate
    }
}

/// Sync conflict representation
public struct SyncConflict {
    public enum ConflictType {
        case task(local: Task, remote: Task)
        case project(local: Project, remote: Project)
    }
    
    public let id: UUID
    public let type: ConflictType
    public let localModifiedDate: Date
    public let remoteModifiedDate: Date
    
    public init(id: UUID = UUID(), type: ConflictType, localModifiedDate: Date, remoteModifiedDate: Date) {
        self.id = id
        self.type = type
        self.localModifiedDate = localModifiedDate
        self.remoteModifiedDate = remoteModifiedDate
    }
}

/// Sync conflict resolution
public struct SyncResolution {
    public let conflictId: UUID
    public let resolution: ConflictResolutionStrategy
    public let resolvedDate: Date
    
    public init(conflictId: UUID, resolution: ConflictResolutionStrategy, resolvedDate: Date = Date()) {
        self.conflictId = conflictId
        self.resolution = resolution
        self.resolvedDate = resolvedDate
    }
}

/// Remote change notification
public enum RemoteChange {
    case taskAdded(Task)
    case taskUpdated(Task)
    case taskDeleted(UUID)
    case projectAdded(Project)
    case projectUpdated(Project)
    case projectDeleted(UUID)
}

/// Subscription token for change notifications
public struct SubscriptionToken {
    public let id: UUID
    
    public init() {
        self.id = UUID()
    }
}
