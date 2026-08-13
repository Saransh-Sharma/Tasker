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

        notificationCenter.publisher(for: NotificationRouteBus.routeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let payload = notification.userInfo?["payload"] as? String else { return }
                let route = NotificationRoute.from(payload: payload, fallbackTaskID: nil)
                _ = NotificationRouteBus.shared.consumePendingRoute()
                delegate?.homeNavigationEventAdapter(self, didReceive: .notificationRoute(route))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenFocusDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.focusDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenChatDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let prompt = (notification.userInfo?["prompt"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self?.emit(.chatDeepLink(prompt: prompt))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenHomeDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.emit(.homeDeepLink(notice: notification.userInfo?["notice"] as? String))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenInsightsDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.insightsDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenTaskScopeDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let scope = (notification.userInfo?["scope"] as? String)?.lowercased() ?? "today"
                let projectID = (notification.userInfo?["projectID"] as? String).flatMap(UUID.init(uuidString:))
                self?.emit(.taskScopeDeepLink(scope: scope, projectID: projectID))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenTaskDetailDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let taskIDRaw = notification.userInfo?["taskID"] as? String,
                      let taskID = UUID(uuidString: taskIDRaw) else {
                    return
                }
                self?.emit(.taskDetailDeepLink(taskID: taskID))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenHabitBoardDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.habitBoardDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenHabitLibraryDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.habitLibraryDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenHabitDetailDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let habitIDRaw = notification.userInfo?["habitID"] as? String,
                      let habitID = UUID(uuidString: habitIDRaw) else {
                    return
                }
                self?.emit(.habitDetailDeepLink(habitID: habitID))
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenQuickAddDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.quickAddDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenCalendarScheduleDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.calendarScheduleDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenCalendarChooserDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.calendarChooserDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenWeeklyPlannerDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.weeklyPlannerDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardOpenWeeklyReviewDeepLink)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.weeklyReviewDeepLink)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .lifeboardProcessWidgetActionCommand)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.emit(.widgetActionCommand)
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

/// Native app-level routing for notifications, deep links, shortcuts, and
/// system-surface commands. It translates external events into the typed
/// Life OS router and canonical Home mutations without a view-controller hop.
@MainActor
final class NavigationEventCoordinator: HomeNavigationEventAdapterDelegate {
    private let router: AppRouter
    private let homeViewModel: HomeViewModel
    private let eventAdapter: HomeNavigationEventAdapter

    init(
        router: AppRouter,
        homeViewModel: HomeViewModel,
        notificationCenter: NotificationCenter = .default
    ) {
        self.router = router
        self.homeViewModel = homeViewModel
        eventAdapter = HomeNavigationEventAdapter(notificationCenter: notificationCenter)
        eventAdapter.delegate = self
    }

    func start() {
        eventAdapter.start()
        if let route = NotificationRouteBus.shared.consumePendingRoute() {
            router.handle(notificationRoute: route)
        }
        consumePendingShortcutHandoff()
        processPendingWidgetActionCommand()
    }

    func stop() {
        eventAdapter.stop()
    }

    func homeNavigationEventAdapter(
        _ adapter: HomeNavigationEventAdapter,
        didReceive intent: HomeNavigationIntent
    ) {
        switch intent {
        case .notificationRoute(let route):
            router.handle(notificationRoute: route)
        case .focusDeepLink:
            router.push(.focusSession(nil), in: .plan)
        case .chatDeepLink(let prompt):
            try? EvaChatLaunchRequestStore.shared.submit(.init(prompt: prompt))
            router.select(.eva)
        case .homeDeepLink(let notice):
            router.select(.home)
            if let notice, notice.isEmpty == false {
                router.activeAlert = .init(title: "Opened Home", message: notice)
            }
        case .insightsDeepLink:
            router.select(.insights)
        case .taskScopeDeepLink(let scope, let projectID):
            routeTaskScope(scope, projectID: projectID)
        case .taskDetailDeepLink(let taskID):
            router.push(.taskDetail(taskID), in: .home)
        case .habitBoardDeepLink:
            router.push(.habitBoard, in: .track)
        case .habitLibraryDeepLink:
            router.push(.habitLibrary, in: .track)
        case .habitDetailDeepLink(let habitID):
            router.push(.habitDetail(habitID), in: .track)
        case .quickAddDeepLink:
            router.captureRouter.request(kind: .task, source: .deepLink)
        case .calendarScheduleDeepLink:
            router.push(.planDay, in: .plan)
        case .calendarChooserDeepLink:
            router.push(.settings, in: .plan)
        case .weeklyPlannerDeepLink:
            router.push(.weeklyPlanner, in: .plan)
        case .weeklyReviewDeepLink:
            router.push(.weeklyReview, in: .plan)
        case .widgetActionCommand, .pendingWidgetActionCommand:
            processPendingWidgetActionCommand()
        case .pendingShortcutHandoff:
            consumePendingShortcutHandoff()
        case .uiTestInjectedRoute:
            break
        case .uiTestOpenSettings:
            router.push(.settings, in: router.selectedDestination)
        case .pendingIPadModalRequest:
            router.captureRouter.request(kind: .task, source: .shell)
        }
    }

