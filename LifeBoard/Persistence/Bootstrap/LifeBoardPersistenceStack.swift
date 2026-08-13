import CoreData
import Foundation
import LifeBoardDomain

/// The Core Data ownership boundary consumed by the application tier.
///
/// App composition receives protocol-typed repositories from this object and
/// does not construct concrete Core Data repositories itself. The container is
/// intentionally module-internal so new consumers cannot leak it back across
/// the Persistence boundary.
public final class LifeBoardPersistenceStack: @unchecked Sendable {
    let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    public var loadedStoreURLs: [URL] {
        container.persistentStoreCoordinator.persistentStores.compactMap(\.url)
    }

    public func saveViewContextIfNeeded() throws {
        let context = container.viewContext
        guard context.hasChanges else { return }
        try context.save()
    }

    public func makeRepositoryBundle(
        syncModeProvider: @escaping @Sendable () -> PersistentSyncMode = { .fullSync }
    ) -> LifeBoardRepositoryBundle {
        LifeBoardRepositoryFactory.make(
            stack: self,
            syncModeProvider: syncModeProvider
        )
    }
}

/// Protocol-typed persistence dependencies used by application composition.
/// Concrete Core Data implementation types never need to escape this module.
public struct LifeBoardRepositoryBundle: Sendable {
    public let project: any ProjectRepositoryProtocol
    public let taskDefinition: any TaskDefinitionRepositoryProtocol
    public let taskReadModel: any TaskReadModelRepositoryProtocol
    public let taskTagLink: any TaskTagLinkRepositoryProtocol
    public let taskDependency: any TaskDependencyRepositoryProtocol
    public let lifeArea: any LifeAreaRepositoryProtocol
    public let section: any SectionRepositoryProtocol
    public let tag: any TagRepositoryProtocol
    public let habit: any HabitRepositoryProtocol
    public let habitRuntimeRead: any HabitRuntimeReadRepositoryProtocol
    public let schedule: any ScheduleRepositoryProtocol
    public let occurrence: any OccurrenceRepositoryProtocol
    public let reminder: any ReminderRepositoryProtocol
    public let weeklyPlan: any WeeklyPlanRepositoryProtocol
    public let weeklyOutcome: any WeeklyOutcomeRepositoryProtocol
    public let weeklyReview: any WeeklyReviewRepositoryProtocol
    public let weeklyReviewMutation: any WeeklyReviewMutationRepositoryProtocol
    public let weeklyReviewDraftStore: any WeeklyReviewDraftStoreProtocol
    public let reflectionNote: any ReflectionNoteRepositoryProtocol
    public let gamification: any GamificationRepositoryProtocol
    public let assistantAction: any AssistantActionRepositoryProtocol
    public let externalSync: any ExternalSyncRepositoryProtocol
    public let tombstone: any TombstoneRepositoryProtocol
    public let cache: any CacheServiceProtocol
    public let schedulingEngine: any SchedulingEngineProtocol

    public func makeCachedProjectRepository() -> any ProjectRepositoryProtocol {
        CachedProjectRepository(repository: project, cache: cache)
    }
}

