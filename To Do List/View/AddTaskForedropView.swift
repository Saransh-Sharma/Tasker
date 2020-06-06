//
//  AddTaskForedropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 03/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import Timepiece
import MaterialComponents.MaterialTextControls_FilledTextAreas
import MaterialComponents.MaterialTextControls_FilledTextFields
import MaterialComponents.MaterialTextControls_OutlinedTextAreas
import MaterialComponents.MaterialTextControls_OutlinedTextFields


extension AddTaskViewController {
    
    func setupFordrop() {
        
        print("Backdrop starts from: \(headerEndY)") //this is key to the whole view; charts, cal, animations, all
        foredropContainer.frame = CGRect(x: 0, y: homeTopBar.frame.maxY*2.2, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        
        //        CGRect(x: 0, y: homeTopBar.frame.maxY-5, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        
        //CGRect(x: 0, y: homeTopBar.frame.maxY-5, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        setupBackdropForeground()
        //            setupTableView()
        foredropContainer.backgroundColor = .clear
        setupAddTaskTextField()
        setupEveningTaskSwitch()
        setupPrioritySC()
        setupDoneButton()
        //            foredropContainer.bringSubviewToFront(tableView)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 2: SETUP FOREGROUND
    //----------------------- *************************** -----------------------
    
    //MARK: Setup forground
    func setupBackdropForeground() {
        
        backdropForeImageView.frame =  CGRect(x: 0, y:0, width: UIScreen.main.bounds.width, height:  UIScreen.main.bounds.height)
        backdropForeImageView.image = backdropForeImage?.withRenderingMode(.alwaysTemplate)
        backdropForeImageView.tintColor = .systemGray6
        
        
        backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
        backdropForeImageView.layer.shadowOpacity = 0.8
        backdropForeImageView.layer.shadowOffset = CGSize(width: -5.0, height: -5.0) //.zero
        backdropForeImageView.layer.shadowRadius = 10
        
        //        view.addSubview(backdropForeImageView)
        foredropContainer.addSubview(backdropForeImageView)
        
    }
    
    // MARK: MAKE AddTask TextFeild
    func setupAddTaskTextField() {
        
        //        let mView = UIView()
        //        mView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/8)
        
        //        mView.backgroundColor = todoColors.backgroundColor
        //        view.center.y += UIScreen.main.bounds.height/6
        //--------MATERIAL TEXT FEILD
        let estimatedFrame = CGRect(x: 0, y: 14, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/8)//CGRect(x: circleMenuStartX+circleMenuRadius/2, y: 0, width: UIScreen.main.bounds.maxX-(10+70+circleMenuRadius/2), height: standardHeight/2)
        addTaskTextBox_Material = MDCFilledTextField(frame: estimatedFrame)
        addTaskTextBox_Material.label.text = "add task & tap done"
        addTaskTextBox_Material.leadingAssistiveLabel.text = "Always add actionable items"
        addTaskTextBox_Material.font = UIFont(name: "HelveticaNeue", size: 18)
        addTaskTextBox_Material.delegate = self
        addTaskTextBox_Material.clearButtonMode = .whileEditing
        let placeholderTextArray = ["meet Laura at 2 for coffee", "design prototype", "bring an ☂️",
                                    "schedule 1:1 with Shelly","grab 401k from mail box",
                                    "get car serviced", "wrap Eve's birthaday gift ", "renew Gym membership",
                                    "book flight tickets to Thailand", "fix the garage door",
                                    "order Cake", "review subscriptions", "get coffee"]
        addTaskTextBox_Material.placeholder = placeholderTextArray.randomElement()!
        addTaskTextBox_Material.sizeToFit()
        //        mView.addSubview(addTaskTextBox_Material)
        //        mView.addSubview(textFeild)
        //        mView.bringSubviewToFront(textFeild)
        foredropContainer.addSubview(addTaskTextBox_Material)
        //        return mView
    }
    
    func setupEveningTaskSwitch() {
        
        
        switchSetContainer.frame = CGRect(x: 0, y: addTaskTextBox_Material.frame.maxY+10, width: UIScreen.main.bounds.width, height: 50)
        switchSetContainer.backgroundColor = .clear
        switchBackground.frame = CGRect(x: 0, y: addTaskTextBox_Material.frame.maxY+10, width: UIScreen.main.bounds.width, height: switchSetContainer.frame.height)
        switchBackground.backgroundColor = .clear//todoColors.secondaryAccentColor
        foredropContainer.addSubview(switchSetContainer)
        foredropContainer.addSubview(switchBackground)
        
        eveningLabel.frame = CGRect(x: 10, y: addTaskTextBox_Material.frame.maxY+10, width: UIScreen.main.bounds.width/2, height: switchBackground.bounds.maxY)
        eveningLabel.text = "evening task"
        eveningLabel.adjustsFontSizeToFitWidth = true
        eveningLabel.font = eveningLabel.font.withSize(switchSetContainer.bounds.height/2)
        eveningLabel.textColor = UIColor.label
        foredropContainer.addSubview(eveningLabel)
        
        //         eveningSwitch.frame = CGRect(x: UIScreen.main.bounds.maxX-70, y:switchSetContainer.bounds.midY-((switchSetContainer.bounds.midY/2)+5), width: UIScreen.main.bounds.width/4, height: switchSetContainer.bounds.height-10)
        eveningSwitch.frame = CGRect(x: UIScreen.main.bounds.maxX-70, y:addTaskTextBox_Material.frame.maxY+18, width: UIScreen.main.bounds.width/4, height: switchSetContainer.frame.height-10)
        //         eveningSwitch.frame = CGRect(x: UIScreen.main.bounds.maxX-70, y:switchSetContainer.bounds.midY-((switchSetContainer.bounds.midY/2)+5), width: UIScreen.main.bounds.width/4, height: switchSetContainer.bounds.height-10)
        
        foredropContainer.addSubview(eveningSwitch)
        
        // Colors
        eveningSwitch.onTintColor = todoColors.primaryColor
        eveningSwitch.addTarget(self, action: #selector(NAddTaskScreen.isEveningSwitchOn(sender:)), for: .valueChanged)
        //         foredropContainer.addSubview(eveningSwitch)
        
        
        //         return mView
    }
    
    
    @objc func isEveningSwitchOn(sender:UISwitch!) -> Bool {
        if (sender.isOn == true){
            print("SWITCH: on")
            return true
        }
        else{
            print("SWITCH: off")
            return false
        }
    }
    
    
    // MARK: MAKE Priority SC
    func setupPrioritySC() {
        
        //        let mView = UIView()
        let p = ["None", "Low", "High", "Highest"]
        prioritySC = UISegmentedControl(items: p)
        
        //        mView.frame = CGRect(x: 0, y: switchSetContainer.frame.maxY, width: UIScreen.main.bounds.width, height: switchSetContainer.frame.height)
        
        //        mView.backgroundColor = todoColors.primaryColor
        prioritySC.frame = CGRect(x: 50, y: switchSetContainer.frame.maxY+18, width: UIScreen.main.bounds.width-100, height: switchSetContainer.frame.height) //mView.frame
        //Task Priority
        prioritySC.selectedSegmentIndex = 1
        prioritySC.backgroundColor = .white
        prioritySC.selectedSegmentTintColor =  todoColors.secondaryAccentColor
        prioritySC.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: UIControl.State.selected)
        
        prioritySC.addTarget(self, action: #selector(changeTaskPriority), for: .valueChanged)
        //        mView.addSubview(prioritySC)
        
        
        foredropContainer.addSubview(prioritySC)
        
        
        //        return mView
    }
    
    //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is none/p4; default is 3(p2)
    @objc
    func changeTaskPriority(sender: UISegmentedControl) -> Int {
        
        switch sender.selectedSegmentIndex {
        case 0:
            print("Priority is None - no priority 4")
            currentTaskPriority = 4
            return 4
        case 1:
            
            print("Priority is P2- low 3")
            currentTaskPriority = 3
            return 3
        case 2:
            print("Priority is P1- high 2")
            currentTaskPriority = 2
            return 2
        case 3:
            print("Priority is p0 - highest 1")
            currentTaskPriority = 1
            return 1
        default:
            print("Failed to get Task Priority")
            return 3
        }
    }
    
    func setupDoneButton() {
        // MARK:---FAB - DONE Task
        
        let doneButtonHeightWidth: CGFloat = 50
        //        let doneButtonY = 4*(standardHeight)+standardHeight/2-(doneButtonHeightWidth/2)
        let doneButtonY = prioritySC.frame.maxY+18
        print("Placing done button at: \(doneButtonY)")
        
        fab_doneTask.mode = .expanded
        fab_doneTask.setTitle("done", for: .normal)
        fab_doneTask.setTitle("nice !", for: .highlighted)
        fab_doneTask.titleLabel?.text = "Done"
        fab_doneTask.titleColor(for: .normal)
        fab_doneTask.frame = CGRect(x: UIScreen.main.bounds.maxX-2.5*doneButtonHeightWidth, y: doneButtonY, width: 2.5*doneButtonHeightWidth, height: doneButtonHeightWidth)
        let doneTaskIconNormalImage = UIImage(named: "material_done_White")
        fab_doneTask.setImage(doneTaskIconNormalImage, for: .normal)
        
        
        if (isEveningSwitchOn(sender: eveningSwitch)) {
            let doneTaskIconNormalImage = UIImage(named: "material_evening_White")
            fab_doneTask.setImage(doneTaskIconNormalImage, for: .highlighted)
        } else {
            let doneTaskIconNormalImage = UIImage(named: "material_day_White")
            fab_doneTask.setImage(doneTaskIconNormalImage, for: .highlighted)
        }
        
        fab_doneTask.backgroundColor = todoColors.secondaryAccentColor
        fab_doneTask.sizeToFit()
        foredropContainer.addSubview(fab_doneTask)
        fab_doneTask.addTarget(self, action: #selector(doneAddTaskAction), for: .touchUpInside)
    }
    
    //MARK:- DONE TASK ACTION
    
    @objc func doneAddTaskAction() {
        
        //       tap DONE --> add new task + nav homeScreen
        //MARK:- ADD TASK ACTION
        isThisEveningTask = isEveningSwitchOn(sender: eveningSwitch)
        var taskDueDate = Date()
        print("task: User tapped done button at add task")
        if currentTaskInMaterialTextBox != "" {
            
            print("Adding task: \(currentTaskInMaterialTextBox)")
            //            TaskManager.sharedInstance.addNewTask(name: currentTaskInMaterialTextBox, taskType: getTaskType(), taskPriority: 2)
            
            //            let title = segm.titleForSegment(at: segment.selectedSegmentIndex)
            
            print("Priority is: \(currentTaskPriority)")
            
            //--//onnly adds task ttoday fix this
            
            taskDueDate = Date.today()
            TaskManager.sharedInstance.addNewTask_Today(name: currentTaskInMaterialTextBox, taskType: getTaskType(), taskPriority: currentTaskPriority, isEveningTask: isThisEveningTask)
            
            //---
        } else {
            print("task: nothing to add - doone ")
        }
        
        
        //              if(taskDayFromPicker == "Unknown" || taskDayFromPicker == "") {
        //                  taskDueDate = Date.today()
        //                  TaskManager.sharedInstance.addNewTask_Today(name: currentTaskInMaterialTextBox, taskType: getTaskType(), taskPriority: currentTaskPriority, isEveningTask: isThisEveningTask)
        //              } else if (taskDayFromPicker == "Tomorrow") { //["Set Date", "Today", "Tomorrow", "Weekend", "Next Week"]
        //                  taskDueDate = Date.tomorrow()
        //                  TaskManager.sharedInstance.addNewTask_Future(name: currentTaskInMaterialTextBox, taskType: getTaskType(), taskPriority: currentTaskPriority, futureTaskDate: taskDueDate, isEveningTask: isThisEveningTask)
        //              } else if (taskDayFromPicker == "Weekend") {
        //
        //                  //get the next weekend
        //                  taskDueDate = Date.today().changed(weekday: 5)!
        //
        //
        //                  TaskManager.sharedInstance.addNewTask_Future(name: currentTaskInMaterialTextBox, taskType: getTaskType(), taskPriority: currentTaskPriority, futureTaskDate: taskDueDate, isEveningTask: isThisEveningTask)
        //
        //
        //
        //              } else if (taskDayFromPicker == "Today") {
        //                  taskDueDate = Date.today()
        //                  TaskManager.sharedInstance.addNewTask_Today(name: currentTaskInMaterialTextBox, taskType: getTaskType(), taskPriority: currentTaskPriority, isEveningTask: isThisEveningTask)
        //              }
        //
        //                          else {
        //                              print("EMPTY TASK ! - Nothing to add")
        //
        //                          }
        
        //          }
        
        //add generic task add here which takes all input
        //        TaskManager.sharedInstance.addNewTask_Today(name: currentTaskInMaterialTextBox, taskType: getTaskType(), taskPriority: 2, isEveningTask: isThisEveningTask)
        
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "homeScreen") as! HomeViewController
        newViewController.modalPresentationStyle = .fullScreen
        self.present(newViewController, animated: true, completion: nil)
    }
    
    //MARK:- CANCEL TASK ACTION
    @objc func cancelAddTaskAction() {
        
        //       tap CANCEL --> homeScreen
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "homeScreen") as! HomeViewController
        newViewController.modalPresentationStyle = .fullScreen
        //        self.present(newViewController, animated: true, completion: nil) //Doesn't look like cancel
        dismiss(animated: true) //this looks more like cancel compared to above
    }
    
    func getTaskType() -> Int { //extend this to return for inbox & upcoming/someday
        if eveningSwitch.isOn {
            print("Adding eveninng task")
            return 2
        }
            //        else if isInboxTask {
            //
            //        }
            //        else if isUpcomingTask {
            //
            //        }
        else {
            //this is morning task
            print("adding mornig task")
            return 1
        }
    }
    
}
