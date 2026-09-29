//
//  SceneDelegate.swift
//  LifeBoard
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass
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
    /// A `PendingShortcutLaunchAction` was queued while the app is alive (Siri
    /// in-process, Control Center, a deep link, or a return to the foreground).
    /// Launch drains the queue on its own; this covers every later arrival.
    static let lifeboardPendingShortcutHandoff = Notification.Name("LifeBoardPendingShortcutHandoff")
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private var foundationDomainMaintenance: FoundationDomainMaintenance?
    /// This window's navigation. The first window uses the shared coordinator,
    /// which widgets, intents and restoration already address; each further
    /// window gets its own (see `FoundationCoordinator(secondaryWindowFor:)`).
    var foundationCoordinator: FoundationCoordinator = .shared
    /// The scene session that owns the shared coordinator, if one is connected.
    @MainActor private static var primarySceneIdentifier: String?

    enum BootstrapFailureAction {
        case retrySync
        case recoverFromICloud
    }

    var window: UIWindow?
    var persistentBootstrapObserver: NSObjectProtocol?
    private var onboardingRequestObserver: NSObjectProtocol?
    weak var journalPrivacyShield: UIView?
    private var navigationEventCoordinator: NavigationEventCoordinator?
    private var launchCoordinator: LaunchCoordinator?
    private var onboardingCoordinator: AppOnboardingCoordinator?
    private var motionConstraintObservers: [NSObjectProtocol] = []
    /// Links, Spotlight results and notification launches that arrived while
    /// onboarding covered the window. Routing them then would change roots
    /// behind a full-screen flow the person cannot see past, and the result
    /// was lost by the time onboarding closed. Replayed once it has.
    private var routesDeferredBehindOnboarding: [() -> Void] = []
    private var deferredRouteDrainTask: Task<Void, Never>?

    /// Executes scene.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let sceneIdentifier = session.persistentIdentifier
        if let primary = Self.primarySceneIdentifier, primary != sceneIdentifier {
            foundationCoordinator = FoundationCoordinator(secondaryWindowFor: sceneIdentifier, sharing: .shared)
        } else {
            Self.primarySceneIdentifier = sceneIdentifier
        }
        
        // Create window programmatically to control root navigation composition
        window = UIWindow(windowScene: windowScene)
        #if targetEnvironment(macCatalyst)
        // A Mac window could shrink to nothing. 760 keeps it above the 700-point
        // switcher breakpoint, so the Mac always gets the desktop chrome rather
        // than the phone's bottom dock. The shell draws its own root switcher,
        // so the title bar carries no title and no toolbar of its own.
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 760, height: 600)
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
            titlebar.separatorStyle = .none
        }
        #endif
        // Anything presented outside the SwiftUI shell's `.tint` — sheets with
        // their own navigation stack, alerts, share sheets — falls back to the
        // window's tint, which was unset and therefore system blue.
        window?.tintColor = SemanticColorTokens.foundationSystemTint
        // Test and evidence fixture only. The shell's `.preferredColorScheme`
        // never reached the window, so `-LIFEBOARD_VISUAL_APPEARANCE=dark` alone
        // produced light screens — every "dark" capture taken without also
        // switching the simulator was mislabelled. Overriding the window forces
        // it everywhere, sheets and UIKit presentations included.
        if let fixture = VisualAppearanceFixture.active {
            window?.overrideUserInterfaceStyle = fixture.preferredColorScheme == .dark ? .dark : .light
        }

        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let rootMode = appDelegate?.makeLaunchRootMode() ?? .bootstrapFailure(
            message: AppDelegate.persistentBootstrapFailureMessage ?? String(localized: "Couldn’t open your data. Relaunch LifeBoard.")
        )
        renderRoot(for: rootMode)
        installPersistentBootstrapObserver()
        installMotionConstraintObservers()
        installAmbientActivityObserver()
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
        guard case .ready(let graph) = appDelegate.appRuntime.state else {
            return nil
        }
        return makeDeferredHomeRootController(
            bootstrapState: appDelegate.persistentBootstrapState,
            failureMessage: AppDelegate.persistentBootstrapFailureMessage,
            makeHomeViewModel: graph.featureFactories.makeHomeViewModel
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
                message: failureMessage ?? String(localized: "Couldn’t finish setting up.")
            )
            return nil
        }

        let projectionCoordinator = HomeProjectionCoordinator(homeViewModel: homeViewModel)
        let launchCoordinator = LaunchCoordinator(
            presentationDependencies: CompositionRoot.shared,
            homeViewModel: homeViewModel,
            router: foundationCoordinator.router
        )
        self.launchCoordinator = launchCoordinator
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let persistentContainer = appDelegate.persistentContainer else {
            showBootstrapFailureRoot(message: String(localized: "Couldn’t open your data."))
            return nil
        }
        let state = CompositionRoot.shared
        guard let taskRepository = state.taskDefinitionRepository,
              let habitRepository = state.habitRuntimeReadRepository,
              let tagRepository = state.tagRepository,
              let assistantActionRepository = state.assistantActionRepository,
              let coordinator = state.useCaseCoordinator else {
            showBootstrapFailureRoot(message: String(localized: "Couldn’t finish setting up."))
            return nil
        }

        // One coordinator owns every permission invitation, so a feature can invite
        // a not-yet-granted user without any two prompts stacking. Wiring the real
        // requests here keeps the coordinator free of service dependencies.
        PermissionPrimingCoordinator.shared.configure(
            connectHealth: { domains in
                await HealthCoordinator.shared.connectionStore.connectReadOnly()
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
        LLMContextRepositoryFactory.configurePhaseIIRepository(phaseIIRepository)
        let planningRepository = CoreDataPlanningRepository(container: persistentContainer)
        LLMContextRepositoryFactory.configureInternalTimeBlockRepository(planningRepository)
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
        foundationDomainMaintenance = CompositionRoot.shared.domainMaintenance(container: persistentContainer,
            planning: planningRepository, track: trackFoundationRepository, phaseII: phaseIIRepository,
            focusCommands: planDependencies?.focusCommands)
        if let scene = window?.windowScene, scene.activationState == .foregroundActive {
            foundationDomainMaintenance?.setScene(scene.session.persistentIdentifier, active: true)
        }
        LLMContextRepositoryFactory.configureTrackFoundationRepository(trackFoundationRepository)
        let habitRuntimeReadRepository = CoreDataHabitRuntimeReadRepository(container: persistentContainer)
        let goalSampleProvider = CoreDataGoalSampleRepository(container: persistentContainer)
        let nutritionRepository = CoreDataNutritionRepository(container: persistentContainer)
        let lifeMomentRepository = CoreDataLifeMomentRepository(container: persistentContainer)
        let wellnessRepository = CoreDataWellnessRepository(container: persistentContainer)
        EvaCaptureLaneFactory.configure(repositories: .init(
            assistantActions: assistantActionRepository,
            phaseII: phaseIIRepository,
            track: trackFoundationRepository,
            wellness: wellnessRepository,
            lifeMoments: lifeMomentRepository
        ))
        #if canImport(WatchConnectivity) && os(iOS)
        if AppDelegate.isRunningTests == false {
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
                                String(localized: "Couldn’t update habit.")
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
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "Couldn’t update fast.")]
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
                                userInfo: [NSLocalizedDescriptionKey: String(localized: "That fast has ended.")]
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
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "Couldn’t update routine.")]
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
                                userInfo: [NSLocalizedDescriptionKey: String(localized: "That routine has ended.")]
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
        }
        #endif
        if AppDelegate.isRunningTests == false,
           V2FeatureFlags.lifeOSSystemSurfacesV2Enabled,
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
                runtime: foundationCoordinator,
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
            // The live layout class for the whole shell. Without it every
            // `layoutClass.isPad` branch and readable-width cap below stayed at
            // the environment's `.phone` default on iPad and Mac.
            root: AnyView(
                foundationRoot.lifeboardLiveLayoutEnvironment(
                    initial: LayoutResolver.classify(windowScene: window?.windowScene)
                )
            ),
            presentationDependencies: CompositionRoot.shared,
            router: foundationCoordinator.router
        )

        navigationEventCoordinator?.stop()
        let navigationEventCoordinator = NavigationEventCoordinator(
            router: foundationCoordinator.router,
            homeViewModel: homeViewModel,
            isEventTarget: { [weak self] in self?.isAppWideEventTarget ?? false }
        )
        navigationEventCoordinator.start()
        self.navigationEventCoordinator = navigationEventCoordinator
        let guidanceModel = HomeOnboardingGuidanceModel()
        let onboardingCoordinator = AppOnboardingCoordinator(
            hostAdapter: foundationController,
            presentationDependencyContainer: CompositionRoot.shared,
            guidanceModel: guidanceModel
        )
        // Home renders the banner; the coordinator decides when it appears and
        // owns what accepting it does.
        homeViewModel.onboardingGuidanceModel = guidanceModel
        guidanceModel.onStart = { [weak onboardingCoordinator] in
            onboardingCoordinator?.enqueuePresentation(.fullFlow(source: "home_banner"))
        }
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

    /// Executes sceneDidDisconnect.
    func sceneDidDisconnect(_ scene: UIScene) {
        foundationDomainMaintenance?.setScene(scene.session.persistentIdentifier, active: false)
        if Self.primarySceneIdentifier == scene.session.persistentIdentifier {
            Self.primarySceneIdentifier = nil
        }
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
        if !ProcessInfo.processInfo.arguments.contains("-UI_TESTING"),
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            Task { _ = await EvaCloudAccessCoordinator.shared.ensureActivated(source: .appLaunch) }
        }
        foundationDomainMaintenance?.setScene(scene.session.persistentIdentifier, active: true)
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_did_become_active")
        // Compile signature Metal effects off the first-use path so the first bloom/reveal is smooth.
        SignatureShaders.warmUp()
        removeJournalPrivacyShield()
        AmbientActivityClock.shared.noteInteraction()
        AmbientActivityClock.shared.setCovered(acceptsAppCommands == false)
    }

    /// Feeds `AmbientActivityClock` from every touch in this window, so the
    /// sky can settle when nobody is using the app. The recognizer never
    /// recognizes, cancels, or delays anything.
    private func installAmbientActivityObserver() {
        guard let window,
              window.gestureRecognizers?.contains(where: { $0 is AmbientActivityTouchObserver }) != true else {
            return
        }
        let observer = AmbientActivityTouchObserver(target: nil, action: nil)
        observer.configurePassive()
        observer.onTouchesBegan = { [weak self] in
            AmbientActivityClock.shared.noteInteraction()
            AmbientActivityClock.shared.setCovered(self?.acceptsAppCommands == false)
        }
        observer.onTouchesMoved = {
            AmbientActivityClock.shared.noteInteraction()
        }
        window.addGestureRecognizer(observer)
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
        foundationDomainMaintenance?.setScene(scene.session.persistentIdentifier, active: false)
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        Task { @MainActor in
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "scene_will_resign_active")
        }
        installJournalPrivacyShieldIfNeeded(for: .willResignActive)
    }

    /// Executes sceneWillEnterForeground.
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_will_enter_foreground")
        // A Shortcut or Control Center press may have queued a handoff while
        // the app was suspended; the adapter drains it (no-op when empty).
        NotificationCenter.default.post(name: .lifeboardPendingShortcutHandoff, object: nil)
        // Widget buttons no longer open the app, so their queued commands
        // are applied here, on every return to the foreground.
        NotificationCenter.default.post(name: .lifeboardProcessWidgetActionCommand, object: nil)
    }

    /// Executes sceneDidEnterBackground.
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        installJournalPrivacyShieldIfNeeded(for: .didEnterBackground)
        Task { @MainActor in
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "scene_did_enter_background")
            foundationCoordinator.router.journalDidLock()
        }
        Task { await ProductTelemetry.shared.flush() }
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_did_enter_background")
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncomingURL(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleIncomingUserActivity(userActivity)
    }

    /// Queues `action` when onboarding covers this window and replays it
    /// after onboarding closes. Returns `true` when it was queued.
    func deferWhileOnboardingCovers(_ action: @escaping () -> Void) -> Bool {
        guard onboardingCoordinator?.onboardingHost != nil else { return false }
        routesDeferredBehindOnboarding.append(action)
        logInfo(
            event: "scene_route_deferred_behind_onboarding",
            message: "Deferred an incoming route until onboarding closes",
            fields: ["pending": String(routesDeferredBehindOnboarding.count)]
        )
        scheduleDeferredRouteDrain()
        return true
    }

    private func scheduleDeferredRouteDrain() {
        guard deferredRouteDrainTask == nil else { return }
        deferredRouteDrainTask = Task { @MainActor [weak self] in
            // Polls twice a second while onboarding is up; the flow owns its
            // own dismissal and posts nothing this could observe instead.
            for _ in 0..<3_600 {
                guard let self else { return }
                if self.onboardingCoordinator?.onboardingHost == nil, self.acceptsAppCommands { break }
                try? await Task.sleep(for: .milliseconds(500))
                guard Task.isCancelled == false else { return }
            }
            // Onboarding delivers its own destination as it closes; land on top
            // of it rather than racing it.
            try? await Task.sleep(for: .milliseconds(600))
            guard Task.isCancelled == false else { return }
            guard let self else { return }
            self.deferredRouteDrainTask = nil
            guard self.onboardingCoordinator?.onboardingHost == nil else {
                // Onboarding came straight back (a replay): keep waiting.
                self.scheduleDeferredRouteDrain()
                return
            }
            let pending = self.routesDeferredBehindOnboarding
            self.routesDeferredBehindOnboarding.removeAll()
            pending.forEach { $0() }
        }
    }

    func handleIncomingURL(_ url: URL) {
        if let scheme = url.scheme?.lowercased(), ["lifeboard", "tasker"].contains(scheme),
           deferWhileOnboardingCovers({ [weak self] in self?.handleIncomingURL(url) }) {
            return
        }
        if let command = RoutineLiveActivityDeepLink.command(from: url) {
            _ = foundationCoordinator.handle(url: url)
            guard V2FeatureFlags.trackBehaviorFlagshipV1Enabled else {
                foundationCoordinator.router.activeAlert = AppAlertState(
                    title: String(localized: "Couldn’t update routine"),
                    message: String(localized: "Open Track to see it.")
                )
                return
            }
            // A cold launch from the Live Activity arrives before the store
            // has opened. The command used to be dropped with a "still
            // opening" alert; it now waits (bounded) for the store and runs.
            Task { @MainActor [foundationCoordinator] in
                guard let container = await AppDelegate.readyWritableContainer() else {
                    foundationCoordinator.router.activeAlert = AppAlertState(
                        title: String(localized: "Couldn’t update routine"),
                        message: String(localized: "Use the controls in Track.")
                    )
                    return
                }
                let repository = CoreDataTrackFoundationRepository(container: container)
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
                        foundationCoordinator.router.activeAlert = AppAlertState(
                            title: String(localized: "Couldn’t update routine"),
                            message: String(localized: "It may have ended. Open Track to check.")
                        )
                    }
                }
            }
            return
        }
        if let command = FastingLiveActivityDeepLink.command(from: url) {
            _ = foundationCoordinator.handle(url: url)
            guard V2FeatureFlags.trackBehaviorFlagshipV1Enabled else {
                foundationCoordinator.router.activeAlert = AppAlertState(
                    title: String(localized: "Couldn’t update fast"),
                    message: String(localized: "Open Track to see it.")
                )
                return
            }
            Task { @MainActor [foundationCoordinator] in
                guard let container = await AppDelegate.readyWritableContainer() else {
                    foundationCoordinator.router.activeAlert = AppAlertState(
                        title: String(localized: "Couldn’t update fast"),
                        message: String(localized: "Use the controls in Track.")
                    )
                    return
                }
                let repository = CoreDataLifeBoardPhaseIIRepository(container: container)
                let store = FastingTimerStore(
                    repository: FastingRepositoryAdapter(repository: repository)
                )
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
                        foundationCoordinator.router.activeAlert = AppAlertState(
                            title: String(localized: "Couldn’t update fast"),
                            message: String(localized: "It may have ended. Open Track to check.")
                        )
                    }
                }
            }
            return
        }
        if let command = FocusLiveActivityDeepLink.command(from: url) {
            _ = foundationCoordinator.handle(url: url)
            guard let container = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer else {
                foundationCoordinator.router.activeAlert = AppAlertState(
                    title: String(localized: "Still opening"),
                    message: String(localized: "Try the focus controls in Plan.")
                )
                return
            }
            Task {
                do {
                    try await FocusLiveActivityCommandRunner.run(
                        command,
                        repository: CoreDataPlanningRepository(container: container)
                    )
                } catch {
                    await MainActor.run {
                        foundationCoordinator.router.activeAlert = AppAlertState(
                            title: String(localized: "Couldn’t update focus"),
                            message: String(localized: "It may have ended. Open Plan to check.")
                        )
                    }
                }
            }
            return
        }
        if V2FeatureFlags.lifeOSFoundationV1Enabled,
           foundationCoordinator.handle(url: url) {
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
                    userInfo: ["notice": String(localized: "Couldn’t open that page. Showing Home.")]
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

// MARK: - Menu bar and hardware keyboard commands

/// The window-side half of `AppCommandMenu`. `AppDelegate` receives the
/// commands — it is always at the end of the responder chain, so they fire
/// even when nothing in the window is first responder, which is most of the
/// time — and forwards them to the key window's scene, whose router they move.
extension SceneDelegate {
    /// Whether app-wide navigation (deep links, widget commands, notification
    /// routes) belongs to this window: the only window, else the key window's
    /// scene, else the primary window.
    var isAppWideEventTarget: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard scenes.count > 1, let mine = window?.windowScene else { return true }
        if let key = scenes.first(where: { scene in
            scene.activationState == .foregroundActive && scene.windows.contains(where: \.isKeyWindow)
        }) {
            return key === mine
        }
        return Self.primarySceneIdentifier == mine.session.persistentIdentifier
    }

    /// Off while onboarding covers the window: it is presented full screen,
    /// and the menu must not change roots or open captures behind it.
    var acceptsAppCommands: Bool {
        guard let root = window?.rootViewController else { return false }
        var presented = root.presentedViewController
        while let current = presented {
            if current.modalPresentationStyle == .fullScreen { return false }
            presented = current.presentedViewController
        }
        return true
    }

    func performNewCapture() {
        let router = foundationCoordinator.router
        if router.selectedDestination == .eva {
            NotificationCenter.default.post(name: .requestEvaChatNewThread, object: nil)
            return
        }
        router.captureRouter.request(kind: router.contextualCaptureKind, source: .shell)
    }

    func performGoTo(_ destination: Destination) {
        foundationCoordinator.router.select(destination)
    }

    func performOpenSettings() {
        let router = foundationCoordinator.router
        router.push(.settings, in: router.selectedDestination)
    }

    var newCaptureTitle: String {
        let router = foundationCoordinator.router
        return AppCommandMenu.newCaptureTitle(
            destination: router.selectedDestination,
            captureKind: router.contextualCaptureKind
        )
    }
}

/// Observes touches for `AmbientActivityClock` without participating in
/// gesture resolution: it stays in `.possible`, recognizes alongside every
/// other recognizer, and never cancels or delays touches to the views below.
private final class AmbientActivityTouchObserver: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onTouchesBegan: (@MainActor () -> Void)?
    var onTouchesMoved: (@MainActor () -> Void)?

    /// Configures the passive behaviour. Kept out of an initializer override
    /// so this does not depend on which `UIGestureRecognizer` initializer the
    /// SDK marks designated.
    func configurePassive() {
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchesBegan?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchesMoved?()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}
