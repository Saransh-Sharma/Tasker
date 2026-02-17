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
public final class EnhancedDependencyContainer {

    // MARK: - Singleton

    public static let shared = EnhancedDependencyContainer()

    // MARK: - Core Dependencies

    public private(set) var persistentContainer: NSPersistentContainer!

    // MARK: - Repositories (State Management Layer)

    public private(set) var taskRepository: TaskRepositoryProtocol!
    public private(set) var projectRepository: ProjectRepositoryProtocol!
    public private(set) var taskDefinitionRepository: TaskDefinitionRepositoryProtocol?
    public private(set) var lifeAreaRepository: LifeAreaRepositoryProtocol?
    public private(set) var sectionRepository: SectionRepositoryProtocol?
    public private(set) var tagRepository: TagRepositoryProtocol?
    public private(set) var habitRepository: HabitRepositoryProtocol?
    public private(set) var scheduleRepository: ScheduleRepositoryProtocol?
    public private(set) var occurrenceRepository: OccurrenceRepositoryProtocol?
    public private(set) var reminderRepository: ReminderRepositoryProtocol?
    public private(set) var gamificationRepository: GamificationRepositoryProtocol?
    public private(set) var assistantActionRepository: AssistantActionRepositoryProtocol?
    public private(set) var externalSyncRepository: ExternalSyncRepositoryProtocol?
    public private(set) var tombstoneRepository: TombstoneRepositoryProtocol?

    // MARK: - Use Cases

    public private(set) var useCaseCoordinator: UseCaseCoordinator!

    // MARK: - Services
    
    private(set) var cacheService: CacheServiceProtocol!
    private(set) var schedulingEngine: SchedulingEngineProtocol?
    private(set) var notificationService: NotificationServiceProtocol?
    private(set) var remindersProvider: AppleRemindersProviderProtocol?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure the container with Core Data
    func configure(with container: NSPersistentContainer) {
        logDebug("🔧 EnhancedDependencyContainer: Starting configuration...")
        
        self.persistentContainer = container
        
        // Initialize cache service
        self.cacheService = InMemoryCacheService()
        
        // Initialize repositories
        let taskDefinitionRepository = CoreDataTaskDefinitionRepository(container: container)
        self.taskRepository = V2TaskRepositoryAdapter(taskDefinitionRepository: taskDefinitionRepository)
        self.projectRepository = CoreDataProjectRepository(container: container)
        self.taskDefinitionRepository = taskDefinitionRepository
        self.lifeAreaRepository = CoreDataLifeAreaRepository(container: container)
        self.sectionRepository = CoreDataSectionRepository(container: container)
        self.tagRepository = CoreDataTagRepository(container: container)
        self.habitRepository = CoreDataHabitRepository(container: container)
        self.scheduleRepository = CoreDataScheduleRepository(container: container)
        self.occurrenceRepository = CoreDataOccurrenceRepository(container: container)
        self.reminderRepository = CoreDataReminderRepository(container: container)
        self.gamificationRepository = CoreDataGamificationRepository(container: container)
        self.assistantActionRepository = CoreDataAssistantActionRepository(container: container)
        self.externalSyncRepository = CoreDataExternalSyncRepository(container: container)
        self.tombstoneRepository = CoreDataTombstoneRepository(container: container)
        if let scheduleRepository, let occurrenceRepository {
            self.schedulingEngine = CoreSchedulingEngine(
                scheduleRepository: scheduleRepository,
                occurrenceRepository: occurrenceRepository
            )
        }
        self.notificationService = LocalNotificationService()
        self.remindersProvider = EventKitAppleRemindersProvider()
        
        var v2Dependencies: UseCaseCoordinator.V2Dependencies?
        if let lifeAreaRepository,
           let sectionRepository,
           let tagRepository,
           let habitRepository,
           let schedulingEngine,
           let occurrenceRepository,
           let tombstoneRepository,
           let reminderRepository,
           let gamificationRepository,
           let assistantActionRepository,
           let externalSyncRepository {
            v2Dependencies = UseCaseCoordinator.V2Dependencies(
                lifeAreaRepository: lifeAreaRepository,
                sectionRepository: sectionRepository,
                tagRepository: tagRepository,
                taskDefinitionRepository: taskDefinitionRepository,
                habitRepository: habitRepository,
                scheduleEngine: schedulingEngine,
                occurrenceRepository: occurrenceRepository,
                tombstoneRepository: tombstoneRepository,
                reminderRepository: reminderRepository,
                gamificationRepository: gamificationRepository,
                assistantActionRepository: assistantActionRepository,
                externalSyncRepository: externalSyncRepository,
                remindersProvider: remindersProvider
            )
        }

        // Initialize UseCaseCoordinator
        self.useCaseCoordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            cacheService: cacheService,
            notificationService: notificationService,
            v2Dependencies: v2Dependencies
        )

        logDebug("✅ EnhancedDependencyContainer: Configuration completed")
    }
    
    // MARK: - Dependency Injection
    
    /// Inject dependencies into a view controller
    func inject(into viewController: UIViewController) {
        let vcType = String(describing: type(of: viewController))
        logDebug("💉 EnhancedDependencyContainer: Injecting into \(vcType)")
        
        // Clean Architecture injection
        if let cleanVC = viewController as? CleanArchitectureDependent {
            cleanVC.taskRepository = taskRepository
            cleanVC.projectRepository = projectRepository
            cleanVC.cacheService = cacheService
            logDebug("✅ Injected Clean Architecture dependencies")
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

    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchTasks(forProjectID: projectID, completion: completion)
    }

    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchTasks(from: startDate, to: endDate, completion: completion)
    }

    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchTasksWithoutProject(completion: completion)
    }

    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        cache.remove(forKey: "all_tasks")
        repository.assignTasksToProject(taskIDs: taskIDs, projectID: projectID, completion: completion)
    }

    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        repository.fetchInboxTasks(completion: completion)
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

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        repository.repairProjectIdentityCollisions(completion: completion)
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
