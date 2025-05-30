//
//  AddTaskForedropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 03/06/20.
//  Copyright 2020 saransh1337. All rights reserved.
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
        
        print("Backdrop starts from: \(self.headerEndY)") //this is key to the whole view; charts, cal,
        self.foredropStackContainer.frame = CGRect(x: 0, y: self.homeTopBar.frame.maxY*2.2, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-self.headerEndY)
        
        
        self.setupBackdropForeground()
        //        self.foredropStackContainer.backgroundColor = .black
        
        self.setupAddTaskTextField()
        self.foredropStackContainer.addArrangedSubview(UIView())
        
        self.setupProjectsPillBar()
        self.foredropStackContainer.addArrangedSubview(UIView())
        
        self.setupPrioritySC()
        self.foredropStackContainer.addArrangedSubview(UIView())
        
        //        self.setupDoneButton()
        self.foredropStackContainer.addArrangedSubview(UIView())
        
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 2: SETUP FOREGROUND
    //----------------------- *************************** -----------------------
    
    //MARK: Setup forground
    func setupBackdropForeground() {
        
        self.backdropForeImageView.frame =  CGRect(x: 0, y:0, width: UIScreen.main.bounds.width, height:  UIScreen.main.bounds.height)
        self.backdropForeImageView.image = self.backdropForeImage?.withRenderingMode(.alwaysTemplate)
        self.backdropForeImageView.tintColor = .systemGray6
        
        
        self.backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
        self.backdropForeImageView.layer.shadowOpacity = 0.8
        self.backdropForeImageView.layer.shadowOffset = CGSize(width: -5.0, height: -5.0) //.zero
        self.backdropForeImageView.layer.shadowRadius = 10
        
        self.foredropStackContainer.addSubview(self.backdropForeImageView)
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    Setup Projects Pill Bar
    //----------------------- *************************** -----------------------
    
    func setupProjectsPillBar() {
        
        print("do9 - SETUP PROJECTS pillbar")
        self.buildProojectsPillBarData()
        
        self.filledBar = self.createProjectsBar(items: self.pillBarProjectList)
        self.filledBar!.frame = CGRect(x: 0, y: 300, width: UIScreen.main.bounds.width, height: 65)
        self.foredropStackContainer.addArrangedSubview(self.filledBar!)
        self.filledBar!.backgroundColor = .clear
        self.filledBar!.isHidden = self.addTaskTextBox_Material.text?.isEmpty ?? true
        
        
        //        filledBar.selected
        //        filledBar.addTarget(self, action: #selector(changeProject))
        
    }
    
    func buildProojectsPillBarData() {
        // ProjectManager's data is expected to be refreshed by AddTaskViewController's viewWillAppear.
        
        let allDisplayProjects = ProjectManager.sharedInstance.displayedProjects // Use displayedProjects instead of getAllProjects
        
        self.pillBarProjectList = [] // Reset the list
        
        // 1. Add the static "Add Project" button first
        self.pillBarProjectList.append(PillButtonBarItem(title: self.addProjectString)) // `addProjectString` should be defined, e.g., "Add Project"
        
        // 2. Add all existing projects
        for each in allDisplayProjects {
            if let projectName = each.projectName {
                print("do9 added to pill bar, from ProjectManager: \(projectName)")
                self.pillBarProjectList.append(PillButtonBarItem(title: projectName))
            }
        }
        
        // 2. Add actual projects from ProjectManager
        // `displayedProjects` should already have "Inbox" sorted appropriately if it exists.
        for project in allDisplayProjects {
            if let projectName = project.projectName {
                // Ensure we don't add "Add Project" if it accidentally exists as a project name
                if projectName.lowercased() != addProjectString.lowercased() {
                    // Avoid duplicates in pillBarProjectList
                    if !pillBarProjectList.contains(where: { $0.title.lowercased() == projectName.lowercased() }) {
                        pillBarProjectList.append(PillButtonBarItem(title: projectName))
                    }
                }
            }
        }
        
        // 3. Ensure "Inbox" is present and correctly positioned (second item, after "Add Project")
        let inboxTitle = ProjectManager.sharedInstance.defaultProject // "Inbox"
        let addProjectItemTitle = addProjectString
        
        // Remove any existing "Inbox" to avoid duplicates before re-inserting at correct position
        pillBarProjectList.removeAll(where: { $0.title.lowercased() == inboxTitle.lowercased() })
        
        // Find index of "Add Project"
        if let addProjectPillIndex = pillBarProjectList.firstIndex(where: { $0.title.lowercased() == addProjectItemTitle.lowercased() }) {
            // Insert "Inbox" right after "Add Project" if "Add Project" exists
            if pillBarProjectList.count > addProjectPillIndex {
                pillBarProjectList.insert(PillButtonBarItem(title: inboxTitle), at: addProjectPillIndex + 1)
                print("do9 - Ensured 'Inbox' is the second item in pillBarProjectList after 'Add Project'.")
            }
        } else {
            // This case should ideally not happen if "Add Project" is always added first.
            // As a fallback, add "Inbox" and then "Add Project" if "Add Project" was missing.
            pillBarProjectList.insert(PillButtonBarItem(title: inboxTitle), at: 0)
            pillBarProjectList.insert(PillButtonBarItem(title: addProjectItemTitle), at: 0)
            print("do9 - Fallback: Added 'Add Project' and 'Inbox' to the start of pillBarProjectList.")
        }
        
        // Log the final list for verification
        print("do9 - Final pillBarProjectList for AddTaskScreen setup:")
        for (index, value) in pillBarProjectList.enumerated() {
            print("do9 --- AT INDEX \(index) value is \(value.title)")
        }
    }
    
    
    func createProjectsBar(items: [PillButtonBarItem], centerAligned: Bool = false) -> UIView {
        let bar = PillButtonBar()
        bar.items = items
        if items.count > 1 {
            bar.selectItem(atIndex: 1) // Default to "Inbox" (index 1)
        } else if !items.isEmpty {
            bar.selectItem(atIndex: 0) // Fallback to first item if only one exists
        }
        bar.barDelegate = self
        bar.centerAligned = centerAligned
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        
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
        self.addTaskTextBox_Material = MDCFilledTextField(frame: estimatedFrame)
        //        addTaskTextBox_Material.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
        self.addTaskTextBox_Material.label.text = "add task & tap done"
        self.addTaskTextBox_Material.leadingAssistiveLabel.text = "add actionable items"
        //        addTaskTextBox_Material.font = UIFont(name: "HelveticaNeue", size: 18)
        
        self.addTaskTextBox_Material.sizeToFit()
        
        self.addTaskTextBox_Material.delegate = self //v
        self.addTaskTextBox_Material.clearButtonMode = .whileEditing
        let placeholderTextArray = ["meet Laura at 2 for coffee", "design prototype", "bring an ☂️",
                                    "schedule 1:1 with Shelly","grab 401k from mail box",
                                    "get car serviced", "wrap Eve's birthaday gift ", "renew Gym membership",
                                    "book flight tickets to Thailand", "fix the garage door",
                                    "order Cake", "review subscriptions", "get coffee"]
        self.addTaskTextBox_Material.placeholder = placeholderTextArray.randomElement()!
        //        addTaskTextBox_Material.sizeToFit()
        
        self.addTaskTextBox_Material.backgroundColor = .clear
        
        
        self.foredropStackContainer.addArrangedSubview(self.addTaskTextBox_Material)
        
        
    }
    
    func setupEveningTaskSwitch() {
        // self.switchSetContainer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50) // Not needed if using StackView for layout
        // self.switchSetContainer.backgroundColor = .clear // Not needed if using StackView for layout
        
        self.eveningLabel.text = "Evening Task"
        self.eveningLabel.textColor = .gray // Or use a color from ToDoColors
        self.eveningLabel.font = self.todoFont.setFont(fontSize: 17, fontweight: .regular, fontDesign: .default) // Corrected font usage
        
        // self.eveningLabel.frame = CGRect(x: 0, y: 0, width: 100, height: 50) // Not needed if using StackView for layout
        // self.eveningLabel.sizeToFit() // StackView will manage size
        
        // self.eveningSwitch.frame = CGRect(x: self.eveningLabel.frame.width + 15, y: 0, width: 20, height: 20) // Not needed if using StackView for layout
        self.eveningSwitch.isOn = false
        self.eveningSwitch.onTintColor = self.todoColors.primaryColor // Corrected color usage
        
        self.eveningSwitch.addTarget(self, action: #selector(self.isEveningSwitchOn(sender:)), for: .valueChanged)
        
        // Add eveningLabel and eveningSwitch to a UIStackView, then add that stack view to self.foredropStackContainer
        let switchRow = UIStackView(arrangedSubviews: [self.eveningLabel, self.eveningSwitch])
        switchRow.spacing = 8
        switchRow.alignment = .center
        // switchRow.distribution = .fill // Or .equalSpacing, .fillProportionally as needed
        self.foredropStackContainer.addArrangedSubview(switchRow)
    }
    
    // MARK: MAKE Priority SC
    func setupPrioritySC() {
        print("SETUP PRIORITY SC")
        //MARK:- -this is in foredrop (tablsegcontrol: to allow users to pick which list stays in today and which goes)
        
        // 1) Initialize with your array of titles directly
        let segmented = SegmentedControl(items: p.map { SegmentItem(title: $0) })
        
        // 2) Default to the penultimate segment (or whatever index makes sense)
        segmented.selectedSegmentIndex = max(0, p.count - 2)
        
        // 3) Show/hide based on eveningSwitch
        segmented.isHidden = eveningSwitch.isOn
        
        // 4) Wire up selection using FluentUI closure API
        segmented.onSelectAction = { [weak self] (item: SegmentItem, selectedIndex: Int) in
            guard let self = self else { return }
            self.changeTaskPriority(segmented)
        }
        
        // 5) Keep a reference and insert into your stack
        self.tabsSegmentedControl = segmented
        self.foredropStackContainer.addArrangedSubview(segmented)
    }
    //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is none/p4; default is 3(p2)
    @objc func changeTaskPriority(_ sender: SegmentedControl) { // Corrected sender type
        //"None", "Low", "High", "Highest"]
        switch sender.selectedSegmentIndex {
        case 0:
            print("Priority is None - priority 4")
            self.currentTaskPriority = 4
        case 1:
            print("Priority is Low - priority 3")
            self.currentTaskPriority = 3
        case 2:
            print("Priority is High - priority 2")
            self.currentTaskPriority = 2
        case 3:
            print("Priority is Highest - priority 1")
            self.currentTaskPriority = 1
        default:
            print("Failed to get Task Priority, defaulting to Low/3")
            self.currentTaskPriority = 3
        }
    }
    
    func setupDoneButton() {
    // MARK:---FAB - DONE Task
    
    let doneButtonHeightWidth: CGFloat = 50
    
    self.fab_doneTask.mode = .expanded
    self.fab_doneTask.setTitle("Done", for: .normal)
    self.fab_doneTask.setTitle("Adding...", for: .highlighted)
    self.fab_doneTask.titleLabel?.text = "Done"
    
    self.fab_doneTask.setTitleColor(.white, for: .normal)
    
    let doneTaskIconNormalImage = UIImage(systemName: "checkmark.circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal)
    self.fab_doneTask.setImage(doneTaskIconNormalImage, for: .normal)
    
    if(self.eveningSwitch.isOn){
        let eveningIcon = UIImage(systemName: "moon.stars.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        self.fab_doneTask.setImage(eveningIcon, for: .highlighted)
    }else{
        let dayIcon = UIImage(systemName: "sun.max.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        self.fab_doneTask.setImage(dayIcon, for: .highlighted)
    }
    
    self.fab_doneTask.backgroundColor = self.todoColors.secondaryAccentColor
    self.fab_doneTask.sizeToFit()
    //        self.foredropContainer.addSubview(self.fab_doneTask)
    //        self.fab_doneTask.contentHorizontalAlignment = .trailing
    self.fab_doneTask.titleLabel?.textAlignment = .center
    
    self.fab_doneTask.isHidden = self.addTaskTextBox_Material.text?.isEmpty ?? true // Aligned with other UI elements
    
    self.foredropStackContainer.addArrangedSubview(self.fab_doneTask)
    self.fab_doneTask.addTarget(self, action: #selector(self.doneAddTaskAction), for: .touchUpInside)
}

//MARK:- DONE TASK ACTION
@objc func doneAddTaskAction() {
    //       tap DONE --> add new task + nav homeScreen
    //MARK:- ADD TASK ACTION
    self.isThisEveningTask = self.isEveningSwitchOn(sender: self.eveningSwitch)
    //        var taskDueDate = Date()
    print("task: User tapped done button at add task")
    if self.currentTaskInMaterialTextBox != "" {
        
        print("Adding task: \(self.currentTaskInMaterialTextBox)")
        print("Priority is: \(self.currentTaskPriority)")
        print("Add ask projet is: \(self.currenttProjectForAddTaskView)")
        
        print("Addig task for date: \(self.dateForAddTaskView.stringIn(dateStyle: .full, timeStyle: .none))")
        
        let taskType = self.getTaskType() // This call should now work
        TaskManager.sharedInstance.addNewTask_Future(name: self.currentTaskInMaterialTextBox, taskType: taskType, taskPriority: self.currentTaskPriority, futureTaskDate: self.dateForAddTaskView, isEveningTask: self.isThisEveningTask, project: self.currenttProjectForAddTaskView)
        
        HUD.shared.showSuccess(from: self, with: "Added to\n\(self.currenttProjectForAddTaskView)")
        
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
    self.dismiss(animated: true) //this looks more like cancel compared to above
}

    func getTaskType() -> Int {
        return self.isThisEveningTask ? 2 : 1
    }
    
    @objc func isEveningSwitchOn(sender: UISwitch!) -> Bool {
        self.isThisEveningTask = sender.isOn
        if sender.isOn {
            print("SWITCH: on")
            return true
        } else {
            print("SWITCH: off")
            return false
        }
    }
}
