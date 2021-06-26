//
//  SettingsBackdrop.swift
//  Tasker
//
//  Created by Saransh Sharma on 27/06/21.
//  Copyright © 2021 saransh1337. All rights reserved.
//

import Foundation
import UIKit

extension SettingsPageViewController {
    
    func setupBackdrop() {
        
        backdropContainer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        
        backdropContainer.backgroundColor = .systemBlue
        
   
        headerEndY = UIScreen.main.bounds.height/7.3
        setupBackdropBackground()

        
        view.addSubview(backdropContainer)
        
 
    }
    
    //MARK:- Setup Backdrop Background - Today label + Score
    func setupBackdropBackground() {
        
        backdropBackgroundImageView.frame =  CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.backgroundColor = .black//todoColors.primaryColor
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        backdropBackgroundImageView.addSubview(homeTopBar)
        
  
        backdropContainer.addSubview(backdropBackgroundImageView)
    }
    

 
    
}
