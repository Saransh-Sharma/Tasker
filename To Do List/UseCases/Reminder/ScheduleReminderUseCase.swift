import Foundation

public final class ScheduleReminderUseCase {
    private let repository: ReminderRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?

    public init(repository: ReminderRepositoryProtocol, notificationService: NotificationServiceProtocol? = nil) {
        self.repository = repository
        self.notificationService = notificationService
    }

    public func execute(
        reminder: ReminderDefinition,
        triggers: [ReminderTriggerDefinition],
        referenceDate: Date? = nil,
        completion: @escaping (Result<ReminderDefinition, Error>) -> Void
    ) {
        repository.saveReminder(reminder) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let saved):
                self.persistTriggersAndDeliveries(
                    reminder: saved,
                    triggers: triggers,
                    referenceDate: referenceDate,
                    completion: completion
                )
            }
        }
    }

    public func execute(reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void) {
        execute(reminder: reminder, triggers: [], referenceDate: nil, completion: completion)
    }

    public func acknowledgeDelivery(
        reminderID: UUID,
        deliveryID: UUID,
        completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void
    ) {
        repository.fetchDeliveries(reminderID: reminderID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let deliveries):
                guard var delivery = deliveries.first(where: { $0.id == deliveryID }) else {
                    completion(.failure(NSError(
                        domain: "ScheduleReminderUseCase",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Reminder delivery not found"]
                    )))
                    return
                }
                delivery.status = "acked"
                delivery.ackAt = Date()
                self.repository.updateDelivery(delivery, completion: completion)
            }
        }
    }

    public func snoozeDelivery(
        reminderID: UUID,
        deliveryID: UUID,
        until: Date,
        completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void
    ) {
        repository.fetchDeliveries(reminderID: reminderID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let deliveries):
                guard var delivery = deliveries.first(where: { $0.id == deliveryID }) else {
                    completion(.failure(NSError(
                        domain: "ScheduleReminderUseCase",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Reminder delivery not found"]
                    )))
                    return
                }
                delivery.status = "snoozed"
                delivery.snoozedUntil = until
                if V2FeatureFlags.remindersSyncEnabled, let notificationService = self.notificationService {
                    notificationService.scheduleTaskReminder(
                        taskId: reminderID,
                        taskName: "Task Reminder",
                        at: until
                    )
                }
                self.repository.updateDelivery(delivery, completion: completion)
            }
        }
    }

    private func persistTriggersAndDeliveries(
        reminder: ReminderDefinition,
        triggers: [ReminderTriggerDefinition],
        referenceDate: Date?,
        completion: @escaping (Result<ReminderDefinition, Error>) -> Void
    ) {
        guard triggers.isEmpty == false else {
            completion(.success(reminder))
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?
        var savedTriggers: [ReminderTriggerDefinition] = []

        for trigger in triggers {
            var normalized = trigger
            normalized = ReminderTriggerDefinition(
                id: normalized.id,
                reminderID: reminder.id,
                triggerType: normalized.triggerType,
                fireAt: normalized.fireAt,
                offsetSeconds: normalized.offsetSeconds,
                locationPayloadData: normalized.locationPayloadData,
                createdAt: normalized.createdAt
            )
            group.enter()
            repository.saveTrigger(normalized) { result in
                lock.lock()
                switch result {
                case .success(let savedTrigger):
                    savedTriggers.append(savedTrigger)
                case .failure(let error):
                    firstError = firstError ?? error
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            if let firstError {
                completion(.failure(firstError))
                return
            }

            self.persistDeliveries(
                reminder: reminder,
                triggers: savedTriggers,
                referenceDate: referenceDate,
                completion: completion
            )
        }
    }

    private func persistDeliveries(
        reminder: ReminderDefinition,
        triggers: [ReminderTriggerDefinition],
        referenceDate: Date?,
        completion: @escaping (Result<ReminderDefinition, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for trigger in triggers {
            let fireDate = resolveFireDate(
                trigger: trigger,
                referenceDate: referenceDate ?? reminder.updatedAt
            )
            let delivery = ReminderDeliveryDefinition(
                id: UUID(),
                reminderID: reminder.id,
                triggerID: trigger.id,
                status: fireDate == nil ? "queued" : "scheduled",
                scheduledAt: fireDate,
                sentAt: nil,
                ackAt: nil,
                snoozedUntil: nil,
                errorCode: nil,
                createdAt: Date()
            )
            group.enter()
            repository.saveDelivery(delivery) { result in
                switch result {
                case .failure(let error):
                    lock.lock()
                    firstError = firstError ?? error
                    lock.unlock()
                case .success:
                    if let fireDate, V2FeatureFlags.remindersSyncEnabled, let notificationService = self.notificationService {
                        notificationService.scheduleTaskReminder(
                            taskId: reminder.sourceID,
                            taskName: "Task Reminder",
                            at: fireDate
                        )
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(reminder))
            }
        }
    }

    private func resolveFireDate(
        trigger: ReminderTriggerDefinition,
        referenceDate: Date
    ) -> Date? {
        switch trigger.triggerType {
        case .absolute:
            return trigger.fireAt
        case .relative:
            guard let offsetSeconds = trigger.offsetSeconds else { return nil }
            return referenceDate.addingTimeInterval(TimeInterval(offsetSeconds))
        case .location:
            return nil
        }
    }
}
