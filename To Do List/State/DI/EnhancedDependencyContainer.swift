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

    public private(set) var projectRepository: ProjectRepositoryProtocol!
    public private(set) var taskDefinitionRepository: TaskDefinitionRepositoryProtocol?
    public private(set) var taskReadModelRepository: TaskReadModelRepositoryProtocol?
    public private(set) var taskTagLinkRepository: TaskTagLinkRepositoryProtocol?
    public private(set) var taskDependencyRepository: TaskDependencyRepositoryProtocol?
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
    public private(set) var v3RuntimeReady: Bool = false
    public private(set) var v3RuntimeFailureReason: String?

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
        self.v3RuntimeReady = false
        self.v3RuntimeFailureReason = nil
        
        // Initialize cache service
        self.cacheService = InMemoryCacheService()
        
        // Initialize repositories
        let taskDefinitionRepository = CoreDataTaskDefinitionRepository(container: container)
        let taskReadModelRepository = CoreDataTaskReadModelRepository(container: container)
        let taskTagLinkRepository = CoreDataTaskTagLinkRepository(container: container)
        let taskDependencyRepository = CoreDataTaskDependencyRepository(container: container)
        self.projectRepository = CoreDataProjectRepository(container: container)
        self.taskDefinitionRepository = taskDefinitionRepository
        self.taskReadModelRepository = taskReadModelRepository
        self.taskTagLinkRepository = taskTagLinkRepository
        self.taskDependencyRepository = taskDependencyRepository
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

        guard let lifeAreaRepository,
              let sectionRepository,
              let tagRepository,
              let habitRepository,
              let schedulingEngine,
              let occurrenceRepository,
              let tombstoneRepository,
              let reminderRepository,
              let gamificationRepository,
              let assistantActionRepository,
              let externalSyncRepository else {
            v3RuntimeReady = false
            v3RuntimeFailureReason = "Missing required V3 repository dependencies during container configuration"
            logError(
                event: "v3_runtime_not_ready",
                message: "Enhanced dependency container failed to construct required dependencies"
            )
            return
        }

        let v2Dependencies = UseCaseCoordinator.V2Dependencies(
            lifeAreaRepository: lifeAreaRepository,
            sectionRepository: sectionRepository,
            tagRepository: tagRepository,
            taskDefinitionRepository: taskDefinitionRepository,
            taskTagLinkRepository: taskTagLinkRepository,
            taskDependencyRepository: taskDependencyRepository,
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

        // Initialize UseCaseCoordinator
        self.useCaseCoordinator = UseCaseCoordinator(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository,
            cacheService: cacheService,
            notificationService: notificationService,
            v2Dependencies: v2Dependencies
        )

        evaluateV3RuntimeReadiness()

        logDebug("✅ EnhancedDependencyContainer: Configuration completed")
    }

    public func assertV3RuntimeReady() throws {
        guard v3RuntimeReady else {
            throw NSError(
                domain: "EnhancedDependencyContainer",
                code: 503,
                userInfo: [
                    NSLocalizedDescriptionKey: v3RuntimeFailureReason
                    ?? "V3 runtime dependencies are not fully configured"
                ]
            )
        }
    }

    private func evaluateV3RuntimeReadiness() {
        var missing: [String] = []
        if taskDefinitionRepository == nil { missing.append("taskDefinitionRepository") }
        if externalSyncRepository == nil { missing.append("externalSyncRepository") }
        if assistantActionRepository == nil { missing.append("assistantActionRepository") }

        if missing.isEmpty {
            v3RuntimeReady = true
            v3RuntimeFailureReason = nil
            return
        }

        v3RuntimeReady = false
        v3RuntimeFailureReason = "Missing required V3 runtime dependencies: \(missing.joined(separator: ", "))"
        logError(
            event: "v3_runtime_not_ready",
            message: "Enhanced dependency container failed V3 runtime readiness checks",
            fields: [
                "missing": missing.joined(separator: ",")
            ]
        )
    }
    
    // MARK: - Dependency Injection
    
    /// Inject dependencies into a view controller
    func inject(into viewController: UIViewController) {
        let vcType = String(describing: type(of: viewController))
        logDebug("💉 EnhancedDependencyContainer: Injecting into \(vcType)")

        // Inject into child view controllers
        for child in viewController.children {
            inject(into: child)
        }
    }
    
    // MARK: - Factory Methods
    
    /// Create a project repository with caching
    func makeCachedProjectRepository() -> ProjectRepositoryProtocol {
        return CachedProjectRepository(
            repository: projectRepository,
            cache: cacheService
        )
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
    
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        cache.clearAll()
        repository.moveTasks(from: sourceProjectId, to: targetProjectId, completion: completion)
    }
    
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        repository.isProjectNameAvailable(name, excludingId: excludingId, completion: completion)
    }
}
