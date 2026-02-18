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

extension AddTaskViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    func calendar(_ calendar: FSCalendar, subtitleFor date: Date) -> String? {
        let dayKey = Calendar.current.startOfDay(for: date)
        let count = calendarTaskCountByDay[dayKey, default: 0]
        if count == 0 {
            return "-"
        } else {
            return "\(count) tasks"
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
        preloadCalendarTaskCounts()
    }
    
    //MARK: Cal changes VIEW + SCORE on date change
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        logDebug("You selected Date: \(date.formatted(date: .complete, time: .omitted))")
        
        dateForAddTaskView = date
        metadataRow.updateDate(date)

        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        
        
    }

    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        preloadCalendarTaskCounts(anchorDate: calendar.currentPage)
    }

    private func preloadCalendarTaskCounts(anchorDate: Date = Date()) {
        guard let viewModel else {
            return
        }
        let cal = Calendar.current
        guard
            let windowStart = cal.date(byAdding: .day, value: -30, to: anchorDate),
            let windowEnd = cal.date(byAdding: .day, value: 60, to: anchorDate)
        else {
            return
        }

        viewModel.loadCalendarTaskCounts(windowStart: windowStart, windowEnd: windowEnd) { [weak self] counts in
            guard let self else { return }
            self.calendarTaskCountByDay = counts
            self.calendar.reloadData()
        }
    }
}
