//
//  AddTaskCalendarExtention.swift
//  To Do List
//
//  Created by Saransh Sharma on 04/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import FSCalendar
import CoreData  // TODO: Migrate away from NSFetchRequest to use repository pattern

extension AddTaskViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    func calendar(_ calendar: FSCalendar, subtitleFor date: Date) -> String? {
        
        // Get tasks from Core Data directly
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfDay as NSDate, endOfDay as NSDate)
        let allTasks = (try? context?.fetch(request)) ?? []
        
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
    func setupCalAtAddTask() {
        let calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.frame.maxY-6, width: UIScreen.main.bounds.width, height:
                                                    homeTopBar.frame.maxY*3.5))
        calendar.calendarHeaderView.backgroundColor = todoColors.accentPrimaryPressed
        calendar.calendarWeekdayView.backgroundColor = todoColors.accentPrimaryPressed
        calendar.appearance.headerTitleColor = .white
        calendar.appearance.headerTitleFont = UIFont.tasker.font(for: .headline)
        
        //weekday title
        calendar.appearance.weekdayTextColor = .lightGray//.lightGray
        calendar.appearance.weekdayFont = UIFont.tasker.font(for: .callout)
        
        //weekend
        calendar.appearance.titleWeekendColor = todoColors.statusDanger
        
        //date
        calendar.appearance.titleFont = UIFont.tasker.font(for: .body)
        calendar.appearance.titleDefaultColor = .white
        calendar.appearance.caseOptions = .weekdayUsesUpperCase
        
        //selection
        calendar.appearance.selectionColor = todoColors.accentMuted
        calendar.appearance.subtitleDefaultColor = .white
        
        //today
        calendar.appearance.todayColor = todoColors.accentPrimaryPressed
        calendar.appearance.titleTodayColor = todoColors.accentOnPrimary
        calendar.appearance.titleSelectionColor = todoColors.textPrimary
        calendar.appearance.subtitleSelectionColor = todoColors.textSecondary
        calendar.appearance.subtitleFont = UIFont.tasker.font(for: .caption2)
        calendar.appearance.borderSelectionColor = todoColors.accentPrimaryPressed
        
        
        calendar.dataSource = self
        calendar.delegate = self

        self.calendar = calendar
        self.calendar.accessibilityIdentifier = "addTask.dueDatePicker"
        self.calendar.scope = FSCalendarScope.week        
    }
    
    //MARK: Cal changes VIEW + SCORE on date change
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        print("You selected Date: \(date.stringIn(dateStyle: .full, timeStyle: .none))")
        
        dateForAddTaskView = date
        
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        
        
    }
    
    
}
