//
//  PresentationDependencyContainer.swift
//  Tasker
//
//  Dependency injection container for presentation layer with ViewModels
//

import Foundation
import CoreData
import UIKit

/// Enhanced dependency container for Clean Architecture with ViewModels
public final class PresentationDependencyContainer {
    
    // MARK: - Singleton
    
    public static let shared = PresentationDependencyContainer()
    
    // MARK: - Core Dependencies
    
    private var persistentContainer: NSPersistentContainer!
    
    // MARK: - Repositories
    
    private var taskRepository: TaskRepositoryProtocol!
    private var projectRepository: ProjectRepositoryProtocol!
    
    // MARK: - Services
    
    private var cacheService: CacheServiceProtocol!
    private var syncCoordinator: OfflineFirstSyncCoordinator!
    
    // MARK: - Use Cases
    
    private var createTaskUseCase: CreateTaskUseCase!
    private var completeTaskUseCase: CompleteTaskUseCase!
    private var deleteTaskUseCase: DeleteTaskUseCase!
    private var updateTaskUseCase: UpdateTaskUseCase!
    private var rescheduleTaskUseCase: RescheduleTaskUseCase!
    private var getTasksUseCase: GetTasksUseCase!
    private var manageProjectsUseCase: ManageProjectsUseCase!
    private var calculateAnalyticsUseCase: CalculateAnalyticsUseCase!
    private var useCaseCoordinator: UseCaseCoordinator!
    
    // MARK: - ViewModels (Lazy initialization)
    
    private var _homeViewModel: HomeViewModel?
    private var _addTaskViewModel: AddTaskViewModel?
    private var _projectManagementViewModel: ProjectManagementViewModel?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure the container with Core Data
    public func configure(with container: NSPersistentContainer) {
        print("🔧 PresentationDependencyContainer: Starting configuration...")
        
        self.persistentContainer = container
        
        // Initialize services
        setupServices()
        
        // Initialize repositories
        setupRepositories()
        
        // Initialize use cases
        setupUseCases()
        
        print("✅ PresentationDependencyContainer: Configuration completed")
    }
    
    // MARK: - Setup Methods
    
    private func setupServices() {
        // Cache service
        self.cacheService = InMemoryCacheService()
        
        // Data sources
        let localDataSource = CoreDataLocalDataSource(container: persistentContainer)
        let remoteDataSource = CloudKitRemoteDataSource(container: persistentContainer)
        
        // Sync coordinator
        self.syncCoordinator = OfflineFirstSyncCoordinator(
            localDataSource: localDataSource,
            remoteDataSource: remoteDataSource,
            cacheService: cacheService
        )
    }
    
    private func setupRepositories() {
        // Task repository with domain protocol conformance
        let coreDataTaskRepo = CoreDataTaskRepository(container: persistentContainer)
        self.taskRepository = coreDataTaskRepo
        
        // Project repository
        self.projectRepository = CoreDataProjectRepository(container: persistentContainer)
    }
    
    private func setupUseCases() {
        // Task use cases
        self.createTaskUseCase = CreateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )
        
        let scoringService = TaskScoringService()
        self.completeTaskUseCase = CompleteTaskUseCase(
            taskRepository: taskRepository,
            scoringService: scoringService,
            analyticsService: nil
        )
        
        self.deleteTaskUseCase = DeleteTaskUseCase(
            taskRepository: taskRepository,
            notificationService: nil,
            analyticsService: nil
        )
        
        self.updateTaskUseCase = UpdateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )
        
        self.rescheduleTaskUseCase = RescheduleTaskUseCase(
            taskRepository: taskRepository,
            notificationService: nil
        )
        
        self.getTasksUseCase = GetTasksUseCase(
            taskRepository: taskRepository,
            cacheService: cacheService
        )
        
        // Project use cases
        self.manageProjectsUseCase = ManageProjectsUseCase(
            projectRepository: projectRepository,
            taskRepository: taskRepository
        )
        
        // Analytics use cases
        self.calculateAnalyticsUseCase = CalculateAnalyticsUseCase(
            taskRepository: taskRepository,
            scoringService: scoringService,
            cacheService: cacheService
        )
        
        // Use case coordinator
        self.useCaseCoordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            cacheService: cacheService,
            syncCoordinator: syncCoordinator,
            notificationService: nil
        )
    }
    
    // MARK: - ViewModel Factory Methods
    
    /// Get or create HomeViewModel
    public func makeHomeViewModel() -> HomeViewModel {
        if let existing = _homeViewModel {
            return existing
        }
        
        let viewModel = HomeViewModel(useCaseCoordinator: useCaseCoordinator)
        _homeViewModel = viewModel
        return viewModel
    }
    
    /// Get or create AddTaskViewModel
    public func makeAddTaskViewModel() -> AddTaskViewModel {
        if let existing = _addTaskViewModel {
            return existing
        }
        
        let viewModel = AddTaskViewModel(
            createTaskUseCase: createTaskUseCase,
            manageProjectsUseCase: manageProjectsUseCase,
            rescheduleTaskUseCase: rescheduleTaskUseCase
        )
        _addTaskViewModel = viewModel
        return viewModel
    }
    
    /// Get or create ProjectManagementViewModel
    public func makeProjectManagementViewModel() -> ProjectManagementViewModel {
        if let existing = _projectManagementViewModel {
            return existing
        }
        
        let viewModel = ProjectManagementViewModel(
            manageProjectsUseCase: manageProjectsUseCase,
            getTasksUseCase: getTasksUseCase
        )
        _projectManagementViewModel = viewModel
        return viewModel
    }
    
    /// Create a fresh AddTaskViewModel (for modal presentations)
    public func makeNewAddTaskViewModel() -> AddTaskViewModel {
        return AddTaskViewModel(
            createTaskUseCase: createTaskUseCase,
            manageProjectsUseCase: manageProjectsUseCase,
            rescheduleTaskUseCase: rescheduleTaskUseCase
        )
    }
    
    // MARK: - View Controller Injection
    
    /// Inject dependencies into a view controller
    public func inject(into viewController: UIViewController) {
        let vcType = String(describing: type(of: viewController))
        print("💉 PresentationDependencyContainer: Injecting into \(vcType)")
        
        // Check for specific view controller types and inject ViewModels
        switch viewController {
        case let homeVC as HomeViewControllerProtocol:
            homeVC.viewModel = makeHomeViewModel()
            print("✅ Injected HomeViewModel")
            
        case let addTaskVC as AddTaskViewControllerProtocol:
            addTaskVC.viewModel = makeNewAddTaskViewModel()
            print("✅ Injected AddTaskViewModel")
            
        case let projectVC as ProjectManagementViewControllerProtocol:
            projectVC.viewModel = makeProjectManagementViewModel()
            print("✅ Injected ProjectManagementViewModel")
            
        default:
            print("ℹ️ No specific injection for \(vcType)")
        }
        
        // Inject into child view controllers
        for child in viewController.children {
            inject(into: child)
        }
    }
    
    // MARK: - Direct Access (for migration)
    
    /// Get the use case coordinator directly (for gradual migration)
    public var coordinator: UseCaseCoordinator {
        return useCaseCoordinator
    }
}

