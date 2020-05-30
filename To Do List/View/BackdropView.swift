//
//  BackdropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 30/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import MaterialComponents.MaterialRipple
import UIKit


extension ViewController {
    
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
    //                          sub:homeTopBar
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
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(calendar)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_toHideCal(view: self.tableView)
            }) { (_) in
                
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_toHideCal(view: self.backdropForeImageView)
            }) { (_) in
                
            }
            
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
            
            print("Cal ELSE !")
            print("cal isCalDown: \(isCalDown)")
            print("cal isChartsDown: \(isChartsDown)")
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(calendar)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealJustCal(view: self.tableView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealJustCal(view: self.backdropForeImageView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.bringSubviewToFront(self.bottomAppBar)
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
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(lineChartView)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealCharts(view: self.tableView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealCharts(view: self.backdropForeImageView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.bringSubviewToFront(self.bottomAppBar)
            self.lineChartView.isHidden = false
            self.animateLineChart(chartView: self.lineChartView)
            
            
            //            tableView.reloadData()
            
            
            //-------
            
            
        } else if (!isChartsDown && isCalDown){ //charts hidden & cal shown
            //            print("Charts + CAL")
            
            print("ShowChartsButton: backdrop is DOWN; + CAL is SHOWING; pushing down FURTHER to show charts")
            
            print("charts: Case BLUE")
            //                        print("***************** Charts are hidden; foredrop ginng DOWN; reveal charts")
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(lineChartView)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealChartsKeepCal(view: self.tableView)
            }) { (_) in
                
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealChartsKeepCal(view: self.backdropForeImageView)
            }) { (_) in
                
            }
            
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
            self.view.bringSubviewToFront(self.bottomAppBar)
            
            
        } else if (isChartsDown && !isCalDown) {//pull it back up // charts shown + cal hidden
            print("charts: Case YELLOW")
            print("ShowChartsButton: backdrop is DOWN; + CAL is HIDDEN; pushing down to show charts")
            
            //                        print("***************** Charts are hidden; foredrop ginng DOWN; reveal charts")
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(lineChartView)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideCharts(view: self.tableView)
            }) { (_) in
                
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideCharts(view: self.backdropForeImageView)
            }) { (_) in
                
            }
            
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
            self.view.bringSubviewToFront(self.bottomAppBar)
        }
            
        else if (isChartsDown && isCalDown) { //pull back to hide charts --> keep showing cal
            print("charts: Case GREEN")
            print("charts: charts & cal are shown; --> hiding charts")
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(lineChartView)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideChartsKeepCal(view: self.tableView)
            }) { (_) in
                
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideChartsKeepCal(view: self.backdropForeImageView)
            }) { (_) in
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
                
                
                
                if (self.isChartsDown) { //todo replace with addtarget observer on foredropimagview
                    
                    print("KEEP SHWING CHARTS")
                    self.lineChartView.isHidden = false
                    
                    //                    self.calendar.isHidden
                    
                    self.isChartsDown = true
                } else {
                    print("backdrop is up; HIDE CHARTS")
                    self.lineChartView.isHidden = true
                    self.calendar.isHidden = true
                    self.isCalDown = false
                    self.isChartsDown = false
                }
                
            }
            self.view.bringSubviewToFront(self.bottomAppBar)
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
    
}
