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

    init(
        projectRepository: ProjectRepositoryProtocol,
        readModelRepository: TaskReadModelRepositoryProtocol? = nil
    ) {
        self.projectRepository = projectRepository
        self.readModelRepository = readModelRepository
    }

    func load(referenceDate: Date?) {
        isLoading = true

        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1

        let currentReferenceDate = referenceDate ?? Date.today()
        let week = calendar.daysWithSameWeekOfYear(as: currentReferenceDate)
        guard let startOfWeek = week.first?.startOfDay,
              let endOfWeek = week.last?.endOfDay else {
            isLoading = false
            return
        }

        projectRepository.fetchCustomProjects { [weak self] projectResult in
            guard let self else { return }
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

                guard let readModel = self.readModelRepository else {
                    DispatchQueue.main.async {
                        logWarning(
                            event: "radar_read_model_missing",
                            message: "Task read-model repository is not configured for radar chart"
                        )
                        self.chartData = []
                        self.chartLabels = []
                        self.hasCustomProjects = true
                        self.hasCompletedTasks = false
                        self.isLoading = false
                    }
                    return
                }

                readModel.fetchProjectCompletionScoreTotals(from: startOfWeek, to: endOfWeek) { taskResult in
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
                        case .success(let scoreByProjectID):
                            let customProjectIDs = Set(customProjects.map(\.id))

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