// MARK: - View Controller Protocols

/// Protocol for HomeViewController to receive ViewModel
public protocol HomeViewControllerProtocol: AnyObject {
    var viewModel: HomeViewModel! { get set }
}

/// Protocol for AddTaskViewController to receive ViewModel
public protocol AddTaskViewControllerProtocol: AnyObject {
    var viewModel: AddTaskViewModel! { get set }
}

/// Protocol for ProjectManagementViewController to receive ViewModel
public protocol ProjectManagementViewControllerProtocol: AnyObject {
    var viewModel: ProjectManagementViewModel! { get set }
}

// MARK: - Placeholder Implementations (from Phase 2)

private class CoreDataLocalDataSource: LocalDataSourceProtocol {
    private let container: NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.container = container
    }
    
    func saveTasks(_ tasks: [Task]) throws {
        let context = container.newBackgroundContext()
        context.performAndWait {
            for task in tasks {
                _ = TaskMapper.toEntity(from: task, in: context)
            }
            try? context.save()
        }
    }
    
    func loadTasks() throws -> [Task] {
        let context = container.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let entities = try context.fetch(request)
        return TaskMapper.toDomainArray(from: entities)
    }
    
    func deleteTasks(withIds ids: [UUID]) throws {
        let context = container.newBackgroundContext()
        context.performAndWait {
            for id in ids {
                if let entity = TaskMapper.findEntity(byId: id, in: context) {
                    context.delete(entity)
                }
            }
            try? context.save()
        }
    }
    
    func clearAllTasks() throws {
        let context = container.newBackgroundContext()
        let request: NSFetchRequest<NSFetchRequestResult> = NTask.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        try context.execute(deleteRequest)
    }
    
    func saveProjects(_ projects: [Project]) throws {
        // Projects are currently string-based
    }
    
    func loadProjects() throws -> [Project] {
        let context = container.viewContext
        let projectNames = ProjectMapper.getAllProjectNames(from: context)
        return ProjectMapper.toDomainArray(from: projectNames)
    }
    
    func deleteProjects(withIds ids: [UUID]) throws {
        // Projects are currently string-based
    }
    
    func clearAllProjects() throws {
        // Projects are currently string-based
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
        return UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date
    }
    
    func setLastSyncTimestamp(_ date: Date) throws {
        UserDefaults.standard.set(date, forKey: "lastSyncTimestamp")
    }
    
    func getStorageSize() -> Int {
        return 0
    }
    
    func isAvailable() -> Bool {
        return true
    }
}

private class CloudKitRemoteDataSource: RemoteDataSourceProtocol {
    private let container: NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.container = container
    }
    
    var isAvailable: Bool { return true }
    var isSyncing: Bool { return false }
    var syncStatus: SyncStatus { return .idle }
    
    func fetchTasks(since date: Date?, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }
    
    func pushTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasks))
    }
    
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
    
    func fetchProjects(since date: Date?, completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success([]))
    }
    
    func pushProjects(_ projects: [Project], completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(projects))
    }
    
    func deleteProjects(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
    
    func performFullSync(completion: @escaping (Result<SyncResult, Error>) -> Void) {
        completion(.success(SyncResult()))
    }
    
    func performIncrementalSync(since date: Date, completion: @escaping (Result<SyncResult, Error>) -> Void) {
        completion(.success(SyncResult()))
    }
    
    func cancelSync() {}
    
    func resolveConflicts(_ conflicts: [SyncConflict], strategy: ConflictResolutionStrategy, completion: @escaping (Result<[SyncResolution], Error>) -> Void) {
        completion(.success([]))
    }
    
    func subscribeToChanges(handler: @escaping (RemoteChange) -> Void) -> SubscriptionToken {
        return SubscriptionToken()
    }
    
    func unsubscribe(token: SubscriptionToken) {}
}
