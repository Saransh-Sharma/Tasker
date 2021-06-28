//
//  SettingsPageViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 26/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class SettingsPageViewController: UIViewController {
    //MARK:- Backdrop & Fordrop parent containers
    var backdropContainer = UIView()
    var foredropContainer = UIView()
    
    //MARK:- Positioning
    var headerEndY: CGFloat = 128
    
    var seperatorTopLineView = UIView()
    var backdropNochImageView = UIImageView()
    var backdropBackgroundImageView = UIImageView()
    var backdropForeImageView = UIImageView()
    let backdropForeImage = UIImage(named: "backdropFrontImage")
    
    var todoColors = ToDoColors()
    var todoFont = ToDoFont()
    
    var homeTopBar = UIView()
    
    let settingsPageTitle = UILabel()
    

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Settings"
        // Do any additional setup after loading the view.
        setupBackdrop()

    }
    
//    backdropBackgroundImageView.frame =  CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//    backdropBackgroundImageView.backgroundColor = todoColors.primaryColor
//    homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
//    backdropBackgroundImageView.addSubview(homeTopBar)
    

    
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        
//        
//        view.addSubview(backdropContainer)
//        setupBackdrop()
//        
////        view.addSubview(foredropStackContainer)
////        setupAddTaskForedrop()
//        
////        addTaskTextBox_Material.becomeFirstResponder()
////        addTaskTextBox_Material.keyboardType = .webSearch
//        //        addTaskTextBox_Material.returnKeyType = .done
////    addTaskTextBox_Material.autocorrectionType = .yes
////        addTaskTextBox_Material.smartDashesType = .yes
//        addTaskTextBox_Material.smartQuotesType = .yes
//        addTaskTextBox_Material.smartInsertDeleteType = .yes
//        
//        addTaskTextBox_Material.delegate = self
//        
//        
//    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        //        filledBar.set
    }
    
    // MARK:- Build Page Header
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    
    
}
