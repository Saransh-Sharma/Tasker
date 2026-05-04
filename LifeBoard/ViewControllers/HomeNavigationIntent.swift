import Foundation

enum HomeNavigationIntent: Equatable {
    case notificationRoute(LifeBoardNotificationRoute)
    case focusDeepLink
    case chatDeepLink(prompt: String?)
    case homeDeepLink(notice: String?)
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
    case persistentSyncModeChanged
    case pendingShortcutHandoff
    case uiTestInjectedRoute
    case uiTestOpenSettings
    case pendingWidgetActionCommand
    case pendingIPadModalRequest
}
