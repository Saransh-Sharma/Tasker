//
//  GenerateProductivityReportUseCase.swift
//  Tasker
//
//  Use case for generating comprehensive productivity reports
//

import Foundation

/// Use case for generating productivity reports
public final class GenerateProductivityReportUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    
    // MARK: - Initialization
    
    public init(taskRepository: TaskRepositoryProtocol) {
        self.taskRepository = taskRepository
    }
    
    // MARK: - Report Methods
    
    /// Generate daily productivity report
    public func generateDailyReport(
        for date: Date = Date(),
        completion: @escaping (Result<GenerateProductivityReportUseCase.ProductivityReport, GenerateProductivityReportUseCase.AnalyticsError>) -> Void
    ) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        taskRepository.fetchTasks(from: startOfDay, to: endOfDay) { result in
            switch result {
            case .success(let tasks):
                let report = GenerateProductivityReportUseCase.ProductivityReport(
                    period: .daily(date),
                    tasksCompleted: tasks.filter { $0.isComplete }.count,
                    totalScore: tasks.filter { $0.isComplete }.reduce(0) { $0 + $1.score }
                )
                completion(.success(report))
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
}

public extension GenerateProductivityReportUseCase {
    struct ProductivityReport {
        public let period: ReportPeriod
        public let tasksCompleted: Int
        public let totalScore: Int
        
        public init(period: ReportPeriod, tasksCompleted: Int, totalScore: Int) {
            self.period = period
            self.tasksCompleted = tasksCompleted
            self.totalScore = totalScore
        }
    }
    
    enum ReportPeriod {
        case daily(Date)
        case weekly(Date)
        case monthly(Date)
    }
    
    enum AnalyticsError: LocalizedError {
        case dataError(Error)
        case invalidPeriod
        
        public var errorDescription: String? {
            switch self {
            case .dataError(let error):
                return "Data error: \(error.localizedDescription)"
            case .invalidPeriod:
                return "Invalid report period"
            }
        }
    }
}