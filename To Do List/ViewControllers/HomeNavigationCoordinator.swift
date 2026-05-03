import Foundation

@MainActor
protocol HomeNavigationCoordinatorDelegate: AnyObject {
    func homeNavigationShowTasksDestination()
    func homeNavigationSetQuickView(_ quickView: HomeQuickView)
    func homeNavigationSetPendingNotificationFocusTaskID(_ taskID: UUID?)
    func homeNavigationResolveAndPresentTaskDetail(taskID: UUID)
    func homeNavigationOpenWeeklyPlanner()
    func homeNavigationOpenWeeklyReview()
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
