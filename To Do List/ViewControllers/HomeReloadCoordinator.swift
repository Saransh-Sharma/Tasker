import Foundation

@MainActor
protocol HomeReloadCoordinatorDelegate: AnyObject {
    func homeReloadCoordinatorDidReceiveTaskMutation(_ mutation: HomeTaskMutationReloadEvent)
    func homeReloadCoordinatorRecordSearchMutation()
    func homeReloadCoordinatorRefreshCharts(reason: HomeTaskMutationEvent?)
    func homeReloadCoordinatorRefreshPersistentSyncMode()
    func homeReloadCoordinatorRefreshWeeklySummary()
    func homeReloadCoordinatorRefreshCalendarContext(reason: String)
}

enum HomeReloadEvent {
    case taskMutation(HomeTaskMutationReloadEvent)
    case persistentSyncModeChanged
    case appDidBecomeActive
    case significantTimeChanged
    case workspacePreferencesChanged
}

struct HomeTaskMutationReloadEvent: Equatable {
    let reason: HomeTaskMutationEvent?
    let source: String?
    let taskID: UUID?
    let shouldRefreshSearch: Bool

    init(
        reason: HomeTaskMutationEvent?,
        source: String?,
        taskID: UUID?,
        shouldRefreshSearch: Bool
    ) {
        self.reason = reason
        self.source = source
        self.taskID = taskID
        self.shouldRefreshSearch = shouldRefreshSearch
    }

    init(notification: Notification) {
        let payload = HomeTaskMutationPayload(notification: notification)
        let reason = payload?.reason
            ?? (notification.userInfo?["reason"] as? String).flatMap(HomeTaskMutationEvent.init(rawValue:))
        self.init(
            reason: reason,
            source: payload?.source ?? notification.userInfo?["source"] as? String,
            taskID: payload?.taskID ?? (notification.userInfo?["taskID"] as? String).flatMap(UUID.init(uuidString:)),
            shouldRefreshSearch: payload.map(HomeSearchInvalidationPolicy.shouldRefreshSearch(for:)) ?? false
        )
    }
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

    func handle(_ event: HomeReloadEvent) {
        switch event {
        case .taskMutation(let mutation):
            handleHomeTaskMutation(mutation)
        case .persistentSyncModeChanged:
            delegate?.homeReloadCoordinatorRefreshPersistentSyncMode()
        case .appDidBecomeActive:
            delegate?.homeReloadCoordinatorRefreshWeeklySummary()
            delegate?.homeReloadCoordinatorRefreshCalendarContext(reason: "app_did_become_active")
        case .significantTimeChanged:
            delegate?.homeReloadCoordinatorRefreshWeeklySummary()
            delegate?.homeReloadCoordinatorRefreshCalendarContext(reason: "significant_time_change")
        case .workspacePreferencesChanged:
            delegate?.homeReloadCoordinatorRefreshWeeklySummary()
            delegate?.homeReloadCoordinatorRefreshCalendarContext(reason: "workspace_preferences_changed")
        }
    }

    func handleHomeTaskMutation(_ notification: Notification) {
        handleHomeTaskMutation(HomeTaskMutationReloadEvent(notification: notification))
    }

    func handleHomeTaskMutation(_ mutation: HomeTaskMutationReloadEvent) {
        delegate?.homeReloadCoordinatorDidReceiveTaskMutation(mutation)

        if mutation.shouldRefreshSearch {
            delegate?.homeReloadCoordinatorRecordSearchMutation()
        }

        scheduleChartRefresh(reason: mutation.reason)
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

extension HomeReloadEvent {
    static func fromTimeOrWorkspaceNotification(_ notification: Notification) -> HomeReloadEvent {
        if notification.name == TaskerWorkspacePreferencesStore.didChangeNotification {
            return .workspacePreferencesChanged
        }
        return .significantTimeChanged
    }
}
