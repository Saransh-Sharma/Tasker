import Foundation
import UserNotifications

public enum TaskerNotificationRuntime {
    public static var orchestrator: TaskNotificationOrchestrator?
    public static var actionHandler: TaskerNotificationActionHandler?
}

public final class LocalNotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()
    private let dateFormatter: DateFormatter

    /// Initializes a new instance.
    public init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    }

    /// Executes scheduleTaskReminder.
    public func scheduleTaskReminder(taskId: UUID, taskName: String, at date: Date) {
        schedule(
            request: TaskerLocalNotificationRequest(
                id: "task.reminder.\(taskId.uuidString)",
                kind: .taskReminder,
                title: "Task Reminder",
                body: taskName,
                fireDate: date,
                route: .taskDetail(taskID: taskId),
                taskID: taskId
            )
        )
    }

    /// Executes cancelTaskReminder.
    public func cancelTaskReminder(taskId: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [
                taskId.uuidString,
                "task.reminder.\(taskId.uuidString)"
            ]
        )
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
        fetchAuthorizationStatus { status in
            completion(status == .authorized || status == .provisional || status == .ephemeral)
        }
    }

    /// Executes fetchAuthorizationStatus.
    public func fetchAuthorizationStatus(completion: @escaping (TaskerNotificationAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            let mapped: TaskerNotificationAuthorizationStatus
            switch settings.authorizationStatus {
            case .notDetermined:
                mapped = .notDetermined
            case .denied:
                mapped = .denied
            case .authorized:
                mapped = .authorized
            case .provisional:
                mapped = .provisional
            case .ephemeral:
                mapped = .ephemeral
            @unknown default:
                mapped = .ephemeral
            }
            completion(mapped)
        }
    }

    /// Executes schedule.
    public func schedule(request: TaskerLocalNotificationRequest) {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.categoryIdentifier = request.categoryIdentifier
        content.threadIdentifier = request.kind.rawValue

        var userInfo = request.userInfo
        userInfo[TaskerLocalNotificationRequest.UserInfoKey.kind] = request.kind.rawValue
        userInfo[TaskerLocalNotificationRequest.UserInfoKey.route] = request.route.payload
        userInfo[TaskerLocalNotificationRequest.UserInfoKey.fireDateUnix] = String(Int(request.fireDate.timeIntervalSince1970.rounded()))
        if let taskID = request.taskID {
            userInfo[TaskerLocalNotificationRequest.UserInfoKey.taskID] = taskID.uuidString
        }
        content.userInfo = userInfo

        let triggerInterval = max(request.fireDate.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: request.repeats)
        let notificationRequest = UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)

        center.add(notificationRequest) { error in
            if let error {
                logError(
                    event: "notification_schedule_failed",
                    message: "Failed to schedule local notification",
                    fields: [
                        "id": request.id,
                        "kind": request.kind.rawValue,
                        "error": error.localizedDescription
                    ]
                )
                return
            }

            self.logLocalEvent(
                name: "scheduled",
                id: request.id,
                kind: request.kind.rawValue,
                fireDate: request.fireDate
            )
        }
    }

    /// Executes cancel.
    public func cancel(ids: [String]) {
        guard ids.isEmpty == false else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Executes pendingRequests.
    public func pendingRequests(completion: @escaping ([TaskerPendingNotificationRequest]) -> Void) {
        center.getPendingNotificationRequests { requests in
            let now = Date()
            let mapped = requests.map { request -> TaskerPendingNotificationRequest in
                let persistedFireDateRaw = request.content.userInfo[TaskerLocalNotificationRequest.UserInfoKey.fireDateUnix] as? String
                let persistedFireDate = persistedFireDateRaw
                    .flatMap(TimeInterval.init)
                    .map(Date.init(timeIntervalSince1970:))
                let fireDate = persistedFireDate ?? Self.resolveFireDate(from: request.trigger, now: now)
                let kindRaw = request.content.userInfo[TaskerLocalNotificationRequest.UserInfoKey.kind] as? String
                let kind = kindRaw.flatMap(TaskerLocalNotificationKind.init(rawValue:))
                let routePayload = request.content.userInfo[TaskerLocalNotificationRequest.UserInfoKey.route] as? String
                let taskIDRaw = request.content.userInfo[TaskerLocalNotificationRequest.UserInfoKey.taskID] as? String
                let taskID = taskIDRaw.flatMap(UUID.init(uuidString:))
                return TaskerPendingNotificationRequest(
                    id: request.identifier,
                    fireDate: fireDate,
                    kind: kind,
                    title: request.content.title,
                    body: request.content.body,
                    categoryIdentifier: request.content.categoryIdentifier,
                    routePayload: routePayload,
                    taskID: taskID
                )
            }
            completion(mapped)
        }
    }

    /// Executes registerCategories.
    public func registerCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }

    /// Executes setDelegate.
    public func setDelegate(_ delegate: UNUserNotificationCenterDelegate?) {
        center.delegate = delegate
    }

    private static func resolveFireDate(from trigger: UNNotificationTrigger?, now: Date) -> Date? {
        guard let trigger else { return nil }
        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return now.addingTimeInterval(intervalTrigger.timeInterval)
        }
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return Calendar.current.nextDate(
                after: now,
                matching: calendarTrigger.dateComponents,
                matchingPolicy: .nextTime
            )
        }
        return nil
    }

    private func logLocalEvent(name: String, id: String, kind: String, fireDate: Date?) {
        var fields: [String: String] = [
            "event_name": name,
            "notification_id": id,
            "kind": kind
        ]
        if let fireDate {
            fields["fire_date"] = dateFormatter.string(from: fireDate)
        }
        logWarning(
            event: "notification_lifecycle",
            message: "Local notification lifecycle event",
            fields: fields
        )
    }
}

