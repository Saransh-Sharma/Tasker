//
//  TaskListTableViewExtention.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import Timepiece
import BEMCheckBox

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    
    
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        let lineSeparator = UIView()
        
        if section == 0 {
            let myLabel = UILabel()
//            myLabel.frame = CGRect(x:5, y: 0, width: (UIScreen.main.bounds.width/3) + 50, height: 30)
            myLabel.frame = CGRect(x:5, y: 8, width: (UIScreen.main.bounds.width), height: 30)
            
            //line.horizontal.3.decrease.circle
            let filterIconConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .thin, scale: .default)
            let filterIconImage = UIImage(systemName: "line.horizontal.3.decrease.circle", withConfiguration: filterIconConfiguration)
            let colouredCalPullDownImage = filterIconImage?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal)
            //
            //            let calButton = colouredCalPullDownImage //UIImage(named: "cal_Icon")
            let filterMenuHomeButton = UIButton()
            //            filterMenuHomeButton.frame = CGRect(x:5, y: -10 , width: 50, height: 50)
//            filterMenuHomeButton.frame = CGRect(x:5, y: 1 , width: 30, height: 30)
             filterMenuHomeButton.frame = CGRect(x:5, y: 8 , width: 30, height: 30)
            filterMenuHomeButton.setImage(colouredCalPullDownImage, for: .normal)
            
            headerView.addSubview(filterMenuHomeButton)
            
            
            
            
            //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
            myLabel.font = setFont(fontSize: 24, fontweight: .medium, fontDesign: .rounded)//UIFont(name: "HelveticaNeue-Bold", size: 20)
            myLabel.textAlignment = .center
            myLabel.adjustsFontSizeToFitWidth = true
            myLabel.textColor = .label
            myLabel.text = self.tableView(tableView, titleForHeaderInSection: section)
            
            //                   let headerView = UIView()
            
            lineSeparator.frame = CGRect(x: 0, y: 45, width: UIScreen.main.bounds.width, height: 1)
            lineSeparator.backgroundColor = UIColor.black
            
            headerView.addSubview(lineSeparator)
            headerView.addSubview(myLabel)
            
            return headerView
        } else if section == 1 {
            
            let myLabel2 = UILabel()
            myLabel2.frame = CGRect(x:5, y: 0, width: UIScreen.main.bounds.width/3, height: 30)
            //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
            myLabel2.font = setFont(fontSize: 20, fontweight: .medium, fontDesign: .rounded)//UIFont(name: "HelveticaNeue-Bold", size: 20)
            myLabel2.textAlignment = .left
            myLabel2.adjustsFontSizeToFitWidth = true
            myLabel2.textColor = .secondaryLabel
            myLabel2.text = self.tableView(tableView, titleForHeaderInSection: section)
            
            headerView.addSubview(myLabel2)
            
            
        }
        
        
        //        let myLabel = UILabel()
        //        myLabel.frame = CGRect(x:5, y: 0, width: UIScreen.main.bounds.width/3, height: 30)
        //        //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
        //        myLabel.font = setFont(fontSize: 24, fontweight: .medium, fontDesign: .serif)//UIFont(name: "HelveticaNeue-Bold", size: 20)
        //        myLabel.textAlignment = .right
        //        myLabel.adjustsFontSizeToFitWidth = true
        //        myLabel.textColor = .secondaryLabel
        //        myLabel.text = self.tableView(tableView, titleForHeaderInSection: section)
        //
        //        let headerView = UIView()
        //        headerView.addSubview(myLabel)
        //
        //        return headerView
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            let now = Date.today
            if (dateForTheView == now()) {
                return "Today"
            } else if (dateForTheView == Date.tomorrow()){
                return "Tomorrow"
            } else if (dateForTheView == Date.yesterday()) {
                return "Yeserday"
                }
            else {
                return "Tasks \(dateForTheView.stringIn(dateStyle: .full, timeStyle: .none))"
            }
            
        //            return "Today's Tasks"
        case 1:
            return "Evening"
        default:
            return nil
        }
    }
    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0:
            let morningTasks: [NTask]
            if(dateForTheView == Date.today()) { //morning tasks today: rollover unfinished tasks + tasks added today + tasks completed today
                morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
                
            } else { //get morning tasks without rollover
                morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
            }
            print("Morning ROW COUNT:  \(morningTasks.count)")
            return morningTasks.count
        case 1:
            //            print("Items in evening: \(TaskManager.sharedInstance.getEveningTasks.count)")
            //            return TaskManager.sharedInstance.getEveningTasks.count
            //                let eveTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            let eveTasks: [NTask]
            if(dateForTheView == Date.today()) {
                eveTasks = TaskManager.sharedInstance.getEveningTasksForToday()
                
                
            } else { //get morning tasks without rollover
                eveTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            }
            print("Evening ROW COUNT:  \(eveTasks.count)")
            
            return eveTasks.count
        default:
            return 0;
        }
    }
    
    // MARK:- CELL AT ROWUITableViewRowAction
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var currentTask: NTask!
        let completedTaskCell = tableView.dequeueReusableCell(withIdentifier: "completedTaskCell", for: indexPath)
        let openTaskCell = tableView.dequeueReusableCell(withIdentifier: "openTaskCell", for: indexPath)
        
        switch indexPath.section {
        case 0:
            print("morning section index is: \(indexPath.row)")
            
            //getMorningTasksForToday
            let morningTasks: [NTask]
            if(dateForTheView == Date.today()) {
                morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
            } else { //get morning tasks without rollover; these are tasks when view is not today
                morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
            }
            //                currentTask = morningTasks[indexPath.row]
            
            let sortedMorningTask = morningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
            currentTask = sortedMorningTask[indexPath.row]
            
            
        case 1:
            print("evening section index is: \(indexPath.row)")
            
            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
            
            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
            
            //                let evenningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            let evenningTasks: [NTask]
            if(dateForTheView == Date.today()) {
                evenningTasks = TaskManager.sharedInstance.getEveningTasksForToday()
            } else { //get eveninng tasks without rollover; these are tasks when view is not today
                evenningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            }
            currentTask = evenningTasks[indexPath.row]
            
            let sortedEveningTask = evenningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
            
            currentTask = sortedEveningTask[indexPath.row]
            print("Row evening: \(sortedEveningTask[indexPath.row].name)")
            print("Row evening index: \(indexPath.row)")
            
        default:
            break
        }
        
        
        completedTaskCell.textLabel!.text = "\t\(currentTask.name)"
        completedTaskCell.backgroundColor = UIColor.clear
        
        //        openTaskCell.textLabel!.text = currentTask.name
        openTaskCell.textLabel!.text = "\t\(currentTask.name)"
        openTaskCell.backgroundColor = UIColor.clear
        
        if currentTask.isComplete {
            completedTaskCell.textLabel?.textColor = .tertiaryLabel
            //            completedTaskCell.accessoryType = .checkmark
            
            let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: openTaskCell.bounds.minX+5, y: openTaskCell.bounds.minY+10, width: 20, height: 25))
            checkBox.lineWidth = 1.0
            checkBox.animationDuration = 0.40
            checkBox.setOn(true, animated: false)
            checkBox.boxType = .square
            checkBox.onAnimationType = .oneStroke
            checkBox.offAnimationType = .oneStroke
            checkBox.onTintColor = todoColors.primaryColor
            
            
            
            completedTaskCell.addSubview(checkBox)
            
            //          let priorityLineView = UIView(frame: CGRect(x: completedTaskCell.bounds.minX, y: completedTaskCell.bounds.minY, width: 5.0, height: completedTaskCell.bounds.height))
            //            priorityLineView.clipsToBounds = true
            
            //            let priorityLineView_Right = UIView(frame: CGRect(x: completedTaskCell.bounds.maxX, y: completedTaskCell.bounds.minY, width: 5.0, height: completedTaskCell.bounds.height))
            //            priorityLineView_Right.clipsToBounds = true
            
            //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
            if (currentTask.taskPriority == 1) { //p0
                
                //                          priorityLineView.backgroundColor = .systemRed
                //                        priorityLineView_Right.backgroundColor = .systemRed
                
            } else if (currentTask.taskPriority == 2) {
                
                //                          priorityLineView.backgroundColor = .systemOrange
                //                        priorityLineView_Right.backgroundColor = .systemOrange
                
            } else if (currentTask.taskPriority == 3) {
                
                //                          priorityLineView.backgroundColor = .systemYellow
                //                        priorityLineView_Right.backgroundColor = .systemYellow
                
            } else {
                //                          priorityLineView.backgroundColor = .systemGray3
                //                        priorityLineView_Right.backgroundColor = .systemGray3
            }
            //            completedTaskCell.addSubview(priorityLineView)
            //            completedTaskCell.addSubview(priorityLineView_Right)
            
            return completedTaskCell
            
        } else {
            
            
            
            openTaskCell.textLabel?.textColor = .label
            //            openTaskCell.accessoryType = .detailButton
            openTaskCell.accessoryType = .disclosureIndicator
            
            
            
            let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: openTaskCell.bounds.minX+5, y: openTaskCell.bounds.minY+10, width: 20, height: 25))
            checkBox.lineWidth = 1.0
            checkBox.animationDuration = 0.40
            checkBox.setOn(false, animated: false)
            checkBox.boxType = .square
            checkBox.onAnimationType = .oneStroke
            checkBox.offAnimationType = .oneStroke
            checkBox.onTintColor = todoColors.primaryColor
            
            openTaskCell.addSubview(checkBox)
            
            
            
            
            let priorityLineView_Right = UIView() //UIView(frame: CGPoint(x: openTaskCell.bounds.maxX, y: openTaskCell.bounds.midY))//(frame: CGRect(x: openTaskCell.bounds.maxX, y: openTaskCell.bounds.minY, width: 5.0, height: openTaskCell.bounds.height))
            
            
            priorityLineView_Right.clipsToBounds = true
            
            //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
            if (currentTask.taskPriority == 1) { //p0
                
                
                //                priorityLineView_Right.backgroundColor = .systemRed
                
            } else if (currentTask.taskPriority == 2) {
                
                
                //                priorityLineView_Right.backgroundColor = .systemOrange
                
            } else if (currentTask.taskPriority == 3) {
                
                
                //                priorityLineView_Right.backgroundColor = .systemYellow
                
            } else {
                
                //                priorityLineView_Right.backgroundColor = .systemGray3
            }
            
            
            //            openTaskCell.addSubview(priorityLineView_Right)
            
            return openTaskCell
        }
    }
    
    //mark:- move this END ---------
    
    //----------------------- *************************** -----------------------
    //MARK:-                      TABLE SWIPE ACTIONS : Completed
    //----------------------- *************************** -----------------------
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let completeTaskAction = UIContextualAction(style: .normal, title: "Complete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
                    
            let morningTasks: [NTask]
            let eveningTasks: [NTask]
            let dateForTheView = self.dateForTheView
            
            if(dateForTheView == Date.today()) {
                morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
            } else { //get morning tasks without rollover
                morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: self.dateForTheView)
            }
            let sortedMorningTask = morningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
                                    
            if(dateForTheView == Date.today()) {
                eveningTasks = TaskManager.sharedInstance.getEveningTasksForToday()
            } else { //get evening tasks without rollover
                eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: self.dateForTheView)
            }
            let sortedEveningTask = eveningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
                        
            switch indexPath.section {
            case 0:
                TaskManager.sharedInstance
                    .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedMorningTask[indexPath.row])]
                    .isComplete = true
                
                TaskManager.sharedInstance
                    .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedMorningTask[indexPath.row])]
                    .dateCompleted = Date.today() as NSDate
                
                TaskManager.sharedInstance.saveContext()
                
                print("Morning MARKINNG COMPLETE: \(TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedMorningTask[indexPath.row])].name)")
                
                tableView.reloadData()
                self.animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
            
            case 1:
                TaskManager.sharedInstance
                    .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedEveningTask[indexPath.row])]
                    .isComplete = true
                
                TaskManager.sharedInstance
                    .getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedEveningTask[indexPath.row])]
                    .dateCompleted = Date.today() as NSDate
                
                TaskManager.sharedInstance.saveContext()
                
                print("Evening MARKINNG COMPLETE: \(TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedEveningTask[indexPath.row])].name)")
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
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        
        
        let morningTasks: [NTask]
                let eveningTasks: [NTask]
                let dateForTheView = self.dateForTheView
                
                if(dateForTheView == Date.today()) {
                    morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
                } else { //get morning tasks without rollover
                    morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: self.dateForTheView)
                }
                let sortedMorningTask = morningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
                                        
                if(dateForTheView == Date.today()) {
                    eveningTasks = TaskManager.sharedInstance.getEveningTasksForToday()
                } else { //get evening tasks without rollover
                    eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: self.dateForTheView)
                }
                let sortedEveningTask = eveningTasks.sorted(by: { !$0.isComplete && $1.isComplete })
        
        //                let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: self.dateForTheView)
           
        
        let deleteTaskAction = UIContextualAction(style: .destructive, title: "Delete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
        
            
            var taskName: String = ""
            switch indexPath.section {
                         case 0:
                             
                            taskName = sortedMorningTask[indexPath.row].name
                         case 1:
                          taskName = sortedEveningTask[indexPath.row].name
                         default:
                             break
                         }
            
                let confirmDelete = UIAlertController(title: "Are you sure?", message: "\nThis will delete this task\n\n \(taskName)", preferredStyle: .alert)
            let yesDeleteAction = UIAlertAction(title: "Yes", style: .destructive)
            {
                (UIAlertAction) in
                
            
                
                switch indexPath.section {
                case 0:
                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedMorningTask[indexPath.row]))
                case 1:
                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: sortedEveningTask[indexPath.row]))
                default:
                    break
                }
                
                //                tableView.reloadData()
                //                tableView.reloadData(
                //                    with: .simple(duration: 0.45, direction: .rotation3D(type: .captainMarvel),
                //                                  constantDelay: 0))
                
                print("SCORE IS: \(self.calculateTodaysScore())")
                   self.scoreCounter.text = "\(self.calculateTodaysScore())"
                   self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(pieChartView: self.tinyPieChartView);
                   self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
                
                tableView.reloadData()
                self.animateTableViewReload()
                
                //                UIView.animate(views: tableView.visibleCells, animations: self.animations, completion: {
                //
                //                       })
                
                
            }
            let noDeleteAction = UIAlertAction(title: "No", style: .cancel)
            { (UIAlertAction) in
                
                print("That was a close one. No deletion.")
            }
            
            //add actions to alert controller
            confirmDelete.addAction(yesDeleteAction)
            confirmDelete.addAction(noDeleteAction)
            
            //show it
            self.present(confirmDelete ,animated: true, completion: nil)
            
            self.title = "\(self.calculateTodaysScore())"
            actionPerformed(true)
        }
        
        
        return UISwipeActionsConfiguration(actions: [deleteTaskAction])
    }
    
    // MARK:- DID SELECT ROW AT
    /*
     Prints logs on selecting a row
     */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You selected row \(indexPath.row) from section \(indexPath.section)")
        
        var currentTask: NTask!
        //        semiViewDefaultOptions(viewToBePrsented: serveViewBlue())
        switch indexPath.section {
        case 0:
            //            currentTask = TaskManager.sharedInstance.getMorningTasks[indexPath.row]
            //            let Tasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
            
            let Tasks: [NTask]
            if(dateForTheView == Date.today()) {
                Tasks = TaskManager.sharedInstance.getMorningTasksForToday()
            } else { //get morning tasks without rollover
                Tasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
            }
            
            
            currentTask = Tasks[indexPath.row]
        case 1:
            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
            let Tasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            currentTask = Tasks[indexPath.row]
        default:
            break
        }
        
        //        semiViewDefaultOptions(viewToBePrsented: serveSemiViewRed())
        
        semiViewDefaultOptions(viewToBePrsented: serveSemiViewBlue(task: currentTask))
        
        //        semiViewDefaultOptions(viewToBePrsented: serveSemiViewGreen(task: currentTask))
        
        
        
    }
    
}
