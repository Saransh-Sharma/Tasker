//
//  HomeViewController+TaskSelection.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import FluentUI

extension HomeViewController {
    
    // MARK: - Task Selection
    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        tableView.deselectRow(at: indexPath, animated: true)
//        
//        print("\n🔍 TASK SELECTION:")
//        print("  📍 IndexPath: Section \(indexPath.section), Row \(indexPath.row)")
//        print("  📱 Current View Type: \(currentViewType)")
//        
//        // Get the selected task
//        var selectedTask: NTask?
//        
//        switch currentViewType {
//        case .allProjectsGrouped, .selectedProjectsGrouped:
//            if indexPath.section > 0 {
//                let actualSection = indexPath.section - 1
//                if actualSection < projectsToDisplayAsSections.count {
//                    let projectName = projectsToDisplayAsSections[actualSection].projectName ?? ""
//                    if let tasks = tasksGroupedByProject[projectName], indexPath.row < tasks.count {
//                        selectedTask = tasks[indexPath.row]
//                        print("  📁 Selected from project: \(projectName)")
//                    }
//                }
//            }
//        default:
//            // Convert TaskListItem to NTask or find corresponding NTask
//            let allTaskItems = ToDoListSections.flatMap({ $0.items })
//            if indexPath.row < allTaskItems.count {
//                // Get the TaskListItem
//                let taskItem = allTaskItems[indexPath.row]
//                print("  📝 TaskItem title: '\(taskItem.TaskTitle)'")
//                // Find the corresponding NTask by title
//                selectedTask = TaskManager.sharedInstance.getAllTasks.first(where: { $0.name == taskItem.TaskTitle })
//            }
//        }
//        
//        guard let task = selectedTask else {
//            print("  ❌ No task found for selection")
//            return
//        }
//        
//        // Print detailed task information
//        print("\n📋 SELECTED TASK DETAILS:")
//        print("  📌 Name: '\(task.name ?? "Unknown")'")
//        print("  📁 Project: '\(task.project ?? "No Project")'")
//        print("  📝 Details: '\(task.taskDetails ?? "No details")'")
//        print("  ⏰ Due Date: \(task.dueDate?.description ?? "No due date")")
//        print("  📅 Date Added: \(task.dateAdded?.description ?? "Unknown")")
//        print("  🎯 Priority: P\(task.taskPriority - 1) (\(task.taskPriority))")
//        print("  🏷️ Type: \(task.taskType)")
//        print("  ✅ Completed: \(task.isComplete ? "Yes" : "No")")
//        if task.isComplete {
//            print("  🎉 Completed Date: \(task.dateCompleted?.description ?? "Unknown")")
//        }
//        print("  🌙 Evening Task: \(task.isEveningTask ? "Yes" : "No")")
//        if let reminderTime = task.alertReminderTime {
//            print("  ⏰ Reminder: \(reminderTime.description)")
//        }
//        print("")
//        
//        // Present task detail view
//        presentTaskDetailView(for: task)
//    }
    
    // MARK: - Present Task Detail
    
    func presentTaskDetailView(for task: NTask) {
        // Create an overlay to dim the background
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.alpha = 0
        view.addSubview(overlayView)
        self.overlayView = overlayView
        
        // Create a tap gesture to dismiss when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissFluentDetailView))
        overlayView.addGestureRecognizer(tapGesture)
        
        // Setup the Fluent detail view
        let detailView = TaskDetailViewFluent(frame: CGRect(x: 0, y: 0, width: view.bounds.width * 0.9, height: view.bounds.height * 0.8))
        detailView.configure(task: task, availableProjects: ProjectManager.sharedInstance.getAllProjects(), delegate: self, taskRepository: taskRepository)
        detailView.alpha = 0
        detailView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the detail view to the view hierarchy
        view.addSubview(detailView)
        
        // Center the detail view and set its width
        NSLayoutConstraint.activate([
            detailView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detailView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            detailView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            detailView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.8)
        ])
        
        // Store reference to the detail view
        self.presentedFluentDetailView = detailView
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            overlayView.alpha = 1
            detailView.alpha = 1
        }
    }
}
