//
//  HomeBottomBarState.swift
//  Tasker
//

import Observation
import CoreGraphics

@MainActor
@Observable
final class HomeBottomBarState {
    var selectedItem: HomeBottomBarItem?
    var isMinimized = false

    private let minimizeThreshold: CGFloat = 18
    private let restoreThreshold: CGFloat = -12
    private let jitterThreshold: CGFloat = 4

    func select(_ item: HomeBottomBarItem) {
        selectedItem = item
    }

    func updateMinimizeState(fromScrollDelta delta: CGFloat) {
        guard delta.isFinite else { return }
        guard abs(delta) >= jitterThreshold else { return }

        if delta > minimizeThreshold {
            isMinimized = true
        } else if delta < restoreThreshold {
            isMinimized = false
        }
    }
}
