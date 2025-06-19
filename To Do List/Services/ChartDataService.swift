//
//  ChartDataService.swift
//  To Do List
//
//  Created by Assistant on Chart Data Service Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import Foundation
import DGCharts
import UIKit

// MARK: - Chart Data Service
class ChartDataService {
    static let shared = ChartDataService()
    
    private init() {}
    
    // MARK: - Line Chart Data Generation
    
    func generateLineChartData(for referenceDate: Date? = nil) -> [ChartDataEntry] {
        var yValues: [ChartDataEntry] = []
        
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1 // Start on Sunday (1 for Sunday, 2 for Monday)
        
        // Get current week dates based on calendar's current page
        let currentReferenceDate = referenceDate ?? Date.today()
        let week = calendar.daysWithSameWeekOfYear(as: currentReferenceDate)
        let today = Date.today()
        
        // Log weekly chart generation
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        print("📊 Generating chart data for week of \(dateFormatter.string(from: currentReferenceDate))")
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM dd"
        
        // Generate chart data points for the week (Sunday to Saturday)
        for (index, day) in week.enumerated() {
            let score: Int
            
            // Enhanced future date handling
            if day > today {
                // For future dates, show 0 but with special styling indication
                score = 0
                print("   🔮 Future date \(dayFormatter.string(from: day)): Setting score to 0")
            } else {
                // For past and current dates, calculate actual score
                print("   📅 Processing \(dayFormatter.string(from: day))...")
                score = calculateScoreForDate(date: day)
            }
            
            // Log each day's score
            let dayName = dayFormatter.string(from: day)
            let status = day > today ? "(Future)" : day.onSameDay(as: today) ? "(Today)" : "(Past)"
            print("   • \(dayName): \(score) points \(status)")
            
            // Ensure score is valid and not NaN or infinite
            let validScore = max(0, score) // Ensure non-negative
            let yValue = Double(validScore)
            
            // Additional safety check for NaN or infinite values
            let safeYValue = yValue.isNaN || yValue.isInfinite ? 0.0 : yValue
            
            let dataEntry = ChartDataEntry(x: Double(index), y: safeYValue)
            
            // Add metadata for future date styling (if needed)
            if day > today {
                dataEntry.data = ["isFuture": true]
            }
            
            yValues.append(dataEntry)
        }
        
        // Log weekly total
        let weeklyTotal = yValues.reduce(0) { $0 + Int($1.y) }
        print("   📈 Weekly Total: \(weeklyTotal) points")
        
        return yValues
    }
    
    func generateSampleData() -> [ChartDataEntry] {
        let sampleValues = [15.0, 25.0, 35.0, 45.0, 30.0, 50.0, 40.0]
        return sampleValues.enumerated().map { index, value in
            // Ensure value is valid and not NaN or infinite
            let safeValue = value.isNaN || value.isInfinite ? 0.0 : value
            return ChartDataEntry(x: Double(index), y: safeValue)
        }
    }
    
    // MARK: - Score Calculation
    
    func calculateScoreForDate(date: Date) -> Int {
        var score = 0
        let allTasks = TaskManager.sharedInstance.getAllTasksForDate(date: date)
        
        // Enhanced debug logging
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        print("\n🔍 [ChartDataService] calculateScoreForDate for \(dayFormatter.string(from: date)): Found \(allTasks.count) tasks")
        
        // Debug: Check all tasks in the database
        let allTasksInDB = TaskManager.sharedInstance.getAllTasks
        print("📊 [ChartDataService] Total tasks in database: \(allTasksInDB.count)")
        
        // Debug: Show completed tasks for this date
        let completedTasksForDate = allTasks.filter { $0.isComplete }
        print("✅ [ChartDataService] Completed tasks for this date: \(completedTasksForDate.count)")
        
        // Debug: Show tasks completed on this specific date
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let tasksCompletedOnDate = allTasksInDB.filter { task in
            guard let completedDate = task.dateCompleted as Date? else { return false }
            return completedDate >= startOfDay && completedDate < endOfDay
        }
        print("📅 [ChartDataService] Tasks actually completed on \(dayFormatter.string(from: date)): \(tasksCompletedOnDate.count)")
        
        for (index, task) in allTasks.enumerated() {
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            let completedDateStr = task.dateCompleted != nil ? dateFormatter.string(from: task.dateCompleted! as Date) : "nil"
            let dueDateStr = task.dueDate != nil ? dayFormatter.string(from: task.dueDate! as Date) : "nil"
            
            print("📝 [ChartDataService] Task \(index + 1): '\(task.name ?? "Unknown")'")
            print("   - Complete: \(task.isComplete), Priority: \(task.priority), Score: \(taskScore)")
            print("   - Due Date: \(dueDateStr), Completed Date: \(completedDateStr)")
            
            if task.isComplete {
                score += taskScore
                print("   ✅ Adding \(taskScore) to total score")
            } else {
                print("   ❌ Task not complete, not adding to score")
            }
        }
        
        print("   📊 Final score for \(dateFormatter.string(from: date)): \(score) points")
        return score
    }
    
    func calculateScoreForProject(project: String) -> Int {
        var score = 0
        
        // Only consider tasks for the specified project
        let morningTasks = TaskManager.sharedInstance.getMorningTasksForProject(projectName: project)
        let eveningTasks = TaskManager.sharedInstance.getEveningTasksForProject(projectName: project)
        
        for task in morningTasks {
            if task.isComplete {
                score = score + task.getTaskScore(task: task)
            }
        }
        
        for task in eveningTasks {
            if task.isComplete {
                score = score + task.getTaskScore(task: task)
            }
        }
        
        return score
    }
    
    // MARK: - Chart Configuration Helpers
    
    func calculateDynamicMaximum(for dataEntries: [ChartDataEntry]) -> Double {
        let maxScore = dataEntries.map { $0.y }.max() ?? 0
        return max(maxScore * 1.2, 10) // Ensure minimum scale of 10
    }
    
    func createLineChartDataSet(with entries: [ChartDataEntry], colors: ToDoColors) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: entries, label: "Daily Score")
        
        // Enhanced visual configuration
        dataSet.mode = .linear
        dataSet.drawCirclesEnabled = true
        dataSet.lineWidth = 3.5
        dataSet.circleRadius = 6
        dataSet.setCircleColor(colors.secondaryAccentColor)
        dataSet.setColor(colors.primaryColor)
        dataSet.drawCircleHoleEnabled = true
        dataSet.circleHoleRadius = 3
        dataSet.circleHoleColor = UIColor.systemBackground
        dataSet.valueFont = .systemFont(ofSize: 10, weight: .medium)
        dataSet.valueTextColor = colors.primaryTextColor
        
        // Enhanced gradient fill with better visual appeal
        let gradientColors = [
            colors.secondaryAccentColor.withAlphaComponent(0.5).cgColor,
            colors.secondaryAccentColor.withAlphaComponent(0.25).cgColor,
            colors.secondaryAccentColor.withAlphaComponent(0.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: [0.0, 0.5, 1.0])!
        
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.5
        
        // Enhanced line style for better visibility
        dataSet.lineDashLengths = nil // Solid line for better readability
        dataSet.highlightEnabled = true
        dataSet.highlightColor = colors.secondaryAccentColor
        dataSet.highlightLineWidth = 2
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.drawVerticalHighlightIndicatorEnabled = true
        
        return dataSet
    }
}