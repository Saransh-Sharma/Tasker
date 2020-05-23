//
//  TaskListTableViewExtention.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import BEMCheckBox

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    
           //mark:- move this ---------
        
        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            let headerView = UIView()
            
            if section == 0 {
                let myLabel = UILabel()
                myLabel.frame = CGRect(x:5, y: 0, width: (UIScreen.main.bounds.width/3) + 50, height: 30)
                
                //line.horizontal.3.decrease.circle
                let filterIconConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .thin, scale: .default)
                let filterIconImage = UIImage(systemName: "line.horizontal.3.decrease.circle", withConfiguration: filterIconConfiguration)
                let colouredCalPullDownImage = filterIconImage?.withTintColor(secondaryAccentColor, renderingMode: .alwaysOriginal)
                //
                //            let calButton = colouredCalPullDownImage //UIImage(named: "cal_Icon")
                let filterMenuHomeButton = UIButton()
                //            filterMenuHomeButton.frame = CGRect(x:5, y: -10 , width: 50, height: 50)
                filterMenuHomeButton.frame = CGRect(x:5, y: 1 , width: 30, height: 30)
                filterMenuHomeButton.setImage(colouredCalPullDownImage, for: .normal)
                
                headerView.addSubview(filterMenuHomeButton)
                
                
                
                
                //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
                myLabel.font = setFont(fontSize: 24, fontweight: .medium, fontDesign: .rounded)//UIFont(name: "HelveticaNeue-Bold", size: 20)
                myLabel.textAlignment = .right
                myLabel.adjustsFontSizeToFitWidth = true
                myLabel.textColor = .label
                myLabel.text = self.tableView(tableView, titleForHeaderInSection: section)
                
                //                   let headerView = UIView()
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
                    return "Today's Tasks"
                } else {
                    return "NOT TODAY"
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
                //            print("Items in morning: \(TaskManager.sharedInstance.getMorningTasks.count)")
                //            return TaskManager.sharedInstance.getMorningTasks.count
                
    //            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
                let morningTasks: [NTask]
                           if(dateForTheView == Date.today()) {
                                morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
                           } else { //get morning tasks without rollover
                                morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
                           }
                
                return morningTasks.count
            case 1:
                //            print("Items in evening: \(TaskManager.sharedInstance.getEveningTasks.count)")
                //            return TaskManager.sharedInstance.getEveningTasks.count
                let eveTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
                return eveTasks.count
            default:
                return 0;
            }
        }
        
        // MARK:- CELL AT ROW
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            
            
            
            //        chec
            
            
            var currentTask: NTask!
            let completedTaskCell = tableView.dequeueReusableCell(withIdentifier: "completedTaskCell", for: indexPath)
            let openTaskCell = tableView.dequeueReusableCell(withIdentifier: "openTaskCell", for: indexPath)
            
            //        print("NTASK count is: \(TaskManager.sharedInstance.count)")
            //        print("morning section index is: \(indexPath.row)")
            
            switch indexPath.section {
            case 0:
                print("morning section index is: \(indexPath.row)")
                
                //            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: Date.today())
                //            currentTask = TaskManager.sharedInstance.getMorningTasks[indexPath.row]
                
    //            getMorningTasksForToday
                let morningTasks: [NTask]
                if(dateForTheView == Date.today()) {
                     morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
                } else { //get morning tasks without rollover
                     morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
                }
                
                currentTask = morningTasks[indexPath.row]
                
            case 1:
                print("evening section index is: \(indexPath.row)")
                
                //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
                
                //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
                
                let evenningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
                currentTask = evenningTasks[indexPath.row]
                
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
                checkBox.animationDuration = 0.45
                checkBox.setOn(true, animated: false)
                checkBox.boxType = .square
                checkBox.onAnimationType = .oneStroke
                checkBox.offAnimationType = .oneStroke
                
                
                
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
                checkBox.animationDuration = 0.45
                checkBox.setOn(false, animated: false)
                checkBox.boxType = .square
                checkBox.onAnimationType = .oneStroke
                checkBox.offAnimationType = .oneStroke
                
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
}
