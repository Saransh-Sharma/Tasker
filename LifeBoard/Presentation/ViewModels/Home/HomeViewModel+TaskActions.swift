//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
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
    func loadTodayTasks(generation: Int) {
        applySelectedDay(
            Date(),
            source: .backToToday,
            trackAnalytics: false,
            generation: generation,
            forceReload: true
        )
    }

    /// Executes scheduleRecurringTopUpIfNeeded.

    public func toggleTaskCompletion(_ task: TaskDefinition) {
        setTaskCompletion(
            taskID: task.id,
            to: !task.isComplete,
            taskSnapshot: task
        ) { _ in }
    }

    public func setTaskCompletion(
        taskID: UUID,
        to desiredCompletion: Bool,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        setTaskCompletion(
            taskID: taskID,
            to: desiredCompletion,
            taskSnapshot: currentTaskSnapshot(for: taskID),
            completion: completion
        )
    }

    /// Create a new task.

    public func createTask(request: CreateTaskDefinitionRequest) {
        useCaseCoordinator.createTaskDefinition.execute(request: request) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.enqueueReload(
                        source: "create_task",
                        reason: .created,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Delete a task.

    public func deleteTask(_ task: TaskDefinition) {
        deleteTask(taskID: task.id) { _ in }
    }

    /// Executes deleteTask.

    public func deleteTask(
        taskID: UUID,
        scope: TaskDeleteScope = .single,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        useCaseCoordinator.deleteTaskDefinition.execute(taskID: taskID, scope: scope) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.removePinnedFocusTaskID(taskID)
                    self?.enqueueReload(
                        source: "delete_task",
                        reason: .deleted,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(()))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    public func restoreDeletedTaskSnapshot(
        _ task: TaskDefinition,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.taskDefinitionRepository.create(task) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let restoredTask):
                    self?.enqueueReload(
                        source: "restore_deleted_task",
                        reason: .bulkChanged,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(restoredTask))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Reschedule a task.

    public func rescheduleTask(_ task: TaskDefinition, to newDate: Date?) {
        rescheduleTask(taskID: task.id, to: newDate) { _ in }
    }

    /// Executes rescheduleTask.

    public func rescheduleTask(
        taskID: UUID,
        to newDate: Date?,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.rescheduleTaskDefinition.execute(taskID: taskID, newDate: newDate) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let task):
                    self?.enqueueReload(
                        source: "reschedule_task",
                        reason: .rescheduled,
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

    /// Executes updateTask.

    public func clearHabitRecoveryReflectionPrompt() {
        habitRecoveryReflectionPrompt = nil
    }

    /// Executes loadTaskChildren.

    public func loadTaskChildren(
        parentTaskID: UUID,
        completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void
    ) {
        useCaseCoordinator.getTaskChildren.execute(parentTaskID: parentTaskID) { result in
            Task { @MainActor in
                completion(result)
            }
        }
    }

    /// Executes createTaskDefinition.
}
