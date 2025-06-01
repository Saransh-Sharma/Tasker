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
            return 1 + projectsToDisplayAsSections.count
            
        default:
            fetchToDoListSections(viewType: currentViewType)
            return ToDoListSections.count
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentViewType {
        case .allProjectsGrouped, .selectedProjectsGrouped:
            if section == 0 {
                return 0
            }
            let projectIndex = section - 1
            guard projectIndex >= 0 && projectIndex < projectsToDisplayAsSections.count else { return 0 }
            let project = projectsToDisplayAsSections[projectIndex]
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
        // Default fetch for fallback and non-grouped views
        fetchToDoListSections(viewType: currentViewType)

        let inboxTasks = fetchInboxTasks(date: dateForTheView)

        switch currentViewType {
        case .todayHomeView:
            let userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
            if indexPath.section == 1 {
                guard indexPath.row < inboxTasks.count else { return UITableViewCell() }
                let task = inboxTasks[indexPath.row]
                let due = task.dueDate! as Date
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if Date.today() > due {
                    return buildOpenInboxCell_Overdue(task: task)
                } else {
                    return buildOpenInboxCell(task: task)
                }
            } else if indexPath.section == 2 {
                guard indexPath.row < userProjectTasks.count else { return UITableViewCell() }
                let task = userProjectTasks[indexPath.row]
                let due = task.dueDate! as Date
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if Date.today() > due {
                    return buildNonInbox_Overdue(task: task)
                } else {
                    return buildNonInbox(task: task)
                }
            }

        case .customDateView:
            let userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_All(date: dateForTheView)
            if indexPath.section == 1 {
                guard indexPath.row < inboxTasks.count else { return UITableViewCell() }
                let task = inboxTasks[indexPath.row]
                let due = task.dueDate! as Date
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if dateForTheView > due {
                    return buildOpenInboxCell_Overdue(task: task)
                } else {
                    return buildOpenInboxCell(task: task)
                }
            } else if indexPath.section == 2 {
                guard indexPath.row < userProjectTasks.count else { return UITableViewCell() }
                let task = userProjectTasks[indexPath.row]
                let due = task.dueDate! as Date
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if dateForTheView > due {
                    return buildNonInbox_Overdue(task: task)
                } else {
                    return buildNonInbox(task: task)
                }
            }

        case .projectView:
            if indexPath.section == 1 {
                let tasks = TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(
                    projectName: projectForTheView,
                    date: dateForTheView
                )
                guard indexPath.row < tasks.count else { return UITableViewCell() }
                let task = tasks[indexPath.row]
                let due = task.dueDate! as Date
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                } else if dateForTheView > due {
                    return buildNonInbox_Overdue(task: task)
                } else {
                    return buildNonInbox(task: task)
                }
            }

        case .allProjectsGrouped, .selectedProjectsGrouped:
            guard indexPath.section > 0 && indexPath.section <= projectsToDisplayAsSections.count else {
                return UITableViewCell()
            }
            let projIdx = indexPath.section - 1
            guard projIdx < projectsToDisplayAsSections.count else { return UITableViewCell() }
            let project = projectsToDisplayAsSections[projIdx]
            guard let taskList = tasksGroupedByProject[project.projectName ?? ""], indexPath.row < taskList.count else {
                return UITableViewCell()
            }
            let task = taskList[indexPath.row]
            let due = task.dueDate! as Date
            if task.isComplete {
                return buildCompleteInbox(task: task)
            } else if dateForTheView > due {
                return buildNonInbox_Overdue(task: task)
            } else {
                return buildNonInbox(task: task)
            }

        default:
            // Fallback: only use ToDoListSections if valid
            if ToDoListSections.indices.contains(indexPath.section) {
                let sectionData = ToDoListSections[indexPath.section]
                if indexPath.row < sectionData.items.count {
                    let item = sectionData.items[indexPath.row]
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: TableViewCell.identifier,
                        for: indexPath
                    ) as! TableViewCell
                    cell.setup(
                        title: item.TaskTitle,
                        subtitle: item.text2,
                        footer: TableViewCellSampleData.hasFullLengthLabelAccessoryView(at: indexPath) ? "" : item.text3,
                        customView: ToDoListData.createCustomView(imageName: item.image),
                        customAccessoryView: sectionData.hasAccessory ? TableViewCellSampleData.customAccessoryView : nil,
                        accessoryType: TableViewCellSampleData.accessoryType(for: indexPath)
                    )
                    return cell
                }
            }
        }

        // No matching case, return empty cell
        return UITableViewCell()
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
        if section == 0 { // Handles the main header for ALL view types
            let mainHeaderView = UIStackView()
            mainHeaderView.axis = .horizontal
            mainHeaderView.alignment = .center
            mainHeaderView.spacing = 8 // Adjust as needed
            // Consider adding layoutMargins if this UIStackView is the root view being returned
            // mainHeaderView.isLayoutMarginsRelativeArrangement = true
            // mainHeaderView.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)


            var buttonIconName: String
            var buttonAction: Selector
            var actualHeaderLabelText: String // Renamed to avoid confusion if toDoListHeaderLabel is an instance var

            switch self.currentViewType {
            case .allProjectsGrouped:
                buttonIconName = "xmark.circle.fill"
                buttonAction = #selector(HomeViewController.clearProjectFilterAndResetView)
                actualHeaderLabelText = "All Projects"
                if self.dateForTheView != Date.today() {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .none
                    actualHeaderLabelText += " - \(dateFormatter.string(from: self.dateForTheView))"
                }
            case .selectedProjectsGrouped:
                buttonIconName = "xmark.circle.fill"
                buttonAction = #selector(HomeViewController.clearProjectFilterAndResetView)
                if selectedProjectNamesForFilter.isEmpty {
                    actualHeaderLabelText = "Projects" // Fallback
                } else if selectedProjectNamesForFilter.count == 1 {
                    actualHeaderLabelText = selectedProjectNamesForFilter.first ?? "Project"
                } else {
                    actualHeaderLabelText = "\(selectedProjectNamesForFilter.count) Projects Selected"
                }
                if self.dateForTheView != Date.today() {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .none
                    actualHeaderLabelText += " - \(dateFormatter.string(from: self.dateForTheView))"
                }
            default: // Covers .todayHomeView, .customDateView, .projectView (single project from pill bar), etc.
                buttonIconName = "line.horizontal.3.decrease.circle"
                buttonAction = #selector(HomeViewController.showTopDrawerButtonTapped)
                
                // Logic to set headerLabelText for default view types (date-based)
                let now = Date.today() // Make sure Date.today() is accessible
                if self.dateForTheView == now {
                    actualHeaderLabelText = "Today"
                } else if self.dateForTheView == Date.tomorrow() { // Make sure Date.tomorrow() is accessible
                    actualHeaderLabelText = "Tomorrow"
                } else if self.dateForTheView == Date.yesterday() { // Make sure Date.yesterday() is accessible
                    actualHeaderLabelText = "Yesterday"
                } else {
                    let customDay = self.dateForTheView
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "EEEE, MMM d" // Format for the label
                    actualHeaderLabelText = dateFormatter.string(from: customDay)
                }
            }

            // Use self.toDoListHeaderLabel if it's an instance property correctly configured elsewhere
            self.toDoListHeaderLabel.text = actualHeaderLabelText
            // Configure other properties of toDoListHeaderLabel as in the original code (font, alignment, color, etc.)
            // E.g., self.toDoListHeaderLabel.font = setFont(fontSize: 20, fontweight: .medium, fontDesign: .rounded)
            // self.toDoListHeaderLabel.textAlignment = .center
            // self.toDoListHeaderLabel.textColor = .label

            let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .light)
            let icon = UIImage(systemName: buttonIconName, withConfiguration: config)?
                .withTintColor(self.todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal) // Use self.todoColors

            let btn = UIButton(type: .system) // Using .system often gives better default tap behavior
            btn.setImage(icon, for: .normal)
            btn.addTarget(self, action: buttonAction, for: .touchUpInside)
            
            // Ensure button maintains its intrinsic size or set explicit constraints
            btn.setContentHuggingPriority(.required, for: .horizontal)
            btn.setContentCompressionResistancePriority(.required, for: .horizontal)

            mainHeaderView.addArrangedSubview(btn)
            mainHeaderView.addArrangedSubview(self.toDoListHeaderLabel) // Add the instance label

            // If you have a lineSeparator as an instance property (self.lineSeparator) and it belongs in this header:
            // You might want a vertical stack if the separator is below the button/label
            // For example:
            // let topContentStack = UIStackView(arrangedSubviews: [btn, self.toDoListHeaderLabel])
            // topContentStack.axis = .horizontal
            // topContentStack.spacing = 8
            // topContentStack.alignment = .center
            //
            // let verticalContainer = UIStackView(arrangedSubviews: [topContentStack, self.lineSeparator])
            // verticalContainer.axis = .vertical
            // verticalContainer.spacing = 4 // or 0 if separator is tight
            // self.lineSeparator.heightAnchor.constraint(equalToConstant: 1).isActive = true // Ensure separator height
            // self.lineSeparator.backgroundColor = .gray // Or your separator color
            // return verticalContainer
            //
            // If just returning mainHeaderView (horizontal stack):

            return mainHeaderView

        } else { // For sections > 0
            switch self.currentViewType {
            case .allProjectsGrouped, .selectedProjectsGrouped:
                let projectIndex = section - 1 // Projects now start at section 1
                guard projectIndex >= 0 && projectIndex < self.projectsToDisplayAsSections.count else { return nil }
                let project = self.projectsToDisplayAsSections[projectIndex]
                let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TableViewHeaderFooterView.identifier) as! TableViewHeaderFooterView
                header.setup(style: .header, title: project.projectName ?? "Unnamed Project")
                return header
            
            default: // For default view types (e.g., .todayHomeView) and sections > 0
                // This should contain the logic for headers of section 1 ("Inbox") and section 2 ("Projects")
                // from your original "else" block.
                if section < self.ToDoListSections.count {
                     let sectionData = self.ToDoListSections[section]
                     if !(sectionData.sectionTitle.isEmpty && !sectionData.hasAccessory) { // Avoid empty headers unless they have accessories
                         let header = tableView.dequeueReusableHeaderFooterView(
                             withIdentifier: TableViewHeaderFooterView.identifier
                         ) as! TableViewHeaderFooterView
                         var title = sectionData.sectionTitle
                         // Specific titles for default view's sections 1 & 2
                         if (self.currentViewType == .todayHomeView || self.currentViewType == .customDateView) {
                             if section == 1 { title = "Inbox" }
                             else if section == 2 { title = "Projects" }
                         }
                         header.setup(style: sectionData.headerStyle, title: title)
                         return header
                     }
                }
                return nil // Fallback for sections > 0 in default views
            }
        }
        // return nil // Should be unreachable if all paths are covered
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
