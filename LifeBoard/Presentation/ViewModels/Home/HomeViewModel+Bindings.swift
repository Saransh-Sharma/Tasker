//
//  HomeViewModelCoreBindings.swift
//  LifeBoard
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

extension HomeViewModel {
    // MARK: - Public Methods

    /// Load tasks for the selected date.

    public func updateTask(
        taskID: UUID,
        request: UpdateTaskDefinitionRequest,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        var normalizedRequest = request
        normalizedRequest.updatedAt = Date()
        logDebug(
            "HOME_TASK_UPDATE request task_id=\(taskID.uuidString) " +
            "due=\(request.dueDate?.description ?? "nil") clear_due=\(request.clearDueDate) " +
            "scheduled_start=\(request.scheduledStartAt?.description ?? "nil") clear_start=\(request.clearScheduledStartAt) " +
            "scheduled_end=\(request.scheduledEndAt?.description ?? "nil") clear_end=\(request.clearScheduledEndAt) " +
            "is_all_day=\(request.isAllDay.map(String.init(describing:)) ?? "nil")"
        )
        useCaseCoordinator.updateTaskDefinition.execute(request: normalizedRequest) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let task):
                    logDebug(
                        "HOME_TASK_UPDATE success task_id=\(task.id.uuidString) " +
                        "due=\(task.dueDate?.description ?? "nil") " +
                        "scheduled_start=\(task.scheduledStartAt?.description ?? "nil") " +
                        "scheduled_end=\(task.scheduledEndAt?.description ?? "nil") " +
                        "is_all_day=\(task.isAllDay)"
                    )
                    self?.enqueueReload(
                        source: "update_task",
                        reason: self?.mutationReason(for: request) ?? .updated,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(task))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes loadTaskDetailMetadata.

    func setupBindings() {
        installResumeForegroundObserver()

        calendarIntegrationService.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.homeCalendarSnapshot = Self.buildHomeCalendarSnapshot(
                    from: snapshot,
                    selectedDate: self.selectedDate,
                    accessAction: self.calendarIntegrationService.accessAction(for: snapshot.authorizationStatus)
                )
            }
            .store(in: &cancellables)

