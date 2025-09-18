//
//  EnhancedDependencyContainer.swift
//  Tasker
//
//  Enhanced dependency injection container for Clean Architecture
//

import Foundation
import CoreData
import UIKit

/// Enhanced dependency container supporting Clean Architecture
final class EnhancedDependencyContainer {
    
    // MARK: - Singleton
    
    static let shared = EnhancedDependencyContainer()
    
    // MARK: - Core Dependencies
    
    private(set) var persistentContainer: NSPersistentContainer!
    
    // MARK: - Repositories (State Management Layer)
    
    private(set) var taskRepository: TaskRepositoryProtocol!
    private(set) var projectRepository: ProjectRepositoryProtocol!
    
    // MARK: - Data Sources
    
    private(set) var localDataSource: LocalDataSourceProtocol!
    private(set) var remoteDataSource: RemoteDataSourceProtocol!
    
    // MARK: - Services
    
    private(set) var cacheService: CacheServiceProtocol!
    private(set) var syncService: SyncServiceProtocol!
    private(set) var syncCoordinator: OfflineFirstSyncCoordinator!
    
    // MARK: - Legacy Support
    
    private(set) var legacyTaskRepository: TaskRepository!
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure the container with Core Data
    func configure(with container: NSPersistentContainer) {
        print("🔧 EnhancedDependencyContainer: Starting configuration...")
        
        self.persistentContainer = container
        
        // Initialize cache service
        self.cacheService = InMemoryCacheService()
        
        // Initialize data sources (placeholder implementations for now)
        self.localDataSource = CoreDataLocalDataSource(container: container)
        self.remoteDataSource = CloudKitRemoteDataSource(container: container)
        
        // Initialize repositories
        let coreDataTaskRepo = CoreDataTaskRepository(container: container)
        self.legacyTaskRepository = coreDataTaskRepo
        self.taskRepository = coreDataTaskRepo // CoreDataTaskRepository now conforms to TaskRepositoryProtocol
        self.projectRepository = CoreDataProjectRepository(container: container)
        
        // Initialize sync service (placeholder for now)
        self.syncService = CloudKitSyncService(
            localDataSource: localDataSource,
            remoteDataSource: remoteDataSource
        )
        
        // Initialize sync coordinator
        self.syncCoordinator = OfflineFirstSyncCoordinator(
            localDataSource: localDataSource,
            remoteDataSource: remoteDataSource,
            cacheService: cacheService
        )
        
        print("✅ EnhancedDependencyContainer: Configuration completed")
    }
    
    // MARK: - Dependency Injection
    
    /// Inject dependencies into a view controller
    func inject(into viewController: UIViewController) {
        let vcType = String(describing: type(of: viewController))
        print("💉 EnhancedDependencyContainer: Injecting into \(vcType)")
        
        // Legacy injection for TaskRepository
        if let dependentVC = viewController as? TaskRepositoryDependent {
            dependentVC.taskRepository = legacyTaskRepository
            print("✅ Injected legacy TaskRepository")
        }
        
        // Clean Architecture injection
        if let cleanVC = viewController as? CleanArchitectureDependent {
            cleanVC.taskRepository = taskRepository
            cleanVC.projectRepository = projectRepository
            cleanVC.cacheService = cacheService
            print("✅ Injected Clean Architecture dependencies")
        }
        
        // Inject into child view controllers
        for child in viewController.children {
            inject(into: child)
        }
    }
    
    // MARK: - Factory Methods
    
    /// Create a task repository with caching
    func makeCachedTaskRepository() -> TaskRepositoryProtocol {
        return CachedTaskRepository(
            repository: taskRepository,
            cache: cacheService
        )
    }
    
    /// Create a project repository with caching
    func makeCachedProjectRepository() -> ProjectRepositoryProtocol {
        return CachedProjectRepository(
            repository: projectRepository,
            cache: cacheService
        )
    }
}

// MARK: - Protocols

/// Protocol for view controllers using Clean Architecture dependencies
protocol CleanArchitectureDependent: AnyObject {
    var taskRepository: TaskRepositoryProtocol! { get set }
    var projectRepository: ProjectRepositoryProtocol! { get set }
    var cacheService: CacheServiceProtocol! { get set }
}

// MARK: - Placeholder Implementations

