//
//  HomeBottomBarState.swift
//  Tasker
//

import Observation
import CoreGraphics
import Foundation

@MainActor
@Observable
final class HomeBottomBarState {
    var selectedItem: HomeBottomBarItem?
    var isMinimized = false

    private let jitterThreshold: CGFloat = 6
    private let minimizeThreshold: CGFloat = 24
    private let restoreThreshold: CGFloat = 12
    private let nearTopThreshold: CGFloat = 40
    private let idleRevealDelayNanoseconds: UInt64 = 400_000_000

    private var lastOffsetY: CGFloat?
    private var cumulativeDownward: CGFloat = 0
    private var cumulativeUpward: CGFloat = 0
    private var idleRevealTask: Task<Void, Never>?

    /// Executes select.
    func select(_ item: HomeBottomBarItem) {
        selectedItem = item
    }

    /// Executes handleScrollOffsetChange.
    func handleScrollOffsetChange(_ newOffset: CGFloat) {
        guard newOffset.isFinite else { return }

        if newOffset < nearTopThreshold {
            revealCluster()
            resetAccumulation()
            cancelIdleReveal()
            lastOffsetY = newOffset
            return
        }

        guard let lastOffsetY else {
            self.lastOffsetY = newOffset
            return
        }

        let delta = newOffset - lastOffsetY
        self.lastOffsetY = newOffset

        if delta > 0 {
            scheduleIdleReveal()
        } else if delta < 0 {
            cancelIdleReveal()
        }

        guard abs(delta) >= jitterThreshold else { return }

        if delta > 0 {
            cumulativeDownward += delta
            cumulativeUpward = 0
            if cumulativeDownward >= minimizeThreshold {
                isMinimized = true
                cumulativeDownward = 0
            }
            return
        }

        cumulativeUpward += abs(delta)
        cumulativeDownward = 0
        if cumulativeUpward >= restoreThreshold {
            revealCluster()
            cumulativeUpward = 0
        }
    }

    private func revealCluster() {
        isMinimized = false
    }

    private func resetAccumulation() {
        cumulativeDownward = 0
        cumulativeUpward = 0
    }

    private func scheduleIdleReveal() {
        cancelIdleReveal()
        let delay = idleRevealDelayNanoseconds
        idleRevealTask = Task { [weak self, delay] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await self?.revealAfterIdleTimeout()
        }
    }

    private func cancelIdleReveal() {
        idleRevealTask?.cancel()
        idleRevealTask = nil
    }

    private func revealAfterIdleTimeout() {
        revealCluster()
        resetAccumulation()
        idleRevealTask = nil
    }
}
