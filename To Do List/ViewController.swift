//
//  ViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func changeBackground(_ sender: Any) {
        view.backgroundColor = UIColor.black
        
        let everything = view.subviews
        
        for each in everything {
            each.backgroundColor = UIColor.red
        }
    }
    @IBAction func changeBackgroundBackToLight(_ sender: Any) {
        
        view.backgroundColor = UIColor.white
            
            let everything = view.subviews
            
            for each in everything {
                each.backgroundColor = UIColor.white
            }
    }
    
}

