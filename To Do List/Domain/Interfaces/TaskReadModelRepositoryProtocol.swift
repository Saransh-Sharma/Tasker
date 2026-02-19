import Foundation

public protocol TaskReadModelRepositoryProtocol {
    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    )
    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    )
}
