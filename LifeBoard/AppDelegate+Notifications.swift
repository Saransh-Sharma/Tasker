import UIKit
import UserNotifications

// Remote-notification registration, the local notification runtime and the
// notification-center delegate. Split out of AppDelegate.swift for the
// file-size ratchet; behaviour is unchanged.
extension AppDelegate {
    // MARK: - Push Notification Handling
    
    // Remote notification registration success/failure callbacks
    /// Executes application.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        // Token forwarding is intentionally deferred until a push provider is configured.
    }
    
    /// Executes application.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logError(
            event: "apns_registration_failed",
            message: "APNs registration failed",
            fields: [
                "error": error.localizedDescription
            ]
        )
    }

    // MARK: - Local Notification Runtime

    func configureLifeBoardNotifications() {
        guard let taskRepository = CompositionRoot.shared.taskDefinitionRepository,
              let notificationService = CompositionRoot.shared.notificationService
        else {
            return
        }

        let orchestrator = TaskNotificationOrchestrator(
            taskRepository: taskRepository,
            notificationService: notificationService,
            gamificationRepository: CompositionRoot.shared.gamificationRepository,
            preferencesStore: .shared,
            reconcileDebounceInterval: 0.35
        )
        orchestrator.startObservingMutations()
        notificationOrchestrator = orchestrator
        NotificationCoordinator.orchestrator = orchestrator

        let actionHandler = NotificationActionUseCase(
            notificationService: notificationService,
            coordinatorProvider: {
                let container = CompositionRoot.shared
                guard container.isConfiguredForRuntime else { return nil }
                return container.coordinator
            }
        )
        notificationActionHandler = actionHandler
        NotificationCoordinator.actionHandler = actionHandler

        if let notificationCenterAdapter = notificationService as? UserNotificationCenterConfiguring {
            notificationCenterAdapter.registerCategories(NotificationCategories.all())
            notificationCenterAdapter.setDelegate(self)
        } else {
            logError(
                event: "notification_adapter_missing",
                message: "Notification service does not expose platform configuration"
            )
        }

        notificationService.fetchAuthorizationStatus { status in
            switch status {
            case .notDetermined:
                break
            case .authorized, .provisional, .ephemeral:
                orchestrator.reconcile(reason: "app_launch_authorized")
            case .denied:
                break
            }
        }
    }

    func reconcileNotifications(reason: String = "manual") {
        notificationOrchestrator?.reconcile(reason: reason)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logWarning(
            event: "notification_delivered",
            message: "Notification delivered while app is foreground",
            fields: [
                "id": notification.request.identifier
            ]
        )
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        guard let notificationActionHandler else {
            completionHandler()
            return
        }
        // Tapping the notification itself opens its subject. While onboarding
        // covers the window that navigation would land behind it and be lost,
        // so it waits for onboarding to close. Action buttons (complete,
        // snooze) still run at once: they change data, not the screen.
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let sceneDelegate = UIApplication.shared.connectedScenes
               .compactMap({ $0.delegate as? SceneDelegate })
               .first(where: \.isAppWideEventTarget) {
            let identifier = response.actionIdentifier
            let request = response.notification.request
            let deferred = sceneDelegate.deferWhileOnboardingCovers {
                notificationActionHandler.handleAction(
                    identifier: identifier,
                    request: request,
                    completion: {}
                )
            }
            if deferred {
                completionHandler()
                return
            }
        }
        notificationActionHandler.handleAction(
            identifier: response.actionIdentifier,
            request: response.notification.request,
            completion: completionHandler
        )
    }
}
