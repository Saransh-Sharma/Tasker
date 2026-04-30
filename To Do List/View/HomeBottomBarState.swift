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
    private var lastPersistentItem: HomeBottomBarItem = .home

    /// Executes select.
    func select(_ item: HomeBottomBarItem) {
        selectedItem = item
        if item != .create {
            lastPersistentItem = item
        }
    }

    func selectIndex(_ index: Int) {
        guard HomeBottomBarItem.visibleAnimatedItems.indices.contains(index) else { return }
        let item = HomeBottomBarItem.visibleAnimatedItems[index]
        select(item)
    }

    func index(for item: HomeBottomBarItem?) -> Int {
        guard let item,
              let index = HomeBottomBarItem.visibleAnimatedItems.firstIndex(of: item) else {
            return HomeBottomBarItem.visibleAnimatedItems.firstIndex(of: .home) ?? 0
        }
        return index
    }

    var selectedIndex: Int {
        index(for: selectedItem)
    }

    func selectMomentaryCreate() {
        selectedItem = .create
    }

    func restoreAfterMomentaryCreate() {
        selectedItem = lastPersistentItem
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
