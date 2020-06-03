//
//  BackdropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 30/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import TinyConstraints
import FSCalendar
import MaterialComponents.MaterialRipple
import UIKit


extension ViewController {
    
    func setupBackdrop() {
        
        backdropContainer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//         CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        
        headerEndY = 128
        setupBackdropBackground()
        addTinyChartToBackdrop()
        setupBackdropNotch()
        setHomeViewDate()
        setupLineChartView()
        setLineChartData()
        lineChartView.isHidden = true //remove this from here hadle elsewhere in a fuc that hides all
        // cal
        setupCal()


//        backdropContainer.addSubview(calendar)
        view.addSubview(calendar)
        
        
        
        calendar.isHidden = true //hidden by default //remove this from here hadle elsewhere in a fuc that hides all
     
        setupCalButton()
        setupChartButton()
        setupTopSeperator()
        
        self.setupPieChartView(pieChartView: tinyPieChartView)
        
        updateTinyPieChartData()
        
        tinyPieChartView.delegate = self
        
        
        
        // entry label styling
        tinyPieChartView.entryLabelColor = .clear
        tinyPieChartView.entryLabelFont = .systemFont(ofSize: 12, weight: .bold)
        
        
        tinyPieChartView.animate(xAxisDuration: 1.8, easingOption: .easeOutBack)
        
        backdropContainer.bringSubviewToFront(calendar)
        //call private methods to setup
        //background view
        //home date
        //top sperator
        //cal & charts buttons
        
        
    }
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 1: SETUP BACKGROUND
    //----------------------- *************************** -----------------------
    
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
        
        //        homeTopBar.addSubview(scoreCounter)
        
