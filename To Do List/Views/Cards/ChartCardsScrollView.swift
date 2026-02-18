//
//  ChartCardsScrollView.swift
//  To Do List
//
//  Created by Assistant on Radar Chart Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import SwiftUI

/// Vertically scrollable view containing multiple chart cards with guaranteed transparent background
struct ChartCardsScrollView: View {
    let referenceDate: Date?
    let onCreateProject: () -> Void
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
        .compositingGroup()
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
    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskSliceResult, Error>) -> Void) {
        completion(.success(TaskSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskSliceResult, Error>) -> Void) {
        completion(.success(TaskSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    ) {
        completion(.success([:]))
    }

    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    ) {
        completion(.success([:]))
    }
}

private final class PreviewChartCardsProjectRepository: ProjectRepositoryProtocol {
    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success([])) }
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success([])) }
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(project)) }
    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(project)) }
    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) { completion(.success(0)) }
    func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(true)) }
}
