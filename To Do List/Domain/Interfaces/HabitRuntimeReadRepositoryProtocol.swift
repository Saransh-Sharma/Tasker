import Foundation

public protocol HabitRuntimeReadRepositoryProtocol {
    /// Executes fetchAgendaHabits.
    func fetchAgendaHabits(
        for date: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    )

    /// Executes fetchAgendaHabit.
    func fetchAgendaHabit(
        habitID: UUID,
        for date: Date,
        completion: @escaping (Result<HabitOccurrenceSummary?, Error>) -> Void
    )

    /// Executes fetchHistory.
    func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
    )

    /// Executes fetchSignals.
    func fetchSignals(
        start: Date,
        end: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    )

    /// Executes fetchHabitLibrary.
    func fetchHabitLibrary(
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    )

    /// Executes fetchHabitLibrary.
    func fetchHabitLibrary(
        habitIDs: [UUID]?,
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    )
}

public extension HabitRuntimeReadRepositoryProtocol {
    func fetchAgendaHabit(
        habitID: UUID,
        for date: Date,
        completion: @escaping (Result<HabitOccurrenceSummary?, Error>) -> Void
    ) {
        fetchAgendaHabits(for: date) { result in
            completion(
                result.map { summaries in
                    summaries.first(where: { $0.habitID == habitID })
                }
            )
        }
    }

    func fetchHabitLibrary(
        habitIDs: [UUID]?,
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        fetchHabitLibrary(includeArchived: includeArchived) { result in
            completion(
                result.map { rows in
                    guard let habitIDs, habitIDs.isEmpty == false else { return rows }
                    let requestedIDs = Set(habitIDs)
                    return rows.filter { requestedIDs.contains($0.habitID) }
                }
            )
        }
    }
}
