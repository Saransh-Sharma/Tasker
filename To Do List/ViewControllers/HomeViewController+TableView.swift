//
//  HomeViewController+TableView.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import CoreData
import FluentUI

// TaskListItem is defined in ToDoListData.swift

extension HomeViewController {
    
    // MARK: - TableView Configuration
    
    func setupTableView() {
        fluentToDoTableViewController?.tableView.dataSource = self
        fluentToDoTableViewController?.tableView.delegate = self
        
        
        fluentToDoTableViewController?.tableView.backgroundColor = TableViewCell.tableBackgroundGroupedColor
        fluentToDoTableViewController?.tableView.separatorStyle  = .none
        fluentToDoTableViewController?.tableView.register(TableViewCell.self,
                           forCellReuseIdentifier: cellReuseID)
        fluentToDoTableViewController?.tableView.register(TableViewHeaderFooterView.self,
                           forHeaderFooterViewReuseIdentifier: headerReuseID)
        
    }
    
    func updateTableView() {
        ToDoListSections.removeAll()
        fluentToDoTableViewController?.tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Original implementation for the main table view
        let sectionCount: Int
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            sectionCount = projectsToDisplayAsSections.count > 0 ? projectsToDisplayAsSections.count + 1 : 1
        case .todayHomeView, .customDateView:
            // Return the number of project sections (Inbox + other projects)
            sectionCount = ToDoListSections.count
        default:
            sectionCount = ToDoListSections.count > 0 ? ToDoListSections.count : 1
        }
        print("HomeViewController: numberOfSections returning \(sectionCount) for viewType \(currentViewType)")
        return sectionCount
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Original implementation for the main table view
        let rowCount: Int
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            if section == 0 {
                // Section 0 is just the main header with filter controls
                rowCount = 0
            } else {
                // Adjust for 0-indexed section
                let actualSection = section - 1
                if actualSection < projectsToDisplayAsSections.count {
                    let projectName = projectsToDisplayAsSections[actualSection].projectName ?? ""
                    rowCount = tasksGroupedByProject[projectName]?.count ?? 0
                } else {
                    rowCount = 0
                }
            }
        case .todayHomeView, .customDateView:
            // Return the number of tasks in the specific section
            if section < ToDoListSections.count {
                rowCount = ToDoListSections[section].items.count
                print("HomeViewController: Section \(section) ('\(ToDoListSections[section].sectionTitle)') has \(rowCount) rows")
            } else {
                rowCount = 0
                print("HomeViewController: Section \(section) is out of bounds, returning 0 rows")
            }
        default:
            if ToDoListSections.isEmpty {
                rowCount = 0
            } else {
                rowCount = ToDoListSections.flatMap({ $0.items }).count
            }
        }
        print("HomeViewController: numberOfRowsInSection \(section) returning \(rowCount)")
        return rowCount
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Original implementation for the main table view
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline) // Replaced todoColors.todoFont (Plan Step C)
        titleLabel.textColor = todoColors.textPrimary
        
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            if section == 0 {
                // Main header with filter icon/label
                titleLabel.text = currentViewType == .allProjectsGrouped ? "All Projects" : "Selected Projects"
                let filterIcon = UIImageView(image: UIImage(systemName: "line.horizontal.3.decrease.circle"))
                filterIcon.tintColor = todoColors.accentPrimary
                
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
        case .todayHomeView, .customDateView:
            // Show section title for each project
            if section < ToDoListSections.count {
                titleLabel.text = ToDoListSections[section].sectionTitle
            }
        default:
            if !ToDoListSections.isEmpty {
                titleLabel.text = ToDoListSections.first?.sectionTitle
            }
        }
        
        headerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Original implementation for the main table view
        return 40
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Original implementation for the main table view
        print("Table - HomeViewController: cellForRowAt called for indexPath \(indexPath)")
        
        //        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskCell", for: indexPath)
        
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: cellReuseID,
            for: indexPath) as? TableViewCell else {
            fatalError("Unable to dequeue TableViewCell – check registration")
        }
        
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
        case .todayHomeView, .customDateView:
            // Get task from the specific section
            print("Table - HomeViewController: ----- ----- ----- ----- ----- ")
            print("Table - HomeViewController: Current view type is \(currentViewType), ToDoListSections.count = \(ToDoListSections.count)")
            if indexPath.section < ToDoListSections.count {
                let section = ToDoListSections[indexPath.section]
                print("Table - HomeViewController: Section '\(section.sectionTitle)' has \(section.items.count) items")
                if indexPath.row < section.items.count {
                    let taskListItem = section.items[indexPath.row]
                    print("Table - HomeViewController: Getting task for TaskListItem with title '\(taskListItem.TaskTitle)'")
                    task = getTaskFromTaskListItem(taskListItem)
                    if task == nil {
                        print("Table - Error: Expected a task item in cellForRowAt, but found nil at indexPath: \(indexPath)")
                    }
                }
            }
        default:
            let allTaskItems = ToDoListSections.flatMap({ $0.items })
            if indexPath.row < allTaskItems.count {
                let taskListItem = allTaskItems[indexPath.row]
                task = getTaskFromTaskListItem(taskListItem)
                if task == nil {
                    print("Table - Error: Expected a task item in cellForRowAt, but found nil at indexPath: \(indexPath)")
                }
            }
        }
        
        if let task = task {
            print("Table - HomeViewController: Found task '\(task.name)' for indexPath \(indexPath)")
            configureCellForTask(cell, with: task, at: indexPath)
            if shouldAnimateCells {
                animateTableViewReloadSingleCell(at: indexPath)
            }
        } else {
            print("Table - HomeViewController: No task found for indexPath \(indexPath)")
            // Configure empty cell
            cell.textLabel?.text = "No Task"
            cell.detailTextLabel?.text = ""
        }
        
        return cell
    }
    
    private func separatorType(for indexPath: IndexPath) -> TableViewCell.SeparatorType {
        let last = indexPath.row == (fluentToDoTableViewController?.tableView.numberOfRows(inSection: indexPath.section) ?? 0) - 1
        return last ? .none : .inset
    }
    
    // MARK: - Cell Configuration
    
    private func configureCellForTask(_ cell: TableViewCell, with task: NTask, at indexPath: IndexPath) {
        // let Fluent handle background
        cell.backgroundStyleType = .grouped        // or .plain if you flip `isGrouped`
        cell.topSeparatorType    = indexPath.row == 0 ? .full : .none
        cell.bottomSeparatorType = separatorType(for: indexPath)
        
        let accessory: TableViewCellAccessoryType = task.isComplete ? .checkmark : .none
        
        cell.setup(title: task.name ?? "Untitled Task",
                   subtitle: task.taskDetails ?? "",
                   accessoryType: accessory)
        
        if task.isComplete {
            let strike = [NSAttributedString.Key.strikethroughStyle:
                            NSUnderlineStyle.single.rawValue]
            cell.setup(attributedTitle   : NSAttributedString(string: task.name ?? "Untitled Task",
                                                              attributes: strike),
                       attributedSubtitle: NSAttributedString(string: task.taskDetails ?? "",
                                                              attributes: strike),
                       accessoryType     : .checkmark)
        }
        
    }
    
    //    private func configureOpenTaskCell(_ cell: UITableViewCell, with task: NTask, at indexPath: IndexPath) {
    //        // Configure cell for open/incomplete tasks
    //
    //        if let fluentCell = cell as? FluentUI.TableViewCell {
    //            print("Table - HomeViewController -- ----> : Using FluentUI cell for task '\(task.name)'")
    //            fluentCell.setup(title: task.name,
    //                           subtitle: task.taskDetails ?? "",
    //                           accessoryType: .none)
    //        } else {
    //            print("Table - ERROR !! - HomeViewController: Using standard UITableViewCell for task '\(task.name)'")
    //            // Fallback for standard UITableViewCell
    //            cell.textLabel?.text = task.name
    //            cell.detailTextLabel?.text = task.taskDetails ?? ""
    //            cell.textLabel?.textColor = .label
    //            cell.textLabel?.attributedText = nil
    //            cell.detailTextLabel?.textColor = .secondaryLabel
    //            cell.detailTextLabel?.attributedText = nil
    //        }
    //    }
    //
    //    private func configureCompletedTaskCell(_ cell: UITableViewCell, with task: NTask, at indexPath: IndexPath) {
    //        // Configure cell for completed tasks with strikethrough and grey styling
    //        if let fluentCell = cell as? FluentUI.TableViewCell {
    //            // Setup cell with plain text first
    //            fluentCell.setup(title: task.name,
    //                           subtitle: task.taskDetails ?? "",
    //                           accessoryType: .checkmark)
    //
    //            // Apply strikethrough and grey styling after setup
    //            // Note: FluentUI.TableViewCell may not expose direct label access
    //            // The styling will be handled by the standard UITableViewCell fallback for now
    //        } else {
    //            // Fallback for standard UITableViewCell
    //            let titleText = task.name
    //            let titleAttributedString = NSMutableAttributedString(string: titleText)
    //            titleAttributedString.addAttribute(NSAttributedString.Key.strikethroughStyle,
    //                                             value: NSUnderlineStyle.single.rawValue,
    //                                             range: NSRange(location: 0, length: titleText.count))
    //            titleAttributedString.addAttribute(NSAttributedString.Key.foregroundColor,
    //                                             value: UIColor.systemGray,
    //                                             range: NSRange(location: 0, length: titleText.count))
    //            cell.textLabel?.attributedText = titleAttributedString
    //
    //            if let subtitleText = task.taskDetails, !subtitleText.isEmpty {
    //                let subtitleAttributedString = NSMutableAttributedString(string: subtitleText)
    //                subtitleAttributedString.addAttribute(NSAttributedString.Key.strikethroughStyle,
    //                                                     value: NSUnderlineStyle.single.rawValue,
    //                                                     range: NSRange(location: 0, length: subtitleText.count))
    //                subtitleAttributedString.addAttribute(NSAttributedString.Key.foregroundColor,
    //                                                     value: UIColor.systemGray2,
    //                                                     range: NSRange(location: 0, length: subtitleText.count))
    //                cell.detailTextLabel?.attributedText = subtitleAttributedString
    //            }
    //
    //            cell.accessoryType = .checkmark
    //        }
    //    }
    
    // MARK: - Swipe Actions
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
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
        case .todayHomeView, .customDateView:
            // Get task from the specific section
            if indexPath.section < ToDoListSections.count {
                let section = ToDoListSections[indexPath.section]
                if indexPath.row < section.items.count {
                    let taskListItem = section.items[indexPath.row]
                    task = getTaskFromTaskListItem(taskListItem)
                    if task == nil {
                        print("Error: Expected a task item for swipe actions, but found nil at indexPath: \(indexPath)")
                    }
                }
            }
        default:
            let allTaskItems = ToDoListSections.flatMap({ $0.items })
            if indexPath.row < allTaskItems.count {
                let taskListItem = allTaskItems[indexPath.row]
                task = getTaskFromTaskListItem(taskListItem)
                if task == nil {
                    print("Error: Expected a task item for swipe actions, but found nil at indexPath: \(indexPath)")
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
            reopenAction.backgroundColor = todoColors.accentMuted
            
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
                self?.deleteTaskOnSwipe(task: task)
                completion(true)
            }
            
            return UISwipeActionsConfiguration(actions: [deleteAction, reopenAction])
        } else {
            let rescheduleAction = UIContextualAction(style: .normal, title: "Reschedule") { [weak self] (_, _, completion) in
                self?.rescheduleAlertActionMenu(tasks: [task], indexPath: indexPath, tableView: tableView)
                completion(true)
            }
            rescheduleAction.backgroundColor = todoColors.accentPrimary
            
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
                self?.deleteTaskOnSwipe(task: task)
                completion(true)
            }
            
            return UISwipeActionsConfiguration(actions: [deleteAction, rescheduleAction])
        }
    }
    
    // MARK: - Sample Table View Helper Methods
    
    // Sample task action methods removed - now handled by FluentUI controller
        
        // MARK: - Leading Swipe Actions (Left-to-Right)
        
        func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            return nil
        }
        
        // MARK: - Task Actions
        
        func updateToDoListAndCharts() {
            // Rebuild sections so that just-completed tasks remain visible
            self.loadTasksForDateGroupedByProject()
            self.fluentToDoTableViewController?.tableView.reloadData()
            self.updateLineChartData()
        }
        
        func markTaskOpenOnSwipe(task: NTask) {
            // Update task directly for now (simpler than using repository's complex API)
            task.isComplete = false
            task.dateCompleted = nil
            saveContext()
            self.fluentToDoTableViewController?.tableView.reloadData()
            self.updateLineChartData()
        }
        
        func deleteTaskOnSwipe(task: NTask) {
            // Delete task using repository
            taskRepository.deleteTask(taskID: task.objectID, completion: { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Task deleted successfully")
                        self?.fluentToDoTableViewController?.tableView.reloadData()
                        self?.updateLineChartData()
                    case .failure(let error):
                        print("❌ Failed to delete task: \(error)")
                    }
                }
            })
        }
        
        func rescheduleAlertActionMenu(tasks: [NTask], indexPath: IndexPath, tableView: UITableView) {
            let alertController = UIAlertController(title: "Reschedule", message: "Move to:", preferredStyle: .actionSheet)

            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

            let tomorrowAction = UIAlertAction(title: "Tomorrow", style: .default) { (_) in
                for task in tasks {
                    task.dueDate = tomorrow as NSDate
                }
                // Save context inline
                if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext, context.hasChanges {
                    try? context.save()
                }
                DispatchQueue.main.async {
                    tableView.reloadData()
                }
            }

            let nextWeekAction = UIAlertAction(title: "Next Week", style: .default) { (_) in
                for task in tasks {
                    task.dueDate = nextWeek as NSDate
                }
                // Save context inline
                if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext, context.hasChanges {
                    try? context.save()
                }
                DispatchQueue.main.async {
                    tableView.reloadData()
                }
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
    
    // MARK: - Helper Methods (Clean Architecture - Using Repository)

    /// Get task from TaskListItem using Core Data fetch
    private func getTaskFromTaskListItem(_ item: ToDoListData.TaskListItem) -> NTask? {
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()

        // Match by task name (TaskListItem only has TaskTitle, no TaskDueDate)
        request.predicate = NSPredicate(format: "name == %@", item.TaskTitle)

        return try? context?.fetch(request).first
    }

    /// Save context directly (simplified for now)
    internal func saveContext() {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return
        }

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
