import Foundation

#if canImport(EventKit)
import EventKit

public final class EventKitAppleRemindersProvider: AppleRemindersProviderProtocol {
    private let store: EKEventStore
    private let mergeEngine = ReminderMergeEngine()

    /// Initializes a new instance.
    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    /// Executes requestAccess.
    public func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
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

    /// Executes fetchLists.
    public func fetchLists(completion: @escaping (Result<[AppleReminderListSnapshot], Error>) -> Void) {
        let calendars = store.calendars(for: .reminder)
        let lists = calendars.map { AppleReminderListSnapshot(listID: $0.calendarIdentifier, title: $0.title) }
        completion(.success(lists))
    }

    /// Executes fetchReminders.
    public func fetchReminders(listID: String, completion: @escaping (Result<[AppleReminderItemSnapshot], Error>) -> Void) {
        guard let calendar = reminderCalendar(id: listID) else {
            completion(.success([]))
            return
        }

        let predicate = store.predicateForReminders(in: [calendar])
        store.fetchReminders(matching: predicate) { reminders in
            let mapped = (reminders ?? []).map { self.map(reminder: $0) }
            completion(.success(mapped))
        }
    }

    /// Executes upsertReminder.
    public func upsertReminder(listID: String, snapshot: AppleReminderItemSnapshot, completion: @escaping (Result<AppleReminderItemSnapshot, Error>) -> Void) {
        guard let calendar = reminderCalendar(id: listID) else {
            let error = NSError(
                domain: "EventKitAppleRemindersProvider",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Reminder list not found: \(listID)"]
            )
            completion(.failure(error))
            return
        }

        let targetReminder: EKReminder
        if let existing = reminder(withItemID: snapshot.itemID) {
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

    /// Executes deleteReminder.
    public func deleteReminder(itemID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let reminder = reminder(withItemID: itemID) else {
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

    /// Executes reminderCalendar.
    private func reminderCalendar(id: String) -> EKCalendar? {
        store.calendars(for: .reminder).first { $0.calendarIdentifier == id }
    }

    /// Executes reminder.
    private func reminder(withItemID itemID: String) -> EKReminder? {
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
public final class EventKitAppleRemindersProvider: AppleRemindersProviderProtocol {
    /// Initializes a new instance.
    public init() {}

    /// Executes requestAccess.
    public func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    /// Executes fetchLists.
    public func fetchLists(completion: @escaping (Result<[AppleReminderListSnapshot], Error>) -> Void) {
        completion(.success([]))
    }

    /// Executes fetchReminders.
    public func fetchReminders(listID: String, completion: @escaping (Result<[AppleReminderItemSnapshot], Error>) -> Void) {
        completion(.success([]))
    }

    /// Executes upsertReminder.
    public func upsertReminder(listID: String, snapshot: AppleReminderItemSnapshot, completion: @escaping (Result<AppleReminderItemSnapshot, Error>) -> Void) {
        completion(.success(snapshot))
    }

    /// Executes deleteReminder.
    public func deleteReminder(itemID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}
#endif
