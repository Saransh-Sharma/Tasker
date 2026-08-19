import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

@MainActor
final class AppOnboardingCoordinator: NSObject {
    weak var hostAdapter: (UIViewController & AppOnboardingHostAdapter)?


    let presentationDependencyContainer: CompositionRoot

    let guidanceModel: HomeOnboardingGuidanceModel

    let stateStore: AppOnboardingStateStore

    let eligibilityService: OnboardingEligibilityService

    let notificationCenter: NotificationCenter

    let feedbackController = OnboardingFeedbackController()

    var onboardingHost: UIHostingController<AnyView>?

    var hasEvaluatedLaunch = false

    var presentationQueue = OnboardingPresentationQueue()

    var pendingPresentationWasBlocked = false

    let evaAppManager = AppManager()

    lazy var lifeMapModel: LifeMapOnboardingModel = {
        let coordinator = LifeMapCommitCoordinator(
            dependencies: .init(
                fetchLifeAreas: { [weak self] in
                    guard let self else { return [] }
                    return try await self.presentationDependencyContainer.coordinator.lifeAreaRepository.fetchAllAsync()
                },
                createLifeArea: { [weak self] template in
                    guard let self else {
                        return LifeArea(name: template.name, color: template.colorHex, icon: template.icon)
                    }
                    return try await self.presentationDependencyContainer.coordinator.manageLifeAreas.createAsync(
                        name: template.name,
                        color: template.colorHex,
                        icon: template.icon
                    )
                },
                updateLifeArea: { [weak self] area in
                    guard let self else { return area }
                    return try await self.presentationDependencyContainer.coordinator.lifeAreaRepository.updateAsync(area)
                },
                fetchTask: { [weak self] id in
                    guard let self else { return nil }
                    return try await self.presentationDependencyContainer.coordinator.taskDefinitionRepository.fetchTaskDefinitionAsync(id: id)
                },
                createTask: { [weak self] request in
                    guard let self else { return request.toTaskDefinition(projectName: request.projectName) }
                    return try await self.presentationDependencyContainer.coordinator.createTaskDefinition.executeAsync(request: request)
                },
                fetchReflection: { [weak self] id in
                    guard let self else { return nil }
                    return try await self.presentationDependencyContainer.coordinator.reflectionNoteRepository
                        .fetchNotesAsync(query: ReflectionNoteQuery(limit: 200))
                        .first(where: { $0.id == id })
                },
                saveReflection: { [weak self] note in
                    guard let self else { return note }
                    return try await self.presentationDependencyContainer.coordinator.reflectionNoteRepository.saveNoteAsync(note)
                },
                saveWorkingHours: { profile in
                    guard let container = await MainActor.run(body: {
                        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer
                    }) else { return }
                    try await CoreDataPlanningRepository(container: container).saveWorkingHoursProfile(profile)
                },
                fetchHomeLayout: {
                    guard let container = await MainActor.run(body: {
                        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer
                    }) else { return nil }
                    return try await CoreDataDashboardLayoutRepository(container: container).fetchHome()
                },
                saveHomeLayout: { layout in
                    guard let container = await MainActor.run(body: {
                        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer
                    }) else { return }
                    try await CoreDataDashboardLayoutRepository(container: container).saveHome(layout)
                }
            ),
            stateStore: stateStore
        )
        return LifeMapOnboardingModel(
            stateStore: stateStore,
            commitCoordinator: coordinator,
            feedback: feedbackController,
            // Merge mode preseeds from the areas the user already has, so the
            // commit upserts their real records instead of creating near-duplicates.
            existingLifeAreas: { [weak self] in
                guard let self else { return [] }
                return try await self.presentationDependencyContainer.coordinator.lifeAreaRepository.fetchAllAsync()
            },
            powerUps: Self.makePowerUpDependencies(
                calendarService: presentationDependencyContainer.coordinator.calendarIntegrationService
            )
        )
    }()

    /// The real services behind the power-up chain.
    ///
    /// Calendar deliberately uses `requestAccessAsync()` rather than
    /// `PermissionPrimingCoordinator.performRequest`: the coordinator's calendar
    /// seam is `() -> Void`, so the grant outcome it reports is no outcome at
    /// all. Health passes `enableWriteBack: false` — onboarding asks about
    /// reading and writing as two separate questions.
    /// Waits for the calendar refresh to settle, with a ceiling.
    ///
    /// Bounded rather than open-ended: a slow or failing EventKit fetch must
    /// leave the user on a step that says "no calendars" and lets them continue,
    /// never on one that hangs.
    @MainActor
    private static func awaitLoadedCalendars(
        from service: CalendarIntegrationService,
        timeout: TimeInterval = 3
    ) async -> [CalendarSourceSnapshot] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if service.snapshot.availableCalendars.isEmpty == false {
                return service.snapshot.availableCalendars
            }
            if service.snapshot.isLoading == false, service.snapshot.errorMessage != nil { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return service.snapshot.availableCalendars
    }

    @MainActor
    private static func makePowerUpDependencies(
        calendarService: CalendarIntegrationService
    ) -> LifeMapPowerUpDependencies {
        LifeMapPowerUpDependencies(
            requestCalendarAccess: { await calendarService.requestAccessAsync() },
            availableCalendars: {
                // `availableCalendars` is populated asynchronously, inside
                // `refreshContext`'s `fetchCalendars` callback — reading the
                // snapshot straight after `refreshAuthorizationStatus()` returns
                // the pre-grant value, which is empty, and the step then says
                // "No calendars found" on a device that has several.
                calendarService.refreshAuthorizationStatus()
                calendarService.refreshContext(reason: "onboarding_calendar_step")
                return await Self.awaitLoadedCalendars(from: calendarService)
            },
            updateSelectedCalendarIDs: { ids in
                calendarService.updateSelectedCalendarIDs(ids)
            },
            upcomingEventCount: {
                calendarService.snapshot.selectedCalendarIDs.isEmpty
                    ? nil : calendarService.snapshot.eventsInRange.count
            },
            requestNotificationAccess: {
                guard let service = CompositionRoot.shared.notificationService else { return false }
                return await service.requestPermissionAsync()
            },
            connectHealth: { domains, enableWriteBack in
                await HealthCoordinator.shared.connectionStore.connect(
                    domains: domains,
                    enableWriteBack: enableWriteBack
                )
            },
            setHealthWriteEnabled: { enabled, domain in
                await HealthCoordinator.shared.connectionStore.setWriteEnabled(enabled, for: domain)
            }
        )
    }


    init?(
        hostAdapter: UIViewController & AppOnboardingHostAdapter,
        presentationDependencyContainer: CompositionRoot?,
        guidanceModel: HomeOnboardingGuidanceModel,
        stateStore: AppOnboardingStateStore = .shared,
        notificationCenter: NotificationCenter = .default
    ) {
        guard let presentationDependencyContainer else { return nil }
        guard presentationDependencyContainer.isConfiguredForRuntime else { return nil }
        self.hostAdapter = hostAdapter
        self.presentationDependencyContainer = presentationDependencyContainer
        self.guidanceModel = guidanceModel
        self.stateStore = stateStore
        self.notificationCenter = notificationCenter
        self.eligibilityService = OnboardingEligibilityService(
            stateStore: stateStore,
            lifeAreaRepository: presentationDependencyContainer.coordinator.lifeAreaRepository,
            projectRepository: presentationDependencyContainer.coordinator.projectRepository,
            taskRepository: presentationDependencyContainer.coordinator.taskDefinitionRepository
        )
        super.init()
    }
}
