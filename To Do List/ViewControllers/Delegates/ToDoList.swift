//
//  TaskListTableViewExtension.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
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
            projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
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
            projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
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
        
        let score = self.calculateTodaysScore()
        self.scoreCounter.text = "\(score)"
        self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView)
        // Refresh navigation pie chart to reflect task completion changes
        self.refreshNavigationPieChart()
        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
        // Update navigation title (Today · date • score)
        // Update navigation title and score, then refresh chart to guarantee latest data
        self.updateDailyScore()
        self.updateSwiftUIChartCard()
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
        return TaskManager.sharedInstance.getTasksForInboxForDate_All(date: date)
    }
    
    func markTaskCompleteOnSwipe(task: NTask) {
        TaskManager.sharedInstance.toggleTaskComplete(task: task)
    }
    
    func rescheduleTaskOnSwipe(task: NTask, scheduleTo: Date) {
        // Only change dueDate; saving handled by caller if needed
        TaskManager.sharedInstance.reschedule(task: task, to: scheduleTo)
    }
    
    func fetchTasksForAllCustomProjctsTodayOpen(date: Date) -> [NTask] {
        return TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: date)
    }
    
    func fetchTasksForAllCustomProjctsTodayAll(date: Date) -> [NTask] {
        return TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_All(date: date)
    }
    
    func fetchTasksForCustomProject(project: String) -> [NTask] {
        return TaskManager.sharedInstance.getTasksForProjectByName(projectName: project)
    }
}

// MARK: – Additional UITableViewDelegate Methods
