//
//  ChartCard.swift
//  To Do List
//
//  Created by Assistant on Chart Card Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import SwiftUI
import DGCharts
import UIKit

// MARK: - Chart Card
struct ChartCard: View {
    let title: String
    let subtitle: String?
    let referenceDate: Date?
    @State private var chartData: [ChartDataEntry] = []
    @State private var isLoading = true
    
    init(title: String = "Weekly Progress", subtitle: String? = "Task completion scores", referenceDate: Date? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.referenceDate = referenceDate
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with enhanced theming (Phase 4: Feature Parity)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .dynamicTypeSize(.large...(.accessibility5))  // Dynamic type support
                    .accessibilityAddTraits(.isHeader)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .dynamicTypeSize(.large...(.accessibility3))  // Dynamic type support
                }
            }
            .accessibilityElement(children: .combine)
            
            // Chart Container
            ZStack {
                if isLoading {
                    // Loading state
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                        )
                } else {
                    // Chart view
                    LineChartViewRepresentable(data: chartData, referenceDate: referenceDate)
                        .frame(height: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            loadChartData()
        }
        .onChange(of: referenceDate) { _ in
            loadChartData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TaskCompletionChanged"))) { _ in
            print("📡 ChartCard: Received TaskCompletionChanged - reloading chart data")
            loadChartData()
        }
    }
    
    private func loadChartData() {
        isLoading = true
        // Generate chart data on the Core Data context queue to ensure freshest state
        TaskManager.sharedInstance.context.perform {
            let newData = ChartDataService.shared.generateLineChartData(for: referenceDate)
            DispatchQueue.main.async {
                self.chartData = newData
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.isLoading = false
                }
                #if DEBUG
                print("📊 SwiftUI Chart Card loaded \(newData.count) data points")
                #endif
            }
        }
    }

}

// MARK: - Line Chart View Representable
struct LineChartViewRepresentable: UIViewRepresentable {
    let data: [ChartDataEntry]
    let referenceDate: Date?
    
    func makeUIView(context: Context) -> LineChartView {
        let chartView = LineChartView()
        setupChartView(chartView)
        return chartView
    }
    
    func updateUIView(_ uiView: LineChartView, context: Context) {
        updateChartData(uiView)
    }
    
    private func setupChartView(_ chartView: LineChartView) {
        let colors = ToDoColors()
        
        // Enhanced chart configuration for feature parity (Phase 4)
        chartView.backgroundColor = UIColor.clear
        chartView.gridBackgroundColor = UIColor.clear
        chartView.drawGridBackgroundEnabled = false
        chartView.drawBordersEnabled = false
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false
        
        // Enhanced interaction capabilities (Phase 4: Feature Parity)
        chartView.scaleXEnabled = true
        chartView.scaleYEnabled = true  // Enable Y-axis scaling like original
        chartView.pinchZoomEnabled = true
        chartView.doubleTapToZoomEnabled = true  // Enable double-tap zoom like original
        chartView.dragEnabled = true
        chartView.highlightPerTapEnabled = true  // Enable tap highlighting
        chartView.highlightPerDragEnabled = false
        chartView.setViewPortOffsets(left: 20, top: 20, right: 20, bottom: 50)
        
        // X-axis configuration
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = true
        xAxis.axisLineColor = colors.primaryTextColor.withAlphaComponent(0.3)
        xAxis.labelTextColor = colors.primaryTextColor
        xAxis.labelFont = .systemFont(ofSize: 11, weight: .medium)
        xAxis.granularity = 1
        xAxis.labelCount = 7
        xAxis.valueFormatter = WeekDayAxisValueFormatter()
        xAxis.avoidFirstLastClippingEnabled = true
        
        // Y-axis configuration
        let leftAxis = chartView.leftAxis
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = colors.primaryTextColor.withAlphaComponent(0.1)
        leftAxis.gridLineWidth = 0.5
        leftAxis.drawAxisLineEnabled = false
        leftAxis.labelTextColor = colors.primaryTextColor
        leftAxis.labelFont = .systemFont(ofSize: 10, weight: .regular)
        leftAxis.granularity = 5
        leftAxis.axisMinimum = 0
        
        let rightAxis = chartView.rightAxis
        rightAxis.enabled = false
        
        // Enhanced marker configuration
        let marker = BalloonMarker(color: colors.secondaryAccentColor.withAlphaComponent(0.9),
                                 font: .systemFont(ofSize: 12, weight: .medium),
                                 textColor: .white,
                                 insets: UIEdgeInsets(top: 8, left: 8, bottom: 20, right: 8))
        marker.chartView = chartView
        marker.minimumSize = CGSize(width: 80, height: 40)
        chartView.marker = marker
        
        // Accessibility configuration (Phase 4: Feature Parity)
        chartView.isAccessibilityElement = true
        chartView.accessibilityLabel = "Weekly task completion chart"
        chartView.accessibilityHint = "Shows daily task completion scores for the current week. Double tap to zoom, pinch to scale, drag to pan."
        chartView.accessibilityTraits = [.adjustable, .updatesFrequently]
        
        // Animation configuration with enhanced easing
        chartView.animate(xAxisDuration: 0.8, yAxisDuration: 0.8, easingOption: .easeInOutCubic)
    }
    
    private func updateChartData(_ chartView: LineChartView) {
        guard !data.isEmpty else {
            chartView.data = nil
            return
        }
        
        let colors = ToDoColors()
        
        // Calculate dynamic maximum for better scaling
        let dynamicMaximum = ChartDataService.shared.calculateDynamicMaximum(for: data)
        chartView.leftAxis.axisMaximum = dynamicMaximum
        
        // Create and configure data set
        let dataSet = ChartDataService.shared.createLineChartDataSet(with: data, colors: colors)
        
        // Create chart data and apply to chart
        let chartData = LineChartData(dataSet: dataSet)
        chartView.data = chartData
        
        // Animate chart update
        DispatchQueue.main.async {
            chartView.animate(xAxisDuration: 1.2, yAxisDuration: 1.2, easingOption: .easeInOutCubic)
            
            // Add subtle bounce effect after main animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                chartView.animate(yAxisDuration: 0.3, easingOption: .easeOutBack)
            }
        }
        
        // Log chart update for debugging
        print("Chart updated with \(data.count) data points, max score: \(dynamicMaximum)")
    }
}

// MARK: - Task Progress Card
public struct TaskProgressCard: View {
    let referenceDate: Date?
    
    public init(referenceDate: Date? = nil) {
        self.referenceDate = referenceDate
    }
    
    public var body: some View {
        ChartCard(
            title: "Weekly Progress",
            subtitle: "Task completion scores",
            referenceDate: referenceDate
        )
    }
}

// MARK: - Preview
struct ChartCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TaskProgressCard()
            
            ChartCard(
                title: "Custom Chart",
                subtitle: "Custom subtitle"
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}