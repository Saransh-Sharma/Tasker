//
//  ChartCardsScrollView.swift
//  LifeBoard
//
//  Created by Assistant on Radar Chart Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import SwiftUI

/// Vertically scrollable view containing multiple chart cards with guaranteed transparent background
struct ChartCardsScrollView: View {
    let referenceDate: Date?
    let onCreateProject: () -> Void
    /// Initializes a new instance.
    @StateObject private var chartViewModel: ChartCardViewModel
    @StateObject private var radarViewModel: RadarChartCardViewModel

    init(
        referenceDate: Date? = nil,
        onCreateProject: @escaping () -> Void = {},
        chartViewModel: ChartCardViewModel,
        radarViewModel: RadarChartCardViewModel
    ) {
        self.referenceDate = referenceDate
        self.onCreateProject = onCreateProject
        _chartViewModel = StateObject(wrappedValue: chartViewModel)
        _radarViewModel = StateObject(wrappedValue: radarViewModel)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 16) {
                // Line Chart Card
                ChartCard(
                    title: "Weekly Progress",
                    subtitle: "Task completion scores",
                    referenceDate: referenceDate,
                    viewModel: chartViewModel
                )
                .background(Color.clear)

                // Radar Chart Card
                RadarChartCard(
                    title: "Project Breakdown",
                    subtitle: "Weekly scores by project",
                    referenceDate: referenceDate,
                    onCreateProject: onCreateProject,
                    viewModel: radarViewModel
                )
                .background(Color.clear)
            }
            .background(Color.clear)
            .padding(.horizontal, 16)
            .background(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Preview

struct ChartCardsScrollView_Previews: PreviewProvider {
    static var previews: some View {
        let readModelRepository = PreviewChartCardsReadModelRepository()
        let projectRepository = PreviewChartCardsProjectRepository()
        ChartCardsScrollView(
            onCreateProject: {},
            chartViewModel: ChartCardViewModel(readModelRepository: readModelRepository),
            radarViewModel: RadarChartCardViewModel(
                projectRepository: projectRepository,
                readModelRepository: readModelRepository
            )
        )
        .frame(height: 350)
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}

private final class PreviewChartCardsReadModelRepository: TaskReadModelRepositoryProtocol {
    /// Executes fetchTasks.
    func fetchTasks(query: TaskReadQuery, completion: @escaping @Sendable (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    /// Executes searchTasks.
    func searchTasks(query: TaskSearchQuery, completion: @escaping @Sendable (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    /// Executes fetchProjectTaskCounts.
    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping @Sendable (Result<[UUID: Int], Error>) -> Void
    ) {
        completion(.success([:]))
    }

    /// Executes fetchProjectCompletionScoreTotals.
    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping @Sendable (Result<[UUID: Int], Error>) -> Void
    ) {
        completion(.success([:]))
    }
}

private final class PreviewChartCardsProjectRepository: ProjectRepositoryProtocol {
    /// Executes fetchAllProjects.
    func fetchAllProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) { completion(.success([])) }
    /// Executes fetchProject.
    func fetchProject(withId id: UUID, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    /// Executes fetchProject.
    func fetchProject(withName name: String, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    /// Executes fetchInboxProject.
    func fetchInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    /// Executes fetchCustomProjects.
    func fetchCustomProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) { completion(.success([])) }
    /// Executes createProject.
    func createProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.success(project)) }
    /// Executes ensureInboxProject.
    func ensureInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    /// Executes repairProjectIdentityCollisions.
    func repairProjectIdentityCollisions(completion: @escaping @Sendable (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }
    /// Executes updateProject.
    func updateProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.success(project)) }
    /// Executes renameProject.
    func renameProject(withId id: UUID, to newName: String, completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    /// Executes deleteProject.
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    /// Executes getTaskCount.
    func getTaskCount(for projectId: UUID, completion: @escaping @Sendable (Result<Int, Error>) -> Void) { completion(.success(0)) }
    /// Executes moveTasks.
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    /// Executes isProjectNameAvailable.
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) { completion(.success(true)) }
}
