import Foundation

#if canImport(EventKit)
@preconcurrency import EventKit

private final class EventKitReminderStoreBox: @unchecked Sendable {
    let store: EKEventStore

    init(store: EKEventStore) {
        self.store = store
    }
}

/// EventKit reminders wrapper; `EKEventStore` access is confined to the worker queue or EventKit callbacks.
public final class EventKitAppleRemindersProvider: AppleRemindersProviderProtocol, @unchecked Sendable {
    private let storeBox: EventKitReminderStoreBox
    private let workerQueue: DispatchQueue
    private let mergeEngine = ReminderMergeEngine()

    /// Initializes a new instance.
    public init(
        store: EKEventStore = EKEventStore(),
        workerQueue: DispatchQueue = DispatchQueue(
            label: "com.tasker.reminders.eventkit-provider",
            qos: .userInitiated
        )
    ) {
        self.storeBox = EventKitReminderStoreBox(store: store)
        self.workerQueue = workerQueue
    }

    /// Executes requestAccess.
    public func requestAccess(completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        workerQueue.async { [storeBox] in
            let store = storeBox.store
            if #available(iOS 17.0, macOS 14.0, *) {
                store.requestFullAccessToReminders { granted, error in
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(granted))
                    }
                }
            } else {
                store.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(granted))
                    }
                }
            }
        }
    }

    /// Executes fetchLists.
    public func fetchLists(completion: @escaping @Sendable (Result<[AppleReminderListSnapshot], Error>) -> Void) {
        workerQueue.async { [storeBox] in
            let calendars = storeBox.store.calendars(for: .reminder)
            let lists = calendars.map { AppleReminderListSnapshot(listID: $0.calendarIdentifier, title: $0.title) }
            completion(.success(lists))
        }
    }

    /// Executes fetchReminders.
    public func fetchReminders(listID: String, completion: @escaping @Sendable (Result<[AppleReminderItemSnapshot], Error>) -> Void) {
        workerQueue.async { [storeBox, self] in
            let store = storeBox.store
            guard let calendar = Self.reminderCalendar(id: listID, store: store) else {
                completion(.success([]))
                return
            }

            let predicate = store.predicateForReminders(in: [calendar])
            store.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).map { self.map(reminder: $0) }
                completion(.success(mapped))
            }
        }
    }

    /// Executes upsertReminder.
    public func upsertReminder(listID: String, snapshot: AppleReminderItemSnapshot, completion: @escaping @Sendable (Result<AppleReminderItemSnapshot, Error>) -> Void) {
        workerQueue.async { [storeBox, self] in
            let store = storeBox.store
            guard let calendar = Self.reminderCalendar(id: listID, store: store) else {
                let error = NSError(
                    domain: "EventKitAppleRemindersProvider",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Reminder list not found: \(listID)"]
                )
                completion(.failure(error))
                return
            }

            let targetReminder: EKReminder
            if let existing = Self.reminder(withItemID: snapshot.itemID, store: store) {
                targetReminder = existing
            } else {
                targetReminder = EKReminder(eventStore: store)
                targetReminder.calendar = calendar
            }

            let payloadEnvelope = decodeMergeEnvelope(snapshot.payloadData)
            let mergedKnownFields = ReminderMergeEnvelope.KnownFields(
                title: snapshot.title,
                notes: snapshot.notes,
                dueDate: snapshot.dueDate,
                completionDate: snapshot.completionDate,
                isCompleted: snapshot.isCompleted,
                priority: snapshot.priority,
                urlString: snapshot.urlString ?? payloadEnvelope?.known.urlString,
                alarmDates: snapshot.alarmDates.isEmpty ? (payloadEnvelope?.known.alarmDates ?? []) : snapshot.alarmDates
            )

            targetReminder.title = mergedKnownFields.title
            targetReminder.notes = mergedKnownFields.notes
            targetReminder.priority = mergedKnownFields.priority
            targetReminder.url = mergedKnownFields.urlString.flatMap(URL.init(string:))
            targetReminder.calendar = calendar
            targetReminder.dueDateComponents = mergedKnownFields.dueDate.map {
                Calendar.current.dateComponents(in: TimeZone.current, from: $0)
            }

            if mergedKnownFields.isCompleted {
                targetReminder.isCompleted = true
                targetReminder.completionDate = mergedKnownFields.completionDate ?? Date()
            } else {
                targetReminder.isCompleted = false
                targetReminder.completionDate = nil
            }

            if mergedKnownFields.alarmDates.isEmpty {
                targetReminder.alarms = nil
            } else {
                targetReminder.alarms = mergedKnownFields.alarmDates.map(EKAlarm.init(absoluteDate:))
            }

            do {
                try store.save(targetReminder, commit: true)
                completion(.success(map(
                    reminder: targetReminder,
                    passthroughData: payloadEnvelope?.passthroughData
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes deleteReminder.
    public func deleteReminder(itemID: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        workerQueue.async { [storeBox] in
            let store = storeBox.store
            guard let reminder = Self.reminder(withItemID: itemID, store: store) else {
                completion(.success(()))
                return
            }

            do {
                try store.remove(reminder, commit: true)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes reminderCalendar.
    private static func reminderCalendar(id: String, store: EKEventStore) -> EKCalendar? {
        store.calendars(for: .reminder).first { $0.calendarIdentifier == id }
    }

    /// Executes reminder.
    private static func reminder(withItemID itemID: String, store: EKEventStore) -> EKReminder? {
        store.calendarItem(withIdentifier: itemID) as? EKReminder
    }

    /// Executes map.
    private func map(reminder: EKReminder, passthroughData: Data? = nil) -> AppleReminderItemSnapshot {
        let alarmDates = (reminder.alarms ?? []).compactMap { $0.absoluteDate }
        let known = ReminderMergeEnvelope.KnownFields(
            title: reminder.title,
            notes: reminder.notes,
            dueDate: reminder.dueDateComponents?.date,
            completionDate: reminder.completionDate,
            isCompleted: reminder.isCompleted,
            priority: reminder.priority,
            urlString: reminder.url?.absoluteString,
            alarmDates: alarmDates
        )
        let payloadData = encodeMergeEnvelope(
            known: known,
            passthroughData: passthroughData
        )
        return AppleReminderItemSnapshot(
            itemID: reminder.calendarItemIdentifier,
            calendarID: reminder.calendar.calendarIdentifier,
            title: reminder.title,
            notes: reminder.notes,
            dueDate: reminder.dueDateComponents?.date,
            completionDate: reminder.completionDate,
            isCompleted: reminder.isCompleted,
            priority: reminder.priority,
            urlString: reminder.url?.absoluteString,
            alarmDates: alarmDates,
            lastModifiedAt: reminder.lastModifiedDate,
            payloadData: payloadData
        )
    }

    /// Executes decodeMergeEnvelope.
    private func decodeMergeEnvelope(_ data: Data?) -> ReminderMergeEnvelope? {
        mergeEngine.decodeEnvelope(data: data)
    }

    /// Executes encodeMergeEnvelope.
    private func encodeMergeEnvelope(
        known: ReminderMergeEnvelope.KnownFields,
        passthroughData: Data?
    ) -> Data? {
        mergeEngine.encodeEnvelope(
            known: known,
            preferredPassthroughData: passthroughData,
            fallbackPassthroughData: nil
        )
    }
}
#else
public final class EventKitAppleRemindersProvider: AppleRemindersProviderProtocol, @unchecked Sendable {
    /// Initializes a new instance.
    public init() {}

    /// Executes requestAccess.
    public func requestAccess(completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    /// Executes fetchLists.
    public func fetchLists(completion: @escaping @Sendable (Result<[AppleReminderListSnapshot], Error>) -> Void) {
        completion(.success([]))
    }

    /// Executes fetchReminders.
    public func fetchReminders(listID: String, completion: @escaping @Sendable (Result<[AppleReminderItemSnapshot], Error>) -> Void) {
        completion(.success([]))
    }

    /// Executes upsertReminder.
    public func upsertReminder(listID: String, snapshot: AppleReminderItemSnapshot, completion: @escaping @Sendable (Result<AppleReminderItemSnapshot, Error>) -> Void) {
        completion(.success(snapshot))
    }

    /// Executes deleteReminder.
    public func deleteReminder(itemID: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}
#endif
