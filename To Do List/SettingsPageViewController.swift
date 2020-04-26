//
//  SettingsPageViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 26/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class SettingsPageViewController: UIViewController {
    
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
