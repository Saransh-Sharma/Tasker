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
    public func undoRescueRun(
        completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        trackHomeInteraction(action: "rescue_undo_tap", metadata: [:])
        undoEvaBatchPlan { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success(let run):
                    self?.trackHomeInteraction(action: "rescue_undo_success", metadata: [
                        "run_id": run.id.uuidString
                    ])
                    completion(.success(run))
                case .failure(let error):
                    self?.trackHomeInteraction(action: "rescue_undo_error", metadata: [
                        "error": error.localizedDescription
                    ])
                    completion(.failure(error))
                }
            }
        }
    }

    public func createSplitChildren(
        parentTaskID: UUID,
        draft: EvaSplitDraft,
        completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void
    ) {
        guard let parent = currentTaskSnapshot(for: parentTaskID) ?? focusOpenTasksForCurrentState().first(where: { $0.id == parentTaskID }) ?? overdueTasks.first(where: { $0.id == parentTaskID }) else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Parent task no longer exists."]
            )))
            return
        }

        let childTitles = draft.children
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard childTitles.count >= 2 else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Add at least two subtasks to split."]
            )))
            return
        }

        let dueDate = draft.childDuePreset?.resolveDueDate()
        let group = DispatchGroup()
        let accumulator = LockedResultAccumulator([TaskDefinition]())

        trackHomeInteraction(action: "rescue_split_open", metadata: [
            "parent_task_id": parentTaskID.uuidString
        ])

        for title in childTitles {
            group.enter()
            let request = CreateTaskDefinitionRequest(
                title: title,
                details: nil,
                projectID: parent.projectID,
                projectName: parent.projectName,
                dueDate: dueDate,
                parentTaskID: parent.id,
                priority: parent.priority,
                type: parent.type,
                energy: parent.energy,
                category: parent.category,
                context: parent.context,
                isEveningTask: parent.isEveningTask,
                estimatedDuration: nil
            )

            useCaseCoordinator.createTaskDefinition.execute(request: request) { result in
                switch result {
                case .success(let task):
                    accumulator.update { $0.append(task) }
                case .failure(let error):
                    accumulator.record(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            switch accumulator.result() {
            case .failure(let firstError):
                self.trackHomeInteraction(action: "rescue_apply_error", metadata: [
                    "split_parent_task_id": parentTaskID.uuidString,
                    "error": firstError.localizedDescription
                ])
                completion(.failure(firstError))
                return
            case .success(let created):
                self.enqueueReload(
                    source: "rescue_split_created",
                    reason: .updated,
                    invalidateCaches: true,
                    includeAnalytics: false,
                    repostEvent: true
                )
                self.trackHomeInteraction(action: "rescue_split_created", metadata: [
                    "parent_task_id": parentTaskID.uuidString,
                    "child_count": created.count
                ])
                completion(.success(created))
            }
        }
    }

    public func undoCreatedSplitChildren(
        childTaskIDs: [UUID],
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard childTaskIDs.isEmpty == false else {
            completion(.success(()))
            return
        }

        let group = DispatchGroup()
        let accumulator = LockedResultAccumulator(())

        for taskID in childTaskIDs {
            group.enter()
            useCaseCoordinator.deleteTaskDefinition.execute(taskID: taskID, scope: .single) { result in
                if case .failure(let error) = result {
                    accumulator.record(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if case .failure(let firstError) = accumulator.result() {
                completion(.failure(firstError))
                return
            }
            self.enqueueReload(
                source: "rescue_split_undo",
                reason: .updated,
                invalidateCaches: true,
                includeAnalytics: false,
                repostEvent: true
            )
            self.trackHomeInteraction(action: "rescue_split_undo", metadata: [
                "child_count": childTaskIDs.count
            ])
            completion(.success(()))
        }
    }

    // MARK: - Private Methods

    /// Executes setupBindings.

}
