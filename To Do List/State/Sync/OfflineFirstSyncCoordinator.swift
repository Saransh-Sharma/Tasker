//
//  OfflineFirstSyncCoordinator.swift
//  Tasker
//
//  Coordinates offline-first data synchronization
//

import Foundation

/// Coordinates offline-first synchronization between local and remote data sources
final class OfflineFirstSyncCoordinator {
    
    // MARK: - Properties
    
    private let localDataSource: LocalDataSourceProtocol
    private let remoteDataSource: RemoteDataSourceProtocol
    private let cacheService: CacheServiceProtocol
    private let conflictStrategy: ConflictResolutionStrategy
    
    private var syncTimer: Timer?
    private var isSyncing = false
    private let syncQueue = DispatchQueue(label: "com.tasker.sync", qos: .background)
    
    // MARK: - Initialization
    
    init(
        localDataSource: LocalDataSourceProtocol,
        remoteDataSource: RemoteDataSourceProtocol,
        cacheService: CacheServiceProtocol,
        conflictStrategy: ConflictResolutionStrategy = .keepNewest
    ) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
        self.cacheService = cacheService
        self.conflictStrategy = conflictStrategy
        
        setupAutoSync()
        observeNetworkChanges()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Perform manual sync
    func syncNow(completion: @escaping (Result<SyncResult, Error>) -> Void) {
        guard !isSyncing else {
            let error = NSError(domain: "SyncCoordinator", code: 1001,
                              userInfo: [NSLocalizedDescriptionKey: "Sync already in progress"])
            completion(.failure(error))
            return
        }
        
        guard remoteDataSource.isAvailable else {
            let error = NSError(domain: "SyncCoordinator", code: 1002,
                              userInfo: [NSLocalizedDescriptionKey: "Remote data source not available"])
            completion(.failure(error))
            return
        }
        
        performSync(completion: completion)
    }
    
    /// Enable or disable auto-sync
    func setAutoSyncEnabled(_ enabled: Bool) {
        if enabled {
            setupAutoSync()
        } else {
            syncTimer?.invalidate()
            syncTimer = nil
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAutoSync() {
        // Sync every 5 minutes
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performSync { _ in
                // Silent sync, no need to handle result
            }
        }
    }
    
    private func observeNetworkChanges() {
        // Listen for network availability changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: NSNotification.Name("NetworkStatusChanged"),
            object: nil
        )
    }
    
    @objc private func networkStatusChanged() {
        if remoteDataSource.isAvailable && !isSyncing {
            // Network became available, trigger sync
            performSync { _ in }
        }
    }
    
