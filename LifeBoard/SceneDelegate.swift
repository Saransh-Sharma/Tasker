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
    private var persistentBootstrapObserver: NSObjectProtocol?
    private weak var journalPrivacyShield: UIView?


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
    private func renderRoot(for rootMode: LaunchRootMode) {
        switch rootMode {
        case .loading, .home:
            if let launchHostController = window?.rootViewController as? LifeBoardLaunchHostController {
                launchHostController.refreshPendingHomeController()
                window?.makeKeyAndVisible()
                return
            }

            let launchHostController = LifeBoardLaunchHostController { [weak self] in
                self?.makeDeferredHomeRootController()
            }
            window?.rootViewController = launchHostController
            window?.makeKeyAndVisible()
        case .bootstrapFailure(let message):
            showBootstrapFailureRoot(message: message)
        }
    }

    private func makeDeferredHomeRootController() -> UIViewController? {
        let interval = LifeBoardPerformanceTrace.begin("SceneDeferredHomeAttach")
        defer { LifeBoardPerformanceTrace.end(interval) }

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return nil
        }
        return makeDeferredHomeRootController(
            bootstrapState: appDelegate.persistentBootstrapState,
            failureMessage: AppDelegate.persistentBootstrapFailureMessage,
            instantiateHomeViewController: {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                return storyboard.instantiateViewController(withIdentifier: "homeScreen") as? HomeViewController
            },
            tryInject: { PresentationDependencyContainer.shared.tryInject(into: $0) }
        )
    }

    @discardableResult
    func makeDeferredHomeRootController(
        bootstrapState: PersistentBootstrapState,
        failureMessage: String?,
        instantiateHomeViewController: () -> HomeViewController?,
        tryInject: (HomeViewController) -> Bool
    ) -> UIViewController? {
        guard case .ready = bootstrapState else {
            return nil
        }

        guard let homeViewController = instantiateHomeViewController() else {
            showBootstrapFailureRoot(message: "LifeBoard could not load the home screen.")
            return nil
        }

        guard tryInject(homeViewController) else {
            showBootstrapFailureRoot(
                message: failureMessage ?? "LifeBoard could not initialize dependencies."
            )
            return nil
        }

        let productionController = UINavigationController(rootViewController: homeViewController)

        guard V2FeatureFlags.lifeOSFoundationV1Enabled
                || V2FeatureFlags.adaptiveHomeV2Enabled
                || V2FeatureFlags.trackersV1Enabled
                || V2FeatureFlags.healthIntegrationsV1Enabled
                || V2FeatureFlags.journalV1Enabled
                || V2FeatureFlags.knowledgeNotesV1Enabled
                || V2FeatureFlags.planDestinationV1Enabled
                || V2FeatureFlags.trackFoundationsV2Enabled else {
            return productionController
        }

        let projectionAdapter = HomeProjectionAdapter(
            chromeStore: homeViewController.chromeStore,
            tasksStore: homeViewController.tasksStore,
            habitsStore: homeViewController.habitsStore,
            calendarStore: homeViewController.calendarStore
        )
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let persistentContainer = appDelegate.persistentContainer else {
            showBootstrapFailureRoot(message: "LifeBoard storage finished opening without a persistent container.")
            return nil
        }
        let state = EnhancedDependencyContainer.shared
        guard let taskRepository = state.taskDefinitionRepository,
              let habitRepository = state.habitRuntimeReadRepository,
              let coordinator = state.useCaseCoordinator else {
            showBootstrapFailureRoot(message: "LifeBoard’s canonical task and habit services did not finish setup.")
            return nil
        }

        let layoutRepository = CoreDataDashboardLayoutRepository(container: persistentContainer)
        let phaseIIRepository = CoreDataLifeBoardPhaseIIRepository(container: persistentContainer)
        let planningRepository = CoreDataPlanningRepository(container: persistentContainer)
        let trackFoundationRepository = CoreDataTrackFoundationRepository(container: persistentContainer)
        let habitRuntimeReadRepository = CoreDataHabitRuntimeReadRepository(container: persistentContainer)
        let goalSampleProvider = CoreDataGoalSampleProvider(container: persistentContainer)
        let nutritionRepository = CoreDataNutritionRepository(container: persistentContainer)
        let lifeMomentRepository = CoreDataLifeMomentRepository(container: persistentContainer)
        let wellnessRepository = CoreDataWellnessRepository(container: persistentContainer)
        #if canImport(WatchConnectivity) && os(iOS)
        LifeBoardWatchConnectivityCoordinator.shared.configure(
            repository: phaseIIRepository,
            container: persistentContainer
        )
        #endif
        if V2FeatureFlags.lifeOSSystemSurfacesV2Enabled,
           let snapshotStore = LifeBoardSystemSnapshotStore.appGroup() {
            let projector = LifeBoardSystemSurfaceProjectionCoordinator(
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
                await LifeBoardSystemSurfaceRefresher.install(projector)
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

        let foundationController = UIHostingController(
            rootView: LifeOSFoundationShell(
                legacyHomeController: productionController,
                homeProjectionAdapter: projectionAdapter,
                dashboardLayoutRepository: layoutRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                trackFoundationRepository: trackFoundationRepository,
                habitRuntimeReadRepository: habitRuntimeReadRepository,
                routineLinkedMutationApplier: routineLinkedMutationApplier,
                goalSampleProvider: goalSampleProvider,
                starterPackMutationApplier: starterPackMutationApplier,
                habitRecoveryMutationApplier: habitRecoveryMutationApplier,
                nutritionRepository: nutritionRepository,
                lifeMomentRepository: lifeMomentRepository,
                wellnessRepository: wellnessRepository
            )
        )

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-UI_TESTING"),
           arguments.contains(where: { $0.hasPrefix("-LIFEBOARD_TEST_SEED_") }) {
            let gate = FoundationUITestSeedGateViewController()
            homeViewController.loadViewIfNeeded()
            homeViewController.seedUITestWorkspacesForLaunchIfNeeded { [weak gate] in
                gate?.install(foundationController)
            }
            return gate
        }

        return foundationController
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
    }

    /// Executes sceneDidBecomeActive.
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_did_become_active")
        // Compile signature Metal effects off the first-use path so the first bloom/reveal is smooth.
        LifeBoardSignatureShaders.warmUp()
        removeJournalPrivacyShield()
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
        shield.backgroundColor = LifeBoardColorTokens.foundationCanvas
        shield.isAccessibilityElement = true
        shield.accessibilityLabel = "LifeBoard content hidden for privacy"

        let symbol = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        symbol.tintColor = LifeBoardColorTokens.foundationApricotAccent
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
            LifeOSFoundationRuntime.shared.router.journalDidLock()
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
        if let url = LifeBoardSpotlightRouteTranslator.url(for: identifier) {
            handleIncomingURL(url)
        } else if identifier.hasPrefix(LifeBoardSpotlightRouteTranslator.journalPrefix) {
            LifeOSFoundationRuntime.shared.router.restoreFallbackToHome(
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
            LifeOSFoundationRuntime.shared.router.handle(notificationRoute: route)
            return
        }
        if let actionHandler = LifeBoardNotificationRuntime.actionHandler {
            actionHandler.handleAction(identifier: actionIdentifier, request: request)
            return
        }

        postFallbackNotificationRoute(for: request)
    }

    func postFallbackNotificationRoute(for request: UNNotificationRequest) {
        let payload = request.content.userInfo[LifeBoardLocalNotificationRequest.UserInfoKey.route] as? String
        let taskIDRaw = request.content.userInfo[LifeBoardLocalNotificationRequest.UserInfoKey.taskID] as? String
        let taskID = taskIDRaw.flatMap(UUID.init(uuidString:))
        let route = LifeBoardNotificationRoute.from(
            payload: payload ?? "home_today",
            fallbackTaskID: taskID
        )
        if V2FeatureFlags.lifeOSFoundationV1Enabled {
            LifeOSFoundationRuntime.shared.router.handle(notificationRoute: route)
            return
        }
        LifeBoardNotificationRouteBus.shared.post(route: route)
    }

    private func foundationNavigationRoute(
        for request: UNNotificationRequest,
        actionIdentifier: String
    ) -> LifeBoardNotificationRoute? {
        let payload = request.content.userInfo[LifeBoardLocalNotificationRequest.UserInfoKey.route] as? String
        let taskID = (request.content.userInfo[LifeBoardLocalNotificationRequest.UserInfoKey.taskID] as? String)
            .flatMap(UUID.init(uuidString:))
        let payloadRoute = LifeBoardNotificationRoute.from(
            payload: payload ?? "home_today",
            fallbackTaskID: taskID
        )
        if actionIdentifier == UNNotificationDefaultActionIdentifier { return payloadRoute }
        guard let action = LifeBoardNotificationActionID(rawValue: actionIdentifier) else { return nil }
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
        if let command = FocusLiveActivityDeepLink.command(from: url) {
            _ = LifeOSFoundationRuntime.shared.handle(url: url)
            guard let container = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer else {
                LifeOSFoundationRuntime.shared.router.activeAlert = AppAlertState(
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
                        LifeOSFoundationRuntime.shared.router.activeAlert = AppAlertState(
                            title: "Focus command not applied",
                            message: "The session may already have ended. Open Plan to review its current state."
                        )
                    }
                }
            }
            return
        }
        if V2FeatureFlags.lifeOSFoundationV1Enabled,
           LifeOSFoundationRuntime.shared.handle(url: url) {
            return
        }
        guard let scheme = url.scheme?.lowercased(), ["lifeboard", "tasker"].contains(scheme) else { return }
        guard let host = url.host?.lowercased() else { return }
        let pathSegments = url.pathComponents.filter { $0 != "/" }

        if host == "chat" {
            let prompt = LifeBoardShortcutDeepLink.chatPrompt(from: url)
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

    private func installPersistentBootstrapObserver() {
        if let persistentBootstrapObserver {
            NotificationCenter.default.removeObserver(persistentBootstrapObserver)
        }
        persistentBootstrapObserver = NotificationCenter.default.addObserver(
            forName: .lifeboardPersistentBootstrapStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePersistentBootstrapStateChange()
            }
        }
    }

    private func handlePersistentBootstrapStateChange() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let rootMode = appDelegate.makeLaunchRootMode()

        switch rootMode {
        case .loading, .home:
            if let launchHostController = window?.rootViewController as? LifeBoardLaunchHostController {
                launchHostController.refreshPendingHomeController()
            } else {
                renderRoot(for: rootMode)
            }
        case .bootstrapFailure(let message):
            if let failureViewController = window?.rootViewController as? BootstrapFailureViewController {
                failureViewController.setWorking(false, hint: message)
            } else {
                renderRoot(for: .bootstrapFailure(message: message))
            }
        }
    }
}

