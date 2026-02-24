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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

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

        switch rootMode {
        case .home:
            _ = LLMRuntimeCoordinator.shared
            // Load HomeViewController from storyboard
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let homeViewController = storyboard.instantiateViewController(withIdentifier: "homeScreen") as? HomeViewController else {
                showBootstrapFailureRoot(message: "Tasker could not load the home screen.")
                return
            }

            // Inject dependencies safely. If setup failed, fall back to a non-crashing bootstrap failure root.
            guard PresentationDependencyContainer.shared.tryInject(into: homeViewController) else {
                showBootstrapFailureRoot(
                    message: AppDelegate.persistentBootstrapFailureMessage ?? "Tasker could not initialize dependencies."
                )
                return
            }

            let navigationController = UINavigationController(rootViewController: homeViewController)

            // Set as root view controller
            window?.rootViewController = navigationController
            window?.makeKeyAndVisible()

        case .bootstrapFailure(let message):
            showBootstrapFailureRoot(message: message)
        }
    }

    /// Executes showBootstrapFailureRoot.
    private func showBootstrapFailureRoot(message: String) {
        let failureViewController = BootstrapFailureViewController(message: message)
        window?.rootViewController = failureViewController
        window?.makeKeyAndVisible()
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
    }

    /// Executes sceneDidEnterBackground.
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        chatPrewarmTask?.cancel()
        chatPrewarmTask = nil
    }


}