    private func routeTaskScope(_ scope: String, projectID: UUID?) {
        if let projectID {
            router.push(.project(projectID), in: .plan)
            return
        }
        switch scope.lowercased() {
        case "overdue": router.push(.backlog, in: .plan)
        case "upcoming": router.push(.planDay, in: .plan)
        case "done": router.select(.insights)
        default: router.select(.home)
        }
    }

    private func consumePendingShortcutHandoff() {
        if let action = PendingShortcutLaunchActionStore.shared.consumePendingAction() {
            switch action.kind {
            case .askEva:
                try? EvaChatLaunchRequestStore.shared.submit(.init(prompt: action.prompt))
                router.select(.eva)
            case .startFocus:
                router.push(.focusSession(nil), in: .plan)
            }
        }
        if ShortcutMutationSignalStore.shared.consumePendingSignal() != nil {
            homeViewModel.handleExternalMutation(reason: .created)
        }
    }

    private func processPendingWidgetActionCommand() {
        guard V2FeatureFlags.interactiveTaskWidgetsEnabled, AppDelegate.isWriteClosed == false else { return }
        if let command = TaskListWidgetActionCommand.loadPending() {
            if command.expiresAt <= Date() {
                TaskListWidgetActionCommand.clearPending()
            } else {
                process(command, attemptsRemaining: 2)
            }
        }
        processPendingBehaviorOccurrenceActionCommand()
    }

    private func processPendingBehaviorOccurrenceActionCommand() {
        guard let command = BehaviorOccurrenceActionCommand.loadPending() else { return }
        guard command.expiresAt > Date() else {
            BehaviorOccurrenceActionCommand.clearPending()
            return
        }
        if let occurrence = TaskListWidgetSnapshot.load().behaviorOccurrences.first(where: {
            $0.occurrenceID == command.occurrenceID
        }), occurrence.result == .completed || occurrence.result == .skipped {
            BehaviorOccurrenceActionCommand.clearPending()
            return
        }
        let resolution: OccurrenceResolutionType = command.action == .complete ? .completed : .skipped
        homeViewModel.useCaseCoordinator.resolveOccurrence.execute(
            id: command.occurrenceID,
            resolution: resolution,
            actor: .user
        ) { result in
            guard case .success = result else { return }
            BehaviorOccurrenceActionCommand.clearPending()
            TaskListWidgetSnapshotService.shared.scheduleRefresh(reason: "behavior_widget_resolution")
        }
    }

    private func process(_ command: TaskListWidgetActionCommand, attemptsRemaining: Int) {
        guard let task = homeViewModel.taskSnapshot(for: command.taskID) else {
            guard attemptsRemaining > 0 else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            homeViewModel.loadTodayTasks()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.process(command, attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }
        guard task.isComplete == false else {
            TaskListWidgetActionCommand.clearPending()
            return
        }
        switch command.action {
        case .complete:
            homeViewModel.setTaskCompletion(taskID: task.id, to: true) { _ in
                TaskListWidgetActionCommand.clearPending()
            }
        case .defer15m, .defer60m:
            let minutes = command.action == .defer15m ? 15 : 60
            let threshold = command.createdAt.addingTimeInterval(TimeInterval(max(minutes - 1, 1) * 60))
            if let dueDate = task.dueDate, dueDate >= threshold {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            let requested = Date().addingTimeInterval(TimeInterval(minutes * 60))
            homeViewModel.rescheduleTask(
                taskID: task.id,
                to: min(requested, Date().addingTimeInterval(24 * 60 * 60))
            ) { _ in
                TaskListWidgetActionCommand.clearPending()
            }
        }
        homeViewModel.setQuickView(.today)
    }
}