/// Placeholder Core Data local data source
private class CoreDataLocalDataSource: LocalDataSourceProtocol {
    private let container: NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.container = container
    }
    
    func saveTasks(_ tasks: [Task]) throws {
        // Implementation will use TaskMapper
    }
    
    func loadTasks() throws -> [Task] {
        // Implementation will use TaskMapper
        return []
    }
    
    func deleteTasks(withIds ids: [UUID]) throws {
        // Implementation will use TaskMapper
    }
    
    func clearAllTasks() throws {
        // Implementation
    }
    
    func saveProjects(_ projects: [Project]) throws {
        // Implementation will use ProjectMapper
    }
    
    func loadProjects() throws -> [Project] {
        // Implementation will use ProjectMapper
        return []
    }
    
    func deleteProjects(withIds ids: [UUID]) throws {
        // Implementation will use ProjectMapper
    }
    
    func clearAllProjects() throws {
        // Implementation
    }
    
    func beginTransaction() throws {
        // Core Data doesn't need explicit transactions
    }
    
    func commitTransaction() throws {
        try container.viewContext.save()
    }
    
    func rollbackTransaction() throws {
        container.viewContext.rollback()
    }
    
    func getLastSyncTimestamp() -> Date? {
        // Implementation would use UserDefaults or Core Data
        return UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date
    }
    
    func setLastSyncTimestamp(_ date: Date) throws {
        UserDefaults.standard.set(date, forKey: "lastSyncTimestamp")
    }
    
    func getStorageSize() -> Int {
        // Implementation would calculate Core Data store size
        return 0
    }
    
    func isAvailable() -> Bool {
        return true
    }
}

/// Placeholder CloudKit remote data source
private class CloudKitRemoteDataSource: RemoteDataSourceProtocol {
    private let container: NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.container = container
    }
    
    var isAvailable: Bool { return true }
    var isSyncing: Bool { return false }
    var syncStatus: SyncStatus { return .idle }
    
    func fetchTasks(since date: Date?, completion: @escaping (Result<[Task], Error>) -> Void) {
        // CloudKit implementation
        completion(.success([]))
    }
    
    func pushTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        // CloudKit implementation
        completion(.success(tasks))
    }
    
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        // CloudKit implementation
        completion(.success(()))
    }
    
    func fetchProjects(since date: Date?, completion: @escaping (Result<[Project], Error>) -> Void) {
        // CloudKit implementation
        completion(.success([]))
    }
    
    func pushProjects(_ projects: [Project], completion: @escaping (Result<[Project], Error>) -> Void) {
        // CloudKit implementation
        completion(.success(projects))
    }
    
    func deleteProjects(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        // CloudKit implementation
        completion(.success(()))
    }
    
    func performFullSync(completion: @escaping (Result<SyncResult, Error>) -> Void) {
        // CloudKit implementation
        completion(.success(SyncResult()))
    }
    
    func performIncrementalSync(since date: Date, completion: @escaping (Result<SyncResult, Error>) -> Void) {
        // CloudKit implementation
        completion(.success(SyncResult()))
    }
    
    func cancelSync() {
        // CloudKit implementation
    }
    
    func resolveConflicts(_ conflicts: [SyncConflict], strategy: ConflictResolutionStrategy, completion: @escaping (Result<[SyncResolution], Error>) -> Void) {
        // CloudKit implementation
        completion(.success([]))
    }
    
    func subscribeToChanges(handler: @escaping (RemoteChange) -> Void) -> SubscriptionToken {
        // CloudKit implementation
        return SubscriptionToken()
    }
    
    func unsubscribe(token: SubscriptionToken) {
        // CloudKit implementation
    }
}

/// Placeholder CloudKit sync service
private class CloudKitSyncService: SyncServiceProtocol {
    private let localDataSource: LocalDataSourceProtocol
    private let remoteDataSource: RemoteDataSourceProtocol
    
    init(localDataSource: LocalDataSourceProtocol, remoteDataSource: RemoteDataSourceProtocol) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }
    
    var isSyncEnabled: Bool { return true }
    var isSyncing: Bool { return false }
    var lastSyncDate: Date? { return localDataSource.getLastSyncTimestamp() }
    
    func startSync(completion: @escaping (Result<Void, Error>) -> Void) {
        remoteDataSource.performFullSync { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func stopSync() {
        remoteDataSource.cancelSync()
    }
    
    func syncTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        remoteDataSource.pushTasks(tasks, completion: completion)
    }
    
    func syncProjects(_ projects: [Project], completion: @escaping (Result<[Project], Error>) -> Void) {
        remoteDataSource.pushProjects(projects, completion: completion)
    }
    
    func resolveConflicts(for tasks: [Task], strategy: ConflictResolutionStrategy, completion: @escaping (Result<[Task], Error>) -> Void) {
        // Implementation
        completion(.success(tasks))
    }
    
    func setSyncEnabled(_ enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        // Implementation
        completion(.success(()))
    }
    
    func setSyncFrequency(_ frequency: SyncFrequency) {
        // Implementation
    }
}

