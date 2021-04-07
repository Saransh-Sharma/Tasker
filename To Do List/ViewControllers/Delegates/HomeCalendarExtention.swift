//
//  CalendarExtention.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import FSCalendar


//----------------------- *************************** -----------------------
//MARK:-                            CALENDAR DELEGATE
//----------------------- *************************** -----------------------

//MARK:- CAL Extention: task count as day subtext
extension HomeViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    func calendar(_ calendar: FSCalendar, subtitleFor date: Date) -> String? {
        
        
        //        let morningTasks: [NTask]
        //                   if(dateForTheView == Date.today()) {
        //                        morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
        //                   } else { //get morning tasks without rollover
        //                        morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
        //                   }
        
        let morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: date)
        let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: date)
        let allTasks = morningTasks+eveningTasks
        
        if(allTasks.count == 0) {
            return "-"
        } else {
            return "\(allTasks.count) tasks"
        }
    }
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                       CALENNDAR:SETUP
    //----------------------- *************************** -----------------------
    
    func setupCalView() {
        calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.frame.maxY-6, width: UIScreen.main.bounds.width, height:
            homeTopBar.frame.maxY*3.5))
    }
    
    
    
    //MARK: Setup calendar appearence
    func setupCalAppearence() {
        //           let calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/2))
        
        //            UIScreen.main.bounds.height/2))
        calendar.calendarHeaderView.backgroundColor = todoColors.primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        calendar.calendarWeekdayView.backgroundColor = todoColors.primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        
        
        calendar.appearance.headerTitleColor = .white
        calendar.appearance.headerTitleFont = setFont(fontSize: 16, fontweight: .light, fontDesign: .default)
        
        
        //weekday title
        calendar.appearance.weekdayTextColor = .lightGray//.lightGray
        calendar.appearance.weekdayFont = setFont(fontSize: 14, fontweight: .light, fontDesign: .rounded)
        
        //weekend
        calendar.appearance.titleWeekendColor = .systemRed
        
        //date
        calendar.appearance.titleFont = setFont(fontSize: 16, fontweight: .regular, fontDesign: .rounded)
        calendar.appearance.titleDefaultColor = .white
        calendar.appearance.caseOptions = .weekdayUsesUpperCase
        
        //selection
        calendar.appearance.selectionColor = todoColors.secondaryAccentColor
        calendar.appearance.subtitleDefaultColor = .white
        
        //today
        calendar.appearance.todayColor = todoColors.primaryColorDarker
        calendar.appearance.titleTodayColor = todoColors.secondaryAccentColor
        calendar.appearance.titleSelectionColor = todoColors.primaryColorDarker
        calendar.appearance.subtitleSelectionColor = todoColors.primaryColorDarker
        calendar.appearance.subtitleFont = setFont(fontSize: 8, fontweight: .regular, fontDesign: .rounded)
        calendar.appearance.borderSelectionColor = todoColors.primaryColorDarker
        
        
        //        calendar.clipsToBounds = true
        
        calendar.dataSource = self
        calendar.delegate = self
        
        //           self.calendar = calendar
        self.calendar.scope = FSCalendarScope.week
        //        calendar.backgroundColor = .white
    }
    
    
    
    
    
    //    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, borderDefaultColorFor date: Date) -> UIColor? {
    //        .blue
    //    }
    //
    //    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, fillDefaultColorFor date: Date) -> UIColor? {
    //        .black
    //    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                            CALENDAR
    //----------------------- *************************** -----------------------
    
    
    //    func calendar(didSelect)
    

    //MARK: Cal changes VIEW + SCORE on date change
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        print("You selected Date: \(date.stringIn(dateStyle: .full, timeStyle: .none))")
      
        
        //        dateToDisplay = date
//        dateForTheView = date
        setDateForViewValue(dateToSetForView: date)
        
        updateViewForHome(viewType: .customDateView, dateForView: date)
        
        
        updateHomeDateLabel(date: dateForTheView)
        self.scoreCounter.text = "\(self.calculateTodaysScore())"
        
        let scoreNumber = "\(self.calculateTodaysScore())"
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        
        let centerText = NSMutableAttributedString(string: "\(scoreNumber)")
        if scoreNumber.count == 1 {
            centerText.setAttributes([.font : setFont(fontSize: 45, fontweight: .medium, fontDesign: .rounded),
                                      .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
        } else if scoreNumber.count == 2 {
            centerText.setAttributes([.font : setFont(fontSize: 45, fontweight: .medium, fontDesign: .rounded),
                                      .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
        } else {
            centerText.setAttributes([.font : setFont(fontSize: 28, fontweight: .medium, fontDesign: .rounded),
                                      .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
            
        }
        
        
        reloadTinyPicChartWithAnimation()
        reloadToDoListWithAnimation()
      
    }
    
 
    
    
}
