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

// MARK: - Radar Chart Card

struct RadarChartCard: View {
    let title: String
    let subtitle: String?
    let referenceDate: Date?
    let onCreateProject: () -> Void
    @StateObject private var viewModel: RadarChartCardViewModel
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    /// Initializes a new instance.
    init(
        title: String = "Project Breakdown",
        subtitle: String? = "Weekly scores by project",
        referenceDate: Date? = nil,
        onCreateProject: @escaping () -> Void,
        viewModel: RadarChartCardViewModel
    ) {
        self.title = title
        self.subtitle = subtitle
        self.referenceDate = referenceDate
        self.onCreateProject = onCreateProject
        _viewModel = StateObject(wrappedValue: viewModel)
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
                    if viewModel.isLoading {
                        RoundedRectangle(cornerRadius: corner.input)
                            .fill(Color.tasker.surfaceSecondary)
                            .frame(height: 350)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.2)
                            )
                    } else if !viewModel.hasCustomProjects {
                        emptyStateView(
                            icon: "folder.badge.plus",
                            title: "No Custom Projects",
                            message: "Create custom projects to see your score breakdown",
                            actionTitle: "Create Project",
                            action: onCreateProject
                        )
                    } else if !viewModel.hasCompletedTasks {
                        emptyStateView(
                            icon: "checkmark.circle",
                            title: "Complete Tasks",
                            message: "Complete tasks in custom projects to see insights",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        RadarChartViewRepresentable(
                            data: viewModel.chartData,
                            labels: viewModel.chartLabels,
                            referenceDate: referenceDate
                        )
                        .frame(height: 350)
                        .taskerDenseSurface(
                            cornerRadius: corner.input,
                            fillColor: Color.tasker.surfacePrimary,
                            strokeColor: Color.tasker.strokeHairline
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
        ) { notification in
            guard let payload = HomeTaskMutationPayload(notification: notification) else {
                viewModel.load(referenceDate: referenceDate, force: true)
                return
            }
            guard ChartInvalidationPolicy.shouldRefreshRadarChart(
                for: payload,
                referenceDate: referenceDate ?? Date.today()
            ) else {
                return
            }
            viewModel.load(referenceDate: referenceDate, force: true)
        }
    }

    // MARK: - Empty State View

    /// Executes emptyStateView.
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

}

// MARK: - Radar Chart View Representable

struct RadarChartViewRepresentable: UIViewRepresentable {
    let data: [RadarChartDataEntry]
    let labels: [String]
    let referenceDate: Date?

    /// Executes makeUIView.
    func makeUIView(context: Context) -> RadarChartView {
        let chartView = RadarChartView()
        setupChartView(chartView)
        return chartView
    }

    /// Executes updateUIView.
    func updateUIView(_ uiView: RadarChartView, context: Context) {
        updateChartData(uiView)
    }

    /// Executes setupChartView.
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

    /// Executes updateChartData.
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

    /// Executes normalizedRenderPayload.
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

    /// Initializes a new instance.
    init(labels: [String]) {
        self.labels = labels
    }

    /// Executes stringForValue.
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
        let previewReadModel = PreviewRadarReadModelRepository()
        let previewProjectRepository = PreviewRadarProjectRepository()
        let viewModel = RadarChartCardViewModel(
            projectRepository: previewProjectRepository,
            readModelRepository: previewReadModel
        )
        VStack(spacing: 20) {
            RadarChartCard(
                onCreateProject: {},
                viewModel: viewModel
            )

            RadarChartCard(
                title: "Custom Radar",
                subtitle: "Custom subtitle",
                onCreateProject: {},
                viewModel: viewModel
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}

private final class PreviewRadarReadModelRepository: TaskReadModelRepositoryProtocol {
    /// Executes fetchTasks.
    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    /// Executes searchTasks.
    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    /// Executes fetchProjectTaskCounts.
    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    ) {
        completion(.success([:]))
    }

    /// Executes fetchProjectCompletionScoreTotals.
    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    ) {
        completion(.success([:]))
    }
}

private final class PreviewRadarProjectRepository: ProjectRepositoryProtocol {
    /// Executes fetchAllProjects.
    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success([])) }
    /// Executes fetchProject.
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    /// Executes fetchProject.
    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    /// Executes fetchInboxProject.
    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    /// Executes fetchCustomProjects.
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success([])) }
    /// Executes createProject.
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(project)) }
    /// Executes ensureInboxProject.
    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    /// Executes repairProjectIdentityCollisions.
    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }
    /// Executes updateProject.
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(project)) }
    /// Executes renameProject.
    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    /// Executes deleteProject.
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    /// Executes getTaskCount.
    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) { completion(.success(0)) }
    /// Executes moveTasks.
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    /// Executes isProjectNameAvailable.
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(true)) }
}
