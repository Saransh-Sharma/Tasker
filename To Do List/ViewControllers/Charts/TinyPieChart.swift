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
        chartView.drawSlicesUnderHoleEnabled = true
        // Hide default 'no chart data available' label when there is no data
        chartView.noDataText = ""
        chartView.noDataTextColor = .clear
        chartView.holeRadiusPercent = 0.85
        chartView.holeColor = todoColors.primaryColor
        chartView.transparentCircleRadiusPercent = 0.41
        //        chartView.setExtraOffsets(left: 7, top: 5, right: 5, bottom: 7)
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
        
        chartView.layer.shadowOpacity = 0.4//0.3
        chartView.layer.shadowOffset = .zero//CGSize(width: -2.0, height: -2.0) //.zero
        chartView.layer.shadowRadius = 4//2
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
                .font : setFont(fontSize: 60, fontweight: .medium, fontDesign: .rounded),
                .paragraphStyle : paragraphStyle,
                .strokeColor : UIColor.label,
                .foregroundColor : todoColors.primaryColor
            ],
            
            range: NSRange(location: 0, length: centerText.length))
        } else {
            print("FONT BIG")
            centerText.setAttributes([
                .font : setFont(fontSize: 44, fontweight: .medium, fontDesign: .rounded),
                .paragraphStyle : paragraphStyle,
                .strokeColor : UIColor.label,
                .foregroundColor : todoColors.primaryColor
            ], range: NSRange(location: 0, length: centerText.length))
        }
        
        chartView.centerAttributedText = centerText;
        return centerText
    }
    
    //---------- SETUP: CHART
    
    func updateTinyPieChartData() {
        if self.shouldHideData {
            tinyPieChartView.data = nil
            return
        }
        print("--------------------------")
        print("X: \(10)")//print("X: \(Int(sliderX.value))")
        print("Y: \(40)")//print("Y: \(UInt32(sliderY.value))")
        print("--------------------------")
        
        //            self.setDataCount(Int(sliderX.value), range: UInt32(sliderY.value))
        self.setTinyPieChartDataCount(4, range: 40)
    }
    
    
    
    //MARK:-GET THIS 1
    func setTinyPieChartDataCount(_ count: Int, range: UInt32) {
        let entries = (0..<count).map { (i) -> PieChartDataEntry in
            // IMPORTANT: In a PieChart, no values (Entry) should have the same xIndex (even if from different DataSets), since no values can be drawn above each other.
            
            let randomValue = Double(arc4random_uniform(range) + range / 5)
            // Ensure value is valid and not NaN or infinite
            let safeValue = randomValue.isNaN || randomValue.isInfinite ? 1.0 : max(1.0, randomValue)
            
            return PieChartDataEntry(value: safeValue,
                                     label: tinyPieChartSections[i % tinyPieChartSections.count],
                                     icon: #imageLiteral(resourceName: "material_done_White"))
            
        }
        
        let set = PieChartDataSet(entries: entries, label: "")
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.sliceSpace = 2
        set.colors = ChartColorTemplates.vordiplom()
        
        let data = PieChartData(dataSet: set)
        
        tinyPieChartView.drawEntryLabelsEnabled = false
        tinyPieChartView.data = data
    }
    
    
}

