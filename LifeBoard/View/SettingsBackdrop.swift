//
//  SettingsBackdrop.swift
//  LifeBoard
//
//  Created by Saransh Sharma on 27/06/21.
//  Copyright © 2021 saransh1337. All rights reserved.
//

import Foundation
import UIKit

extension SettingsPageViewController {
    
    /// Executes setupBackdrop.
    func setupBackdrop() {
        
        backdropContainer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        
//        backdropContainer.backgroundColor = .systemBlue
        
   
        headerEndY = UIScreen.main.bounds.height/7.3
        setupBackdropBackground()

        
        view.addSubview(backdropContainer)
        
 
    }
    
    //MARK:- Setup Backdrop Background - Today label + Score
    /// Executes setupBackdropBackground.
    func setupBackdropBackground() {
        
        backdropBackgroundImageView.frame =  CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.backgroundColor = UIColor.lifeboard.bgCanvas
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        
        
        let settingsTitle = UILabel()
        settingsTitle.frame =  CGRect(x: 0, y: 10, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        settingsTitle.text = "Settings"
        settingsTitle.textColor = UIColor.lifeboard.textPrimary
        settingsTitle.font = UIFont.lifeboard.font(for: .title1)
        
        homeTopBar.addSubview(settingsTitle)
        
        backdropBackgroundImageView.addSubview(homeTopBar)
        
  
        backdropContainer.addSubview(backdropBackgroundImageView)
    }
    

 
    
}
