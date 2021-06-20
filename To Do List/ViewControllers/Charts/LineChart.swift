//
//  LineChart.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import Charts


extension HomeViewController {

    
    //MARK:- SET CHART DATA - LINE
    func setLineChartData() {
        let set01 = LineChartDataSet(entries: generateLineChartData(), label: "Score for the day")
        //        let set01 = LineChartDataSet(entries: generateLineChartData())
        
        //        set01.drawCirclesEnabled = false
        set01.drawCirclesEnabled = false
        set01.mode = .cubicBezier
        set01.setColor(todoColors.secondaryAccentColor)
        set01.lineWidth = 3
        set01.fill = Fill(color: todoColors.primaryColorDarker)
        set01.fillAlpha = 0.8
        set01.drawFilledEnabled = true
        
        //TODO add set 1 and this week & add set 2 with different color as last week
        
        let lineChartData_01 = LineChartData(dataSet: set01)
        lineChartView.data = lineChartData_01
        
        
    }
    
}