        //        view.addSubview(backdropBackgroundImageView)
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
        backdropNochImageView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40)
        backdropNochImageView.backgroundColor = todoColors.primaryColorDarker
        
        backdropContainer.addSubview(backdropNochImageView)
    }
    
    func addTinyChartToBackdrop() {
        tinyPieChartView.frame = CGRect(x: (UIScreen.main.bounds.width)-(homeTopBar.bounds.height+15), y: 15, width: (homeTopBar.bounds.height)+45, height: (homeTopBar.bounds.height)+45)
        view.addSubview(tinyPieChartView)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    SETUP HOME DATE VIEW
    //                          sub:homeTopBar
    //----------------------- *************************** -----------------------
    func setHomeViewDate() {
        let today = dateForTheView
        if("\(today.day)".count < 2) {
            homeDate_Day.text = "0\(today.day)"
        } else {
            homeDate_Day.text = "\(today.day)"
        }
        homeDate_WeekDay.text = getWeekday(date: today)
        homeDate_Month.text = getMonth(date: today)
        
        
        homeDate_Day.numberOfLines = 1
        homeDate_WeekDay.numberOfLines = 1
        homeDate_Month.numberOfLines = 1
        
        homeDate_Day.textColor = .systemGray6
        homeDate_WeekDay.textColor = .systemGray6
        homeDate_Month.textColor = .systemGray6
        
        homeDate_Day.font =  setFont(fontSize: 52, fontweight: .medium, fontDesign: .rounded)
        homeDate_WeekDay.font =  setFont(fontSize: 24, fontweight: .thin, fontDesign: .rounded)
        homeDate_Month.font =  setFont(fontSize: 24, fontweight: .regular, fontDesign: .rounded)
        
        homeDate_Day.textAlignment = .left
        homeDate_WeekDay.textAlignment = .left
        homeDate_Month.textAlignment = .left
        
        
        homeDate_Day.frame = CGRect(x: 5, y: 18, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        homeDate_WeekDay.frame = CGRect(x: 68, y: homeTopBar.bounds.minY+30, width: (homeTopBar.bounds.width/2)-100, height: homeTopBar.bounds.height)
        homeDate_Month.frame = CGRect(x: 68, y: homeTopBar.bounds.minY+10, width: (homeTopBar.bounds.width/2)-80, height: homeTopBar.bounds.height)
        
        
        homeDate_WeekDay.adjustsFontSizeToFitWidth = true
        homeDate_Month.adjustsFontSizeToFitWidth = true
        
        homeTopBar.addSubview(homeDate_Day)
        homeTopBar.addSubview(homeDate_WeekDay)
        homeTopBar.addSubview(homeDate_Month)
        
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
        revealCalAtHomeButton.addTarget(self, action: #selector(showCalMoreButtonnAction), for: .touchUpInside)
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
        revealChartsAtHomeButton.addTarget(self, action: #selector(showChartsHHomeButton_Action), for: .touchUpInside)
        view.addSubview(revealChartsAtHomeButton)
        //        homeTopBar.addSubview(revealChartsAtHomeButton)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                     ACTION: SHOW CALENDAR
    //----------------------- *************************** -----------------------
    @objc func showCalMoreButtonnAction() {
        let delay: Double = 0.2
        let duration: Double = 1.2
        
        //isChartsDown && !isCalDown
        
        if(isCalDown && !isChartsDown) { //cal is out; it sldes back up
            
            print("***************** Cal is out; foredrop going up")
//            self.view.bringSubviewToFront(self.tableView)
//            self.view.sendSubviewToBack(calendar)
//            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_toHideCal(view: self.foredropContainer)
            }) { (_) in
                
            }
            
//            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
//                self.moveUp_toHideCal(view: self.backdropForeImageView)
//            }) { (_) in
//
//            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
                
                if (self.isCalDown) { //todo replace with addtarget observer on foredropimagview
                    print("KEEP SHWING CAL")
                    self.calendar.isHidden = false
                    self.isCalDown = true
                } else {
                    print("backdrop is up; Hidinng CAL")
                    self.calendar.isHidden = true
                    self.isCalDown = false
                }
            }
            
            print("cal CASE: BLUE")
            self.view.bringSubviewToFront(self.bottomAppBar)
            
        } else if (isCalDown && isChartsDown) { //cal is shown & charts are shown --> hide cal
            
            //            isChartsDown && !isCalDown
            
            print("cal CASE: GREEN")
            print("cal isCalDown: \(isCalDown)")
            print("cal isChartsDown: \(isChartsDown)")
            print("Cal is downn & charts are down !")
            
            self.calendar.isHidden = true
            isCalDown = false
            
        }
        else if (!isCalDown && isChartsDown) { //cal hidden & charts show --> show cal without moving foredrop
            
            //            isChartsDown && !isCalDown
            print("cal CASE: YELLOW")
            
            print("cal isCalDown: \(isCalDown)")
            print("cal isChartsDown: \(isChartsDown)")
            print("Cal is downn & charts are down !")
            
            self.calendar.isHidden = false
            isCalDown = true
            
        }
        else { //cal is covered; reveal it
            
            print("Cal ELSE ! - DROP NOW FOR CAL")
            print("cal isCalDown: \(isCalDown)")
            print("cal isChartsDown: \(isChartsDown)")

            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealJustCal(view: self.foredropContainer)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
//            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
//                self.moveDown_revealJustCal(view: self.backdropForeImageView)
//            }) { (_) in
//                //            self.moveLeft(view: self.black4)
//            }
            
//            self.view.bringSubviewToFront(self.tableView)
//            self.view.bringSubviewToFront(self.bottomAppBar)
            self.backdropContainer.bringSubviewToFront(calendar)
            print("Cal bring to front !")
            self.calendar.isHidden = false
            
            
        }
        tableView.reloadData()
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                     ACTION: SHOW CHARTS
    //----------------------- *************************** -----------------------
    
    @objc func showChartsHHomeButton_Action() {
        
        print("Show CHARTS !!")
        let delay: Double = 0.2
        let duration: Double = 1.2
        
        if (!isChartsDown && !isCalDown) { //if backdrop is up; then push down & show charts
            
            print("charts: Case RED")
            //--------------------
            
            print("ShowChartsButton: backdrop is UP; pushing down to show charts")
            
//            self.view.bringSubviewToFront(self.tableView)
//            self.view.sendSubviewToBack(lineChartView)
//            self.view.sendSubviewToBack(backdropBackgroundImageView)
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
//                self.moveDown_revealCharts(view: self.tableView)
                self.moveDown_revealCharts(view: self.foredropContainer)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
//            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
//                self.moveDown_revealCharts(view: self.backdropForeImageView)
//            }) { (_) in
//                //            self.moveLeft(view: self.black4)
//            }
            
//            self.view.bringSubviewToFront(self.tableView)
//            self.view.bringSubviewToFront(self.bottomAppBar)
            self.lineChartView.isHidden = false
            self.animateLineChart(chartView: self.lineChartView)
            
            
            //            tableView.reloadData()
            
            
            //-------
            
            
        } else if (!isChartsDown && isCalDown){ //charts hidden & cal shown
            //            print("Charts + CAL")
            
            print("ShowChartsButton: backdrop is DOWN; + CAL is SHOWING; pushing down FURTHER to show charts")
            
            print("charts: Case BLUE")
            //                        print("***************** Charts are hidden; foredrop ginng DOWN; reveal charts")
//            self.view.bringSubviewToFront(self.tableView)
//            self.view.sendSubviewToBack(lineChartView)
//            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealChartsKeepCal(view: self.foredropContainer)
            }) { (_) in
                
            }
//
//            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
//                self.moveDown_revealChartsKeepCal(view: self.backdropForeImageView)
//            }) { (_) in
//
//            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
                
                if (self.isChartsDown) { //todo replace with addtarget observer on foredropimagview
                    
                    print("KEEP SHOWING CHARTS")
                    self.lineChartView.isHidden = false
                    self.isChartsDown = true
                    self.animateLineChart(chartView: self.lineChartView)
                    
                } else {
                    print("backdrop is up; HIDE CHARTS")
                    self.lineChartView.isHidden = true
                }
            }
//            self.view.bringSubviewToFront(self.bottomAppBar)
            
            
        } else if (isChartsDown && !isCalDown) {//pull it back up // charts shown + cal hidden
            print("charts: Case YELLOW")
            print("ShowChartsButton: backdrop is DOWN; + CAL is HIDDEN; pushing down to show charts")
            
            //                        print("***************** Charts are hidden; foredrop ginng DOWN; reveal charts")
//            self.view.bringSubviewToFront(self.tableView)
//            self.view.sendSubviewToBack(lineChartView)
//            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideCharts(view: self.foredropContainer)
            }) { (_) in
                
            }
            
