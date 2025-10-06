//
//  HomeViewController+ForedropState.swift
//  To Do List
//
//  Created by Cascade on 30/09/25.
//  Copyright 2025 saransh1337. All rights reserved.
//
//  Extension for foredrop state management integration
//

import UIKit

extension HomeViewController {
    
    // MARK: - Foredrop State Manager Initialization
    
    /// Initializes the foredrop state manager with all required views
    /// Call this after all views have been set up in viewDidLoad
    func initializeForedropStateManager() {
        // Phase 7: Use chartScrollContainer (horizontally scrollable) instead of old swiftUIChartContainer
        guard let chartsContainer = chartScrollContainer else {
            print("⚠️ ForedropStateManager: chartScrollContainer not ready, will retry after layout")
            // Retry after a short delay to ensure views are laid out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.initializeForedropStateManager()
            }
            return
        }

        foredropStateManager = ForedropStateManager(
            foredropContainer: foredropContainer,
            calendar: calendar,
            chartsContainer: chartsContainer,
            parentView: view,
            navigationController: navigationController
        )

        print("✅ ForedropStateManager initialized with chartScrollContainer (Phase 7)")
    }
    
    // MARK: - Orientation Change Handling
    
    /// Override to handle orientation changes
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Notify state manager about orientation change
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.foredropStateManager?.handleOrientationChange()
        }
    }
}
