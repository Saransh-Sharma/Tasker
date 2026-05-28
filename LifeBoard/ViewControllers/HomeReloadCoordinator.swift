import Combine
import Foundation
import UIKit

@MainActor
protocol HomeReloadCoordinatorDelegate: AnyObject {
    func homeReloadCoordinatorDidReceiveTaskMutation(_ mutation: HomeTaskMutationReloadEvent)
    func homeReloadCoordinatorRecordSearchMutation()
    func homeReloadCoordinatorRefreshInsights(reason: HomeTaskMutationEvent?)
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
    case homeHabitMutation
    case gamificationLedgerMutation
}

@MainActor
protocol HomeReloadEventAdapterDelegate: AnyObject {
    func homeReloadEventAdapter(
        _ adapter: HomeReloadEventAdapter,
        didReceive event: HomeReloadEvent
    )
}

@MainActor
final class HomeReloadEventAdapter {
    weak var delegate: HomeReloadEventAdapterDelegate?

    private let notificationCenter: NotificationCenter
    private var cancellables = Set<AnyCancellable>()

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func start() {
        stop()

        notificationCenter.publisher(for: .homeTaskMutation)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.emit(.taskMutation(HomeTaskMutationReloadEvent(notification: notification)))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardPersistentSyncModeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.persistentSyncModeChanged)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.appDidBecomeActive)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIApplication.significantTimeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.significantTimeChanged)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: LifeBoardWorkspacePreferencesStore.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.workspacePreferencesChanged)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .homeHabitMutation)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.homeHabitMutation)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .gamificationLedgerDidMutate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.gamificationLedgerMutation)
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
    }

    private func emit(_ event: HomeReloadEvent) {
        delegate?.homeReloadEventAdapter(self, didReceive: event)
    }
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
    private var pendingInsightsRefreshTask: Task<Void, Never>?

    init(
        delegate: HomeReloadCoordinatorDelegate? = nil,
        insightsRefreshDebounceSeconds: TimeInterval = 0.12
    ) {
        self.delegate = delegate
        self.debounceNanoseconds = UInt64(max(0, insightsRefreshDebounceSeconds) * 1_000_000_000)
    }

    deinit {
        pendingInsightsRefreshTask?.cancel()
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
        case .homeHabitMutation:
            delegate?.homeReloadCoordinatorRefreshWeeklySummary()
            delegate?.homeReloadCoordinatorRefreshCalendarContext(reason: "home_habit_mutation")
        case .gamificationLedgerMutation:
            delegate?.homeReloadCoordinatorRefreshWeeklySummary()
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

        // HomeViewModel still owns task-list reload batching. The coordinator owns
        // shell/search/insights side effects until those paths are consolidated.
        scheduleInsightsRefresh(reason: mutation.reason)
    }

    func refreshInsightsImmediately(reason: HomeTaskMutationEvent?) {
        pendingInsightsRefreshTask?.cancel()
        pendingInsightsRefreshTask = nil
        delegate?.homeReloadCoordinatorRefreshInsights(reason: reason)
    }

    func cancelPendingReloads() {
        pendingInsightsRefreshTask?.cancel()
        pendingInsightsRefreshTask = nil
    }

    private func scheduleInsightsRefresh(reason: HomeTaskMutationEvent?) {
        pendingInsightsRefreshTask?.cancel()
        pendingInsightsRefreshTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }
            LifeBoardPerformanceTrace.event("HomeTaskMutationInsightsRefreshDebounced")
            delegate?.homeReloadCoordinatorRefreshInsights(reason: reason)
            pendingInsightsRefreshTask = nil
        }
    }
}

extension HomeReloadEvent {
    static func fromTimeOrWorkspaceNotification(_ notification: Notification) -> HomeReloadEvent {
        if notification.name == LifeBoardWorkspacePreferencesStore.didChangeNotification {
            return .workspacePreferencesChanged
        }
        return .significantTimeChanged
    }
}
