import Foundation

#if canImport(EventKit)
import EventKit

public final class EventKitAppleRemindersProvider: AppleRemindersProviderProtocol {
    private struct ReminderPayload: Codable, Equatable, Hashable {
        var title: String
        var notes: String?
        var dueDate: Date?
        var completionDate: Date?
        var priority: Int
        var urlString: String?
        var alarmDates: [Date]
    }

    private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

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

    public func fetchLists(completion: @escaping (Result<[AppleReminderListSnapshot], Error>) -> Void) {
        let calendars = store.calendars(for: .reminder)
        let lists = calendars.map { AppleReminderListSnapshot(listID: $0.calendarIdentifier, title: $0.title) }
        completion(.success(lists))
    }

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

        targetReminder.title = snapshot.title
        targetReminder.notes = snapshot.notes
        targetReminder.priority = snapshot.priority
        targetReminder.url = snapshot.urlString.flatMap(URL.init(string:))
        targetReminder.calendar = calendar
        targetReminder.dueDateComponents = snapshot.dueDate.map { Calendar.current.dateComponents(in: TimeZone.current, from: $0) }

        if snapshot.isCompleted {
            targetReminder.isCompleted = true
            targetReminder.completionDate = snapshot.completionDate ?? Date()
        } else {
            targetReminder.isCompleted = false
            targetReminder.completionDate = nil
        }

        if snapshot.alarmDates.isEmpty {
            targetReminder.alarms = nil
        } else {
            targetReminder.alarms = snapshot.alarmDates.map(EKAlarm.init(absoluteDate:))
        }

        do {
            try store.save(targetReminder, commit: true)
            completion(.success(map(reminder: targetReminder)))
        } catch {
            completion(.failure(error))
        }
    }

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

    private func reminderCalendar(id: String) -> EKCalendar? {
        store.calendars(for: .reminder).first { $0.calendarIdentifier == id }
    }

    private func reminder(withItemID itemID: String) -> EKReminder? {
        store.calendarItem(withIdentifier: itemID) as? EKReminder
    }

    private func map(reminder: EKReminder) -> AppleReminderItemSnapshot {
        let alarmDates = (reminder.alarms ?? []).compactMap { $0.absoluteDate }
        let payload = ReminderPayload(
            title: reminder.title,
            notes: reminder.notes,
            dueDate: reminder.dueDateComponents?.date,
            completionDate: reminder.completionDate,
            priority: reminder.priority,
            urlString: reminder.url?.absoluteString,
            alarmDates: alarmDates
        )
        let payloadData = try? JSONEncoder().encode(payload)
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
}
#else
public final class EventKitAppleRemindersProvider: AppleRemindersProviderProtocol {
    public init() {}

    public func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    public func fetchLists(completion: @escaping (Result<[AppleReminderListSnapshot], Error>) -> Void) {
        completion(.success([]))
    }

    public func fetchReminders(listID: String, completion: @escaping (Result<[AppleReminderItemSnapshot], Error>) -> Void) {
        completion(.success([]))
    }

    public func upsertReminder(listID: String, snapshot: AppleReminderItemSnapshot, completion: @escaping (Result<AppleReminderItemSnapshot, Error>) -> Void) {
        completion(.success(snapshot))
    }

    public func deleteReminder(itemID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}
#endif
