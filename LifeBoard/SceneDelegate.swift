//
//  SceneDelegate.swift
//  LifeBoard
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import UserNotifications
import SwiftUI
import CoreSpotlight

// Import Clean Architecture components
// These types are defined in the Presentation layer

extension Notification.Name {
    static let lifeboardOpenFocusDeepLink = Notification.Name("LifeBoardOpenFocusDeepLink")
    static let lifeboardOpenChatDeepLink = Notification.Name("LifeBoardOpenChatDeepLink")
    static let lifeboardOpenHomeDeepLink = Notification.Name("LifeBoardOpenHomeDeepLink")
    static let lifeboardOpenInsightsDeepLink = Notification.Name("LifeBoardOpenInsightsDeepLink")
    static let lifeboardOpenTaskScopeDeepLink = Notification.Name("LifeBoardOpenTaskScopeDeepLink")
    static let lifeboardOpenTaskDetailDeepLink = Notification.Name("LifeBoardOpenTaskDetailDeepLink")
    static let lifeboardOpenWeeklyPlannerDeepLink = Notification.Name("LifeBoardOpenWeeklyPlannerDeepLink")
    static let lifeboardOpenWeeklyReviewDeepLink = Notification.Name("LifeBoardOpenWeeklyReviewDeepLink")
    static let lifeboardOpenQuickAddDeepLink = Notification.Name("LifeBoardOpenQuickAddDeepLink")
    static let lifeboardOpenCalendarScheduleDeepLink = Notification.Name("LifeBoardOpenCalendarScheduleDeepLink")
    static let lifeboardOpenCalendarChooserDeepLink = Notification.Name("LifeBoardOpenCalendarChooserDeepLink")
    static let lifeboardOpenHabitBoardDeepLink = Notification.Name("LifeBoardOpenHabitBoardDeepLink")
    static let lifeboardOpenHabitLibraryDeepLink = Notification.Name("LifeBoardOpenHabitLibraryDeepLink")
    static let lifeboardOpenHabitDetailDeepLink = Notification.Name("LifeBoardOpenHabitDetailDeepLink")
    static let lifeboardPresentHabitBoard = Notification.Name("LifeBoardPresentHabitBoard")
    static let lifeboardPresentHabitLibrary = Notification.Name("LifeBoardPresentHabitLibrary")
    static let lifeboardPresentHabitDetail = Notification.Name("LifeBoardPresentHabitDetail")
    static let lifeboardProcessWidgetActionCommand = Notification.Name("LifeBoardProcessWidgetActionCommand")
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private enum BootstrapFailureAction {
        case retrySync
        case recoverFromICloud
    }

    var window: UIWindow?
    var persistentBootstrapObserver: NSObjectProtocol?
    private var onboardingRequestObserver: NSObjectProtocol?
    private weak var journalPrivacyShield: UIView?
    private var navigationEventCoordinator: NavigationEventCoordinator?
    private var launchCoordinator: LaunchCoordinator?
    private var onboardingCoordinator: AppOnboardingCoordinator?
    private var motionConstraintObservers: [NSObjectProtocol] = []


