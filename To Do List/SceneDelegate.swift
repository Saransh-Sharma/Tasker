//
//  SceneDelegate.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import FluentUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Create window programmatically
        window = UIWindow(windowScene: windowScene)
        
        // Create navigation controller
        let navigationController = NavigationController()
        
        // Initialize coordinator with dependency container
        appCoordinator = AppCoordinator(
            navigationController: navigationController,
            dependencyContainer: DependencyContainer.shared
        )
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        // Start the app flow (will choose between Legacy and Liquid Glass UI)
        appCoordinator?.start()
        
        // Add shake gesture for debug menu in development
        #if DEBUG
        addShakeGestureForDebugMenu()
        #endif
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    // MARK: - Debug Menu Support
    
    #if DEBUG
    private func addShakeGestureForDebugMenu() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showDebugMenu),
            name: UIDevice.deviceDidShakeNotification,
            object: nil
        )
    }
    
    @objc private func showDebugMenu() {
        guard FeatureFlags.enableDebugMenu else { return }
        
        let debugVC = LGDebugMenuViewController()
        let nav = UINavigationController(rootViewController: debugVC)
        window?.rootViewController?.present(nav, animated: true)
    }
    #endif


}

// MARK: - Shake Detection Extension
extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name("DeviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

