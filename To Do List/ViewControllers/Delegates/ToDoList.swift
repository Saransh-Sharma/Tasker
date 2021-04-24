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

extension HomeViewController: BEMCheckBoxDelegate {
    
    func didTap(_ checkBox: BEMCheckBox) {
        // do stuff here
        
        // 1
        currentCheckboxTag = checkBox.tag
        
        print("checkboc tag: \(currentCheckboxTag)")
        print("checkboc idex: \(currentIndex)")
        
        checkBoxCompleteAction(indexPath: currentIndex, checkBox: checkBox)
        
    }
    
    @objc private func showTopDrawerButtonTapped(sender: UIButton) {
        let rect = sender.superview!.convert(sender.frame, to: nil)
        
        presentDrawer(sourceView: sender, presentationOrigin: rect.maxY+8, presentationDirection: .down, contentView: containerForActionViews(), customWidth: true)
    }
    
    func checkBoxCompleteAction(indexPath: IndexPath, checkBox: BEMCheckBox) {
        if checkBox.tag == indexPath.row {
            checkBox.setOn(true, animated: true)
        }
        let inboxTasks: [NTask]
        let projectsTasks: [NTask]
        let dateForTheView = self.dateForTheView
        
        inboxTasks = TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(projectName: ProjectManager.sharedInstance.defaultProject, date: dateForTheView)
        
        projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
        //                   let sortedEveningTask = projectsTasks.sorted(by: { !$0.isComplete && $1.isComplete })
        
        switch indexPath.section {
        case 1:
            TaskManager.sharedInstance
                .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: inboxTasks[indexPath.row])]
                .isComplete = true
            