    /// Executes scene.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Create window programmatically to control root navigation composition
        window = UIWindow(windowScene: windowScene)

        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let rootMode = appDelegate?.makeLaunchRootMode() ?? .bootstrapFailure(
            message: AppDelegate.persistentBootstrapFailureMessage ?? "LifeBoard storage is unavailable. Please relaunch the app."
        )
        renderRoot(for: rootMode)
        installPersistentBootstrapObserver()
        installMotionConstraintObservers()
        onboardingRequestObserver = NotificationCenter.default.addObserver(
            forName: .lifeboardStartOnboardingRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onboardingCoordinator?.restartOnboarding() }
        }

        if let notificationResponse = connectionOptions.notificationResponse {
            DispatchQueue.main.async { [weak self] in
                self?.handleNotificationLaunch(
                    request: notificationResponse.notification.request,
                    actionIdentifier: notificationResponse.actionIdentifier
                )
            }
        }

        if let deepLinkURL = connectionOptions.urlContexts.first?.url {
            DispatchQueue.main.async { [weak self] in
                self?.handleIncomingURL(deepLinkURL)
            }
        } else if let userActivity = connectionOptions.userActivities.first {
            DispatchQueue.main.async { [weak self] in
                self?.handleIncomingUserActivity(userActivity)
            }
        }
    }

    /// Executes renderRoot.
    func renderRoot(for rootMode: LaunchRootMode) {
        switch rootMode {
        case .loading, .home:
            if let launchHostController = window?.rootViewController as? LaunchHostController {
                launchHostController.refreshPendingHomeController()
                window?.makeKeyAndVisible()
                return
            }

            let launchHostController = LaunchHostController { [weak self] in
                self?.makeDeferredHomeRootController()
            }
            window?.rootViewController = launchHostController
            window?.makeKeyAndVisible()
        case .bootstrapFailure(let message):
            showBootstrapFailureRoot(message: message)
        }
    }

    private func makeDeferredHomeRootController() -> UIViewController? {
        let interval = PerformanceTrace.begin("SceneDeferredHomeAttach")
        defer { PerformanceTrace.end(interval) }

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return nil
        }
        return makeDeferredHomeRootController(
            bootstrapState: appDelegate.persistentBootstrapState,
            failureMessage: AppDelegate.persistentBootstrapFailureMessage,
            makeHomeViewModel: {
                let dependencies = CompositionRoot.shared
                guard dependencies.isConfiguredForRuntime else { return nil }
                return dependencies.makeHomeViewModel()
            }
        )
    }

    @discardableResult
    func makeDeferredHomeRootController(
        bootstrapState: PersistentBootstrapState,
        failureMessage: String?,
        makeHomeViewModel: () -> HomeViewModel?
    ) -> UIViewController? {
        guard case .ready = bootstrapState else {
            return nil
        }

        guard let homeViewModel = makeHomeViewModel() else {
            showBootstrapFailureRoot(
                message: failureMessage ?? "LifeBoard could not initialize dependencies."
            )
            return nil
        }

        let projectionCoordinator = HomeProjectionCoordinator(homeViewModel: homeViewModel)
        let launchCoordinator = LaunchCoordinator(
            presentationDependencies: CompositionRoot.shared,
            homeViewModel: homeViewModel,
            router: FoundationCoordinator.shared.router
        )
        self.launchCoordinator = launchCoordinator
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let persistentContainer = appDelegate.persistentContainer else {
            showBootstrapFailureRoot(message: "LifeBoard storage finished opening without a persistent container.")
            return nil
        }
        let state = CompositionRoot.shared
        guard let taskRepository = state.taskDefinitionRepository,
              let habitRepository = state.habitRuntimeReadRepository,
              let tagRepository = state.tagRepository,
              let coordinator = state.useCaseCoordinator else {
            showBootstrapFailureRoot(message: "LifeBoard’s canonical task and habit services did not finish setup.")
            return nil
        }

        // One coordinator owns every permission invitation, so a feature can invite
        // a not-yet-granted user without any two prompts stacking. Wiring the real
        // requests here keeps the coordinator free of service dependencies.
        PermissionPrimingCoordinator.shared.configure(
            connectHealth: { domains in
                await HealthCoordinator.shared.connectionStore.connect(domains: domains)
            },
            requestNotifications: {
                guard let service = CompositionRoot.shared.notificationService else { return }
                _ = await service.requestPermissionAsync()
            },
            requestCalendar: {
                coordinator.calendarIntegrationService.requestAccess(source: "permission_priming")
            }
        )

        let layoutRepository = CoreDataDashboardLayoutRepository(container: persistentContainer)
        let phaseIIRepository = CoreDataLifeBoardPhaseIIRepository(container: persistentContainer)
        let planningRepository = CoreDataPlanningRepository(container: persistentContainer)
        let planDependencies: PlanFeatureDependencies? = {
            guard V2FeatureFlags.phase1ExecutionFlagshipEnabled else { return nil }
            return PlanFeatureDependencies(
                planningRepository: planningRepository,
                taskDefinitionRepository: taskRepository,
                projectRepository: state.projectRepository,
                sectionRepository: state.sectionRepository,
                lifeAreaRepository: state.lifeAreaRepository,
                tagRepository: tagRepository,
                gamificationEngine: coordinator.gamificationEngine,
                taskTagLinkRepository: state.taskTagLinkRepository,
                taskDependencyRepository: state.taskDependencyRepository,
                reflectionNoteRepository: state.reflectionNoteRepository
            )
        }()
        if let planDependencies {
            homeViewModel.configureCanonicalFocusCommands(planDependencies.focusCommands)
        }
        let trackFoundationRepository = CoreDataTrackFoundationRepository(container: persistentContainer)
        let habitRuntimeReadRepository = CoreDataHabitRuntimeReadRepository(container: persistentContainer)
        let goalSampleProvider = CoreDataGoalSampleRepository(container: persistentContainer)
        let nutritionRepository = CoreDataNutritionRepository(container: persistentContainer)
        let lifeMomentRepository = CoreDataLifeMomentRepository(container: persistentContainer)
        let wellnessRepository = CoreDataWellnessRepository(container: persistentContainer)
        #if canImport(WatchConnectivity) && os(iOS)
        WatchConnectivityCoordinator.shared.configure(
            repository: phaseIIRepository,
            container: persistentContainer,
            resolveBehaviorOccurrence: { command, completion in
                guard V2FeatureFlags.trackBehaviorFlagshipV1Enabled else {
                    completion(.failure(NSError(
                        domain: "LifeBoardWatchBehavior",
                        code: 403,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Behavior actions are unavailable while the flagship is disabled."
                        ]
                    )))
                    return
                }
                coordinator.resolveOccurrence.execute(
                    id: command.occurrenceID,
                    resolution: command.action == .complete ? .completed : .skipped,
                    actor: .user,
                    completion: completion
                )
            },
            resolveFasting: { command, completion in
                guard V2FeatureFlags.trackBehaviorFlagshipV1Enabled else {
                    completion(.failure(NSError(
                        domain: "LifeBoardWatchFasting",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "Fasting controls are unavailable while the flagship is disabled."]
                    )))
                    return
                }
                Task {
                    do {
                        let store = FastingTimerStore(
                            repository: FastingRepositoryAdapter(repository: phaseIIRepository)
                        )
                        guard try await store.activeSession()?.id == command.sessionID else {
                            throw NSError(
                                domain: "LifeBoardWatchFasting",
                                code: 409,
                                userInfo: [NSLocalizedDescriptionKey: "That fasting session is no longer active."]
                            )
                        }
                        switch command.action {
                        case .finish:
                            _ = try await store.finish()
                        case .cancel:
                            _ = try await store.cancel()
                        }
                        completion(.success(()))
                    } catch {
                        completion(.failure(error))
                    }
                }
            },
            resolveRoutine: { command, completion in
                guard V2FeatureFlags.trackBehaviorFlagshipV1Enabled else {
                    completion(.failure(NSError(
                        domain: "LifeBoardWatchRoutine",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "Routine controls are unavailable while the flagship is disabled."]
                    )))
                    return
                }
                Task {
                    do {
                        guard let run = try await trackFoundationRepository
                            .fetchRoutineRuns(routineID: nil)
                            .first(where: { $0.id == command.runID }) else {
                            throw NSError(
                                domain: "LifeBoardWatchRoutine",
                                code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "That routine run is no longer available."]
                            )
                        }
                        let runCommand: RoutineRunCommand = switch command.action {
                        case .pause: .pause
                        case .resume: .resume
                        case .stop: .stop
                        }
                        let transition = DefaultRoutineExecutionService().apply(
                            command: runCommand,
                            to: run,
                            at: Date()
                        )
                        try await trackFoundationRepository.saveRoutineRun(transition.run)
                        await RoutineLiveActivityCoordinator.shared.synchronize(run: transition.run)
                        SystemSurfaceRefresher.requestRefreshSoon()
                        completion(.success(()))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        )
        #endif
        if V2FeatureFlags.lifeOSSystemSurfacesV2Enabled,
           let snapshotStore = SystemSnapshotStore.appGroup() {
            let projector = SystemSurfaceProjectionCoordinator(
                store: snapshotStore,
                phaseII: phaseIIRepository,
                track: trackFoundationRepository,
                wellness: wellnessRepository,
                nutrition: nutritionRepository,
                moments: lifeMomentRepository
            )
            Task {
                // Registration makes every canonical mutation republish the
                // redacted widget/Watch envelopes instead of relying on the
                // single launch-time refresh.
                await SystemSurfaceRefresher.install(projector)
                await projector.refresh()
            }
        }
        let routineLinkedMutationApplier = CanonicalRoutineLinkedMutationApplier(
            taskRepository: taskRepository,
            habitRepository: habitRepository,
            completeTask: coordinator.completeTaskDefinition,
            resolveHabit: coordinator.resolveHabitOccurrence
        )
        let starterPackMutationApplier = CanonicalStarterPackMutationApplier(
            lifeAreaRepository: coordinator.lifeAreaRepository,
            createHabitUseCase: coordinator.createHabit,
            setHabitArchivedUseCase: coordinator.setHabitArchived
        )
        let habitRecoveryMutationApplier = CanonicalHabitRecoveryMutationApplier(
            repository: habitRepository,
            resolveHabit: coordinator.resolveHabitOccurrence,
            resetHabit: coordinator.resetHabitOccurrence,
            resolveOccurrence: coordinator.resolveOccurrence,
            recomputeStreaks: coordinator.recomputeHabitStreaks
        )

        let foundationRoot = FoundationShell(
                homeViewModel: homeViewModel,
                homeProjectionAdapter: projectionCoordinator,
                dashboardLayoutRepository: layoutRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                planDependencies: planDependencies,
                trackFoundationRepository: trackFoundationRepository,
                habitRuntimeReadRepository: habitRuntimeReadRepository,
                routineLinkedMutationApplier: routineLinkedMutationApplier,
                goalSampleProvider: goalSampleProvider,
                starterPackMutationApplier: starterPackMutationApplier,
                habitRecoveryMutationApplier: habitRecoveryMutationApplier,
                nutritionRepository: nutritionRepository,
                lifeMomentRepository: lifeMomentRepository,
                wellnessRepository: wellnessRepository,
                gamificationRepository: coordinator.gamificationRepository
            )
        let foundationController = ApplicationHostController(
            root: AnyView(foundationRoot),
            presentationDependencies: CompositionRoot.shared,
            router: FoundationCoordinator.shared.router
        )

        navigationEventCoordinator?.stop()
        let navigationEventCoordinator = NavigationEventCoordinator(
            router: FoundationCoordinator.shared.router,
            homeViewModel: homeViewModel
        )
        navigationEventCoordinator.start()
        self.navigationEventCoordinator = navigationEventCoordinator
        let onboardingCoordinator = AppOnboardingCoordinator(
            hostAdapter: foundationController,
            presentationDependencyContainer: CompositionRoot.shared,
            guidanceModel: HomeOnboardingGuidanceModel()
        )
        self.onboardingCoordinator = onboardingCoordinator

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-UI_TESTING"),
           arguments.contains(where: { $0.hasPrefix("-LIFEBOARD_TEST_SEED_") }) {
            let gate = UITestSeedGateViewController()
            launchCoordinator.seedUITestWorkspacesIfNeeded { [weak gate, weak onboardingCoordinator] in
                Self.seedDayLoopRitualsIfNeeded(
                    planning: planningRepository,
                    tasks: taskRepository
                ) {
                    gate?.install(foundationController)
                    DispatchQueue.main.async {
                        onboardingCoordinator?.evaluateLaunchIfNeeded()
                    }
                }
            }
            return gate
        }

        // Manual simulator verification of the rituals does not run under
        // `-UI_TESTING`, and the seed argument was previously gated behind it —
        // so launching with `-LIFEBOARD_FORCE_DAY_CLOSE -LIFEBOARD_TEST_SEED_DAY_CLOSE`
        // by hand silently seeded nothing. There is no seed gate here: the
        // rituals are reached by tapping, so the write only has to land before
        // the person navigates, not before the first frame.
        Self.seedDayLoopRitualsIfNeeded(
            planning: planningRepository,
            tasks: taskRepository
        ) {}
        DispatchQueue.main.async { [weak onboardingCoordinator] in
            onboardingCoordinator?.evaluateLaunchIfNeeded()
        }

        return foundationController
    }

    /// Commits three known tasks to a day so the day-loop rituals have a deck.
    ///
    /// `-LIFEBOARD_TEST_SEED_DAY_CLOSE` commits them to today, which is what the
    /// evening ritual reconciles. `-LIFEBOARD_TEST_SEED_DAY_OPEN` commits them to
    /// yesterday, because `DayCloseStore` in `.open` mode reads a distinct
    /// `retrospectiveDay` — seeding today leaves the morning surface empty.
    ///
    /// This creates its own tasks. It previously wrote planning metadata over
    /// whatever another seeder had already made and returned silently when it
    /// found none, so it produced an empty deck unless it happened to be paired
    /// with a workspace seed — and `-LIFEBOARD_TEST_SEED_DAY_CLOSE` is not a
    /// case `HomeUITestWorkspaceSeeder` recognises, so pairing it did not help.
    /// Owning the rows also makes the must-do-first ordering deterministic
    /// instead of depending on which task `fetchAll` returned first.
    private static func seedDayLoopRitualsIfNeeded(
        planning: CoreDataPlanningRepository,
        tasks: any TaskDefinitionRepositoryProtocol,
        completion: @escaping () -> Void
    ) {
        let arguments = ProcessInfo.processInfo.arguments
        let seedsClose = arguments.contains("-LIFEBOARD_TEST_SEED_DAY_CLOSE")
        let seedsOpen = arguments.contains("-LIFEBOARD_TEST_SEED_DAY_OPEN")
        guard seedsClose || seedsOpen else {
            completion()
            return
        }
        // Fixed identifiers so the deck's "must-do first, then UUID" ordering is
        // reproducible across runs and a screenshot can be compared to the last.
        let seeds: [(id: UUID, title: String, commitment: TaskCommitmentLevel)] = [
            (UUID(uuidString: "0DC10000-0000-0000-0000-000000000001")!,
             "Draft the quarterly note", .mustDo),
            (UUID(uuidString: "0DC10000-0000-0000-0000-000000000002")!,
             "Reply to the venue about Friday", .standard),
            (UUID(uuidString: "0DC10000-0000-0000-0000-000000000003")!,
             "Book the dentist", .standard)
        ]
        let day = PlanningDay(
            date: seedsOpen ? Date().addingTimeInterval(-86_400) : Date()
        )

        Task { @MainActor in
            defer { completion() }
            let existing: [TaskDefinition] = await withCheckedContinuation { continuation in
                tasks.fetchAll { continuation.resume(returning: (try? $0.get()) ?? []) }
            }
            let existingIDs = Set(existing.map(\.id))
            let existingMetadata = (
                try? await planning.fetchTaskMetadata(taskIDs: Set(seeds.map(\.id)))
            ) ?? []
            let metadataByID = Dictionary(
                uniqueKeysWithValues: existingMetadata.map { ($0.taskID, $0) }
            )

            for seed in seeds {
                if existingIDs.contains(seed.id) == false {
                    let definition = TaskDefinition(
                        id: seed.id,
                        projectID: ProjectConstants.inboxProjectID,
                        title: seed.title
                    )
                    let created: Bool = await withCheckedContinuation { continuation in
                        tasks.create(definition) { continuation.resume(returning: (try? $0.get()) != nil) }
                    }
                    guard created else {
                        // Swallowing this made a failed seed indistinguishable
                        // from a successful one, which is how the empty deck
                        // went undiagnosed.
                        logError("Day-loop seed could not create task \(seed.title)")
                        continue
                    }
                }
                // Read-modify-write: constructing fresh metadata reset fields the
                // deck filters on, notably `availability` and
                // `unscheduledDisposition`.
                var metadata = metadataByID[seed.id] ?? PlanningTaskMetadata(taskID: seed.id)
                metadata.planningDay = day
                metadata.commitmentLevel = seed.commitment
                metadata.availability = .actionable
                metadata.unscheduledDisposition = .inbox
                metadata.updatedAt = Date()
                do {
                    try await planning.saveTaskMetadata(metadata)
                } catch {
                    logError("Day-loop seed could not commit \(seed.title): \(error)")
                }
            }
        }
    }

    /// Executes showBootstrapFailureRoot.
    private func showBootstrapFailureRoot(message: String) {
        let failureViewController = BootstrapFailureViewController(
            message: message,
            onRetrySync: { [weak self] in
                self?.performBootstrapFailureAction(.retrySync)
            },
            onRecoverFromICloud: { [weak self] in
                self?.performBootstrapFailureAction(.recoverFromICloud)
            }
        )
        window?.rootViewController = failureViewController
        window?.makeKeyAndVisible()
    }

    private func performBootstrapFailureAction(_ action: BootstrapFailureAction) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let mode: LaunchRootMode
        switch action {
        case .retrySync:
            mode = appDelegate.retryPersistentStoreBootstrap()
        case .recoverFromICloud:
            mode = appDelegate.recoverFromCloudAuthoritativeReset()
        }

        renderRoot(for: mode)
        if case .bootstrapFailure(let message) = mode,
           let failureVC = window?.rootViewController as? BootstrapFailureViewController {
            failureVC.setWorking(false, hint: message)
        }
    }

    /// Executes sceneDidDisconnect.
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
        if let persistentBootstrapObserver {
            NotificationCenter.default.removeObserver(persistentBootstrapObserver)
            self.persistentBootstrapObserver = nil
        }
        if let onboardingRequestObserver {
            NotificationCenter.default.removeObserver(onboardingRequestObserver)
            self.onboardingRequestObserver = nil
        }
        for observer in motionConstraintObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        motionConstraintObservers.removeAll()
    }

    /// Executes sceneDidBecomeActive.
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_did_become_active")
        // Compile signature Metal effects off the first-use path so the first bloom/reveal is smooth.
        SignatureShaders.warmUp()
        removeJournalPrivacyShield()
    }

    private func installMotionConstraintObservers() {
        guard motionConstraintObservers.isEmpty else { return }
        let center = NotificationCenter.default
        for name in [Notification.Name.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification] {
            motionConstraintObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { _ in
                    Task { @MainActor in SignatureShaders.warmUp() }
                }
            )
        }
    }

    /// Executes sceneWillResignActive.
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        Task { @MainActor in
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "scene_will_resign_active")
        }
        installJournalPrivacyShieldIfNeeded()
    }

    private func installJournalPrivacyShieldIfNeeded() {
        let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
        let policy = JournalPrivacyPolicyPersistence.load(from: defaults)
        guard policy.shieldsAppSwitcher, journalPrivacyShield == nil, let window else { return }

        let shield = UIView(frame: window.bounds)
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shield.backgroundColor = SemanticColorTokens.foundationCanvas
        shield.isAccessibilityElement = true
        shield.accessibilityLabel = "LifeBoard content hidden for privacy"

        let symbol = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        symbol.tintColor = SemanticColorTokens.foundationApricotAccent
        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        symbol.translatesAutoresizingMaskIntoConstraints = false
        shield.addSubview(symbol)
        NSLayoutConstraint.activate([
            symbol.centerXAnchor.constraint(equalTo: shield.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: shield.centerYAnchor)
        ])
        window.addSubview(shield)
        journalPrivacyShield = shield
    }

    private func removeJournalPrivacyShield() {
        journalPrivacyShield?.removeFromSuperview()
    }

    /// Executes sceneWillEnterForeground.
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_will_enter_foreground")
    }

    /// Executes sceneDidEnterBackground.
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        Task { @MainActor in
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "scene_did_enter_background")
            FoundationCoordinator.shared.router.journalDidLock()
        }
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_did_enter_background")
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncomingURL(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleIncomingUserActivity(userActivity)
    }

    private func handleIncomingUserActivity(_ userActivity: NSUserActivity) {
        if let webpageURL = userActivity.webpageURL {
            handleIncomingURL(webpageURL)
            return
        }
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }
        if let url = SpotlightRouteTranslator.url(for: identifier) {
            handleIncomingURL(url)
        } else if identifier.hasPrefix(SpotlightRouteTranslator.journalPrefix) {
            FoundationCoordinator.shared.router.restoreFallbackToHome(
                message: "That Journal result is incomplete or no longer available."
            )
        }
    }

    func handleNotificationLaunch(
        request: UNNotificationRequest,
        actionIdentifier: String = UNNotificationDefaultActionIdentifier
    ) {
        if V2FeatureFlags.lifeOSFoundationV1Enabled,
           let route = foundationNavigationRoute(for: request, actionIdentifier: actionIdentifier) {
            FoundationCoordinator.shared.router.handle(notificationRoute: route)
            return
        }
        if let actionHandler = NotificationCoordinator.actionHandler {
            actionHandler.handleAction(identifier: actionIdentifier, request: request)
            return
        }

        postFallbackNotificationRoute(for: request)
    }

    func postFallbackNotificationRoute(for request: UNNotificationRequest) {
        let payload = request.content.userInfo[LocalNotificationRequest.UserInfoKey.route] as? String
        let taskIDRaw = request.content.userInfo[LocalNotificationRequest.UserInfoKey.taskID] as? String
        let taskID = taskIDRaw.flatMap(UUID.init(uuidString:))
        let route = NotificationRoute.from(
            payload: payload ?? "home_today",
            fallbackTaskID: taskID
        )
        if V2FeatureFlags.lifeOSFoundationV1Enabled {
            FoundationCoordinator.shared.router.handle(notificationRoute: route)
            return
        }
        NotificationRouteBus.shared.post(route: route)
    }

    private func foundationNavigationRoute(
        for request: UNNotificationRequest,
        actionIdentifier: String
    ) -> NotificationRoute? {
        let payload = request.content.userInfo[LocalNotificationRequest.UserInfoKey.route] as? String
        let taskID = (request.content.userInfo[LocalNotificationRequest.UserInfoKey.taskID] as? String)
            .flatMap(UUID.init(uuidString:))
        let payloadRoute = NotificationRoute.from(
            payload: payload ?? "home_today",
            fallbackTaskID: taskID
        )
        if actionIdentifier == UNNotificationDefaultActionIdentifier { return payloadRoute }
        guard let action = NotificationActionID(rawValue: actionIdentifier) else { return nil }
        switch action {
        case .open: return payloadRoute
        case .openToday: return .homeToday(taskID: taskID)
        case .openWeeklyPlanner: return .weeklyPlanner
        case .openWeeklyReview: return .weeklyReview
        case .openDone: return .homeDone
        case .complete, .snooze15m, .snooze30m, .snooze60m: return nil
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if let command = RoutineLiveActivityDeepLink.command(from: url) {
            _ = FoundationCoordinator.shared.handle(url: url)
            guard V2FeatureFlags.trackBehaviorFlagshipV1Enabled else {
                FoundationCoordinator.shared.router.activeAlert = AppAlertState(
                    title: "Routine controls unavailable",
                    message: "Open Track to review the current run."
                )
                return
            }
            guard let container = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer else {
                FoundationCoordinator.shared.router.activeAlert = AppAlertState(
                    title: "Routine command pending",
                    message: "LifeBoard is still opening. Use the in-app routine controls once Track appears."
                )
                return
            }
            let repository = CoreDataTrackFoundationRepository(container: container)
            Task {
                do {
                    guard let run = try await repository
                        .fetchRoutineRuns(routineID: nil)
                        .first(where: { $0.id == command.runID }) else {
                        throw NSError(
                            domain: "RoutineLiveActivity",
                            code: 404,
                            userInfo: [NSLocalizedDescriptionKey: "Routine run not found"]
                        )
                    }
                    let transition = DefaultRoutineExecutionService().apply(
                        command: command.action.runCommand,
                        to: run,
                        at: Date()
                    )
                    try await repository.saveRoutineRun(transition.run)
                    await RoutineLiveActivityCoordinator.shared.synchronize(run: transition.run)
                    SystemSurfaceRefresher.requestRefreshSoon()
                } catch {
                    await MainActor.run {
                        FoundationCoordinator.shared.router.activeAlert = AppAlertState(
                            title: "Routine command not applied",
                            message: "The run may already have ended. Open Track to review its current state."
                        )
                    }
                }
            }
            return
        }
        if let command = FastingLiveActivityDeepLink.command(from: url) {
            _ = FoundationCoordinator.shared.handle(url: url)
            guard V2FeatureFlags.trackBehaviorFlagshipV1Enabled else {
                FoundationCoordinator.shared.router.activeAlert = AppAlertState(
                    title: "Fasting controls unavailable",
                    message: "Open Track to review the current session."
                )
                return
            }
            guard let container = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer else {
                FoundationCoordinator.shared.router.activeAlert = AppAlertState(
                    title: "Fasting command pending",
                    message: "LifeBoard is still opening. Use the in-app fasting controls once Track appears."
                )
                return
            }
            let repository = CoreDataLifeBoardPhaseIIRepository(container: container)
            let store = FastingTimerStore(
                repository: FastingRepositoryAdapter(repository: repository)
            )
            Task {
                do {
                    guard try await store.activeSession()?.id == command.sessionID else {
                        throw FastingTimerStoreError.noActiveSession
                    }
                    switch command.action {
                    case .finish:
                        _ = try await store.finish()
                    case .cancel:
                        _ = try await store.cancel()
                    }
                } catch {
                    await MainActor.run {
                        FoundationCoordinator.shared.router.activeAlert = AppAlertState(
                            title: "Fasting command not applied",
                            message: "The session may already have ended. Open Track to review its current state."
                        )
                    }
                }
            }
            return
        }
        if let command = FocusLiveActivityDeepLink.command(from: url) {
            _ = FoundationCoordinator.shared.handle(url: url)
            guard let container = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer else {
                FoundationCoordinator.shared.router.activeAlert = AppAlertState(
                    title: "Focus command pending",
                    message: "LifeBoard is still opening. Use the in-app Focus controls once Plan appears."
                )
                return
            }
            let repository = CoreDataPlanningRepository(container: container)
            Task {
                do {
                    let session = try await repository.handle(command)
                    let liveActivitiesAvailable = await FocusLiveActivityCoordinator.shared.synchronize(session: session)
                    await FocusNotificationFallbackCoordinator.shared.synchronize(
                        session: session,
                        title: "Focus session",
                        liveActivitiesAvailable: liveActivitiesAvailable
                    )
                } catch {
                    await MainActor.run {
                        FoundationCoordinator.shared.router.activeAlert = AppAlertState(
                            title: "Focus command not applied",
                            message: "The session may already have ended. Open Plan to review its current state."
                        )
                    }
                }
            }
            return
        }
        if V2FeatureFlags.lifeOSFoundationV1Enabled,
           FoundationCoordinator.shared.handle(url: url) {
            return
        }
        guard let scheme = url.scheme?.lowercased(), ["lifeboard", "tasker"].contains(scheme) else { return }
        guard let host = url.host?.lowercased() else { return }
        let pathSegments = url.pathComponents.filter { $0 != "/" }

        if host == "chat" {
            let prompt = ShortcutDeepLink.chatPrompt(from: url)
            var userInfo: [String: String] = [:]
            if let prompt {
                userInfo["prompt"] = prompt
            }
            NotificationCenter.default.post(
                name: .lifeboardOpenChatDeepLink,
                object: nil,
                userInfo: userInfo
            )
            return
        }
        if host == "focus" {
            NotificationCenter.default.post(name: .lifeboardOpenFocusDeepLink, object: nil)
            return
        }
        if host == "home" {
            NotificationCenter.default.post(name: .lifeboardOpenHomeDeepLink, object: nil)
            return
        }
        if host == "insights" {
            NotificationCenter.default.post(name: .lifeboardOpenInsightsDeepLink, object: nil)
            return
        }
        if host == "quickadd" {
            NotificationCenter.default.post(name: .lifeboardOpenQuickAddDeepLink, object: nil)
            return
        }
        if host == "calendar" {
            let route = pathSegments.first?.lowercased() ?? "schedule"
            switch route {
            case "schedule":
                NotificationCenter.default.post(name: .lifeboardOpenCalendarScheduleDeepLink, object: nil)
            case "chooser", "calendars", "filters":
                NotificationCenter.default.post(name: .lifeboardOpenCalendarChooserDeepLink, object: nil)
            default:
                break
            }
            return
        }
        if host == "weekly" {
            let route = pathSegments.first?.lowercased() ?? "planner"
            switch route {
            case "planner", "plan":
                NotificationCenter.default.post(name: .lifeboardOpenWeeklyPlannerDeepLink, object: nil)
            case "review":
                NotificationCenter.default.post(name: .lifeboardOpenWeeklyReviewDeepLink, object: nil)
            default:
                NotificationCenter.default.post(
                    name: .lifeboardOpenHomeDeepLink,
                    object: nil,
                    userInfo: ["notice": "That weekly destination is unavailable. Opened Home instead."]
                )
            }
            return
        }
        if host == "tasks" {
            guard let scope = pathSegments.first?.lowercased() else { return }
            if scope == "project",
               pathSegments.count > 1,
               let projectID = UUID(uuidString: pathSegments[1]) {
                NotificationCenter.default.post(
                    name: .lifeboardOpenTaskScopeDeepLink,
                    object: nil,
                    userInfo: [
                        "scope": "project",
                        "projectID": projectID.uuidString
                    ]
                )
                NotificationCenter.default.post(name: .lifeboardProcessWidgetActionCommand, object: nil)
                return
            }
            let allowedScopes: Set<String> = ["today", "upcoming", "overdue"]
            guard allowedScopes.contains(scope) else { return }
            NotificationCenter.default.post(
                name: .lifeboardOpenTaskScopeDeepLink,
                object: nil,
                userInfo: ["scope": scope]
            )
            NotificationCenter.default.post(name: .lifeboardProcessWidgetActionCommand, object: nil)
            return
        }
        if host == "habits" {
            let route = pathSegments.first?.lowercased() ?? "board"
            switch route {
            case "board":
                NotificationCenter.default.post(name: .lifeboardOpenHabitBoardDeepLink, object: nil)
            case "library", "manage":
                NotificationCenter.default.post(name: .lifeboardOpenHabitLibraryDeepLink, object: nil)
            case "habit":
                if pathSegments.count > 1,
                   let habitID = UUID(uuidString: pathSegments[1]) {
                    NotificationCenter.default.post(
                        name: .lifeboardOpenHabitDetailDeepLink,
                        object: nil,
                        userInfo: ["habitID": habitID.uuidString]
                    )
                }
            default:
                break
            }
            return
        }
        if host == "habit",
           let firstSegment = pathSegments.first,
           let habitID = UUID(uuidString: firstSegment) {
            NotificationCenter.default.post(
                name: .lifeboardOpenHabitDetailDeepLink,
                object: nil,
                userInfo: ["habitID": habitID.uuidString]
            )
            return
        }
        if host == "task",
           let firstSegment = pathSegments.first,
           let taskID = UUID(uuidString: firstSegment) {
            NotificationCenter.default.post(
                name: .lifeboardOpenTaskDetailDeepLink,
                object: nil,
                userInfo: ["taskID": taskID.uuidString]
            )
            NotificationCenter.default.post(name: .lifeboardProcessWidgetActionCommand, object: nil)
            return
        }
    }

}

