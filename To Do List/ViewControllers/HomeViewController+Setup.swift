//
//  HomeViewController+Setup.swift
//  Tasker
//
//  Extension to add Clean Architecture properties to HomeViewController
//

import UIKit
import Combine

extension HomeViewController {
    
    // MARK: - Associated Keys for Runtime Properties
    
    private struct AssociatedKeys {
        static var viewModel = "viewModel"
        static var cancellables = "cancellables"
    }
    
    // MARK: - Combine Properties
    
    /// Combine cancellables for subscriptions
    var cancellables: Set<AnyCancellable> {
        get {
            if let existing = objc_getAssociatedObject(self, &AssociatedKeys.cancellables) as? Set<AnyCancellable> {
                return existing
            }
            let new = Set<AnyCancellable>()
            objc_setAssociatedObject(self, &AssociatedKeys.cancellables, new, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return new
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.cancellables, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Setup Method
    
    /// Call this in viewDidLoad to setup Clean Architecture
    func setupCleanArchitectureIfAvailable() {
        // Try to get injected ViewModel
        if viewModel == nil {
            // Try to inject from container
            PresentationDependencyContainer.shared.inject(into: self)
        }
        
        // Setup Clean Architecture if ViewModel is available
        if viewModel != nil {
            setupCleanArchitecture()
        } else {
            print("⚠️ HomeViewController: Running in legacy mode with migration adapter")
        }
    }
}
