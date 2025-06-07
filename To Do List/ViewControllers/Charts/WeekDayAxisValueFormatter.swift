//
//  WeekDayAxisValueFormatter.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import Foundation
import DGCharts

/// Custom formatter for displaying weekday labels on chart x-axis
class WeekDayAxisValueFormatter: AxisValueFormatter {
    
    private let weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let index = Int(value)
        
        // Ensure index is within bounds
        guard index >= 0 && index < weekDays.count else {
            return ""
        }
        
        return weekDays[index]
    }
}