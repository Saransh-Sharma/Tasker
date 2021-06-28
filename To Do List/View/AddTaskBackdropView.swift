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
    
    func setupBackdrop() {
        
        backdropContainer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        //         CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        
        //        headerEndY = 128
        headerEndY = UIScreen.main.bounds.height/7.3
        setupBackdropBackground()
        addCancelBackdrop()
//        setupBackdropNotch()
        setHomeViewDate()
        
        // cal
        setupCalAtAddTask()
        backdropContainer.addSubview(calendar)
    }
    
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
    
    func addCancelBackdrop() {
        cancelButton.frame = CGRect(x: (UIScreen.main.bounds.width)-(homeTopBar.bounds.height+15), y: 15, width: (homeTopBar.bounds.height)+45, height: (homeTopBar.bounds.height)+45)
        view.addSubview(cancelButton)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 1.1 : SETUP NOTCH BACKDROP
    //----------------------- *************************** -----------------------
    
//    //MARK:- Setup Backdrop Notch
//    func setupBackdropNotch() {
//        if (UIDevice.current.hasNotch) {
//            print("I SEE NOTCH !!")
//        } else {
//            print("NO NOTCH !")
//        }
//
//    }
//
    
    //----------------------- *************************** -----------------------
    //MARK:-                    SETUP HOME DATE VIEW
    //                          sub:homeTopBar
    //----------------------- *************************** -----------------------
    func setHomeViewDate() {
        let today = dateForAddTaskView
        if("\(today.day)".count < 2) {
            homeDate_Day.text = "0\(today.day)"
        } else {
            homeDate_Day.text = "\(today.day)"
        }
        homeDate_WeekDay.text = todoTimeUtils.getWeekday(date: today)
        homeDate_Month.text = todoTimeUtils.getMonth(date: today)
        
        
        homeDate_Day.numberOfLines = 1
        homeDate_WeekDay.numberOfLines = 1
        homeDate_Month.numberOfLines = 1
        
        homeDate_Day.textColor = .systemGray6
        homeDate_WeekDay.textColor = .systemGray6
        homeDate_Month.textColor = .systemGray6
        
        homeDate_Day.font =  todoFont.setFont(fontSize: 58, fontweight: .medium, fontDesign: .rounded)
        homeDate_WeekDay.font =  todoFont.setFont(fontSize: 26, fontweight: .thin, fontDesign: .rounded)
        homeDate_Month.font =  todoFont.setFont(fontSize: 26, fontweight: .regular, fontDesign: .rounded)
        
        homeDate_Day.textAlignment = .left
        homeDate_WeekDay.textAlignment = .left
        homeDate_Month.textAlignment = .left
        
        
        homeDate_Day.frame = CGRect(x: 5, y: 18, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        homeDate_WeekDay.frame = CGRect(x: 76, y: homeTopBar.bounds.minY+30, width: (homeTopBar.bounds.width/2)-100, height: homeTopBar.bounds.height)
        homeDate_Month.frame = CGRect(x: 76, y: homeTopBar.bounds.minY+10, width: (homeTopBar.bounds.width/2)-80, height: homeTopBar.bounds.height)
        
        
        homeDate_WeekDay.adjustsFontSizeToFitWidth = true
        homeDate_Month.adjustsFontSizeToFitWidth = true
        
        homeTopBar.addSubview(homeDate_Day)
        homeTopBar.addSubview(homeDate_WeekDay)
        homeTopBar.addSubview(homeDate_Month)
        
        
        homeDate_Day.layer.shadowColor =  todoColors.primaryColorDarker.cgColor//todoColors.primaryColorDarker.cgColor
        homeDate_Day.layer.shadowOpacity = 0.6
        homeDate_Day.layer.shadowOffset = .zero //CGSize(width: -2.0, height: -2.0) //.zero
        homeDate_Day.layer.shadowRadius = 8
        
        homeDate_WeekDay.layer.shadowColor = todoColors.primaryColorDarker.cgColor
        homeDate_WeekDay.layer.shadowOpacity = 0.6
        homeDate_WeekDay.layer.shadowOffset = .zero //CGSize(width: -2.0, height: -2.0) //.zero
        homeDate_WeekDay.layer.shadowRadius = 8
        
        homeDate_Month.layer.shadowColor = todoColors.primaryColorDarker.cgColor
        homeDate_Month.layer.shadowOpacity = 0.6
        homeDate_Month.layer.shadowOffset = .zero //CGSize(width: -2.0, height: -2.0) //.zero
        homeDate_Month.layer.shadowRadius = 8
        
    }
}
