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
        
        // Generate chart data points for the week (Sunday to Saturday)
        for (index, day) in week.enumerated() {
            let score = calculateScoreForDate(date: day)
            let dataEntry = ChartDataEntry(x: Double(index), y: Double(score))
            yValues.append(dataEntry)
        }
        
        // Always generate sample data for demonstration
        // TODO: Remove this line when real task data is available
        yValues = generateSampleData()
        
        return yValues
    }
    
    func generateSampleData() -> [ChartDataEntry] {
        let sampleValues = [15.0, 25.0, 35.0, 45.0, 30.0, 50.0, 40.0]
        return sampleValues.enumerated().map { index, value in
            ChartDataEntry(x: Double(index), y: value)
        }
    }
    
    func updateLineChartForCurrentWeek() {
        // Update the line chart data based on the current calendar week
        updateLineChartData()
    }
    
    func updateLineChartData() {
        let dataEntries = generateLineChartData()
        
        let dataSet = LineChartDataSet(entries: dataEntries, label: "Daily Score")
        
        // Configure line chart with stepped mode (like LineChart1ViewController)
        dataSet.mode = .stepped
        dataSet.drawCirclesEnabled = true
        dataSet.lineWidth = 3
        dataSet.circleRadius = 5
        dataSet.setCircleColor(todoColors.secondaryAccentColor)
        dataSet.setColor(todoColors.primaryColor)
        dataSet.drawCircleHoleEnabled = false
        dataSet.valueFont = .systemFont(ofSize: 9)
        
        // Add gradient fill
        let gradientColors = [
            todoColors.primaryColor.withAlphaComponent(0.9).cgColor,
            todoColors.primaryColor.withAlphaComponent(0.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!
        
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 1
        
        // Configure line style
        dataSet.lineDashLengths = [5, 2.5]
        dataSet.highlightLineDashLengths = [5, 2.5]
        dataSet.formLineDashLengths = [5, 2.5]
        dataSet.formLineWidth = 1
        dataSet.formSize = 15
        
        let data = LineChartData(dataSet: dataSet)
        data.setDrawValues(true)
        
        lineChartView.data = data
        
        // Animate with both X and Y axis animation (like LineChart1ViewController)
        lineChartView.animate(xAxisDuration: 1.5, yAxisDuration: 1.5, easingOption: .easeInOutQuad)
    }
    
    func calculateScoreForDate(date: Date) -> Int {
        var score = 0
        let allTasks = TaskManager.sharedInstance.getAllTasksForDate(date: date)
        
        for task in allTasks {
            if task.isComplete {
                if let dateCompleted = task.dateCompleted as Date?, dateCompleted.onSameDay(as: date) {
                    score = score + task.getTaskScore(task: task)
                }
            }
        }
        
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
