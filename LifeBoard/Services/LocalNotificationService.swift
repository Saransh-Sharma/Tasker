import Foundation
import UIKit
import UserNotifications

/// The subject a non-task reminder is about, as the app's own deep link.
///
/// Habit, tracker, medication and focus reminders are scheduled by their own
/// features and carry only their record's ID in `userInfo`, so a tap used to
/// resolve to the task route's `home_today` default and land on Home. The
/// deep links below are the same ones widgets use, so the tap lands on the
/// habit, the tracker, Care, or the session it was about.
public enum NotificationSubjectLink {
    /// The route payload a focus-session reminder carries (set by the Focus
    /// feature); `NotificationRoute` has no case for it.
    static let focusSessionPayloadPrefix = "focus_session:"

    public static func url(from userInfo: [AnyHashable: Any]) -> URL? {
        func id(_ key: String) -> String? {
            (userInfo[key] as? String).flatMap(UUID.init(uuidString:))?.uuidString
        }
        if let payload = userInfo[LocalNotificationRequest.UserInfoKey.route] as? String {
            // A typed task/day route wins; only the focus payload maps here.
            guard payload.hasPrefix(focusSessionPayloadPrefix),
                  let sessionID = UUID(uuidString: String(payload.dropFirst(focusSessionPayloadPrefix.count)))
            else { return nil }
            return URL(string: "lifeboard://focus/\(sessionID.uuidString)")
        }
        if let habitID = id("habitID") { return URL(string: "lifeboard://habit/\(habitID)") }
        if let trackerID = id("trackerID") { return URL(string: "lifeboard://tracker/\(trackerID)") }
        if id("medicationID") != nil { return URL(string: "lifeboard://care") }
        if let sessionID = id("focusSessionID") { return URL(string: "lifeboard://focus/\(sessionID)") }
        return nil
    }
}

public enum NotificationCoordinator {
    private final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var orchestratorStorage: TaskNotificationOrchestrator?
        private var actionHandlerStorage: NotificationActionUseCase?

        var orchestrator: TaskNotificationOrchestrator? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return orchestratorStorage
            }
            set {
                lock.lock()
                orchestratorStorage = newValue
                lock.unlock()
            }
        }

        var actionHandler: NotificationActionUseCase? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return actionHandlerStorage
            }
            set {
                lock.lock()
                actionHandlerStorage = newValue
                lock.unlock()
            }
        }
    }

    private static let storage = Storage()

    public static var orchestrator: TaskNotificationOrchestrator? {
        get { storage.orchestrator }
        set { storage.orchestrator = newValue }
    }

    public static var actionHandler: NotificationActionUseCase? {
        get { storage.actionHandler }
        set { storage.actionHandler = newValue }
    }
}

/// Platform-only controls intentionally kept out of the domain notification
/// contract so feature and domain packages do not import UserNotifications.
protocol UserNotificationCenterConfiguring: AnyObject {
    func registerCategories(_ categories: Set<UNNotificationCategory>)
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate?)
}

