//
//  HomeViewController+Charts.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import DGCharts

extension HomeViewController {
    
    // MARK: - Chart Setup and Data
    
    func setupCharts() {
        // LineChart setup - Based on LineChart1ViewController
        lineChartView.backgroundColor = .clear
        lineChartView.legend.form = .line
        lineChartView.rightAxis.enabled = false
        
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
    
    func generateLineChartData() -> [ChartDataEntry] {
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
        
        // Generate chart data points for the week (Sunday to Saturday)
        for (index, day) in week.enumerated() {
            let score: Int
            
            // Enhanced future date handling
            if day > today {
                // For future dates, show 0 but with special styling indication
                score = 0
            } else {
                // For past and current dates, calculate actual score
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
    
    func updateLineChartForCurrentWeek() {
        // Update the line chart data based on the current calendar week
        updateLineChartData()
    }
    
    func updateLineChartData() {
        let dataEntries = generateLineChartData()
        
        // Calculate dynamic y-axis maximum (20% more than max score)
        let maxScore = dataEntries.map { $0.y }.max() ?? 0
        let dynamicMaximum = max(maxScore * 1.2, 10) // Ensure minimum scale of 10
        
        // Update left axis maximum with smooth transition
        let leftAxis = lineChartView.leftAxis
        leftAxis.axisMaximum = dynamicMaximum
        
        let dataSet = LineChartDataSet(entries: dataEntries, label: "Daily Score")
        
        // Enhanced visual configuration
        dataSet.mode = .linear
        dataSet.drawCirclesEnabled = true
        dataSet.lineWidth = 3.5
        dataSet.circleRadius = 6
        dataSet.setCircleColor(todoColors.secondaryAccentColor)
        dataSet.setColor(todoColors.primaryColor)
        dataSet.drawCircleHoleEnabled = true
        dataSet.circleHoleRadius = 3
        dataSet.circleHoleColor = UIColor.systemBackground
        dataSet.valueFont = .systemFont(ofSize: 10, weight: .medium)
        dataSet.valueTextColor = todoColors.primaryTextColor
        
        // Enhanced gradient fill with better visual appeal
        let gradientColors = [
            todoColors.secondaryAccentColor.withAlphaComponent(0.5).cgColor,
            todoColors.secondaryAccentColor.withAlphaComponent(0.25).cgColor,
            todoColors.secondaryAccentColor.withAlphaComponent(0.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: [0.0, 0.5, 1.0])!
        
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.5
        
        // Enhanced line style for better visibility
        dataSet.lineDashLengths = nil // Solid line for better readability
        dataSet.highlightEnabled = true
        dataSet.highlightColor = todoColors.secondaryAccentColor
        dataSet.highlightLineWidth = 2
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.drawVerticalHighlightIndicatorEnabled = true
        
        let data = LineChartData(dataSet: dataSet)
        data.setDrawValues(true)
        
        // Enhanced animation with staggered effect
        lineChartView.data = data
        
        // Animate with enhanced timing and easing
        DispatchQueue.main.async { [weak self] in
            self?.lineChartView.animate(xAxisDuration: 1.2, yAxisDuration: 1.2, easingOption: .easeInOutCubic)
            
            // Add subtle bounce effect after main animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self?.lineChartView.animate(yAxisDuration: 0.3, easingOption: .easeOutBack)
            }
        }
        
        // Log chart update for debugging
        print("Chart updated with \(dataEntries.count) data points, max score: \(maxScore)")
    }
    
    func calculateScoreForDate(date: Date) -> Int {
        var score = 0
        let allTasks = TaskManager.sharedInstance.getAllTasksForDate(date: date)
        
        // Debug logging
        print("🔍 calculateScoreForDate for \(date): Found \(allTasks.count) tasks")
        
        for task in allTasks {
            if task.isComplete {
                // getAllTasksForDate already filters completed tasks by dateCompleted range
                // so we don't need the additional onSameDay check
                let taskScore = task.getTaskScore(task: task)
                score = score + taskScore
                print("   ✅ Task '\(task.name)' completed: +\(taskScore) points")
            }
        }
        
        print("   📊 Total score for \(date): \(score) points")
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
    
    func animateLineChart(chartView: LineChartView) {
        // Animate with both X and Y axis like LineChart1ViewController
        chartView.animate(xAxisDuration: 1.5, yAxisDuration: 1.5, easingOption: .easeInOutQuad)
    }
}
