//
//  StatsViewModel.swift
//  Tasker
//
//  ViewModel for the Stats screen.
//  Fetches real user data from analytics use cases.
//

import Foundation
import Combine
import SwiftUI

// MARK: - StatsViewModel

/// ViewModel for the Stats screen
/// Fetches and manages all statistics data from use cases
public final class StatsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Today's XP earned
    @Published public private(set) var todayXP: Int = 0

    /// Daily XP goal
    @Published public private(set) var dailyXPGoal: Int = 100

    /// Current streak (consecutive days with completed tasks)
    @Published public private(set) var currentStreak: Int = 0

    /// Best day XP ever
    @Published public private(set) var bestDayXP: Int = 0

    /// Best day date
    @Published public private(set) var bestDayDate: Date = Date()

    /// Weekly XP data (7 days, Sun-Sat)
    @Published public private(set) var weeklyXPData: [Int] = [0, 0, 0, 0, 0, 0, 0]

    /// Activity heatmap data (7 rows x 52 columns)
    @Published public private(set) var heatmapData: [[Int]] = Array(repeating: Array(repeating: 0, count: 52), count: 7)

    /// Habit completion rate (0.0 - 1.0)
    @Published public private(set) var habitCompletionRate: Double = 0.0

    /// Most productive day of the week
    @Published public private(set) var mostProductiveDay: String = "—"

    /// Average daily XP
    @Published public private(set) var averageDailyXP: Int = 0

    /// Week-over-week change percentage
    @Published public private(set) var weekOverWeekChange: Int = 0

    /// Loading state
    @Published public private(set) var isLoading: Bool = false

    /// Error message
    @Published public private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let useCaseCoordinator: UseCaseCoordinator
    private let xpService: XPServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(useCaseCoordinator: UseCaseCoordinator, xpService: XPServiceProtocol? = nil) {
        self.useCaseCoordinator = useCaseCoordinator
        self.xpService = xpService ?? ThreadSafeXPService()
    }

    /// Convenience initializer using shared container
    public convenience init() {
        self.init(useCaseCoordinator: EnhancedDependencyContainer.shared.useCaseCoordinator)
    }

    // MARK: - Public Methods

    /// Load all stats data
    public func loadData() {
        isLoading = true
        errorMessage = nil

        // Load data in parallel
        loadTodayXP()
        loadStreak()
        loadWeeklyData()
        loadHeatmapData()
        loadHabitPerformance()
        loadInsights()
    }

    // MARK: - Private Data Loading

    private func loadTodayXP() {
        // Get today's XP from XP service
        let dailyXP = xpService.getDailyXP(for: Date())
        DispatchQueue.main.async {
            self.todayXP = dailyXP.earnedXP
        }

        // Also get from analytics for backup/verification
        useCaseCoordinator.calculateAnalytics.calculateTodayAnalytics { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let analytics):
                    // Use totalScore as XP if XP service returns 0
                    if self?.todayXP == 0 {
                        self?.todayXP = analytics.totalScore
                    }
                case .failure:
                    break // Silently fail, XP from service is primary
                }
            }
        }
    }

    private func loadStreak() {
        useCaseCoordinator.calculateAnalytics.calculateStreak { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let streakInfo):
                    self?.currentStreak = streakInfo.currentStreak
                case .failure:
                    self?.currentStreak = 0
                }
            }
        }
    }

    private func loadWeeklyData() {
        useCaseCoordinator.calculateAnalytics.calculateWeeklyAnalytics { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let weeklyAnalytics):
                    // Extract daily scores for the week
                    let dailyScores = weeklyAnalytics.dailyAnalytics.map { $0.totalScore }

                    // Pad to 7 days if needed
                    var scores = dailyScores
                    while scores.count < 7 {
                        scores.append(0)
                    }
                    self?.weeklyXPData = Array(scores.prefix(7))

                    // Find best day
                    if let bestDay = weeklyAnalytics.mostProductiveDay {
                        self?.bestDayXP = max(self?.bestDayXP ?? 0, bestDay.totalScore)
                        if bestDay.totalScore >= (self?.bestDayXP ?? 0) {
                            self?.bestDayDate = bestDay.date
                        }
                    }

                    // Calculate week over week change
                    self?.calculateWeekOverWeekChange(currentWeekTotal: weeklyAnalytics.totalScore)

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadHeatmapData() {
        // Get activity data for the past year
        let calendar = Calendar.current
        let today = Date()
        guard let yearAgo = calendar.date(byAdding: .year, value: -1, to: today) else { return }

        useCaseCoordinator.calculateAnalytics.calculateAnalytics(from: yearAgo, to: today) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let periodAnalytics):
                    self?.generateHeatmapFromAnalytics(periodAnalytics)
                case .failure:
                    // Use empty heatmap on failure
                    break
                }
            }
        }
    }

    private func generateHeatmapFromAnalytics(_ analytics: PeriodAnalytics) {
        let calendar = Calendar.current
        var heatmap: [[Int]] = Array(repeating: Array(repeating: 0, count: 52), count: 7)

        for dailyAnalytics in analytics.dailyBreakdown {
            let weekOfYear = calendar.component(.weekOfYear, from: dailyAnalytics.date) - 1
            let weekday = calendar.component(.weekday, from: dailyAnalytics.date) - 1 // 0 = Sunday

            guard weekOfYear >= 0 && weekOfYear < 52 && weekday >= 0 && weekday < 7 else { continue }

            // Convert score to intensity level (0-4)
            let intensity: Int
            switch dailyAnalytics.totalScore {
            case 0: intensity = 0
            case 1...10: intensity = 1
            case 11...25: intensity = 2
            case 26...50: intensity = 3
            default: intensity = 4
            }

            heatmap[weekday][weekOfYear] = intensity
        }

        self.heatmapData = heatmap
    }

    private func loadHabitPerformance() {
        guard let calculateHabitStreak = useCaseCoordinator.calculateHabitStreak else {
            // Habit use case not available, calculate from task completion rate
            loadTaskCompletionRate()
            return
        }

        calculateHabitStreak.getActiveHabitStreaks { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let streaks):
                    // Calculate completion rate based on active habits with streaks > 0
                    let activeCount = streaks.count
                    let completedToday = streaks.filter { $0.currentStreak > 0 }.count
                    self?.habitCompletionRate = activeCount > 0 ? Double(completedToday) / Double(activeCount) : 0.0
                case .failure:
                    self?.loadTaskCompletionRate()
                }
            }
        }
    }

    private func loadTaskCompletionRate() {
        useCaseCoordinator.calculateAnalytics.calculateTodayAnalytics { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let analytics) = result {
                    self?.habitCompletionRate = analytics.completionRate
                }
            }
        }
    }

    private func loadInsights() {
        // Load weekly analytics for insights
        useCaseCoordinator.calculateAnalytics.calculateWeeklyAnalytics { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let weeklyAnalytics):
                    // Most productive day
                    if let bestDay = weeklyAnalytics.mostProductiveDay {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "EEEE"
                        self?.mostProductiveDay = formatter.string(from: bestDay.date)
                    }

                    // Average daily XP
                    let avgXP = weeklyAnalytics.dailyAnalytics.isEmpty ? 0 :
                        weeklyAnalytics.dailyAnalytics.reduce(0) { $0 + $1.totalScore } / weeklyAnalytics.dailyAnalytics.count
                    self?.averageDailyXP = avgXP

                case .failure:
                    break
                }
            }
        }
    }

    private func calculateWeekOverWeekChange(currentWeekTotal: Int) {
        // Get last week's data
        let calendar = Calendar.current
        guard let lastWeekEnd = calendar.date(byAdding: .day, value: -7, to: Date()),
              let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: lastWeekEnd) else {
            return
        }

        useCaseCoordinator.calculateAnalytics.calculateAnalytics(from: lastWeekStart, to: lastWeekEnd) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let lastWeekAnalytics) = result {
                    let lastWeekTotal = lastWeekAnalytics.totalScore
                    if lastWeekTotal > 0 {
                        let change = ((currentWeekTotal - lastWeekTotal) * 100) / lastWeekTotal
                        self?.weekOverWeekChange = change
                    } else if currentWeekTotal > 0 {
                        self?.weekOverWeekChange = 100 // Infinite improvement from 0
                    }
                }
            }
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension StatsViewModel {
    /// Create a preview instance with sample data
    static var preview: StatsViewModel {
        let viewModel = StatsViewModel(useCaseCoordinator: EnhancedDependencyContainer.shared.useCaseCoordinator)
        viewModel.todayXP = 42
        viewModel.currentStreak = 7
        viewModel.bestDayXP = 85
        viewModel.weeklyXPData = [12, 45, 23, 67, 42, 55, 38]
        viewModel.habitCompletionRate = 0.78
        viewModel.mostProductiveDay = "Wednesday"
        viewModel.averageDailyXP = 42
        viewModel.weekOverWeekChange = 15
        return viewModel
    }
}
#endif