/// Keeps seeded UI journeys deterministic without delaying or changing production launch.
private final class FoundationUITestSeedGateViewController: UIViewController {
    private let progress = UIActivityIndicatorView(style: .medium)
    private var installed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LifeBoardColorTokens.foundationCanvas
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

private final class LifeBoardLaunchHostController: UIViewController {
    private let resolveHomeRootController: () -> UIViewController?

    private var hasScheduledHomeAttach = false
    private var pendingHomeController: UIViewController?
    private var attachedHomeController: UIViewController?
    private let splashState = LifeBoardLaunchSplashState()
    private var splashHostController: UIHostingController<LifeBoardLaunchSplashView>?

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
        view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas

        let splashHostController = UIHostingController(rootView: LifeBoardLaunchSplashView(state: splashState))
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

        let firstFrameInterval = LifeBoardPerformanceTrace.begin("LaunchHostFirstFrame")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            LifeBoardPerformanceTrace.end(firstFrameInterval)
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

        let interval = LifeBoardPerformanceTrace.begin("LaunchHostAttachHome")
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
        LifeBoardPerformanceTrace.end(interval)
        attachedHomeController = homeController
        pendingHomeController = nil
        completeSplashOverAttachedHome()
    }

    private func completeSplashOverAttachedHome() {
        guard let splashHostController else { return }

        if UIAccessibility.isReduceMotionEnabled {
            fadeSplashOverAttachedHome(duration: 0.12, delay: 0)
            return
        }

        splashState.completeReveal()
        fadeSplashOverAttachedHome(
            duration: LifeBoardLaunchSplashMetrics.finalCrossfadeDuration,
            delay: max(
                LifeBoardLaunchSplashMetrics.revealDuration
                    - LifeBoardLaunchSplashMetrics.finalCrossfadeDuration,
                0
            ),
            splashHostController: splashHostController
        )
    }

    private func fadeSplashOverAttachedHome(
        duration: TimeInterval,
        delay: TimeInterval,
        splashHostController: UIHostingController<LifeBoardLaunchSplashView>? = nil
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
        _ splashHostController: UIHostingController<LifeBoardLaunchSplashView>
    ) {
        splashHostController.willMove(toParent: nil)
        splashHostController.view.removeFromSuperview()
        splashHostController.removeFromParent()
        if self.splashHostController === splashHostController {
            self.splashHostController = nil
        }
    }
}