/// Immutable service wrapper around `UNUserNotificationCenter`; mutable scheduling state lives in the system center.
public final class LocalNotificationService: NotificationServiceProtocol, UserNotificationCenterConfiguring, @unchecked Sendable {
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
            request: LocalNotificationRequest(
                id: "task.reminder.\(taskId.uuidString)",
                kind: .taskReminder,
                title: taskName,
                body: "",
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
        content.title = "LifeBoard"
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
    public func requestPermission(completion: @escaping @Sendable (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            completion(granted)
        }
    }

    /// Executes checkAuthorizationStatus.
    public func checkAuthorizationStatus(completion: @escaping @Sendable (Bool) -> Void) {
        fetchAuthorizationStatus { status in
            completion(status == .authorized || status == .provisional || status == .ephemeral)
        }
    }

    /// Executes fetchAuthorizationStatus.
    public func fetchAuthorizationStatus(completion: @escaping @Sendable (NotificationAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            let mapped: NotificationAuthorizationStatus
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
    public func schedule(request: LocalNotificationRequest) {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.categoryIdentifier = request.categoryIdentifier
        content.threadIdentifier = request.kind.rawValue

        var userInfo = request.userInfo
        userInfo[LocalNotificationRequest.UserInfoKey.kind] = request.kind.rawValue
        userInfo[LocalNotificationRequest.UserInfoKey.route] = request.route.payload
        userInfo[LocalNotificationRequest.UserInfoKey.fireDateUnix] = String(Int(request.fireDate.timeIntervalSince1970.rounded()))
        if let taskID = request.taskID {
            userInfo[LocalNotificationRequest.UserInfoKey.taskID] = taskID.uuidString
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
    public func pendingRequests(completion: @escaping @Sendable ([PendingNotificationRequest]) -> Void) {
        center.getPendingNotificationRequests { requests in
            let now = Date()
            let mapped = requests.map { request -> PendingNotificationRequest in
                let persistedFireDateRaw = request.content.userInfo[LocalNotificationRequest.UserInfoKey.fireDateUnix] as? String
                let persistedFireDate = persistedFireDateRaw
                    .flatMap(TimeInterval.init)
                    .map(Date.init(timeIntervalSince1970:))
                let fireDate = persistedFireDate ?? Self.resolveFireDate(from: request.trigger, now: now)
                let kindRaw = request.content.userInfo[LocalNotificationRequest.UserInfoKey.kind] as? String
                let kind = kindRaw.flatMap(LocalNotificationKind.init(rawValue:))
                let routePayload = request.content.userInfo[LocalNotificationRequest.UserInfoKey.route] as? String
                let taskIDRaw = request.content.userInfo[LocalNotificationRequest.UserInfoKey.taskID] as? String
                let taskID = taskIDRaw.flatMap(UUID.init(uuidString:))
                return PendingNotificationRequest(
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
        logDebug(
            event: "notification_lifecycle",
            message: "Local notification lifecycle event",
            fields: fields
        )
    }
}

public enum NotificationCategories {
    public static func all() -> Set<UNNotificationCategory> {
        let openAction = UNNotificationAction(
            identifier: NotificationActionID.open.rawValue,
            title: String(localized: "Open"),
            options: [.foreground]
        )
        let completeAction = UNNotificationAction(
            identifier: NotificationActionID.complete.rawValue,
            title: String(localized: "Complete"),
            options: []
        )
        let snooze15Action = UNNotificationAction(
            identifier: NotificationActionID.snooze15m.rawValue,
            title: String(localized: "Snooze 15 min"),
            options: []
        )
        let taskCategory = UNNotificationCategory(
            identifier: NotificationCategoryID.taskActionable.rawValue,
            actions: [openAction, completeAction, snooze15Action],
            intentIdentifiers: [],
            options: []
        )

        let openTodayAction = UNNotificationAction(
            identifier: NotificationActionID.openToday.rawValue,
            title: String(localized: "Open Today"),
            options: [.foreground]
        )
        let planWeekAction = UNNotificationAction(
            identifier: NotificationActionID.openWeeklyPlanner.rawValue,
            title: String(localized: "Plan week"),
            options: [.foreground]
        )
        let snooze30Action = UNNotificationAction(
            identifier: NotificationActionID.snooze30m.rawValue,
            title: String(localized: "Snooze 30 min"),
            options: []
        )
        let morningCategory = UNNotificationCategory(
            identifier: NotificationCategoryID.dailyMorning.rawValue,
            actions: [openTodayAction, planWeekAction, snooze30Action],
            intentIdentifiers: [],
            options: []
        )

        let openDoneAction = UNNotificationAction(
            identifier: NotificationActionID.openDone.rawValue,
            title: String(localized: "Close the day"),
            options: [.foreground]
        )
        let reviewWeekAction = UNNotificationAction(
            identifier: NotificationActionID.openWeeklyReview.rawValue,
            title: String(localized: "Review week"),
            options: [.foreground]
        )
        let snooze60Action = UNNotificationAction(
            identifier: NotificationActionID.snooze60m.rawValue,
            title: String(localized: "Snooze 1 hr"),
            options: []
        )
        let nightlyCategory = UNNotificationCategory(
            identifier: NotificationCategoryID.dailyNightly.rawValue,
            actions: [openDoneAction, reviewWeekAction, snooze60Action],
            intentIdentifiers: [],
            options: []
        )

        return [taskCategory, morningCategory, nightlyCategory]
    }
}

/// Reconciliation coordinator with immutable dependencies; internal observer/timer state is main-queue confined.
public final class TaskNotificationOrchestrator: @unchecked Sendable {
    private let taskRepository: TaskDefinitionRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    private let gamificationRepository: GamificationRepositoryProtocol?
    private let preferencesStore: NotificationPreferencesStore
    private let calendar: Calendar
    private let now: () -> Date
    private let dayLoopClosureLog: DayLoopClosureLog

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
        preferencesStore: NotificationPreferencesStore = .shared,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        reconcileDebounceInterval: TimeInterval = 0,
        dayLoopClosureLog: DayLoopClosureLog = DayLoopClosureLog()
    ) {
        self.taskRepository = taskRepository
        self.notificationService = notificationService
        self.gamificationRepository = gamificationRepository
        self.preferencesStore = preferencesStore
        self.calendar = calendar
        self.now = now
        self.reconcileDebounceInterval = max(0, reconcileDebounceInterval)
        self.dayLoopClosureLog = dayLoopClosureLog

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
            Notification.Name("HomeTaskMutationEvent")
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

        let interval = PerformanceTrace.begin("NotificationReconcile")
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
                PerformanceTrace.end(interval)
                self.completeReconcileCycle()
            case .success(let tasks):
                self.applyReconciliation(tasks: tasks, reason: mergedReason) {
                    PerformanceTrace.end(interval)
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
        completion: @escaping @Sendable () -> Void
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
            let desiredByID = desired.reduce(into: [String: LocalNotificationRequest]()) { partialResult, request in
                partialResult[request.id] = request
            }

            self.notificationService.pendingRequests { pending in
                let pendingByID = pending.reduce(into: [String: PendingNotificationRequest]()) { partialResult, request in
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

                logInfo(
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
        completion: @escaping @Sendable ([String: Int]) -> Void
    ) {
        guard let gamificationRepository else {
            completion([:])
            return
        }

        let startOfToday = calendar.startOfDay(for: nowDate)
        let endDate = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? startOfToday
        let startKey = XPCalculationService.periodKey(for: startOfToday)
        let endKey = XPCalculationService.periodKey(for: endDate)

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
}

extension TaskNotificationOrchestrator {
    private func desiredRequests(
        tasks: [TaskDefinition],
        nowDate: Date,
        preferences: NotificationPreferences,
        exactDailyXPByDateKey: [String: Int] = [:]
    ) -> [LocalNotificationRequest] {
        let openTasks = tasks.filter { !$0.isComplete }
        var requests: [LocalNotificationRequest] = []

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
        let quietHoursAdjusted = applyQuietHours(to: requests, nowDate: nowDate, preferences: preferences)
        return quietHoursAdjusted.filter { $0.fireDate > nowDate }
    }

    private func makeTaskReminders(tasks: [TaskDefinition], nowDate: Date) -> [LocalNotificationRequest] {
        tasks.compactMap { task in
            guard let reminderTime = task.alertReminderTime, reminderTime > nowDate else {
                return nil
            }

            // The title is the task itself — "Task Reminder" said nothing a
            // glance at the lock screen could use. The body says when it is due.
            return LocalNotificationRequest(
                id: "task.reminder.\(task.id.uuidString)",
                kind: .taskReminder,
                title: task.title,
                body: dueLine(for: task, relativeTo: reminderTime),
                fireDate: reminderTime,
                route: .taskDetail(taskID: task.id),
                taskID: task.id
            )
        }
    }

    private func makeDueSoonNotifications(
        tasks: [TaskDefinition],
        nowDate: Date,
        preferences: NotificationPreferences
    ) -> [LocalNotificationRequest] {
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

        // Title is the task; the body is when, plus how many others are close.
        let dueIn = Self.durationText(minutes: minutesUntilDue)
        let body = additionalCount > 0
            ? String(localized: "Due in \(dueIn) · \(additionalCount) more due soon")
            : String(localized: "Due in \(dueIn)")

        return [
            LocalNotificationRequest(
                id: "task.dueSoon.\(primaryTask.id.uuidString).\(stamp)",
                kind: .dueSoon,
                title: primaryTask.title,
                body: body,
                fireDate: fireDate,
                route: .taskDetail(taskID: primaryTask.id),
                taskID: primaryTask.id
            )
        ]
    }

    private func makeOverdueNotifications(tasks: [TaskDefinition], nowDate: Date) -> [LocalNotificationRequest] {
        let startOfToday = calendar.startOfDay(for: nowDate)
        let overdueTasks = tasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < startOfToday
            }
            .sorted(by: taskUrgencySort(lhs:rhs:))

        guard let primary = overdueTasks.first else { return [] }

        // One nudge a day at 10:00, not two per task per day: a slipped task
        // is a fact to review once, and the review is one pass through them.
        // One task: its title, and how long ago it was due. Several: a count
        // and the first one's name.
        let count = overdueTasks.count
        let title = count == 1 ? primary.title : String(localized: "\(count) tasks from earlier")
        let others = count - 1
        let body = String(localized: "“\(primary.title)” and \(others) more")

        return [0, 1].compactMap { offset -> LocalNotificationRequest? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day),
                  fireDate > nowDate
            else {
                return nil
            }
            let stamp = dateStamp(for: day)
            if count == 1 {
                return LocalNotificationRequest(
                    id: "task.overdue.\(primary.id.uuidString).\(stamp).am",
                    kind: .overdue,
                    title: title,
                    body: fromEarlierLine(dueDate: primary.dueDate, relativeTo: day),
                    fireDate: fireDate,
                    route: .taskDetail(taskID: primary.id),
                    taskID: primary.id
                )
            }
            // Several tasks open the rescue deck, which walks through them.
            return LocalNotificationRequest(
                id: "task.overdue.digest.\(stamp)",
                kind: .overdue,
                title: title,
                body: body,
                fireDate: fireDate,
                route: .dayCompass(flow: .rescue, dateStamp: stamp),
                categoryIdentifier: NotificationCategoryID.dailyMorning.rawValue
            )
        }
    }

    private func makeMorningAgendaNotifications(
        tasks: [TaskDefinition],
        nowDate: Date,
        preferences: NotificationPreferences
    ) -> [LocalNotificationRequest] {
        // A morning with nothing on it gets no notification: "No tasks
        // queued" was a nudge about nothing.
        let quietStamps = Set((0...2).compactMap { offset -> String? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: nowDate)) else { return nil }
            return morningAgendaBody(tasks: tasks, day: day) == nil ? dateStamp(for: day) : nil
        })
        return makeDailyNotifications(
            prefix: "daily.morning",
            kind: .morningPlan,
            title: String(localized: "Start the day"),
            nowDate: nowDate,
            hour: preferences.morningHour,
            minute: preferences.morningMinute
        ) { day, _ in
            self.morningAgendaBody(tasks: tasks, day: day) ?? ""
        }
        .filter { request in
            quietStamps.contains(String(request.id.suffix(8))) == false
        }
    }

    private func makeNightlyRetrospectiveNotifications(
        tasks: [TaskDefinition],
        nowDate: Date,
        preferences: NotificationPreferences,
        exactDailyXPByDateKey: [String: Int]
    ) -> [LocalNotificationRequest] {
        let closedStamps = dayLoopClosureLog.closedStamps()
        return makeDailyNotifications(
            prefix: "daily.nightly",
            kind: .nightlyRetrospective,
            title: String(localized: "Close the day"),
            nowDate: nowDate,
            hour: preferences.nightlyHour,
            minute: preferences.nightlyMinute
        ) { _, _ in
            // Static on purpose: the body is written up to two days ahead,
            // so a done/left count would be stale by the time it fires.
            String(localized: "See what’s done and what’s left.")
        }
        .filter { request in
            let stamp = String(request.id.suffix(8))
            return closedStamps.contains(stamp) == false
        }
    }

    private func makeDailyNotifications(
        prefix: String,
        kind: LocalNotificationKind,
        title: String,
        nowDate: Date,
        hour: Int,
        minute: Int,
        bodyBuilder: (Date, String) -> String
    ) -> [LocalNotificationRequest] {
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
            let summaryKind: DailySummaryKind = (kind == .nightlyRetrospective) ? .nightly : .morning
            let compassFlow: DayCompassFlow = (summaryKind == .nightly) ? .eveningReview : .morningPlan
            let route: NotificationRoute = .dayCompass(flow: compassFlow, dateStamp: dateStamp)

            return LocalNotificationRequest(
                id: "\(prefix).\(dateStamp)",
                kind: kind,
                title: title,
                body: bodyBuilder(day, dateStamp),
                fireDate: fireDate,
                route: route
            )
        }
    }

    /// `nil` when the day has nothing due or slipped.
    private func morningAgendaBody(tasks: [TaskDefinition], day: Date) -> String? {
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

        guard let topTask = candidate.first else { return nil }

        var detail: [String] = []
        if highCount > 0 { detail.append(String(localized: "\(highCount) high priority")) }
        if overdueCount > 0 { detail.append(String(localized: "\(overdueCount) from earlier")) }
        let count = openCount == 1 ? String(localized: "1 task today") : String(localized: "\(openCount) tasks today")
        let summary = detail.isEmpty ? count : "\(count) (\(detail.joined(separator: ", ")))"
        return String(localized: "\(summary). First: “\(topTask.title)”")
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

        // Unused today; kept neutral in case the evening body turns dynamic.
        guard completedToday.isEmpty == false else {
            return String(localized: "Nothing done today")
        }

        let dueTodayIDs = Set(tasks.compactMap { task -> UUID? in
            guard let dueDate = task.dueDate, dueDate >= start, dueDate < end else { return nil }
            return task.id
        })
        let completedIDs = Set(completedToday.map(\.id))
        let totalCount = max(completedToday.count, dueTodayIDs.union(completedIDs).count)
        let doneCount = completedToday.count
        return String(localized: "\(doneCount) of \(totalCount) done today")
    }

    /// "Due at 3:30 PM", "Due tomorrow at 9:00 AM", "Due Thu, Feb 26": the
    /// line under a reminder, read against the day the reminder fires.
    private func dueLine(for task: TaskDefinition, relativeTo reference: Date) -> String {
        // No due date: the title says it all.
        guard let dueDate = task.dueDate else { return "" }
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let components = calendar.dateComponents([.hour, .minute], from: dueDate)
        let hasTime = (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
        let time = timeFormatter.string(from: dueDate)
        if calendar.isDate(dueDate, inSameDayAs: reference) {
            return hasTime ? String(localized: "Due at \(time)") : String(localized: "Due today")
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: reference),
           calendar.isDate(dueDate, inSameDayAs: tomorrow) {
            return hasTime ? String(localized: "Due tomorrow at \(time)") : String(localized: "Due tomorrow")
        }
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.timeZone = calendar.timeZone
        dayFormatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        let day = dayFormatter.string(from: dueDate)
        return hasTime ? String(localized: "Due \(day) at \(time)") : String(localized: "Due \(day)")
    }

    /// "From yesterday", "From 3 days ago": how old a task from earlier is,
    /// counted from the day the notification fires.
    private func fromEarlierLine(dueDate: Date?, relativeTo day: Date) -> String {
        guard let dueDate else { return String(localized: "From earlier") }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: dueDate),
            to: calendar.startOfDay(for: day)
        ).day ?? 0
        guard days > 1 else { return String(localized: "From yesterday") }
        return String(localized: "From \(days) days ago")
    }

    /// "25 min", "1 hr", "1 hr, 30 min" — the app's duration voice.
    static func durationText(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(max(1, minutes)) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) hr" : "\(hours) hr, \(rest) min"
    }

    private func dateStamp(for date: Date) -> String {
        stampFormatter.string(from: date)
    }

    private func fingerprint(for request: LocalNotificationRequest) -> NotificationFingerprint {
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

    private func fingerprint(for request: PendingNotificationRequest) -> NotificationFingerprint {
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
        to requests: [LocalNotificationRequest],
        nowDate: Date,
        preferences: NotificationPreferences
    ) -> [LocalNotificationRequest] {
        guard preferences.quietHoursEnabled else { return requests }

        return requests.map { request in
            guard shouldApplyQuietHours(for: request.kind, preferences: preferences),
                  isDateInQuietHours(request.fireDate, preferences: preferences)
            else {
                return request
            }

            let adjustedDate = nextAllowedDate(after: request.fireDate, nowDate: nowDate, preferences: preferences)
            guard adjustedDate != request.fireDate else { return request }

            return LocalNotificationRequest(
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
        for kind: LocalNotificationKind,
        preferences: NotificationPreferences
    ) -> Bool {
        switch kind {
        case .taskReminder, .dueSoon, .overdue, .snoozedTask:
            return preferences.quietHoursAppliesToTaskAlerts
        case .morningPlan, .nightlyRetrospective, .snoozedMorning, .snoozedNightly:
            return preferences.quietHoursAppliesToDailySummaries
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

    private func nextAllowedDate(
        after date: Date,
        nowDate: Date,
        preferences: NotificationPreferences
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
