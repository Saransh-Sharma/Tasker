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
        self.addTaskTextBox_Material.label.text = "Task"
        self.addTaskTextBox_Material.leadingAssistiveLabel.text = "Add task"
        
        self.addTaskTextBox_Material.sizeToFit()
        
        self.addTaskTextBox_Material.delegate = self
        self.addTaskTextBox_Material.clearButtonMode = .whileEditing
        let placeholderTextArray = ["meet Laura at 2 for coffee", "design prototype", "bring an ☂️",
                                    "schedule 1:1 with Shelly","grab 401k from mail box",
                                    "get car serviced", "wrap Eve's birthday gift ", "renew Gym membership",
                                    "book flight tickets to Thailand", "fix the garage door",
                                    "order cake", "review subscriptions", "get coffee"]
        self.addTaskTextBox_Material.placeholder = placeholderTextArray.randomElement()!
        self.addTaskTextBox_Material.returnKeyType = .go
        
        self.addTaskTextBox_Material.backgroundColor = .clear
        
    }
    
    func setupEveningTaskSwitch() {

        
        self.eveningLabel.text = "Evening Task"
        self.eveningLabel.textColor = .gray // Or use a color from ToDoColors
        self.eveningLabel.font = self.todoFont.setFont(fontSize: 17, fontweight: .regular, fontDesign: .default) 
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
        let segmented = UISegmentedControl(items: p)

        // 2) Default to the penultimate segment (or whatever index makes sense)
        segmented.selectedSegmentIndex = max(0, p.count - 2)

        // 3) Show/hide based on eveningSwitch
        segmented.isHidden = eveningSwitch.isOn

        // 4) Configure to prevent text wrapping by using shorter text if needed
        // FluentUI SegmentedControl doesn't support setTitleTextAttributes
        // Instead, we'll ensure the container has enough width and use shorter labels if needed

        // 5) Wire up selection using standard UISegmentedControl API
        segmented.addTarget(self, action: #selector(changeTaskPriority(_:)), for: .valueChanged)

        // 6) Set accessibility identifier
        segmented.accessibilityIdentifier = "addTask.prioritySegmentedControl"

        // 7) Keep a reference
        self.tabsSegmentedControl = segmented
        // Don't add to stack container here - it's added in viewDidLoad
    }
    //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is none/p4; default is 3(p2)
    @objc func changeTaskPriority(_ sender: UISegmentedControl) { // Corrected sender type
        //"None", "Low", "High", "Highest"]
        switch sender.selectedSegmentIndex {
        case 0:
            print("Priority is None - priority 4")
            self.currentTaskPriority = .low  // Map "None" to low priority
        case 1:
            print("Priority is Low - priority 3")
            self.currentTaskPriority = .low
        case 2:
            print("Priority is High - priority 2")
            self.currentTaskPriority = .high
        case 3:
            print("Priority is Highest - priority 1")
            self.currentTaskPriority = .high  // Map "Highest" to high priority
        default:
            print("Failed to get Task Priority, defaulting to Low/3")
            self.currentTaskPriority = .low
        }
    }
    
    // OLD: setupDoneButton() method removed
    // Now using navigation bar Done button instead of FAB
    // See AddTaskViewController.swift setupNavigationBar() for new implementation


    func getTaskType() -> Int32 {
        return self.isThisEveningTask ? 2 : 1 // 2=evening, 1=morning
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
