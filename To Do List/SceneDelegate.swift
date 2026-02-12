//
//  SceneDelegate.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import FluentUI

// Import Clean Architecture components
// These types are defined in the Presentation layer

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Create window programmatically to use FluentUI NavigationController
        window = UIWindow(windowScene: windowScene)
        
        // Load HomeViewController from storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let homeViewController = storyboard.instantiateViewController(withIdentifier: "homeScreen") as! HomeViewController
        
        // Inject dependencies using typed APIs (no reflection).
        DependencyContainer.shared.inject(into: homeViewController)
        PresentationDependencyContainer.shared.inject(into: homeViewController)
        print("HOME_DI scene.inject viewModel=\(homeViewController.viewModel != nil)")
        
        // Embed in FluentUI NavigationController
        let navigationController = NavigationController(rootViewController: homeViewController)

        // Set FluentUI custom navigation bar color to match app's primary color immediately on launch
        let themeColors = TaskerThemeManager.shared.currentTheme.tokens.color
        homeViewController.navigationItem.fluentConfiguration.customNavigationBarColor = themeColors.accentPrimary
        homeViewController.navigationItem.fluentConfiguration.navigationBarStyle = .custom

        // Set as root view controller
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
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


}
