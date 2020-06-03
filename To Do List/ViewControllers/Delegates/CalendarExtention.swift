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
extension ViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
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
       
       //MARK: Setup calendar appearence
       func setupCal() {
           let calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/2))
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
           calendar.appearance.subtitleFont = setFont(fontSize: 10, fontweight: .regular, fontDesign: .rounded)
           calendar.appearance.borderSelectionColor = todoColors.primaryColorDarker
           
           
           
           calendar.dataSource = self
           calendar.delegate = self
           
           self.calendar = calendar
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
        dateForTheView = date


        updateHomeDate(date: dateForTheView)
        //        (self.calculateTodaysScore()
        self.scoreCounter.text = "\(self.calculateTodaysScore())"

        let scoreNumber = "\(self.calculateTodaysScore())"
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center


        //            let centerText = NSMutableAttributedString(string: "\(scoreNumber)\nscore")
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

        //            centerText.addAttributes([.font : setFont(fontSize: 16, fontweight: .regular, fontDesign: .monospaced),
        //                                      .foregroundColor : UIColor.secondaryLabel], range: NSRange(location: scoreNumber.count+1, length: centerText.length - (scoreNumber.count+1)))
//        self.tinyPieChartView.centerAttributedText = centerText;

        self.tinyPieChartView.centerAttributedText = setTinyPieChartScoreText(pieChartView: self.tinyPieChartView)
        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)

        tableView.reloadData()
        animateTableViewReload()
    }
}
