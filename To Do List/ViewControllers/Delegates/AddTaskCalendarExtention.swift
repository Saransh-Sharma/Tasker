//
//  AddTaskCalendarExtention.swift
//  To Do List
//
//  Created by Saransh Sharma on 04/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import FSCalendar

extension AddTaskViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {

    
    //----------------------- *************************** -----------------------
        //MARK:-                       CALENNDAR:SETUP
        //----------------------- *************************** -----------------------
        
        //MARK: Setup calendar appearence
        func setupCalAtAddTask() {
            let calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/2))
            calendar.calendarHeaderView.backgroundColor = todoColors.primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
            calendar.calendarWeekdayView.backgroundColor = todoColors.primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
            
            
            calendar.appearance.headerTitleColor = .white
            calendar.appearance.headerTitleFont = todoFont.setFont(fontSize: 16, fontweight: .light, fontDesign: .default)
            
            
            //weekday title
            calendar.appearance.weekdayTextColor = .lightGray//.lightGray
            calendar.appearance.weekdayFont = todoFont.setFont(fontSize: 14, fontweight: .light, fontDesign: .rounded)
            
            //weekend
            calendar.appearance.titleWeekendColor = .systemRed
            
            //date
            calendar.appearance.titleFont = todoFont.setFont(fontSize: 16, fontweight: .regular, fontDesign: .rounded)
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
            calendar.appearance.subtitleFont = todoFont.setFont(fontSize: 10, fontweight: .regular, fontDesign: .rounded)
            calendar.appearance.borderSelectionColor = todoColors.primaryColorDarker
            
            
            
            calendar.dataSource = self
            calendar.delegate = self
            
            self.calendar = calendar
            self.calendar.scope = FSCalendarScope.week
            //        calendar.backgroundColor = .white
        }
     
    
}
