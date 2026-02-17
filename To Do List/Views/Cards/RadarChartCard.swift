//
//  RadarChartCard.swift
//  To Do List
//
//  Created by Assistant on Radar Chart Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import SwiftUI
import DGCharts
import UIKit
import Combine

// MARK: - Radar Chart Card

struct RadarChartCard: View {
    let title: String
    let subtitle: String?
    let referenceDate: Date?

    @State private var chartData: [RadarChartDataEntry] = []
    @State private var chartLabels: [String] = []
    @State private var isLoading = true
    @State private var hasCustomProjects = true
    @State private var hasCompletedTasks = true
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    init(title: String = "Project Breakdown", subtitle: String? = "Weekly scores by project", referenceDate: Date? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.referenceDate = referenceDate
    }

    var body: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.titleSubtitleGap) {
                HStack {
                    VStack(alignment: .leading, spacing: spacing.s2) {
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
                }
                .accessibilityElement(children: .contain)

                ZStack {
                    if isLoading {
                        RoundedRectangle(cornerRadius: corner.input)
                            .fill(Color.tasker.surfaceSecondary)
                            .frame(height: 350)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.2)
                            )
                    } else if !hasCustomProjects {
                        emptyStateView(
                            icon: "folder.badge.plus",
                            title: "No Custom Projects",
                            message: "Create custom projects to see your score breakdown",
                            actionTitle: "Create Project",
                            action: {
                                NotificationCenter.default.post(name: Notification.Name("ShowProjectManagement"), object: nil)
                            }
                        )
                    } else if !hasCompletedTasks {
                        emptyStateView(
                            icon: "checkmark.circle",
                            title: "Complete Tasks",
                            message: "Complete tasks in custom projects to see insights",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        RadarChartViewRepresentable(
                            data: chartData,
                            labels: chartLabels,
                            referenceDate: referenceDate
                        )
                        .frame(height: 350)
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
            loadChartData()
        }
        .onChange(of: referenceDate) { _, _ in
            loadChartData()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .homeTaskMutation)
                .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
        ) { _ in
            loadChartData()
        }
    }

    // MARK: - Empty State View

    private func emptyStateView(
        icon: String,
        title: String,
        message: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: spacing.cardPadding) {
            Image(systemName: icon)
                .font(.tasker(.title1))
                .foregroundColor(.tasker(.textTertiary))

            VStack(spacing: spacing.s8) {
                Text(title)
                    .font(.tasker(.headline))
                    .foregroundColor(.tasker(.textPrimary))

                Text(message)
                    .font(.tasker(.callout))
                    .foregroundColor(.tasker(.textSecondary))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, spacing.s24)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.tasker(.buttonSmall))
                        .fontWeight(.semibold)
                        .foregroundColor(.tasker(.accentOnPrimary))
                        .padding(.horizontal, spacing.s24)
                        .padding(.vertical, spacing.s12)
                        .background(Color.tasker.accentPrimary)
                        .cornerRadius(corner.input)
                }
                .padding(.top, spacing.s8)
            }
        }
        .frame(height: 350)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: corner.input)
                .fill(Color.tasker.surfacePrimary)
        )
    }

    // MARK: - Data Loading

    private func loadChartData() {
        isLoading = true
        guard let taskRepository = EnhancedDependencyContainer.shared.taskRepository else {
            isLoading = false
            return
        }

        guard let projectRepository = EnhancedDependencyContainer.shared.projectRepository else {
            isLoading = false
            return
        }
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1

        let currentReferenceDate = referenceDate ?? Date.today()
        let week = calendar.daysWithSameWeekOfYear(as: currentReferenceDate)
        guard let startOfWeek = week.first?.startOfDay,
              let endOfWeek = week.last?.endOfDay else {
            isLoading = false
            return
        }

        projectRepository.fetchCustomProjects { projectResult in
            switch projectResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    logWarning(
                        event: "radar_project_fetch_failed",
                        message: "Failed to fetch projects for radar chart",
                        fields: ["error": error.localizedDescription]
                    )
                    self.chartData = []
                    self.chartLabels = []
                    self.hasCustomProjects = false
                    self.hasCompletedTasks = false
                    self.isLoading = false
                }
            case .success(let projects):
                let customProjects = projects.filter { !$0.isArchived && !$0.isInbox }
                guard customProjects.isEmpty == false else {
                    DispatchQueue.main.async {
                        self.chartData = []
                        self.chartLabels = []
                        self.hasCustomProjects = false
                        self.hasCompletedTasks = false
                        withAnimation(TaskerAnimation.gentle) {
                            self.isLoading = false
                        }
                    }
                    return
                }

                taskRepository.fetchAllTasks { taskResult in
                    DispatchQueue.main.async {
                        switch taskResult {
                        case .failure(let error):
                            logWarning(
                                event: "radar_task_fetch_failed",
                                message: "Failed to fetch tasks for radar chart",
                                fields: ["error": error.localizedDescription]
                            )
                            self.chartData = []
                            self.chartLabels = []
                            self.hasCustomProjects = true
                            self.hasCompletedTasks = false
                            self.isLoading = false
                        case .success(let tasks):
                            var scoreByProjectID: [UUID: Int] = [:]
                            let customProjectIDs = Set(customProjects.map(\.id))

                            for task in tasks where task.isComplete {
                                guard customProjectIDs.contains(task.projectID) else { continue }
                                guard let completedAt = task.dateCompleted else { continue }
                                guard completedAt >= startOfWeek && completedAt <= endOfWeek else { continue }
                                scoreByProjectID[task.projectID, default: 0] += task.priority.scorePoints
                            }

                            let sortedProjects = customProjects
                                .sorted { lhs, rhs in
                                    let lhsScore = scoreByProjectID[lhs.id, default: 0]
                                    let rhsScore = scoreByProjectID[rhs.id, default: 0]
                                    if lhsScore == rhsScore {
                                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                                    }
                                    return lhsScore > rhsScore
                                }
                                .prefix(5)

                            self.chartLabels = sortedProjects.map(\.name)
                            self.chartData = sortedProjects.map { project in
                                RadarChartDataEntry(value: Double(scoreByProjectID[project.id, default: 0]))
                            }
                            self.hasCustomProjects = true
                            self.hasCompletedTasks = self.chartData.contains(where: { $0.value > 0 })

                            withAnimation(TaskerAnimation.gentle) {
                                self.isLoading = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Radar Chart View Representable

struct RadarChartViewRepresentable: UIViewRepresentable {
    let data: [RadarChartDataEntry]
    let labels: [String]
    let referenceDate: Date?

    func makeUIView(context: Context) -> RadarChartView {
        let chartView = RadarChartView()
        setupChartView(chartView)
        return chartView
    }

    func updateUIView(_ uiView: RadarChartView, context: Context) {
        updateChartData(uiView)
    }

    private func setupChartView(_ chartView: RadarChartView) {
        let themeTokens = TaskerThemeManager.shared.currentTheme.tokens
        let colors = themeTokens.color

        // Chart configuration
        chartView.backgroundColor = UIColor.clear
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false
        chartView.rotationAngle = 180

        // Extremely aggressive negative offsets to eliminate white space above/below polygon
        chartView.setExtraOffsets(left: -30, top: -60, right: -30, bottom: -60)
        chartView.minOffset = 0

        // Web configuration
        chartView.webLineWidth = 1.0
        chartView.innerWebLineWidth = 0.75
        chartView.webColor = colors.divider.withAlphaComponent(0.15)
        chartView.innerWebColor = colors.strokeHairline.withAlphaComponent(0.12)
        chartView.webAlpha = 1.0

        // Interaction
        chartView.rotationEnabled = false
        chartView.highlightPerTapEnabled = true

        // Y-axis (radial axis)
        let yAxis = chartView.yAxis
        yAxis.labelFont = UIFont.tasker.font(for: .caption1)
        yAxis.labelCount = 5
        yAxis.axisMinimum = 0
        yAxis.drawLabelsEnabled = false
        yAxis.labelTextColor = colors.textTertiary
        yAxis.spaceTop = 0
        yAxis.spaceBottom = 0

        // X-axis (angular axis - project names)
        let xAxis = chartView.xAxis
        xAxis.labelFont = UIFont.tasker.font(for: .caption1)
        xAxis.xOffset = 0
        xAxis.yOffset = 0
        xAxis.labelTextColor = colors.textSecondary
        xAxis.valueFormatter = RadarXAxisFormatter(labels: labels)

        // Accessibility
        chartView.isAccessibilityElement = true
        chartView.accessibilityLabel = "Project breakdown radar chart"
        chartView.accessibilityHint = "Shows weekly scores across your custom projects"
        chartView.accessibilityTraits = [.updatesFrequently]
        chartView.accessibilityIdentifier = "home.radarChartView"
    }

    private func updateChartData(_ chartView: RadarChartView) {
        let normalizedPayload = normalizedRenderPayload()
        guard !normalizedPayload.entries.isEmpty else {
            chartView.data = nil
            return
        }

        let themeTokens = TaskerThemeManager.shared.currentTheme.tokens
        let colors = themeTokens.color

        // Calculate dynamic maximum
        let maxValue = normalizedPayload.entries.map(\.value).max() ?? 0
        let dynamicMaximum = max(ceil(maxValue / 5) * 5, 5)
        chartView.yAxis.axisMaximum = dynamicMaximum

        // Rebuild renderer to prevent stale accessibility label caches inside DGCharts.
        chartView.renderer = RadarChartRenderer(
            chart: chartView,
            animator: chartView.chartAnimator,
            viewPortHandler: chartView.viewPortHandler
        )

        // Update X-axis labels
        chartView.xAxis.valueFormatter = RadarXAxisFormatter(labels: normalizedPayload.labels)

        // Create data set
        let dataSet = RadarChartDataSet(entries: normalizedPayload.entries, label: "Project Scores")
        dataSet.setColor(colors.accentPrimary)
        dataSet.fillColor = colors.accentMuted
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.3
        dataSet.lineWidth = 4.0
        dataSet.drawHighlightCircleEnabled = true
        dataSet.setDrawHighlightIndicators(false)
        dataSet.valueFont = themeTokens.typography.font(for: .caption1)
        dataSet.valueTextColor = colors.textSecondary
        dataSet.drawValuesEnabled = true

        // Create chart data
        let radarData = RadarChartData(dataSet: dataSet)
        chartView.data = radarData
        chartView.notifyDataSetChanged()

        // Animate chart
        DispatchQueue.main.async {
            chartView.animate(yAxisDuration: 1.0, easingOption: .easeOutBack)
        }

    }

    private func normalizedRenderPayload() -> (entries: [RadarChartDataEntry], labels: [String]) {
        let pairedCount = min(data.count, labels.count)
        if data.count != labels.count {
            logWarning(
                event: "radar_data_label_count_mismatch",
                message: "Radar chart data/label counts differ; trimming to safe paired payload",
                fields: [
                    "entry_count": String(data.count),
                    "label_count": String(labels.count),
                    "paired_count": String(pairedCount)
                ]
            )
        }

        guard pairedCount > 0 else {
            return ([], [])
        }

        let pairedEntries = Array(data.prefix(pairedCount))
        let pairedLabels = Array(labels.prefix(pairedCount))
        return (pairedEntries, pairedLabels)
    }
}

// MARK: - Radar X-Axis Formatter

class RadarXAxisFormatter: AxisValueFormatter {
    private let labels: [String]

    init(labels: [String]) {
        self.labels = labels
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let index = Int(value)
        guard index >= 0 && index < labels.count else {
            return ""
        }
        return labels[index]
    }
}

// MARK: - Preview

struct RadarChartCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            RadarChartCard()

            RadarChartCard(
                title: "Custom Radar",
                subtitle: "Custom subtitle"
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
