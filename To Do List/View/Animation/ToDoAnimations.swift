//
//  ToDoAnimations.swift
//  To Do List
//
//  Created by Saransh Sharma on 07/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import DGCharts

class ToDoAnimations  {
    
    /// Executes animateTinyPieChartAtHome.
    func animateTinyPieChartAtHome(pieChartView: PieChartView) {
        pieChartView.animate(xAxisDuration: 1.8, easingOption: .easeOutBack)
    }
    
//    func animateLineChartAtHome(lineChartView: LineChartView) {
//        lineChartView.animate(.)
//    }
}
