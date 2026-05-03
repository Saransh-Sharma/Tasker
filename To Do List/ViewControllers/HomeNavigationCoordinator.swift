import Foundation

@MainActor
protocol HomeNavigationCoordinatorDelegate: AnyObject {
    func homeNavigationShowTasksDestination()
    func homeNavigationSetQuickView(_ quickView: HomeQuickView)
    func homeNavigationSetPendingNotificationFocusTaskID(_ taskID: UUID?)
    func homeNavigationResolveAndPresentTaskDetail(taskID: UUID)
    func homeNavigationOpenFocus()
    func homeNavigationOpenChat(prompt: String?)
    func homeNavigationOpenHome(notice: String?)
    func homeNavigationOpenInsights()
    func homeNavigationOpenTaskScope(scope: String, projectID: UUID?)
    func homeNavigationOpenHabitBoard()
    func homeNavigationOpenHabitLibrary()
    func homeNavigationOpenHabitDetail(habitID: UUID)
    func homeNavigationOpenQuickAdd()
    func homeNavigationOpenCalendarSchedule()
    func homeNavigationOpenCalendarChooser()
    func homeNavigationOpenWeeklyPlanner()
    func homeNavigationOpenWeeklyReview()
    func homeNavigationProcessWidgetActionCommand()
    func homeNavigationRefreshPersistentSyncMode()
    func homeNavigationConsumePendingShortcutHandoff()
    func homeNavigationConsumeUITestInjectedRoute()
    func homeNavigationConsumeUITestOpenSettings()
    func homeNavigationProcessPendingIPadModalRequest()
    func homeNavigationPresentDailySummary(kind: TaskerDailySummaryKind, dateStamp: String?)
    func homeNavigationPresentReflectPlan(preferredReflectionDate: Date?)
    func homeNavigationDate(from stamp: String?) -> Date?
}

@MainActor
final class HomeNavigationCoordinator {
    weak var delegate: HomeNavigationCoordinatorDelegate?

    init(delegate: HomeNavigationCoordinatorDelegate? = nil) {
        self.delegate = delegate
    }

    func handle(_ intent: HomeNavigationIntent) {
        switch intent {
        case .notificationRoute(let route):
            handleNotificationRoute(route)
        case .focusDeepLink:
            delegate?.homeNavigationOpenFocus()
        case .chatDeepLink(let prompt):
            delegate?.homeNavigationOpenChat(prompt: prompt)
        case .homeDeepLink(let notice):
            delegate?.homeNavigationOpenHome(notice: notice)
        case .insightsDeepLink:
            delegate?.homeNavigationOpenInsights()
        case .taskScopeDeepLink(let scope, let projectID):
            delegate?.homeNavigationOpenTaskScope(scope: scope, projectID: projectID)
        case .taskDetailDeepLink(let taskID):
            delegate?.homeNavigationResolveAndPresentTaskDetail(taskID: taskID)
        case .habitBoardDeepLink:
            delegate?.homeNavigationOpenHabitBoard()
        case .habitLibraryDeepLink:
            delegate?.homeNavigationOpenHabitLibrary()
        case .habitDetailDeepLink(let habitID):
            delegate?.homeNavigationOpenHabitDetail(habitID: habitID)
        case .quickAddDeepLink:
            delegate?.homeNavigationOpenQuickAdd()
        case .calendarScheduleDeepLink:
            delegate?.homeNavigationOpenCalendarSchedule()
        case .calendarChooserDeepLink:
            delegate?.homeNavigationOpenCalendarChooser()
        case .weeklyPlannerDeepLink:
            delegate?.homeNavigationOpenWeeklyPlanner()
        case .weeklyReviewDeepLink:
            delegate?.homeNavigationOpenWeeklyReview()
        case .widgetActionCommand, .pendingWidgetActionCommand:
            delegate?.homeNavigationProcessWidgetActionCommand()
        case .persistentSyncModeChanged:
            delegate?.homeNavigationRefreshPersistentSyncMode()
        case .pendingShortcutHandoff:
            delegate?.homeNavigationConsumePendingShortcutHandoff()
        case .uiTestInjectedRoute:
            delegate?.homeNavigationConsumeUITestInjectedRoute()
        case .uiTestOpenSettings:
            delegate?.homeNavigationConsumeUITestOpenSettings()
        case .pendingIPadModalRequest:
            delegate?.homeNavigationProcessPendingIPadModalRequest()
        }
    }

    func handleNotificationRoute(_ route: TaskerNotificationRoute) {
        guard let delegate else { return }

        switch route {
        case .homeToday(let taskID):
            delegate.homeNavigationShowTasksDestination()
            delegate.homeNavigationSetQuickView(.today)
            delegate.homeNavigationSetPendingNotificationFocusTaskID(taskID)

        case .homeDone:
            delegate.homeNavigationShowTasksDestination()
            delegate.homeNavigationSetQuickView(.done)
            delegate.homeNavigationSetPendingNotificationFocusTaskID(nil)

        case .taskDetail(let taskID):
            delegate.homeNavigationShowTasksDestination()
            delegate.homeNavigationSetQuickView(.today)
            delegate.homeNavigationSetPendingNotificationFocusTaskID(taskID)
            delegate.homeNavigationResolveAndPresentTaskDetail(taskID: taskID)

        case .weeklyPlanner:
            delegate.homeNavigationOpenWeeklyPlanner()

        case .weeklyReview:
            delegate.homeNavigationOpenWeeklyReview()

        case .dailySummary(let kind, let dateStamp):
            if kind == .nightly {
                delegate.homeNavigationPresentReflectPlan(
                    preferredReflectionDate: delegate.homeNavigationDate(from: dateStamp)
                )
            } else {
                delegate.homeNavigationPresentDailySummary(kind: kind, dateStamp: dateStamp)
            }
        }
    }
}
