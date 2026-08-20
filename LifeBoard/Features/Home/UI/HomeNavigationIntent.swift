import Foundation

enum HomeNavigationIntent: Equatable {
    case notificationRoute(NotificationRoute)
    case focusDeepLink
    case chatDeepLink(prompt: String?)
    case homeDeepLink(notice: String?)
    case setupCenterDeepLink
    case insightsDeepLink
    case taskScopeDeepLink(scope: String, projectID: UUID?)
    case taskDetailDeepLink(taskID: UUID)
    case habitBoardDeepLink
    case habitLibraryDeepLink
    case habitDetailDeepLink(habitID: UUID)
    case quickAddDeepLink
    case calendarScheduleDeepLink
    case calendarChooserDeepLink
    case weeklyPlannerDeepLink
    case weeklyReviewDeepLink
    case widgetActionCommand
    case pendingShortcutHandoff
    case uiTestInjectedRoute
    case uiTestOpenSettings
    case pendingWidgetActionCommand
    case pendingIPadModalRequest
}
