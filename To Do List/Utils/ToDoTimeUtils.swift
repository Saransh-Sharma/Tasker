//
//  ToDoTimeUtils.swift
//  To Do List
//
//  Created by Saransh Sharma on 04/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation

class ToDoTimeUtils {
    
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

// MARK: - Calendar Extension
extension Calendar {
    func daysWithSameWeekOfYear(as date: Date) -> [Date] {
        let calendar = Calendar.autoupdatingCurrent
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.year, from: date)
        
        // Find the first day of the week
        guard let firstDayOfWeek = calendar.date(from: DateComponents(weekOfYear: weekOfYear, yearForWeekOfYear: year)) else {
            return []
        }
        
        // Create array of all 7 days in the week
        var days: [Date] = []
        for day in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDayOfWeek) {
                days.append(date)
            }
        }
        
        return days
    }
}

// MARK: - Date Extension
extension Date {
    func onSameDay(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: date)
    }
    
    var hour: Int {
        return Calendar.current.component(.hour, from: self)
    }
}

// MARK: - ToDoTimeUtils Extension
extension ToDoTimeUtils {
    func isNightTime(date: Date) -> Bool {
        // Consider evening/night time to be 8 PM (20:00) or later
        return date.hour >= 20
    }
}
