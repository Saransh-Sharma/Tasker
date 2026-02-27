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
    
    /// Initializes a new instance.
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
        let writeGate = SyncWriteGate()
        let baseProjectRepository = CoreDataProjectRepository(container: container)
        let taskDefinitionRepository = CoreDataTaskDefinitionRepository(container: container)
        let taskReadModelRepository = CoreDataTaskReadModelRepository(container: container)
        let taskTagLinkRepository = CoreDataTaskTagLinkRepository(container: container)
        let taskDependencyRepository = CoreDataTaskDependencyRepository(container: container)
        let baseLifeAreaRepository = CoreDataLifeAreaRepository(container: container)
        let baseSectionRepository = CoreDataSectionRepository(container: container)
        let baseTagRepository = CoreDataTagRepository(container: container)
        let baseHabitRepository = CoreDataHabitRepository(container: container)
        let baseScheduleRepository = CoreDataScheduleRepository(container: container)
        let baseOccurrenceRepository = CoreDataOccurrenceRepository(container: container)
        let baseReminderRepository = CoreDataReminderRepository(container: container)
        let baseGamificationRepository = CoreDataGamificationRepository(container: container)
        let baseAssistantActionRepository = CoreDataAssistantActionRepository(container: container)
        let baseExternalSyncRepository = CoreDataExternalSyncRepository(container: container)
        let baseTombstoneRepository = CoreDataTombstoneRepository(container: container)

        self.projectRepository = WriteClosedProjectRepositoryAdapter(
            base: baseProjectRepository,
            gate: writeGate
        )
        self.taskDefinitionRepository = WriteClosedTaskDefinitionRepositoryAdapter(
            base: taskDefinitionRepository,
            gate: writeGate
        )
        self.taskReadModelRepository = taskReadModelRepository
        self.taskTagLinkRepository = WriteClosedTaskTagLinkRepositoryAdapter(
            base: taskTagLinkRepository,
            gate: writeGate
        )
        self.taskDependencyRepository = WriteClosedTaskDependencyRepositoryAdapter(
            base: taskDependencyRepository,
            gate: writeGate
        )
        self.lifeAreaRepository = WriteClosedLifeAreaRepositoryAdapter(
            base: baseLifeAreaRepository,
            gate: writeGate
        )
        self.sectionRepository = WriteClosedSectionRepositoryAdapter(
            base: baseSectionRepository,
            gate: writeGate
        )
        self.tagRepository = WriteClosedTagRepositoryAdapter(
            base: baseTagRepository,
            gate: writeGate
        )
        self.habitRepository = WriteClosedHabitRepositoryAdapter(
            base: baseHabitRepository,
            gate: writeGate
        )
        self.scheduleRepository = WriteClosedScheduleRepositoryAdapter(
            base: baseScheduleRepository,
            gate: writeGate
        )
        self.occurrenceRepository = WriteClosedOccurrenceRepositoryAdapter(
            base: baseOccurrenceRepository,
            gate: writeGate
        )
        self.reminderRepository = WriteClosedReminderRepositoryAdapter(
            base: baseReminderRepository,
            gate: writeGate
        )
        self.gamificationRepository = WriteClosedGamificationRepositoryAdapter(
            base: baseGamificationRepository,
            gate: writeGate
        )
        self.assistantActionRepository = WriteClosedAssistantActionRepositoryAdapter(
            base: baseAssistantActionRepository,
            gate: writeGate
        )
        self.externalSyncRepository = WriteClosedExternalSyncRepositoryAdapter(
            base: baseExternalSyncRepository,
            gate: writeGate
        )
        self.tombstoneRepository = WriteClosedTombstoneRepositoryAdapter(
            base: baseTombstoneRepository,
            gate: writeGate
        )
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

    /// Executes assertV3RuntimeReady.
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

    /// Executes evaluateV3RuntimeReadiness.
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
    
    /// Initializes a new instance.
    init(repository: ProjectRepositoryProtocol, cache: CacheServiceProtocol) {
        self.repository = repository
        self.cache = cache
    }
    
    // Implement all ProjectRepositoryProtocol methods with caching
    // This is a simplified example
    
    /// Executes fetchAllProjects.
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
    
    /// Executes fetchProject.
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        repository.fetchProject(withId: id, completion: completion)
    }
    
    /// Executes fetchProject.
    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        repository.fetchProject(withName: name, completion: completion)
    }
    
    /// Executes fetchInboxProject.
    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        repository.fetchInboxProject(completion: completion)
    }
    
    /// Executes fetchCustomProjects.
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        repository.fetchCustomProjects(completion: completion)
    }
    
    /// Executes createProject.
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        cache.clearAll()
        repository.createProject(project, completion: completion)
    }
    
    /// Executes ensureInboxProject.
    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        repository.ensureInboxProject(completion: completion)
    }

    /// Executes repairProjectIdentityCollisions.
    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        repository.repairProjectIdentityCollisions(completion: completion)
    }
    
    /// Executes updateProject.
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        cache.clearAll()
        repository.updateProject(project, completion: completion)
    }
    
    /// Executes renameProject.
    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        cache.clearAll()
        repository.renameProject(withId: id, to: newName, completion: completion)
    }
    
    /// Executes deleteProject.
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        cache.clearAll()
        repository.deleteProject(withId: id, deleteTasks: deleteTasks, completion: completion)
    }
    
    /// Executes getTaskCount.
    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        repository.getTaskCount(for: projectId, completion: completion)
    }
    
    /// Executes moveTasks.
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        cache.clearAll()
        repository.moveTasks(from: sourceProjectId, to: targetProjectId, completion: completion)
    }
    
    /// Executes isProjectNameAvailable.
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        repository.isProjectNameAvailable(name, excludingId: excludingId, completion: completion)
    }
}