public enum TaskerNotificationCategories {
    public static func all() -> Set<UNNotificationCategory> {
        let openAction = UNNotificationAction(
            identifier: TaskerNotificationActionID.open.rawValue,
            title: "Open",
            options: [.foreground]
        )
        let completeAction = UNNotificationAction(
            identifier: TaskerNotificationActionID.complete.rawValue,
            title: "Complete",
            options: []
        )
        let snooze15Action = UNNotificationAction(
            identifier: TaskerNotificationActionID.snooze15m.rawValue,
            title: "Snooze 15m",
            options: []
        )
        let taskCategory = UNNotificationCategory(
            identifier: TaskerNotificationCategoryID.taskActionable.rawValue,
            actions: [openAction, completeAction, snooze15Action],
            intentIdentifiers: [],
            options: []
        )

        let openTodayAction = UNNotificationAction(
            identifier: TaskerNotificationActionID.openToday.rawValue,
            title: "Open Today",
            options: [.foreground]
        )
        let snooze30Action = UNNotificationAction(
            identifier: TaskerNotificationActionID.snooze30m.rawValue,
            title: "Snooze 30m",
            options: []
        )
        let morningCategory = UNNotificationCategory(
            identifier: TaskerNotificationCategoryID.dailyMorning.rawValue,
            actions: [openTodayAction, snooze30Action],
            intentIdentifiers: [],
            options: []
        )

        let openDoneAction = UNNotificationAction(
            identifier: TaskerNotificationActionID.openDone.rawValue,
            title: "Open Done",
            options: [.foreground]
        )
        let snooze60Action = UNNotificationAction(
            identifier: TaskerNotificationActionID.snooze60m.rawValue,
            title: "Snooze 60m",
            options: []
        )
        let nightlyCategory = UNNotificationCategory(
            identifier: TaskerNotificationCategoryID.dailyNightly.rawValue,
            actions: [openDoneAction, snooze60Action],
            intentIdentifiers: [],
            options: []
        )

        return [taskCategory, morningCategory, nightlyCategory]
    }
}

public final class TaskerNotificationRouteBus {
    public static let routeDidChange = Notification.Name("TaskerNotificationRouteDidChange")
    public static let shared = TaskerNotificationRouteBus()

    private var pendingRoute: TaskerNotificationRoute?
    private let lock = NSLock()

    private init() {}

    public func post(route: TaskerNotificationRoute) {
        lock.lock()
        pendingRoute = route
        lock.unlock()
        NotificationCenter.default.post(
            name: Self.routeDidChange,
            object: nil,
            userInfo: ["payload": route.payload]
        )
    }

    public func consumePendingRoute() -> TaskerNotificationRoute? {
        lock.lock()
        defer { lock.unlock() }
        let route = pendingRoute
        pendingRoute = nil
        return route
    }
}

public final class TaskerNotificationActionHandler {
    private let notificationService: NotificationServiceProtocol
    private let coordinatorProvider: () -> UseCaseCoordinator?
    private let routeBus: TaskerNotificationRouteBus
    private let preferencesStore: TaskerNotificationPreferencesStore
    private let calendar: Calendar
    private let now: () -> Date
    private let actionCompletionTimeoutSeconds: TimeInterval = 4

