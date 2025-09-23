//
//  ChartDataService.swift
//  To Do List
//
//  Created by Assistant on Chart Data Service Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import Foundation
import CoreData
import DGCharts
import UIKit

// MARK: - Chart Data Service
class ChartDataService {
    // Remove singleton, use dependency injection
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
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
    
    /// Calculates the total score for a specific calendar day based **solely** on
    /// tasks that were *completed* on that day (regardless of their due date).
    /// - Parameter date: The day to calculate the score for (00:00 – 24:00)
    /// - Returns: The summed score of all tasks completed on that day.
    func calculateScoreForDate(date: Date) -> Int {
        var score = 0
        // Formatter reused for multiple debug prints
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Fetch **all** tasks once – cheaper than multiple Core-Data fetches during week generation
        // Fetch all tasks using Core Data directly
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let allTasks = (try? context.fetch(request)) ?? []
        
        #if DEBUG
        print("────────────────────────────────────────────────────────")
        print("🕵️‍♂️ [ChartDataService] Debug Score Calculation")
        let rangeFormatter = DateFormatter()
        rangeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("Date being evaluated: \(dayFormatter.string(from: date))")
        print(" → startOfDay: \(rangeFormatter.string(from: startOfDay))")
        print(" → endOfDay  : \(rangeFormatter.string(from: endOfDay))")
        print("Fetched ALL tasks count: \(allTasks.count)")
        #endif
        
        // Filter only the tasks that were completed on the specific day
        let tasksCompletedOnDate = allTasks.filter { task in
            guard task.isComplete, let completedDate = task.dateCompleted as Date? else { return false }
            return completedDate >= startOfDay && completedDate < endOfDay
        }
        
        #if DEBUG
        print("Tasks completed on this date (after filtering): \(tasksCompletedOnDate.count)")
        // Show up to first 10 tasks with key metadata for deeper inspection
        for (idx, task) in allTasks.prefix(20).enumerated() {
            let cd = (task.dateCompleted as Date?)?.toString(format: "yyyy-MM-dd HH:mm:ss") ?? "nil"
            let dd = (task.dueDate as Date?)?.toString(format: "yyyy-MM-dd") ?? "nil"
            print("   [AllTasks] #\(idx+1) \(task.name ?? "Unnamed") | complete: \(task.isComplete) | dateCompleted: \(cd) | dueDate: \(dd)")
        }
        #endif
        
        // --- Debug logging (can be removed in production) ---
        #if DEBUG
        print("\n🔍 [ChartDataService] Score calc for \(dayFormatter.string(from: date)) – completed tasks: \(tasksCompletedOnDate.count)")
        #endif
        print("📅 [ChartDataService] Tasks actually completed on \(dayFormatter.string(from: date)): \(tasksCompletedOnDate.count)")
        
        for (index, task) in tasksCompletedOnDate.enumerated() {
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            let completedDateStr = task.dateCompleted != nil ? dayFormatter.string(from: task.dateCompleted! as Date) : "nil"
            let dueDateStr = task.dueDate != nil ? dayFormatter.string(from: task.dueDate! as Date) : "nil"
            
            print("📝 [ChartDataService] Task \(index + 1): '\(task.name ?? "Unknown")'")
            print("   - Complete: \(task.isComplete), Priority: \(task.taskPriority), Score: \(taskScore)")
            print("   - Due Date: \(dueDateStr), Completed Date: \(completedDateStr)")
            score += taskScore
            #if DEBUG
            print("   ✅ Adding \(taskScore) points (task is complete on this date)")
            #endif
        }
        
        #if DEBUG
        print("   📊 Final score: \(score) points")
        #endif
        return score
    }
    
    func calculateScoreForProject(project: String) -> Int {
        var score = 0
        
        // Only consider tasks for the specified project
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(format: "project == %@", project)
        let projectTasks = (try? context.fetch(request)) ?? []
        
        let morningTasks = projectTasks.filter { $0.taskType == 1 } // TaskType.morning.rawValue
        let eveningTasks = projectTasks.filter { $0.taskType == 2 } // TaskType.evening.rawValue
        
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