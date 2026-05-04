import Foundation

public struct DeleteLifeAreaRequest: Equatable, Sendable {
    public let areaID: UUID
    public let destinationLifeAreaID: UUID

    public init(
        areaID: UUID,
        destinationLifeAreaID: UUID
    ) {
        self.areaID = areaID
        self.destinationLifeAreaID = destinationLifeAreaID
    }
}

public struct DeleteProjectRequest: Equatable, Sendable {
    public let projectID: UUID
    public let destinationProjectID: UUID

    public init(
        projectID: UUID,
        destinationProjectID: UUID
    ) {
        self.projectID = projectID
        self.destinationProjectID = destinationProjectID
    }
}

enum LifeManagementDestructiveFlowError: LocalizedError {
    case lifeAreaDestinationMatchesSource
    case projectDestinationMatchesSource
    case rollbackFailed(underlying: Error, rollbackError: Error)

    var errorDescription: String? {
        switch self {
        case .lifeAreaDestinationMatchesSource:
            return "Choose a different destination area before deleting this area."
        case .projectDestinationMatchesSource:
            return "Choose a different destination project before deleting this project."
        case .rollbackFailed:
            return "The delete flow failed and the rollback could not fully restore the previous state."
        }
    }
}

public final class LifeManagementDestructiveFlowCoordinator: @unchecked Sendable {
    private struct LifeAreaProjectSnapshot {
        let projectID: UUID
        let lifeAreaID: UUID
    }

    private struct LifeAreaHabitSnapshot {
        let habitID: UUID
        let lifeAreaID: UUID
        let projectID: UUID?
    }

    private struct ProjectTaskSnapshot {
        let taskID: UUID
        let projectID: UUID
        let lifeAreaID: UUID?
    }

    private struct ProjectHabitSnapshot {
        let habitID: UUID
        let projectID: UUID?
    }

    private let manageProjectsUseCase: ManageProjectsUseCase
    private let updateHabitUseCase: UpdateHabitUseCase
    private let projectRepository: ProjectRepositoryProtocol
    private let taskDefinitionRepository: TaskDefinitionRepositoryProtocol
    private let lifeAreaRepository: LifeAreaRepositoryProtocol
    private let habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol

    public init(
        manageProjectsUseCase: ManageProjectsUseCase,
        updateHabitUseCase: UpdateHabitUseCase,
        projectRepository: ProjectRepositoryProtocol,
        taskDefinitionRepository: TaskDefinitionRepositoryProtocol,
        lifeAreaRepository: LifeAreaRepositoryProtocol,
        habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol
    ) {
        self.manageProjectsUseCase = manageProjectsUseCase
        self.updateHabitUseCase = updateHabitUseCase
        self.projectRepository = projectRepository
        self.taskDefinitionRepository = taskDefinitionRepository
        self.lifeAreaRepository = lifeAreaRepository
        self.habitRuntimeReadRepository = habitRuntimeReadRepository
    }

