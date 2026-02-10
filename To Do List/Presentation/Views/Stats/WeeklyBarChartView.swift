//
//  WeeklyBarChartView.swift
//  Tasker
//
//  Bar chart showing last 7 days of XP using DGCharts.
//

import SwiftUI
import DGCharts

public struct WeeklyBarChartView: UIViewRepresentable {
    public let data: [Int]
    
    public init(data: [Int]) {
        self.data = data
    }
    
    public func makeUIView(context: Context) -> BarChartView {
        let chart = BarChartView()
        chart.data = generateChartData()
        chart.xAxis.valueFormatter = DayAxisFormatter()
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.granularity = 1
        chart.rightAxis.enabled = false
        chart.leftAxis.enabled = false
        chart.legend.enabled = false
        chart.notifyDataSetChanged()
        return chart
    }
    
    public func updateUIView(_ uiView: BarChartView, context: Context) {
        uiView.data = generateChartData()
    }
    
    private func generateChartData() -> BarChartData {
        let entries = data.enumerated().map { (index, value) in
            BarChartDataEntry(x: Double(index), y: Double(value))
        }

        let set = BarChartDataSet(entries: entries, label: "XP")
        // Use coral theme color: #FF6B6B
        let coralColor = NSUIColor(red: 255/255, green: 107/255, blue: 107/255, alpha: 1.0)
        set.colors = [coralColor]
        set.valueColors = [.darkGray]
        set.drawValuesEnabled = true
        set.valueFont = .systemFont(ofSize: 10, weight: .medium)

        return BarChartData(dataSet: set)
    }
}

class DayAxisFormatter: AxisValueFormatter {
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let calendar = Calendar.current
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let today = calendar.component(.weekday, from: Date())
        let offset = (7 + Int(value) - (today - 1)) % 7
        return days[offset]
    }
}
