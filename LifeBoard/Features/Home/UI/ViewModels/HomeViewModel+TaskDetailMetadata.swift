//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

extension HomeViewModel {
    public func loadTaskDetailMetadata(
        projectID: UUID,
        completion: @escaping @Sendable (Result<TaskDetailMetadataPayload, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let accumulator = LockedResultAccumulator(
            HomeTaskDetailMetadataState(projects: projects)
        )

        group.enter()
        useCaseCoordinator.manageProjects.getAllProjects { result in
            defer { group.leave() }
            switch result {
            case .success(let projectsWithStats):
                accumulator.update { $0.projects = projectsWithStats.map(\.project) }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.enter()
        useCaseCoordinator.manageSections.list(projectID: projectID) { result in
            defer { group.leave() }
            switch result {
            case .success(let sections):
                accumulator.update { $0.sections = sections }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.enter()
        useCaseCoordinator.buildWeeklyPlanSnapshot.execute(referenceDate: Date()) { result in
            defer { group.leave() }
            switch result {
            case .success(let snapshot):
                accumulator.update { $0.weeklyOutcomes = snapshot.outcomes.sorted { $0.orderIndex < $1.orderIndex } }
            case .failure(let error):
                logWarning(
                    event: "task_detail_metadata_weekly_snapshot_failed",
                    message: "Weekly snapshot unavailable while loading task detail metadata",
                    fields: ["error": error.localizedDescription]
                )
            }
        }

        group.notify(queue: .main) {
            let result = accumulator.result()
            if case .failure(let error) = result {
                completion(.failure(error))
                return
            }
            guard case .success(let metadataState) = result else { return }
            let projectMotivation = metadataState.projects.first(where: { $0.id == projectID }).map {
                ProjectWeeklyMotivation(
                    why: $0.motivationWhy,
                    successLooksLike: $0.motivationSuccessLooksLike,
                    costOfNeglect: $0.motivationCostOfNeglect
                )
            }
            completion(.success(TaskDetailMetadataPayload(
                projects: metadataState.projects,
                sections: metadataState.sections,
                weeklyOutcomes: metadataState.weeklyOutcomes,
                projectMotivation: projectMotivation
            )))
        }
    }

    public func loadTaskDetailRelationshipMetadata(
        projectID: UUID,
        completion: @escaping @Sendable (Result<TaskDetailRelationshipMetadataPayload, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let accumulator = LockedResultAccumulator(HomeTaskDetailRelationshipMetadataState())

        group.enter()
        useCaseCoordinator.manageLifeAreas.list { result in
            defer { group.leave() }
            switch result {
            case .success(let lifeAreas):
                accumulator.update { $0.lifeAreas = lifeAreas }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.enter()
        useCaseCoordinator.manageTags.list { result in
            defer { group.leave() }
            switch result {
            case .success(let tags):
                accumulator.update { $0.tags = tags }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.enter()
        useCaseCoordinator.getTasks.getTasksForProject(projectID, includeCompleted: false) { result in
            defer { group.leave() }
            switch result {
            case .success(let slice):
                accumulator.update { $0.availableTasks = slice.tasks }
            case .failure(let error):
                accumulator.record(error)
            }
        }

        group.enter()
        useCaseCoordinator.reflectionNoteRepository.fetchNotes(
            query: ReflectionNoteQuery(linkedProjectID: projectID, limit: 6)
        ) { result in
            defer { group.leave() }
            switch result {
            case .success(let notes):
                accumulator.update { $0.recentReflectionNotes = notes }
            case .failure(let error):
                logWarning(
                    event: "task_detail_relationship_metadata_reflections_failed",
                    message: "Reflection notes unavailable while loading task relationship metadata",
                    fields: ["error": error.localizedDescription]
                )
            }
        }

        group.notify(queue: .main) {
            let result = accumulator.result()
            if case .failure(let error) = result {
                completion(.failure(error))
                return
            }
            guard case .success(let relationshipState) = result else { return }
            completion(.success(TaskDetailRelationshipMetadataPayload(
                lifeAreas: relationshipState.lifeAreas,
                tags: relationshipState.tags,
                availableTasks: relationshipState.availableTasks,
                recentReflectionNotes: relationshipState.recentReflectionNotes
            )))
        }
    }

    public func saveReflectionNote(
        _ note: ReflectionNote,
        completion: @escaping @Sendable (Result<ReflectionNote, Error>) -> Void
    ) {
        useCaseCoordinator.reflectionNoteRepository.saveNote(note) { [weak self] result in
            guard let self else { return }

            if case .success(let savedNote) = result {
                self.useCaseCoordinator.gamificationEngine.recordEvent(
                    context: XPEventContext(
                        category: .reflectionCapture,
                        source: .manual,
                        taskID: savedNote.linkedTaskID,
                        habitID: savedNote.linkedHabitID,
                        completedAt: savedNote.createdAt
                    )
                ) { _ in }
            }

            Task { @MainActor in
                completion(result)
            }
        }
    }

}
