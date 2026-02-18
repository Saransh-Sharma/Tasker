import Foundation
import Combine
import DGCharts
import SwiftUI

public final class ChartCardViewModel: ObservableObject {
    @Published var chartData: [ChartDataEntry] = []
    @Published var isLoading = true

    private let taskRepository: TaskRepositoryProtocol

    init(taskRepository: TaskRepositoryProtocol) {
        self.taskRepository = taskRepository
    }

    func load(referenceDate: Date?) {
        isLoading = true

        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1

        let currentReferenceDate = referenceDate ?? Date.today()
        let week = calendar.daysWithSameWeekOfYear(as: currentReferenceDate)
        guard let weekStart = week.first?.startOfDay,
              let weekEnd = week.last?.endOfDay else {
            isLoading = false
            return
        }

        taskRepository.fetchTasks(from: weekStart, to: weekEnd) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let tasks):
                    let today = Date.today().startOfDay
                    var dayScores: [Date: Int] = [:]
                    for task in tasks where task.isComplete {
                        guard let completedDay = task.dateCompleted?.startOfDay else { continue }
                        dayScores[completedDay, default: 0] += task.priority.scorePoints
                    }

                    self.chartData = week.enumerated().map { index, day in
                        let score: Int
                        if day.startOfDay > today {
                            score = 0
                        } else {
                            score = max(0, dayScores[day.startOfDay] ?? 0)
                        }
                        return ChartDataEntry(x: Double(index), y: Double(score))
                    }
                    withAnimation(TaskerAnimation.gentle) {
                        self.isLoading = false
                    }
                case .failure(let error):
                    logWarning(
                        event: "chart_card_fetch_failed",
                        message: "Failed to fetch weekly tasks for chart card",
                        fields: ["error": error.localizedDescription]
                    )
                    self.chartData = []
                    self.isLoading = false
                }
            }
        }
    }
}
