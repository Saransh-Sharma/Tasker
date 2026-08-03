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
        let bounds = view.bounds
        backdropContainer.frame = bounds
        backdropContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
//        backdropContainer.backgroundColor = .systemBlue
        
   
        headerEndY = bounds.height / 7.3
        setupBackdropBackground()

        
        view.addSubview(backdropContainer)
        
 
    }
    
    //MARK:- Setup Backdrop Background - Today label + Score
    /// Executes setupBackdropBackground.
    func setupBackdropBackground() {
        let bounds = backdropContainer.bounds
        backdropBackgroundImageView.frame = bounds
        backdropBackgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropBackgroundImageView.backgroundColor = UIColor.lifeboard.bgCanvas
        homeTopBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 120)
        homeTopBar.autoresizingMask = [.flexibleWidth]
        
        
        let settingsTitle = UILabel()
        settingsTitle.frame = CGRect(x: 0, y: 10, width: bounds.width, height: bounds.height)
        settingsTitle.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        settingsTitle.text = "Settings"
        settingsTitle.textColor = UIColor.lifeboard.textPrimary
        settingsTitle.font = UIFont.lifeboard.font(for: .title1)
        
        homeTopBar.addSubview(settingsTitle)
        
        backdropBackgroundImageView.addSubview(homeTopBar)
        
  
        backdropContainer.addSubview(backdropBackgroundImageView)
    }
    

 
    
}
