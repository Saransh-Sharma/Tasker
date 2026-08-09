//
//  CompositionRoot.swift
//  LifeBoard
//
//  Enhanced dependency injection container for Clean Architecture
//

import Foundation
import CoreData
import UIKit
@preconcurrency import Combine

enum AppStoreScreenshotTestConfiguration {
    private static let fixedNowEnvironmentKey = "LIFEBOARD_SCREENSHOT_FIXED_NOW"

    static var referenceDate: Date {
        guard let value = ProcessInfo.processInfo.environment[fixedNowEnvironmentKey],
              let date = ISO8601DateFormatter().date(from: value) else {
            return Date()
        }
        return date
    }
}

private final class UserDefaultsWriteProxy: @unchecked Sendable {
    private let defaults: UserDefaults

    init(_ defaults: UserDefaults) {
        self.defaults = defaults
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

/// Enhanced dependency container supporting Clean Architecture
public final class CompositionRoot: @unchecked Sendable {
    private enum HabitRuntimeBootstrapRepair {
        static let repairKey = "lifeboard.habit.runtime.bootstrap_repair.v1"
    }

    // MARK: - Singleton

    public static let shared = CompositionRoot()

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

    // The view-model caches. Stored, so they cannot live in the
    // `CompositionRoot+ViewModels` extension that uses them.
    var _homeViewModel: HomeViewModel?
    var _addTaskViewModel: AddTaskViewModel?
    var _addHabitViewModel: AddHabitViewModel?
    var _projectManagementViewModel: ProjectManagementViewModel?
    var _lifeManagementViewModel: LifeManagementViewModel?
    var _projectSelectionViewModel: ProjectSelectionViewModel?
    var _habitLibraryViewModel: HabitLibraryViewModel?
    private(set) var schedulingEngine: SchedulingEngineProtocol?
    private(set) var notificationService: NotificationServiceProtocol?
    private(set) var remindersProvider: AppleRemindersRepositoryProtocol?
    private(set) var calendarEventsProvider: CalendarEventsRepositoryProtocol?
    
    // MARK: - Initialization
    
    /// Initializes a new instance.
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure the container with Core Data
    @MainActor
    func configure(with container: NSPersistentContainer) {
        logDebug("🔧 CompositionRoot: Starting configuration...")

        self.persistentContainer = container
        self.v3RuntimeReady = false
        self.v3RuntimeFailureReason = nil
        
        // Initialize cache service
        self.cacheService = InMemoryCacheService()
        
        // Initialize repositories
        let writeGate = SyncWriteGate(modeProvider: AppDelegate.persistentSyncModeSnapshot)
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
        self.reflectionNoteRepository = WriteClosedReflectionNoteRepositoryAdapter(
            base: baseReflectionNoteRepository,
            gate: writeGate
        )
        LegacyDailyReflectionImporter(repository: baseReflectionNoteRepository).migrate { result in
            switch result {
            case .success(let report):
                guard report.alreadyCompleted == false else { return }
                logInfo(
                    event: "legacy_daily_reflection_migration_completed",
                    message: "Imported legacy Daily Reflection text into canonical reflection notes",
                    fields: ["imported_count": String(report.importedTextCount)]
                )
            case .failure(let error):
                logWarning(
                    event: "legacy_daily_reflection_migration_failed",
                    message: "Legacy Daily Reflection text remains available for a later retry",
                    fields: ["error": error.localizedDescription]
                )
            }
        }
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
            self.schedulingEngine = CoreSchedulingService(
                scheduleRepository: scheduleRepository,
                occurrenceRepository: occurrenceRepository
            )
        }
        self.notificationService = LocalNotificationService()
        self.remindersProvider = EventKitAppleRemindersRepository()
        if let calendarMode = calendarUITestMode() {
            UserDefaultsCalendarAccessAttemptStore.shared.reset()
            if calendarMode == .deniedAfterAttempt {
                UserDefaultsCalendarAccessAttemptStore.shared.recordFullAccessAttempt(
                    CalendarAccessAttemptRecord(
                        source: "ui_test_seed",
                        statusBefore: .denied,
                        statusAfter: .denied,
                        outcome: .denied,
                        appVersion: UserDefaultsCalendarAccessAttemptStore.defaultAppVersion()
                    )
                )
            }
            self.calendarEventsProvider = UITestCalendarEventsRepository(mode: calendarMode)
            applyCalendarUITestWorkspaceDefaults(mode: calendarMode)
        } else {
            self.calendarEventsProvider = EventKitCalendarEventsRepository()
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

        logDebug("✅ CompositionRoot: Configuration completed")
    }

    private func calendarUITestMode() -> UITestCalendarMode? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-LIFEBOARD_TEST_CALENDAR_STUB") else {
            return nil
        }
        guard let modeArgument = arguments.first(where: { $0.hasPrefix("-LIFEBOARD_TEST_CALENDAR_MODE:") }) else {
            return .active
        }
        let rawMode = String(modeArgument.split(separator: ":", maxSplits: 1).last ?? "")
        return UITestCalendarMode(rawValue: rawMode) ?? .active
    }

    private func applyCalendarUITestWorkspaceDefaults(mode: UITestCalendarMode) {
        WorkspacePreferencesStore.shared.update { preferences in
            preferences.includeDeclinedCalendarEvents = false
            preferences.includeCanceledCalendarEvents = false
            preferences.includeAllDayInAgenda = true
            preferences.includeAllDayInBusyStrip = false
            preferences.showCalendarEventsInTimeline = mode == .active

            switch mode {
            case .permission, .writeOnly, .denied, .deniedAfterAttempt, .noCalendars:
                preferences.selectedCalendarIDs = []
            case .active, .allDayOnly, .empty, .error:
                preferences.selectedCalendarIDs = ["work"]
            }
        }
    }

    private func performHabitRuntimeBootstrapRepairIfNeeded() {
        let defaults = UserDefaults.standard
        let defaultsWriter = UserDefaultsWriteProxy(defaults)
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
                        defaultsWriter.set(true, forKey: HabitRuntimeBootstrapRepair.repairKey)
                    }
                }
            }
        }
    }

    /// Executes assertV3RuntimeReady.
    public func assertV3RuntimeReady() throws {
        guard v3RuntimeReady else {
            throw NSError(
                domain: "CompositionRoot",
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
    @MainActor
    
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
    case writeOnly
    case denied
    case deniedAfterAttempt
    case noCalendars
    case empty
    case error
}
