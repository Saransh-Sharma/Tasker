import Foundation

public final class ManageHabitsUseCase {
    private let repository: HabitRepositoryProtocol

    /// Initializes a new instance.
    public init(repository: HabitRepositoryProtocol) {
        self.repository = repository
    }

    /// Executes list.
    public func list(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void) {
        repository.fetchAll(completion: completion)
    }

    /// Executes create.
    public func create(
        title: String,
        habitType: String,
        projectID: UUID?,
        lifeAreaID: UUID?,
        completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void
    ) {
        let habit = HabitDefinitionRecord(
            lifeAreaID: lifeAreaID,
            projectID: projectID,
            title: title,
            habitType: habitType
        )
        repository.create(habit, completion: completion)
    }

    /// Executes pause.
    public func pause(id: UUID, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        repository.fetchAll { result in
            switch result {
            case .success(let habits):
                guard var habit = habits.first(where: { $0.id == id }) else {
                    completion(.failure(NSError(domain: "ManageHabitsUseCase", code: 404)))
                    return
                }
                habit.isPaused = true
                habit.updatedAt = Date()
                self.repository.update(habit, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