        $selectedDate
            .removeDuplicates(by: Self.isSameCalendarDay(_:_:))
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] selectedDate in
                guard let self else { return }
                self.homeCalendarSnapshot = Self.buildHomeCalendarSnapshot(
                    from: self.calendarIntegrationService.snapshot,
                    selectedDate: selectedDate,
                    accessAction: self.calendarIntegrationService.accessAction(
                        for: self.calendarIntegrationService.snapshot.authorizationStatus
                    )
                )
                self.calendarIntegrationService.refreshContext(
                    referenceDate: selectedDate,
                    reason: "home_selected_date_changed"
                )
            }
            .store(in: &cancellables)

        let taskMutationPublishers: [AnyPublisher<HomeTaskReloadNotificationEvent, Never>] = [
            NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated"))
                .map { _ in
                    HomeTaskReloadNotificationEvent(
                        source: "notification_task_created",
                        reason: .created,
                        notificationSource: nil,
                        includeAnalytics: false,
                        repostEvent: true,
                        isCompletionChange: false,
                        isStructured: false
                    )
                }
                .eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: NSNotification.Name("TaskUpdated"))
                .map { _ in
                    HomeTaskReloadNotificationEvent(
                        source: "notification_task_updated",
                        reason: .updated,
                        notificationSource: nil,
                        includeAnalytics: false,
                        repostEvent: true,
                        isCompletionChange: false,
                        isStructured: false
                    )
                }
                .eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: NSNotification.Name("TaskDeleted"))
                .map { _ in
                    HomeTaskReloadNotificationEvent(
                        source: "notification_task_deleted",
                        reason: .deleted,
                        notificationSource: nil,
                        includeAnalytics: false,
                        repostEvent: true,
                        isCompletionChange: false,
                        isStructured: false
                    )
                }
                .eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: NSNotification.Name("TaskCompletionChanged"))
                .map { _ in
                    HomeTaskReloadNotificationEvent(
                        source: "notification_task_completion_changed",
                        reason: .bulkChanged,
                        notificationSource: nil,
                        includeAnalytics: true,
                        repostEvent: true,
                        isCompletionChange: true,
                        isStructured: false
                    )
                }
                .eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: .homeTaskMutation)
                .map { notification in
                    let payload = HomeTaskMutationPayload(notification: notification)
                    let reasonRaw = notification.userInfo?["reason"] as? String
                    return HomeTaskReloadNotificationEvent(
                        source: "notification_home_task_mutation",
                        reason: payload?.reason ?? reasonRaw.flatMap(HomeTaskMutationEvent.init(rawValue:)) ?? .updated,
                        notificationSource: payload?.source ?? notification.userInfo?["source"] as? String,
                        includeAnalytics: true,
                        repostEvent: false,
                        isCompletionChange: false,
                        isStructured: true
                    )
                }
                .eraseToAnyPublisher()
        ]

        // HomeViewModel remains the task-list reload owner for now. Compatibility
        // notifications are bridged into the structured reload window until all
        // producers emit only HomeTaskMutationEvent.
        Publishers.MergeMany(taskMutationPublishers)
            .receive(on: RunLoop.main)
            .collect(.byTime(RunLoop.main, .milliseconds(max(completionNotificationDebounceMS, mutationNotificationDebounceMS))))
            .sink { [weak self] events in
                guard let self else { return }
                let eligibleEvents = events.filter { event in
                    guard event.notificationSource != Self.mutationNotificationSource else { return false }
                    if event.isStructured == false,
                       let suppressUntil = self.suppressTaskReloadsForHabitMutationUntil,
                       Date() <= suppressUntil {
                        logDebug("HOME_ROW_STATE vm.notification_suppressed source=\(event.source) reason=habit_mutation")
                        return false
                    }
                    if event.isCompletionChange,
                       let suppressUntil = self.suppressCompletionReloadUntil,
                       Date() <= suppressUntil {
                        logDebug("HOME_ROW_STATE vm.notification_suppressed source=TaskCompletionChanged")
                        return false
                    }
                    return true
                }
                guard let selectedEvent = eligibleEvents.last(where: \.isStructured) ?? eligibleEvents.last else {
                    return
                }
                self.enqueueReload(
                    source: selectedEvent.source,
                    reason: selectedEvent.reason,
                    invalidateCaches: true,
                    includeAnalytics: eligibleEvents.contains(where: \.includeAnalytics),
                    repostEvent: selectedEvent.repostEvent
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gamificationLedgerDidMutate)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let mutation = notification.gamificationLedgerMutation else { return }
                self?.handleGamificationLedgerMutation(mutation)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .homeHabitMutation)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let mutation = self.habitMutationNotification(from: notification.object) else {
                    return
                }
                if self.consumeSelfOriginatedHabitMutationContext(mutation.context) {
                    logDebug("HOME_HABIT_STATE vm.notification_suppressed id=\(mutation.habitID.uuidString)")
                    return
                }
                self.reconcileHabitMutation(habitID: mutation.habitID, on: self.selectedDate)
            }
            .store(in: &cancellables)
    }

    /// Executes setTaskCompletion.

    func restorePinnedFocusTaskIDs() {
        let persistedIDs = userDefaults
            .stringArray(forKey: Self.pinnedFocusTaskIDsKey)?
            .compactMap(UUID.init(uuidString:))
            ?? []
        pinnedFocusTaskIDs = normalizedPinnedFocusTaskIDs(persistedIDs)
    }

    /// Executes persistPinnedFocusTaskIDs.

    func restoreRecentShuffleTaskIDs() {
        recentShuffledFocusTaskIDs = userDefaults
            .stringArray(forKey: Self.recentShuffleTaskIDsKey)?
            .compactMap(UUID.init(uuidString:))
            ?? []
    }

    /// Executes persistRecentShuffleTaskIDs.
}
