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
        
        // CRITICAL: Refresh ALL charts including tiny pie chart
        print("🎯 FluentUIDelegate: Task completion changed - refreshing ALL charts")
        refreshChartsAfterTaskCompletion()
        
        // Phase 7: Also update horizontal chart cards with slight delay for smooth animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateChartCardsScrollView()
        }
        
        // Log with detailed task and daily score information
        let status = task.isComplete ? "completed" : "uncompleted"
        let taskScore = task.getTaskScore(task: task)
        // Use ChartDataService for accurate score calculation
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let chartService = ChartDataService(context: context!)
        let dailyTotal = chartService.calculateScoreForDate(date: Date())
        print("📋 Task \(status): '\(task.name ?? "Untitled Task")'")
        print("   • Task Score: \(taskScore)")
        print("   • Daily Total Score: \(dailyTotal)")
        print("   • Priority: \(task.taskPriority)")
        print("   • Type: \(task.isEveningTask ? "Evening" : "Morning")")
        if let project = task.project {
            print("   • Project: \(project)")
        }
    }
    
    func fluentToDoTableViewControllerDidUpdateTask(_ controller: FluentUIToDoTableViewController, task: NTask) {
        // Gentle haptic feedback for updates
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Phase 7: Update chart data with slight delay for smooth experience
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.updateChartCardsScrollView()
        }
        
        // Log detailed task update information
        let taskScore = task.getTaskScore(task: task)
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let chartService = ChartDataService(context: context!)
        let dailyTotal = chartService.calculateScoreForDate(date: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dueDateString = task.dueDate != nil ? dateFormatter.string(from: task.dueDate! as Date) : "No date"
        
        print("✏️ Task updated: '\(task.name ?? "Untitled Task")'")
        print("   • Task Score: \(taskScore)")
        print("   • Daily Total Score: \(dailyTotal)")
        print("   • Priority: \(task.taskPriority)")
        print("   • Due Date: \(dueDateString)")
        print("   • Type: \(task.isEveningTask ? "Evening" : "Morning")")
        print("   • Completed: \(task.isComplete)")
        if let project = task.project {
            print("   • Project: \(project)")
        }
    }
    
    func fluentToDoTableViewControllerDidDeleteTask(_ controller: FluentUIToDoTableViewController, task: NTask) {
        // Strong haptic feedback for deletion
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Phase 7: Update chart immediately for deletion to show instant feedback
        updateChartCardsScrollView()
        
        // Log deletion with detailed task information
        let taskScore = task.getTaskScore(task: task)
        // Use ChartDataService for accurate score calculation
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let chartService = ChartDataService(context: context!)
        let dailyTotal = chartService.calculateScoreForDate(date: Date())
        print("🗑️ Task deleted: '\(task.name ?? "Untitled Task")'")
        print("   • Task Score: \(taskScore)")
        print("   • Was Completed: \(task.isComplete)")
        print("   • Updated Daily Total: \(dailyTotal)")
        print("   • Priority: \(task.taskPriority)")
        if let project = task.project {
            print("   • Project: \(project)")
        }
        
        // Optional: Show brief confirmation (could be enhanced with toast notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("Chart updated after task deletion")
        }
    }
}
