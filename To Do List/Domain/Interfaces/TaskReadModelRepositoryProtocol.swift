import Foundation

public protocol TaskReadModelRepositoryProtocol {
    /// Executes fetchTasks.
    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    /// Executes searchTasks.
    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    /// Executes fetchProjectTaskCounts.
    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    )
    /// Executes fetchProjectCompletionScoreTotals.
    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    )
}
