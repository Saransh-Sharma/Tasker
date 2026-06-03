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
    func loadTodayTasks(generation: Int) {
        applySelectedDay(
            Date(),
            source: .backToToday,
            trackAnalytics: false,
            generation: generation,
            forceReload: true
        )
    }

    /// Executes scheduleRecurringTopUpIfNeeded.

    func scheduleRecurringTopUpIfNeeded() {
        let now = Date()
        if let lastRecurringTopUpAt,
           now.timeIntervalSince(lastRecurringTopUpAt) < recurringTopUpThrottleSeconds {
            return
        }
        pendingRecurringTopUpTask?.cancel()
        pendingRecurringTopUpTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.recurringTopUpDelay)
            } catch {
                return
            }
            guard Task.isCancelled == false, let self else { return }
            self.lastRecurringTopUpAt = Date()
            self.useCaseCoordinator.createTaskDefinition.maintainRecurringSeries(daysAhead: 45) { _ in }
            self.pendingRecurringTopUpTask = nil
        }
    }

    /// Toggle task completion.

    public func toggleTaskCompletion(_ task: TaskDefinition) {
        setTaskCompletion(
            taskID: task.id,
            to: !task.isComplete,
            taskSnapshot: task
        ) { _ in }
    }

    public func completeHabit(_ row: HomeHabitRow, source: String = "habit_row_action") {
        resolveHabit(row, action: row.kind == .positive ? .complete : .abstained, source: source)
    }

    public func skipHabit(_ row: HomeHabitRow, source: String = "habit_row_action") {
        resolveHabit(row, action: .skip, source: source)
    }

    public func lapseHabit(_ row: HomeHabitRow, source: String = "habit_row_action") {
        resolveHabit(row, action: .lapsed, source: source)
    }

    public func performHabitLastCellAction(
        _ row: HomeHabitRow,
        source: String = "habit_home_last_cell"
    ) {
        let interaction = HomeHabitLastCellInteraction.resolve(for: row)
        switch interaction.action {
        case .complete:
            completeHabit(row, source: source)
        case .skip:
            skipHabit(row, source: source)
        case .lapse:
            lapseHabit(row, source: source)
        case .clear:
            resetHabit(row, source: source)
        }
    }

    public func logHabitProgress(
        _ row: HomeHabitRow,
        on date: Date,
        source: String = "quiet_tracking"
    ) {
        resolveHabit(row, action: row.kind == .positive ? .complete : .abstained, on: date, source: source)
    }

    public func logHabitLapse(
        _ row: HomeHabitRow,
        on date: Date,
        source: String = "quiet_tracking"
    ) {
        resolveHabit(row, action: .lapsed, on: date, source: source)
    }

    /// Deterministically sets completion to a desired value.

    public func setTaskCompletion(
        taskID: UUID,
        to desiredCompletion: Bool,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        setTaskCompletion(
            taskID: taskID,
            to: desiredCompletion,
            taskSnapshot: currentTaskSnapshot(for: taskID),
            completion: completion
        )
    }

    /// Create a new task.

    public func createTask(request: CreateTaskDefinitionRequest) {
        useCaseCoordinator.createTaskDefinition.execute(request: request) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.enqueueReload(
                        source: "create_task",
                        reason: .created,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Delete a task.

    public func deleteTask(_ task: TaskDefinition) {
        deleteTask(taskID: task.id) { _ in }
    }

    /// Executes deleteTask.

    public func deleteTask(
        taskID: UUID,
        scope: TaskDeleteScope = .single,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        useCaseCoordinator.deleteTaskDefinition.execute(taskID: taskID, scope: scope) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.removePinnedFocusTaskID(taskID)
                    self?.enqueueReload(
                        source: "delete_task",
                        reason: .deleted,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(()))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    public func restoreDeletedTaskSnapshot(
        _ task: TaskDefinition,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.taskDefinitionRepository.create(task) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let restoredTask):
                    self?.enqueueReload(
                        source: "restore_deleted_task",
                        reason: .bulkChanged,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(restoredTask))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Reschedule a task.

    public func rescheduleTask(_ task: TaskDefinition, to newDate: Date?) {
        rescheduleTask(taskID: task.id, to: newDate) { _ in }
    }

    /// Executes rescheduleTask.

    public func rescheduleTask(
        taskID: UUID,
        to newDate: Date?,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.rescheduleTaskDefinition.execute(taskID: taskID, newDate: newDate) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let task):
                    self?.enqueueReload(
                        source: "reschedule_task",
                        reason: .rescheduled,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(task))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes updateTask.

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

    public func clearHabitRecoveryReflectionPrompt() {
        habitRecoveryReflectionPrompt = nil
    }

    /// Executes loadTaskChildren.

    public func loadTaskChildren(
        parentTaskID: UUID,
        completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void
    ) {
        useCaseCoordinator.getTaskChildren.execute(parentTaskID: parentTaskID) { result in
            Task { @MainActor in
                completion(result)
            }
        }
    }

    /// Executes createTaskDefinition.
}
