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
    
    
    
    // setupAddTaskForedrop() method removed to fix duplicate declaration
    
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
        self.addTaskTextBox_Material.label.text = "Task Name"
        self.addTaskTextBox_Material.leadingAssistiveLabel.text = "Enter task name"
        
        self.addTaskTextBox_Material.sizeToFit()
        
        self.addTaskTextBox_Material.delegate = self
        self.addTaskTextBox_Material.clearButtonMode = .whileEditing
        let placeholderTextArray = ["meet Laura at 2 for coffee", "design prototype", "bring an ☂️",
                                    "schedule 1:1 with Shelly","grab 401k from mail box",
                                    "get car serviced", "wrap Eve's birthaday gift ", "renew Gym membership",
                                    "book flight tickets to Thailand", "fix the garage door",
                                    "order Cake", "review subscriptions", "get coffee"]
        self.addTaskTextBox_Material.placeholder = placeholderTextArray.randomElement()!
        self.addTaskTextBox_Material.returnKeyType = .go
        
        self.addTaskTextBox_Material.backgroundColor = .clear
        
        // Don't add to stack container here - it's added in viewDidLoad
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
        
        // 5) Keep a reference
        self.tabsSegmentedControl = segmented
        // Don't add to stack container here - it's added in viewDidLoad
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
    
    // Don't add to stack container here - it's added in viewDidLoad
    self.fab_doneTask.addTarget(self, action: #selector(self.doneAddTaskAction), for: .touchUpInside)
}

//MARK:- DONE TASK ACTION
// doneAddTaskAction() method removed to fix duplicate declaration

//MARK:- CANCEL TASK ACTION
// cancelAddTaskAction() method removed to fix duplicate declaration

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
