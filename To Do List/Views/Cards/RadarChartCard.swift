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

    init(title: String = "Project Breakdown", subtitle: String? = "Weekly scores by project", referenceDate: Date? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.referenceDate = referenceDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with project selection button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .dynamicTypeSize(.large...(.accessibility5))
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .dynamicTypeSize(.large...(.accessibility3))
                    }
                }

                Spacer()

                // Project selection button (show if has custom projects, regardless of chart data)
                // This allows users to change pinned projects even if current selection has no data
                if hasCustomProjects {
                    Button(action: {
                        showProjectSelection = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("Select projects")
                    .accessibilityHint("Choose which projects to display on the radar chart")
                }
            }
            .accessibilityElement(children: .contain)

            // Chart Container
            ZStack {
                if isLoading {
                    // Loading state
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 350)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                        )
                } else if !hasCustomProjects {
                    // Empty state: No custom projects
                    emptyStateView(
                        icon: "folder.badge.plus",
                        title: "No Custom Projects",
                        message: "Create custom projects to see your score breakdown",
                        actionTitle: "Create Project",
                        action: {
                            // Navigate to project creation
                            NotificationCenter.default.post(name: Notification.Name("ShowProjectManagement"), object: nil)
                        }
                    )
                } else if !hasCompletedTasks {
                    // Empty state: No completed tasks in custom projects
                    emptyStateView(
                        icon: "checkmark.circle",
                        title: "Complete Tasks",
                        message: "Complete tasks in custom projects to see insights",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    // Radar chart view
                    RadarChartViewRepresentable(
                        data: chartData,
                        labels: chartLabels,
                        referenceDate: referenceDate
                    )
                    .frame(height: 350)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .sheet(isPresented: $showProjectSelection) {
            ProjectSelectionSheet(
                selectedProjectIDs: selectedProjectIDs ?? [],
                onSave: { pinnedProjectIDs in
                    print("📌 [RadarChartCard] Received \(pinnedProjectIDs.count) pinned projects from sheet")
                    selectedProjectIDs = pinnedProjectIDs

                    // Persist pinned projects using ProjectSelectionService
                    if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
                        let service = ProjectSelectionService(context: context)
                        do {
                            try service.setPinnedProjectIDs(pinnedProjectIDs)
                            print("📌 [RadarChartCard] Successfully saved pinned projects")
                        } catch {
                            print("⚠️ [RadarChartCard] Failed to save pinned projects: \(error)")
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
        .onChange(of: referenceDate) { _ in
            loadChartData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TaskCompletionChanged"))) { _ in
            print("📡 RadarChartCard: Received TaskCompletionChanged - reloading chart data")
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
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .frame(height: 350)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Data Loading

    /// Load pinned projects from ProjectSelectionService
    /// Called once on appear to initialize selectedProjectIDs
    private func loadPinnedProjects() {
        print("📌 [RADAR CARD] Loading pinned projects...")

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            print("⚠️ [RADAR CARD] Failed to get AppDelegate")
            loadChartData()
            return
        }

        let context = appDelegate.persistentContainer.viewContext
        let service = ProjectSelectionService(context: context)

        service.getPinnedProjectIDs { [self] pinnedIDs in
            DispatchQueue.main.async {
                print("📌 [RADAR CARD] Loaded \(pinnedIDs.count) pinned projects: \(pinnedIDs)")
                self.selectedProjectIDs = pinnedIDs
                self.loadChartData()
            }
        }
    }

    private func loadChartData() {
        print("🎨 [RADAR CARD] loadChartData() called with selectedProjectIDs: \(selectedProjectIDs?.count ?? 0)")
        isLoading = true

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            print("⚠️ [RADAR CARD] Failed to get AppDelegate")
            isLoading = false
            return
        }

        let context = appDelegate.persistentContainer.viewContext
        print("🎨 [RADAR CARD] Got viewContext: \(context)")

        // Execute on main context directly (SwiftUI is already on main thread)
        let chartService = ChartDataService(context: context)
        print("🎨 [RADAR CARD] Created ChartDataService")

        // Generate radar chart data ONLY for selected/pinned projects
        let result = chartService.generateRadarChartData(
            for: referenceDate,
            selectedProjectIDs: selectedProjectIDs
        )

        print("🎨 [RADAR CARD] Generated data: \(result.entries.count) entries, \(result.labels.count) labels")

        self.chartData = result.entries
        self.chartLabels = result.labels

        // Determine empty states
        print("🎨 [RADAR CARD] ==================")
        print("🎨 [RADAR CARD] Determining empty states:")
        print("   result.labels count: \(result.labels.count)")
        print("   result.labels: \(result.labels)")
        print("   result.entries count: \(result.entries.count)")
        print("   result.labels.isEmpty: \(result.labels.isEmpty)")

        let checkResult = self.checkHasCustomProjects(context: context)
        print("   checkHasCustomProjects() returned: \(checkResult)")

        self.hasCustomProjects = !result.labels.isEmpty || checkResult
        print("   FINAL hasCustomProjects: \(self.hasCustomProjects) (from: !labels.isEmpty[\(!result.labels.isEmpty)] OR checkResult[\(checkResult)])")

        self.hasCompletedTasks = !result.entries.isEmpty && result.entries.contains(where: { $0.value > 0 })
        print("   FINAL hasCompletedTasks: \(self.hasCompletedTasks)")

        if !self.hasCustomProjects {
            print("   ❌ UI STATE: Will show 'No Custom Projects' empty state")
        } else if !self.hasCompletedTasks {
            print("   ⚠️ UI STATE: Will show 'Complete Tasks' empty state")
        } else {
            print("   ✅ UI STATE: Will show radar chart with \(result.entries.count) projects")
        }
        print("🎨 [RADAR CARD] ==================")

        withAnimation(.easeInOut(duration: 0.3)) {
            self.isLoading = false
        }

        print("📊 Radar Chart loaded \(result.entries.count) projects")
    }

    private func checkHasCustomProjects(context: NSManagedObjectContext) -> Bool {
        print("🔍 [CHECK PROJECTS] ==================")
        print("🔍 [CHECK PROJECTS] Inbox UUID to exclude: \(ProjectConstants.inboxProjectID.uuidString)")

        // Fetch ALL projects first to see what we have
        let allRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
        let allProjects = (try? context.fetch(allRequest)) ?? []
        print("🔍 [CHECK PROJECTS] Total projects in DB: \(allProjects.count)")

        for (index, project) in allProjects.enumerated() {
            let hasID = project.projectID != nil
            let projectID = project.projectID?.uuidString ?? "NIL"
            let projectName = project.projectName ?? "NIL"
            let isInbox = project.projectID == ProjectConstants.inboxProjectID
            print("   Project \(index+1): '\(projectName)' | hasUUID: \(hasID) | UUID: \(projectID) | isInbox: \(isInbox)")
        }

        // Now run the actual filter
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        request.predicate = NSPredicate(
            format: "projectID != %@",
            ProjectConstants.inboxProjectID as CVarArg
        )
        request.fetchLimit = 1

        let count = (try? context.count(for: request)) ?? 0
        print("🔍 [CHECK PROJECTS] Predicate: \(request.predicate?.predicateFormat ?? "none")")
        print("🔍 [CHECK PROJECTS] Custom projects count (with filter): \(count)")
        print("🔍 [CHECK PROJECTS] Returning: \(count > 0)")
        print("🔍 [CHECK PROJECTS] ==================")

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
        let colors = ToDoColors()

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
        chartView.webColor = colors.primaryTextColor.withAlphaComponent(0.2)
        chartView.innerWebColor = colors.primaryTextColor.withAlphaComponent(0.1)
        chartView.webAlpha = 1.0

        // Interaction
        chartView.rotationEnabled = false
        chartView.highlightPerTapEnabled = true

        // Y-axis (radial axis)
        let yAxis = chartView.yAxis
        yAxis.labelFont = .systemFont(ofSize: 12, weight: .regular)
        yAxis.labelCount = 5
        yAxis.axisMinimum = 0
        yAxis.drawLabelsEnabled = false
        yAxis.labelTextColor = colors.primaryTextColor
        yAxis.spaceTop = 0
        yAxis.spaceBottom = 0

        // X-axis (angular axis - project names)
        let xAxis = chartView.xAxis
        xAxis.labelFont = .systemFont(ofSize: 14, weight: .medium)
        xAxis.xOffset = 0
        xAxis.yOffset = 0
        xAxis.labelTextColor = colors.primaryTextColor
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

        let colors = ToDoColors()

        // Use ChartDataService for consistent styling
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let chartService = ChartDataService(context: context!)

        // Calculate dynamic maximum
        let dynamicMaximum = chartService.calculateRadarChartMaximum(for: data)
        chartView.yAxis.axisMaximum = dynamicMaximum

        // Update X-axis labels
        chartView.xAxis.valueFormatter = RadarXAxisFormatter(labels: labels)

        // Create data set
        let dataSet = chartService.createRadarChartDataSet(with: data, colors: colors)

        // Create chart data
        let radarData = RadarChartData(dataSet: dataSet)
        chartView.data = radarData

        // Animate chart
        DispatchQueue.main.async {
            chartView.animate(yAxisDuration: 1.0, easingOption: .easeOutBack)
        }

        print("Radar chart updated with \(data.count) projects, max score: \(dynamicMaximum)")
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
