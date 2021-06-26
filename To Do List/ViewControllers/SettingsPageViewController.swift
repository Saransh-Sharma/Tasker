//
//  SettingsPageViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 26/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class SettingsPageViewController: UIViewController {
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
    
    
}
