//
//  RadarChartCard.swift
//  To Do List
//
//  Created by Assistant on Radar Chart Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import SwiftUI
import CoreData
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
    @State private var showProjectSelection = false
    @State private var selectedProjectIDs: [UUID]? = nil
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

                    Spacer()

                    if hasCustomProjects {
                        Button(action: {
                            showProjectSelection = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.tasker(.buttonSmall))
                                .foregroundColor(.tasker(.accentPrimary))
                                .padding(spacing.s8)
                                .background(Color.tasker.accentMuted)
                                .cornerRadius(corner.r1)
                        }
                        .accessibilityLabel("Select projects")
                        .accessibilityHint("Choose which projects to display on the radar chart")
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
        .sheet(isPresented: $showProjectSelection) {
            ProjectSelectionSheet(
                selectedProjectIDs: selectedProjectIDs ?? [],
                onSave: { pinnedProjectIDs in
                    selectedProjectIDs = pinnedProjectIDs

                    // Persist pinned projects using ProjectSelectionService
                    if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
                        let service = ProjectSelectionService(context: context)
                        do {
                            try service.setPinnedProjectIDs(pinnedProjectIDs)
                        } catch {
                            logWarning(
                                event: "radar_pinned_projects_save_failed",
                                message: "Failed to save pinned projects",
                                fields: ["error": error.localizedDescription]
                            )
                        }
                    }

                    // Reload chart with new pinned projects
                    loadChartData()
                }
            )
        }
        .onAppear {
            loadPinnedProjects()
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

    /// Load pinned projects from ProjectSelectionService
    /// Called once on appear to initialize selectedProjectIDs
    private func loadPinnedProjects() {

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            logWarning(
                event: "radar_app_delegate_unavailable",
                message: "App delegate unavailable while loading pinned projects"
            )
            loadChartData()
            return
        }

        let context = appDelegate.persistentContainer.viewContext
        let service = ProjectSelectionService(context: context)

        service.getPinnedProjectIDs { [self] pinnedIDs in
            DispatchQueue.main.async {
                self.selectedProjectIDs = pinnedIDs
                self.loadChartData()
            }
        }
    }

    private func loadChartData() {
        isLoading = true

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            logWarning(
                event: "radar_app_delegate_unavailable",
                message: "App delegate unavailable while loading radar chart"
            )
            isLoading = false
            return
        }

        let context = appDelegate.persistentContainer.viewContext

        // Execute on main context directly (SwiftUI is already on main thread)
        let chartService = ChartDataService(context: context)

        // Generate radar chart data ONLY for selected/pinned projects
        let result = chartService.generateRadarChartData(
            for: referenceDate,
            selectedProjectIDs: selectedProjectIDs
        )


        self.chartData = result.entries
        self.chartLabels = result.labels

        // Determine empty states

        let checkResult = self.checkHasCustomProjects(context: context)

        self.hasCustomProjects = !result.labels.isEmpty || checkResult

        self.hasCompletedTasks = !result.entries.isEmpty && result.entries.contains(where: { $0.value > 0 })

        if !self.hasCustomProjects {
        } else if !self.hasCompletedTasks {
        } else {
        }

        withAnimation(TaskerAnimation.gentle) {
            self.isLoading = false
        }

    }

    private func checkHasCustomProjects(context: NSManagedObjectContext) -> Bool {

        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        request.predicate = NSPredicate(
            format: "projectID != %@",
            ProjectConstants.inboxProjectID as CVarArg
        )
        request.fetchLimit = 1

        let count = (try? context.count(for: request)) ?? 0

        return count > 0
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
    }

    private func updateChartData(_ chartView: RadarChartView) {
        guard !data.isEmpty else {
            chartView.data = nil
            return
        }

        let themeTokens = TaskerThemeManager.shared.currentTheme.tokens
        let colors = themeTokens.color

        // Use ChartDataService for consistent styling
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let chartService = ChartDataService(context: context!)

        // Calculate dynamic maximum
        let dynamicMaximum = chartService.calculateRadarChartMaximum(for: data)
        chartView.yAxis.axisMaximum = dynamicMaximum

        // Update X-axis labels
        chartView.xAxis.valueFormatter = RadarXAxisFormatter(labels: labels)

        // Create data set
        let dataSet = chartService.createRadarChartDataSet(
            with: data,
            colors: colors,
            typography: themeTokens.typography
        )

        // Create chart data
        let radarData = RadarChartData(dataSet: dataSet)
        chartView.data = radarData

        // Animate chart
        DispatchQueue.main.async {
            chartView.animate(yAxisDuration: 1.0, easingOption: .easeOutBack)
        }

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
