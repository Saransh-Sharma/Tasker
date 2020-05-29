//
//  TinyPieChart.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import Charts


extension ViewController {
    
    
    
    //setup chart
    func setupPieChartView(pieChartView chartView: PieChartView) {
        //            chartView.usePercentValuesEnabled = false
        chartView.drawSlicesUnderHoleEnabled = true
        chartView.holeRadiusPercent = 0.85
        chartView.holeColor = todoColors.primaryColor
        //            chartView.holeRadiusPercent = 0.10
        chartView.transparentCircleRadiusPercent = 0.41
        //            chartView.chartDescription?.enabled = true
        
        chartView.setExtraOffsets(left: 5, top: 5, right: 5, bottom: 5)
        
   
        chartView.drawCenterTextEnabled = true
        
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        

        chartView.centerAttributedText = setTinyPieChartScoreText(pieChartView: chartView);
//        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
        
        

        chartView.drawHoleEnabled = true
        chartView.rotationAngle = 0
        chartView.rotationEnabled = true
        chartView.highlightPerTapEnabled = false
        chartView.legend.form = .none
    
        
        
        
    }
    
    func setTinyPieChartScoreText(pieChartView chartView: PieChartView) -> NSAttributedString {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
         let scoreNumber = "\(self.calculateTodaysScore())"
               let centerText = NSMutableAttributedString(string: "\(scoreNumber)")
               centerText.setAttributes([.font : setFont(fontSize: 45, fontweight: .medium, fontDesign: .rounded),
                                         .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
               centerText.addAttribute(NSAttributedString.Key.foregroundColor, value: scoreInTinyPieChartColor, range: NSRange(location: 0, length: centerText.length)) //addAttribute(NSForegroundColorAttributeName, value: UIColor.redColor() , range: range)
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
            
            return PieChartDataEntry(value: Double(arc4random_uniform(range) + range / 5),
                                     label: tinyPieChartSections[i % tinyPieChartSections.count],
                                     icon: #imageLiteral(resourceName: "material_done_White"))
            
            //                return PieChartDataEntry(value: 25, label: "25_1")
            //                return PieChartDataEntry(value: 25, label: "25_2")
            //                return PieChartDataEntry(value: 25, label: "25_3")
            //                return PieChartDataEntry(value: 25, label: "25_4")
        }
        
        //            let set = PieChartDataSet(entries: entries, label: "Election Results")
        let set = PieChartDataSet(entries: entries, label: "")
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        
        set.sliceSpace = 2
        
        //        let set01 = LineChartDataSet(entries: generateLineChartData(), label: "Score for the day")
        
        //            for set2 in set {
        //                                      set2.drawValuesEnabled = !set2.drawValuesEnabled
        //                                  }
        
        
        //let scoreNumber = "\(self.calculateTodaysScore())"
        
        //todo: change set color for 0 score day
//        print("hool: score is: \(self.calculateTodaysScore())")
//        if (self.calculateTodaysScore() > 0) {
////            print("hool: GREEN")
//            set.colors = ChartColorTemplates.vordiplom()
//
//        } else {
////            print("hool: BLUE")
//            set.colors = ChartColorTemplates.liberty()
//        }
        
        
        set.colors = ChartColorTemplates.vordiplom()
        
        
//        set.colors = ChartColorTemplates.vordiplom()
//            + ChartColorTemplates.joyful()
//            + ChartColorTemplates.colorful()
//            + ChartColorTemplates.liberty()
//            + ChartColorTemplates.pastel()
//            + [UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)]
        
        let data = PieChartData(dataSet: set)
        
        
        
        
        
        tinyPieChartView.drawEntryLabelsEnabled = false
        tinyPieChartView.data = data
        //            chartView.highlightValues(nil)
    }
    

}

