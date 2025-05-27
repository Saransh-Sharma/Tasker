//
//  TaskListTableViewExtention.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import FluentUI
import Timepiece
import BEMCheckBox
import TinyConstraints

extension HomeViewController: BEMCheckBoxDelegate {
    
    func didTap(_ checkBox: BEMCheckBox) {
        // do stuff here
        
        // 1
        openTaskCheckboxTag = checkBox.tag
        
        print("checkboc tag: \(openTaskCheckboxTag)")
        print("checkboc idex: \(currentIndex)")
        
        checkBoxCompleteAction(indexPath: currentIndex, checkBox: checkBox)
        
    }
    
    @objc private func showTopDrawerButtonTapped(sender: UIButton) {
        let rect = sender.superview!.convert(sender.frame, to: nil)
        
        presentDrawer(sourceView: sender, presentationOrigin: rect.maxY+8, presentationDirection: .down, contentView: containerForActionViews(), customWidth: true)
    }
    
    func checkBoxCompleteAction2(checkBox: BEMCheckBox) {
        
        if (checkBox.on) {
            checkBox.on = false
        } else{
            checkBox.on = true
        }
    }
    func checkBoxCompleteAction(indexPath: IndexPath, checkBox: BEMCheckBox) {
        if checkBox.tag == indexPath.row {
            checkBox.setOn(true, animated: true)
        }
        var inboxTasks: [NTask]
        var projectsTasks: [NTask]
        let dateForTheView = self.dateForTheView
        
        print("checkboc ELLO !")
        
        switch self.currentViewType {
        
        case .todayHomeView:
            print("checkboc TODAY VIEW !")
            inboxTasks = self.fetchInboxTasks(date: dateForTheView)
            projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
            
            switch indexPath.section {
            
            
            case 1:
                print("checkboc TODAY VIEW ! -- DEFAULT SEC 1")
                
                print("checkboc TASK NME: \(inboxTasks[indexPath.row].name)")
                if !inboxTasks[indexPath.row].isComplete {
                    self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                    print("checkboc TASK: \(inboxTasks[indexPath.row].name)")
                    
                    
                    tableView.reloadData()
                    updateLineChartData()
                    
                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                }
                
            case 2:
                print("checkboc TODAY VIEW ! -- DEFAULT SEC 2")
                if !projectsTasks[indexPath.row].isComplete {
                    self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                    
                    
                    tableView.reloadData()
                    updateLineChartData()
                    
                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                }
                
            default:
                print("checkboc TODAY VIEW ! -- DEFAULT SEC 3")
                break
            }
            
        case .customDateView:
            
            print("checkboc CUSTOM DATE VIEW !")
            inboxTasks = self.fetchInboxTasks(date: dateForTheView)
            projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
            
            switch indexPath.section {
            
            case 1:
                
                if !inboxTasks[indexPath.row].isComplete {
                    self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                    
                    tableView.reloadData()
                    updateLineChartData()
                    
                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                }
                
            case 2:
                
                if !projectsTasks[indexPath.row].isComplete {
                    self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                    
                    tableView.reloadData()
                    updateLineChartData()
                    
                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                    
                }
                
            default:
                print("checkboc  - DEFAULT VIEW")
                break
            }
        case .projectView:
            print("checkboc  - PROHECT VIEW") //TODO
        case .upcomingView:
            print("checkboc - Upcooming") //TODO
        case .historyView:
            print("checkboc - HISTORY VIEW") //TODO
        }
        
        
        print("SCORE IS: \(self.calculateTodaysScore())")
        self.scoreCounter.text = "\(self.calculateTodaysScore())"
        self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView);
        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
        
        //            tableView.reloadData()
        //            self.animateTableViewReload()
        
        self.title = "\(self.calculateTodaysScore())"
        
    }
    
    
    
    
    @objc private func selectionBarButtonTapped(sender: UIBarButtonItem) {
        //        isInSelectionMode = !isInSelectionMode
    }
    
    @objc private func styleBarButtonTapped(sender: UIBarButtonItem) {
        isGrouped = !isGrouped
        //        sender.title = styleButtonTitle
    }
    
    private func updateNavigationTitle() {
        
    }
    
    public func updateTableView() {
        tableView.backgroundColor = .clear //isGrouped ? Colors.Table.backgroundGrouped : Colors.Table.background
        tableView.reloadData()
    }
    
}



// MARK: - TableViewCellDemoController: UITableViewDataSource

