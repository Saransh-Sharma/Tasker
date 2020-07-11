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
        //        let rect2 = lineSeparator.frame
        //         presentDrawer(sourceView: sender, presentationOrigin: rect.maxY, presentationDirection: .down, contentView: containerForActionViews(), customWidth: true)
        
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
    
    
    
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:- OLD TABLE VIEW
    //
    //
    //----------------------- *************************** -----------------------
    
    //    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    //        let headerView = UIView()
    //
    //
    //        if section == 0 {
    //            let myLabel = UILabel()
    //            //            myLabel.frame = CGRect(x:5, y: 0, width: (UIScreen.main.bounds.width/3) + 50, height: 30)
    //            myLabel.frame = CGRect(x:5, y: 8, width: (UIScreen.main.bounds.width), height: 30)
    //
    //            //line.horizontal.3.decrease.circle
    //            let filterIconConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .thin, scale: .default)
    //            let filterIconImage = UIImage(systemName: "line.horizontal.3.decrease.circle", withConfiguration: filterIconConfiguration)
    //            let colouredCalPullDownImage = filterIconImage?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal)
    //            //
    //            //            let calButton = colouredCalPullDownImage //UIImage(named: "cal_Icon")
    //            let filterMenuHomeButton = UIButton()
    //            //            filterMenuHomeButton.frame = CGRect(x:5, y: -10 , width: 50, height: 50)
    //            //            filterMenuHomeButton.frame = CGRect(x:5, y: 1 , width: 30, height: 30)
    //            filterMenuHomeButton.frame = CGRect(x:5, y: 8 , width: 30, height: 30)
    //            filterMenuHomeButton.setImage(colouredCalPullDownImage, for: .normal)
    //
    //            filterMenuHomeButton.addTarget(self, action:  #selector(showTopDrawerButtonTapped), for: .touchUpInside)
    //            //
    //
    //            headerView.addSubview(filterMenuHomeButton)
    //
    //
    //
    //
    //            //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
    //            myLabel.font = setFont(fontSize: 24, fontweight: .medium, fontDesign: .rounded)//UIFont(name: "HelveticaNeue-Bold", size: 20)
    //            myLabel.textAlignment = .center
    //            myLabel.adjustsFontSizeToFitWidth = true
    //            myLabel.textColor = .label
    //            myLabel.text = self.tableView(tableView, titleForHeaderInSection: section)
    //
    //            //                   let headerView = UIView()
    //
    //            lineSeparator.frame = CGRect(x: 0, y: 45, width: UIScreen.main.bounds.width, height: 1)
    //            lineSeparator.backgroundColor = UIColor.black
    //
    //            headerView.addSubview(lineSeparator)
    //            headerView.addSubview(myLabel)
    //
    //            //            headerView.ad
    //
    //            return headerView
    //        } else if section == 1 {
    //
    //            let myLabel2 = UILabel()
    //            myLabel2.frame = CGRect(x:5, y: 0, width: UIScreen.main.bounds.width/3, height: 30)
    //            //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
    //            myLabel2.font = setFont(fontSize: 20, fontweight: .medium, fontDesign: .rounded)//UIFont(name: "HelveticaNeue-Bold", size: 20)
    //            myLabel2.textAlignment = .left
    //            myLabel2.adjustsFontSizeToFitWidth = true
    //            myLabel2.textColor = .secondaryLabel
    //            myLabel2.text = self.tableView(tableView, titleForHeaderInSection: section)
    //
    //            headerView.addSubview(myLabel2)
    //
    //
    //        }
    //
    //
    //        //        let myLabel = UILabel()
    //        //        myLabel.frame = CGRect(x:5, y: 0, width: UIScreen.main.bounds.width/3, height: 30)
    //        //        //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
    //        //        myLabel.font = setFont(fontSize: 24, fontweight: .medium, fontDesign: .serif)//UIFont(name: "HelveticaNeue-Bold", size: 20)
    //        //        myLabel.textAlignment = .right
    //        //        myLabel.adjustsFontSizeToFitWidth = true
    //        //        myLabel.textColor = .secondaryLabel
    //        //        myLabel.text = self.tableView(tableView, titleForHeaderInSection: section)
    //        //
    //        //        let headerView = UIView()
    //        //        headerView.addSubview(myLabel)
    //        //
    //        //        return headerView
    //
    //        return headerView
    //    }
    //
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
    //
    //    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    //
    //        switch section {
    //        case 0:
    //            let morningTasks: [NTask]
    //            if(dateForTheView == Date.today()) { //morning tasks today: rollover unfinished tasks + tasks added today + tasks completed today
    //                morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
    //
    //            } else { //get morning tasks without rollover
    //                morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
    //            }
    //            print("Morning ROW COUNT:  \(morningTasks.count)")
    //            return morningTasks.count
    //        case 1:
    //            //            print("Items in evening: \(TaskManager.sharedInstance.getEveningTasks.count)")
    //            //            return TaskManager.sharedInstance.getEveningTasks.count
    //            //                let eveTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
    //            let eveTasks: [NTask]
    //            if(dateForTheView == Date.today()) {
    //                eveTasks = TaskManager.sharedInstance.getEveningTasksForToday()
    //
    //
    //            } else { //get morning tasks without rollover
    //                eveTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
    //            }
    //            print("Evening ROW COUNT:  \(eveTasks.count)")
    //
    //            return eveTasks.count
    //        default:
    //            return 0;
    //        }
    //    }
    //
    //
    //    //    tableView.register(TableViewCell.self, forCellReuseIdentifier: "openTaskCell")
    //
    //    // MARK:- CELL AT ROWUITableViewRowAction
    //
    //    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    //
    //        var currentTask: NTask!
    //        let completedTaskCell = tableView.dequeueReusableCell(withIdentifier: "completedTaskCell", for: indexPath)
    //        let openTaskCell = tableView.dequeueReusableCell(withIdentifier: "openTaskCell", for: indexPath)
    //
    //        switch indexPath.section {
    //        case 0:
    //            print("morning section index is: \(indexPath.row)")
    //
    //            //getMorningTasksForToday
    //            let morningTasks: [NTask]
    //            if(dateForTheView == Date.today()) {
    //                morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
    //            } else { //get morning tasks without rollover; these are tasks when view is not today
    //                morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
    //            }
    //            //                currentTask = morningTasks[indexPath.row]
    //
    //            let sortedMorningTask = morningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
    //            currentTask = sortedMorningTask[indexPath.row]
    //
    //
    //        case 1:
    //            print("evening section index is: \(indexPath.row)")
    //
    //            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
    //
    //            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
    //
    //            //                let evenningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
    //            let evenningTasks: [NTask]
    //            if(dateForTheView == Date.today()) {
    //                evenningTasks = TaskManager.sharedInstance.getEveningTasksForToday()
    //            } else { //get eveninng tasks without rollover; these are tasks when view is not today
    //                evenningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
    //            }
    //            currentTask = evenningTasks[indexPath.row]
    //
    //            let sortedEveningTask = evenningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
    //
    //            currentTask = sortedEveningTask[indexPath.row]
    //            print("Row evening: \(sortedEveningTask[indexPath.row].name)")
    //            print("Row evening index: \(indexPath.row)")
    //
    //        default:
    //            break
    //        }
    //
    //
    //        completedTaskCell.textLabel!.text = "\t\(currentTask.name)"
    //        completedTaskCell.backgroundColor = UIColor.clear
    //
    //        //        openTaskCell.textLabel!.text = currentTask.name
    //        openTaskCell.textLabel!.text = "\t\(currentTask.name)"
    //        openTaskCell.backgroundColor = UIColor.clear
    //
    //        //-----
    //        //        var mImage = UIImageView()
    //        //        mImage.frame = openTaskCell.frame
    //        //        mImage.backgroundColor = .black
    //        //        openTaskCell.addSubview(mImage)
    //
    //        //-----
    //
    //        if currentTask.isComplete {
    //            completedTaskCell.textLabel?.textColor = .tertiaryLabel
    //            //            completedTaskCell.accessoryType = .checkmark
    //
    //            let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: openTaskCell.bounds.minX+5, y: openTaskCell.bounds.minY+10, width: 20, height: 25))
    //            checkBox.lineWidth = 1.0
    //            checkBox.animationDuration = 0.40
    //            checkBox.setOn(true, animated: false)
    //            checkBox.boxType = .square
    //            checkBox.onAnimationType = .oneStroke
    //            checkBox.offAnimationType = .oneStroke
    //            checkBox.onTintColor = todoColors.primaryColor
    //
    //
    //
    //            completedTaskCell.addSubview(checkBox)
    //
    //            //          let priorityLineView = UIView(frame: CGRect(x: completedTaskCell.bounds.minX, y: completedTaskCell.bounds.minY, width: 5.0, height: completedTaskCell.bounds.height))
    //            //            priorityLineView.clipsToBounds = true
    //
    //            //            let priorityLineView_Right = UIView(frame: CGRect(x: completedTaskCell.bounds.maxX, y: completedTaskCell.bounds.minY, width: 5.0, height: completedTaskCell.bounds.height))
    //            //            priorityLineView_Right.clipsToBounds = true
    //
    //            //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
    //            if (currentTask.taskPriority == 1) { //p0
    //
    //                //                          priorityLineView.backgroundColor = .systemRed
    //                //                        priorityLineView_Right.backgroundColor = .systemRed
    //
    //            } else if (currentTask.taskPriority == 2) {
    //
    //                //                          priorityLineView.backgroundColor = .systemOrange
    //                //                        priorityLineView_Right.backgroundColor = .systemOrange
    //
    //            } else if (currentTask.taskPriority == 3) {
    //
    //                //                          priorityLineView.backgroundColor = .systemYellow
    //                //                        priorityLineView_Right.backgroundColor = .systemYellow
    //
    //            } else {
    //                //                          priorityLineView.backgroundColor = .systemGray3
    //                //                        priorityLineView_Right.backgroundColor = .systemGray3
    //            }
    //            //            completedTaskCell.addSubview(priorityLineView)
    //            //            completedTaskCell.addSubview(priorityLineView_Right)
    //
    //            return completedTaskCell
    //
    //        } else {
    //
    //
    //
    //            openTaskCell.textLabel?.textColor = .label
    //            //            openTaskCell.accessoryType = .detailButton
    //            openTaskCell.accessoryType = .disclosureIndicator
    //
    //
    //
    //            let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: openTaskCell.bounds.minX+5, y: openTaskCell.bounds.minY+10, width: 20, height: 25))
    //            checkBox.lineWidth = 1.0
    //            checkBox.animationDuration = 0.40
    //            checkBox.setOn(false, animated: false)
    //            checkBox.boxType = .square
    //            checkBox.onAnimationType = .oneStroke
    //            checkBox.offAnimationType = .oneStroke
    //            checkBox.onTintColor = todoColors.primaryColor
    //
    //            openTaskCell.addSubview(checkBox)
    //
    //
    //
    //
    //            let priorityLineView_Right = UIView() //UIView(frame: CGPoint(x: openTaskCell.bounds.maxX, y: openTaskCell.bounds.midY))//(frame: CGRect(x: openTaskCell.bounds.maxX, y: openTaskCell.bounds.minY, width: 5.0, height: openTaskCell.bounds.height))
    //
    //
    //            priorityLineView_Right.clipsToBounds = true
    //
    //            //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
    //            if (currentTask.taskPriority == 1) { //p0
    //
    //
    //                //                priorityLineView_Right.backgroundColor = .systemRed
    //
    //            } else if (currentTask.taskPriority == 2) {
    //
    //
    //                //                priorityLineView_Right.backgroundColor = .systemOrange
    //
    //            } else if (currentTask.taskPriority == 3) {
    //
    //
    //                //                priorityLineView_Right.backgroundColor = .systemYellow
    //
    //            } else {
    //
    //                //                priorityLineView_Right.backgroundColor = .systemGray3
    //            }
    //
    //
    //            //            openTaskCell.addSubview(priorityLineView_Right)
    //
    //            return openTaskCell
    //        }
    //    }
    //
    //    //mark:- move this END ---------
    //
    //    //----------------------- *************************** -----------------------
    //    //MARK:-                      TABLE SWIPE ACTIONS : Completed
    //    //----------------------- *************************** -----------------------
    //
    //    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    //
    //        let completeTaskAction = UIContextualAction(style: .normal, title: "Complete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
    //
    //            let morningTasks: [NTask]
    //            let eveningTasks: [NTask]
    //            let dateForTheView = self.dateForTheView
    //
    //            if(dateForTheView == Date.today()) {
    //                morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
    //            } else { //get morning tasks without rollover
    //                morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: self.dateForTheView)
    //            }
    //            let sortedMorningTask = morningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
    //
    //            if(dateForTheView == Date.today()) {
    //                eveningTasks = TaskManager.sharedInstance.getEveningTasksForToday()
    //            } else { //get evening tasks without rollover
    //                eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: self.dateForTheView)
    //            }
    //            let sortedEveningTask = eveningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
    //
    //            switch indexPath.section {
    //            case 0:
    //                TaskManager.sharedInstance
    //                    .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedMorningTask[indexPath.row])]
    //                    .isComplete = true
    //
    //                TaskManager.sharedInstance
    //                    .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedMorningTask[indexPath.row])]
    //                    .dateCompleted = Date.today() as NSDate
    //
    //                TaskManager.sharedInstance.saveContext()
    //
    //                print("Morning MARKINNG COMPLETE: \(TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedMorningTask[indexPath.row])].name)")
    //
    //                tableView.reloadData()
    //                self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    //
    //            case 1:
    //                TaskManager.sharedInstance
    //                    .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedEveningTask[indexPath.row])]
    //                    .isComplete = true
    //
    //                TaskManager.sharedInstance
    //                    .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedEveningTask[indexPath.row])]
    //                    .dateCompleted = Date.today() as NSDate
    //
    //                TaskManager.sharedInstance.saveContext()
    //
    //                print("Evening MARKINNG COMPLETE: \(TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedEveningTask[indexPath.row])].name)")
    //                tableView.reloadData()
    //                self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    //
    //            default:
    //                break
    //            }
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
    //
    //    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    //
    //
    //
    //        let morningTasks: [NTask]
    //        let eveningTasks: [NTask]
    //        let dateForTheView = self.dateForTheView
    //
    //        if(dateForTheView == Date.today()) {
    //            morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
    //        } else { //get morning tasks without rollover
    //            morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: self.dateForTheView)
    //        }
    //        let sortedMorningTask = morningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
    //
    //        if(dateForTheView == Date.today()) {
    //            eveningTasks = TaskManager.sharedInstance.getEveningTasksForToday()
    //        } else { //get evening tasks without rollover
    //            eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: self.dateForTheView)
    //        }
    //        let sortedEveningTask = eveningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
    //
    //        //                let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: self.dateForTheView)
    //
    //
    //        let deleteTaskAction = UIContextualAction(style: .destructive, title: "Delete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
    //
    //
    //
    //            var taskName: String = ""
    //            switch indexPath.section {
    //            case 0:
    //
    //                taskName = sortedMorningTask[indexPath.row].name
    //            case 1:
    //                taskName = sortedEveningTask[indexPath.row].name
    //            default:
    //                break
    //            }
    //
    //            let confirmDelete = UIAlertController(title: "Are you sure?", message: "\nThis will delete this task\n\n \(taskName)", preferredStyle: .alert)
    //            let yesDeleteAction = UIAlertAction(title: "Yes", style: .destructive)
    //            {
    //                (UIAlertAction) in
    //
    //
    //
    //                switch indexPath.section {
    //                case 0:
    //                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedMorningTask[indexPath.row]))
    //                case 1:
    //                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedEveningTask[indexPath.row]))
    //                default:
    //                    break
    //                }
    //
    //                //                tableView.reloadData()
    //                //                tableView.reloadData(
    //                //                    with: .simple(duration: 0.45, direction: .rotation3D(type: .captainMarvel),
    //                //                                  constantDelay: 0))
    //
    //                print("SCORE IS: \(self.calculateTodaysScore())")
    //                HUD.shared.showFailure(from: self, with: "Deleted")
    //
    //                self.scoreCounter.text = "\(self.calculateTodaysScore())"
    //                self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView);
    //                self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
    //
    //                tableView.reloadData()
    //                self.animateTableViewReload()
    //
    //                //                UIView.animate(views: tableView.visibleCells, animations: self.animations, completion: {
    //                //
    //                //                       })
    //
    //
    //            }
    //            let noDeleteAction = UIAlertAction(title: "No", style: .cancel)
    //            { (UIAlertAction) in
    //
    //                print("That was a close one. No deletion.")
    //            }
    //
    //            //add actions to alert controller
    //            confirmDelete.addAction(yesDeleteAction)
    //            confirmDelete.addAction(noDeleteAction)
    //
    //            //show it
    //            self.present(confirmDelete ,animated: true, completion: nil)
    //
    //            self.title = "\(self.calculateTodaysScore())"
    //            actionPerformed(true)
    //        }
    //
    //
    //        return UISwipeActionsConfiguration(actions: [deleteTaskAction])
    //    }
    //
    //    // MARK:- DID SELECT ROW AT
    //    /*
    //     Prints logs on selecting a row
    //     */
    //    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    //        print("You selected row \(indexPath.row) from section \(indexPath.section)")
    //        var currentTask: NTask!
    //        switch indexPath.section {
    //        case 0:
    //            let Tasks: [NTask]
    //            if(dateForTheView == Date.today()) {
    //                Tasks = TaskManager.sharedInstance.getMorningTasksForToday()
    //            } else { //get morning tasks without rollover
    //                Tasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
    //            }
    //            currentTask = Tasks[indexPath.row]
    //        case 1:
    //            let Tasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
    //            currentTask = Tasks[indexPath.row]
    //        default:
    //            break
    //        }
    //        semiViewDefaultOptions(viewToBePrsented: serveSemiViewBlue(task: currentTask))
    //
    //    }
    //
    //----------------------- *************************** -----------------------
    //MARK:- OLD TABLE VIEW : ENDS
    //
    //
    //----------------------- *************************** -----------------------
    
    
}