            TaskManager.sharedInstance
                .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: inboxTasks[indexPath.row])]
                .dateCompleted = Date.today() as NSDate
            
            TaskManager.sharedInstance.saveContext()
            
            print("inboox MARKINNG COMPLETE: \(TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: inboxTasks[indexPath.row])].name)")
            
            tableView.reloadData()
            self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
            
        case 2:
            TaskManager.sharedInstance
                .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: projectsTasks[indexPath.row])]
                .isComplete = true
            
            TaskManager.sharedInstance
                .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: projectsTasks[indexPath.row])]
                .dateCompleted = Date.today() as NSDate
            
            TaskManager.sharedInstance.saveContext()
            
            print("project task MARKINNG COMPLETE: \(TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: projectsTasks[indexPath.row])].name)")
            tableView.reloadData()
            self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
            
        default:
            break
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
        //        if isInSelectionMode {
        //            let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
        //            navigationItem.title = selectedCount == 1 ? "1 item selected" : "\(selectedCount) items selected"
        //        } else {
        //            navigationItem.title = title
        //        }
    }
    
    public func updateTableView() {
        tableView.backgroundColor = isGrouped ? Colors.Table.backgroundGrouped : Colors.Table.background
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
        //        if section == 0 {
        //            return 0
        //        } else if section == 1 {
        //            let inboxTasks = TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(projectName: ProjectManager.sharedInstance.defaultProject, date: dateForTheView)
        //            return inboxTasks.count //TODO: Add completed tasks to this
        //        } else if section == 2 {
        //            let userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
        //            return userProjectTasks.count //TODO: Add completed tasks to this
        //        }
        //
        //        else {
        //            return TableViewCellSampleData.numberOfItemsInSection
        //        }
        
        
        
        //        return ToDoListSections.c
        
        
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
                print("ref: numberOfRowsInSection - todayHomeView - C - projectTaskCount \(customProjectTasks.count)")
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
        //            else if section == 2 { //Goal: have sub projects as section headers; this is built at run time
        //
        //                     }
        case .customDateView:
            if section == 1 { //inbox tasks
                let inboxTasks = fetchInboxTasks(date: dateForTheView)
                print("dud inbox task ccount:  \(inboxTasks.count)")
                return inboxTasks.count
            } else if section == 2 { //projects
                //                let customProjectTasks = fetchTasksForAllCustomProjctsTodayOpen(date: dateForTheView)
                
                let customProjectTasks = fetchTasksForAllCustomProjctsTodayAll(date: dateForTheView)
                for each in customProjectTasks {
                    print("rhur print list : \(each.name)")
                }
                print("rhur : rows in section 2 : \(customProjectTasks.count)")
                
                
                //                let morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: date)
                //                let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: date)
                //                let allTasks = morningTasks+eveningTasks
                
                
                
                print("dud custom task ccount:  \(customProjectTasks.count)")
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
    
    //        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    //            switch section {
    //            case 0:
    //                let now = Date.today
    //                if (dateForTheView == now()) {
    //                    return "Today"
    //                } else if (dateForTheView == Date.tomorrow()){
    //                    return "Tomorrow"
    //                } else if (dateForTheView == Date.yesterday()) {
    //                    return "Yesterday"
    //                }
    //                else {
    //                    return "Tasks \(dateForTheView.stringIn(dateStyle: .full, timeStyle: .none))"
    //                }
    //
    //            //            return "Today's Tasks"
    //            case 1:
    //                return "Evening"
    //            default:
    //                return "DEFAULT HOLA !!"
    //            }
    //        }
    
    //build 5 types of cells here in 5 functions; tthis returns a UITableViewCell
    
    func setupCheckbox(cell: UITableViewCell) -> BEMCheckBox {
        let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: cell.bounds.minX+5, y: cell.bounds.minY+10, width: 20, height: 25))
        checkBox.lineWidth = 1.0
        checkBox.animationDuration = 0.40
        checkBox.setOn(true, animated: false)
        checkBox.boxType = .circle
        checkBox.onAnimationType = .oneStroke
        checkBox.offAnimationType = .oneStroke
        checkBox.onTintColor = todoColors.primaryColor
        //                     checkBox.addTarget(HomeViewController.self, action:  #selector(checkboxTappedAction), for: .touchUpInside)
        checkBox.setOn(false, animated: true)
        return checkBox
    }
    
    //open inbox
    func buildOpenInboxCell(task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        let foo = setupCheckbox(cell: cell)
        
        
        cell.setup(
            title: task.name,
            subtitle: "",
            footer: "",
            customView: foo,
            accessoryType: .none
        )
        cell.customViewSize = .small
        cell.titleNumberOfLines = 0
        cell.titleLeadingAccessoryView = .none
        cell.titleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])
        
        
        
        return cell
    }
    //open inbox overdue
    func buildOpenInboxCell_Overdue(checkBox: BEMCheckBox,task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        let foo = setupCheckbox(cell: cell)
        
        cell.setup(
            title: task.name,
            subtitle: "",
            footer: "",
            customView: checkBox,
            customAccessoryView: TableViewCellSampleData.customAccessoryView,
            accessoryType: .none
        )
        cell.customViewSize = .small
        cell.titleNumberOfLines = 0
        //                checkBox.addTarget(self, action:  #selector(checkboxTappedAction), for: .touchUpInside)
        
        //                cell.titleTrailingAccessoryView = item.text1TrailingAccessoryView()
        cell.titleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])//item.text1LeadingAccessoryView()
        
        return cell
    }
    //open inbox overdue
    func buildCompleteInbox(checkBox: BEMCheckBox, task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        cell.setup(
            title: task.name,
            subtitle: "",
            footer: "",
            //                    customView: TableViewSampleData.createCustomView(imageName: item.image),
            //            customView: checkBox,
            //            customView: "",
            //                                            customAccessoryView: TableViewCellSampleData.customAccessoryView,
            accessoryType: .checkmark
        )
        checkBox.setOn(true, animated: true)
        cell.customViewSize = .small
        cell.titleNumberOfLines = 0
        cell.isEnabled = false
        //                checkBox.addTarget(self, action:  #selector(checkboxTappedAction), for: .touchUpInside)
        
        //                cell.titleTrailingAccessoryView = item.text1TrailingAccessoryView()
        //        cell.titleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])//item.text1LeadingAccessoryView()
        
        return cell
    }
    //open NON inbox
    func buildNonInbox(checkBox: BEMCheckBox, task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        cell.setup(
            title: task.name,
            subtitle: (task.project ?? "") as String,
            footer: "",
            customView: checkBox
            //                                           rcustomAccessoryView: TableViewCellSampleData.customAccessoryView,
            //                    accessoryType: TableViewCellSampleData.accessoryType(for: indexPath)
        )
        cell.customViewSize = .small
        cell.titleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])
        cell.subtitleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])
        cell.titleNumberOfLines = 0
        
        //                cell.titleTrailingAccessoryView = item.text1TrailingAccessoryView()
        //        cell.titleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])//item.text1LeadingAccessoryView()
        
        return cell
    }    //open inbox overdue
    func buildNonInbox_Overdue(checkBox: BEMCheckBox, task: NTask) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        cell.setup(
            title: task.name,
            subtitle: (task.project ?? "") as String,
            footer: "",
            customView: checkBox,
            //                                           rcustomAccessoryView: TableViewCellSampleData.customAccessoryView,
            customAccessoryView: TableViewCellSampleData.customAccessoryView,
            accessoryType: .none
        )
        
        cell.titleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])
        cell.subtitleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])
        cell.customViewSize = .small
        cell.titleNumberOfLines = 0
        
        //                cell.titleTrailingAccessoryView = item.text1TrailingAccessoryView()
        //        cell.titleLeadingAccessoryView = TableViewCellSampleData.createIconsAccessoryView(images: ["success-12x12"])//item.text1LeadingAccessoryView()
        
        return cell
    }
    
    //    func coompleteTaksViaCheckbox() {
    //        let inboxTasks = TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(projectName: "inbox", date: dateForTheView)
    //              let userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
    //
    //        TaskManager.removeTaskAtIndex(<#T##self: TaskManager##TaskManager#>)
    //    }
    
    //    enum ViewType: String {
    //        case DateView = "date"
    //        case ProjectView = "project"
    //        case UpcomingView = "upcoming"
    //    }
    
    //----------------
    //----------------
    //----------------
    //----------------
    //----------------
    //----------------
    
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
        //    func updateViewForHome(viewType: ToDoListViewType, dateForView: Date, projectForView: String = ProjectManager.sharedInstance.defaultProject) {
        
        
        //        var movement = ;
        //        if viewType == ViewType.todayHomeView {
        //
        //        }
        
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
        
        //        switch movement {
        //        case .forward:
        //            print("you moved forward")
        //        case .back:
        //            print("you moved backwards")
        //        case .left:
        //            print("you moved to the left")
        //        case .right:
        //            print("you moved to the right")
        //        }
        
        
        ////        if (ViewType.DateView.rawValue.lowercased() == "date") {
        //        if viewType.T
        //            print("ViewSetter: This is dateview")
        //
        //        } else if (ViewType.ProjectView.rawValue.lowercased() == "project") {
        //            print("ViewSetter: This is projctView")
        //        } else if (ViewType.UpcomingView.rawValue.lowercased() == "upcoming") {
        //            print("ViewSetter: This is upcoming")
        //        }
        
        
    }
    
    //----------------
    //----------------
    //----------------
    //----------------
    //----------------
    
    func fetchInboxTasks(date: Date) -> [NTask] {
        
        //        return TaskManager.sharedInstance.getTasksForCustomProjectByNameForDate_All(projectName: ProjectManager.sharedInstance.defaultProject, date: date)
        return TaskManager.sharedInstance.getTasksForInboxForDate_All(date: date)
        
        
        //        return TaskManager.sharedInstance.getAllInboxTasks
    }
    
    func fetchTasksForAllCustomProjctsTodayOpen(date: Date) -> [NTask] {
        //          return TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(projectName: ProjectManager.sharedInstance.defaultProject, date: dateForTheView)
        return TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: date)
    }
    
    func fetchTasksForAllCustomProjctsTodayAll(date: Date) -> [NTask] {
        //          return TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(projectName: ProjectManager.sharedInstance.defaultProject, date: dateForTheView)
        return TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_All(date: date)
    }
    
    func fetchTasksForCustomProject(project: String) -> [NTask] {
        return TaskManager.sharedInstance.getTasksForProjectByName(projectName: project)
        //        return TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: date)
    }
    
    
    //----------------------------------------------------
    //----------------------------------------------------
    //----------------------------------------------------
    //MARK:- TASK LIST cellForRowAt
    //----------------------------------------------------
    //----------------------------------------------------
    //----------------------------------------------------
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //        let section = sections[indexPath.section]
        
        
        print("sls : currentViewType is: \(currentViewType)")
        fetchToDoListSections(viewType: currentViewType)  //defaults to today
        
        self.listSection = ToDoListSections[indexPath.section]
        let item = listSection!.item
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as! TableViewCell
        
        
        let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: cell.bounds.minX+5, y: cell.bounds.minY+10, width: 20, height: 25))
        checkBox.lineWidth = 1.0
        checkBox.animationDuration = 0.40
        checkBox.setOn(true, animated: false)
        checkBox.boxType = .circle
        checkBox.onAnimationType = .oneStroke
        checkBox.offAnimationType = .oneStroke
        checkBox.onTintColor = todoColors.primaryColor
        //        checkBox.addTarget(HomeViewController.self, action:  #selector(checkboxTappedAction), for: .touchUpInside)
        checkBox.setOn(false, animated: true)
        
        
        //--
        checkBox.tag = indexPath.row
        currentCheckboxTag = indexPath.row
        currentIndex = indexPath
        
        
        checkBox.delegate = self
        ///--
        
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
                    return buildCompleteInbox( checkBox: checkBox, task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    print("sls: task is NOT complete ! \(task.name)")
                    return buildOpenInboxCell_Overdue(checkBox: checkBox, task: task)
                } else {
                    print("sls: task is NOT 2 complete ! \(task.name)")
                    return buildOpenInboxCell( task: task)
                }
            } else if indexPath.section == 2 {
                let task = userProjectTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                
                if task.isComplete {
                    return buildCompleteInbox(checkBox: checkBox, task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildNonInbox_Overdue(checkBox: checkBox, task: task)
                } else {
                    return buildNonInbox(checkBox: checkBox, task: task)
                }
            }
            
            
            
        case .customDateView: // custom date view cells
            userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_All(date: dateForTheView)
            if indexPath.section == 1 {
                
                
                let task = inboxTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                if task.isComplete {
                    return buildCompleteInbox( checkBox: checkBox, task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildOpenInboxCell_Overdue(checkBox: checkBox, task: task)
                } else {
                    return buildOpenInboxCell( task: task)
                }
            } else if indexPath.section == 2 {
                let task = userProjectTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                
                if task.isComplete {
                    return buildCompleteInbox(checkBox: checkBox, task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildNonInbox_Overdue(checkBox: checkBox, task: task)
                } else {
                    return buildNonInbox(checkBox: checkBox, task: task)
                }
            }
        case .projectView: // custom project view cells
            if indexPath.section == 1 {
                let task = userProjectTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                
                if task.isComplete {
                    return buildCompleteInbox(checkBox: checkBox, task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildNonInbox_Overdue(checkBox: checkBox, task: task)
                } else {
                    return buildNonInbox(checkBox: checkBox, task: task)
                }
            }
        default: //default: today home view cells
            if indexPath.section == 1 {
                
                let task = inboxTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                if task.isComplete {
                    return buildCompleteInbox( checkBox: checkBox, task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildOpenInboxCell_Overdue(checkBox: checkBox, task: task)
                } else {
                    return buildOpenInboxCell( task: task)
                }
            } else if indexPath.section == 2 {
                let task = userProjectTasks[indexPath.row]
                
                let taskDueDate = task.dueDate
                
                
                
                if task.isComplete {
                    return buildCompleteInbox(checkBox: checkBox, task: task)
                }
                else if (Date.today() > taskDueDate! as Date) {
                    return buildNonInbox_Overdue(checkBox: checkBox, task: task)
                } else {
                    return buildNonInbox(checkBox: checkBox, task: task)
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
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        
        
        
        
        let completeTaskAction = UIContextualAction(style: .normal, title: "Complete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let inboxTasks: [NTask]
            let projectsTasks: [NTask]
            let dateForTheView = self.dateForTheView
            
            //            inboxTasks = self.fetchInboxTasks(date: dateForTheView)
            
            
            switch self.currentViewType {
            
            case .todayHomeView:
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
                switch indexPath.section {
                
                case 1:
                    
                    if !inboxTasks[indexPath.row].isComplete {
                        self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
                        tableView.reloadData()
                        self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                    }
                    
                case 2:
                    
                    if !projectsTasks[indexPath.row].isComplete {
                        self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                        tableView.reloadData()
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
                        tableView.reloadData()
                        self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                    }
                    
                case 2:
                    
                    if !projectsTasks[indexPath.row].isComplete {
                        self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
                        tableView.reloadData()
                        self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
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
        
        //        print("SCORE IS: \(self.calculateTodaysScore())")
        //        self.scoreCounter.text = "\(self.calculateTodaysScore())"
        //        self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView);
        //        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
        //        self.title = "\(self.calculateTodaysScore())"
        //        actionPerformed(true)
        
        let undoTaskAction = UIContextualAction(style: .normal, title: "U N D O") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let inboxTasks: [NTask]
            let projectsTasks: [NTask]
            let dateForTheView = self.dateForTheView
            
            //            inboxTasks = self.fetchInboxTasks(date: dateForTheView)
            
            
            switch self.currentViewType {
            
            case .todayHomeView:
                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
                projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
                
                switch indexPath.section {
                
                case 1:
                    
                    if inboxTasks[indexPath.row].isComplete {
                        self.markTaskOpenOnSwipe(task: inboxTasks[indexPath.row])
                        tableView.reloadData()
                        self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                    }
                    
                case 2:
                    
                    if projectsTasks[indexPath.row].isComplete {
                        self.markTaskOpenOnSwipe(task: projectsTasks[indexPath.row])
                        tableView.reloadData()
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
                    
                    if inboxTasks[indexPath.row].isComplete {
                        self.markTaskOpenOnSwipe(task: inboxTasks[indexPath.row])
                        tableView.reloadData()
                        self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
                    }
                    
                case 2:
                    
                    if projectsTasks[indexPath.row].isComplete {
                        self.markTaskOpenOnSwipe(task: projectsTasks[indexPath.row])
                        tableView.reloadData()
                        self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
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
        undoTaskAction.backgroundColor = todoColors.primaryColor
        completeTaskAction.backgroundColor = todoColors.completeTaskSwipeColor
        
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
                    return UISwipeActionsConfiguration(actions: [undoTaskAction])
                } else if !inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction])
                }
                
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoTaskAction])
                } else if !projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction])
                }
                
            default:
                break
            }
            
        case .customDateView:
            switch indexPath.section {
            
            case 1:
                
                
                if inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoTaskAction])
                } else if !inboxTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction])
                }
                
            case 2:
                if projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [undoTaskAction])
                } else if !projectsTasks[indexPath.row].isComplete {
                    return UISwipeActionsConfiguration(actions: [completeTaskAction])
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
        
        return UISwipeActionsConfiguration(actions: [completeTaskAction,undoTaskAction])
    }
    
    //    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    //
    //        let completeTaskAction = UIContextualAction(style: .normal, title: "Complete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
    //
    //            let inboxTasks: [NTask]
    //            let projectsTasks: [NTask]
    //            let dateForTheView = self.dateForTheView
    //
    //
    //
    //            switch self.currentViewType {
    //
    //            case .todayHomeView:
    //                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
    //
    //                switch indexPath.section {
    //
    //                case 1:
    //
    //                    self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
    //
    //                    tableView.reloadData()
    //                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    //
    //
    //                case 2:
    //
    //                    projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
    //
    //
    //                    self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
    //
    //                    tableView.reloadData()
    //                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    //
    //                default:
    //                    break
    //                }
    //
    //            case .customDateView:
    //                inboxTasks = self.fetchInboxTasks(date: dateForTheView)
    //                print("SWIPE - CUSTOM DATTE")
    //                switch indexPath.section {
    //
    //                case 1:
    //
    //                    self.markTaskCompleteOnSwipe(task: inboxTasks[indexPath.row])
    //
    //                    tableView.reloadData()
    //                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    //
    //
    //                case 2:
    //
    //                    projectsTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
    //
    //
    //                    self.markTaskCompleteOnSwipe(task: projectsTasks[indexPath.row])
    //
    //                    tableView.reloadData()
    //                    self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    //
    //                default:
    //                    break
    //                }
    //            case .projectView:
    //                print("SWIPE - PROHECT VIEW") //TODO
    //            case .upcomingView:
    //                print("SWIPE - Upcooming") //TODO
    //            case .historyView:
    //                print("SWIPE - HISTORY VIEW") //TODO
    //            }
    //
    //
    //            print("SCORE IS: \(self.calculateTodaysScore())")
    //            self.scoreCounter.text = "\(self.calculateTodaysScore())"
    //            self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView);
    //            self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
    //
    //            //            tableView.reloadData()
    //            //            self.animateTableViewReload()
    //
    //            self.title = "\(self.calculateTodaysScore())"
    //            actionPerformed(true)
    //        }
    //
    //        completeTaskAction.backgroundColor = todoColors.completeTaskSwipeColor
    //
    //        //        NSUIColor(red: 192/255.0, green: 255/255.0, blue: 140/255.0, alpha: 1.0), green
    //        //                 NSUIColor(red: 255/255.0, green: 247/255.0, blue: 140/255.0, alpha: 1.0), yellow
    //        //                 NSUIColor(red: 255/255.0, green: 208/255.0, blue: 140/255.0, alpha: 1.0), orange
    //        //                 NSUIColor(red: 140/255.0, green: 234/255.0, blue: 255/255.0, alpha: 1.0), blue
    //        //                 NSUIColor(red: 255/255.0, green: 140/255.0, blue: 157/255.0, alpha: 1.0) red
    //
    //        return UISwipeActionsConfiguration(actions: [completeTaskAction])
    //    }
    
    
    
}

