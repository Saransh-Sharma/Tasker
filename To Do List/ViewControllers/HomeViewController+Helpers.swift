//
//  HomeViewController+Helpers.swift
//  Tasker
//
//  Helper methods for HomeViewController - Clean Architecture
//

import UIKit

extension HomeViewController {

    // MARK: - Task Fetching Helpers (Clean Architecture)

    /// Get task from TaskListItem using task UUID lookup
    /// Maps TaskListItem -> Task (domain model) via HomeViewModel
    func getTaskFromTaskListItem(_ item: TaskListItem) -> NTask? {
        // TODO: This is a temporary bridge. Ideally, we should refactor the UI
        // to work directly with domain Task models instead of NTask entities.
        // For now, we'll use the task UUID stored in TaskListItem to look up the entity.

        guard let taskID = item.taskID else {
            print("⚠️ TaskListItem missing taskID, cannot look up task")
            return nil
        }

        // Use repository to fetch the task entity
        // This is a synchronous operation that should be migrated to async
        var foundTask: NTask?
        taskRepository.fetchTask(by: taskID) { result in
            if case .success(let task) = result {
                foundTask = task
            }
        }

        return foundTask
    }

    /// Delete task using Clean Architecture
    /// Delegates to HomeViewModel which uses UseCaseCoordinator
    /// TODO: Re-enable when ViewModel is available
    func deleteTaskDirectly(_ task: NTask) {
        // guard let viewModel = viewModel,
        //       let taskID = task.taskID else {
        //     print("⚠️ Cannot delete task: ViewModel or taskID missing")
        //     return
        // }
        //
        // // Convert NTask to domain Task for deletion
        // let domainTask = TaskMapper.toDomain(from: task)
        //
        // // Use ViewModel to delete task
        // viewModel.deleteTask(domainTask)

        print("⚠️ deleteTaskDirectly disabled - TODO: Re-enable when ViewModel is available")
        print("⚠️ Falling back to legacy delete method")
        // Use legacy taskRepository for now
        if let taskID = task.taskID {
            taskRepository.deleteTask(by: taskID) { result in
                switch result {
                case .success:
                    print("✅ Task deleted via legacy repository")
                case .failure(let error):
                    print("❌ Failed to delete task: \(error)")
                }
            }
        }
    }

    /// Reschedule task using Clean Architecture
    /// Delegates to HomeViewModel which uses UseCaseCoordinator
    /// TODO: Re-enable when ViewModel is available
    func rescheduleTaskDirectly(_ task: NTask, to date: Date) {
        // guard let viewModel = viewModel,
        //       let taskID = task.taskID else {
        //     print("⚠️ Cannot reschedule task: ViewModel or taskID missing")
        //     return
        // }
        //
        // // Convert NTask to domain Task for rescheduling
        // let domainTask = TaskMapper.toDomain(from: task)
        //
        // // Use ViewModel to reschedule task
        // viewModel.rescheduleTask(domainTask, to: date)

        print("⚠️ rescheduleTaskDirectly disabled - TODO: Re-enable when ViewModel is available")
        print("⚠️ Falling back to legacy reschedule method")
        // Use legacy taskRepository for now
        task.dueDate = date as NSDate
        taskRepository.updateTask(task) { result in
            switch result {
            case .success:
                print("✅ Task rescheduled via legacy repository")
            case .failure(let error):
                print("❌ Failed to reschedule task: \(error)")
            }
        }
    }
}