/// Keeps seeded UI journeys deterministic without delaying or changing production launch.
private final class UITestSeedGateViewController: UIViewController {
    private let progress = UIActivityIndicatorView(style: .medium)
    private var installed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SemanticColorTokens.foundationCanvas
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.startAnimating()
        progress.accessibilityLabel = "Preparing LifeBoard test workspace"
        view.addSubview(progress)
        NSLayoutConstraint.activate([
            progress.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progress.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func install(_ controller: UIViewController) {
        guard installed == false else { return }
        installed = true
        loadViewIfNeeded()
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        progress.stopAnimating()
        progress.removeFromSuperview()
    }
}

final class LaunchHostController: UIViewController {
    private let resolveHomeRootController: () -> UIViewController?

    private var hasScheduledHomeAttach = false
    private var pendingHomeController: UIViewController?
    private var attachedHomeController: UIViewController?
    private let splashState = LaunchSplashState()
    private var splashHostController: UIHostingController<LaunchSplashView>?

    init(resolveHomeRootController: @escaping () -> UIViewController?) {
        self.resolveHomeRootController = resolveHomeRootController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSplash()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleHomeAttachIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        attachHomeIfPossible()
    }

    private func setupSplash() {
        view.backgroundColor = ThemeStore.shared.currentTheme.tokens.color.bgCanvas

        let splashHostController = UIHostingController(rootView: LaunchSplashView(state: splashState))
        splashHostController.view.backgroundColor = .clear
        splashHostController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(splashHostController)
        view.addSubview(splashHostController.view)
        NSLayoutConstraint.activate([
            splashHostController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splashHostController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splashHostController.view.topAnchor.constraint(equalTo: view.topAnchor),
            splashHostController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        splashHostController.didMove(toParent: self)
        self.splashHostController = splashHostController
    }

    private func scheduleHomeAttachIfNeeded() {
        guard hasScheduledHomeAttach == false else { return }
        hasScheduledHomeAttach = true

        let firstFrameInterval = PerformanceTrace.begin("LaunchHostFirstFrame")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            PerformanceTrace.end(firstFrameInterval)
            self.refreshPendingHomeController()
        }
    }

    func refreshPendingHomeController() {
        guard attachedHomeController == nil else { return }
        pendingHomeController = resolveHomeRootController()
        attachHomeIfPossible()
    }

    private func attachHomeIfPossible() {
        guard attachedHomeController == nil else { return }
        guard let homeController = pendingHomeController else { return }
        guard view.bounds.width > 1, view.bounds.height > 1 else { return }

        let interval = PerformanceTrace.begin("LaunchHostAttachHome")
        addChild(homeController)
        homeController.view.translatesAutoresizingMaskIntoConstraints = false
        homeController.view.alpha = 1
        if let splashView = splashHostController?.view {
            view.insertSubview(homeController.view, belowSubview: splashView)
        } else {
            view.addSubview(homeController.view)
        }
        NSLayoutConstraint.activate([
            homeController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            homeController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            homeController.view.topAnchor.constraint(equalTo: view.topAnchor),
            homeController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        homeController.didMove(toParent: self)
        PerformanceTrace.end(interval)
        attachedHomeController = homeController
        pendingHomeController = nil
        completeSplashOverAttachedHome()
    }

    private func completeSplashOverAttachedHome() {
        guard let splashHostController else { return }

        if MotionOverride.effectiveReduceMotion {
            fadeSplashOverAttachedHome(duration: 0.12, delay: 0)
            return
        }

        splashState.completeReveal()
        fadeSplashOverAttachedHome(
            duration: LaunchSplashMetrics.finalCrossfadeDuration,
            delay: max(
                LaunchSplashMetrics.revealDuration
                    - LaunchSplashMetrics.finalCrossfadeDuration,
                0
            ),
            splashHostController: splashHostController
        )
    }

    private func fadeSplashOverAttachedHome(
        duration: TimeInterval,
        delay: TimeInterval,
        splashHostController: UIHostingController<LaunchSplashView>? = nil
    ) {
        let splashHostController = splashHostController ?? self.splashHostController
        guard let splashHostController else { return }

        UIView.animate(
            withDuration: duration,
            delay: delay,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            splashHostController.view.alpha = 0
        } completion: { [weak self, weak splashHostController] _ in
            guard let self, let splashHostController else { return }
            self.removeSplashHostController(splashHostController)
        }
    }

    private func removeSplashHostController(
        _ splashHostController: UIHostingController<LaunchSplashView>
    ) {
        splashHostController.willMove(toParent: nil)
        splashHostController.view.removeFromSuperview()
        splashHostController.removeFromParent()
        if self.splashHostController === splashHostController {
            self.splashHostController = nil
        }
    }
}
