//
//  SyncServiceProtocol.swift
//  Tasker
//
//  Protocol defining the interface for data synchronization operations
//

import Foundation

/// Protocol defining synchronization operations for CloudKit or other sync services
public protocol SyncServiceProtocol {
    
    // MARK: - Sync Status
    
    /// Check if sync is enabled
    var isSyncEnabled: Bool { get }
    
    /// Check if currently syncing
    var isSyncing: Bool { get }
    
    /// Get the last sync date
    var lastSyncDate: Date? { get }
    
    // MARK: - Sync Operations
    
    /// Start a full sync
    func startSync(completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Stop ongoing sync
    func stopSync()
    
    /// Sync specific tasks
    func syncTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Sync specific projects
    func syncProjects(_ projects: [Project], completion: @escaping (Result<[Project], Error>) -> Void)
    
    // MARK: - Conflict Resolution
    
    /// Resolve sync conflicts
    func resolveConflicts(for tasks: [Task], strategy: ConflictResolutionStrategy, completion: @escaping (Result<[Task], Error>) -> Void)
    
    // MARK: - Configuration
    
    /// Enable or disable sync
    func setSyncEnabled(_ enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Configure sync frequency
    func setSyncFrequency(_ frequency: SyncFrequency)
}

// MARK: - Supporting Types

/// Strategy for resolving sync conflicts
public enum ConflictResolutionStrategy {
    case keepLocal
    case keepRemote
    case keepNewest
    case merge
}

/// Frequency of automatic sync
public enum SyncFrequency {
    case manual
    case immediate
    case every5Minutes
    case every15Minutes
    case hourly
    case daily
}