extension HomeViewController: UITableViewDataSource {
    
    func fetchToDoListSections(viewType: ToDoListViewType) {
        
        switch viewType {
        //        case .upcomingView:
        //            ToDoListSections = TableViewCellSampleData.UpcomingViewSections
        case .todayHomeView:
            ToDoListSections = TableViewCellSampleData.DateForViewSections
        case .projectView:
            ToDoListSections = TableViewCellSampleData.ProjectForViewSections
        case .customDateView:
            ToDoListSections = TableViewCellSampleData.DateForViewSections
        case .upcomingView:
            ToDoListSections = TableViewCellSampleData.UpcomingViewSections
        case .historyView:
            ToDoListSections = TableViewCellSampleData.HistoryViewSections
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        fetchToDoListSections(viewType: currentViewType)
        return ToDoListSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        fetchToDoListSections(viewType: currentViewType)
        
        //spacer section
        if section == 0 {
            return 0
        }
        enum ToDoListViewType {
            case todayHomeView
            case customDateView
            case projectView
            case upcomingView
            case historyView
        }
        switch currentViewType {
        case .todayHomeView:
            print("ref: numberOfRowsInSection - todayHomeView - A")
            if section == 1 { //inbox tasks
                let inboxTasks = fetchInboxTasks(date: Date.today())
                print("ref: numberOfRowsInSection - todayHomeView - B - inboxCount \(inboxTasks.count)")
                return inboxTasks.count
            } else if section == 2 { //projects
                let customProjectTasks = fetchTasksForAllCustomProjctsTodayOpen(date: Date.today())
                print("ref proj00: numberOfRowsInSection - todayHomeView - C - projectTaskCount \(customProjectTasks.count)")
                return customProjectTasks.count
            } else {
                return 0
            }
        case .projectView:
            if section == 1 { //all custom project tasks
                
                let customProjectTasks = fetchTasksForAllCustomProjctsTodayOpen(date: Date.today())
                return customProjectTasks.count
            } else {
                return 0
            }
            
        case .customDateView:
            if section == 1 { //inbox tasks
                let inboxTasks = fetchInboxTasks(date: dateForTheView)
                print("dud inbox task ccount:  \(inboxTasks.count)")
                return inboxTasks.count
            } else if section == 2 { //projects
                
                
                let customProjectTasks = fetchTasksForAllCustomProjctsTodayAll(date: dateForTheView)
                for each in customProjectTasks {
                    print("proj00 rhur print list : \(each.name)")
                }
                print("proj00 rhur : rows in section 2 : \(customProjectTasks.count)")
                
                print("proj00 dud custom task ccount:  \(customProjectTasks.count)")
                return customProjectTasks.count
            } else {
                return 0
            }
        default:
            if section == 1 { //inbox tasks
                let inboxTasks = fetchInboxTasks(date: Date.today())
                return inboxTasks.count
            } else if section == 2 { //projects
                let customProjectTasks = fetchTasksForAllCustomProjctsTodayOpen(date: Date.today())
                return customProjectTasks.count
            } else {
                return 0
            }
        }
    }
    
    
    
    //open inbox
    func buildOpenInboxCell(task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        
        cell.setup(
            title: task.name,
            subtitle: "",
            footer: "",
            //customView: foo,
            accessoryType: .none
        )
        cell.customViewSize = .small
        cell.titleNumberOfLines = 0
        cell.titleLeadingAccessoryView = .none
        let prioritySymbol = UIImageView()
        
        ////1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
        if task.taskPriority == 1 {
            prioritySymbol.image = highestPrioritySymbol
        } else if task.taskPriority == 2 {
            prioritySymbol.image = highPrioritySymbol
        }
        
        cell.titleLeadingAccessoryView = prioritySymbol
        
        return cell
    }
    //open inbox overdue
    func buildOpenInboxCell_Overdue(task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        //let foo = setupCheckbox(cell: cell)
        
        //foo.setOn(false, animated: true)
        cell.setup(
            title: task.name,
            subtitle: "",
            footer: "",
            //customView: foo,
            customAccessoryView: TableViewCellSampleData.customAccessoryView,
            accessoryType: .none
        )
        cell.customViewSize = .small
        cell.titleNumberOfLines = 0
        
        let prioritySymbol = UIImageView()
        
        ////1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
        if task.taskPriority == 1 {
            prioritySymbol.image = highestPrioritySymbol
        } else if task.taskPriority == 2 {
            prioritySymbol.image = highPrioritySymbol
        }
        
        cell.titleLeadingAccessoryView = prioritySymbol
        
        return cell
    }
    //open inbox overdue
    func buildCompleteInbox( task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        //let foo = setupCheckbox(cell: cell)
        //foo.setOn(true, animated: true)
        cell.setup(
            title: task.name,
            subtitle: "",
            footer: "",
            // customView: foo,
            accessoryType: .checkmark
        )
        
        cell.customViewSize = .small
        cell.titleNumberOfLines = 0
        cell.isEnabled = false
        
        
        return cell
    }
    //open NON inbox
    func buildNonInbox( task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        // let foo = setupCheckbox(cell: cell)
        //        if task.isComplete {
        //            foo.setOn(true, animated: true)
        //        } else {
        //            foo.setOn(false, animated: true)
        //        }
        
        cell.setup(
            title: task.name,
            subtitle: (task.project ?? "") as String,
            footer: ""
            // customView: foo
            
        )
        let prioritySymbol = UIImageView()
        
        ////1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
        if task.taskPriority == 1 {
            prioritySymbol.image = highestPrioritySymbol
        } else if task.taskPriority == 2 {
            prioritySymbol.image = highPrioritySymbol
        }
        
        cell.titleLeadingAccessoryView = prioritySymbol
        
        cell.customViewSize = .small
        //        cell.titleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])
        //        cell.subtitleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])
        cell.titleNumberOfLines = 0
        
        
        
        return cell
    }    //open inbox overdue
    func buildNonInbox_Overdue( task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        //let foo = setupCheckbox(cell: cell)
        // foo.setOn(false, animated: true)
        cell.setup(
            title: task.name,
            subtitle: (task.project ?? "") as String,
            footer: "",
            //customView: foo,
            
            customAccessoryView: TableViewCellSampleData.customAccessoryView,
            accessoryType: .none
        )
        
        let prioritySymbol = UIImageView()
        
        ////1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
        if task.taskPriority == 1 {
            prioritySymbol.image = highestPrioritySymbol
        } else if task.taskPriority == 2 {
            prioritySymbol.image = highPrioritySymbol
        }
        
        cell.titleLeadingAccessoryView = prioritySymbol
        
        //        cell.titleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])
        //        cell.subtitleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])
        cell.customViewSize = .small
        cell.titleNumberOfLines = 0
        
        
        return cell
    }
    
    
    
    func reloadTinyPicChartWithAnimation() {
        
        self.tinyPieChartView.centerAttributedText = setTinyPieChartScoreText(pieChartView: self.tinyPieChartView)
        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
    }
    
    func reloadToDoListWithAnimation() {
        
        
        tableView.reloadData()
        animateTableViewReload()
    }
    
    enum ToDoListViewType {
        case todayHomeView
        case customDateView
        case projectView
        case upcomingView
        case historyView
    }
    
    func setupViewForDate(date: Date) {
        
    }
    
    func setupViewForProject(date: Date) {
        
    }
    
    
    
    //----------------------------------------------------
    //----------------------------------------------------
    //----------------------------------------------------
    //MARK:- updateViewForHome
    //----------------------------------------------------
    //----------------------------------------------------
    //----------------------------------------------------
    func updateViewForHome(viewType: ToDoListViewType, dateForView: Date = Date.today(), projectForView: String = ProjectManager.sharedInstance.defaultProject) {
        
        currentViewType = viewType
        print("woo ViewType is: \(currentViewType)")
        
        fetchToDoListSections(viewType: currentViewType)
        print("woo Fetched To Do list for View Type: \(currentViewType)")
        
        switch viewType {
        case .todayHomeView:
            print("woo ViewType: TODAY VIEW")
            
            let today = Date.today()
            setDateForViewValue(dateToSetForView: today)
            updateHomeDateLabel(date: today)
            
            //aimations
            reloadTinyPicChartWithAnimation()
            reloadToDoListWithAnimation()
            
            
        case .customDateView:
            print("woo ViewType: CUSTOM DATE VIEW")
            //            let today = dateForView
            setDateForViewValue(dateToSetForView: dateForView)
            updateHomeDateLabel(date: dateForView)
            
            //aimations
            reloadTinyPicChartWithAnimation()
            reloadToDoListWithAnimation()
            
        case .projectView:
            print("woo ViewType: PROJECT VIEW")
            setProjectForViewValue(projectName: projectForView)
            
            
            //dismiss filter
            dismiss(animated: true)
            
            //aimations
            reloadTinyPicChartWithAnimation()
            reloadToDoListWithAnimation()
            
            
            
        case .upcomingView:
            print("woo ViewType: UPCOMING VIEW")
            
        case .historyView:
            print("woo ViewType: HISTORY VIEW")
            
        }
        
        
    }
    
    //----------------
    //----------------
    //----------------
    //----------------
    //----------------
    
    func fetchInboxTasks(date: Date) -> [NTask] {
        
        return TaskManager.sharedInstance.getTasksForInboxForDate_All(date: date)
    }
    
    func fetchTasksForAllCustomProjctsTodayOpen(date: Date) -> [NTask] {
        print("proj00")
        return TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: date)
    }
    
