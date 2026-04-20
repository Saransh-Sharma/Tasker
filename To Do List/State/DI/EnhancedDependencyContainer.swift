//
//  EnhancedDependencyContainer.swift
//  Tasker
//
//  Enhanced dependency injection container for Clean Architecture
//

import Foundation
import CoreData
import UIKit
import Combine

/// Enhanced dependency container supporting Clean Architecture
public final class EnhancedDependencyContainer {
    private enum HabitRuntimeBootstrapRepair {
        static let repairKey = "tasker.habit.runtime.bootstrap_repair.v1"
    }

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
    public private(set) var habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol?
    public private(set) var scheduleRepository: ScheduleRepositoryProtocol?
    public private(set) var occurrenceRepository: OccurrenceRepositoryProtocol?
    public private(set) var reminderRepository: ReminderRepositoryProtocol?
    public private(set) var weeklyPlanRepository: WeeklyPlanRepositoryProtocol?
    public private(set) var weeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol?
    public private(set) var weeklyReviewRepository: WeeklyReviewRepositoryProtocol?
    public private(set) var weeklyReviewMutationRepository: WeeklyReviewMutationRepositoryProtocol?
    public private(set) var weeklyReviewDraftStore: WeeklyReviewDraftStoreProtocol?
    public private(set) var dailyReflectionStore: DailyReflectionStoreProtocol?
    public private(set) var reflectionNoteRepository: ReflectionNoteRepositoryProtocol?
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
    private(set) var calendarEventsProvider: CalendarEventsProviderProtocol?
    
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
        let baseHabitRuntimeReadRepository = CoreDataHabitRuntimeReadRepository(container: container)
        let baseScheduleRepository = CoreDataScheduleRepository(container: container)
        let baseOccurrenceRepository = CoreDataOccurrenceRepository(container: container)
        let baseReminderRepository = CoreDataReminderRepository(container: container)
        let baseWeeklyPlanRepository = CoreDataWeeklyPlanRepository(container: container)
        let baseWeeklyOutcomeRepository = CoreDataWeeklyOutcomeRepository(container: container)
        let baseWeeklyReviewRepository = CoreDataWeeklyReviewRepository(container: container)
        let baseWeeklyReviewMutationRepository = CoreDataWeeklyReviewMutationRepository(container: container)
        let baseWeeklyReviewDraftStore = UserDefaultsWeeklyReviewDraftStore()
        let baseDailyReflectionStore = UserDefaultsDailyReflectionStore()
        let baseReflectionNoteRepository = CoreDataReflectionNoteRepository(container: container)
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
        self.habitRuntimeReadRepository = baseHabitRuntimeReadRepository
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
        self.weeklyPlanRepository = WriteClosedWeeklyPlanRepositoryAdapter(
            base: baseWeeklyPlanRepository,
            gate: writeGate
        )
        self.weeklyOutcomeRepository = WriteClosedWeeklyOutcomeRepositoryAdapter(
            base: baseWeeklyOutcomeRepository,
            gate: writeGate
        )
        self.weeklyReviewRepository = WriteClosedWeeklyReviewRepositoryAdapter(
            base: baseWeeklyReviewRepository,
            gate: writeGate
        )
        self.weeklyReviewMutationRepository = WriteClosedWeeklyReviewMutationRepositoryAdapter(
            base: baseWeeklyReviewMutationRepository,
            gate: writeGate
        )
        self.weeklyReviewDraftStore = baseWeeklyReviewDraftStore
        self.dailyReflectionStore = baseDailyReflectionStore
        self.reflectionNoteRepository = WriteClosedReflectionNoteRepositoryAdapter(
            base: baseReflectionNoteRepository,
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
        if let calendarMode = calendarUITestMode() {
            self.calendarEventsProvider = UITestCalendarEventsProvider(mode: calendarMode)
            applyCalendarUITestWorkspaceDefaults(mode: calendarMode)
        } else {
            self.calendarEventsProvider = EventKitCalendarEventsProvider()
        }

        guard let lifeAreaRepository,
              let sectionRepository,
              let tagRepository,
              let habitRepository,
              let habitRuntimeReadRepository = self.habitRuntimeReadRepository,
              let scheduleRepository,
              let schedulingEngine,
              let occurrenceRepository,
              let tombstoneRepository,
              let reminderRepository,
              let weeklyPlanRepository,
              let weeklyOutcomeRepository,
              let weeklyReviewRepository,
              let weeklyReviewMutationRepository,
              let weeklyReviewDraftStore,
              let dailyReflectionStore,
              let reflectionNoteRepository,
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
            projectRepository: projectRepository,
            lifeAreaRepository: lifeAreaRepository,
            sectionRepository: sectionRepository,
            tagRepository: tagRepository,
            taskDefinitionRepository: taskDefinitionRepository,
            taskTagLinkRepository: taskTagLinkRepository,
            taskDependencyRepository: taskDependencyRepository,
            habitRepository: habitRepository,
            habitRuntimeReadRepository: habitRuntimeReadRepository,
            scheduleRepository: scheduleRepository,
            scheduleEngine: schedulingEngine,
            occurrenceRepository: occurrenceRepository,
            tombstoneRepository: tombstoneRepository,
            reminderRepository: reminderRepository,
            weeklyPlanRepository: weeklyPlanRepository,
            weeklyOutcomeRepository: weeklyOutcomeRepository,
            weeklyReviewRepository: weeklyReviewRepository,
            weeklyReviewMutationRepository: weeklyReviewMutationRepository,
            weeklyReviewDraftStore: weeklyReviewDraftStore,
            dailyReflectionStore: dailyReflectionStore,
            reflectionNoteRepository: reflectionNoteRepository,
            gamificationRepository: gamificationRepository,
            assistantActionRepository: assistantActionRepository,
            externalSyncRepository: externalSyncRepository,
            remindersProvider: remindersProvider,
            calendarEventsProvider: calendarEventsProvider
        )

