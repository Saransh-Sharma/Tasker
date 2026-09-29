import UIKit
import UserNotifications
import CoreSpotlight

extension SceneDelegate {
    func handleIncomingUserActivity(_ userActivity: NSUserActivity) {
        if deferWhileOnboardingCovers({ [weak self] in self?.handleIncomingUserActivity(userActivity) }) {
            return
        }
        if let webpageURL = userActivity.webpageURL {
            handleIncomingURL(webpageURL)
            return
        }
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }
        if let reference = SpotlightRouteTranslator.reference(for: identifier) {
            RecordRouteResolver.open(reference, with: foundationCoordinator.router)
        } else if identifier.hasPrefix(SpotlightRouteTranslator.journalPrefix) {
            foundationCoordinator.router.restoreFallbackToHome(
                message: "That Journal result is incomplete or no longer available."
            )
        }
    }

    func handleNotificationLaunch(
        request: UNNotificationRequest,
        actionIdentifier: String = UNNotificationDefaultActionIdentifier
    ) {
        if deferWhileOnboardingCovers({ [weak self] in
            self?.handleNotificationLaunch(request: request, actionIdentifier: actionIdentifier)
        }) {
            return
        }
        // Habit, tracker, medication and focus reminders name their subject
        // with a deep link; a cold-launch tap opens that subject, as a warm
        // tap does through `NotificationActionUseCase`.
        if actionIdentifier == UNNotificationDefaultActionIdentifier,
           let link = NotificationSubjectLink.url(from: request.content.userInfo) {
            handleIncomingURL(link)
            return
        }
        if V2FeatureFlags.lifeOSFoundationV1Enabled,
           let route = foundationNavigationRoute(for: request, actionIdentifier: actionIdentifier) {
            foundationCoordinator.router.handle(notificationRoute: route)
            return
        }
        if let actionHandler = NotificationCoordinator.actionHandler {
            actionHandler.handleAction(identifier: actionIdentifier, request: request)
            return
        }

        postFallbackNotificationRoute(for: request)
    }

    func postFallbackNotificationRoute(for request: UNNotificationRequest) {
        let payload = request.content.userInfo[LocalNotificationRequest.UserInfoKey.route] as? String
        let taskIDRaw = request.content.userInfo[LocalNotificationRequest.UserInfoKey.taskID] as? String
        let taskID = taskIDRaw.flatMap(UUID.init(uuidString:))
        let route = NotificationRoute.from(
            payload: payload ?? "home_today",
            fallbackTaskID: taskID
        )
        if V2FeatureFlags.lifeOSFoundationV1Enabled {
            foundationCoordinator.router.handle(notificationRoute: route)
            return
        }
        NotificationRouteBus.shared.post(route: route)
    }

    private func foundationNavigationRoute(
        for request: UNNotificationRequest,
        actionIdentifier: String
    ) -> NotificationRoute? {
        let payload = request.content.userInfo[LocalNotificationRequest.UserInfoKey.route] as? String
        let taskID = (request.content.userInfo[LocalNotificationRequest.UserInfoKey.taskID] as? String)
            .flatMap(UUID.init(uuidString:))
        let payloadRoute = NotificationRoute.from(
            payload: payload ?? "home_today",
            fallbackTaskID: taskID
        )
        if actionIdentifier == UNNotificationDefaultActionIdentifier { return payloadRoute }
        guard let action = NotificationActionID(rawValue: actionIdentifier) else { return nil }
        switch action {
        case .open: return payloadRoute
        case .openToday: return .homeToday(taskID: taskID)
        case .openWeeklyPlanner: return .weeklyPlanner
        case .openWeeklyReview: return .weeklyReview
        case .openDone: return .homeDone
        case .complete, .snooze15m, .snooze30m, .snooze60m: return nil
        }
    }
}
