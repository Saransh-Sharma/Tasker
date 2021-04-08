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
    //MARK:-                       CALENDAR:SETUP
    //----------------------- *************************** -----------------------
    
    func setupCalView() {
        calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.frame.maxY-6, width: UIScreen.main.bounds.width, height:
            homeTopBar.frame.maxY*3.5))
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                       CALENDAR:APPEARENCE
    //----------------------- *************************** -----------------------
    func setupCalAppearence() {

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
        
        
        calendar.dataSource = self
        calendar.delegate = self
        
        self.calendar.scope = FSCalendarScope.week
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                            CALENDAR: didSelect
    //----------------------- *************************** -----------------------
    
    //MARK: Cal changes VIEW + SCORE on date change
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        print("You selected Date from Cal: \(date.stringIn(dateStyle: .full, timeStyle: .none))")
        setDateForViewValue(dateToSetForView: date)
        
        if (date == Date.today()) {
            updateViewForHome(viewType: .todayHomeView)
        } else {
            updateViewForHome(viewType: .customDateView, dateForView: date)
        }
        
        
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
