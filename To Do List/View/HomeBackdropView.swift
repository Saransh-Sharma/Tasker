//
//  BackdropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 30/05/20.
//  Copyright 2020 saransh1337. All rights reserved.


import Foundation
import TinyConstraints
import FSCalendar
import MaterialComponents.MaterialRipple
import UIKit


extension HomeViewController {
    
    func setupBackdrop() {
        
        backdropContainer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        headerEndY = UIScreen.main.bounds.height/8
        setupBackdropBackground()
        addTinyChartToBackdrop()
        setupBackdropNotch()
        setupHomeDateView()
        updateHomeViewDate(dateToDisplay: dateForTheView)
        setupLineChartView()
        updateLineChartData()
        lineChartView.isHidden = true //remove this from here hadle elsewhere in a fuc that hides all
        
        // cal
        setupCalView()
        setupCalAppearence()
        backdropContainer.addSubview(calendar)
        calendar.isHidden = false   // always present under foredrop
        setupCalButton()
        setupChartButton()
        setupTopSeperator()
        
        self.setupPieChartView(pieChartView: tinyPieChartView)
        updateTinyPieChartData()
        tinyPieChartView.delegate = self
        
        // entry label styling
        tinyPieChartView.entryLabelColor = .clear
        tinyPieChartView.entryLabelFont = .systemFont(ofSize: 12, weight: .bold)
        
        backdropContainer.bringSubviewToFront(calendar)
        // remember original position for restore
        originalForedropCenterY = foredropContainer.center.y

        // compute revealDistance once
        let bottomOfCalendar = calendar.frame.maxY
        let bottomOfChart    = lineChartView.frame.maxY
        let requiredReveal   = max(bottomOfCalendar, bottomOfChart)
        let foredropTopY     = foredropContainer.frame.minY
        let padding: CGFloat = 16
        revealDistance = (requiredReveal - foredropTopY) + padding

        // hook both buttons to same toggle
        revealCalAtHomeButton.addTarget(self, action: #selector(toggleBackdrop), for: .touchUpInside)
        revealChartsAtHomeButton.addTarget(self, action: #selector(toggleBackdrop), for: .touchUpInside)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 1: SETUP BACKGROUND
    //----------------------- *************************** -----------------------
    
    //MARK:- Setup Backdrop Background - Today label + Score
    func setupBackdropBackground() {
        
//        backdropBackgroundImageView.frame =  CGRect(x: 0, y: backdropNochImageView.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.frame =  CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.backgroundColor = todoColors.primaryColor
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        backdropBackgroundImageView.addSubview(homeTopBar)
        
        
        //---------- score at home
        
        scoreAtHomeLabel.text = "\n\nscore"
        scoreAtHomeLabel.numberOfLines = 3
        scoreAtHomeLabel.textColor = .label
        scoreAtHomeLabel.font = setFont(fontSize: 20, fontweight: .regular, fontDesign: .monospaced)
        
        
        scoreAtHomeLabel.textAlignment = .center
        scoreAtHomeLabel.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 20, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        
        //        homeTopBar.addSubview(scoreAtHomeLabel)
        
        //---- score
        
        scoreCounter.text = "\(self.calculateTodaysScore())"
        scoreCounter.numberOfLines = 1
        scoreCounter.textColor = .systemGray5
        scoreCounter.font = setFont(fontSize: 52, fontweight: .bold, fontDesign: .rounded)
        
        scoreCounter.textAlignment = .center
        scoreCounter.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 15, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        
        backdropContainer.addSubview(backdropBackgroundImageView)
        
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 1.1 : SETUP NOTCH BACKDROP
    //----------------------- *************************** -----------------------
    
    //MARK:- Setup Backdrop Notch
    func setupBackdropNotch() {
        if (UIDevice.current.hasNotch) {
            print("I SEE NOTCH !!")
        } else {
            print("NO NOTCH !")
        }
        //backdropNochImageView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40)
        //backdropNochImageView.backgroundColor = todoColors.primaryColorDarker
        
        //backdropContainer.addSubview(backdropNochImageView)
    }
    
    func addTinyChartToBackdrop() {
        tinyPieChartView.frame = CGRect(x: homeTopBar.frame.maxX-(homeTopBar.frame.height + 10), y: homeTopBar.frame.minY + 15, width: (homeTopBar.frame.height)+41, height: (homeTopBar.frame.height)+41)
        backdropContainer.addSubview(tinyPieChartView)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    SETUP HOME DATE VIEW
    //                          sub:homeTopBar
    //----------------------- *************************** -----------------------
    func setupHomeDateView() {
        homeDate_WeekDay.adjustsFontSizeToFitWidth = true
        homeDate_Month.adjustsFontSizeToFitWidth = true
        
        homeDate_Day.frame = CGRect(x: 5, y: 18, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        homeDate_WeekDay.frame = CGRect(x: 76, y: homeTopBar.bounds.minY+30, width: (homeTopBar.bounds.width/2)-100, height: homeTopBar.bounds.height)
        homeDate_Month.frame = CGRect(x: 76, y: homeTopBar.bounds.minY+10, width: (homeTopBar.bounds.width/2)-80, height: homeTopBar.bounds.height)
    }
    
    func updateHomeViewDate(dateToDisplay: Date) {
        let today = dateToDisplay
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
        
        
        homeDate_Day.font =  setFont(fontSize: 58, fontweight: .medium, fontDesign: .rounded)
        homeDate_WeekDay.font =  setFont(fontSize: 26, fontweight: .thin, fontDesign: .rounded)
        homeDate_Month.font =  setFont(fontSize: 26, fontweight: .regular, fontDesign: .rounded)
        
        homeDate_Day.textAlignment = .left
        homeDate_WeekDay.textAlignment = .left
        homeDate_Month.textAlignment = .left
        
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
    
    //----------------------- *************************** -----------------------
    //MARK:-                         TOP SEPERATOR
    //                               sub:homeTopBar
    //----------------------- *************************** -----------------------
    func setupTopSeperator() {
        
        seperatorTopLineView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2, y: backdropNochImageView.bounds.height + 10, width: 1.0, height: homeTopBar.bounds.height/2))
        seperatorTopLineView.layer.borderWidth = 1.0
        seperatorTopLineView.layer.borderColor = UIColor.gray.cgColor
        homeTopBar.addSubview(seperatorTopLineView)
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    SETUP CALENDAR BUTTON
    //                          sub:backdrop view
    //----------------------- *************************** -----------------------
    func setupCalButton()  {
        revealCalAtHomeButton.backgroundColor = .clear
        revealCalAtHomeButton.frame = CGRect(x: 0 , y: UIScreen.main.bounds.minY+40, width: (UIScreen.main.bounds.width/2), height: homeTopBar.bounds.height/2 + 30 )
        let CalButtonRippleDelegate = DateViewRippleDelegate()
        let calButtonRippleController = MDCRippleTouchController(view: revealCalAtHomeButton)
        calButtonRippleController.delegate = CalButtonRippleDelegate
        //        homeTopBar.addSubview(revealCalAtHomeButton)
        view.addSubview(revealCalAtHomeButton)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                     CHARTS BUTTON
    //----------------------- *************************** -----------------------
    
    func setupChartButton()  {
        revealChartsAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.width/2) , y: UIScreen.main.bounds.minY+40, width: (UIScreen.main.bounds.width/2), height: homeTopBar.bounds.height/2 + 30 )
        revealChartsAtHomeButton.backgroundColor = .clear
        let ChartsButtonRippleDelegate = TinyPieChartRippleDelegate()
        let chartsButtonRippleController = MDCRippleTouchController(view: revealChartsAtHomeButton)
        chartsButtonRippleController.delegate = ChartsButtonRippleDelegate
        view.addSubview(revealChartsAtHomeButton)
        //        homeTopBar.addSubview(revealChartsAtHomeButton)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                     ACTION: SHOW CALENDAR
    //----------------------- *************************** -----------------------
    @objc func toggleBackdrop() {
        let duration: TimeInterval = 1.2
        let delay:    TimeInterval = 0.2
        UIView.animate(
          withDuration: duration,
          delay: delay,
          usingSpringWithDamping: 0.5,
          initialSpringVelocity: 2,
          options: .curveLinear
        ) {
          if !self.isBackdropRevealed {
            // slide down by revealDistance
            self.foredropContainer.center.y += self.revealDistance
          } else {
            // restore original
            self.foredropContainer.center.y = self.originalForedropCenterY
          }
        } completion: { _ in
          // toggle state
          self.isBackdropRevealed.toggle()
          // chart shows only when revealed
          self.lineChartView.isHidden = !self.isBackdropRevealed
          // refresh table
          self.tableView.reloadData()
        }
    }

    @objc func showChartsHHomeButton_Action() { }
    @objc func showCalMoreButtonnAction() { }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    setup line chart
    //----------------------- *************************** -----------------------
    func setupLineChartView() {
        
        backdropContainer.addSubview(lineChartView)
        lineChartView.centerInSuperview()
        lineChartView.edges(to: backdropBackgroundImageView, insets: TinyEdgeInsets(top: 2*headerEndY, left: 0, bottom: UIScreen.main.bounds.height/2.5, right: 0))
        //lineChartView.edges(to: backdropBackgroundImageView, insets: TinyEdgeInsets(top: headerEndY, left: 0, bottom: UIScreen.main.bounds.height/2.5, right: 0))
        
    }
    
    @objc func hideChartsAndCalendar() {
        let delay: TimeInterval    = 0.2
        let duration: TimeInterval = 1.2

        UIView.animate(
          withDuration: duration,
          delay: delay,
          usingSpringWithDamping: 0.5,
          initialSpringVelocity: 2,
          options: .curveLinear
        ) {
          self.foredropContainer.center.y = self.originalForedropCenterY
        } completion: { _ in
          self.calendar.isHidden      = true
          self.lineChartView.isHidden = true
          self.isCalDown    = false
          self.isChartsDown = false
          self.tableView.reloadData()
        }
    }

}
