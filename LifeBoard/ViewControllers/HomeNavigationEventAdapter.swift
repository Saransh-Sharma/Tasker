import Combine
import Foundation

@MainActor
protocol HomeNavigationEventAdapterDelegate: AnyObject {
    func homeNavigationEventAdapter(
        _ adapter: HomeNavigationEventAdapter,
        didReceive intent: HomeNavigationIntent
    )
}

@MainActor
final class HomeNavigationEventAdapter {
    weak var delegate: HomeNavigationEventAdapterDelegate?

    private let notificationCenter: NotificationCenter
    private var cancellables = Set<AnyCancellable>()

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func start() {
        stop()

        notificationCenter.publisher(for: TaskerNotificationRouteBus.routeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let payload = notification.userInfo?["payload"] as? String else { return }
                let route = TaskerNotificationRoute.from(payload: payload, fallbackTaskID: nil)
                delegate?.homeNavigationEventAdapter(self, didReceive: .notificationRoute(route))
                _ = TaskerNotificationRouteBus.shared.consumePendingRoute()
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenFocusDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.focusDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenChatDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let prompt = (notification.userInfo?["prompt"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self?.emit(.chatDeepLink(prompt: prompt))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenHomeDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.emit(.homeDeepLink(notice: notification.userInfo?["notice"] as? String))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenInsightsDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.insightsDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenTaskScopeDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let scope = (notification.userInfo?["scope"] as? String)?.lowercased() ?? "today"
                let projectID = (notification.userInfo?["projectID"] as? String).flatMap(UUID.init(uuidString:))
                self?.emit(.taskScopeDeepLink(scope: scope, projectID: projectID))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenTaskDetailDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let taskIDRaw = notification.userInfo?["taskID"] as? String,
                      let taskID = UUID(uuidString: taskIDRaw) else {
                    return
                }
                self?.emit(.taskDetailDeepLink(taskID: taskID))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenHabitBoardDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.habitBoardDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenHabitLibraryDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.habitLibraryDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenHabitDetailDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let habitIDRaw = notification.userInfo?["habitID"] as? String,
                      let habitID = UUID(uuidString: habitIDRaw) else {
                    return
                }
                self?.emit(.habitDetailDeepLink(habitID: habitID))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenQuickAddDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.quickAddDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenCalendarScheduleDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.calendarScheduleDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenCalendarChooserDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.calendarChooserDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenWeeklyPlannerDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.weeklyPlannerDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerOpenWeeklyReviewDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.weeklyReviewDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerProcessWidgetActionCommand)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.widgetActionCommand)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .taskerPersistentSyncModeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.persistentSyncModeChanged)
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
    }

    private func emit(_ intent: HomeNavigationIntent) {
        delegate?.homeNavigationEventAdapter(self, didReceive: intent)
    }
}
