//
//  HomeViewController+Helpers.swift
//  Tasker
//
//  Helper methods for HomeViewController - Clean Architecture
//

import UIKit

extension HomeViewController {

    // MARK: - Task Helpers (Clean Architecture)
    // NOTE: getTaskFromTaskListItem is implemented in HomeViewController+TableView.swift
    // The TableView version uses synchronous CoreData fetch for UI responsiveness

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
