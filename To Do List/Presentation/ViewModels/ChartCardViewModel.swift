import Foundation
import Combine
import DGCharts
import SwiftUI

public final class ChartCardViewModel: ObservableObject {
    @Published var chartData: [ChartDataEntry] = []
    @Published var isLoading = true

    private let readModelRepository: TaskReadModelRepositoryProtocol?

    init(
        readModelRepository: TaskReadModelRepositoryProtocol? = nil
    ) {
        self.readModelRepository = readModelRepository
    }

    func load(referenceDate: Date?) {
        isLoading = true
        guard let readModel = readModelRepository else {
            logWarning(
                event: "chart_card_read_model_missing",
                message: "Task read-model repository is not configured for chart card"
            )
            chartData = []
            isLoading = false
            return
        }

        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1

        let currentReferenceDate = referenceDate ?? Date.today()
        let week = calendar.daysWithSameWeekOfYear(as: currentReferenceDate)
        guard let weekStart = week.first?.startOfDay,
              let weekEnd = week.last?.endOfDay else {
            isLoading = false
            return
        }

        let loadTasks: (@escaping (Result<[TaskDefinition], Error>) -> Void) -> Void = { handler in
            readModel.fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    dueDateStart: weekStart,
                    dueDateEnd: weekEnd,
                    sortBy: .dueDateAscending,
                    limit: 2_000,
                    offset: 0
                )
            ) { handler($0.map(\.tasks)) }
        }

        loadTasks { [weak self] result in
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
