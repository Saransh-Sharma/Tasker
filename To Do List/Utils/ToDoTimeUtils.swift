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
