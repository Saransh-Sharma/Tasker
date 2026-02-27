//
//  SceneDelegate.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

// Import Clean Architecture components
// These types are defined in the Presentation layer

extension Notification.Name {
    static let taskerOpenFocusDeepLink = Notification.Name("TaskerOpenFocusDeepLink")
    static let taskerOpenHomeDeepLink = Notification.Name("TaskerOpenHomeDeepLink")
    static let taskerOpenInsightsDeepLink = Notification.Name("TaskerOpenInsightsDeepLink")
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private enum BootstrapFailureAction {
        case retrySync
        case recoverFromICloud
    }

    var window: UIWindow?
    private var chatPrewarmTask: Task<Void, Never>?


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

        if let deepLinkURL = connectionOptions.urlContexts.first?.url {
            DispatchQueue.main.async { [weak self] in
                self?.handleIncomingURL(deepLinkURL)
            }
        }
    }

    /// Executes renderRoot.
    private func renderRoot(for rootMode: LaunchRootMode) {
        switch rootMode {
        case .home:
            _ = LLMRuntimeCoordinator.shared
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let homeViewController = storyboard.instantiateViewController(withIdentifier: "homeScreen") as? HomeViewController else {
                showBootstrapFailureRoot(message: "Tasker could not load the home screen.")
                return
            }

            guard PresentationDependencyContainer.shared.tryInject(into: homeViewController) else {
                showBootstrapFailureRoot(
                    message: AppDelegate.persistentBootstrapFailureMessage ?? "Tasker could not initialize dependencies."
                )
                return
            }

            let navigationController = UINavigationController(rootViewController: homeViewController)
            window?.rootViewController = navigationController
            window?.makeKeyAndVisible()

        case .bootstrapFailure(let message):
            showBootstrapFailureRoot(message: message)
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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let mode: LaunchRootMode
            switch action {
            case .retrySync:
                mode = appDelegate.retryPersistentStoreBootstrap()
            case .recoverFromICloud:
                mode = appDelegate.recoverFromCloudAuthoritativeReset()
            }

            DispatchQueue.main.async {
                self?.renderRoot(for: mode)
                if case .bootstrapFailure(let message) = mode,
                   let failureVC = self?.window?.rootViewController as? BootstrapFailureViewController {
                    failureVC.setWorking(false, hint: message)
                }
            }
        }
    }

    /// Executes sceneDidDisconnect.
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    /// Executes sceneDidBecomeActive.
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_did_become_active")
        chatPrewarmTask?.cancel()
        chatPrewarmTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await LLMRuntimeCoordinator.shared.prewarmIfEligibleCurrentModel()
        }
    }

    /// Executes sceneWillResignActive.
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        chatPrewarmTask?.cancel()
        chatPrewarmTask = nil
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
        chatPrewarmTask?.cancel()
        chatPrewarmTask = nil
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: "scene_did_enter_background")
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncomingURL(url)
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "tasker" else { return }
        guard let host = url.host?.lowercased() else { return }

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
        }
    }


}
