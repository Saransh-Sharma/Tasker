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
        setupTableView()
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
        backdropForeImageView.tintColor = .systemGray6
        //        backdropForeImageView.tintColor = UIColor(red: 37.0/255.0, green: 41.0/255.0, blue: 41.0/255.0, alpha: 1.0)//.systemGray5
        
        
        backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
        backdropForeImageView.layer.shadowOpacity = 0.8
        backdropForeImageView.layer.shadowOffset = CGSize(width: -5.0, height: -5.0) //.zero
        backdropForeImageView.layer.shadowRadius = 10
        
        foredropContainer.addSubview(backdropForeImageView)
        
        
    }
    
    
    func setupTableView() {
        // table view
        print("bottom bar heigght is \(bottomAppBar.bounds.height)")
        tableView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height:  UIScreen.main.bounds.height - bottomAppBar.bounds.height)
        
        foredropContainer.addSubview(tableView)
    }
    
    
}