// MARK: - Cached Repository Wrappers

/// Task repository with caching
private class CachedTaskRepository: TaskRepositoryProtocol {
    private let repository: TaskRepositoryProtocol
    private let cache: CacheServiceProtocol
    
    init(repository: TaskRepositoryProtocol, cache: CacheServiceProtocol) {
        self.repository = repository
        self.cache = cache
    }
    
    // Implement all TaskRepositoryProtocol methods with caching
    // This is a simplified example - full implementation would cache appropriately
    
    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        if let cached = cache.get([Task].self, forKey: "all_tasks") {
            completion(.success(cached))
            return
        }
        
        repository.fetchAllTasks { [weak self] result in
            if case .success(let tasks) = result {
                self?.cache.set(tasks, forKey: "all_tasks", expiration: .minutes(5))
            }
            completion(result)
        }
    }
    
    // ... implement other methods similarly
    
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchTasks(for: date, completion: completion)
    }
    
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchTodayTasks(completion: completion)
    }
    
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchTasks(for: project, completion: completion)
    }
    
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchOverdueTasks(completion: completion)
    }
    
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchUpcomingTasks(completion: completion)
    }
    
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchCompletedTasks(completion: completion)
    }
    
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchTasks(ofType: type, completion: completion)
    }
    
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) {
        repository.fetchTask(withId: id, completion: completion)
    }
    
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.createTask(task, completion: completion)
    }
    
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.updateTask(task, completion: completion)
    }
    
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.completeTask(withId: id, completion: completion)
    }
    
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.uncompleteTask(withId: id, completion: completion)
    }
    
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.rescheduleTask(withId: id, to: date, completion: completion)
    }
    
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.deleteTask(withId: id, completion: completion)
    }
    
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.deleteCompletedTasks(completion: completion)
    }
    
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.createTasks(tasks, completion: completion)
    }
    
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.updateTasks(tasks, completion: completion)
    }
    
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.deleteTasks(withIds: ids, completion: completion)
    }
}

/// Project repository with caching
private class CachedProjectRepository: ProjectRepositoryProtocol {
    private let repository: ProjectRepositoryProtocol
    private let cache: CacheServiceProtocol
    
    init(repository: ProjectRepositoryProtocol, cache: CacheServiceProtocol) {
        self.repository = repository
        self.cache = cache
    }
    
    // Implement all ProjectRepositoryProtocol methods with caching
    // This is a simplified example
    
    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        if let cached = cache.getCachedProjects() {
            completion(.success(cached))
            return
        }
        
        repository.fetchAllProjects { [weak self] result in
            if case .success(let projects) = result {
                self?.cache.cacheProjects(projects)
            }
            completion(result)
        }
    }
    
    // ... implement other methods similarly
    
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        repository.fetchProject(withId: id, completion: completion)
    }
    
    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        repository.fetchProject(withName: name, completion: completion)
    }
    
    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        repository.fetchInboxProject(completion: completion)
    }
    
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        repository.fetchCustomProjects(completion: completion)
    }
    
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        cache.clearAll()
        repository.createProject(project, completion: completion)
    }
    
    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        repository.ensureInboxProject(completion: completion)
    }
    
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        cache.clearAll()
        repository.updateProject(project, completion: completion)
    }
    
    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        cache.clearAll()
        repository.renameProject(withId: id, to: newName, completion: completion)
    }
    
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        cache.clearAll()
        repository.deleteProject(withId: id, deleteTasks: deleteTasks, completion: completion)
    }
    
    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        repository.getTaskCount(for: projectId, completion: completion)
    }
    
    func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.getTasks(for: projectId, completion: completion)
    }
    
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        cache.clearAll()
        repository.moveTasks(from: sourceProjectId, to: targetProjectId, completion: completion)
    }
    
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        repository.isProjectNameAvailable(name, excludingId: excludingId, completion: completion)
    }
}
