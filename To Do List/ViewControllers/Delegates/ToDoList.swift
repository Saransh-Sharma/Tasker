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
            checkBox.setOn(true, animated: true)
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
                if !inboxTasks[indexPath.row].isComplete {
                    self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                    self.tableView.reloadData()
                    self.updateLineChartData()
                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                }
            case 2:
                if !projectsTasks[indexPath.row].isComplete {
                    self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                    self.tableView.reloadData()
                    self.updateLineChartData()
                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                }
            default:
                break
            }
            
        case .customDateView:
            inboxTasks = self.fetchInboxTasks(date: dateForTheView)
            projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
            switch indexPath.section {
            case 1:
                if !inboxTasks[indexPath.row].isComplete {
                    self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                    self.tableView.reloadData()
                    self.updateLineChartData()
                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                }
            case 2:
                if !projectsTasks[indexPath.row].isComplete {
                    self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                    self.tableView.reloadData()
                    self.updateLineChartData()
                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                }
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
        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
        self.title = "\(score)"
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
    
    public func updateTableView() {
        self.tableView.backgroundColor = .clear
        self.tableView.reloadData()
    }
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

// MARK: – UITableViewDataSource & UITableViewDelegate
extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    
    func fetchToDoListSections(viewType: ToDoListViewType) {
        switch viewType {
        case .todayHomeView, .customDateView:
            ToDoListSections = TableViewCellSampleData.DateForViewSections
            
        case .projectView:
            ToDoListSections = TableViewCellSampleData.ProjectForViewSections
            
        case .upcomingView:
            ToDoListSections = TableViewCellSampleData.UpcomingViewSections
            
        case .historyView:
            ToDoListSections = TableViewCellSampleData.HistoryViewSections
            
        case .allProjectsGrouped:
            prepareAndFetchTasksForProjectGroupedView()
            ToDoListSections = projectsToDisplayAsSections.map { proj in
                let title = proj.projectName ?? "Unnamed Project"
                return ToDoListData.Section(
                    title: title,
                    taskListItems: [],
                    numberOfLines: 1,
                    hasFullLengthLabelAccessoryView: false,
                    hasAccessory: false,
                    allowsMultipleSelection: false,
                    headerStyle: .header,
                    hasFooter: false,
                    footerText: "",
                    footerLinkText: "",
                    hasCustomLinkHandler: false,
                    hasCustomAccessoryView: false
                )
            }
            
        case .selectedProjectsGrouped:
            prepareAndFetchTasksForProjectGroupedView()
            ToDoListSections = projectsToDisplayAsSections.map { proj in
                let title = proj.projectName ?? "Unnamed Project"
                return ToDoListData.Section(
                    title: title,
                    taskListItems: [],
                    numberOfLines: 1,
                    hasFullLengthLabelAccessoryView: false,
                    hasAccessory: false,
                    allowsMultipleSelection: false,
                    headerStyle: .header,
                    hasFooter: false,
                    footerText: "",
                    footerLinkText: "",
                    hasCustomLinkHandler: false,
                    hasCustomAccessoryView: false
                )
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            return projectsToDisplayAsSections.count
            
        default:
            fetchToDoListSections(viewType: currentViewType)
            return ToDoListSections.count
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            guard section < projectsToDisplayAsSections.count else { return 0 }
            let project = projectsToDisplayAsSections[section]
            return tasksGroupedByProject[project.projectName ?? ""]?.count ?? 0
            
        default:
            fetchToDoListSections(viewType: currentViewType)
            if section == 0 { return 0 }
            
            switch currentViewType {
            case .todayHomeView:
                if section == 1 {
                    let inboxTasks = fetchInboxTasks(date: Date.today())
                    return inboxTasks.count
                } else if section == 2 {
                    let customProjectTasks = fetchTasksForAllCustomProjctsTodayOpen(date: Date.today())
                    return customProjectTasks.count
                } else {
                    return 0
                }
                
            case .projectView:
                if section == 1 {
                    let customProjectTasks = fetchTasksForAllCustomProjctsTodayOpen(date: Date.today())
                    return customProjectTasks.count
                } else {
                    return 0
                }
                
            case .customDateView:
                if section == 1 {
                    let inboxTasks = fetchInboxTasks(date: dateForTheView)
                    return inboxTasks.count
                } else if section == 2 {
                    let customProjectTasks = fetchTasksForAllCustomProjctsTodayAll(date: dateForTheView)
                    return customProjectTasks.count
                } else {
                    return 0
                }
                
            default:
                if section == 1 {
                    let inboxTasks = fetchInboxTasks(date: Date.today())
                    return inboxTasks.count
                } else if section == 2 {
                    let customProjectTasks = fetchTasksForAllCustomProjctsTodayOpen(date: Date.today())
                    return customProjectTasks.count
                } else {
                    return 0
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fetchToDoListSections(viewType: currentViewType)
        self.listSection = ToDoListSections[indexPath.section]
        
        let inboxTasks = fetchInboxTasks(date: dateForTheView)
        var userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
        
        switch currentViewType {
        case .todayHomeView:
            if indexPath.section == 1 {
                let task = inboxTasks[indexPath.row]
                let taskDueDate = task.dueDate!
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if Date.today() > (taskDueDate as Date) {
                    return buildOpenInboxCell_Overdue(task: task)
                } else {
                    return buildOpenInboxCell(task: task)
                }
            } else if indexPath.section == 2 {
                let task = userProjectTasks[indexPath.row]
                let taskDueDate = task.dueDate!
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if Date.today() > (taskDueDate as Date) {
                    return buildNonInbox_Overdue(task: task)
                } else {
                    return buildNonInbox(task: task)
                }
            }
            
        case .customDateView:
            userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_All(date: dateForTheView)
            if indexPath.section == 1 {
                let task = inboxTasks[indexPath.row]
                let taskDueDate = task.dueDate!
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if Date.today() > (taskDueDate as Date) {
                    return buildOpenInboxCell_Overdue(task: task)
                } else {
                    return buildOpenInboxCell(task: task)
                }
            } else if indexPath.section == 2 {
                let task = userProjectTasks[indexPath.row]
                let taskDueDate = task.dueDate!
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if Date.today() > (taskDueDate as Date) {
                    return buildNonInbox_Overdue(task: task)
                } else {
                    return buildNonInbox(task: task)
                }
            }
            
        case .projectView:
            if indexPath.section == 1 {
                let task = userProjectTasks[indexPath.row]
                let taskDueDate = task.dueDate!
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if Date.today() > (taskDueDate as Date) {
                    return buildNonInbox_Overdue(task: task)
                } else {
                    return buildNonInbox(task: task)
                }
            }
            
        case .allProjectsGrouped, .selectedProjectsGrouped:
            guard indexPath.section < projectsToDisplayAsSections.count else {
                return UITableViewCell()
            }
            let project = projectsToDisplayAsSections[indexPath.section]
            guard let tasksForThisProject = tasksGroupedByProject[project.projectName ?? ""],
                  indexPath.row < tasksForThisProject.count else {
                return UITableViewCell()
            }
            let task = tasksForThisProject[indexPath.row]
            let taskDueDate = task.dueDate!
            if task.isComplete {
                return buildCompleteInbox(task: task)
            } else if Date.today() > (taskDueDate as Date) {
                return buildNonInbox_Overdue(task: task)
            } else {
                return buildNonInbox(task: task)
            }
            
        default:
            if indexPath.section == 1 {
                let task = inboxTasks[indexPath.row]
                let taskDueDate = task.dueDate!
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if Date.today() > (taskDueDate as Date) {
                    return buildOpenInboxCell_Overdue(task: task)
                } else {
                    return buildOpenInboxCell(task: task)
                }
            } else if indexPath.section == 2 {
                let task = userProjectTasks[indexPath.row]
                let taskDueDate = task.dueDate!
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if Date.today() > (taskDueDate as Date) {
                    return buildNonInbox_Overdue(task: task)
                } else {
                    return buildNonInbox(task: task)
                }
            }
        }
        
        // Fallback cell (should rarely be hit)
        let item = listSection!.item
        let cell = tableView.dequeueReusableCell(
            withIdentifier: TableViewCell.identifier,
            for: indexPath
        ) as! TableViewCell
        cell.setup(
            title: item.TaskTitle,
            subtitle: item.text2,
            footer: TableViewCellSampleData.hasFullLengthLabelAccessoryView(at: indexPath) ? "" : item.text3,
            customView: ToDoListData.createCustomView(imageName: item.image),
            customAccessoryView: listSection!.hasAccessory ? TableViewCellSampleData.customAccessoryView : nil,
            accessoryType: TableViewCellSampleData.accessoryType(for: indexPath)
        )
        return cell
    }
    
    // MARK: – Cell Builders
    
    func buildOpenInboxCell(task: NTask) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(
            withIdentifier: TableViewCell.identifier,
            for: IndexPath(row: 0, section: 0)
        ) as! TableViewCell
        cell.setup(
            title: task.name,
            subtitle: "",
            footer: "",
            accessoryType: .none
        )
        cell.titleNumberOfLines = 0
        let prioritySymbol = UIImageView()
        if task.taskPriority == 1 {
            prioritySymbol.image = highestPrioritySymbol
        } else if task.taskPriority == 2 {
            prioritySymbol.image = highPrioritySymbol
        }
        cell.titleLeadingAccessoryView = prioritySymbol
        return cell
    }
    
    func buildOpenInboxCell_Overdue(task: NTask) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(
            withIdentifier: TableViewCell.identifier,
            for: IndexPath(row: 0, section: 0)
        ) as! TableViewCell
        cell.setup(
            title: task.name,
            subtitle: "",
            footer: "",
            customAccessoryView: TableViewCellSampleData.customAccessoryView,
            accessoryType: .none
        )
        cell.titleNumberOfLines = 0
        let prioritySymbol = UIImageView()
        if task.taskPriority == 1 {
            prioritySymbol.image = highestPrioritySymbol
        } else if task.taskPriority == 2 {
            prioritySymbol.image = highPrioritySymbol
        }
        cell.titleLeadingAccessoryView = prioritySymbol
        return cell
    }
    
    func buildCompleteInbox(task: NTask) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(
            withIdentifier: TableViewCell.identifier,
            for: IndexPath(row: 0, section: 0)
        ) as! TableViewCell
        cell.setup(
            title: task.name,
            subtitle: "",
            footer: "",
            accessoryType: .checkmark
        )
        cell.titleNumberOfLines = 0
        cell.isEnabled = false
        return cell
    }
    
    func buildNonInbox(task: NTask) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(
            withIdentifier: TableViewCell.identifier,
            for: IndexPath(row: 0, section: 0)
        ) as! TableViewCell
        cell.setup(
            title: task.name,
            subtitle: task.project ?? "",
            footer: ""
        )
        let prioritySymbol = UIImageView()
        if task.taskPriority == 1 {
            prioritySymbol.image = highestPrioritySymbol
        } else if task.taskPriority == 2 {
            prioritySymbol.image = highPrioritySymbol
        }
        cell.titleLeadingAccessoryView = prioritySymbol
        cell.titleNumberOfLines = 0
        return cell
    }
    
    func buildNonInbox_Overdue(task: NTask) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(
            withIdentifier: TableViewCell.identifier,
            for: IndexPath(row: 0, section: 0)
        ) as! TableViewCell
        cell.setup(
            title: task.name,
            subtitle: task.project ?? "",
            footer: "",
            customAccessoryView: TableViewCellSampleData.customAccessoryView,
            accessoryType: .none
        )
        cell.titleNumberOfLines = 0
        let prioritySymbol = UIImageView()
        if task.taskPriority == 1 {
            prioritySymbol.image = highestPrioritySymbol
        } else if task.taskPriority == 2 {
            prioritySymbol.image = highPrioritySymbol
        }
        cell.titleLeadingAccessoryView = prioritySymbol
        return cell
    }
    
    // MARK: – Swipe Actions & Helpers
    
    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let completeTaskAction = UIContextualAction(
            style: .normal,
            title: "done"
        ) { _, _, actionPerformed in
            let inboxTasks = self.fetchInboxTasks(date: self.dateForTheView)
            let projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: self.dateForTheView)
            switch self.currentViewType {
            case .todayHomeView:
                switch indexPath.section {
                case 1:
                    if !inboxTasks[indexPath.row].isComplete {
                        self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                        self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                    }
                case 2:
                    if !projectsTasks[indexPath.row].isComplete {
                        self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                        self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                    }
                default:
                    break
                }
                
            case .customDateView:
                switch indexPath.section {
                case 1:
                    if !inboxTasks[indexPath.row].isComplete {
                        self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                        self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                    }
                case 2:
                    if !projectsTasks[indexPath.row].isComplete {
                        self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                        self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                    }
                default:
                    break
                }
                
            case .projectView, .upcomingView, .historyView, .allProjectsGrouped, .selectedProjectsGrouped:
                break
            }
            let score = self.calculateTodaysScore()
            self.scoreCounter.text = "\(score)"
            self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView)
            self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
            self.title = "\(score)"
            actionPerformed(true)
        }
        
        let undoAction = UIContextualAction(
            style: .normal,
            title: "U N D O"
        ) { _, _, actionPerformed in
            let inboxTasks = self.fetchInboxTasks(date: self.dateForTheView)
            let projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: self.dateForTheView)
            switch self.currentViewType {
            case .todayHomeView:
                switch indexPath.section {
                case 1:
                    if inboxTasks[indexPath.row].isComplete {
                        self.markTaskOpenOnSwipe(task: inboxTasks[indexPath.row])
                        self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                    }
                case 2:
                    if projectsTasks[indexPath.row].isComplete {
                        self.markTaskOpenOnSwipe(task: projectsTasks[indexPath.row])
                        self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                    }
                default:
                    break
                }
                
            case .customDateView:
                switch indexPath.section {
                case 1:
                    if inboxTasks[indexPath.row].isComplete {
                        self.markTaskOpenOnSwipe(task: inboxTasks[indexPath.row])
                        self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                    }
                case 2:
                    if projectsTasks[indexPath.row].isComplete {
                        self.markTaskOpenOnSwipe(task: projectsTasks[indexPath.row])
                        self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                    }
                default:
                    break
                }
                
            case .projectView, .upcomingView, .historyView, .allProjectsGrouped, .selectedProjectsGrouped:
                break
            }
            let score = self.calculateTodaysScore()
            self.scoreCounter.text = "\(score)"
            self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView)
            self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
            self.title = "\(score)"
            actionPerformed(true)
        }
        
        let deleteAction = UIContextualAction(
            style: .destructive,
            title: "delete"
        ) { _, _, actionPerformed in
            let inboxTasks = self.fetchInboxTasks(date: self.dateForTheView)
            let projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: self.dateForTheView)
            switch self.currentViewType {
            case .todayHomeView:
                switch indexPath.section {
                case 1:
                    self.deleteTaskOnSwipe(task: inboxTasks[indexPath.row])
                    self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                case 2:
                    self.deleteTaskOnSwipe(task: projectsTasks[indexPath.row])
                    self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                default:
                    break
                }
                
            case .customDateView:
                switch indexPath.section {
                case 1:
                    self.deleteTaskOnSwipe(task: inboxTasks[indexPath.row])
                    self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                case 2:
                    self.deleteTaskOnSwipe(task: projectsTasks[indexPath.row])
                    self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
                default:
                    break
                }
                
            case .projectView, .upcomingView, .historyView, .allProjectsGrouped, .selectedProjectsGrouped:
                break
            }
            let score = self.calculateTodaysScore()
            self.scoreCounter.text = "\(score)"
            self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView)
            self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
            self.title = "\(score)"
            actionPerformed(true)
        }
        
        undoAction.backgroundColor = todoColors.primaryColor
        completeTaskAction.backgroundColor = todoColors.completeTaskSwipeColor
        deleteAction.backgroundColor = .red
        
        let inboxTasks = fetchInboxTasks(date: dateForTheView)
        let projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
        
        switch self.currentViewType {
        case .todayHomeView:
            switch indexPath.section {
            case 1:
                if inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction, deleteAction])
                } else {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction, deleteAction])
                }
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction, deleteAction])
                } else {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction, deleteAction])
                }
            default:
                break
            }
            
        case .customDateView:
            switch indexPath.section {
            case 1:
                if inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction, deleteAction])
                } else {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction, deleteAction])
                }
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction, deleteAction])
                } else {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction, deleteAction])
                }
            default:
                break
            }
            
        default:
            break
        }
        
        return UISwipeActionsConfiguration(actions: [completeTaskAction, deleteAction])
    }
    
    func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let rescheduleTaskAction = UIContextualAction(
            style: .normal,
            title: "reschedule"
        ) { _, _, actionPerformed in
            let inboxTasks = self.fetchInboxTasks(date: self.dateForTheView)
            let projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: self.dateForTheView)
            switch self.currentViewType {
            case .todayHomeView:
                switch indexPath.section {
                case 1:
                    if !inboxTasks[indexPath.row].isComplete {
                        self.rescheduleAlertActionMenu(tasks: inboxTasks, indexPath: indexPath, tableView: tableView)
                    }
                case 2:
                    if !projectsTasks[indexPath.row].isComplete {
                        self.rescheduleAlertActionMenu(tasks: projectsTasks, indexPath: indexPath, tableView: tableView)
                    }
                default:
                    break
                }
                
            case .customDateView:
                switch indexPath.section {
                case 1:
                    self.rescheduleAlertActionMenu(tasks: inboxTasks, indexPath: indexPath, tableView: tableView)
                case 2:
                    self.rescheduleAlertActionMenu(tasks: inboxTasks, indexPath: indexPath, tableView: tableView)
                default:
                    break
                }
                
            default:
                break
            }
            actionPerformed(true)
        }
        
        let undoAction = UIContextualAction(
            style: .normal,
            title: "U N D O"
        ) { _, _, actionPerformed in
            actionPerformed(true)
        }
        
        undoAction.backgroundColor = todoColors.primaryColor
        rescheduleTaskAction.backgroundColor = todoColors.secondaryAccentColor
        
        let inboxTasks = fetchInboxTasks(date: dateForTheView)
        let projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
        
        switch self.currentViewType {
        case .todayHomeView:
            switch indexPath.section {
            case 1:
                if inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction])
                } else {
                    return UISwipeActionsConfiguration(actions: [rescheduleTaskAction])
                }
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction])
                } else {
                    return UISwipeActionsConfiguration(actions: [rescheduleTaskAction])
                }
            default:
                break
            }
        case .customDateView:
            switch indexPath.section {
            case 1:
                if inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction])
                } else {
                    return UISwipeActionsConfiguration(actions: [rescheduleTaskAction])
                }
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction])
                } else {
                    return UISwipeActionsConfiguration(actions: [rescheduleTaskAction])
                }
            default:
                break
            }
        default:
            break
        }
        
        return UISwipeActionsConfiguration(actions: [])
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            guard section < projectsToDisplayAsSections.count else { return nil }
            let project = projectsToDisplayAsSections[section]
            let header = tableView.dequeueReusableHeaderFooterView(
                withIdentifier: TableViewHeaderFooterView.identifier
            ) as! TableViewHeaderFooterView
            header.setup(style: .header, title: project.projectName ?? "Unnamed Project")
            return header
            
        default:
            if section == 0 {
                let inboxTitleHeaderView = UIStackView()
                inboxTitleHeaderView.addSubview(toDoListHeaderLabel)
                inboxTitleHeaderView.addSubview(lineSeparator)
                
                toDoListHeaderLabel.center(in: inboxTitleHeaderView, offset: CGPoint(x: 0, y: 8))
                let filterIconConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .light, scale: .default)
                let filterIconImage = UIImage(
                    systemName: "line.horizontal.3.decrease.circle",
                    withConfiguration: filterIconConfiguration
                )
                let colouredCalPullDownImage = filterIconImage?.withTintColor(
                    todoColors.secondaryAccentColor,
                    renderingMode: .alwaysOriginal
                )
                let filterMenuHomeButton = UIButton()
                inboxTitleHeaderView.addSubview(filterMenuHomeButton)
                filterMenuHomeButton.leftToSuperview(offset: 10)
                filterMenuHomeButton.setImage(colouredCalPullDownImage, for: .normal)
                filterMenuHomeButton.addTarget(
                    self,
                    action: #selector(showTopDrawerButtonTapped),
                    for: .touchUpInside
                )
                
                toDoListHeaderLabel.font = setFont(
                    fontSize: 20,
                    fontweight: .medium,
                    fontDesign: .rounded
                )
                toDoListHeaderLabel.textAlignment = .center
                toDoListHeaderLabel.adjustsFontSizeToFitWidth = true
                toDoListHeaderLabel.textColor = .label
                
                let now = Date.today
                var sectionLabel = ""
                if dateForTheView == now() {
                    sectionLabel = "Today"
                } else if dateForTheView == Date.tomorrow() {
                    sectionLabel = "Tomorrow"
                } else if dateForTheView == Date.yesterday() {
                    sectionLabel = "Yesterday"
                } else {
                    let customDay = dateForTheView
                    if "\(customDay.day)".count < 2 {
                        homeDate_Day.text = "0\(customDay.day)"
                    } else {
                        homeDate_Day.text = "\(customDay.day)"
                    }
                    let dateFormatter_Weekday = DateFormatter()
                    dateFormatter_Weekday.dateFormat = "EEEE"
                    let nameOfWeekday = dateFormatter_Weekday.string(from: customDay)
                    sectionLabel = nameOfWeekday
                }
                toDoListHeaderLabel.text = sectionLabel
                
                lineSeparator.frame = CGRect(
                    x: 0,
                    y: 32,
                    width: UIScreen.main.bounds.width,
                    height: 1
                )
                lineSeparator.backgroundColor = .black
                inboxTitleHeaderView.addSubview(lineSeparator)
                return inboxTitleHeaderView
                
            } else if section == 1 {
                let header = UIStackView()
                header.backgroundColor = .clear
                return header
                
            } else if section == 2 {
                let projectsHeader = UIStackView()
                projectsHeader.backgroundColor = .clear
                let projectsHeaderLabel = UILabel()
                projectsHeader.addSubview(projectsHeaderLabel)
                projectsHeaderLabel.center(in: projectsHeader, offset: CGPoint(x: 0, y: 8))
                projectsHeaderLabel.font = setFont(
                    fontSize: 20,
                    fontweight: .medium,
                    fontDesign: .rounded
                )
                projectsHeaderLabel.textAlignment = .center
                projectsHeaderLabel.adjustsFontSizeToFitWidth = true
                projectsHeaderLabel.textColor = .label
                projectsHeaderLabel.text = "Projects"
                return projectsHeader
                
            } else if section < ToDoListSections.count {
                let header = tableView.dequeueReusableHeaderFooterView(
                    withIdentifier: TableViewHeaderFooterView.identifier
                ) as! TableViewHeaderFooterView
                let sectionData = ToDoListSections[section]
                header.setup(style: .header, title: sectionData.sectionTitle)
                return header
            }
            return nil
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath
    ) {
        let title = ToDoListSections[indexPath.section].item.TaskTitle
        showAlertForDetailButtonTapped(title: title)
    }
    
    func showAlertForDetailButtonTapped(title: String) {
        let alert = UIAlertController(
            title: "\(title) detail button was tapped",
            message: nil,
            preferredStyle: .alert
        )
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true)
    }
}

