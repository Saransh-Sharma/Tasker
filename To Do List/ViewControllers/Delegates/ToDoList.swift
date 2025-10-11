//
//  TaskListTableViewExtension.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import FluentUI
import Timepiece
import BEMCheckBox
import TinyConstraints

// MARK: – BEMCheckBoxDelegate
extension HomeViewController: BEMCheckBoxDelegate {
    
    func didTap(_ checkBox: BEMCheckBox) {
        openTaskCheckboxTag = checkBox.tag
        print("checkboc tag: \(openTaskCheckboxTag)")
        print("checkboc index: \(currentIndex)")
        checkBoxCompleteAction(indexPath: currentIndex, checkBox: checkBox)
    }
    
    @objc private func showTopDrawerButtonTapped(sender: UIButton) {
        let rect = sender.superview!.convert(sender.frame, to: nil)
        presentDrawer(
            sourceView: sender,
            presentationOrigin: rect.maxY + 8,
            presentationDirection: .down,
            contentView: containerForActionViews(),
            customWidth: true
        )
    }
    
    func checkBoxCompleteAction2(checkBox: BEMCheckBox) {
        checkBox.on.toggle()
    }
    
    func checkBoxCompleteAction(indexPath: IndexPath, checkBox: BEMCheckBox) {
        if checkBox.tag == indexPath.row {
            // Toggle the visual state to reflect the new completion status
            checkBox.on.toggle()
        }
        
        var inboxTasks: [NTask]
        var projectsTasks: [NTask]
        let dateForTheView = self.dateForTheView
        
        switch self.currentViewType {
        case .todayHomeView:
            inboxTasks = self.fetchInboxTasks(date: dateForTheView)
            projectsTasks = fetchTasksForAllCustomProjctsTodayOpen(date: dateForTheView)
            switch indexPath.section {
            case 1:
                // Toggle completion state (complete ↔ reopen)
                self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                // Updated to use FluentUI table view
        self.fluentToDoTableViewController?.tableView.reloadData()
                // refresh chart later
                self.animateTableViewReloadSingleCell(at: indexPath)
                // Rebuild sections so completed/overdue tasks display correctly
                self.loadTasksForDateGroupedByProject()
            case 2:
                // Toggle completion state (complete ↔ reopen)
                self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                // Updated to use FluentUI table view
        self.fluentToDoTableViewController?.tableView.reloadData()
                // refresh chart later
                self.animateTableViewReloadSingleCell(at: indexPath)
                // Rebuild sections so completed/overdue tasks display correctly
                self.loadTasksForDateGroupedByProject()
            default:
                break
            }
            
        case .customDateView:
            inboxTasks = self.fetchInboxTasks(date: dateForTheView)
            projectsTasks = fetchTasksForAllCustomProjctsTodayOpen(date: dateForTheView)
            switch indexPath.section {
            case 1:
                // Toggle completion state (complete ↔ reopen)
                self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                // Updated to use FluentUI table view
        self.fluentToDoTableViewController?.tableView.reloadData()
                // refresh chart later
                self.animateTableViewReloadSingleCell(at: indexPath)
                // Rebuild sections so completed/overdue tasks display correctly
                self.loadTasksForDateGroupedByProject()
            case 2:
                // Toggle completion state (complete ↔ reopen)
                self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                // Updated to use FluentUI table view
        self.fluentToDoTableViewController?.tableView.reloadData()
                // refresh chart later
                self.animateTableViewReloadSingleCell(at: indexPath)
                // Rebuild sections so completed/overdue tasks display correctly
                self.loadTasksForDateGroupedByProject()
            default:
                break
            }
            
        case .projectView, .upcomingView, .historyView, .allProjectsGrouped, .selectedProjectsGrouped:
            // TODO: handle these view types if needed
            break
        }
        
        print("🔄 Task completion toggled - starting chart refresh sequence")
        
        // Calculate and update score
        let score = self.calculateTodaysScore()
        self.scoreCounter.text = "\(score)"
        print("📊 Score calculated: \(score)")
        
        // Update tiny pie chart data (slices based on priority breakdown)
        print("🥧 About to call updateTinyPieChartData()")
        self.updateTinyPieChartData()
        print("🥧 updateTinyPieChartData() called")
        
        // Update tiny pie chart center text with new score
        print("📝 Updating tiny pie chart center text")
        self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView, scoreOverride: score)
        
        // Animate tiny pie chart
        print("🎬 Animating tiny pie chart")
        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
        
        // Refresh navigation pie chart to reflect task completion changes
        print("🔄 Refreshing navigation pie chart")
        self.refreshNavigationPieChart()
        
        // Phase 7: Update navigation title and backdrop horizontal chart cards
        print("📊 Updating daily score and chart cards")
        self.updateDailyScore()
        self.updateChartCardsScrollView()
        
        print("✅ Tiny pie chart refresh sequence completed")
    }
    
    @objc private func selectionBarButtonTapped(sender: UIBarButtonItem) {
        // Selection mode toggle if implemented
    }
    
    @objc private func styleBarButtonTapped(sender: UIBarButtonItem) {
        isGrouped.toggle()
    }
    
    private func updateNavigationTitle() {
        // Update navigation title if needed
    }
    
//    public func updateTableView() {
//        self.tableView.backgroundColor = .clear
//        // Updated to use FluentUI table view
//        self.fluentToDoTableViewController?.tableView.reloadData()
//    }
}

// MARK: – Task Fetch & Management Helpers
extension HomeViewController {
    func fetchInboxTasks(date: Date) -> [NTask] {
        // Use direct Core Data access (Clean Architecture)
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(
            format: "project == %@ AND dueDate >= %@ AND dueDate < %@",
            "Inbox", startOfDay as NSDate, endOfDay as NSDate
        )
        
        return (try? context?.fetch(request)) ?? []
    }
    
    func markTaskCompleteOnSwipe(task: NTask) {
        // Use direct Core Data access (Clean Architecture)
        task.isComplete.toggle()
        if task.isComplete {
            task.dateCompleted = Date() as NSDate
        } else {
            task.dateCompleted = nil
        }
        saveContext()
    }
    
    func rescheduleTaskOnSwipe(task: NTask, scheduleTo: Date) {
        // Use direct Core Data access (Clean Architecture)
        task.dueDate = scheduleTo as NSDate
        saveContext()
    }
    
    func fetchTasksForAllCustomProjctsTodayOpen(date: Date) -> [NTask] {
        // Use direct Core Data access (Clean Architecture)
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(
            format: "project != %@ AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            "Inbox", startOfDay as NSDate, endOfDay as NSDate
        )
        
        return (try? context?.fetch(request)) ?? []
    }
    
    func fetchTasksForAllCustomProjctsTodayAll(date: Date) -> [NTask] {
        // Use direct Core Data access (Clean Architecture)
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(
            format: "project != %@ AND dueDate >= %@ AND dueDate < %@",
            "Inbox", startOfDay as NSDate, endOfDay as NSDate
        )
        
        return (try? context?.fetch(request)) ?? []
    }
    
    func fetchTasksForCustomProject(project: String) -> [NTask] {
        // Use direct Core Data access (Clean Architecture)
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        request.predicate = NSPredicate(format: "project == %@", project)
        
        return (try? context?.fetch(request)) ?? []
    }
    
    /// Save context without using TaskManager singleton
    private func saveContext() {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return
        }
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Failed to save context: \(error)")
            }
        }
    }
}

// MARK: – Additional UITableViewDelegate Methods