    private func performSync(completion: @escaping (Result<SyncResult, Error>) -> Void) {
        isSyncing = true
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Step 1: Get last sync timestamp
                let lastSync = self.localDataSource.getLastSyncTimestamp()
                
                // Step 2: Fetch remote changes
                let dispatchGroup = DispatchGroup()
                var remoteTasks: [Task] = []
                var remoteProjects: [Project] = []
                var fetchError: Error?
                
                dispatchGroup.enter()
                self.remoteDataSource.fetchTasks(since: lastSync) { result in
                    switch result {
                    case .success(let tasks):
                        remoteTasks = tasks
                    case .failure(let error):
                        fetchError = error
                    }
                    dispatchGroup.leave()
                }
                
                dispatchGroup.enter()
                self.remoteDataSource.fetchProjects(since: lastSync) { result in
                    switch result {
                    case .success(let projects):
                        remoteProjects = projects
                    case .failure(let error):
                        fetchError = error
                    }
                    dispatchGroup.leave()
                }
                
                dispatchGroup.wait()
                
                if let error = fetchError {
                    throw error
                }
                
                // Step 3: Get local data
                let localTasks = try self.localDataSource.loadTasks()
                let localProjects = try self.localDataSource.loadProjects()
                
                // Step 4: Detect and resolve conflicts
                let taskConflicts = self.detectTaskConflicts(local: localTasks, remote: remoteTasks)
                let projectConflicts = self.detectProjectConflicts(local: localProjects, remote: remoteProjects)
                
                let allConflicts = taskConflicts + projectConflicts
                var resolutions: [SyncResolution] = []
                
                if !allConflicts.isEmpty {
                    dispatchGroup.enter()
                    self.remoteDataSource.resolveConflicts(allConflicts, strategy: self.conflictStrategy) { result in
                        switch result {
                        case .success(let resolved):
                            resolutions = resolved
                        case .failure(let error):
                            fetchError = error
                        }
                        dispatchGroup.leave()
                    }
                    
                    dispatchGroup.wait()
                    
                    if let error = fetchError {
                        throw error
                    }
                }
                
                // Step 5: Merge changes
                let mergedTasks = self.mergeTasks(local: localTasks, remote: remoteTasks, resolutions: resolutions)
                let mergedProjects = self.mergeProjects(local: localProjects, remote: remoteProjects, resolutions: resolutions)
                
                // Step 6: Save merged data locally
                try self.localDataSource.beginTransaction()
                try self.localDataSource.saveTasks(mergedTasks)
                try self.localDataSource.saveProjects(mergedProjects)
                try self.localDataSource.setLastSyncTimestamp(Date())
                try self.localDataSource.commitTransaction()
                
                // Step 7: Push local changes to remote
                dispatchGroup.enter()
                self.remoteDataSource.pushTasks(mergedTasks) { _ in
                    dispatchGroup.leave()
                }
                
                dispatchGroup.enter()
                self.remoteDataSource.pushProjects(mergedProjects) { _ in
                    dispatchGroup.leave()
                }
                
                dispatchGroup.wait()
                
                // Step 8: Clear cache to force refresh
                self.cacheService.clearAll()
                
                // Create sync result
                let syncResult = SyncResult(
                    tasksAdded: max(0, mergedTasks.count - localTasks.count),
                    tasksUpdated: taskConflicts.count,
                    tasksDeleted: max(0, localTasks.count - mergedTasks.count),
                    projectsAdded: max(0, mergedProjects.count - localProjects.count),
                    projectsUpdated: projectConflicts.count,
                    projectsDeleted: max(0, localProjects.count - mergedProjects.count),
                    conflicts: allConflicts,
                    syncDate: Date()
                )
                
                DispatchQueue.main.async {
                    self.isSyncing = false
                    completion(.success(syncResult))
                    
                    // Post notification that sync completed
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SyncCompleted"),
                        object: syncResult
                    )
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Conflict Detection
    
    private func detectTaskConflicts(local: [Task], remote: [Task]) -> [SyncConflict] {
        var conflicts: [SyncConflict] = []
        
        for localTask in local {
            if let remoteTask = remote.first(where: { $0.id == localTask.id }) {
                // Check if both were modified
                if localTask.dateAdded != remoteTask.dateAdded {
                    let conflict = SyncConflict(
                        type: .task(local: localTask, remote: remoteTask),
                        localModifiedDate: localTask.dateAdded,
                        remoteModifiedDate: remoteTask.dateAdded
                    )
                    conflicts.append(conflict)
                }
            }
        }
        
        return conflicts
    }
    
    private func detectProjectConflicts(local: [Project], remote: [Project]) -> [SyncConflict] {
        var conflicts: [SyncConflict] = []
        
        for localProject in local {
            if let remoteProject = remote.first(where: { $0.id == localProject.id }) {
                // Check if both were modified
                if localProject.modifiedDate != remoteProject.modifiedDate {
                    let conflict = SyncConflict(
                        type: .project(local: localProject, remote: remoteProject),
                        localModifiedDate: localProject.modifiedDate,
                        remoteModifiedDate: remoteProject.modifiedDate
                    )
                    conflicts.append(conflict)
                }
            }
        }
        
        return conflicts
    }
    
    // MARK: - Merging
    
    private func mergeTasks(local: [Task], remote: [Task], resolutions: [SyncResolution]) -> [Task] {
        var merged = local
        
        // Add remote tasks that don't exist locally
        for remoteTask in remote {
            if !merged.contains(where: { $0.id == remoteTask.id }) {
                merged.append(remoteTask)
            }
        }
        
        // Apply conflict resolutions
        for resolution in resolutions {
            // Find the conflict and apply resolution
            // This is simplified - in production, you'd match the resolution to specific conflicts
        }
        
        return merged
    }
    
    private func mergeProjects(local: [Project], remote: [Project], resolutions: [SyncResolution]) -> [Project] {
        var merged = local
        
        // Add remote projects that don't exist locally
        for remoteProject in remote {
            if !merged.contains(where: { $0.id == remoteProject.id }) {
                merged.append(remoteProject)
            }
        }
        
        // Apply conflict resolutions
        for resolution in resolutions {
            // Find the conflict and apply resolution
            // This is simplified - in production, you'd match the resolution to specific conflicts
        }
        
        return merged
    }
}
