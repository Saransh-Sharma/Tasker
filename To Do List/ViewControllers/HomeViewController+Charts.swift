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
        // LineChart setup
        lineChartView.backgroundColor = .clear
        lineChartView.legend.form = .default
        lineChartView.rightAxis.enabled = false
        
        let leftAxis = lineChartView.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawZeroLineEnabled = false
        leftAxis.drawAxisLineEnabled = false
        
        lineChartView.xAxis.drawGridLinesEnabled = false
        lineChartView.xAxis.drawAxisLineEnabled = false
        lineChartView.xAxis.drawLabelsEnabled = false
        
        lineChartView.legend.enabled = false
        lineChartView.animate(xAxisDuration: 1.5)
        
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
        calendar.firstWeekday = 2 // Start on Monday (or 1 for Sunday)
        
        // Get current week dates
        let week = calendar.daysWithSameWeekOfYear(as: Date.today())
        
        // Generate chart data points for the week
        for (index, day) in week.enumerated() {
            let score = calculateScoreForDate(date: day)
            let dataEntry = ChartDataEntry(x: Double(index), y: Double(score))
            yValues.append(dataEntry)
        }
        
        return yValues
    }
    
    func updateLineChartData() {
        let dataEntries = generateLineChartData()
        
        let dataSet = LineChartDataSet(entries: dataEntries, label: "Score")
        
        dataSet.drawCirclesEnabled = true
        dataSet.lineWidth = 3
        dataSet.circleRadius = 5
        dataSet.setCircleColor(todoColors.secondaryAccentColor)
        dataSet.setColor(todoColors.primaryColor)
        dataSet.mode = .cubicBezier
        
        let gradientColors = [
            todoColors.primaryColor.withAlphaComponent(0.9).cgColor,
            todoColors.primaryColor.withAlphaComponent(0.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!
        
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        
        let data = LineChartData(dataSet: dataSet)
        data.setDrawValues(false)
        
        lineChartView.data = data
        animateLineChart(chartView: lineChartView)
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
        chartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0, easingOption: .easeInOutQuad)
    }
}
