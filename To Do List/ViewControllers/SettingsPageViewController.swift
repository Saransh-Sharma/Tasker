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
    
    @IBAction func backToHome(_ sender: Any) {
    }
    
    @IBOutlet weak var switchState: UISwitch!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Settings"
        // Do any additional setup after loading the view.
        if UserDefaults.standard.bool(forKey: "isDarkModeOn") {
            switchState.setOn(true, animated: true)
            print("SETTINGS: DARK ON")
            view.backgroundColor = UIColor.darkGray
        } else {
            
            print("SETTINGS: DARK OFF !!")
            UserDefaults.standard.set(false, forKey: "isDarkModeOn")
        }
    }
    
//    backdropBackgroundImageView.frame =  CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//    backdropBackgroundImageView.backgroundColor = todoColors.primaryColor
//    homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
//    backdropBackgroundImageView.addSubview(homeTopBar)
    
    
    @IBAction func toggleDarkMode(_ sender: Any) {
        let mSwitch = sender as! UISwitch
        
        if mSwitch.isOn {
            view.backgroundColor = UIColor.darkGray
            //                ViewController.view.backgroundColor = UIColor.darkGray
            
            //ViewController.toggleDarkMode(ViewController.self)
            UserDefaults.standard.set(true, forKey: "isDarkModeOn")
        } else {
            UserDefaults.standard.set(false, forKey: "isDarkModeOn")
            view.backgroundColor = UIColor.white
        }
    }
    
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
