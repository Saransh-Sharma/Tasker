//
//  TinyPieChart.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import DGCharts


extension HomeViewController {
    
    
    
    //setup chart
    func setupPieChartView(pieChartView chartView: PieChartView) {
        chartView.drawSlicesUnderHoleEnabled = false
        // Hide default 'no chart data available' label when there is no data
        chartView.noDataText = ""
        chartView.noDataTextColor = .clear
        chartView.holeRadiusPercent = 0.60
        chartView.holeColor = todoColors.primaryColorDarker
        chartView.transparentCircleRadiusPercent = 0.60
        chartView.setExtraOffsets(left: 7, top: 2, right: 5, bottom: 0)
        
        
        chartView.drawCenterTextEnabled = true
        
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        
        
        chartView.centerAttributedText = setTinyPieChartScoreText(pieChartView: chartView);
        chartView.drawHoleEnabled = true
        chartView.rotationAngle = 0
        chartView.rotationEnabled = true
        chartView.highlightPerTapEnabled = false
        chartView.legend.form = .none
        
        
        //        chartView.layer.shadowColor = UIColor.black.cgColor
        chartView.layer.shadowColor = todoColors.primaryColorDarker.cgColor
        
        chartView.layer.shadowOpacity = 0.8//0.3
        chartView.layer.shadowOffset = .zero//CGSize(width: -2.0, height: -2.0) //.zero
        chartView.layer.shadowRadius = 14//2
        
        setTinyChartShadow(chartView: chartView)
    }
    
    func setTinyChartShadow(chartView: PieChartView) {
        //        chartView.layer.shadowColor = UIColor.black.cgColor
        chartView.layer.shadowColor = todoColors.primaryColorDarker.cgColor
        
        chartView.layer.shadowOpacity = 0.4
        chartView.layer.shadowOffset = .zero
        chartView.layer.shadowRadius = 4
    }
    
    /// Makes the tiny pie chart spin with animation
    /// - Parameters:
    ///   - chartView: The PieChartView to animate
    ///   - duration: Animation duration in seconds (default: 2.0)
    ///   - easingOption: Animation easing option (default: .easeInCubic)
    func spinTinyPieChart(_ chartView: PieChartView, duration: TimeInterval = 2.0, easingOption: ChartEasingOption = .easeInCubic) {
        chartView.spin(duration: duration,
                       fromAngle: chartView.rotationAngle,
                       toAngle: chartView.rotationAngle + 360,
                       easingOption: easingOption)
    }
    
    /// Sets the center text of a small pie chart to the supplied score (defaults to today's score if none provided).
    /// - Parameters:
    ///   - chartView: The `PieChartView` whose center text should be updated.
    ///   - scoreOverride: If non-nil, uses this score instead of recalculating.
    /// - Returns: The attributed string applied to `centerAttributedText`.
    func setTinyPieChartScoreText(pieChartView chartView: PieChartView, scoreOverride: Int? = nil) -> NSAttributedString {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        let effectiveScore = scoreOverride ?? self.calculateTodaysScore()
        let scoreNumber = "\(effectiveScore)"
        
        
        let centerText = NSMutableAttributedString(string: "\(scoreNumber)")
        if (effectiveScore < 9) {
            print("FONT SMALL")
            centerText.setAttributes([
                .font : setFont(fontSize: 44, fontweight: .medium, fontDesign: .rounded),
                .paragraphStyle : paragraphStyle,
                .strokeColor : UIColor.label,
                .foregroundColor : todoColors.backgroundColor //todoColors.primaryColorDarker
            ],
            
            range: NSRange(location: 0, length: centerText.length))
        } else {
            print("FONT BIG")
            centerText.setAttributes([
                .font : setFont(fontSize: 32, fontweight: .medium, fontDesign: .rounded),
                .paragraphStyle : paragraphStyle,
                .strokeColor : UIColor.label,
                .foregroundColor : todoColors.backgroundColor //todoColors.primaryColorDarker
            ], range: NSRange(location: 0, length: centerText.length))
        }
        
        chartView.centerAttributedText = centerText;
        return centerText
    }
    
    //---------- SETUP: CHART
    
    /// Updates tiny pie chart with real task data based on priority breakdown
    func updateTinyPieChartData() {
        if self.shouldHideData {
            tinyPieChartView.data = nil
            return
        }
        
        print("🥧 Updating tiny pie chart data for date: \(dateForTheView)")
        
        // Get priority breakdown for current view date
        let breakdown = priorityBreakdown(for: dateForTheView)
        print("📊 Tiny chart priority breakdown: \(breakdown)")
        
        // Build entries using chart weights from config
        let entries: [PieChartDataEntry] = [
            (Int32(1), "None"),    // None priority
            (Int32(2), "Low"),     // Low priority
            (Int32(3), "High"),    // High priority
            (Int32(4), "Max")      // Max priority
        ].compactMap { (priorityRaw, label) in
            let rawCount = Double(breakdown[priorityRaw] ?? 0)
            let weight = TaskPriorityConfig.chartWeightForPriority(priorityRaw)
            let weightedValue = rawCount * weight
            return weightedValue > 0 ? PieChartDataEntry(value: weightedValue, label: label) : nil
        }
        
        // If no data, show empty chart
        guard !entries.isEmpty else {
            print("⚠️ No data for tiny pie chart")
            tinyPieChartView.data = nil
            return
        }
        
        // Build colors array matching entries
        var sliceColors: [UIColor] = []
        for entry in entries {
            switch entry.label {
            case "None":
                sliceColors.append(TaskPriorityConfig.Priority.none.color)
            case "Low":
                sliceColors.append(TaskPriorityConfig.Priority.low.color)
            case "High":
                sliceColors.append(TaskPriorityConfig.Priority.high.color)
            case "Max":
                sliceColors.append(TaskPriorityConfig.Priority.max.color)
            default:
                sliceColors.append(todoColors.secondaryAccentColor)
            }
        }
        
        let set = PieChartDataSet(entries: entries, label: "")
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.sliceSpace = 2
        set.colors = sliceColors
        
        let data = PieChartData(dataSet: set)
        tinyPieChartView.drawEntryLabelsEnabled = false
        tinyPieChartView.data = data
        
        print("✅ Tiny pie chart updated with \(entries.count) slices")
    }
    
    
}

