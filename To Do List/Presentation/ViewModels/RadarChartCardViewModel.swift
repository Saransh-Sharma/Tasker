import Foundation
import Combine
import DGCharts
import SwiftUI

public final class RadarChartCardViewModel: ObservableObject {
    @Published var chartData: [RadarChartDataEntry] = []
    @Published var chartLabels: [String] = []
    @Published var isLoading = true
    @Published var hasCustomProjects = true
    @Published var hasCompletedTasks = true

    private let projectRepository: ProjectRepositoryProtocol
    private let readModelRepository: TaskReadModelRepositoryProtocol?
    private let computeQueue = DispatchQueue(label: "tasker.radarChart.compute", qos: .userInitiated)
    private var cachedWeekStart: Date?
    private var loadGeneration: Int = 0

    /// Initializes a new instance.
    init(
        projectRepository: ProjectRepositoryProtocol,
        readModelRepository: TaskReadModelRepositoryProtocol? = nil
    ) {
        self.projectRepository = projectRepository
        self.readModelRepository = readModelRepository
    }

    /// Executes load.
    func load(referenceDate: Date?, force: Bool = false) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1

        let currentReferenceDate = referenceDate ?? Date.today()
        let week = calendar.daysWithSameWeekOfYear(as: currentReferenceDate)
        guard let startOfWeek = week.first?.startOfDay else {
            isLoading = false
            return
        }

        if !force, cachedWeekStart == startOfWeek, chartLabels.isEmpty == false || chartData.isEmpty == false {
            isLoading = false
            return
        }

        loadGeneration += 1
        let requestedGeneration = loadGeneration
        isLoading = true
        let interval = TaskerPerformanceTrace.begin("RadarChartLoad")

        projectRepository.fetchCustomProjects { [weak self] projectResult in
            guard let self else {
                TaskerPerformanceTrace.end(interval)
                return
            }
            switch projectResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    defer { TaskerPerformanceTrace.end(interval) }
                    guard requestedGeneration == self.loadGeneration else { return }
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
                        defer { TaskerPerformanceTrace.end(interval) }
                        guard requestedGeneration == self.loadGeneration else { return }
                        self.chartData = []
                        self.chartLabels = []
                        self.hasCustomProjects = false
                        self.hasCompletedTasks = false
                        self.cachedWeekStart = nil
                        self.isLoading = false
                    }
                    return
                }

                guard let readModel = self.readModelRepository else {
                    DispatchQueue.main.async {
                        defer { TaskerPerformanceTrace.end(interval) }
                        guard requestedGeneration == self.loadGeneration else { return }
                        logWarning(
                            event: "radar_read_model_missing",
                            message: "Task read-model repository is not configured for radar chart"
                        )
                        self.chartData = []
                        self.chartLabels = []
                        self.hasCustomProjects = true
                        self.hasCompletedTasks = false
                        self.cachedWeekStart = nil
                        self.isLoading = false
                    }
                    return
                }

                readModel.fetchWeekChartProjection(referenceDate: currentReferenceDate) { taskResult in
                    self.computeQueue.async {
                        switch taskResult {
                        case .failure(let error):
                            DispatchQueue.main.async {
                                defer { TaskerPerformanceTrace.end(interval) }
                                guard requestedGeneration == self.loadGeneration else { return }
                                logWarning(
                                    event: "radar_task_fetch_failed",
                                    message: "Failed to fetch tasks for radar chart",
                                    fields: ["error": error.localizedDescription]
                                )
                                self.chartData = []
                                self.chartLabels = []
                                self.hasCustomProjects = true
                                self.hasCompletedTasks = false
                                self.cachedWeekStart = nil
                                self.isLoading = false
                            }
                        case .success(let projection):
                            let sortedProjects = customProjects
                                .sorted { lhs, rhs in
                                    let lhsScore = projection.projectScores[lhs.id, default: 0]
                                    let rhsScore = projection.projectScores[rhs.id, default: 0]
                                    if lhsScore == rhsScore {
                                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                                    }
                                    return lhsScore > rhsScore
                                }
                                .prefix(5)

                            let labels = sortedProjects.map(\.name)
                            let data = sortedProjects.map { project in
                                RadarChartDataEntry(value: Double(projection.projectScores[project.id, default: 0]))
                            }
                            let hasCompletedTasks = data.contains(where: { $0.value > 0 })

                            DispatchQueue.main.async {
                                defer { TaskerPerformanceTrace.end(interval) }
                                guard requestedGeneration == self.loadGeneration else { return }
                                self.chartLabels = labels
                                self.chartData = data
                                self.hasCustomProjects = true
                                self.hasCompletedTasks = hasCompletedTasks
                                self.cachedWeekStart = startOfWeek
                                self.isLoading = false
                            }
                        }
                    }
                }
            }
        }
    }
}