    func fetchTasksForAllCustomProjctsTodayAll(date: Date) -> [NTask] {
        
        return TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_All(date: date)
    }
    
    func fetchTasksForCustomProject(project: String) -> [NTask] {
        return TaskManager.sharedInstance.getTasksForProjectByName(projectName: project)
    }
    
    
    //----------------------------------------------------
    //----------------------------------------------------
    //----------------------------------------------------
    //MARK:- TASK LIST cellForRowAt
    //----------------------------------------------------
    //----------------------------------------------------
    //----------------------------------------------------
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        print("sls : currentViewType is: \(currentViewType)")
        fetchToDoListSections(viewType: currentViewType)  //defaults to today
        
        self.listSection = ToDoListSections[indexPath.section]
        let item = listSection!.item
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        
        let inboxTasks = fetchInboxTasks(date: dateForTheView)
        var userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
        //        let userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_All(date: dateForTheView)
        
        
        switch currentViewType {
        
        case .todayHomeView: //today home view cells
            
            
            if indexPath.section == 1 {
                
                print("sls : today view !")
                
                let task = inboxTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                if task.isComplete {
                    print("sls: task is complete ! \(task.name)")
                    return buildCompleteInbox(task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    print("sls: task is NOT complete ! \(task.name)")
                    return buildOpenInboxCell_Overdue(task: task)
                } else {
                    print("sls: task is NOT 2 complete ! \(task.name)")
                    return buildOpenInboxCell( task: task)
                }
            } else if indexPath.section == 2 {
                let task = userProjectTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildNonInbox_Overdue(task: task)
                } else {
                    return buildNonInbox( task: task)
                }
            }
            
            
            
        case .customDateView: // custom date view cells
            userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_All(date: dateForTheView)
            if indexPath.section == 1 {
                
                
                let task = inboxTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                if task.isComplete {
                    return buildCompleteInbox(  task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildOpenInboxCell_Overdue( task: task)
                } else {
                    return buildOpenInboxCell( task: task)
                }
            } else if indexPath.section == 2 {
                let task = userProjectTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                
                if task.isComplete {
                    return buildCompleteInbox( task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildNonInbox_Overdue( task: task)
                } else {
                    return buildNonInbox( task: task)
                }
            }
        case .projectView: // custom project view cells
            if indexPath.section == 1 {
                let task = userProjectTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                
                if task.isComplete {
                    return buildCompleteInbox( task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildNonInbox_Overdue( task: task)
                } else {
                    return buildNonInbox( task: task)
                }
            }
        default: //default: today home view cells
            if indexPath.section == 1 {
                
                let task = inboxTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                if task.isComplete {
                    return buildCompleteInbox(  task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildOpenInboxCell_Overdue( task: task)
                } else {
                    return buildOpenInboxCell( task: task)
                }
            } else if indexPath.section == 2 {
                let task = userProjectTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                
                if task.isComplete {
                    return buildCompleteInbox(task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildNonInbox_Overdue( task: task)
                } else {
                    return buildNonInbox( task: task)
                }
            }
        }
        
        cell.setup(
            title: item.TaskTitle,
            subtitle: item.text2,
            footer: TableViewCellSampleData.hasFullLengthLabelAccessoryView(at: indexPath) ? "" : item.text3,
            customView: ToDoListData.createCustomView(imageName: item.image),
            customAccessoryView: listSection!.hasAccessory ? TableViewCellSampleData.customAccessoryView : nil,
            accessoryType: TableViewCellSampleData.accessoryType(for: indexPath)
        )
        
        let showsLabelAccessoryView = TableViewCellSampleData.hasLabelAccessoryViews(at: indexPath)
        cell.titleLeadingAccessoryView = showsLabelAccessoryView ? item.text1LeadingAccessoryView() : nil
        cell.titleTrailingAccessoryView = showsLabelAccessoryView ? item.text1TrailingAccessoryView() : nil
        cell.subtitleLeadingAccessoryView = showsLabelAccessoryView ? item.text2LeadingAccessoryView() : nil
        cell.subtitleTrailingAccessoryView = showsLabelAccessoryView ? item.text2TrailingAccessoryView() : nil
        cell.footerLeadingAccessoryView = showsLabelAccessoryView ? item.text3LeadingAccessoryView() : nil
        cell.footerTrailingAccessoryView = showsLabelAccessoryView ? item.text3TrailingAccessoryView() : nil
        
        cell.titleNumberOfLines = listSection!.numberOfLines
        cell.subtitleNumberOfLines = listSection!.numberOfLines
        cell.footerNumberOfLines = listSection!.numberOfLines
        
        cell.titleLineBreakMode = .byTruncatingMiddle
        
        cell.titleNumberOfLinesForLargerDynamicType = listSection?.numberOfLines == 1 ? 3 : TableViewCell.defaultNumberOfLinesForLargerDynamicType
        cell.subtitleNumberOfLinesForLargerDynamicType = listSection?.numberOfLines == 1 ? 2 : TableViewCell.defaultNumberOfLinesForLargerDynamicType
        cell.footerNumberOfLinesForLargerDynamicType = listSection?.numberOfLines == 1 ? 2 : TableViewCell.defaultNumberOfLinesForLargerDynamicType
        
        cell.backgroundColor = isGrouped ? Colors.Table.Cell.backgroundGrouped : Colors.Table.Cell.background
        cell.topSeparatorType = isGrouped && indexPath.row == 0 ? .full : .none
        let isLastInSection = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1
        cell.bottomSeparatorType = isLastInSection ? .full : .inset
        
        //            cell.isInSelectionMode = listSection!.allowsMultipleSelection ? isInSelectionMode : false
        
        return cell
        
        
        
    }
    
    //    print("woohoo! ")
    //    tableView.reloadData()
    //    calendar.reloadData()
    //    self.updateLineChartData()
    //    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    
    func rescheduleTaskOnSwipe(task: NTask, scheduleTo: Date) {
        TaskManager.sharedInstance
            .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: task)]
            .dueDate = scheduleTo as NSDate
        
        TaskManager.sharedInstance.saveContext()
        
        //        tableView.reloadData()
        //        animateTableViewReload()
        //        updateToDoListAndCharts()
        
        
        //        self.updateLineChartData()
    }
    
    func markTaskCompleteOnSwipe(task: NTask) {
        TaskManager.sharedInstance
            .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: task)]
            .isComplete = true
        
        TaskManager.sharedInstance
            .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: task)]
            .dateCompleted = Date.today() as NSDate
        
        //inboxTasks[indexPath.row
        
        TaskManager.sharedInstance.saveContext()
    }
    
    func markTaskOpenOnSwipe(task: NTask) {
        TaskManager.sharedInstance
            .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: task)]
            .isComplete = false
        
        TaskManager.sharedInstance
            .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: task)]
            .dateCompleted = nil
        
        //inboxTasks[indexPath.row
        
        TaskManager.sharedInstance.saveContext()
        
        // Updating scores is handled when the UI is refreshed
        print("TASK MARKED UNCOMPLETE")
    }
    
    func deleteTaskOnSwipe(task: NTask) {
        let taskIndex = getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: task)
        
        // Remove the task - score will be automatically updated when UI refreshes
        TaskManager.sharedInstance.removeTaskAtIndex(index: taskIndex)
        print("TASK DELETED")
        
        TaskManager.sharedInstance.saveContext()
    }
    
    func updateToDoListAndCharts(tableView: UITableView, indexPath: IndexPath) {
        
        print("woohoo! ")
        tableView.reloadData()
        calendar.reloadData() //not reloading data
        self.updateLineChartData()
        self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let completeTaskAction = UIContextualAction(style: .normal, title: " done ") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let inboxTasks: [NTask]
            let projectsTasks: [NTask]
            let dateForTheView = self.dateForTheView
            
            switch self.currentViewType {
            
            case .todayHomeView:
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
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
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
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
            case .projectView:
                print("SWIPE - PROHECT VIEW") //TODO
            case .upcomingView:
                print("SWIPE - Upcooming") //TODO
            case .historyView:
                print("SWIPE - HISTORY VIEW") //TODO
            }
            
            print("SCORE IS: \(self.calculateTodaysScore())")
            self.scoreCounter.text = "\(self.calculateTodaysScore())"
            self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView);
            self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
            self.title = "\(self.calculateTodaysScore())"
            
            actionPerformed(true)
        }
        
        let undoAction = UIContextualAction(style: .normal, title: "U N D O") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let inboxTasks: [NTask]
            let projectsTasks: [NTask]
            let dateForTheView = self.dateForTheView
            
            switch self.currentViewType {
            
            case .todayHomeView:
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
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
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
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
            case .projectView:
                print("SWIPE - PROHECT VIEW") //TODO
            case .upcomingView:
                print("SWIPE - Upcooming") //TODO
            case .historyView:
                print("SWIPE - HISTORY VIEW") //TODO
            }
            
            print("SCORE IS: \(self.calculateTodaysScore())")
            self.scoreCounter.text = "\(self.calculateTodaysScore())"
            self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView);
            self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
            self.title = "\(self.calculateTodaysScore())"
            
            actionPerformed(true)
        }
        
        let deleteAction = UIContextualAction(style: .destructive, title: "delete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let inboxTasks: [NTask]
            let projectsTasks: [NTask]
            let dateForTheView = self.dateForTheView
            
            switch self.currentViewType {
            
            case .todayHomeView:
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
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
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
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
            case .projectView:
                print("SWIPE - PROHECT VIEW")
            case .upcomingView:
                print("SWIPE - Upcooming") //TODO
            case .historyView:
                print("SWIPE - HISTORY VIEW") //TODO
            }
            
            print("SCORE IS: \(self.calculateTodaysScore())")
            self.scoreCounter.text = "\(self.calculateTodaysScore())"
            self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView);
            self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
            self.title = "\(self.calculateTodaysScore())"
            
            actionPerformed(true)
        }
        
        // Set action colors
        undoAction.backgroundColor = todoColors.primaryColor
        completeTaskAction.backgroundColor = todoColors.completeTaskSwipeColor
        deleteAction.backgroundColor = UIColor.red
        
        let dateForTheView = self.dateForTheView
        let inboxTasks = self.fetchInboxTasks(date: dateForTheView)
        let projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
        
        switch self.currentViewType {
        
        case .todayHomeView:
            
            switch indexPath.section {
            
            case 1:
                if inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction, deleteAction])
                } else if !inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction, deleteAction])
                }
                
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction, deleteAction])
                } else if !projectsTasks[indexPath.row].isComplete {
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
                } else if !inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction, deleteAction])
                }
                
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction, deleteAction])
                } else if !projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction, deleteAction])
                }
                
            default:
                break
            }
        case .projectView:
            print("SWIPE - PROHECT VIEW")
        case .upcomingView:
            print("SWIPE - upccoming VIEW")
        case .historyView:
            print("SWIPE - histtory VIEW")
        }
        
        // Default configuration if none of the above cases match
        return UISwipeActionsConfiguration(actions: [completeTaskAction, deleteAction])
    }
    
    func rescheduleAlertActionMenu(tasks: [NTask], indexPath: IndexPath, tableView: UITableView) {
        
        let currentDateForView = dateForTheView
        let offset_1Days = Calendar.current.date(byAdding: .day, value: 1, to: currentDateForView)!
        let offset_2Days = Calendar.current.date(byAdding: .day, value: 2, to: currentDateForView)!
        let offset_6Days = Calendar.current.date(byAdding: .day, value: 7, to: currentDateForView)!
        
        if dateForTheView == Date.today() {
            
            print("boomff 1")
            let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            controller.addAction(UIAlertAction(title: "Tomorrow", style: .default, handler: { _ in
                print("boomff A")
                self.rescheduleTaskOnSwipe(task: tasks[indexPath.row], scheduleTo: offset_1Days)
                self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
            }))
            
            controller.addAction(UIAlertAction(title: "Day After Tomorrow", style: .default, handler: { _ in
                print("boomff B")
                let today = Date()
                print(today)
                let modifiedDate = Calendar.current.date(byAdding: .day, value: 2, to: today)!
                print(modifiedDate)
                print("reschedule --- TASK DATE --> \(String(describing: TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: tasks[indexPath.row])].dueDate))")
                
                print("reschedule --- NEW DATE -->\(modifiedDate.dateString(in: .medium))")
                self.rescheduleTaskOnSwipe(task: tasks[indexPath.row], scheduleTo: (offset_2Days))
                self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
            }))
            
            controller.addAction(UIAlertAction(title: "Next Week", style: .default, handler: { _ in
                print("boomff B")
                let today = Date()
                print(today)
                let modifiedDate = Calendar.current.date(byAdding: .day, value: 2, to: today)!
                print(modifiedDate)
                print("reschedule --- TASK DATE --> \(String(describing: TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: tasks[indexPath.row])].dueDate))")
                
                print("reschedule --- NEW DATE -->\(modifiedDate.dateString(in: .medium))")
                //            self.rescheduleTaskOnSwipe(task: tasks[indexPath.row], scheduleTo: (modifiedDate))
                self.rescheduleTaskOnSwipe(task: tasks[indexPath.row], scheduleTo: (offset_6Days))
                self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
            }))
            
            //next week //pick week start from constants
            
            controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                print("boomff CANCEL")
            }))
            
            print("boomff 99 ")
            self.present(controller, animated: true, completion: nil)
            
        }
    }
    
    func tableView(_ tableView: UITableView,
                   leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let resheduleTaskAction = UIContextualAction(style: .normal, title: "reschedule") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let inboxTasks: [NTask]
            let projectsTasks: [NTask]
            let dateForTheView = self.dateForTheView
            
            switch self.currentViewType {
            
            case .todayHomeView:
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
                switch indexPath.section {
                
                case 1:
                    
                    if !inboxTasks[indexPath.row].isComplete {
                        
                        //self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                        
                        print("boomff 0")
                        
                        self.rescheduleAlertActionMenu(tasks: inboxTasks, indexPath: indexPath, tableView: tableView)
                        
                        
                    }
                    
                case 2:
                    
                    if !projectsTasks[indexPath.row].isComplete {
                        //                       self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                        
                        self.rescheduleAlertActionMenu(tasks: projectsTasks, indexPath: indexPath, tableView: tableView)
                        
                        //                       tableView.reloadData()
                        //                       self.updateLineChartData()
                        
                        //                       self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                    }
                    
                default:
                    break
                }
                
            case .customDateView:
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
                switch indexPath.section {
                
                case 1:
                    
                    self.rescheduleAlertActionMenu(tasks: inboxTasks, indexPath: indexPath, tableView: tableView)
                    
                case 2:
                    
                    self.rescheduleAlertActionMenu(tasks: inboxTasks, indexPath: indexPath, tableView: tableView)
                    
                default:
                    break
                }
            case .projectView:
                print("SWIPE - PROHECT VIEW") //TODO
            case .upcomingView:
                print("SWIPE - Upcooming") //TODO
            case .historyView:
                print("SWIPE - HISTORY VIEW") //TODO
            }
            
            actionPerformed(true)
        }
        
        // Create an undo task action for the leading swipe
        let undoAction = UIContextualAction(style: .normal, title: "U N D O") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            // Handle undo action
            actionPerformed(true)
        }
        
        undoAction.backgroundColor = todoColors.primaryColor//.systemOrange
        resheduleTaskAction.backgroundColor = todoColors.secondaryAccentColor
        
        let inboxTasks: [NTask]
        let projectsTasks: [NTask]
        let dateForTheView = self.dateForTheView
        
        inboxTasks = self.fetchInboxTasks(date: dateForTheView)
        projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
        
        switch self.currentViewType {
        
        case .todayHomeView:
            
            switch indexPath.section {
            
            case 1:
                
                
                if inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction])
                } else if !inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [resheduleTaskAction])
                }
                
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoAction])
                } else if !projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [resheduleTaskAction])
                }
                
            default:
                break
            }
            
        case .customDateView:
            switch indexPath.section {
            
            case 1:
                
                
                if inboxTasks[indexPath.row].isComplete {
                    //                   return UISwipeActionsConfiguration(actions: [undoTaskAction])
                } else if !inboxTasks[indexPath.row].isComplete {
                    //                   return UISwipeActionsConfiguration(actions: [resheduleTaskAction])
                }
                
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    //                   return UISwipeActionsConfiguration(actions: [undoTaskAction])
                } else if !projectsTasks[indexPath.row].isComplete {
                    //                   return UISwipeActionsConfiguration(actions: [resheduleTaskAction])
                }
                
            default:
                break
            }
        case .projectView:
            print("SWIPE - PROHECT VIEW")
        case .upcomingView:
            print("SWIPE - upccoming VIEW")
        case .historyView:
            print("SWIPE - histtory VIEW")
        }
        
        
        return UISwipeActionsConfiguration(actions: [])
    }
}


