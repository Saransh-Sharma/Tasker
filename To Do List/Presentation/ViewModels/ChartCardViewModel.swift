import Foundation
import Combine
import DGCharts
import SwiftUI

public final class ChartCardViewModel: ObservableObject {
    @Published var chartData: [ChartDataEntry] = []
    @Published var isLoading = true

    private let readModelRepository: TaskReadModelRepositoryProtocol?
    private let computeQueue = DispatchQueue(label: "tasker.chartCard.compute", qos: .userInitiated)
    private var cachedWeekStart: Date?
    private var loadGeneration: Int = 0

    /// Initializes a new instance.
    init(
        readModelRepository: TaskReadModelRepositoryProtocol? = nil
    ) {
        self.readModelRepository = readModelRepository
    }

    /// Executes load.
    func load(referenceDate: Date?, force: Bool = false) {
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
        guard let weekStart = week.first?.startOfDay else {
            isLoading = false
            return
        }

        if !force, cachedWeekStart == weekStart, chartData.isEmpty == false {
            isLoading = false
            return
        }

        loadGeneration += 1
        let requestedGeneration = loadGeneration
        isLoading = true
        let interval = TaskerPerformanceTrace.begin("ChartCardLoad")

        readModel.fetchWeekChartProjection(referenceDate: currentReferenceDate) { [weak self] result in
            guard let self else {
                TaskerPerformanceTrace.end(interval)
                return
            }
            self.computeQueue.async {
                let payload: [ChartDataEntry]
                switch result {
                case .success(let projection):
                    let today = Date.today().startOfDay
                    payload = week.enumerated().map { index, day in
                        let score: Int
                        if day.startOfDay > today {
                            score = 0
                        } else {
                            score = max(0, projection.dayScores[day.startOfDay] ?? 0)
                        }
                        return ChartDataEntry(x: Double(index), y: Double(score))
                    }
                case .failure(let error):
                    logWarning(
                        event: "chart_card_fetch_failed",
                        message: "Failed to fetch weekly tasks for chart card",
                        fields: ["error": error.localizedDescription]
                    )
                    DispatchQueue.main.async {
                        defer { TaskerPerformanceTrace.end(interval) }
                        guard requestedGeneration == self.loadGeneration else { return }
                        self.chartData = []
                        self.cachedWeekStart = nil
                        self.isLoading = false
                    }
                    return
                }

                DispatchQueue.main.async {
                    defer { TaskerPerformanceTrace.end(interval) }
                    guard requestedGeneration == self.loadGeneration else { return }
                    self.chartData = payload
                    self.cachedWeekStart = weekStart
                    self.isLoading = false
                }
            }
        }
    }

    func unload() {
        loadGeneration &+= 1
        chartData = []
        cachedWeekStart = nil
        isLoading = false
    }
}
