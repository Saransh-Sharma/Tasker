import Foundation
import UserNotifications

public final class LocalNotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()

    public init() {}

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

    public func cancelTaskReminder(taskId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
    }

    public func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }

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

    public func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            completion(granted)
        }
    }

    public func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            completion(settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
        }
    }
}
