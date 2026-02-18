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

    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol

    init(taskRepository: TaskRepositoryProtocol, projectRepository: ProjectRepositoryProtocol) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
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

                self.taskRepository.fetchAllTasks { taskResult in
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
