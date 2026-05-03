import Foundation

@MainActor
protocol HomeReloadCoordinatorDelegate: AnyObject {
    func homeReloadCoordinatorRecordSearchMutation()
    func homeReloadCoordinatorRefreshCharts(reason: HomeTaskMutationEvent?)
}

@MainActor
final class HomeReloadCoordinator {
    weak var delegate: HomeReloadCoordinatorDelegate?

    private let debounceNanoseconds: UInt64
    private var pendingChartRefreshTask: Task<Void, Never>?

    init(
        delegate: HomeReloadCoordinatorDelegate? = nil,
        chartRefreshDebounceSeconds: TimeInterval = 0.12
    ) {
        self.delegate = delegate
        self.debounceNanoseconds = UInt64(max(0, chartRefreshDebounceSeconds) * 1_000_000_000)
    }

    deinit {
        pendingChartRefreshTask?.cancel()
    }

    func handleHomeTaskMutation(_ notification: Notification) {
        let payload = HomeTaskMutationPayload(notification: notification)
        let reason = payload?.reason
            ?? (notification.userInfo?["reason"] as? String).flatMap(HomeTaskMutationEvent.init(rawValue:))

        if let payload, HomeSearchInvalidationPolicy.shouldRefreshSearch(for: payload) {
            delegate?.homeReloadCoordinatorRecordSearchMutation()
        }

        scheduleChartRefresh(reason: reason)
    }

    func refreshChartsImmediately(reason: HomeTaskMutationEvent?) {
        pendingChartRefreshTask?.cancel()
        pendingChartRefreshTask = nil
        delegate?.homeReloadCoordinatorRefreshCharts(reason: reason)
    }

    func cancelPendingReloads() {
        pendingChartRefreshTask?.cancel()
        pendingChartRefreshTask = nil
    }

    private func scheduleChartRefresh(reason: HomeTaskMutationEvent?) {
        pendingChartRefreshTask?.cancel()
        pendingChartRefreshTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }
            TaskerPerformanceTrace.event("HomeTaskMutationChartRefreshDebounced")
            delegate?.homeReloadCoordinatorRefreshCharts(reason: reason)
            pendingChartRefreshTask = nil
        }
    }
}
