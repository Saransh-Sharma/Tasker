//
//  HomeBottomBarState.swift
//  Tasker
//

import Observation
import Foundation

@MainActor
@Observable
final class HomeBottomBarState {
    var selectedItem: HomeBottomBarItem? = .home
    var isMinimized = false

    /// Executes select.
    func select(_ item: HomeBottomBarItem) {
        selectedItem = item
    }

    func handleChromeStateChange(_ state: HomeScrollChromeState) {
        switch state {
        case .nearTop, .expanded, .idle:
            isMinimized = false
        case .collapsed:
            isMinimized = true
        }
    }
}
