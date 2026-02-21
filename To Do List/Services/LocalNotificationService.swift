import Foundation
import UserNotifications

public final class LocalNotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()

    /// Initializes a new instance.
    public init() {}

    /// Executes scheduleTaskReminder.
    public func scheduleTaskReminder(taskId: UUID, taskName: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = taskName
        content.sound = .default

        let triggerDate = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: taskId.uuidString, content: content, trigger: trigger)

        center.add(request)
    }

    /// Executes cancelTaskReminder.
    public func cancelTaskReminder(taskId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
    }

    /// Executes cancelAllReminders.
    public func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }

    /// Executes send.
    public func send(_ notification: CollaborationNotification) {
        let content = UNMutableNotificationContent()
        content.title = "Tasker"
        content.body = notification.message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        center.add(request)
    }

    /// Executes requestPermission.
    public func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            completion(granted)
        }
    }

    /// Executes checkAuthorizationStatus.
    public func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            completion(settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
        }
    }
}
