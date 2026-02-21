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
    /// Executes setupPieChartView.
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
    
    /// Executes setTinyChartShadow.
    func setTinyChartShadow(chartView: PieChartView) {
        applyTinyChartShadowStyle(to: chartView, deferredIfNeeded: true)
    }

    /// Executes applyTinyChartShadowStyle.
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

        // Build entries with priority info for color mapping (no labels to prevent rendering)
        typealias PriorityEntry = (entry: PieChartDataEntry, priority: Int32)
        let priorityEntries: [PriorityEntry] = [Int32(1), Int32(2), Int32(3), Int32(4)].compactMap { priorityRaw in
            let rawCount = Double(breakdown[priorityRaw] ?? 0)
            let weight = TaskPriorityConfig.chartWeightForPriority(priorityRaw)
            let weightedValue = rawCount * weight
            // Note: No label to prevent any text from rendering
            guard weightedValue > 0 else { return nil }
            return PriorityEntry(entry: PieChartDataEntry(value: weightedValue), priority: priorityRaw)
        }

        // If no data, show empty chart
        guard !priorityEntries.isEmpty else {
            tinyPieChartView.data = nil
            return
        }

        // Map colors using priority values directly
        var sliceColors: [UIColor] = []
        for priorityEntry in priorityEntries {
            switch priorityEntry.priority {
            case 1:
                sliceColors.append(TaskPriorityConfig.Priority.none.color)
            case 2:
                sliceColors.append(TaskPriorityConfig.Priority.low.color)
            case 3:
                sliceColors.append(TaskPriorityConfig.Priority.high.color)
            case 4:
                sliceColors.append(TaskPriorityConfig.Priority.max.color)
            default:
                sliceColors.append(todoColors.accentMuted)
            }
        }

        let entries = priorityEntries.map { $0.entry }
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