// MARK: – Swipe Helpers (only defined once)

extension HomeViewController {
    /// Reload tableView, calendar & charts after a row‐level change
    func updateToDoListAndCharts(tableView: UITableView, indexPath: IndexPath) {
        tableView.reloadData()
        calendar.reloadData()
        updateLineChartData()
        animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    }

    /// Mark a task as open (undo complete)
    func markTaskOpenOnSwipe(task: NTask) {
        let globalIndex = self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: task)
        let nTask = TaskManager.sharedInstance.getAllTasks[globalIndex]
        nTask.isComplete = false
        nTask.dateCompleted = nil
        TaskManager.sharedInstance.saveContext()
    }

    /// Delete a task permanently on swipe
    func deleteTaskOnSwipe(task: NTask) {
        let idx = getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: task)
        TaskManager.sharedInstance.removeTaskAtIndex(index: idx)
        TaskManager.sharedInstance.saveContext()
    }

    /// Show action sheet to pick new due dates (Tomorrow, Day After Tomorrow, Next Week)
    func rescheduleAlertActionMenu(tasks: [NTask], indexPath: IndexPath, tableView: UITableView) {
        let current = dateForTheView
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: current)!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: current)!

        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "Tomorrow", style: .default) { _ in
            TaskManager.sharedInstance.reschedule(task: tasks[indexPath.row], to: tomorrow)
            self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
        })
        controller.addAction(UIAlertAction(title: "Day After Tomorrow", style: .default) { _ in
            TaskManager.sharedInstance.reschedule(task: tasks[indexPath.row], to: dayAfter)
            self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
        })
        controller.addAction(UIAlertAction(title: "Next Week", style: .default) { _ in
            TaskManager.sharedInstance.reschedule(task: tasks[indexPath.row], to: nextWeek)
            self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
        })
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
}