//            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
//                self.moveUp_hideCharts(view: self.backdropForeImageView)
//            }) { (_) in
//
//            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
                
                if (self.isChartsDown) { //todo replace with addtarget observer on foredropimagview
                    
                    print("KEEP SHWING CHARTS")
                    self.lineChartView.isHidden = false
                    self.isChartsDown = true
                } else {
                    print("backdrop is up; HIDE CHARTS")
                    self.lineChartView.isHidden = true
                    self.isChartsDown = false
                }
                
            }
//            self.view.bringSubviewToFront(self.bottomAppBar)
        }
            
        else if (isChartsDown && isCalDown) { //pull back to hide charts --> keep showing cal
            print("charts: Case GREEN")
            print("charts: charts & cal are shown; --> hiding charts")
//            self.view.bringSubviewToFront(self.tableView)
//            self.view.sendSubviewToBack(lineChartView)
//            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideChartsKeepCal(view: self.foredropContainer)
            }) { (_) in
                
            }
            
//            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
//                self.moveUp_hideChartsKeepCal(view: self.backdropForeImageView)
//            }) { (_) in
//                
//            }
            
//            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
               self.isCalDown = false
                
                
             
                
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                    if (self.isChartsDown) { //todo replace with addtarget observer on foredropimagview
                                     
                                     print("KEEP SHWING CHARTS")
                                     self.lineChartView.isHidden = false
                                     
                                     //                    self.calendar.isHidden
                                     
                                     self.isChartsDown = true
                                 } else {
                                     print("backdrop is up; HIDE CHARTS")
                                     self.lineChartView.isHidden = true
                                     self.calendar.isHidden = true
                                  
                                     self.isChartsDown = false
                                 }
                    
            }
//            self.view.bringSubviewToFront(self.bottomAppBar)
        }
        else {
            print("ERROR LAYOUT - SHOW CHARTS")
        }
        
        tableView.reloadData()
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                    get name of the month
    //----------------------- *************************** -----------------------
    func getMonth(date: Date) -> String {
        
        let dateFormatter_Month = DateFormatter()
        dateFormatter_Month.dateFormat = "LLL" //try MMM
        let nameOfMonth = dateFormatter_Month.string(from: date)
        return nameOfMonth
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    get name of the weekday
    //----------------------- *************************** -----------------------
    func getWeekday(date: Date) -> String {
        
        let dateFormatter_Weekday = DateFormatter()
        dateFormatter_Weekday.dateFormat = "EEE"
        let nameOfWeekday = dateFormatter_Weekday.string(from: date)
        return nameOfWeekday
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    setup line chart
    //----------------------- *************************** -----------------------
    func setupLineChartView() {
        
        backdropContainer.addSubview(lineChartView)
        lineChartView.centerInSuperview()
        lineChartView.edges(to: backdropBackgroundImageView, insets: TinyEdgeInsets(top: 2*headerEndY, left: 0, bottom: UIScreen.main.bounds.height/2.5, right: 0))
        
    }
    
}
