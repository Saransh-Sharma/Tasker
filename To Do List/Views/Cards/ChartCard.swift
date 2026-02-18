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
    @StateObject private var viewModel: ChartCardViewModel
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    
    init(
        title: String = "Weekly Progress",
        subtitle: String? = "Task completion scores",
        referenceDate: Date? = nil,
        viewModel: ChartCardViewModel
    ) {
        self.title = title
        self.subtitle = subtitle
        self.referenceDate = referenceDate
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.cardPadding) {
                VStack(alignment: .leading, spacing: spacing.titleSubtitleGap) {
                    Text(title)
                        .font(.tasker(.headline))
                        .fontWeight(.semibold)
                        .foregroundColor(.tasker(.textPrimary))
                        .dynamicTypeSize(.large...(.accessibility5))
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.tasker(.caption1))
                            .foregroundColor(.tasker(.textSecondary))
                            .dynamicTypeSize(.large...(.accessibility3))
                    }
                }
                .accessibilityElement(children: .combine)

                ZStack {
                    if viewModel.isLoading {
                        RoundedRectangle(cornerRadius: corner.input)
                            .fill(Color.tasker.surfaceSecondary)
                            .frame(height: 200)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.2)
                            )
                    } else {
                        LineChartViewRepresentable(data: viewModel.chartData, referenceDate: referenceDate)
                            .frame(height: 200)
                            .background(
                                RoundedRectangle(cornerRadius: corner.input)
                                    .fill(Color.tasker.surfacePrimary)
                                    .taskerElevation(.e1, cornerRadius: corner.input, includesBorder: false)
                            )
                    }
                }
            }
        }
        .onAppear {
            viewModel.load(referenceDate: referenceDate)
        }
        .onChange(of: referenceDate) { _, _ in
            viewModel.load(referenceDate: referenceDate)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .homeTaskMutation)
                .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
        ) { _ in
            logDebug("📡 ChartCard: Received HomeTaskMutationEvent - reloading chart data")
            viewModel.load(referenceDate: referenceDate)
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
        let themeTokens = TaskerThemeManager.shared.currentTheme.tokens
        let colors = themeTokens.color
        
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
        xAxis.axisLineColor = colors.divider.withAlphaComponent(0.5)
        xAxis.labelTextColor = colors.textSecondary
        xAxis.labelFont = UIFont.tasker.font(for: .caption2)
        xAxis.granularity = 1
        xAxis.labelCount = 7
        xAxis.valueFormatter = WeekDayAxisValueFormatter()
        xAxis.avoidFirstLastClippingEnabled = true
        
        // Y-axis configuration
        let leftAxis = chartView.leftAxis
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = colors.strokeHairline.withAlphaComponent(0.12)
        leftAxis.gridLineWidth = 0.5
        leftAxis.drawAxisLineEnabled = false
        leftAxis.labelTextColor = colors.textTertiary
        leftAxis.labelFont = UIFont.tasker.font(for: .caption2)
        leftAxis.granularity = 5
        leftAxis.axisMinimum = 0
        
        let rightAxis = chartView.rightAxis
        rightAxis.enabled = false
        
        // Enhanced marker configuration
        let marker = BalloonMarker(color: colors.accentPrimary.withAlphaComponent(0.9),
                                 font: UIFont.tasker.font(for: .caption1),
                                 textColor: colors.textInverse,
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
        
        let themeTokens = TaskerThemeManager.shared.currentTheme.tokens
        let colors = themeTokens.color

        // Calculate dynamic maximum for better scaling
        let maxScore = data.map(\.y).max() ?? 0
        let dynamicMaximum = max(maxScore * 1.2, 10)
        chartView.leftAxis.axisMaximum = dynamicMaximum
        
        // Create and configure data set
        let dataSet = LineChartDataSet(entries: data, label: "Daily Score")
        dataSet.mode = .linear
        dataSet.drawCirclesEnabled = true
        dataSet.lineWidth = 3.5
        dataSet.circleRadius = 6
        dataSet.setCircleColor(colors.accentPrimary)
        dataSet.setColor(colors.chartPrimary)
        dataSet.drawCircleHoleEnabled = true
        dataSet.circleHoleRadius = 3
        dataSet.circleHoleColor = colors.surfacePrimary
        dataSet.valueFont = themeTokens.typography.font(for: .caption2)
        dataSet.valueTextColor = colors.textTertiary

        let gradientColors = [
            colors.chartPrimary.withAlphaComponent(0.35).cgColor,
            colors.chartPrimary.withAlphaComponent(0.18).cgColor,
            colors.chartPrimary.withAlphaComponent(0.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: [0.0, 0.5, 1.0])!
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.5
        dataSet.lineDashLengths = nil
        dataSet.highlightEnabled = true
        dataSet.highlightColor = colors.accentPrimary
        dataSet.highlightLineWidth = 2
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.drawVerticalHighlightIndicatorEnabled = true
        
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
        logDebug("Chart updated with \(data.count) data points, max score: \(dynamicMaximum)")
    }
}

// MARK: - Task Progress Card
public struct TaskProgressCard: View {
    let referenceDate: Date?
    let viewModel: ChartCardViewModel
    
    init(referenceDate: Date? = nil, viewModel: ChartCardViewModel) {
        self.referenceDate = referenceDate
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ChartCard(
            title: "Weekly Progress",
            subtitle: "Task completion scores",
            referenceDate: referenceDate,
            viewModel: viewModel
        )
    }
}

// MARK: - Preview
struct ChartCard_Previews: PreviewProvider {
    static var previews: some View {
        let previewRepository = PreviewTaskRepository()
        let viewModel = ChartCardViewModel(taskRepository: previewRepository)
        VStack(spacing: 20) {
            TaskProgressCard(viewModel: viewModel)
            
            ChartCard(
                title: "Custom Chart",
                subtitle: "Custom subtitle",
                viewModel: viewModel
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}

private final class PreviewTaskRepository: TaskRepositoryProtocol {
    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) { completion(.success(nil)) }
    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) { completion(.success(task)) }
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) { completion(.success(task)) }
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
}
