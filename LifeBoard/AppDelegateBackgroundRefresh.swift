import UIKit
@preconcurrency import Dispatch
@preconcurrency import BackgroundTasks

extension AppDelegate {
    /// Executes registerBackgroundTasks.
    func registerBackgroundTasks() {
        guard Self.isRunningTests == false else { return }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: occurrenceRefreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleOccurrenceRefresh(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: remindersRefreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleRemindersRefresh(task: refreshTask)
        }
    }

    /// Executes scheduleOccurrenceRefresh.
    func scheduleOccurrenceRefresh() {
        guard Self.isRunningTests == false else { return }
        let request = BGAppRefreshTaskRequest(identifier: occurrenceRefreshTaskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date())
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logWarning(
                event: "bg_refresh_schedule_failed",
                message: "Failed to schedule V3 occurrence refresh task",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    /// Executes scheduleRemindersRefresh.
    func scheduleRemindersRefresh() {
        guard Self.isRunningTests == false else { return }
        let request = BGAppRefreshTaskRequest(identifier: remindersRefreshTaskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logWarning(
                event: "bg_reminders_schedule_failed",
                message: "Failed to schedule reminders background refresh task",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    /// Executes handleOccurrenceRefresh.
    private func handleOccurrenceRefresh(task: BGAppRefreshTask) {
        scheduleOccurrenceRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        let coordinator = CompositionRoot.shared.coordinator
        let generateUseCase = coordinator.generateOccurrences
        let maintain = coordinator.maintainOccurrences
        let purge = coordinator.purgeExpiredTombstones

        generateUseCase.execute(daysAhead: 14) { result in
            switch result {
            case .success:
                maintain.execute { maintainResult in
                    switch maintainResult {
                    case .success:
                        purge.execute { purgeResult in
                            switch purgeResult {
                            case .success:
                                task.setTaskCompleted(success: true)
                            case .failure(let error):
                                logWarning(
                                    event: "bg_tombstone_purge_failed",
                                    message: "Tombstone purge failed in background refresh",
                                    fields: ["error": error.localizedDescription]
                                )
                                task.setTaskCompleted(success: false)
                            }
                        }
                    case .failure(let error):
                        logWarning(
                            event: "bg_maintenance_failed",
                            message: "Occurrence maintenance failed in background refresh",
                            fields: ["error": error.localizedDescription]
                        )
                        task.setTaskCompleted(success: false)
                    }
                }
            case .failure(let error):
                logWarning(
                    event: "bg_refresh_execute_failed",
                    message: "Occurrence generation failed in background refresh",
                    fields: ["error": error.localizedDescription]
                )
                task.setTaskCompleted(success: false)
            }
        }
    }

    /// Executes handleRemindersRefresh.
    private func handleRemindersRefresh(task: BGAppRefreshTask) {
        scheduleRemindersRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        guard V2FeatureFlags.remindersSyncEnabled, V2FeatureFlags.remindersBackgroundRefreshEnabled else {
            task.setTaskCompleted(success: true)
            return
        }

        let reconcileUseCase = CompositionRoot.shared.coordinator.reconcileExternalReminders
        guard let externalRepository = CompositionRoot.shared.externalSyncRepository else {
            logWarning(
                event: "bg_reminders_missing_dependencies",
                message: "Skipping reminders refresh because V3 sync dependencies are unavailable",
                fields: [:]
            )
            task.setTaskCompleted(success: false)
            return
        }

        externalRepository.fetchContainerMappings { result in
            switch result {
            case .failure(let error):
                logWarning(
                    event: "bg_reminders_fetch_mappings_failed",
                    message: "Failed to load external container mappings for reminders refresh",
                    fields: ["error": error.localizedDescription]
                )
                task.setTaskCompleted(success: false)
            case .success(let mappings):
                let syncedMappings = mappings.filter { $0.provider == "apple_reminders" && $0.syncEnabled }
                guard syncedMappings.isEmpty == false else {
                    task.setTaskCompleted(success: true)
                    return
                }

                Self.processReminderReconcileQueue(
                    mappings: syncedMappings,
                    index: 0,
                    reconcileUseCase: reconcileUseCase,
                    externalRepository: externalRepository,
                    failureCount: 0
                ) { failureCount in
                    task.setTaskCompleted(success: failureCount == 0)
                }
            }
        }
    }

    /// Executes processReminderReconcileQueue.
    nonisolated private static func processReminderReconcileQueue(
        mappings: [ExternalContainerMapDefinition],
        index: Int,
        reconcileUseCase: ReconcileExternalRemindersUseCase,
        externalRepository: ExternalSyncRepositoryProtocol,
        failureCount: Int,
        completion: @escaping @Sendable (Int) -> Void
    ) {
        guard index < mappings.count else {
            completion(failureCount)
            return
        }

        let mapping = mappings[index]
        let completionGate = ReminderReconcileCompletionGate()
        let timeoutItem = DispatchWorkItem {
            guard completionGate.claim() else { return }
            logWarning(
                event: "bg_reminders_project_timeout",
                message: "Project reconcile timed out in background reminders refresh",
                fields: [
                    "project_id": mapping.projectID.uuidString,
                    "external_container_id": mapping.externalContainerID
                ]
            )
            Self.processReminderReconcileQueue(
                mappings: mappings,
                index: index + 1,
                reconcileUseCase: reconcileUseCase,
                externalRepository: externalRepository,
                failureCount: failureCount + 1,
                completion: completion
            )
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 55, execute: timeoutItem)

        reconcileUseCase.reconcileProject(projectID: mapping.projectID) { result in
            guard completionGate.claim() else { return }
            timeoutItem.cancel()

            switch result {
            case .success:
                externalRepository.upsertContainerMapping(
                    provider: mapping.provider,
                    projectID: mapping.projectID
                ) { existing in
                    var resolved = existing ?? mapping
                    resolved.lastSyncAt = Date()
                    resolved.syncEnabled = true
                    return resolved
                } completion: { _ in
                    Self.processReminderReconcileQueue(
                        mappings: mappings,
                        index: index + 1,
                        reconcileUseCase: reconcileUseCase,
                        externalRepository: externalRepository,
                        failureCount: failureCount,
                        completion: completion
                    )
                }
            case .failure(let error):
                logWarning(
                    event: "bg_reminders_project_failed",
                    message: "Project reconcile failed in background reminders refresh",
                    fields: [
                        "project_id": mapping.projectID.uuidString,
                        "external_container_id": mapping.externalContainerID,
                        "error": error.localizedDescription
                    ]
                )
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    Self.processReminderReconcileQueue(
                        mappings: mappings,
                        index: index + 1,
                        reconcileUseCase: reconcileUseCase,
                        externalRepository: externalRepository,
                        failureCount: failureCount + 1,
                        completion: completion
                    )
                }
            }
        }
    }
}
