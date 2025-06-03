//
//  HomeViewController+TableView.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import FluentUI

extension HomeViewController {
    
    // MARK: - TableView Configuration
    
    func setupTableView() {
        tableView.dataSource = self as UITableViewDataSource
        tableView.delegate = self as UITableViewDelegate
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        
        // Register cell classes if needed
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TaskCell")
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }
    
    func updateTableView() {
        ToDoListSections.removeAll()
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    
    @objc func numberOfSections(in tableView: UITableView) -> Int {
        // Always have at least one section for the main header
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            return projectsToDisplayAsSections.count > 0 ? projectsToDisplayAsSections.count + 1 : 1
        default:
            return 1
        }
    }
    
    @objc func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            if section == 0 {
                // Section 0 is just the main header with filter controls
                return 0
            } else {
                // Adjust for 0-indexed section
                let actualSection = section - 1
                if actualSection < projectsToDisplayAsSections.count {
                    let projectName = projectsToDisplayAsSections[actualSection].projectName ?? ""
                    return tasksGroupedByProject[projectName]?.count ?? 0
                }
                return 0
            }
        default:
            return ToDoListSections.flatMap({ $0.items }).count
        }
    }
    
    @objc func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline) // Replaced todoColors.todoFont (Plan Step C)
        titleLabel.textColor = todoColors.primaryTextColor
        
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            if section == 0 {
                // Main header with filter icon/label
                titleLabel.text = currentViewType == .allProjectsGrouped ? "All Projects" : "Selected Projects"
                let filterIcon = UIImageView(image: UIImage(systemName: "line.horizontal.3.decrease.circle"))
                filterIcon.tintColor = todoColors.primaryColor
                
                // Add components to headerView with proper constraints
                // Add tap gesture to reset filters if needed
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(clearProjectFilterAndResetView))
                headerView.addGestureRecognizer(tapGesture)
            } else {
                // Project section headers
                let actualSection = section - 1
                if actualSection < projectsToDisplayAsSections.count {
                    titleLabel.text = projectsToDisplayAsSections[actualSection].projectName
                }
            }
        default:
            titleLabel.text = ToDoListSections.first?.sectionTitle // Fixed: Use sectionTitle
        }
        
        headerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        
        return headerView
    }
    
    @objc func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    @objc func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskCell", for: indexPath)
        
        // Configure the cell based on task data
        var task: NTask?
        
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            if indexPath.section > 0 {
                let actualSection = indexPath.section - 1
                if actualSection < projectsToDisplayAsSections.count {
                    let projectName = projectsToDisplayAsSections[actualSection].projectName ?? ""
                    task = tasksGroupedByProject[projectName]?[indexPath.row]
                }
            }
        default:
            let allTaskItems = ToDoListSections.flatMap({ $0.items })
            if indexPath.row < allTaskItems.count {
                let taskListItem = allTaskItems[indexPath.row]
                // We need to convert or retrieve the actual NTask object instead of direct assignment
                // This is a placeholder - you'll need to implement the actual conversion logic
                // For example, you might need to fetch the task from CoreData based on some identifier
                // or create a new NTask with properties from taskListItem
                task = TaskManager.sharedInstance.getTaskFromTaskListItem(taskListItem: taskListItem)
                if task == nil {
                    print("Error: Expected a task item in cellForRowAt, but found nil at indexPath: \(indexPath)")
                    // task remains nil, cell configuration should handle this
                }
            }
        }
        
        if let task = task {
            configureCellForTask(cell, with: task, at: indexPath)
        }
        
        return cell
    }
    
    // MARK: - Cell Configuration
    
    private func configureCellForTask(_ cell: UITableViewCell, with task: NTask, at indexPath: IndexPath) {
        // Clear existing content and configuration
        cell.backgroundColor = .clear
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        if task.isComplete {
            configureCompletedTaskCell(cell, with: task, at: indexPath)
        } else {
            configureOpenTaskCell(cell, with: task, at: indexPath)
        }
    }
    
    private func configureOpenTaskCell(_ cell: UITableViewCell, with task: NTask, at indexPath: IndexPath) {
        // Implementation would depend on your specific UI requirements
        // This is a placeholder for the cell building logic
    }
    
    private func configureCompletedTaskCell(_ cell: UITableViewCell, with task: NTask, at indexPath: IndexPath) {
        // Implementation would depend on your specific UI requirements
        // This is a placeholder for the cell building logic
    }
    
    // MARK: - Swipe Actions
    
    @objc func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Get task for this row
        var task: NTask?
        
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            if indexPath.section > 0 {
                let actualSection = indexPath.section - 1
                if actualSection < projectsToDisplayAsSections.count {
                    let projectName = projectsToDisplayAsSections[actualSection].projectName ?? ""
                    if let tasks = tasksGroupedByProject[projectName], indexPath.row < tasks.count {
                        task = tasks[indexPath.row]
                    }
                }
            }
        default:
            let allTaskItems = ToDoListSections.flatMap({ $0.items })
            if indexPath.row < allTaskItems.count {
                let taskListItem = allTaskItems[indexPath.row]
                // We need to convert or retrieve the actual NTask object instead of direct assignment
                // Use the same conversion method as in cellForRowAt
                task = TaskManager.sharedInstance.getTaskFromTaskListItem(taskListItem: taskListItem)
                if task == nil {
                    print("Error: Expected a task item for swipe actions, but found nil at indexPath: \(indexPath)")
                    // task remains nil, guard statement below will handle this
                }
            }
        }
        
        guard let task = task else { return nil }
        
        // Define swipe actions based on task state
        if task.isComplete {
            let reopenAction = UIContextualAction(style: .normal, title: "Reopen") { [weak self] (_, _, completion) in
                self?.markTaskOpenOnSwipe(task: task)
                completion(true)
            }
            reopenAction.backgroundColor = todoColors.secondaryAccentColor
            
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
                self?.deleteTaskOnSwipe(task: task)
                completion(true)
            }
            
            return UISwipeActionsConfiguration(actions: [deleteAction, reopenAction])
        } else {
            let completeAction = UIContextualAction(style: .normal, title: "Complete") { [weak self] (_, _, completion) in
                task.isComplete = true
                task.dateCompleted = Date() as NSDate
                TaskManager.sharedInstance.saveContext()
                self?.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                completion(true)
            }
            completeAction.backgroundColor = todoColors.secondaryAccentColor
            
            let rescheduleAction = UIContextualAction(style: .normal, title: "Reschedule") { [weak self] (_, _, completion) in
                self?.rescheduleAlertActionMenu(tasks: [task], indexPath: indexPath, tableView: tableView)
                completion(true)
            }
            rescheduleAction.backgroundColor = todoColors.primaryColor
            
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
                self?.deleteTaskOnSwipe(task: task)
                completion(true)
            }
            
            return UISwipeActionsConfiguration(actions: [deleteAction, rescheduleAction, completeAction])
        }
    }
    
    // MARK: - Task Actions
    
    func updateToDoListAndCharts(tableView: UITableView, indexPath: IndexPath) {
        tableView.reloadData()
        updateLineChartData()
    }
    
    func markTaskOpenOnSwipe(task: NTask) {
        task.isComplete = false
        task.dateCompleted = nil
        TaskManager.sharedInstance.saveContext()
        tableView.reloadData()
        updateLineChartData()
    }
    
    func deleteTaskOnSwipe(task: NTask) {
        // Delete the task directly from the context
        TaskManager.sharedInstance.context.delete(task)
        TaskManager.sharedInstance.saveContext()
        tableView.reloadData()
        updateLineChartData()
    }
    
    func rescheduleAlertActionMenu(tasks: [NTask], indexPath: IndexPath, tableView: UITableView) {
        let alertController = UIAlertController(title: "Reschedule", message: "Move to:", preferredStyle: .actionSheet)
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        
        let tomorrowAction = UIAlertAction(title: "Tomorrow", style: .default) { (_) in
            for task in tasks {
                task.dueDate = tomorrow as NSDate
            }
            TaskManager.sharedInstance.saveContext()
            tableView.reloadData()
        }
        
        let nextWeekAction = UIAlertAction(title: "Next Week", style: .default) { (_) in
            for task in tasks {
                task.dueDate = nextWeek as NSDate
            }
            TaskManager.sharedInstance.saveContext()
            tableView.reloadData()
        }
        
        let chooseDateAction = UIAlertAction(title: "Choose Date...", style: .default) { (_) in
            // Call date picker functionality
            // This would need to be implemented separately
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(tomorrowAction)
        alertController.addAction(nextWeekAction)
        alertController.addAction(chooseDateAction)
        alertController.addAction(cancelAction)
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = tableView
            popoverController.sourceRect = tableView.rectForRow(at: indexPath)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
}
