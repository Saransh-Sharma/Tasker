//
//  ForedropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit

extension ViewController {


    func setupFordrop() {
        
        setupBackdropForeground()
        setupTableView()
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 2: SETUP FOREGROUND
    //----------------------- *************************** -----------------------
    
    //MARK: Setup forground
    func setupBackdropForeground() {
        //    func setupBackdropForeground() {
        
        print("Backdrop starts from: \(headerEndY)") //this is key to the whole view; charts, cal, animations, all
        backdropForeImageView.frame = CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        
        
        
        backdropForeImageView.image = backdropForeImage?.withRenderingMode(.alwaysTemplate)
        backdropForeImageView.tintColor = .systemGray6
        
        
        backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
        backdropForeImageView.layer.shadowOpacity = 0.8
        backdropForeImageView.layer.shadowOffset = CGSize(width: -5.0, height: -5.0) //.zero
        backdropForeImageView.layer.shadowRadius = 10
        
        view.addSubview(backdropForeImageView)
        
    }
    
    func setupTableView() {
        // table view
                   tableView.frame = CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
                   view.addSubview(tableView)
    }
    
    
}
