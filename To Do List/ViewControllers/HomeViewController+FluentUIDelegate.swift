//
//  HomeViewController+FluentUIDelegate.swift
//  To Do List
//
//  Created by AI Assistant
//  Copyright 2024 saransh1337. All rights reserved.
//

import UIKit
import Foundation

// MARK: - FluentUIToDoTableViewControllerDelegate

extension HomeViewController: FluentUIToDoTableViewControllerDelegate {
    
    func fluentToDoTableViewControllerDidCompleteTask(_ controller: FluentUIToDoTableViewController, task: NTask) {
        // Add haptic feedback immediately for responsive feel
        let impactFeedback = UIImpactFeedbackGenerator(style: task.isComplete ? .medium : .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Delay chart update slightly to allow UI to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateLineChartData()
        }
        
        // Log with more detailed information
         let status = task.isComplete ? "completed" : "uncompleted"
         let score = task.getTaskScore(task: task)
         print("Task \(status): '\(task.name)' (Score: \(score))")
    }
    
    func fluentToDoTableViewControllerDidUpdateTask(_ controller: FluentUIToDoTableViewController, task: NTask) {
        // Gentle haptic feedback for updates
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Update chart data with slight delay for smooth experience
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.updateLineChartData()
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dueDateString = task.dueDate != nil ? dateFormatter.string(from: task.dueDate! as Date) : "No date"
        print("Task updated: '\(task.name)' (Priority: \(task.taskPriority), Due: \(dueDateString))")
    }
    
    func fluentToDoTableViewControllerDidDeleteTask(_ controller: FluentUIToDoTableViewController, task: NTask) {
        // Strong haptic feedback for deletion
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Update chart immediately for deletion to show instant feedback
        updateLineChartData()
        
        // Log deletion with task details
         let score = task.getTaskScore(task: task)
         print("Task deleted: '\(task.name)' (Score: \(score), Was completed: \(task.isComplete))")
        
        // Optional: Show brief confirmation (could be enhanced with toast notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("Chart updated after task deletion")
        }
    }
}