        // Initialize UseCaseCoordinator
        self.useCaseCoordinator = UseCaseCoordinator(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: projectRepository,
            cacheService: cacheService,
            notificationService: notificationService,
            v2Dependencies: v2Dependencies
        )

        performHabitRuntimeBootstrapRepairIfNeeded()

        evaluateV3RuntimeReadiness()

        logDebug("✅ EnhancedDependencyContainer: Configuration completed")
    }

    private func calendarUITestMode() -> UITestCalendarMode? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-TASKER_TEST_CALENDAR_STUB") else {
            return nil
        }
        guard let modeArgument = arguments.first(where: { $0.hasPrefix("-TASKER_TEST_CALENDAR_MODE:") }) else {
            return .active
        }
        let rawMode = String(modeArgument.split(separator: ":", maxSplits: 1).last ?? "")
        return UITestCalendarMode(rawValue: rawMode) ?? .active
    }

    private func applyCalendarUITestWorkspaceDefaults(mode: UITestCalendarMode) {
        TaskerWorkspacePreferencesStore.shared.update { preferences in
            preferences.includeDeclinedCalendarEvents = false
            preferences.includeCanceledCalendarEvents = false
            preferences.includeAllDayInAgenda = true
            preferences.includeAllDayInBusyStrip = false

            switch mode {
            case .permission, .noCalendars:
                preferences.selectedCalendarIDs = []
            case .active, .allDayOnly, .empty, .error:
                preferences.selectedCalendarIDs = ["work"]
            }
        }
    }

    private func performHabitRuntimeBootstrapRepairIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: HabitRuntimeBootstrapRepair.repairKey) == false else {
            return
        }

        useCaseCoordinator.maintainHabitRuntime.execute(anchorDate: Date()) { [weak self] maintainResult in
            switch maintainResult {
            case .failure(let error):
                logWarning(
                    event: "habit_runtime_bootstrap_maintain_failed",
                    message: "Failed one-time habit runtime maintenance during startup",
                    fields: ["error": error.localizedDescription]
                )
            case .success:
                self?.useCaseCoordinator.recomputeHabitStreaks.execute(referenceDate: Date()) { recomputeResult in
                    switch recomputeResult {
                    case .failure(let error):
                        logWarning(
                            event: "habit_runtime_bootstrap_recompute_failed",
                            message: "Failed one-time habit streak recompute during startup",
                            fields: ["error": error.localizedDescription]
                        )
                    case .success:
                        defaults.set(true, forKey: HabitRuntimeBootstrapRepair.repairKey)
                    }
                }
            }
        }
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
        if habitRuntimeReadRepository == nil { missing.append("habitRuntimeReadRepository") }

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

enum UITestCalendarMode: String {
    case active
    case allDayOnly
    case permission
    case noCalendars
    case empty
    case error
}

final class UITestCalendarEventsProvider: CalendarEventsProviderProtocol {
    private let mode: UITestCalendarMode
    private let storeChangedSubject = PassthroughSubject<Void, Never>()
    private var authStatus: TaskerCalendarAuthorizationStatus

    init(mode: UITestCalendarMode) {
        self.mode = mode
        switch mode {
        case .permission:
            self.authStatus = .notDetermined
        case .active, .allDayOnly, .noCalendars, .empty, .error:
            self.authStatus = .authorized
        }
    }