    public func deleteLifeArea(
        request: DeleteLifeAreaRequest,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard request.areaID != request.destinationLifeAreaID else {
            completion(.failure(LifeManagementDestructiveFlowError.lifeAreaDestinationMatchesSource))
            return
        }

        Task {
            var movedProjects: [LifeAreaProjectSnapshot] = []
            var updatedHabits: [LifeAreaHabitSnapshot] = []

            do {
                let projects = try await fetchProjects(inLifeArea: request.areaID)
                let habits = try await fetchHabits(inLifeArea: request.areaID)
                let movedProjectIDs = Set(projects.map(\.id))

                for project in projects {
                    let originalLifeAreaID = project.lifeAreaID ?? request.areaID
                    _ = try await awaitProjectResult { completion in
                        self.manageProjectsUseCase.moveProjectToLifeArea(
                            projectId: project.id,
                            lifeAreaID: request.destinationLifeAreaID,
                            completion: completion
                        )
                    }
                    movedProjects.append(
                        LifeAreaProjectSnapshot(
                            projectID: project.id,
                            lifeAreaID: originalLifeAreaID
                        )
                    )
                }

                for habit in habits {
                    let shouldKeepProject = habit.projectID.map(movedProjectIDs.contains) ?? false
                    _ = try await awaitHabitResult { completion in
                        self.updateHabitUseCase.execute(
                            request: UpdateHabitRequest(
                                id: habit.habitID,
                                lifeAreaID: request.destinationLifeAreaID,
                                projectID: shouldKeepProject ? habit.projectID : nil,
                                clearProject: habit.projectID != nil && shouldKeepProject == false
                            ),
                            completion: completion
                        )
                    }
                    updatedHabits.append(
                        LifeAreaHabitSnapshot(
                            habitID: habit.habitID,
                            lifeAreaID: request.areaID,
                            projectID: habit.projectID
                        )
                    )
                }

                try await awaitVoid { completion in
                    self.lifeAreaRepository.delete(id: request.areaID, completion: completion)
                }

                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                if let rollbackError = await rollbackLifeAreaDeletion(
                    updatedHabits: updatedHabits,
                    movedProjects: movedProjects
                ) {
                    await MainActor.run {
                        completion(.failure(LifeManagementDestructiveFlowError.rollbackFailed(underlying: error, rollbackError: rollbackError)))
                    }
                    return
                }

                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    public func deleteProject(
        request: DeleteProjectRequest,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard request.projectID != request.destinationProjectID else {
            completion(.failure(LifeManagementDestructiveFlowError.projectDestinationMatchesSource))
            return
        }

        Task {
            var movedTasks: [ProjectTaskSnapshot] = []
            var updatedHabits: [ProjectHabitSnapshot] = []

            do {
                let destinationProject = try await fetchProject(id: request.destinationProjectID)
                let tasks = try await fetchTasks(inProject: request.projectID)
                let linkedHabitIDs = try await fetchLinkedHabitIDs(projectID: request.projectID)

                for task in tasks {
                    _ = try await awaitTaskResult { completion in
                        self.taskDefinitionRepository.update(
                            request: UpdateTaskDefinitionRequest(
                                id: task.id,
                                projectID: request.destinationProjectID,
                                lifeAreaID: destinationProject.lifeAreaID,
                                clearLifeArea: destinationProject.lifeAreaID == nil
                            ),
                            completion: completion
                        )
                    }
                    movedTasks.append(
                        ProjectTaskSnapshot(
                            taskID: task.id,
                            projectID: task.projectID,
                            lifeAreaID: task.lifeAreaID
                        )
                    )
                }

                for habitID in linkedHabitIDs {
                    _ = try await awaitHabitResult { completion in
                        self.updateHabitUseCase.execute(
                            request: UpdateHabitRequest(id: habitID, clearProject: true),
                            completion: completion
                        )
                    }
                    updatedHabits.append(
                        ProjectHabitSnapshot(
                            habitID: habitID,
                            projectID: request.projectID
                        )
                    )
                }

                _ = try await awaitProjectResult { completion in
                    self.manageProjectsUseCase.deleteProject(
                        projectId: request.projectID,
                        deleteStrategy: .moveToInbox,
                        completion: completion
                    )
                }

                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                if let rollbackError = await rollbackProjectDeletion(
                    updatedHabits: updatedHabits,
                    movedTasks: movedTasks
                ) {
                    await MainActor.run {
                        completion(.failure(LifeManagementDestructiveFlowError.rollbackFailed(underlying: error, rollbackError: rollbackError)))
                    }
                    return
                }

                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    private func fetchProject(id: UUID) async throws -> Project {
        let project = try await awaitResult { completion in
            self.projectRepository.fetchProject(withId: id, completion: completion)
        }
        guard let project else {
            throw NSError(
                domain: "LifeManagementDestructiveFlowCoordinator",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "The selected destination project no longer exists."]
            )
        }
        return project
    }

    private func fetchProjects(inLifeArea lifeAreaID: UUID) async throws -> [Project] {
        let projects = try await awaitResult { completion in
            self.projectRepository.fetchAllProjects(completion: completion)
        }
        return projects.filter { $0.lifeAreaID == lifeAreaID }
    }

    private func fetchTasks(inProject projectID: UUID) async throws -> [TaskDefinition] {
        let tasks = try await awaitResult { completion in
            self.taskDefinitionRepository.fetchAll(query: nil, completion: completion)
        }
        return tasks.filter { $0.projectID == projectID }
    }

    private func fetchHabits(inLifeArea lifeAreaID: UUID) async throws -> [HabitLibraryRow] {
        let habits = try await awaitResult { completion in
            self.habitRuntimeReadRepository.fetchHabitLibrary(includeArchived: true, completion: completion)
        }
        return habits.filter { $0.lifeAreaID == lifeAreaID }
    }

    private func fetchLinkedHabitIDs(projectID: UUID) async throws -> [UUID] {
        let habits = try await awaitResult { completion in
            self.habitRuntimeReadRepository.fetchHabitLibrary(includeArchived: true, completion: completion)
        }
        return habits
            .filter { $0.projectID == projectID }
            .map(\.habitID)
    }

    private func rollbackLifeAreaDeletion(
        updatedHabits: [LifeAreaHabitSnapshot],
        movedProjects: [LifeAreaProjectSnapshot]
    ) async -> Error? {
        for habit in updatedHabits.reversed() {
            do {
                _ = try await awaitHabitResult { completion in
                    self.updateHabitUseCase.execute(
                        request: UpdateHabitRequest(
                            id: habit.habitID,
                            lifeAreaID: habit.lifeAreaID,
                            projectID: habit.projectID,
                            clearProject: habit.projectID == nil
                        ),
                        completion: completion
                    )
                }
            } catch {
                return error
            }
        }

        for project in movedProjects.reversed() {
            do {
                _ = try await awaitProjectResult { completion in
                    self.manageProjectsUseCase.moveProjectToLifeArea(
                        projectId: project.projectID,
                        lifeAreaID: project.lifeAreaID,
                        completion: completion
                    )
                }
            } catch {
                return error
            }
        }

        return nil
    }

    private func rollbackProjectDeletion(
        updatedHabits: [ProjectHabitSnapshot],
        movedTasks: [ProjectTaskSnapshot]
    ) async -> Error? {
        for habit in updatedHabits.reversed() {
            do {
                _ = try await awaitHabitResult { completion in
                    self.updateHabitUseCase.execute(
                        request: UpdateHabitRequest(
                            id: habit.habitID,
                            projectID: habit.projectID,
                            clearProject: habit.projectID == nil
                        ),
                        completion: completion
                    )
                }
            } catch {
                return error
            }
        }

        for task in movedTasks.reversed() {
            do {
                _ = try await awaitTaskResult { completion in
                    self.taskDefinitionRepository.update(
                        request: UpdateTaskDefinitionRequest(
                            id: task.taskID,
                            projectID: task.projectID,
                            lifeAreaID: task.lifeAreaID,
                            clearLifeArea: task.lifeAreaID == nil
                        ),
                        completion: completion
                    )
                }
            } catch {
                return error
            }
        }

        return nil
    }

    private func awaitResult<T: Sendable>(
        _ operation: @escaping @Sendable (@escaping @Sendable (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            operation { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error as NSError)
                }
            }
        }
    }

    private func awaitProjectResult<T: Sendable>(
        _ operation: @escaping @Sendable (@escaping @Sendable (Result<T, ProjectError>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            operation { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func awaitHabitResult<T: Sendable>(
        _ operation: @escaping @Sendable (@escaping @Sendable (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            operation { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error as NSError)
                }
            }
        }
    }

    private func awaitTaskResult<T: Sendable>(
        _ operation: @escaping @Sendable (@escaping @Sendable (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            operation { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error as NSError)
                }
            }
        }
    }

    private func awaitVoid(
        _ operation: @escaping @Sendable (@escaping @Sendable (Result<Void, Error>) -> Void) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            operation { result in
                continuation.resume(with: result)
            }
        }
    }
}
