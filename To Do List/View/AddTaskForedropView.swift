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
import FluentUI
import Firebase
import MaterialComponents.MaterialTextControls_FilledTextAreas
import MaterialComponents.MaterialTextControls_FilledTextFields
import MaterialComponents.MaterialTextControls_OutlinedTextAreas
import MaterialComponents.MaterialTextControls_OutlinedTextFields


extension AddTaskViewController {
    
    
    
    func setupAddTaskForedrop() {
        
        print("Backdrop starts from: \(headerEndY)") //this is key to the whole view; charts, cal,
        foredropStackContainer.frame = CGRect(x: 0, y: homeTopBar.frame.maxY*2.2, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        
        
        setupBackdropForeground()
        //        foredropStackContainer.backgroundColor = .black
        
        setupAddTaskTextField()
        foredropStackContainer.addArrangedSubview(UIView())
        
        setupProjectsPillBar()
        foredropStackContainer.addArrangedSubview(UIView())
        
        setupPrioritySC()
        foredropStackContainer.addArrangedSubview(UIView())
        
        //        setupDoneButton()
        foredropStackContainer.addArrangedSubview(UIView())
        
        
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
        
        foredropStackContainer.addSubview(backdropForeImageView)
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    Setup Projects Pill Bar
    //----------------------- *************************** -----------------------
    
    func setupProjectsPillBar() {
        
        print("do9 - SETUP PROJECTS pillbar")
        buildProojectsPillBarData()
        
        //        let filledBar = createProjectsBar(items: pillBarProjectList, style: .outline)
        filledBar = createProjectsBar(items: pillBarProjectList, style: .outline)
        filledBar!.frame = CGRect(x: 0, y: 300, width: UIScreen.main.bounds.width, height: 65)
        //        self.filledBar = filledBar
        foredropStackContainer.addArrangedSubview(filledBar!)
        filledBar!.backgroundColor = .clear
        filledBar!.isHidden = true
        
        
        //        filledBar.selected
        //        filledBar.addTarget(self, action: #selector(changeProject))
        
    }
    
    func buildProojectsPillBarData() {
        
        let allProjects = ProjectManager.sharedInstance.getAllProjects
        pillBarProjectList = []
        pillBarProjectList = [PillButtonBarItem(title: "Add Project")]
        
        for each in allProjects {
            print("do9 --> FOUND PROJECT --> \(each.projectName!)")
            pillBarProjectList.append(PillButtonBarItem(title: "\(each.projectName! as String)"))
        }
        
        if pillBarProjectList[1].title.lowercased() != "inbox" {
            print("do9 - ADDING inbox !")
            pillBarProjectList.insert(PillButtonBarItem(title: "Inbox"), at: 1)
        }
        
        for (index, value) in pillBarProjectList.enumerated() {
            print("do9 --- AT INDEX \(index) value is \(value.title)")
        }
    }
    
    
    func createProjectsBar(items: [PillButtonBarItem], style: PillButtonStyle = .outline, centerAligned: Bool = false) -> UIView {
        let bar = PillButtonBar(pillButtonStyle: style)
        bar.items = items
        _ = bar.selectItem(atIndex: 1)
        bar.barDelegate = self
        bar.centerAligned = centerAligned
        
        let backgroundView = UIView()
        if style == .outline {
            backgroundView.backgroundColor = .clear//Colors.Navigation.System.background
        }
        backgroundView.addSubview(bar)
        let margins = UIEdgeInsets(top: 16.0, left: 0, bottom: 16.0, right: 0.0)
        fitViewIntoSuperview(bar, margins: margins)
        return backgroundView
    }
    
    func fitViewIntoSuperview(_ view: UIView, margins: UIEdgeInsets) {
        guard let superview = view.superview else {
            return
        }
        
        view.translatesAutoresizingMaskIntoConstraints = false
        let constraints = [view.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: margins.left),
                           view.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -margins.right),
                           view.topAnchor.constraint(equalTo: superview.topAnchor, constant: margins.top),
                           view.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -margins.bottom)]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    // MARK: MAKE AddTask TextFeild
    func setupAddTaskTextField() {
        
        let estimatedFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
        addTaskTextBox_Material = MDCFilledTextField(frame: estimatedFrame)
        //        addTaskTextBox_Material.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
        addTaskTextBox_Material.label.text = "add task & tap done"
        addTaskTextBox_Material.leadingAssistiveLabel.text = "add actionable items"
        //        addTaskTextBox_Material.font = UIFont(name: "HelveticaNeue", size: 18)
        
        addTaskTextBox_Material.sizeToFit()
        
        addTaskTextBox_Material.delegate = self
        addTaskTextBox_Material.clearButtonMode = .whileEditing
        let placeholderTextArray = ["meet Laura at 2 for coffee", "design prototype", "bring an ☂️",
                                    "schedule 1:1 with Shelly","grab 401k from mail box",
                                    "get car serviced", "wrap Eve's birthaday gift ", "renew Gym membership",
                                    "book flight tickets to Thailand", "fix the garage door",
                                    "order Cake", "review subscriptions", "get coffee"]
        addTaskTextBox_Material.placeholder = placeholderTextArray.randomElement()!
        //        addTaskTextBox_Material.sizeToFit()
        
        addTaskTextBox_Material.backgroundColor = .clear
        
        
        foredropStackContainer.addArrangedSubview(addTaskTextBox_Material)
        
        
    }
    
