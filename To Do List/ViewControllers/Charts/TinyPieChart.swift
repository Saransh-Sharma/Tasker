//
//  TinyPieChart.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import DGCharts
import UIKit


extension HomeViewController {
    
    
    
    //setup chart
    func setupPieChartView(pieChartView chartView: PieChartView) {
        chartView.drawSlicesUnderHoleEnabled = false
        // Hide default 'no chart data available' label when there is no data
        chartView.noDataText = ""
        chartView.noDataTextColor = .clear
        chartView.holeRadiusPercent = 0.60
        chartView.holeColor = todoColors.accentPrimaryPressed
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
        chartView.layer.borderWidth = 0
        chartView.layer.borderColor = UIColor.clear.cgColor
        setTinyChartShadow(chartView: chartView)
    }
    
    func setTinyChartShadow(chartView: PieChartView) {
        applyTinyChartShadowStyle(to: chartView, deferredIfNeeded: true)
    }

    private func applyTinyChartShadowStyle(to chartView: PieChartView, deferredIfNeeded: Bool) {
        let style = TaskerThemeManager.shared.currentTheme.tokens.elevation.e1

        chartView.layer.shadowColor = style.shadowColor.cgColor
        chartView.layer.shadowOpacity = style.shadowOpacity
        chartView.layer.shadowOffset = CGSize(width: 0, height: style.shadowOffsetY)
        chartView.layer.shadowRadius = style.shadowBlur / 2
        chartView.layer.borderWidth = 0
        chartView.layer.borderColor = UIColor.clear.cgColor
        chartView.layer.masksToBounds = false

        let bounds = chartView.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            chartView.layer.shadowPath = nil
            guard deferredIfNeeded else { return }
            DispatchQueue.main.async { [weak self, weak chartView] in
                guard let self, let chartView else { return }
                self.applyTinyChartShadowStyle(to: chartView, deferredIfNeeded: false)
            }
            return
        }

        chartView.layer.shadowPath = UIBezierPath(ovalIn: bounds).cgPath
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
            logDebug("FONT SMALL")
            centerText.setAttributes([
                .font : setFont(fontSize: 44, fontweight: .medium, fontDesign: .rounded),
                .paragraphStyle : paragraphStyle,
                .strokeColor : UIColor.label,
                .foregroundColor : todoColors.bgCanvas //todoColors.accentPrimaryPressed
            ],
            
            range: NSRange(location: 0, length: centerText.length))
        } else {
            logDebug("FONT BIG")
            centerText.setAttributes([
                .font : setFont(fontSize: 32, fontweight: .medium, fontDesign: .rounded),
                .paragraphStyle : paragraphStyle,
                .strokeColor : UIColor.label,
                .foregroundColor : todoColors.bgCanvas //todoColors.accentPrimaryPressed
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
        
        logDebug("🥧 Updating tiny pie chart data for date: \(dateForTheView)")
        
        // Get priority breakdown for current view date
        let breakdown = priorityBreakdown(for: dateForTheView)
        logDebug("📊 Tiny chart priority breakdown: \(breakdown)")
        
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
                sliceColors.append(todoColors.accentMuted)
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
        
        logDebug("✅ Tiny pie chart updated with \(entries.count) slices")
    }
    
    
}
