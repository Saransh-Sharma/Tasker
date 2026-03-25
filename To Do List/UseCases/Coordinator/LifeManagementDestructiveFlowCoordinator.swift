import Foundation

public struct DeleteLifeAreaRequest: Equatable {
    public let areaID: UUID
    public let destinationLifeAreaID: UUID
    public let projects: [Project]
    public let habits: [HabitLibraryRow]

    public init(
        areaID: UUID,
        destinationLifeAreaID: UUID,
        projects: [Project],
        habits: [HabitLibraryRow]
    ) {
        self.areaID = areaID
        self.destinationLifeAreaID = destinationLifeAreaID
        self.projects = projects
        self.habits = habits
    }
}

public struct DeleteProjectRequest: Equatable {
    public let projectID: UUID
    public let destinationProjectID: UUID
    public let linkedHabitIDs: [UUID]

    public init(
        projectID: UUID,
        destinationProjectID: UUID,
        linkedHabitIDs: [UUID]
    ) {
        self.projectID = projectID
        self.destinationProjectID = destinationProjectID
        self.linkedHabitIDs = linkedHabitIDs
    }
}

public final class LifeManagementDestructiveFlowCoordinator {
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let updateHabitUseCase: UpdateHabitUseCase
    private let projectRepository: ProjectRepositoryProtocol
    private let lifeAreaRepository: LifeAreaRepositoryProtocol

    public init(
        manageProjectsUseCase: ManageProjectsUseCase,
        updateHabitUseCase: UpdateHabitUseCase,
        projectRepository: ProjectRepositoryProtocol,
        lifeAreaRepository: LifeAreaRepositoryProtocol
    ) {
        self.manageProjectsUseCase = manageProjectsUseCase
        self.updateHabitUseCase = updateHabitUseCase
        self.projectRepository = projectRepository
        self.lifeAreaRepository = lifeAreaRepository
    }

    public func deleteLifeArea(
        request: DeleteLifeAreaRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                let movedProjectIDs = Set(request.projects.map(\.id))

                for project in request.projects {
                    _ = try await awaitProjectResult { completion in
                        self.manageProjectsUseCase.moveProjectToLifeArea(
                            projectId: project.id,
                            lifeAreaID: request.destinationLifeAreaID,
                            completion: completion
                        )
                    }
                }

                for habit in request.habits {
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
                }

                _ = try await awaitVoid { completion in
                    self.lifeAreaRepository.delete(id: request.areaID, completion: completion)
                }

                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    public func deleteProject(
        request: DeleteProjectRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                _ = try await awaitVoid { completion in
                    self.projectRepository.moveTasks(
                        from: request.projectID,
                        to: request.destinationProjectID,
                        completion: completion
                    )
                }

                for habitID in request.linkedHabitIDs {
                    _ = try await awaitHabitResult { completion in
                        self.updateHabitUseCase.execute(
                            request: UpdateHabitRequest(id: habitID, clearProject: true),
                            completion: completion
                        )
                    }
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
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    private func awaitProjectResult<T>(
        _ operation: @escaping (@escaping (Result<T, ProjectError>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            operation { result in
                continuation.resume(with: result)
            }
        }
    }

    private func awaitHabitResult<T>(
        _ operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            operation { result in
                continuation.resume(with: result)
            }
        }
    }

    private func awaitVoid(
        _ operation: @escaping (@escaping (Result<Void, Error>) -> Void) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            operation { result in
                continuation.resume(with: result)
            }
        }
    }
}