    /// Initializes a new instance.
    public init(
        notificationService: NotificationServiceProtocol,
        coordinatorProvider: @escaping () -> UseCaseCoordinator?,
        routeBus: TaskerNotificationRouteBus = .shared,
        preferencesStore: TaskerNotificationPreferencesStore = .shared,
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
        completion: @escaping () -> Void
    ) {
        let finish = completionGate(completion)
        DispatchQueue.main.asyncAfter(deadline: .now() + actionCompletionTimeoutSeconds) {
            finish()
        }

        if identifier == UNNotificationDefaultActionIdentifier {
            let route = routeFrom(request: request)
            routeBus.post(route: route)
            logWarning(event: "notification_opened", message: "Notification opened", fields: ["id": request.identifier])
            finish()
            return
        }

        guard let action = TaskerNotificationActionID(rawValue: identifier) else {
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

    private func completeTask(from request: UNNotificationRequest, completion: @escaping () -> Void) {
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

    private func cancelTaskBoundNotifications(taskID: UUID, completion: (() -> Void)? = nil) {
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
        let kind: TaskerLocalNotificationKind
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
            request: TaskerLocalNotificationRequest(
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
        let raw = request.content.userInfo[TaskerLocalNotificationRequest.UserInfoKey.taskID] as? String
        return raw.flatMap(UUID.init(uuidString:))
    }

    private func kind(from request: UNNotificationRequest) -> TaskerLocalNotificationKind {
        let raw = request.content.userInfo[TaskerLocalNotificationRequest.UserInfoKey.kind] as? String
        return raw.flatMap(TaskerLocalNotificationKind.init(rawValue:)) ?? .taskReminder
    }

    private func routeFrom(request: UNNotificationRequest) -> TaskerNotificationRoute {
        let payload = request.content.userInfo[TaskerLocalNotificationRequest.UserInfoKey.route] as? String
        return TaskerNotificationRoute.from(
            payload: payload ?? "home_today",
            fallbackTaskID: taskID(from: request)
        )
    }

    private func completionGate(_ completion: @escaping () -> Void) -> () -> Void {
        let lock = NSLock()
        var completed = false
        return {
            lock.lock()
            defer { lock.unlock() }
            guard completed == false else { return }
            completed = true
            completion()
        }
    }

    private func adjustedSnoozeFireDate(_ fireDate: Date, for kind: TaskerLocalNotificationKind) -> Date {
        let preferences = preferencesStore.load()
        guard preferences.quietHoursEnabled else { return fireDate }
        guard shouldApplyQuietHoursToSnooze(kind: kind, preferences: preferences) else { return fireDate }
        guard isDateInQuietHours(fireDate, preferences: preferences) else { return fireDate }
        return nextAllowedDate(after: fireDate, preferences: preferences)
    }

    private func shouldApplyQuietHoursToSnooze(
        kind: TaskerLocalNotificationKind,
        preferences: TaskerNotificationPreferences
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

    private func isDateInQuietHours(_ date: Date, preferences: TaskerNotificationPreferences) -> Bool {
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

    private func nextAllowedDate(after date: Date, preferences: TaskerNotificationPreferences) -> Date {
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

public final class TaskNotificationOrchestrator {
    private let taskRepository: TaskDefinitionRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    private let gamificationRepository: GamificationRepositoryProtocol?
    private let preferencesStore: TaskerNotificationPreferencesStore
    private let calendar: Calendar
    private let now: () -> Date

    private let managedPrefixes: [String] = [
        "task.reminder.",
        "task.dueSoon.",
        "task.overdue.",
        "task.snooze.",
        "daily.morning.",
        "daily.nightly.",
        "daily.reflection."
    ]

    private var observers: [NSObjectProtocol] = []
    private let stampFormatter: DateFormatter
    private let reconcileDebounceInterval: TimeInterval
    private var pendingReconcileReasons: Set<String> = []
    private var pendingReconcileWorkItem: DispatchWorkItem?
    private var isReconciling = false
    private var queuedReconcileAfterCurrentPass = false

    /// Initializes a new instance.
    public init(
        taskRepository: TaskDefinitionRepositoryProtocol,
        notificationService: NotificationServiceProtocol,
        gamificationRepository: GamificationRepositoryProtocol? = nil,
        preferencesStore: TaskerNotificationPreferencesStore = .shared,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        reconcileDebounceInterval: TimeInterval = 0
    ) {
        self.taskRepository = taskRepository
        self.notificationService = notificationService
        self.gamificationRepository = gamificationRepository
        self.preferencesStore = preferencesStore
        self.calendar = calendar
        self.now = now
        self.reconcileDebounceInterval = max(0, reconcileDebounceInterval)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        self.stampFormatter = formatter
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    public func startObservingMutations() {
        guard observers.isEmpty else { return }
        let names: [Notification.Name] = [
            NSNotification.Name("TaskCreated"),
            NSNotification.Name("TaskUpdated"),
            NSNotification.Name("TaskDeleted"),
            NSNotification.Name("TaskCompletionChanged"),
            Notification.Name("HomeTaskMutationEvent"),
            .dailyReflectionCompleted
        ]
        names.forEach { name in
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reconcile(reason: name.rawValue)
            }
            observers.append(token)
        }
    }

    public func reconcile(reason: String = "manual") {
        DispatchQueue.main.async { [weak self] in
            self?.scheduleReconcile(reason: reason)
        }
    }

    private func scheduleReconcile(reason: String) {
        pendingReconcileReasons.insert(reason)

        if isReconciling {
            queuedReconcileAfterCurrentPass = true
            return
        }

        pendingReconcileWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPendingReconcile()
        }
        pendingReconcileWorkItem = workItem

        if reconcileDebounceInterval == 0 {
            DispatchQueue.main.async(execute: workItem)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + reconcileDebounceInterval, execute: workItem)
        }
    }

    private func flushPendingReconcile() {
        guard isReconciling == false else {
            queuedReconcileAfterCurrentPass = true
            return
        }
        guard pendingReconcileReasons.isEmpty == false else { return }

        isReconciling = true
        let reasons = pendingReconcileReasons.sorted()
        pendingReconcileReasons.removeAll()
        pendingReconcileWorkItem = nil

        let interval = TaskerPerformanceTrace.begin("NotificationReconcile")
        let mergedReason = reasons.joined(separator: ",")
        taskRepository.fetchAll(query: nil) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                logError(
                    event: "notification_reconcile_failed",
                    message: "Failed to fetch tasks for notification reconciliation",
                    fields: [
                        "reason": mergedReason,
                        "error": error.localizedDescription
                    ]
                )
                TaskerPerformanceTrace.end(interval)
                self.completeReconcileCycle()
            case .success(let tasks):
                self.applyReconciliation(tasks: tasks, reason: mergedReason) {
                    TaskerPerformanceTrace.end(interval)
                    self.completeReconcileCycle()
                }
            }
        }
    }

    private func completeReconcileCycle() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isReconciling = false
            if self.queuedReconcileAfterCurrentPass || self.pendingReconcileReasons.isEmpty == false {
                self.queuedReconcileAfterCurrentPass = false
                self.scheduleReconcile(reason: "queued_follow_up")
            }
        }
    }

    private func applyReconciliation(
        tasks: [TaskDefinition],
        reason: String,
        completion: @escaping () -> Void
    ) {
        let nowDate = now()
        resolveExactDailyXPByDateKey(nowDate: nowDate) { [weak self] exactDailyXPByDateKey in
            guard let self else {
                completion()
                return
            }
            let preferences = self.preferencesStore.load()
            let desired = self.desiredRequests(
                tasks: tasks,
                nowDate: nowDate,
                preferences: preferences,
                exactDailyXPByDateKey: exactDailyXPByDateKey
            )
            let desiredByID = desired.reduce(into: [String: TaskerLocalNotificationRequest]()) { partialResult, request in
                partialResult[request.id] = request
            }

            self.notificationService.pendingRequests { pending in
                let pendingByID = pending.reduce(into: [String: TaskerPendingNotificationRequest]()) { partialResult, request in
                    partialResult[request.id] = request
                }

                let staleIDs = pendingByID.keys
                    .filter { self.isManagedIdentifier($0) && desiredByID[$0] == nil }
                    .sorted()
                let changedIDs = desiredByID.compactMap { id, request -> String? in
                    guard let existing = pendingByID[id] else { return nil }
                    let desiredFingerprint = self.fingerprint(for: request)
                    let existingFingerprint = self.fingerprint(for: existing)
                    return desiredFingerprint == existingFingerprint ? nil : id
                }.sorted()
                let changedSet = Set(changedIDs)

                let addedRequests = desired.filter { pendingByID[$0.id] == nil }
                let updatedRequests = desired.filter { changedSet.contains($0.id) }
                let requestsToSchedule = addedRequests + updatedRequests
                let unchangedCount = max(0, desired.count - requestsToSchedule.count)
                let idsToCancel = Array(Set(staleIDs + changedIDs)).sorted()

                if idsToCancel.isEmpty == false {
                    self.notificationService.cancel(ids: idsToCancel)
                }
                requestsToSchedule.forEach { self.notificationService.schedule(request: $0) }

                logWarning(
                    event: "notification_reconciled",
                    message: "Notification schedule reconciled",
                    fields: [
                        "reason": reason,
                        "desired_count": String(desired.count),
                        "added_count": String(addedRequests.count),
                        "updated_count": String(updatedRequests.count),
                        "removed_count": String(idsToCancel.count),
                        "unchanged_count": String(unchangedCount)
                    ]
                )
                completion()
            }
        }
    }

    private func resolveExactDailyXPByDateKey(
        nowDate: Date,
        completion: @escaping ([String: Int]) -> Void
    ) {
        guard let gamificationRepository else {
            completion([:])
            return
        }

        let startOfToday = calendar.startOfDay(for: nowDate)
        let endDate = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? startOfToday
        let startKey = XPCalculationEngine.periodKey(for: startOfToday)
        let endKey = XPCalculationEngine.periodKey(for: endDate)

        gamificationRepository.fetchDailyAggregates(from: startKey, to: endKey) { result in
            switch result {
            case .success(let aggregates):
                var mapped: [String: Int] = [:]
                for aggregate in aggregates {
                    let totalXP = max(0, aggregate.totalXP)
                    mapped[aggregate.dateKey] = totalXP
                    mapped[aggregate.dateKey.replacingOccurrences(of: "-", with: "")] = totalXP
                }
                completion(mapped)
            case .failure:
                completion([:])
            }
        }
    }

    private func desiredRequests(
        tasks: [TaskDefinition],
        nowDate: Date,
        preferences: TaskerNotificationPreferences,
        exactDailyXPByDateKey: [String: Int] = [:]
    ) -> [TaskerLocalNotificationRequest] {
        let openTasks = tasks.filter { !$0.isComplete }
        var requests: [TaskerLocalNotificationRequest] = []

        if preferences.taskRemindersEnabled {
            requests.append(contentsOf: makeTaskReminders(tasks: openTasks, nowDate: nowDate))
        }
        if preferences.dueSoonEnabled {
            requests.append(contentsOf: makeDueSoonNotifications(tasks: openTasks, nowDate: nowDate, preferences: preferences))
        }
        if preferences.overdueNudgesEnabled {
            requests.append(contentsOf: makeOverdueNotifications(tasks: openTasks, nowDate: nowDate))
        }
        if preferences.morningAgendaEnabled {
            requests.append(contentsOf: makeMorningAgendaNotifications(tasks: tasks, nowDate: nowDate, preferences: preferences))
        }
        if preferences.nightlyRetrospectiveEnabled {
            requests.append(contentsOf: makeNightlyRetrospectiveNotifications(
                tasks: tasks,
                nowDate: nowDate,
                preferences: preferences,
                exactDailyXPByDateKey: exactDailyXPByDateKey
            ))
        }
        requests.append(contentsOf: makeReflectionRitualNudges(nowDate: nowDate, preferences: preferences))

        let quietHoursAdjusted = applyQuietHours(to: requests, nowDate: nowDate, preferences: preferences)
        return quietHoursAdjusted.filter { $0.fireDate > nowDate }
    }

    private func makeTaskReminders(tasks: [TaskDefinition], nowDate: Date) -> [TaskerLocalNotificationRequest] {
        tasks.compactMap { task in
            guard let reminderTime = task.alertReminderTime, reminderTime > nowDate else {
                return nil
            }

            let dueText = relativeDueText(for: task, nowDate: nowDate)
            let body: String
            if let dueText {
                body = "\"\(task.title)\" is due \(dueText)."
            } else {
                body = "\"\(task.title)\" is waiting for you."
            }

            return TaskerLocalNotificationRequest(
                id: "task.reminder.\(task.id.uuidString)",
                kind: .taskReminder,
                title: "Task Reminder",
                body: body,
                fireDate: reminderTime,
                route: .taskDetail(taskID: task.id),
                taskID: task.id
            )
        }
    }

    private func makeDueSoonNotifications(
        tasks: [TaskDefinition],
        nowDate: Date,
        preferences: TaskerNotificationPreferences
    ) -> [TaskerLocalNotificationRequest] {
        let horizon = nowDate.addingTimeInterval(120 * 60)
        let candidates = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            guard dueDate > nowDate, dueDate <= horizon else { return false }
            if let reminder = task.alertReminderTime, reminder >= nowDate, reminder <= horizon {
                return false
            }
            return true
        }
        .sorted(by: taskUrgencySort(lhs:rhs:))

        guard let primaryTask = candidates.first,
              let dueDate = primaryTask.dueDate
        else {
            return []
        }
        let additionalCount = max(0, candidates.count - 1)
        let stamp = dateStamp(for: nowDate)

        let leadMinutes = preferences.dueSoonLeadMinutes
        let fireDate = maxDate(nowDate.addingTimeInterval(10), dueDate.addingTimeInterval(TimeInterval(-leadMinutes * 60)))
        let minutesUntilDue = max(1, Int(ceil(dueDate.timeIntervalSince(fireDate) / 60)))

        var body = "\"\(primaryTask.title)\" is due in \(minutesUntilDue)m."
        if additionalCount > 0 {
            body += " + \(additionalCount) more due soon"
        }

        return [
            TaskerLocalNotificationRequest(
                id: "task.dueSoon.\(primaryTask.id.uuidString).\(stamp)",
                kind: .dueSoon,
                title: "Due Soon",
                body: body,
                fireDate: fireDate,
                route: .taskDetail(taskID: primaryTask.id),
                taskID: primaryTask.id
            )
        ]
    }

    private func makeOverdueNotifications(tasks: [TaskDefinition], nowDate: Date) -> [TaskerLocalNotificationRequest] {
        let startOfToday = calendar.startOfDay(for: nowDate)
        let overdueTasks = tasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < startOfToday
            }
            .sorted(by: taskUrgencySort(lhs:rhs:))

        guard let primary = overdueTasks.first else { return [] }

        let additionalCount = max(0, overdueTasks.count - 1)
        let daysOverdue = overdueDays(for: primary, nowDate: nowDate)
        var body = "\"\(primary.title)\" is overdue by \(daysOverdue) day(s)."
        if additionalCount > 0 {
            body += " + \(additionalCount) more overdue"
        }

        let slots: [(suffix: String, hour: Int)] = [("am", 10), ("pm", 16)]
        let offsets = [0, 1]
        return offsets.flatMap { offset -> [TaskerLocalNotificationRequest] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                return []
            }
            let stamp = dateStamp(for: day)
            return slots.compactMap { slot in
                guard let fireDate = calendar.date(bySettingHour: slot.hour, minute: 0, second: 0, of: day),
                      fireDate > nowDate
                else {
                    return nil
                }
                return TaskerLocalNotificationRequest(
                    id: "task.overdue.\(primary.id.uuidString).\(stamp).\(slot.suffix)",
                    kind: .overdue,
                    title: "Overdue Task",
                    body: body,
                    fireDate: fireDate,
                    route: .taskDetail(taskID: primary.id),
                    taskID: primary.id
                )
            }
        }
    }

    private func makeMorningAgendaNotifications(
        tasks: [TaskDefinition],
        nowDate: Date,
        preferences: TaskerNotificationPreferences
    ) -> [TaskerLocalNotificationRequest] {
        makeDailyNotifications(
            prefix: "daily.morning",
            kind: .morningPlan,
            title: "Morning Plan",
            nowDate: nowDate,
            hour: preferences.morningHour,
            minute: preferences.morningMinute
        ) { day, _ in
            self.morningAgendaBody(tasks: tasks, day: day)
        }
    }

    private func makeNightlyRetrospectiveNotifications(
        tasks: [TaskDefinition],
        nowDate: Date,
        preferences: TaskerNotificationPreferences,
        exactDailyXPByDateKey: [String: Int]
    ) -> [TaskerLocalNotificationRequest] {
        makeDailyNotifications(
            prefix: "daily.nightly",
            kind: .nightlyRetrospective,
            title: "Day Retrospective",
            nowDate: nowDate,
            hour: preferences.nightlyHour,
            minute: preferences.nightlyMinute
        ) { day, dateStamp in
            self.nightlyRetrospectiveBody(
                tasks: tasks,
                day: day,
                exactDayXP: exactDailyXPByDateKey[dateStamp]
            )
        }
    }

    private func makeReflectionRitualNudges(
        nowDate: Date,
        preferences: TaskerNotificationPreferences
    ) -> [TaskerLocalNotificationRequest] {
        guard preferences.nightlyRetrospectiveEnabled else { return [] }

        let completedDateStamps = reflectionCompletedDateStamps()
        let startOfToday = calendar.startOfDay(for: nowDate)
        let offsets = [0, 1, 2]

        return offsets.flatMap { offset -> [TaskerLocalNotificationRequest] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { return [] }
            let dateStamp = dateStamp(for: day)
            guard completedDateStamps.contains(dateStamp) == false else { return [] }

            guard let eveningFire = calendar.date(
                bySettingHour: preferences.nightlyHour,
                minute: preferences.nightlyMinute,
                second: 0,
                of: day
            ) else {
                return []
            }

            var requests: [TaskerLocalNotificationRequest] = []
            if eveningFire > nowDate {
                requests.append(
                    TaskerLocalNotificationRequest(
                        id: "daily.reflection.\(dateStamp).evening",
                        kind: .nightlyRetrospective,
                        title: "Daily Reflection",
                        body: "Close your day with a 60-second reflection and secure your XP momentum.",
                        fireDate: eveningFire,
                        route: .dailySummary(kind: .nightly, dateStamp: dateStamp)
                    )
                )
            }

            if let followUpFire = calendar.date(byAdding: .minute, value: 90, to: eveningFire),
               calendar.isDate(followUpFire, inSameDayAs: day),
               followUpFire > nowDate {
                requests.append(
                    TaskerLocalNotificationRequest(
                        id: "daily.reflection.\(dateStamp).followup",
                        kind: .nightlyRetrospective,
                        title: "Reflection Reminder",
                        body: "One quick reflection keeps your streak resilient. Claim it before day-end.",
                        fireDate: followUpFire,
                        route: .dailySummary(kind: .nightly, dateStamp: dateStamp)
                    )
                )
            }

            return requests
        }
    }

    private func makeDailyNotifications(
        prefix: String,
        kind: TaskerLocalNotificationKind,
        title: String,
        nowDate: Date,
        hour: Int,
        minute: Int,
        bodyBuilder: (Date, String) -> String
    ) -> [TaskerLocalNotificationRequest] {
        let startOfToday = calendar.startOfDay(for: nowDate)
        let offsets = [0, 1, 2]

        return offsets.compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireDate > nowDate
            else {
                return nil
            }

            let dateStamp = dateStamp(for: day)
            let summaryKind: TaskerDailySummaryKind = (kind == .nightlyRetrospective) ? .nightly : .morning
            let route: TaskerNotificationRoute = .dailySummary(kind: summaryKind, dateStamp: dateStamp)

            return TaskerLocalNotificationRequest(
                id: "\(prefix).\(dateStamp)",
                kind: kind,
                title: title,
                body: bodyBuilder(day, dateStamp),
                fireDate: fireDate,
                route: route
            )
        }
    }

    private func morningAgendaBody(tasks: [TaskDefinition], day: Date) -> String {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let openTasks = tasks.filter { !$0.isComplete }

        let dueToday = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= start && dueDate < end
        }
        let overdue = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < start
        }

        let candidate = (dueToday + overdue).sorted(by: taskUrgencySort(lhs:rhs:))
        let openCount = candidate.count
        let highCount = candidate.filter { $0.priority.isHighPriority }.count
        let overdueCount = overdue.count

        guard let topTask = candidate.first else {
            return "No tasks queued. Capture one meaningful win."
        }

        return "\(openCount) tasks today (\(highCount) high priority, \(overdueCount) overdue). Start with \"\(topTask.title)\"."
    }

    private func nightlyRetrospectiveBody(tasks: [TaskDefinition], day: Date, exactDayXP: Int?) -> String {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        let completedToday = tasks
            .filter { task in
                guard let dateCompleted = task.dateCompleted else { return false }
                return dateCompleted >= start && dateCompleted < end
            }
            .sorted(by: taskUrgencySort(lhs:rhs:))

        guard completedToday.isEmpty == false else {
            return "No completions today. Pick one tiny restart for tomorrow."
        }

        let dueTodayIDs = Set(tasks.compactMap { task -> UUID? in
            guard let dueDate = task.dueDate, dueDate >= start, dueDate < end else { return nil }
            return task.id
        })
        let completedIDs = Set(completedToday.map(\.id))
        let totalCount = max(completedToday.count, dueTodayIDs.union(completedIDs).count)
        let topCompletedTask = completedToday.first?.title ?? "Task"

        if let exactDayXP {
            return "Completed \(completedToday.count)/\(totalCount) tasks, earned \(exactDayXP) XP. Biggest win: \"\(topCompletedTask)\"."
        }
        return "Completed \(completedToday.count)/\(totalCount) tasks. Biggest win: \"\(topCompletedTask)\". Open Tasker for exact XP."
    }

    private func relativeDueText(for task: TaskDefinition, nowDate: Date) -> String? {
        guard let dueDate = task.dueDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: dueDate, relativeTo: nowDate)
    }

    private func overdueDays(for task: TaskDefinition, nowDate: Date) -> Int {
        guard let dueDate = task.dueDate else { return 1 }
        let dueStart = calendar.startOfDay(for: dueDate)
        let nowStart = calendar.startOfDay(for: nowDate)
        return max(1, calendar.dateComponents([.day], from: dueStart, to: nowStart).day ?? 1)
    }

    private func dateStamp(for date: Date) -> String {
        stampFormatter.string(from: date)
    }

    private func reflectionCompletedDateStamps() -> Set<String> {
        let keys = UserDefaults.standard.stringArray(forKey: "gamification.reflection.completedDateKeys") ?? []
        return Set(keys)
    }

    private func fingerprint(for request: TaskerLocalNotificationRequest) -> NotificationFingerprint {
        NotificationFingerprint(
            kind: request.kind.rawValue,
            fireDateSecond: Int(request.fireDate.timeIntervalSince1970.rounded()),
            title: request.title,
            body: request.body,
            categoryIdentifier: request.categoryIdentifier,
            routePayload: request.route.payload,
            taskID: request.taskID?.uuidString
        )
    }

    private func fingerprint(for request: TaskerPendingNotificationRequest) -> NotificationFingerprint {
        NotificationFingerprint(
            kind: request.kind?.rawValue ?? "",
            fireDateSecond: request.fireDate.map { Int($0.timeIntervalSince1970.rounded()) },
            title: request.title,
            body: request.body,
            categoryIdentifier: request.categoryIdentifier,
            routePayload: request.routePayload ?? "",
            taskID: request.taskID?.uuidString
        )
    }

    private func isManagedIdentifier(_ id: String) -> Bool {
        managedPrefixes.contains(where: { id.hasPrefix($0) })
    }

    private func taskUrgencySort(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority.rawValue > rhs.priority.rawValue
        }
        let lhsDue = lhs.dueDate ?? .distantFuture
        let rhsDue = rhs.dueDate ?? .distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }

    private func applyQuietHours(
        to requests: [TaskerLocalNotificationRequest],
        nowDate: Date,
        preferences: TaskerNotificationPreferences
    ) -> [TaskerLocalNotificationRequest] {
        guard preferences.quietHoursEnabled else { return requests }

        return requests.map { request in
            guard shouldApplyQuietHours(for: request.kind, preferences: preferences),
                  isDateInQuietHours(request.fireDate, preferences: preferences)
            else {
                return request
            }

            let adjustedDate = nextAllowedDate(after: request.fireDate, nowDate: nowDate, preferences: preferences)
            guard adjustedDate != request.fireDate else { return request }

            return TaskerLocalNotificationRequest(
                id: request.id,
                kind: request.kind,
                title: request.title,
                body: request.body,
                fireDate: adjustedDate,
                repeats: request.repeats,
                route: request.route,
                taskID: request.taskID,
                categoryIdentifier: request.categoryIdentifier,
                userInfo: request.userInfo
            )
        }
    }

    private func shouldApplyQuietHours(
        for kind: TaskerLocalNotificationKind,
        preferences: TaskerNotificationPreferences
    ) -> Bool {
        switch kind {
        case .taskReminder, .dueSoon, .overdue, .snoozedTask:
            return preferences.quietHoursAppliesToTaskAlerts
        case .morningPlan, .nightlyRetrospective, .snoozedMorning, .snoozedNightly:
            return preferences.quietHoursAppliesToDailySummaries
        }
    }

    private func isDateInQuietHours(_ date: Date, preferences: TaskerNotificationPreferences) -> Bool {
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

    private func nextAllowedDate(
        after date: Date,
        nowDate: Date,
        preferences: TaskerNotificationPreferences
    ) -> Date {
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

        let candidate: Date
        if startMinutes < endMinutes {
            candidate = endTimeForDay
        } else if currentMinutes >= startMinutes {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            candidate = calendar.date(
                bySettingHour: preferences.quietHoursEndHour,
                minute: preferences.quietHoursEndMinute,
                second: 0,
                of: nextDay
            ) ?? date
        } else {
            candidate = endTimeForDay
        }

        // Ensure deferred date never drifts behind the current reconcile instant.
        if candidate <= nowDate {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: candidate)) ?? candidate
            return calendar.date(
                bySettingHour: preferences.quietHoursEndHour,
                minute: preferences.quietHoursEndMinute,
                second: 0,
                of: nextDay
            ) ?? nowDate.addingTimeInterval(60)
        }
        return candidate
    }
}

private struct NotificationFingerprint: Equatable {
    let kind: String
    let fireDateSecond: Int?
    let title: String
    let body: String
    let categoryIdentifier: String
    let routePayload: String
    let taskID: String?
}
