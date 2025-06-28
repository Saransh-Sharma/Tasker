//
//  HomeViewController+Charts.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import SwiftUI
import DGCharts

extension HomeViewController {
    
    // MARK: - Chart Setup and Data
    
    func setupCharts() {
        // LineChart setup - Based on LineChart1ViewController
        lineChartView.backgroundColor = todoColors.backgroundColor
        lineChartView.legend.form = .line
        lineChartView.rightAxis.enabled = false
        
        // Add card view styling
        lineChartView.layer.cornerRadius = 12
        lineChartView.layer.shadowColor = todoColors.primaryColorDarker.cgColor
        lineChartView.layer.shadowOpacity = 0.1
        lineChartView.layer.shadowOffset = CGSize(width: 0, height: 2)
        lineChartView.layer.shadowRadius = 8
        lineChartView.layer.masksToBounds = false
        
        // Enable chart description and interactions
        lineChartView.chartDescription.enabled = false
        lineChartView.dragEnabled = true
        lineChartView.setScaleEnabled(true)
        lineChartView.pinchZoomEnabled = true
        
        let leftAxis = lineChartView.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.axisMaximum = 100
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridLineDashLengths = [5, 5]
        leftAxis.drawZeroLineEnabled = false
        leftAxis.drawAxisLineEnabled = false
        leftAxis.labelTextColor = todoColors.primaryTextColor
        
        // Setup x-axis to show day labels
        let xAxis = lineChartView.xAxis
        xAxis.drawGridLinesEnabled = true
        xAxis.gridLineDashLengths = [10, 10]
        xAxis.gridLineDashPhase = 0
        xAxis.drawAxisLineEnabled = false
        xAxis.drawLabelsEnabled = true
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = todoColors.primaryTextColor
        xAxis.valueFormatter = WeekDayAxisValueFormatter()
        xAxis.granularity = 1.0
        xAxis.labelCount = 7
        
        // Add marker for value display
        let marker = BalloonMarker(color: UIColor(white: 180/255, alpha: 1),
                                   font: UIFont.systemFont(ofSize: 12),
                                   textColor: UIColor.white,
                                   insets: UIEdgeInsets(top: 8, left: 8, bottom: 20, right: 8))
        marker.chartView = lineChartView
        marker.minimumSize = CGSize(width: 80, height: 40)
        lineChartView.marker = marker
        
        lineChartView.legend.enabled = false
        
        // PieChart setup
        tinyPieChartView.holeRadiusPercent = 0.5
        tinyPieChartView.holeColor = UIColor.clear
        tinyPieChartView.transparentCircleColor = UIColor.clear
        tinyPieChartView.drawEntryLabelsEnabled = false
        tinyPieChartView.legend.enabled = false
        tinyPieChartView.rotationEnabled = false
        
        updateLineChartData()
    }
    
