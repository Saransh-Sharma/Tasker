import Foundation
import UIKit
import UserNotifications

/// Notification action bridge. Dependencies are immutable and callbacks are hopped back to the main actor.
public final class NotificationActionUseCase: @unchecked Sendable {
    private let notificationService: NotificationServiceProtocol
    private let coordinatorProvider: () -> UseCaseCoordinator?
    private let routeBus: NotificationRouteBus
    private let preferencesStore: NotificationPreferencesStore
    private let calendar: Calendar
    private let now: () -> Date
    private let actionCompletionTimeoutSeconds: TimeInterval = 4

    /// Initializes a new instance.
    public init(
        notificationService: NotificationServiceProtocol,
        coordinatorProvider: @escaping () -> UseCaseCoordinator?,
        routeBus: NotificationRouteBus = .shared,
        preferencesStore: NotificationPreferencesStore = .shared,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.notificationService = notificationService
        self.coordinatorProvider = coordinatorProvider
        self.routeBus = routeBus
        self.preferencesStore = preferencesStore
        self.calendar = calendar
        self.now = now
    }

    public func handleAction(identifier: String, request: UNNotificationRequest) {
        handleAction(identifier: identifier, request: request, completion: {})
    }

    public func handleAction(
        identifier: String,
        request: UNNotificationRequest,
        completion: @escaping @Sendable () -> Void
    ) {
        let finish = completionGate(completion)
        DispatchQueue.main.asyncAfter(deadline: .now() + actionCompletionTimeoutSeconds) {
            finish()
        }

        if identifier == UNNotificationDefaultActionIdentifier || identifier == NotificationActionID.open.rawValue,
           let link = NotificationSubjectLink.url(from: request.content.userInfo) {
            // Through the scene's URL handling, which also waits out onboarding.
            Task { @MainActor in _ = await UIApplication.shared.open(link) }
            logWarning(event: "notification_opened", message: "Opened reminder subject", fields: ["id": request.identifier])
            finish()
            return
        }

        if identifier == UNNotificationDefaultActionIdentifier {
            let route = routeFrom(request: request)
            routeBus.post(route: route)
            logWarning(event: "notification_opened", message: "Notification opened", fields: ["id": request.identifier])
            finish()
            return
        }

        guard let action = NotificationActionID(rawValue: identifier) else {
            finish()
            return
        }

        switch action {
        case .open:
            routeBus.post(route: routeFrom(request: request))
            logWarning(event: "notification_opened", message: "Opened from action", fields: ["id": request.identifier])
            finish()
        case .openToday:
            routeBus.post(route: .homeToday(taskID: taskID(from: request)))
            logWarning(event: "notification_opened", message: "Opened today from action", fields: ["id": request.identifier])
            finish()
        case .openWeeklyPlanner:
            routeBus.post(route: .weeklyPlanner)
            logWarning(event: "notification_opened", message: "Opened weekly planner from action", fields: ["id": request.identifier])
            finish()
        case .openWeeklyReview:
            routeBus.post(route: .weeklyReview)
            logWarning(event: "notification_opened", message: "Opened weekly review from action", fields: ["id": request.identifier])
            finish()
        case .openDone:
            routeBus.post(route: .homeDone)
            logWarning(event: "notification_opened", message: "Opened done from action", fields: ["id": request.identifier])
            finish()
        case .complete:
            completeTask(from: request, completion: finish)
        case .snooze15m:
            snooze(request: request, minutes: 15)
            finish()
        case .snooze30m:
            snooze(request: request, minutes: 30)
            finish()
        case .snooze60m:
            snooze(request: request, minutes: 60)
            finish()
        }
    }

    private func completeTask(from request: UNNotificationRequest, completion: @escaping @Sendable () -> Void) {
        guard let taskID = taskID(from: request) else {
            completion()
            return
        }
        guard let coordinator = coordinatorProvider() else {
            completion()
            return
        }
        coordinator.completeTaskDefinition.setCompletion(taskID: taskID, to: true) { _ in
            self.cancelTaskBoundNotifications(taskID: taskID) {
                completion()
            }
        }
        logWarning(
            event: "notification_completed_task",
            message: "Task completed from notification action",
            fields: ["task_id": taskID.uuidString, "notification_id": request.identifier]
        )
    }

    private func cancelTaskBoundNotifications(taskID: UUID, completion: (@Sendable () -> Void)? = nil) {
        notificationService.pendingRequests { pending in
            let taskIDString = taskID.uuidString
            let ids = pending
                .filter { $0.taskID == taskID || $0.id.contains(taskIDString) }
                .map(\.id)
            self.notificationService.cancel(ids: ids)
            completion?()
        }
    }

