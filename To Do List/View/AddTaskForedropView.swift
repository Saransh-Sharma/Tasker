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
        
        self.backdropForeImageView.applyTaskerElevation(.e1)
        
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

        // Token-based styling: iOS-native filled field look
        styleFilledTextField(self.addTaskTextBox_Material)
    }
    
    func setupEveningTaskSwitch() {

        
        self.eveningLabel.text = "Evening Task"
        self.eveningLabel.textColor = UIColor.tasker.textSecondary
        self.eveningLabel.font = UIFont.tasker.font(for: .body)
        self.eveningSwitch.isOn = false
        self.eveningSwitch.onTintColor = UIColor.tasker.accentPrimary
        
        self.eveningSwitch.addTarget(self, action: #selector(self.isEveningSwitchOn(sender:)), for: .valueChanged)
        
        // Add eveningLabel and eveningSwitch to a UIStackView, then add that stack view to self.foredropStackContainer
        let switchRow = UIStackView(arrangedSubviews: [self.eveningLabel, self.eveningSwitch])
        switchRow.spacing = 8
        switchRow.alignment = .center
        // switchRow.distribution = .fill // Or .equalSpacing, .fillProportionally as needed
        self.foredropStackContainer.addArrangedSubview(switchRow)
    }
    
    // MARK: - Shared Field Styling

    /// Apply token-based styling to MDCFilledTextField for iOS-native filled look.
    func styleFilledTextField(_ field: MDCFilledTextField) {
        // Background
        field.setFilledBackgroundColor(todoColors.surfaceSecondary, for: .normal)
        field.setFilledBackgroundColor(todoColors.surfaceSecondary, for: .editing)

        // Border + focus ring
        field.setUnderlineColor(todoColors.strokeHairline, for: .normal)
        field.setUnderlineColor(todoColors.accentRing, for: .editing)

        // Corner radius
        field.containerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.r2

        // Label colors
        field.setFloatingLabelColor(todoColors.textTertiary, for: .normal)
        field.setFloatingLabelColor(todoColors.accentPrimary, for: .editing)
        field.setNormalLabelColor(todoColors.textQuaternary, for: .normal)
        field.setTextColor(todoColors.textPrimary, for: .normal)
        field.setTextColor(todoColors.textPrimary, for: .editing)
        field.tintColor = todoColors.accentPrimary
    }

    // MARK: MAKE Priority SC
    func setupPrioritySC() {
        print("SETUP PRIORITY SC")

        // 1) Initialize with your array of titles directly
        let segmented = UISegmentedControl(items: p)

        // 2) Keep UI selection aligned with current model value
        segmented.selectedSegmentIndex = currentTaskPriority.segmentIndex()

        // 3) Show/hide based on eveningSwitch
        segmented.isHidden = eveningSwitch.isOn

        // 4) Token-based styling
        segmented.backgroundColor = todoColors.surfaceTertiary
        segmented.selectedSegmentTintColor = todoColors.surfacePrimary
        segmented.setTitleTextAttributes([
            .foregroundColor: todoColors.textSecondary,
            .font: UIFont.tasker.font(for: .callout)
        ], for: .normal)
        segmented.setTitleTextAttributes([
            .foregroundColor: todoColors.accentPrimary,
            .font: UIFont.tasker.font(for: .callout)
        ], for: .selected)

        // 5) Wire up selection using standard UISegmentedControl API
        segmented.addTarget(self, action: #selector(changeTaskPriority(_:)), for: .valueChanged)

        // 6) Set accessibility identifier
        segmented.accessibilityIdentifier = "addTask.prioritySegmentedControl"

        // 7) Keep a reference
        self.tabsSegmentedControl = segmented
        // Don't add to stack container here - it's added in viewDidLoad
    }
    @objc func changeTaskPriority(_ sender: UISegmentedControl) {
        self.currentTaskPriority = TaskPriority.fromSegmentIndex(sender.selectedSegmentIndex)
        print("Priority selected: \(self.currentTaskPriority.displayName) (\(self.currentTaskPriority.rawValue))")
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
