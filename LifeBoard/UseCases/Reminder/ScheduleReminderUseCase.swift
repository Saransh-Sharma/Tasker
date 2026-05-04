import Foundation

private final class ReminderPersistenceAccumulator<State: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State
    private var firstError: Error?

    init(_ state: State) {
        self.state = state
    }

    func update(_ body: (inout State) -> Void) {
        lock.lock()
        body(&state)
        lock.unlock()
    }

    func record(_ error: Error) {
        lock.lock()
        if firstError == nil {
            firstError = error
        }
        lock.unlock()
    }

    func result() -> Result<State, Error> {
        lock.lock()
        let state = state
        let firstError = firstError
        lock.unlock()

        if let firstError {
            return .failure(firstError)
        }
        return .success(state)
    }
}

public final class ScheduleReminderUseCase: @unchecked Sendable {
    private let repository: ReminderRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?

    /// Initializes a new instance.
    public init(repository: ReminderRepositoryProtocol, notificationService: NotificationServiceProtocol? = nil) {
        self.repository = repository
        self.notificationService = notificationService
    }

    /// Executes execute.
    public func execute(
        reminder: ReminderDefinition,
        triggers: [ReminderTriggerDefinition],
        referenceDate: Date? = nil,
        completion: @escaping @Sendable (Result<ReminderDefinition, Error>) -> Void
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

    /// Executes execute.
    public func execute(reminder: ReminderDefinition, completion: @escaping @Sendable (Result<ReminderDefinition, Error>) -> Void) {
        execute(reminder: reminder, triggers: [], referenceDate: nil, completion: completion)
    }

    /// Executes acknowledgeDelivery.
    public func acknowledgeDelivery(
        reminderID: UUID,
        deliveryID: UUID,
        completion: @escaping @Sendable (Result<ReminderDeliveryDefinition, Error>) -> Void
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

    /// Executes snoozeDelivery.
    public func snoozeDelivery(
        reminderID: UUID,
        deliveryID: UUID,
        until: Date,
        completion: @escaping @Sendable (Result<ReminderDeliveryDefinition, Error>) -> Void
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

    /// Executes persistTriggersAndDeliveries.
    private func persistTriggersAndDeliveries(
        reminder: ReminderDefinition,
        triggers: [ReminderTriggerDefinition],
        referenceDate: Date?,
        completion: @escaping @Sendable (Result<ReminderDefinition, Error>) -> Void
    ) {
        guard triggers.isEmpty == false else {
            completion(.success(reminder))
            return
        }

        let group = DispatchGroup()
        let accumulator = ReminderPersistenceAccumulator([ReminderTriggerDefinition]())

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
                switch result {
                case .success(let savedTrigger):
                    accumulator.update { $0.append(savedTrigger) }
                case .failure(let error):
                    accumulator.record(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            let savedTriggers: [ReminderTriggerDefinition]
            switch accumulator.result() {
            case .failure(let firstError):
                completion(.failure(firstError))
                return
            case .success(let triggers):
                savedTriggers = triggers
            }

            self.persistDeliveries(
                reminder: reminder,
                triggers: savedTriggers,
                referenceDate: referenceDate,
                completion: completion
            )
        }
    }

    /// Executes persistDeliveries.
    private func persistDeliveries(
        reminder: ReminderDefinition,
        triggers: [ReminderTriggerDefinition],
        referenceDate: Date?,
        completion: @escaping @Sendable (Result<ReminderDefinition, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let accumulator = ReminderPersistenceAccumulator(())

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
                    accumulator.record(error)
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
            switch accumulator.result() {
            case .failure(let firstError):
                completion(.failure(firstError))
            case .success:
                completion(.success(reminder))
            }
        }
    }

    /// Executes resolveFireDate.
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