// MARK: - TableViewCellDemoController: UITableViewDataSource

extension HomeViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return ToDoListSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 0
        } else if section == 1 {
            let inboxTasks = TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(projectName: ProjectManager.sharedInstance.defaultProject, date: dateForTheView)
            return inboxTasks.count //TODO: Add completed tasks to this
        } else if section == 2 {
            let userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
            return userProjectTasks.count //TODO: Add completed tasks to this
        }
            
        else {
            return TableViewCellSampleData.numberOfItemsInSection
        }
        //        return TableViewCellSampleData.numberOfItemsInSection
        
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
    
    enum ViewType {
        case todayHomeView
        case customSateView
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
    func updateViewForHome(viewType: ViewType, dateForView: Date = Date.today(), projectForView: String = ProjectManager.sharedInstance.defaultProject) {
        
        //        var movement = ;
        //        if viewType == ViewType.todayHomeView {
        //
        //        }
        
        currentViewType = viewType
        print("woo ViewType is: \(currentViewType)")
        
        switch viewType {
        case .todayHomeView:
            print("woo ViewType: TODAY VIEW")
            
            let today = Date.today()
            setDateForViewValue(dateToSetForView: today)
            updateHomeDateLabel(date: today)
            
            //aimations
            reloadTinyPicChartWithAnimation()
            reloadToDoListWithAnimation()
            
            
        case .customSateView:
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //        let section = sections[indexPath.section]
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
        
        let inboxTasks = TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(projectName: ProjectManager.sharedInstance.defaultProject, date: dateForTheView)
        let userProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: dateForTheView)
        
        
        if indexPath.section == 1  { //inbox
            
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
            
            
            
            
            
            
        }
        else if indexPath.section == 2  { //projects
            
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
        else {
            
            
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
        
        
    }
    
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let completeTaskAction = UIContextualAction(style: .normal, title: "Complete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
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
            actionPerformed(true)
        }
        
        completeTaskAction.backgroundColor = todoColors.completeTaskSwipeColor
        
        //        NSUIColor(red: 192/255.0, green: 255/255.0, blue: 140/255.0, alpha: 1.0), green
        //                 NSUIColor(red: 255/255.0, green: 247/255.0, blue: 140/255.0, alpha: 1.0), yellow
        //                 NSUIColor(red: 255/255.0, green: 208/255.0, blue: 140/255.0, alpha: 1.0), orange
        //                 NSUIColor(red: 140/255.0, green: 234/255.0, blue: 255/255.0, alpha: 1.0), blue
        //                 NSUIColor(red: 255/255.0, green: 140/255.0, blue: 157/255.0, alpha: 1.0) red
        
        return UISwipeActionsConfiguration(actions: [completeTaskAction])
    }
    
    
    
}

// MARK: - TableViewCellDemoController: UITableViewDelegate

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            //            let headStack = HomeViewController.createTopHeaderVerticalContainer()
            
            let headerView = UIView()
            let myLabel = UILabel()
            //            myLabel.frame = CGRect(x:5, y: 0, width: (UIScreen.main.bounds.width/3) + 50, height: 30)
            myLabel.frame = CGRect(x:5, y: 4, width: (UIScreen.main.bounds.width), height: 30)
            
            //line.horizontal.3.decrease.circle
            let filterIconConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .thin, scale: .default)
            let filterIconImage = UIImage(systemName: "line.horizontal.3.decrease.circle", withConfiguration: filterIconConfiguration)
            let colouredCalPullDownImage = filterIconImage?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal)
            //
            //            let calButton = colouredCalPullDownImage //UIImage(named: "cal_Icon")
            let filterMenuHomeButton = UIButton()
            //            filterMenuHomeButton.frame = CGRect(x:5, y: -10 , width: 50, height: 50)
            //            filterMenuHomeButton.frame = CGRect(x:5, y: 1 , width: 30, height: 30)
            filterMenuHomeButton.frame = CGRect(x:5, y: 4 , width: 30, height: 30)
            filterMenuHomeButton.setImage(colouredCalPullDownImage, for: .normal)
            
            filterMenuHomeButton.addTarget(self, action:  #selector(showTopDrawerButtonTapped), for: .touchUpInside)
            //
            
            
            
            
            
            
            //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
            myLabel.font = setFont(fontSize: 24, fontweight: .medium, fontDesign: .rounded)//UIFont(name: "HelveticaNeue-Bold", size: 20)
            myLabel.textAlignment = .center
            myLabel.adjustsFontSizeToFitWidth = true
            myLabel.textColor = .label
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
            }
            myLabel.text = sectionLabel//tableView(tableView, gree: section)
            
            //                   let headerView = UIView()
            
            lineSeparator.frame = CGRect(x: 0, y: 40, width: UIScreen.main.bounds.width, height: 1)
            lineSeparator.backgroundColor = UIColor.black
            
            
            
            
            //                            headStack.addArrangedSubview(myLabel)
            //            headStack.addArrangedSubview(UIView())
            //                 headStack.addArrangedSubview(Separator())
            //            headStack.addArrangedSubview(UIView())
            
            //                            headStack.addArrangedSubview(lineSeparator)
            //            headStack.addArrangedSubview(UIView())
            
            headerView.addSubview(filterMenuHomeButton)
            headerView.addSubview(myLabel)
            
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
