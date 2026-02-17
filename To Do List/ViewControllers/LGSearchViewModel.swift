//
//  LGSearchViewModel.swift
//  Tasker
//
//  Search ViewModel for Liquid Glass Search Screen
//

import Foundation

class LGSearchViewModel {

    enum StatusFilterType {
        case all
        case today
        case overdue
        case completed
    }

    // MARK: - Properties

    private let useCaseCoordinator: UseCaseCoordinator
    private var currentStatusFilter: StatusFilterType = .all
    private var lastQuery: String = ""

    var searchResults: [Task] = []
    private(set) var projects: [Project] = []
    var filteredProjects: Set<String> = []
    var filteredPriorities: Set<Int32> = []

    var onResultsUpdated: (([Task]) -> Void)?

    // MARK: - Initialization

    init(useCaseCoordinator: UseCaseCoordinator) {
        self.useCaseCoordinator = useCaseCoordinator
    }

    // MARK: - Search Methods

    func search(query: String) {
        lastQuery = query
        fetchTasksForCurrentStatusFilter { [weak self] tasks in
            guard let self else { return }
            self.searchResults = self.applyInMemoryFilters(tasks: tasks, query: query)
            DispatchQueue.main.async {
                self.onResultsUpdated?(self.searchResults)
            }
        }
    }

    func searchAll() {
        search(query: lastQuery)
    }

    func loadProjects(completion: (() -> Void)? = nil) {
        useCaseCoordinator.manageProjects.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let projectsWithStats) = result {
                    self?.projects = projectsWithStats.map(\.project)
                }
                completion?()
            }
        }
    }

    func setStatusFilter(_ filter: StatusFilterType) {
        currentStatusFilter = filter
    }

    func setTaskCompletion(taskID: UUID, to isComplete: Bool, completion: @escaping (Bool) -> Void) {
        let taskSnapshot = searchResults.first(where: { $0.id == taskID })
        useCaseCoordinator.completeTask.setCompletion(
            taskId: taskID,
            to: isComplete,
            taskSnapshot: taskSnapshot
        ) { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    logError(
                        event: "search_toggle_completion_failed",
                        message: "Failed to toggle task completion in search",
                        fields: [
                            "task_id": taskID.uuidString,
                            "error": error.localizedDescription
                        ]
                    )
                }
                completion((try? result.get()) != nil)
            }
        }
    }

    func deleteTask(taskID: UUID, completion: @escaping (Bool) -> Void) {
        useCaseCoordinator.deleteTask.execute(taskId: taskID) { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    logError(
                        event: "search_delete_task_failed",
                        message: "Failed to delete task from search",
                        fields: [
                            "task_id": taskID.uuidString,
                            "error": error.localizedDescription
                        ]
                    )
                }
                completion((try? result.get()) != nil)
            }
        }
    }

    func rescheduleTask(taskID: UUID, to newDate: Date, completion: @escaping (Bool) -> Void) {
        useCaseCoordinator.rescheduleTask.execute(taskId: taskID, newDate: newDate) { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    logError(
                        event: "search_reschedule_task_failed",
                        message: "Failed to reschedule task from search",
                        fields: [
                            "task_id": taskID.uuidString,
                            "error": error.localizedDescription
                        ]
                    )
                }
                completion((try? result.get()) != nil)
            }
        }
    }

    func updateTask(
        taskID: UUID,
        request: UpdateTaskRequest,
        completion: @escaping (Result<Task, Error>) -> Void
    ) {
        useCaseCoordinator.updateTask.execute(taskId: taskID, request: request) { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    logError(
                        event: "search_update_task_failed",
                        message: "Failed to update task from search detail sheet",
                        fields: [
                            "task_id": taskID.uuidString,
                            "error": error.localizedDescription
                        ]
                    )
                }
                completion(result.mapError { $0 as Error })
            }
        }
    }

    // MARK: - Filter Methods

    func toggleProjectFilter(_ project: String) {
        if filteredProjects.contains(project) {
            filteredProjects.remove(project)
        } else {
            filteredProjects.insert(project)
        }
    }
    
    func togglePriorityFilter(_ priority: Int32) {
        if filteredPriorities.contains(priority) {
            filteredPriorities.remove(priority)
        } else {
            filteredPriorities.insert(priority)
        }
    }
    
    func clearFilters() {
        filteredProjects.removeAll()
        filteredPriorities.removeAll()
        currentStatusFilter = .all
    }

    // MARK: - Helper Methods

    func getAllProjects() -> [String] {
        let projects = Set(searchResults.compactMap { $0.project })
        return Array(projects).sorted()
    }

    func groupTasksByProject(_ tasks: [Task]) -> [(project: String, tasks: [Task])] {
        let grouped = Dictionary(grouping: tasks) { $0.project ?? "Inbox" }
        return grouped.map { (project: $0.key, tasks: $0.value) }
            .sorted { $0.project < $1.project }
    }

    private func fetchTasksForCurrentStatusFilter(completion: @escaping ([Task]) -> Void) {
        let handler: (Result<[Task], Error>) -> Void = { result in
            switch result {
            case .success(let tasks):
                completion(tasks)
            case .failure(let error):
                logError(
                    event: "search_task_fetch_failed",
                    message: "Failed to fetch tasks for search",
                    fields: ["error": error.localizedDescription]
                )
                completion([])
            }
        }

        switch currentStatusFilter {
        case .all:
            useCaseCoordinator.taskRepository.fetchAllTasks(completion: handler)
        case .today:
            useCaseCoordinator.taskRepository.fetchTodayTasks(completion: handler)
        case .overdue:
            useCaseCoordinator.taskRepository.fetchOverdueTasks(completion: handler)
        case .completed:
            useCaseCoordinator.taskRepository.fetchCompletedTasks(completion: handler)
        }
    }

    private func applyInMemoryFilters(tasks: [Task], query: String) -> [Task] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedProjects = Set(filteredProjects.map { $0.lowercased() })

        return tasks.filter { task in
            if normalizedQuery.isEmpty == false {
                let haystacks = [
                    task.name,
                    task.details ?? "",
                    task.project ?? ""
                ].map { $0.lowercased() }
                guard haystacks.contains(where: { $0.contains(normalizedQuery) }) else {
                    return false
                }
            }

            if normalizedProjects.isEmpty == false {
                let projectName = (task.project ?? ProjectConstants.inboxProjectName).lowercased()
                guard normalizedProjects.contains(projectName) else {
                    return false
                }
            }

            if filteredPriorities.isEmpty == false {
                let mappedPriority = Int32(task.priority.rawValue)
                guard filteredPriorities.contains(mappedPriority) else {
                    return false
                }
            }

            return true
        }
        .sorted(by: { lhs, rhs in
            if lhs.isComplete != rhs.isComplete {
                return lhs.isComplete == false
            }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?):
                return l < r
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            case (nil, nil):
                return lhs.dateAdded < rhs.dateAdded
            }
        })
    }
}
