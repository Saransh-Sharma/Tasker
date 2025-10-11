//
//  LocalDataSourceProtocol.swift
//  Tasker
//
//  Protocol defining local data source operations
//

import Foundation

/// Protocol for local data persistence operations
public protocol LocalDataSourceProtocol {
    
    // MARK: - Task Operations
    
    /// Save tasks to local storage
    func saveTasks(_ tasks: [Task]) throws
    
    /// Load all tasks from local storage
    func loadTasks() throws -> [Task]
    
    /// Delete tasks from local storage
    func deleteTasks(withIds ids: [UUID]) throws
    
    /// Clear all tasks from local storage
    func clearAllTasks() throws
    
    // MARK: - Project Operations
    
    /// Save projects to local storage
    func saveProjects(_ projects: [Project]) throws
    
    /// Load all projects from local storage
    func loadProjects() throws -> [Project]
    
    /// Delete projects from local storage
    func deleteProjects(withIds ids: [UUID]) throws
    
    /// Clear all projects from local storage
    func clearAllProjects() throws
    
    // MARK: - Transaction Support
    
    /// Begin a transaction
    func beginTransaction() throws
    
    /// Commit the current transaction
    func commitTransaction() throws
    
    /// Rollback the current transaction
    func rollbackTransaction() throws
    
    // MARK: - Metadata
    
    /// Get the last sync timestamp
    func getLastSyncTimestamp() -> Date?
    
    /// Set the last sync timestamp
    func setLastSyncTimestamp(_ date: Date) throws
    
    /// Get storage size in bytes
    func getStorageSize() -> Int
    
    /// Check if local storage is available
    func isAvailable() -> Bool
}
