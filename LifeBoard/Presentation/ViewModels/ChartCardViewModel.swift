import Foundation
import Combine
import DGCharts
import SwiftUI

@MainActor
public final class ChartCardViewModel: ObservableObject {
    @Published var chartData: [ChartDataEntry] = []
    @Published var isLoading = true

    private let readModelRepository: TaskReadModelRepositoryProtocol?
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
        let interval = LifeBoardPerformanceTrace.begin("ChartCardLoad")

        readModel.fetchWeekChartProjection(referenceDate: currentReferenceDate) { [weak self] result in
            switch result {
            case .success(let projection):
                let today = Date.today().startOfDay
                let payload = week.map { day in
                    if day.startOfDay > today {
                        return 0.0
                    }
                    return Double(max(0, projection.dayScores[day.startOfDay] ?? 0))
                }

                Task { @MainActor [weak self] in
                    defer { LifeBoardPerformanceTrace.end(interval) }
                    guard let self, requestedGeneration == self.loadGeneration else { return }
                    self.chartData = payload.enumerated().map { index, score in
                        ChartDataEntry(x: Double(index), y: score)
                    }
                    self.cachedWeekStart = weekStart
                    self.isLoading = false
                }
            case .failure(let error):
                let message = error.localizedDescription
                Task { @MainActor [weak self] in
                    defer { LifeBoardPerformanceTrace.end(interval) }
                    guard let self, requestedGeneration == self.loadGeneration else { return }
                    logWarning(
                        event: "chart_card_fetch_failed",
                        message: "Failed to fetch weekly tasks for chart card",
                        fields: ["error": message]
                    )
                    self.chartData = []
                    self.cachedWeekStart = nil
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