// MARK: - TableViewCellDemoController: UITableViewDelegate

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            //            let headStack = HomeViewController.createTopHeaderVerticalContainer()
            
            let headerView = UIView()
            
            //            myLabel.frame = CGRect(x:5, y: 0, width: (UIScreen.main.bounds.width/3) + 50, height: 30)
            toDoListHeaderLabel.frame = CGRect(x:5, y: 4, width: (UIScreen.main.bounds.width), height: 30)
            
            //line.horizontal.3.decrease.circle
            let filterIconConfiguration = UIImage.SymbolConfiguration(pointSize: 32, weight: .light, scale: .default)
            let filterIconImage = UIImage(systemName: "line.horizontal.3.decrease.circle", withConfiguration: filterIconConfiguration)
            let colouredCalPullDownImage = filterIconImage?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal)
            //
            //            let calButton = colouredCalPullDownImage //UIImage(named: "cal_Icon")
            let filterMenuHomeButton = UIButton()
            //            filterMenuHomeButton.frame = CGRect(x:5, y: -10 , width: 50, height: 50)
            //            filterMenuHomeButton.frame = CGRect(x:5, y: 1 , width: 30, height: 30)
            filterMenuHomeButton.frame = CGRect(x:10, y: 2 , width: 32, height: 32)
            filterMenuHomeButton.setImage(colouredCalPullDownImage, for: .normal)
            
            filterMenuHomeButton.addTarget(self, action:  #selector(showTopDrawerButtonTapped), for: .touchUpInside)
            //
            
            
            
            
            
            
            //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
            toDoListHeaderLabel.font = setFont(fontSize: 24, fontweight: .medium, fontDesign: .rounded)//UIFont(name: "HelveticaNeue-Bold", size: 20)
            toDoListHeaderLabel.textAlignment = .center
            toDoListHeaderLabel.adjustsFontSizeToFitWidth = true
            toDoListHeaderLabel.textColor = .label
            //            myLabel.backgroundColor = .black
            //                            myLabel.text = "GREEN GREEN"//tableView(tableView, gree: section)
            
            let now = Date.today
            var sectionLabel = ""
            if (dateForTheView == now()) {
                sectionLabel =  "Today"
            } else if (dateForTheView == Date.tomorrow()){
                sectionLabel = "Tomorrow"
            } else if (dateForTheView == Date.yesterday()) {
                sectionLabel = "Yesterday"
            } else {
                sectionLabel = "xoom xoom xoom"
            }
            toDoListHeaderLabel.text = sectionLabel//tableView(tableView, gree: section)
            
            //                   let headerView = UIView()
            
            lineSeparator.frame = CGRect(x: 0, y: 33, width: UIScreen.main.bounds.width, height: 1)
            lineSeparator.backgroundColor = UIColor.black
            
            
            
            
            //                            headStack.addArrangedSubview(myLabel)
            //            headStack.addArrangedSubview(UIView())
            //                 headStack.addArrangedSubview(Separator())
            //            headStack.addArrangedSubview(UIView())
            
            //                            headStack.addArrangedSubview(lineSeparator)
            //            headStack.addArrangedSubview(UIView())
            
            headerView.addSubview(filterMenuHomeButton)
            headerView.addSubview(toDoListHeaderLabel)
            
            headerView.addSubview(lineSeparator)
            
            
            
            
            return headerView
            //                            return headStack
            
            //            return
            
        } else if section == 1 {
            let headerView = UIView()
            return headerView
        } else {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TableViewHeaderFooterView.identifier) as! TableViewHeaderFooterView
            let section = ToDoListSections[section]
            //            header.setup(style: section.headerStyle, title: section.title)
            header.setup(style: .divider, title: section.sectionTitle)
            return header
        }
        
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let title = ToDoListSections[indexPath.section].item.TaskTitle
        showAlertForDetailButtonTapped(title: title)
    }
    
    //    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    //        if isInSelectionMode {
    //            updateNavigationTitle()
    //        } else {
    //            tableView.deselectRow(at: indexPath, animated: true)
    //        }
    //    }
    
    //    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
    //        if isInSelectionMode {
    //            updateNavigationTitle()
    //        }
    //    }
    
    private func showAlertForDetailButtonTapped(title: String) {
        let alert = UIAlertController(title: "\(title) detail button was tapped", message: nil, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true)
    }
}
