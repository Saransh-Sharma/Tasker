//
//  AddTaskBackdropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 03/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation

import UIKit

extension AddTaskViewController {
    // setupBackdrop() method removed to fix duplicate declaration

    //MARK:- Setup Backdrop Background - Today label + Score
    func setupBackdropBackground() {

        backdropBackgroundImageView.frame =  CGRect(x: 0, y: backdropNochImageView.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.backgroundColor = todoColors.primaryColor
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        backdropBackgroundImageView.addSubview(homeTopBar)


        //---------- score at home

        scoreAtHomeLabel.text = "\n\nscore"
        scoreAtHomeLabel.numberOfLines = 3
        scoreAtHomeLabel.textColor = .label
        scoreAtHomeLabel.font = todoFont.setFont(fontSize: 20, fontweight: .regular, fontDesign: .monospaced)


        scoreAtHomeLabel.textAlignment = .center
        scoreAtHomeLabel.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 20, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)

        //---- score

        scoreCounter.text = "tt"
        scoreCounter.numberOfLines = 1
        scoreCounter.textColor = .systemGray5
        scoreCounter.font = todoFont.setFont(fontSize: 52, fontweight: .bold, fontDesign: .rounded)

        scoreCounter.textAlignment = .center
        scoreCounter.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 15, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)

        backdropContainer.addSubview(backdropBackgroundImageView)
    }
}