    private func snooze(request: UNNotificationRequest, minutes: Int) {
        let currentKind = kind(from: request)
        let kind: LocalNotificationKind
        switch currentKind {
        case .morningPlan, .snoozedMorning:
            kind = .snoozedMorning
        case .nightlyRetrospective, .snoozedNightly:
            kind = .snoozedNightly
        default:
            kind = .snoozedTask
        }

        let route = routeFrom(request: request)
        let provisionalFireDate = now().addingTimeInterval(TimeInterval(minutes * 60))
        let fireDate = adjustedSnoozeFireDate(provisionalFireDate, for: kind)
        let taskID = taskID(from: request)
        let requestID = "task.snooze.\(request.identifier).\(Int(fireDate.timeIntervalSince1970))"

        notificationService.schedule(
            request: LocalNotificationRequest(
                id: requestID,
                kind: kind,
                title: request.content.title,
                body: request.content.body,
                fireDate: fireDate,
                route: route,
                taskID: taskID,
                categoryIdentifier: request.content.categoryIdentifier.isEmpty ? nil : request.content.categoryIdentifier
            )
        )

        logWarning(
            event: "notification_snoozed",
            message: "Notification snoozed",
            fields: [
                "notification_id": request.identifier,
                "snooze_minutes": String(minutes)
            ]
        )
    }

    private func taskID(from request: UNNotificationRequest) -> UUID? {
        let raw = request.content.userInfo[LocalNotificationRequest.UserInfoKey.taskID] as? String
        return raw.flatMap(UUID.init(uuidString:))
    }

    private func kind(from request: UNNotificationRequest) -> LocalNotificationKind {
        let raw = request.content.userInfo[LocalNotificationRequest.UserInfoKey.kind] as? String
        return raw.flatMap(LocalNotificationKind.init(rawValue:)) ?? .taskReminder
    }

    private func routeFrom(request: UNNotificationRequest) -> NotificationRoute {
        let payload = request.content.userInfo[LocalNotificationRequest.UserInfoKey.route] as? String
        return NotificationRoute.from(
            payload: payload ?? "home_today",
            fallbackTaskID: taskID(from: request)
        )
    }

    private func completionGate(_ completion: @escaping @Sendable () -> Void) -> @Sendable () -> Void {
        final class CompletionGate: @unchecked Sendable {
            private let lock = NSLock()
            private var completed = false

            func claim() -> Bool {
                lock.lock()
                defer { lock.unlock() }
                guard completed == false else { return false }
                completed = true
                return true
            }
        }
        let gate = CompletionGate()
        return {
            guard gate.claim() else { return }
            completion()
        }
    }

    private func adjustedSnoozeFireDate(_ fireDate: Date, for kind: LocalNotificationKind) -> Date {
        let preferences = preferencesStore.load()
        guard preferences.quietHoursEnabled else { return fireDate }
        guard shouldApplyQuietHoursToSnooze(kind: kind, preferences: preferences) else { return fireDate }
        guard isDateInQuietHours(fireDate, preferences: preferences) else { return fireDate }
        return nextAllowedDate(after: fireDate, preferences: preferences)
    }

    private func shouldApplyQuietHoursToSnooze(
        kind: LocalNotificationKind,
        preferences: NotificationPreferences
    ) -> Bool {
        switch kind {
        case .snoozedTask:
            return preferences.quietHoursAppliesToTaskAlerts
        case .snoozedMorning, .snoozedNightly:
            return preferences.quietHoursAppliesToDailySummaries
        default:
            return false
        }
    }

    private func isDateInQuietHours(_ date: Date, preferences: NotificationPreferences) -> Bool {
        let startMinutes = preferences.quietHoursStartHour * 60 + preferences.quietHoursStartMinute
        let endMinutes = preferences.quietHoursEndHour * 60 + preferences.quietHoursEndMinute
        guard startMinutes != endMinutes else { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute

        if startMinutes < endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
        return currentMinutes >= startMinutes || currentMinutes < endMinutes
    }

    private func nextAllowedDate(after date: Date, preferences: NotificationPreferences) -> Date {
        let startMinutes = preferences.quietHoursStartHour * 60 + preferences.quietHoursStartMinute
        let endMinutes = preferences.quietHoursEndHour * 60 + preferences.quietHoursEndMinute
        guard startMinutes != endMinutes else { return date }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute
        let dayStart = calendar.startOfDay(for: date)
        let endTimeForDay = calendar.date(
            bySettingHour: preferences.quietHoursEndHour,
            minute: preferences.quietHoursEndMinute,
            second: 0,
            of: dayStart
        ) ?? date

        if startMinutes < endMinutes {
            return endTimeForDay > date ? endTimeForDay : date
        }
        if currentMinutes >= startMinutes {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            return calendar.date(
                bySettingHour: preferences.quietHoursEndHour,
                minute: preferences.quietHoursEndMinute,
                second: 0,
                of: nextDay
            ) ?? date
        }
        return endTimeForDay > date ? endTimeForDay : date
    }
}