public enum LifeBoardRepositoryFactory {
    public static func make(
        stack: LifeBoardPersistenceStack,
        syncModeProvider: @escaping @Sendable () -> PersistentSyncMode = { .fullSync }
    ) -> LifeBoardRepositoryBundle {
        let container = stack.container
        let gate = SyncWriteGate(modeProvider: syncModeProvider)

        let project = WriteClosedProjectRepositoryAdapter(
            base: CoreDataProjectRepository(container: container),
            gate: gate
        )
        let taskDefinition = WriteClosedTaskDefinitionRepositoryAdapter(
            base: CoreDataTaskDefinitionRepository(container: container),
            gate: gate
        )
        let taskTagLink = WriteClosedTaskTagLinkRepositoryAdapter(
            base: CoreDataTaskTagLinkRepository(container: container),
            gate: gate
        )
        let taskDependency = WriteClosedTaskDependencyRepositoryAdapter(
            base: CoreDataTaskDependencyRepository(container: container),
            gate: gate
        )
        let lifeArea = WriteClosedLifeAreaRepositoryAdapter(
            base: CoreDataLifeAreaRepository(container: container),
            gate: gate
        )
        let section = WriteClosedSectionRepositoryAdapter(
            base: CoreDataSectionRepository(container: container),
            gate: gate
        )
        let tag = WriteClosedTagRepositoryAdapter(
            base: CoreDataTagRepository(container: container),
            gate: gate
        )
        let habit = WriteClosedHabitRepositoryAdapter(
            base: CoreDataHabitRepository(container: container),
            gate: gate
        )
        let schedule = WriteClosedScheduleRepositoryAdapter(
            base: CoreDataScheduleRepository(container: container),
            gate: gate
        )
        let occurrence = WriteClosedOccurrenceRepositoryAdapter(
            base: CoreDataOccurrenceRepository(container: container),
            gate: gate
        )
        let reminder = WriteClosedReminderRepositoryAdapter(
            base: CoreDataReminderRepository(container: container),
            gate: gate
        )
        let weeklyPlan = WriteClosedWeeklyPlanRepositoryAdapter(
            base: CoreDataWeeklyPlanRepository(container: container),
            gate: gate
        )
        let weeklyOutcome = WriteClosedWeeklyOutcomeRepositoryAdapter(
            base: CoreDataWeeklyOutcomeRepository(container: container),
            gate: gate
        )
        let weeklyReview = WriteClosedWeeklyReviewRepositoryAdapter(
            base: CoreDataWeeklyReviewRepository(container: container),
            gate: gate
        )
        let weeklyReviewMutation = WriteClosedWeeklyReviewMutationRepositoryAdapter(
            base: CoreDataWeeklyReviewMutationRepository(container: container),
            gate: gate
        )
        let reflectionNote = WriteClosedReflectionNoteRepositoryAdapter(
            base: CoreDataReflectionNoteRepository(container: container),
            gate: gate
        )
        let gamification = WriteClosedGamificationRepositoryAdapter(
            base: CoreDataGamificationRepository(container: container),
            gate: gate
        )
        let assistantAction = WriteClosedAssistantActionRepositoryAdapter(
            base: CoreDataAssistantActionRepository(container: container),
            gate: gate
        )
        let externalSync = WriteClosedExternalSyncRepositoryAdapter(
            base: CoreDataExternalSyncRepository(container: container),
            gate: gate
        )
        let tombstone = WriteClosedTombstoneRepositoryAdapter(
            base: CoreDataTombstoneRepository(container: container),
            gate: gate
        )
        let scheduleEngine = CoreSchedulingService(
            scheduleRepository: schedule,
            occurrenceRepository: occurrence
        )

        return LifeBoardRepositoryBundle(
            project: project,
            taskDefinition: taskDefinition,
            taskReadModel: CoreDataTaskReadModelRepository(container: container),
            taskTagLink: taskTagLink,
            taskDependency: taskDependency,
            lifeArea: lifeArea,
            section: section,
            tag: tag,
            habit: habit,
            habitRuntimeRead: CoreDataHabitRuntimeReadRepository(container: container),
            schedule: schedule,
            occurrence: occurrence,
            reminder: reminder,
            weeklyPlan: weeklyPlan,
            weeklyOutcome: weeklyOutcome,
            weeklyReview: weeklyReview,
            weeklyReviewMutation: weeklyReviewMutation,
            weeklyReviewDraftStore: UserDefaultsWeeklyReviewDraftStore(),
            reflectionNote: reflectionNote,
            gamification: gamification,
            assistantAction: assistantAction,
            externalSync: externalSync,
            tombstone: tombstone,
            cache: InMemoryCacheService(),
            schedulingEngine: scheduleEngine
        )
    }
}
