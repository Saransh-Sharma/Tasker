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
    
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    
    // MARK: - Initialization
    
    /// Initializes a new instance.
    public init(taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil) {
        self.taskReadModelRepository = taskReadModelRepository
    }
    
    // MARK: - Report Methods
    
    /// Generate daily productivity report
    public func generateDailyReport(
        for date: Date = Date(),
        completion: @escaping (Result<GenerateProductivityReportUseCase.ProductivityReport, GenerateProductivityReportUseCase.AnalyticsError>) -> Void
    ) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        guard let taskReadModelRepository else {
            completion(.failure(.dataError(NSError(
                domain: "GenerateProductivityReportUseCase",
                code: 503,
                userInfo: [NSLocalizedDescriptionKey: "Task read-model repository is not configured"]
            ))))
            return
        }

        taskReadModelRepository.fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateStart: startOfDay,
                dueDateEnd: endOfDay,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { result in
            switch result {
            case .success(let slice):
                let completedTasks = slice.tasks.filter(\.isComplete)
                let report = GenerateProductivityReportUseCase.ProductivityReport(
                    period: .daily(date),
                    tasksCompleted: completedTasks.count,
                    totalScore: completedTasks.reduce(0) { $0 + $1.priority.scorePoints }
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
        
        /// Initializes a new instance.
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