// MARK: - TableViewCellDemoController: UITableViewDelegate

extension HomeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            
            let inboxTitleHeaderView = UIStackView()
            
            
            inboxTitleHeaderView.addSubview(toDoListHeaderLabel)
            inboxTitleHeaderView.addSubview(lineSeparator)
            
            
            toDoListHeaderLabel.center(in: inboxTitleHeaderView, offset: CGPoint(x: 0, y: 8))
            let filterIconConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .light, scale: .default)
            
            let filterIconImage = UIImage(systemName: "line.horizontal.3.decrease.circle", withConfiguration: filterIconConfiguration)
            
            let colouredCalPullDownImage = filterIconImage?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal)
            
            let filterMenuHomeButton = UIButton()
            
            inboxTitleHeaderView.addSubview(filterMenuHomeButton)
            
            filterMenuHomeButton.leftToSuperview(offset: 10)
            filterMenuHomeButton.setImage(colouredCalPullDownImage, for: .normal)
            filterMenuHomeButton.addTarget(self, action:  #selector(showTopDrawerButtonTapped), for: .touchUpInside)
            
            toDoListHeaderLabel.font = setFont(fontSize: 20, fontweight: .medium, fontDesign: .rounded)
            toDoListHeaderLabel.textAlignment = .center
            toDoListHeaderLabel.adjustsFontSizeToFitWidth = true
            toDoListHeaderLabel.textColor = .label
            
            let now = Date.today
            var sectionLabel = ""
            if (dateForTheView == now()) {
                sectionLabel =  "Today"
            } else if (dateForTheView == Date.tomorrow()){
                sectionLabel = "Tomorrow"
            } else if (dateForTheView == Date.yesterday()) {
                sectionLabel = "Yesterday"
            } else {
                let customDay = dateForTheView
                if("\(customDay.day)".count < 2) {
                    homeDate_Day.text = "0\(customDay.day)"
                } else {
                    homeDate_Day.text = "\(customDay.day)"
                }
                
                
                let dateFormatter_Weekday = DateFormatter()
                dateFormatter_Weekday.dateFormat = "EEEE"
                let nameOfWeekday = dateFormatter_Weekday.string(from: customDay)
                
                let c = nameOfWeekday
                
                sectionLabel = "\(c)"
            }
            toDoListHeaderLabel.text = sectionLabel
            
            lineSeparator.frame = CGRect(x: 0, y: 32, width: UIScreen.main.bounds.width, height: 1)
            lineSeparator.backgroundColor = UIColor.black
            
            inboxTitleHeaderView.addSubview(lineSeparator)
            
            return inboxTitleHeaderView
            
            
        } else if section == 1 {
            let header = UIStackView()
            
            header.backgroundColor = .clear
            
            return header
        }
        else if section == 2 {
            
            let projectsHeader = UIStackView()
                        projectsHeader.backgroundColor = .clear
                        let projectsHeaderLabel = UILabel()
                        projectsHeader.addSubview(projectsHeaderLabel)
            
                        projectsHeaderLabel.center(in: projectsHeader, offset: CGPoint(x: 0, y: 8))
            //
                        projectsHeaderLabel.font = setFont(fontSize: 20, fontweight: .medium, fontDesign: .rounded)
                        projectsHeaderLabel.textAlignment = .center
                        projectsHeaderLabel.adjustsFontSizeToFitWidth = true
                        projectsHeaderLabel.textColor = .label
                        projectsHeaderLabel.text = "Projects"
            
            return projectsHeader
            
            
            
            
        } else {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TableViewHeaderFooterView.identifier) as! TableViewHeaderFooterView
            let section = ToDoListSections[section]
            header.setup(style: .divider, title: section.sectionTitle)
            return header
        }
        
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let title = ToDoListSections[indexPath.section].item.TaskTitle
        showAlertForDetailButtonTapped(title: title)
    }
    
    private func showAlertForDetailButtonTapped(title: String) {
        let alert = UIAlertController(title: "\(title) detail button was tapped", message: nil, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true)
    }
}
