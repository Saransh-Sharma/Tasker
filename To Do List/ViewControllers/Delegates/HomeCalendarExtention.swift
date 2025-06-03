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
    
    func calendar(_ calendarView: FSCalendar, subtitleFor date: Date) -> String? {
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
        // Set appropriate height for week view - approximately 100 points is sufficient for a single week
        let calendarHeight: CGFloat = 100
        self.calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.frame.maxY-6, width: UIScreen.main.bounds.width, height: calendarHeight))
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                       CALENDAR:APPEARENCE
    //----------------------- *************************** -----------------------
    func setupCalAppearence() {
        
//        self.calendar.calendarHeaderView.backgroundColor = todoColors.primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        self.calendar.calendarHeaderView.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.5)
        self.calendar.calendarHeaderView.backgroundColor?.setFill()
        //UIColor.lightGray.withAlphaComponent(0.1)
        self.calendar.calendarWeekdayView.backgroundColor = todoColors.primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        
        
        
        self.calendar.appearance.headerTitleColor = .white
        self.calendar.appearance.headerTitleFont = setFont(fontSize: 16, fontweight: .light, fontDesign: .default) as UIFont
        
        
        //weekday title
        self.calendar.appearance.weekdayTextColor = .lightGray//.lightGray
        self.calendar.appearance.weekdayFont = setFont(fontSize: 14, fontweight: .light, fontDesign: .rounded) as UIFont
        
        //weekend
        self.calendar.appearance.titleWeekendColor = .systemRed
        
        //date
        self.calendar.appearance.titleFont = setFont(fontSize: 16, fontweight: .regular, fontDesign: .rounded) as UIFont
        self.calendar.appearance.titleDefaultColor = .white
        self.calendar.appearance.caseOptions = .weekdayUsesUpperCase
        
        //selection
        self.calendar.appearance.selectionColor = todoColors.secondaryAccentColor
        self.calendar.appearance.subtitleDefaultColor = .white
        
        self.calendar.firstWeekday = 2
        
        //today
        self.calendar.appearance.todayColor = todoColors.primaryColorDarker
        self.calendar.appearance.titleTodayColor = todoColors.secondaryAccentColor
        self.calendar.appearance.titleSelectionColor = todoColors.primaryColorDarker
        self.calendar.appearance.subtitleSelectionColor = todoColors.primaryColorDarker
        self.calendar.appearance.subtitleFont = setFont(fontSize: 8, fontweight: .regular, fontDesign: .rounded) as UIFont
        self.calendar.appearance.borderSelectionColor = todoColors.primaryColorDarker
        
        
        self.calendar.dataSource = self
        self.calendar.delegate = self
        
        self.calendar.scope = FSCalendarScope.week
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                            CALENDAR: didSelect
    //----------------------- *************************** -----------------------
    
    //MARK: Cal changes VIEW + SCORE on date change
    func calendar(_ calendarView: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        print("You selected Date from Cal: \(date.stringIn(dateStyle: .full, timeStyle: .none))")
        setDateForViewValue(dateToSetForView: date)
        
        if (date == Date.today()) {
            updateViewForHome(viewType: .todayHomeView)
        } else {
            updateViewForHome(viewType: .customDateView, dateForView: date)
        }
        
        
        self.updateHomeDateLabel(date: dateForTheView)
        self.scoreCounter.text = "\(self.calculateTodaysScore())"
        
        let scoreNumber = "\(self.calculateTodaysScore())"
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        
        let centerText = NSMutableAttributedString(string: "\(scoreNumber)")
        if scoreNumber.count == 1 {
            centerText.setAttributes([NSAttributedString.Key.font : setFont(fontSize: 45, fontweight: .medium, fontDesign: .rounded) as UIFont,
                                      NSAttributedString.Key.paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
        } else if scoreNumber.count == 2 {
            centerText.setAttributes([NSAttributedString.Key.font : setFont(fontSize: 45, fontweight: .medium, fontDesign: .rounded) as UIFont,
                                      NSAttributedString.Key.paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
        } else {
            centerText.setAttributes([NSAttributedString.Key.font : setFont(fontSize: 28, fontweight: .medium, fontDesign: .rounded) as UIFont,
                                      NSAttributedString.Key.paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
            
        }
        
        
        reloadTinyPicChartWithAnimation()
        reloadToDoListWithAnimation()
        
    }
    
    
    
    
}