    func generateLineChartData(completion: @escaping ([ChartDataEntry]) -> Void) {
        var yValues: [ChartDataEntry] = []
        
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1 // Start on Sunday (1 for Sunday, 2 for Monday)
        
        // Get current week dates based on calendar's current page
        let referenceDate = self.calendar?.currentPage ?? Date.today()
        let week = calendar.daysWithSameWeekOfYear(as: referenceDate)
        let today = Date.today()
        
        // Log weekly chart generation
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        print("📊 Generating chart data for week of \(dateFormatter.string(from: referenceDate))")
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM dd"
        
        let dispatchGroup = DispatchGroup()
        var dayScores: [(Int, Int)] = [] // (index, score) pairs
        
        // Generate chart data points for the week (Sunday to Saturday)
        for (index, day) in week.enumerated() {
            // Enhanced future date handling
            if day > today {
                // For future dates, show 0 but with special styling indication
                let dayName = dayFormatter.string(from: day)
                print("   • \(dayName): 0 points (Future)")
                dayScores.append((index, 0))
            } else {
                // For past and current dates, calculate actual score using async method
                dispatchGroup.enter()
                calculateScoreForDate(date: day) { score in
                    let dayName = dayFormatter.string(from: day)
                    let status = day.onSameDay(as: today) ? "(Today)" : "(Past)"
                    print("   • \(dayName): \(score) points \(status)")
                    dayScores.append((index, score))
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // Sort by index to maintain correct order
            dayScores.sort { $0.0 < $1.0 }
            
            for (index, score) in dayScores {
                // Ensure score is valid and not NaN or infinite
                let validScore = max(0, score) // Ensure non-negative
                let yValue = Double(validScore)
                
                // Additional safety check for NaN or infinite values
                let safeYValue = yValue.isNaN || yValue.isInfinite ? 0.0 : yValue
                
                let dataEntry = ChartDataEntry(x: Double(index), y: safeYValue)
                
                // Add metadata for future date styling (if needed)
                let day = week[index]
                if day > today {
                    dataEntry.data = ["isFuture": true]
                }
                
                yValues.append(dataEntry)
            }
            
            // Log weekly total
            let weeklyTotal = yValues.reduce(0) { $0 + Int($1.y) }
            print("   📈 Weekly Total: \(weeklyTotal) points")
            
            completion(yValues)
        }
    }
    
    func generateSampleData() -> [ChartDataEntry] {
        let sampleValues = [15.0, 25.0, 35.0, 45.0, 30.0, 50.0, 40.0]
        return sampleValues.enumerated().map { index, value in
            // Ensure value is valid and not NaN or infinite
            let safeValue = value.isNaN || value.isInfinite ? 0.0 : value
            return ChartDataEntry(x: Double(index), y: safeValue)
        }
    }
    
    func updateLineChartForCurrentWeek() {
        // Update the line chart data based on the current calendar week
        updateLineChartData()
    }
    
    func updateLineChartData() {
        // Phase 5: Transition to SwiftUI-only chart implementation
        generateLineChartData { [weak self] dataEntries in
            guard let self = self else { return }
            
            let maxScore = dataEntries.map { $0.y }.max() ?? 0
            
            // Legacy UIKit chart update (Phase 5: DEPRECATED - keeping for compatibility)
            let dynamicMaximum = max(maxScore * 1.2, 10)
            let leftAxis = self.lineChartView.leftAxis
            leftAxis.axisMaximum = dynamicMaximum
            
            let dataSet = LineChartDataSet(entries: dataEntries, label: "Daily Score")
            dataSet.mode = .linear
            dataSet.drawCirclesEnabled = true
            dataSet.lineWidth = 3.5
            dataSet.circleRadius = 6
            dataSet.setCircleColor(self.todoColors.secondaryAccentColor)
            dataSet.setColor(self.todoColors.primaryColor)
            dataSet.drawCircleHoleEnabled = true
            dataSet.circleHoleRadius = 3
            dataSet.circleHoleColor = UIColor.systemBackground
            dataSet.valueFont = .systemFont(ofSize: 10, weight: .medium)
            dataSet.valueTextColor = self.todoColors.primaryTextColor
            
            let gradientColors = [
                self.todoColors.secondaryAccentColor.withAlphaComponent(0.5).cgColor,
                self.todoColors.secondaryAccentColor.withAlphaComponent(0.25).cgColor,
                self.todoColors.secondaryAccentColor.withAlphaComponent(0.0).cgColor
            ]
            let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: [0.0, 0.5, 1.0])!
            dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
            dataSet.drawFilledEnabled = true
            dataSet.fillAlpha = 0.5
            dataSet.lineDashLengths = nil
            dataSet.highlightEnabled = true
            dataSet.highlightColor = self.todoColors.secondaryAccentColor
            dataSet.highlightLineWidth = 2
            dataSet.drawHorizontalHighlightIndicatorEnabled = false
            dataSet.drawVerticalHighlightIndicatorEnabled = true
            
            let data = LineChartData(dataSet: dataSet)
            data.setDrawValues(true)
            self.lineChartView.data = data
            
            // Phase 5: Primary focus on SwiftUI chart card
            self.updateSwiftUIChartCard()
            
            // Log chart update for debugging
            print("📊 Phase 5: SwiftUI chart updated with \(dataEntries.count) data points, max score: \(maxScore)")
            print("⚠️ Phase 5: UIKit chart updated but remains hidden")
        }
    }
    
    func calculateScoreForDate(date: Date) -> Int {
        // Use the same logic as ChartDataService for consistency
        let allTasks = TaskManager.sharedInstance.getAllTasksForDate(date: date)
        
        let score = allTasks.filter { $0.isComplete }.reduce(0) { total, task in
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            return total + taskScore
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        print("📊 [HomeViewController] Score for \(dateFormatter.string(from: date)): \(score) from \(allTasks.filter { $0.isComplete }.count) completed tasks")
        
        return score
    }
    
    /// Async version of calculateScoreForDate that uses the repository pattern
    private func calculateScoreForDate(date: Date, completion: @escaping (Int) -> Void) {
        // Use the same approach as ChartDataService for consistency
        let allTasks = TaskManager.sharedInstance.getAllTasksForDate(date: date)
        
        let score = allTasks.filter { $0.isComplete }.reduce(0) { total, task in
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            return total + taskScore
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        print("📊 [HomeViewController] Score for \(dateFormatter.string(from: date)): \(score) from \(allTasks.filter { $0.isComplete }.count) completed tasks")
        completion(score)
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
    
    /// Async version of calculateScoreForProject that uses the repository pattern
    func calculateScoreForProject(project: String, completion: @escaping (Int) -> Void) {
        var morningScore = 0
        var eveningScore = 0
        let group = DispatchGroup()
        
        // Get morning tasks for the project
        group.enter()
        let morningPredicate = NSPredicate(format: "project == %@ AND type == %@", project, TaskType.morning.rawValue)
        taskRepository.fetchTasks(predicate: morningPredicate, sortDescriptors: nil) { taskData in
            for data in taskData {
                if data.isComplete {
                    morningScore += data.priority.scoreValue
                }
            }
            group.leave()
        }
        
        // Get evening tasks for the project
        group.enter()
        let eveningPredicate = NSPredicate(format: "project == %@ AND type == %@", project, TaskType.evening.rawValue)
        taskRepository.fetchTasks(predicate: eveningPredicate, sortDescriptors: nil) { taskData in
            for data in taskData {
                if data.isComplete {
                    eveningScore += data.priority.scoreValue
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(morningScore + eveningScore)
        }
    }
    
    func animateLineChart(chartView: LineChartView) {
        // Animate with both X and Y axis like LineChart1ViewController
        chartView.animate(xAxisDuration: 1.5, yAxisDuration: 1.5, easingOption: .easeInOutQuad)
    }
    
//    func updateSwiftUIChartCard() {
//        // Update the SwiftUI chart with new data when needed
//        guard let hostingController = swiftUIChartHostingController else { return }
//        
//        let updatedChartCard = TaskProgressCard(referenceDate: dateForTheView)
//        hostingController.rootView = AnyView(updatedChartCard)
//        
//        print("📊 SwiftUI Chart Card updated with new reference date")
//    }
}
