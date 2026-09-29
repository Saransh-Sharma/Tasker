import Accessibility
import Charts
import SwiftUI

/// An Audio Graphs description for a bar chart of named categories. Shared by
/// the Health hub and Nutrition, whose charts are both category → amount.
struct CategoryBarChartDescriptor: AXChartDescriptorRepresentable {
    struct Point {
        let label: String
        let value: Double
    }

    let title: String
    let categoryTitle: String
    let valueTitle: String
    let unit: String
    let points: [Point]

    func makeChartDescriptor() -> AXChartDescriptor {
        let unit = unit
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: categoryTitle,
            categoryOrder: points.map(\.label)
        )
        let upper = max(points.map(\.value).max() ?? 1, 1)
        let yAxis = AXNumericDataAxisDescriptor(
            title: valueTitle,
            range: 0...upper,
            gridlinePositions: []
        ) { value in "\(value.formatted(.number.precision(.fractionLength(0)))) \(unit)" }
        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: false,
            dataPoints: points.map { AXDataPoint(x: $0.label, y: $0.value) }
        )
        return AXChartDescriptor(
            title: title,
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

struct HealthNutritionChartValue: Identifiable {
    let label: String
    let value: Double
    var id: String { label }
}
