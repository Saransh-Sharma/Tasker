//
//  ForedropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit

extension HomeViewController {
    
    
    func setupHomeFordrop() {
        
        print("Backdrop starts from: \(headerEndY)") //this is key to the whole view; charts, cal, animations, all
        foredropContainer.frame =  CGRect(x: 0, y: homeTopBar.frame.maxY-5, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)//CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        //homeTopBar.frame.maxY
        setupBackdropForeground()
        setupTableViewFrame()
        foredropContainer.backgroundColor = .clear
        foredropContainer.bringSubviewToFront(tableView)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 2: SETUP FOREGROUND
    //----------------------- *************************** -----------------------
    
    //MARK: Setup forground
    func setupBackdropForeground() {
        
        backdropForeImageView.frame =  CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height:  UIScreen.main.bounds.height)
        backdropForeImageView.image = backdropForeImage?.withRenderingMode(.alwaysTemplate)
        backdropForeImageView.tintColor = .systemBackground
        // backdropForeImageView.tintColor may be adjusted from token roles if needed.
        backdropForeImageView.applyTaskerElevation(.e1)
        
        foredropContainer.addSubview(backdropForeImageView)
        
        
    }
    
    
    func setupTableViewFrame() {
        // table view
        tableView.frame = foredropContainer.bounds
        
        foredropContainer.addSubview(tableView)
    }
    
    
}