    func authorizationStatus() -> TaskerCalendarAuthorizationStatus {
        authStatus
    }

    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        authStatus = .authorized
        completion(.success(true))
    }

    func resetStoreStateAfterPermissionChange() {}

    func fetchCalendars(completion: @escaping (Result<[TaskerCalendarSourceSnapshot], Error>) -> Void) {
        switch mode {
        case .error:
            completion(.failure(NSError(
                domain: "UITestCalendarEventsProvider",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load test calendars."]
            )))
        case .noCalendars:
            completion(.success([]))
        default:
            completion(.success([
                TaskerCalendarSourceSnapshot(
                    id: "work",
                    title: "Work",
                    sourceTitle: "iCloud",
                    colorHex: "#007AFF",
                    allowsContentModifications: false
                ),
                TaskerCalendarSourceSnapshot(
                    id: "personal",
                    title: "Personal",
                    sourceTitle: "iCloud",
                    colorHex: "#34C759",
                    allowsContentModifications: false
                )
            ]))
        }
    }

    func fetchEvents(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSnapshot], Error>) -> Void
    ) {
        switch mode {
        case .permission, .noCalendars, .empty:
            completion(.success([]))
        case .error:
            completion(.failure(NSError(
                domain: "UITestCalendarEventsProvider",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load test events."]
            )))
        case .active:
            let calendar = Calendar.current
            let now = Date()
            let clampedAnchor = min(max(now, startDate), endDate.addingTimeInterval(-60))
            let startOfAnchorDay = calendar.startOfDay(for: clampedAnchor)
            let firstStart = calendar.date(byAdding: .hour, value: 10, to: startOfAnchorDay) ?? startOfAnchorDay
            let firstEnd = calendar.date(byAdding: .minute, value: 30, to: firstStart) ?? firstStart
            let secondStart = calendar.date(byAdding: .hour, value: 14, to: startOfAnchorDay) ?? firstEnd
            let secondEnd = calendar.date(byAdding: .minute, value: 30, to: secondStart) ?? secondStart
            let allEvents = [
                TaskerCalendarEventSnapshot(
                    id: "test_meeting_1",
                    calendarID: "work",
                    calendarTitle: "Work",
                    calendarColorHex: "#007AFF",
                    title: "Design Review",
                    location: "Zoom",
                    startDate: firstStart,
                    endDate: firstEnd,
                    isAllDay: false,
                    availability: .busy,
                    participationStatus: .accepted
                ),
                TaskerCalendarEventSnapshot(
                    id: "test_meeting_2",
                    calendarID: "work",
                    calendarTitle: "Work",
                    calendarColorHex: "#007AFF",
                    title: "Sprint Standup",
                    location: "Room A",
                    startDate: secondStart,
                    endDate: secondEnd,
                    isAllDay: false,
                    availability: .busy,
                    participationStatus: .accepted
                )
            ]
            let inWindowEvents = allEvents.filter { event in
                event.endDate > startDate && event.startDate < endDate
            }
            let filteredEvents = calendarIDs.isEmpty
                ? inWindowEvents
                : inWindowEvents.filter { calendarIDs.contains($0.calendarID) }
            completion(.success(filteredEvents))
        case .allDayOnly:
            let calendar = Calendar.current
            let now = Date()
            let clampedAnchor = min(max(now, startDate), endDate.addingTimeInterval(-60))
            let allDayStart = calendar.startOfDay(for: clampedAnchor)
            let allDayEnd = calendar.date(byAdding: .day, value: 1, to: allDayStart) ?? allDayStart
            let event = TaskerCalendarEventSnapshot(
                id: "test_all_day",
                calendarID: "work",
                calendarTitle: "Work",
                calendarColorHex: "#007AFF",
                title: "All-Day Offsite",
                location: nil,
                startDate: allDayStart,
                endDate: allDayEnd,
                isAllDay: true,
                availability: .busy,
                participationStatus: .accepted
            )
            let inWindow = event.endDate > startDate && event.startDate < endDate
            let matchesCalendar = calendarIDs.isEmpty || calendarIDs.contains(event.calendarID)
            completion(.success(inWindow && matchesCalendar ? [event] : []))
        }
    }

    func storeChangedPublisher() -> AnyPublisher<Void, Never> {
        storeChangedSubject.eraseToAnyPublisher()
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

    /// Executes moveProjectToLifeArea.
    func moveProjectToLifeArea(
        projectID: UUID,
        lifeAreaID: UUID,
        completion: @escaping (Result<ProjectLifeAreaMoveResult, Error>) -> Void
    ) {
        cache.clearAll()
        repository.moveProjectToLifeArea(
            projectID: projectID,
            lifeAreaID: lifeAreaID,
            completion: completion
        )
    }

    /// Executes backfillProjectsWithoutLifeArea.
    func backfillProjectsWithoutLifeArea(
        defaultLifeAreaID: UUID,
        completion: @escaping (Result<ProjectLifeAreaBackfillResult, Error>) -> Void
    ) {
        cache.clearAll()
        repository.backfillProjectsWithoutLifeArea(
            defaultLifeAreaID: defaultLifeAreaID,
            completion: completion
        )
    }
    
    /// Executes isProjectNameAvailable.
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        repository.isProjectNameAvailable(name, excludingId: excludingId, completion: completion)
    }
}
