//
//  AddTaskForedropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 03/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import MaterialComponents.MaterialTextControls_FilledTextAreas
import MaterialComponents.MaterialTextControls_FilledTextFields
import MaterialComponents.MaterialTextControls_OutlinedTextAreas
import MaterialComponents.MaterialTextControls_OutlinedTextFields


extension AddTaskViewController {

     func setupFordrop() {
            
            print("Backdrop starts from: \(headerEndY)") //this is key to the whole view; charts, cal, animations, all
            foredropContainer.frame =  CGRect(x: 0, y: headerEndY+UIScreen.main.bounds.height/6, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
            setupBackdropForeground()
//            setupTableView()
            foredropContainer.backgroundColor = .clear
        setupAddTaskTextField()
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
        let estimatedFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/8)//CGRect(x: circleMenuStartX+circleMenuRadius/2, y: 0, width: UIScreen.main.bounds.maxX-(10+70+circleMenuRadius/2), height: standardHeight/2)
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

}
