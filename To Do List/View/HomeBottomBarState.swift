//
//  HomeBottomBarState.swift
//  Tasker
//

import Observation
import CoreGraphics
import Foundation

@MainActor
private final class IdleRevealScheduler {
    typealias TimeoutHandler = @MainActor () -> Void

    private let delayNanoseconds: UInt64
    private let onTimeout: TimeoutHandler
    private var deadlineNanoseconds: UInt64?
    private var workerTask: Task<Void, Never>?
#if DEBUG
    private(set) var workerStartCount = 0
#endif

    init(delayNanoseconds: UInt64, onTimeout: @escaping TimeoutHandler) {
        self.delayNanoseconds = delayNanoseconds
        self.onTimeout = onTimeout
    }

    func ingestScroll(
        deltaY: CGFloat,
        timestampNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) {
        guard deltaY > 0 else { return }
        deadlineNanoseconds = timestampNanoseconds &+ delayNanoseconds
        guard workerTask == nil else { return }

#if DEBUG
        workerStartCount += 1
#endif

        workerTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func cancel() {
        workerTask?.cancel()
        workerTask = nil
        deadlineNanoseconds = nil
    }

    func reset() {
        cancel()
    }

    private func runLoop() async {
        while !Task.isCancelled {
            guard let deadlineNanoseconds else {
                workerTask = nil
                return
            }

            let now = DispatchTime.now().uptimeNanoseconds
            if now >= deadlineNanoseconds {
                self.deadlineNanoseconds = nil
                await onTimeout()
                if self.deadlineNanoseconds == nil {
                    workerTask = nil
                    return
                }
                continue
            }

            do {
                try await Task.sleep(nanoseconds: deadlineNanoseconds &- now)
            } catch {
                workerTask = nil
                return
            }
        }
        workerTask = nil
    }
}

@MainActor
@Observable
final class HomeBottomBarState {
    var selectedItem: HomeBottomBarItem? = .home
    var isMinimized = false

    @ObservationIgnored private let jitterThreshold: CGFloat = 6
    @ObservationIgnored private let minimizeThreshold: CGFloat = 24
    @ObservationIgnored private let restoreThreshold: CGFloat = 12
    @ObservationIgnored private let nearTopThreshold: CGFloat = 40
    @ObservationIgnored private let idleRevealDelayNanoseconds: UInt64 = 400_000_000

    @ObservationIgnored private var lastOffsetY: CGFloat?
    @ObservationIgnored private var cumulativeDownward: CGFloat = 0
    @ObservationIgnored private var cumulativeUpward: CGFloat = 0
    @ObservationIgnored private var idleRevealTask: Task<Void, Never>?
    @ObservationIgnored private lazy var idleRevealScheduler = IdleRevealScheduler(
        delayNanoseconds: idleRevealDelayNanoseconds
    ) { [weak self] in
        self?.revealAfterIdleTimeout()
    }

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
            idleRevealScheduler.reset()
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
            if V2FeatureFlags.iPadPerfBottomBarSchedulerV2Enabled {
                idleRevealScheduler.ingestScroll(deltaY: delta)
            } else {
                scheduleIdleReveal()
            }
        } else if delta < 0 {
            if V2FeatureFlags.iPadPerfBottomBarSchedulerV2Enabled == false {
                cancelIdleReveal()
            }
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
        logWarning(
            event: "bottomBarIdleReveal",
            message: "Revealed home bottom bar after idle timeout",
            fields: [:]
        )
        revealCluster()
        resetAccumulation()
        idleRevealTask = nil
    }

#if DEBUG
    var idleRevealSchedulerWorkerStartsForTesting: Int {
        idleRevealScheduler.workerStartCount
    }
#endif
}
