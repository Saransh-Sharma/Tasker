//
//  SceneDelegate.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import UserNotifications

// Import Clean Architecture components
// These types are defined in the Presentation layer

extension Notification.Name {
    static let taskerOpenFocusDeepLink = Notification.Name("TaskerOpenFocusDeepLink")
    static let taskerOpenChatDeepLink = Notification.Name("TaskerOpenChatDeepLink")
    static let taskerOpenHomeDeepLink = Notification.Name("TaskerOpenHomeDeepLink")
    static let taskerOpenInsightsDeepLink = Notification.Name("TaskerOpenInsightsDeepLink")
    static let taskerOpenTaskScopeDeepLink = Notification.Name("TaskerOpenTaskScopeDeepLink")
    static let taskerOpenTaskDetailDeepLink = Notification.Name("TaskerOpenTaskDetailDeepLink")
    static let taskerOpenQuickAddDeepLink = Notification.Name("TaskerOpenQuickAddDeepLink")
    static let taskerProcessWidgetActionCommand = Notification.Name("TaskerProcessWidgetActionCommand")
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private enum BootstrapFailureAction {
        case retrySync
        case recoverFromICloud
    }

    var window: UIWindow?
    private var persistentBootstrapObserver: NSObjectProtocol?


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
            message: AppDelegate.persistentBootstrapFailureMessage ?? "Tasker storage is unavailable. Please relaunch the app."
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
        }
    }

    /// Executes renderRoot.
    private func renderRoot(for rootMode: LaunchRootMode) {
        switch rootMode {
        case .loading, .home:
            if let launchHostController = window?.rootViewController as? TaskerLaunchHostController {
                launchHostController.refreshPendingHomeController()
                window?.makeKeyAndVisible()
                return
            }

            let launchHostController = TaskerLaunchHostController { [weak self] in
                self?.makeDeferredHomeRootController()
            }
            window?.rootViewController = launchHostController
            window?.makeKeyAndVisible()
        case .bootstrapFailure(let message):
            showBootstrapFailureRoot(message: message)
        }
    }

    private func makeDeferredHomeRootController() -> UIViewController? {
        let interval = TaskerPerformanceTrace.begin("SceneDeferredHomeAttach")
        defer { TaskerPerformanceTrace.end(interval) }

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return nil
        }
        guard case .ready = appDelegate.persistentBootstrapState else {
            return nil
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let homeViewController = storyboard.instantiateViewController(withIdentifier: "homeScreen") as? HomeViewController else {
            showBootstrapFailureRoot(message: "Tasker could not load the home screen.")
            return nil
        }

        guard PresentationDependencyContainer.shared.tryInject(into: homeViewController) else {
            showBootstrapFailureRoot(
                message: AppDelegate.persistentBootstrapFailureMessage ?? "Tasker could not initialize dependencies."
            )
            return nil
        }

        return UINavigationController(rootViewController: homeViewController)
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
    }

    /// Executes sceneWillResignActive.
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        Task { @MainActor in
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "scene_will_resign_active")
        }
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
        }
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_did_enter_background")
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncomingURL(url)
    }

    func handleNotificationLaunch(
        request: UNNotificationRequest,
        actionIdentifier: String = UNNotificationDefaultActionIdentifier
    ) {
        if let actionHandler = TaskerNotificationRuntime.actionHandler {
            actionHandler.handleAction(identifier: actionIdentifier, request: request)
            return
        }

        postFallbackNotificationRoute(for: request)
    }

    func postFallbackNotificationRoute(for request: UNNotificationRequest) {
        let payload = request.content.userInfo[TaskerLocalNotificationRequest.UserInfoKey.route] as? String
        let taskIDRaw = request.content.userInfo[TaskerLocalNotificationRequest.UserInfoKey.taskID] as? String
        let taskID = taskIDRaw.flatMap(UUID.init(uuidString:))
        let route = TaskerNotificationRoute.from(
            payload: payload ?? "home_today",
            fallbackTaskID: taskID
        )
        TaskerNotificationRouteBus.shared.post(route: route)
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "tasker" else { return }
        guard let host = url.host?.lowercased() else { return }
        let pathSegments = url.pathComponents.filter { $0 != "/" }

        if host == "chat" {
            let prompt = TaskerShortcutDeepLink.chatPrompt(from: url)
            var userInfo: [String: String] = [:]
            if let prompt {
                userInfo["prompt"] = prompt
            }
            NotificationCenter.default.post(
                name: .taskerOpenChatDeepLink,
                object: nil,
                userInfo: userInfo
            )
            return
        }
        if host == "focus" {
            NotificationCenter.default.post(name: .taskerOpenFocusDeepLink, object: nil)
            return
        }
        if host == "home" {
            NotificationCenter.default.post(name: .taskerOpenHomeDeepLink, object: nil)
            return
        }
        if host == "insights" {
            NotificationCenter.default.post(name: .taskerOpenInsightsDeepLink, object: nil)
            return
        }
        if host == "quickadd" {
            NotificationCenter.default.post(name: .taskerOpenQuickAddDeepLink, object: nil)
            return
        }
        if host == "tasks" {
            guard let scope = pathSegments.first?.lowercased() else { return }
            if scope == "project",
               pathSegments.count > 1,
               let projectID = UUID(uuidString: pathSegments[1]) {
                NotificationCenter.default.post(
                    name: .taskerOpenTaskScopeDeepLink,
                    object: nil,
                    userInfo: [
                        "scope": "project",
                        "projectID": projectID.uuidString
                    ]
                )
                NotificationCenter.default.post(name: .taskerProcessWidgetActionCommand, object: nil)
                return
            }
            let allowedScopes: Set<String> = ["today", "upcoming", "overdue"]
            guard allowedScopes.contains(scope) else { return }
            NotificationCenter.default.post(
                name: .taskerOpenTaskScopeDeepLink,
                object: nil,
                userInfo: ["scope": scope]
            )
            NotificationCenter.default.post(name: .taskerProcessWidgetActionCommand, object: nil)
            return
        }
        if host == "task",
           let firstSegment = pathSegments.first,
           let taskID = UUID(uuidString: firstSegment) {
            NotificationCenter.default.post(
                name: .taskerOpenTaskDetailDeepLink,
                object: nil,
                userInfo: ["taskID": taskID.uuidString]
            )
            NotificationCenter.default.post(name: .taskerProcessWidgetActionCommand, object: nil)
            return
        }
    }

    private func installPersistentBootstrapObserver() {
        if let persistentBootstrapObserver {
            NotificationCenter.default.removeObserver(persistentBootstrapObserver)
        }
        persistentBootstrapObserver = NotificationCenter.default.addObserver(
            forName: .taskerPersistentBootstrapStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePersistentBootstrapStateChange()
        }
    }

    private func handlePersistentBootstrapStateChange() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let rootMode = appDelegate.makeLaunchRootMode()

        switch rootMode {
        case .loading, .home:
            if let launchHostController = window?.rootViewController as? TaskerLaunchHostController {
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

private final class TaskerLaunchHostController: UIViewController {
    private let resolveHomeRootController: () -> UIViewController?

    private let canvasView = UIView()
    private let chromePlaceholderView = UIView()
    private let foredropPlaceholderView = UIView()
    private let skeletonStack = UIStackView()
    private let gradientLayer = CAGradientLayer()

    private var hasScheduledHomeAttach = false
    private var pendingHomeController: UIViewController?
    private var attachedHomeController: UIViewController?

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
        setupSkeleton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleHomeAttachIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = canvasView.bounds
        attachHomeIfPossible()
    }

    private func setupSkeleton() {
        view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        chromePlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        foredropPlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        skeletonStack.translatesAutoresizingMaskIntoConstraints = false

        gradientLayer.colors = [
            TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas.cgColor,
            TaskerThemeManager.shared.currentTheme.tokens.color.overlayScrim.withAlphaComponent(0.08).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        canvasView.layer.insertSublayer(gradientLayer, at: 0)

        chromePlaceholderView.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.surfaceSecondary
            .withAlphaComponent(0.78)
        chromePlaceholderView.layer.cornerRadius = 22

        foredropPlaceholderView.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.surfaceTertiary
        foredropPlaceholderView.layer.cornerRadius = 28

        skeletonStack.axis = .vertical
        skeletonStack.spacing = 20
        skeletonStack.alignment = .fill
        skeletonStack.addArrangedSubview(chromePlaceholderView)
        skeletonStack.addArrangedSubview(foredropPlaceholderView)

        view.addSubview(canvasView)
        view.addSubview(skeletonStack)

        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            skeletonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            skeletonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            skeletonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            skeletonStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            chromePlaceholderView.heightAnchor.constraint(equalToConstant: 112),
            foredropPlaceholderView.heightAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
    }

    private func scheduleHomeAttachIfNeeded() {
        guard hasScheduledHomeAttach == false else { return }
        hasScheduledHomeAttach = true

        let firstFrameInterval = TaskerPerformanceTrace.begin("LaunchHostFirstFrame")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            TaskerPerformanceTrace.end(firstFrameInterval)
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

        let interval = TaskerPerformanceTrace.begin("LaunchHostAttachHome")
        addChild(homeController)
        homeController.view.translatesAutoresizingMaskIntoConstraints = false
        homeController.view.alpha = 1
        view.addSubview(homeController.view)
        NSLayoutConstraint.activate([
            homeController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            homeController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            homeController.view.topAnchor.constraint(equalTo: view.topAnchor),
            homeController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        homeController.didMove(toParent: self)
        skeletonStack.alpha = 0
        TaskerPerformanceTrace.end(interval)
        skeletonStack.removeFromSuperview()
        attachedHomeController = homeController
        pendingHomeController = nil
    }
}
