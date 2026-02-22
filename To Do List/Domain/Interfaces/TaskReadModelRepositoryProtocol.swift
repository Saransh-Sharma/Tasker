import Foundation

public protocol TaskReadModelRepositoryProtocol {
    /// Executes fetchTasks.
    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    /// Executes searchTasks.
    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    /// Executes fetchLatestTaskUpdatedAt.
    func fetchLatestTaskUpdatedAt(completion: @escaping (Result<Date?, Error>) -> Void)
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

public extension TaskReadModelRepositoryProtocol {
    func fetchLatestTaskUpdatedAt(completion: @escaping (Result<Date?, Error>) -> Void) {
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .updatedAtDescending,
                limit: 1,
                offset: 0
            )
        ) { result in
            switch result {
            case .success(let slice):
                completion(.success(slice.tasks.first?.updatedAt))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