    func setupEveningTaskSwitch() {
        
        
        switchSetContainer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
        switchSetContainer.backgroundColor = .clear
        switchBackground.frame = CGRect(x: 0, y: addTaskTextBox_Material.frame.maxY+10, width: UIScreen.main.bounds.width, height: switchSetContainer.frame.height)
        switchBackground.backgroundColor = .clear//todoColors.secondaryAccentColor
        foredropContainer.addSubview(switchSetContainer)
        foredropContainer.addSubview(switchBackground)
        
        eveningLabel.frame = CGRect(x: 10, y: 0, width: UIScreen.main.bounds.width/2, height: switchBackground.bounds.maxY)
        eveningLabel.text = "evening task"
        eveningLabel.adjustsFontSizeToFitWidth = true
        eveningLabel.font = eveningLabel.font.withSize(switchSetContainer.bounds.height/2)
        eveningLabel.textColor = UIColor.label
        foredropContainer.addSubview(eveningLabel)
        
        
        eveningSwitch.frame = CGRect(x: UIScreen.main.bounds.maxX-70, y:18, width: UIScreen.main.bounds.width/4, height: switchSetContainer.frame.height-10)
        
        // Colors
        eveningSwitch.onTintColor = todoColors.primaryColor
        eveningSwitch.addTarget(self, action: #selector(NAddTaskScreen.isEveningSwitchOn(sender:)), for: .valueChanged)
        
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
        
        tabsSegmentedControl = SegmentedControl(items: p)
        
        
        
        
        tabsSegmentedControl.frame = CGRect(x: 50, y: 50, width: UIScreen.main.bounds.width-100, height: 50)
        tabsSegmentedControl.selectedSegmentIndex = 1
        
        tabsSegmentedControl.addTarget(self, action: #selector(changeTaskPriority), for: .valueChanged)
        
        tabsSegmentedControl.isHidden = true
        
        foredropStackContainer.addArrangedSubview(tabsSegmentedControl)
        
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
        //        foredropContainer.addSubview(fab_doneTask)
        //        fab_doneTask.contentHorizontalAlignment = .trailing
        fab_doneTask.titleLabel?.textAlignment = .center
        
        fab_doneTask.isHidden = true
        
        foredropStackContainer.addArrangedSubview(fab_doneTask)
        fab_doneTask.addTarget(self, action: #selector(doneAddTaskAction), for: .touchUpInside)
        
    }
    
    //MARK:- DONE TASK ACTION
    
    @objc func doneAddTaskAction() {
        
        //       tap DONE --> add new task + nav homeScreen
        //MARK:- ADD TASK ACTION
        isThisEveningTask = isEveningSwitchOn(sender: eveningSwitch)
        //        var taskDueDate = Date()
        print("task: User tapped done button at add task")
        if currentTaskInMaterialTextBox != "" {
            
            print("Adding task: \(currentTaskInMaterialTextBox)")
            print("Priority is: \(currentTaskPriority)")
            print("Add ask projet is: \(currenttProjectForAddTaskView)")
            
            print("Addig task for date: \(dateForAddTaskView.stringIn(dateStyle: .full, timeStyle: .none))")
            
            TaskManager.sharedInstance.addNewTask_Future(name: currentTaskInMaterialTextBox, taskType: getTaskType(), taskPriority: currentTaskPriority, futureTaskDate: dateForAddTaskView, isEveningTask: isThisEveningTask, project: currenttProjectForAddTaskView)
            
            HUD.shared.showSuccess(from: self, with: "Added to\n\(currenttProjectForAddTaskView)")
            
            let addTaskEvent = "Add_NEW_Task"
            Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
                AnalyticsParameterItemID: "id-\(addTaskEvent)",
                AnalyticsParameterItemName: addTaskEvent,
                AnalyticsParameterContentType: "cont"
            ])
            
        } else {
            HUD.shared.showFailure(from: self, with: "Nothing Added")
        }
        
        
        
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // your code here
            
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let newViewController = storyBoard.instantiateViewController(withIdentifier: "homeScreen") as! HomeViewController
            newViewController.modalPresentationStyle = .fullScreen
            //        self.present(newViewController, animated: true, completion: nil)
            self.present(newViewController, animated: true, completion: { () in
                print("SUCCESS !!!")
                //                HUD.shared.showSuccess(from: self, with: "Success")
                
            })
            
            
        }
        
        
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
