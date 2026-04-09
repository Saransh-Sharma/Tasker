//
//  LGSearchViewModel.swift
//  Tasker
//
//  Search ViewModel for Liquid Glass Search Screen
//

import Foundation

class LGSearchViewModel {

    enum StatusFilterType: Hashable {
        case all
        case today
        case overdue
        case completed
    }

    private struct CorpusCacheKey: Hashable {
        let revision: Int
        let status: StatusFilterType
    }

    private struct SearchCacheKey: Hashable {
        let cacheRevision: Int
        let status: StatusFilterType
        let normalizedQuery: String
        let normalizedProjects: [String]
        let priorities: [Int32]
    }

    private struct PreparedTask {
        let task: TaskDefinition
        let normalizedTitle: String
        let normalizedDetails: String
        let normalizedProjectName: String
        let mappedPriority: Int32
    }

    private final class SearchComputationWorker {
        private let queue = DispatchQueue(label: "tasker.search.computation", qos: .userInitiated)

        func compute(
            preparedTasks: [PreparedTask],
            cacheKey: SearchCacheKey,
            filter: @escaping ([PreparedTask], SearchCacheKey) -> [PreparedTask],
            group: @escaping ([PreparedTask]) -> [(project: String, tasks: [TaskDefinition])],
            completion: @escaping ([PreparedTask], [(project: String, tasks: [TaskDefinition])]) -> Void
        ) {
            queue.async {
                let filteredPreparedTasks = filter(preparedTasks, cacheKey)
                let groupedResults = group(filteredPreparedTasks)
                DispatchQueue.main.async {
                    completion(filteredPreparedTasks, groupedResults)
                }
            }
        }
    }

    // MARK: - Properties

    private let useCaseCoordinator: UseCaseCoordinator
    private let computationWorker = SearchComputationWorker()
    private var currentStatusFilter: StatusFilterType = .all
    private var lastQuery: String = ""
    private var activeCacheRevision: Int = 0
    private var latestSearchRequestID: Int = 0
    private var corpusCache: [CorpusCacheKey: [PreparedTask]] = [:]
    private var filteredResultsCache: [SearchCacheKey: [TaskDefinition]] = [:]
    private var groupedResultsCache: [SearchCacheKey: [(project: String, tasks: [TaskDefinition])]] = [:]
    private var lastEmittedSearchCacheKey: SearchCacheKey?
    private var lastEmittedSearchTaskIDs: [UUID] = []

    var searchResults: [TaskDefinition] = []
    private(set) var projects: [Project] = []
    var filteredProjects: Set<String> = []
    var filteredPriorities: Set<Int32> = []

    var onResultsUpdated: (([TaskDefinition]) -> Void)?
    var onResultsUpdatedWithRevision: ((Int, [TaskDefinition]) -> Void)?

    // MARK: - Initialization

    /// Initializes a new instance.
    init(useCaseCoordinator: UseCaseCoordinator) {
        self.useCaseCoordinator = useCaseCoordinator
    }

    // MARK: - Search Methods

    /// Executes search.
    func search(query: String) {
        search(query: query, revision: latestSearchRequestID &+ 1)
    }

    /// Executes search.
    func search(query: String, revision: Int) {
        lastQuery = query
        latestSearchRequestID &+= 1
        let requestID = latestSearchRequestID
        let cacheKey = makeSearchCacheKey(query: query)

        if let cachedResults = filteredResultsCache[cacheKey] {
            let groupedResults = groupedResultsCache[cacheKey] ?? groupPreparedTasksByProject(prepareTasks(cachedResults))
            commitSearchResultsIfCurrent(
                cachedResults,
                groupedResults: groupedResults,
                cacheKey: cacheKey,
                revision: revision,
                requestID: requestID
            )
            return
        }

        let selectedProjectIDs = selectedProjectIDsForRepository()
        let canUseReadModelRepository = filteredProjects.isEmpty || selectedProjectIDs.isEmpty == false

        if canUseReadModelRepository, let readModelRepository = useCaseCoordinator.taskReadModelRepository {
            let repositoryQuery = TaskRepositorySearchQuery(
                text: query,
                status: repositorySearchStatus(for: currentStatusFilter),
                projectIDs: selectedProjectIDs,
                priorities: filteredPriorities.sorted(),
                needsTotalCount: false,
                limit: 600,
                offset: 0
            )
            readModelRepository.searchTasks(query: repositoryQuery) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    logError(
                        event: "search_task_fetch_failed",
                        message: "Failed to fetch tasks for search",
                        fields: ["error": error.localizedDescription]
                    )
                    self.clearSearchResultsIfCurrent(revision: revision, requestID: requestID)
                case .success(let slice):
                    let filteredTasks = slice.tasks
                    let groupedResults = self.groupPreparedTasksByProject(self.prepareTasks(filteredTasks))
                    self.commitSearchResultsIfCurrent(
                        filteredTasks,
                        groupedResults: groupedResults,
                        cacheKey: cacheKey,
                        revision: revision,
                        requestID: requestID
                    )
                }
            }
            return
        }

        fetchPreparedTasksForCurrentStatusFilter(revision: activeCacheRevision) { [weak self] preparedTasks in
            guard let self else { return }
            self.computationWorker.compute(
                preparedTasks: preparedTasks,
                cacheKey: cacheKey,
                filter: { tasks, key in
                    self.applyInMemoryFilters(tasks: tasks, cacheKey: key)
                },
                group: { tasks in
                    self.groupPreparedTasksByProject(tasks)
                }
            ) { [weak self] filteredPreparedTasks, groupedResults in
                guard let self else { return }
                let filteredTasks = filteredPreparedTasks.map(\.task)
                self.commitSearchResultsIfCurrent(
                    filteredTasks,
                    groupedResults: groupedResults,
                    cacheKey: cacheKey,
                    revision: revision,
                    requestID: requestID
                )
            }
        }
    }

    /// Executes searchAll.
    func searchAll() {
        search(query: lastQuery, revision: latestSearchRequestID &+ 1)
    }

    /// Executes loadProjects.
    func loadProjects(completion: (() -> Void)? = nil) {
        useCaseCoordinator.manageProjects.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let projectsWithStats) = result {
                    let nextProjects = projectsWithStats.map(\.project)
                    if self?.projects != nextProjects {
                        self?.projects = nextProjects
                    }
                }
                completion?()
            }
        }
    }

    /// Executes setStatusFilter.
    func setStatusFilter(_ filter: StatusFilterType) {
        currentStatusFilter = filter
    }

    func replaceFilters(
        status: StatusFilterType,
        projects: [String],
        priorities: [Int32]
    ) {
        currentStatusFilter = status
        filteredProjects = Set(projects)
        filteredPriorities = Set(priorities)
    }

    func invalidateSearchCache(revision: Int) {
        guard revision != activeCacheRevision else { return }
        activeCacheRevision = revision
        latestSearchRequestID &+= 1
        let floorRevision = max(0, revision - 1)
        corpusCache = corpusCache.filter { $0.key.revision >= floorRevision }
        filteredResultsCache = filteredResultsCache.filter { $0.key.cacheRevision >= floorRevision }
        groupedResultsCache = groupedResultsCache.filter { $0.key.cacheRevision >= floorRevision }

        if let lastEmittedSearchCacheKey,
           lastEmittedSearchCacheKey.cacheRevision < floorRevision {
            self.lastEmittedSearchCacheKey = nil
            self.lastEmittedSearchTaskIDs = []
        }
    }

    func purgeCaches() {
        activeCacheRevision &+= 1
        latestSearchRequestID &+= 1
        corpusCache.removeAll(keepingCapacity: false)
        filteredResultsCache.removeAll(keepingCapacity: false)
        groupedResultsCache.removeAll(keepingCapacity: false)
        lastEmittedSearchCacheKey = nil
        lastEmittedSearchTaskIDs = []
        searchResults = []
    }

    /// Executes fetchTodayXPSoFar.
    func fetchTodayXPSoFar(completion: @escaping (Int?) -> Void) {
        guard V2FeatureFlags.gamificationV2Enabled else {
            completion(0)
            return
        }
        useCaseCoordinator.gamificationEngine.fetchTodayXP { result in
            DispatchQueue.main.async {
                let resolvedXP = (try? result.get()).map { max(0, $0) }
                completion(resolvedXP)
            }
        }
    }

    /// Executes setTaskCompletion.
    func setTaskCompletion(taskID: UUID, to isComplete: Bool, completion: @escaping (Bool) -> Void) {
        useCaseCoordinator.completeTaskDefinition.setCompletion(
            taskID: taskID,
            to: isComplete
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

    /// Executes deleteTask.
    func deleteTask(taskID: UUID, scope: TaskDeleteScope = .single, completion: @escaping (Bool) -> Void) {
        useCaseCoordinator.deleteTaskDefinition.execute(taskID: taskID, scope: scope) { result in
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

    /// Executes rescheduleTask.
    func rescheduleTask(taskID: UUID, to newDate: Date?, completion: @escaping (Bool) -> Void) {
        useCaseCoordinator.rescheduleTaskDefinition.execute(taskID: taskID, newDate: newDate) { result in
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

    /// Executes updateTask.
    func updateTask(
        taskID: UUID,
        request: UpdateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        var normalizedRequest = request
        normalizedRequest.updatedAt = Date()
        useCaseCoordinator.updateTaskDefinition.execute(request: normalizedRequest) { result in
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

    /// Executes loadTaskDetailMetadata.
    func loadTaskDetailMetadata(
        projectID: UUID,
        completion: @escaping (Result<TaskDetailMetadataPayload, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        var loadedProjects: [Project] = projects
        var loadedSections: [TaskerProjectSection] = []

        func record(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        group.enter()
        useCaseCoordinator.manageProjects.getAllProjects { result in
            defer { group.leave() }
            switch result {
            case .success(let projectsWithStats):
                loadedProjects = projectsWithStats.map(\.project)
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.manageSections.list(projectID: projectID) { result in
            defer { group.leave() }
            switch result {
            case .success(let sections):
                loadedSections = sections
            case .failure(let error):
                record(error)
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }

            completion(.success(TaskDetailMetadataPayload(
                projects: loadedProjects,
                sections: loadedSections
            )))
        }
    }

    func loadTaskDetailRelationshipMetadata(
        projectID: UUID,
        completion: @escaping (Result<TaskDetailRelationshipMetadataPayload, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        var loadedLifeAreas: [LifeArea] = []
        var loadedTags: [TagDefinition] = []
        var availableTasks: [TaskDefinition] = []

        /// Executes record.
        func record(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        group.enter()
        useCaseCoordinator.manageLifeAreas.list { result in
            defer { group.leave() }
            switch result {
            case .success(let lifeAreas):
                loadedLifeAreas = lifeAreas
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.manageTags.list { result in
            defer { group.leave() }
            switch result {
            case .success(let tags):
                loadedTags = tags
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.getTasks.getTasksForProject(projectID, includeCompleted: false) { result in
            defer { group.leave() }
            switch result {
            case .success(let slice):
                availableTasks = slice.tasks
            case .failure(let error):
                record(error)
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }

            completion(.success(TaskDetailRelationshipMetadataPayload(
                lifeAreas: loadedLifeAreas,
                tags: loadedTags,
                availableTasks: availableTasks
            )))
        }
    }

    /// Executes loadTaskChildren.
    func loadTaskChildren(
        parentTaskID: UUID,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        useCaseCoordinator.getTaskChildren.execute(parentTaskID: parentTaskID) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Executes createTaskDefinition.
    func createTaskDefinition(
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.createTaskDefinition.execute(request: request) { result in
            DispatchQueue.main.async {
                completion(result.mapError { $0 as Error })
            }
        }
    }

    /// Executes createTagForTaskDetail.
    func createTagForTaskDetail(
        name: String,
        completion: @escaping (Result<TagDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.manageTags.create(name: name, color: nil, icon: nil) { result in
            DispatchQueue.main.async {
                completion(result.mapError { $0 as Error })
            }
        }
    }

    /// Executes createProjectForTaskDetail.
    func createProjectForTaskDetail(
        name: String,
        completion: @escaping (Result<Project, Error>) -> Void
    ) {
        useCaseCoordinator.manageProjects.createProject(request: CreateProjectRequest(name: name)) { result in
            DispatchQueue.main.async {
                completion(result.mapError { $0 as Error })
            }
        }
    }

    // MARK: - Filter Methods

    /// Executes toggleProjectFilter.
    func toggleProjectFilter(_ project: String) {
        if filteredProjects.contains(project) {
            filteredProjects.remove(project)
        } else {
            filteredProjects.insert(project)
        }
    }
    
    /// Executes togglePriorityFilter.
    func togglePriorityFilter(_ priority: Int32) {
        if filteredPriorities.contains(priority) {
            filteredPriorities.remove(priority)
        } else {
            filteredPriorities.insert(priority)
        }
    }
    
    /// Executes clearFilters.
    func clearFilters() {
        filteredProjects.removeAll()
        filteredPriorities.removeAll()
        currentStatusFilter = .all
    }

    // MARK: - Helper Methods

    /// Executes getAllProjects.
    func getAllProjects() -> [String] {
        let projects = Set(searchResults.compactMap { $0.projectName })
        return Array(projects).sorted()
    }

    /// Executes groupTasksByProject.
    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])] {
        let taskIDs = tasks.map(\.id)
        if let lastEmittedSearchCacheKey,
           taskIDs == lastEmittedSearchTaskIDs,
           let cachedGrouping = groupedResultsCache[lastEmittedSearchCacheKey] {
            return cachedGrouping
        }

        let grouped = Dictionary(grouping: tasks) { $0.projectName ?? ProjectConstants.inboxProjectName }
        return grouped
            .map { (project: $0.key, tasks: $0.value) }
            .sorted { $0.project < $1.project }
    }

    private func dispatchSearchResults(
        _ results: [TaskDefinition],
        revision: Int,
        requestID: Int
    ) {
        guard requestID == latestSearchRequestID else { return }
        onResultsUpdated?(results)
        onResultsUpdatedWithRevision?(revision, results)
    }

    private func clearSearchResultsIfCurrent(revision: Int, requestID: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard requestID == self.latestSearchRequestID else { return }
            self.searchResults = []
            self.dispatchSearchResults([], revision: revision, requestID: requestID)
        }
    }

    private func commitSearchResultsIfCurrent(
        _ filteredTasks: [TaskDefinition],
        groupedResults: [(project: String, tasks: [TaskDefinition])],
        cacheKey: SearchCacheKey,
        revision: Int,
        requestID: Int
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard requestID == self.latestSearchRequestID else { return }
            self.searchResults = filteredTasks
            self.filteredResultsCache[cacheKey] = filteredTasks
            self.groupedResultsCache[cacheKey] = groupedResults
            self.lastEmittedSearchCacheKey = cacheKey
            self.lastEmittedSearchTaskIDs = filteredTasks.map(\.id)
            self.pruneCachesIfNeeded()
            self.dispatchSearchResults(filteredTasks, revision: revision, requestID: requestID)
        }
    }

    private func makeSearchCacheKey(query: String) -> SearchCacheKey {
        SearchCacheKey(
            cacheRevision: activeCacheRevision,
            status: currentStatusFilter,
            normalizedQuery: query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            normalizedProjects: filteredProjects.map { $0.lowercased() }.sorted(),
            priorities: filteredPriorities.sorted()
        )
    }

    private func selectedProjectIDsForRepository() -> [UUID] {
        guard filteredProjects.isEmpty == false else { return [] }
        let selectedNames = Set(filteredProjects.map { $0.lowercased() })
        return projects
            .filter { selectedNames.contains($0.name.lowercased()) }
            .map(\.id)
    }

    private func repositorySearchStatus(for status: StatusFilterType) -> TaskSearchStatus {
        switch status {
        case .all:
            return .all
        case .today:
            return .today
        case .overdue:
            return .overdue
        case .completed:
            return .completed
        }
    }

    private func fetchPreparedTasksForCurrentStatusFilter(
        revision: Int,
        completion: @escaping ([PreparedTask]) -> Void
    ) {
        let status = currentStatusFilter
        let cacheKey = CorpusCacheKey(revision: revision, status: status)
        if let cached = corpusCache[cacheKey] {
            completion(cached)
            return
        }

        let handler: (Result<[TaskDefinition], Error>) -> Void = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let tasks):
                let preparedTasks = self.prepareTasks(tasks)
                DispatchQueue.main.async {
                    self.corpusCache[cacheKey] = preparedTasks
                    completion(preparedTasks)
                }
            case .failure(let error):
                logError(
                    event: "search_task_fetch_failed",
                    message: "Failed to fetch tasks for search",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }

        switch status {
        case .all:
            useCaseCoordinator.getTasks.searchTasks(query: "", in: .all) { result in
                handler(result.mapError { $0 as Error })
            }
        case .today:
            useCaseCoordinator.getTasks.getTodayTasks { result in
                let mapped = result.map { today in
                    let openTasks = today.morningTasks + today.eveningTasks + today.overdueTasks
                    return openTasks + today.completedTasks
                }.mapError { $0 as Error }
                handler(mapped)
            }
        case .overdue:
            useCaseCoordinator.getTasks.getOverdueTasks { result in
                handler(result.mapError { $0 as Error })
            }
        case .completed:
            useCaseCoordinator.getTasks.searchTasks(query: "", in: .all) { result in
                let mapped = result.map { tasks in
                    tasks.filter(\.isComplete)
                }.mapError { $0 as Error }
                handler(mapped)
            }
        }
    }

    private func prepareTasks(_ tasks: [TaskDefinition]) -> [PreparedTask] {
        tasks.map { task in
            PreparedTask(
                task: task,
                normalizedTitle: task.title.lowercased(),
                normalizedDetails: (task.details ?? "").lowercased(),
                normalizedProjectName: (task.projectName ?? ProjectConstants.inboxProjectName).lowercased(),
                mappedPriority: Int32(task.priority.rawValue)
            )
        }
    }

    private func groupPreparedTasksByProject(_ preparedTasks: [PreparedTask]) -> [(project: String, tasks: [TaskDefinition])] {
        let grouped = Dictionary(grouping: preparedTasks) {
            $0.task.projectName ?? ProjectConstants.inboxProjectName
        }

        return grouped
            .map { key, value in
                (project: key, tasks: value.map(\.task))
            }
            .sorted { $0.project < $1.project }
    }

    private func pruneCachesIfNeeded() {
        let floorRevision = max(0, activeCacheRevision - 2)
        corpusCache = corpusCache.filter { $0.key.revision >= floorRevision }
        filteredResultsCache = filteredResultsCache.filter { $0.key.cacheRevision >= floorRevision }
        groupedResultsCache = groupedResultsCache.filter { $0.key.cacheRevision >= floorRevision }
    }

    /// Executes applyInMemoryFilters.
    private func applyInMemoryFilters(
        tasks: [PreparedTask],
        cacheKey: SearchCacheKey
    ) -> [PreparedTask] {
        let normalizedQuery = cacheKey.normalizedQuery
        let normalizedProjects = Set(cacheKey.normalizedProjects)
        let priorities = Set(cacheKey.priorities)

        return tasks.filter { preparedTask in
            if normalizedQuery.isEmpty == false {
                let haystacks = [
                    preparedTask.normalizedTitle,
                    preparedTask.normalizedDetails,
                    preparedTask.normalizedProjectName
                ]
                guard haystacks.contains(where: { $0.contains(normalizedQuery) }) else {
                    return false
                }
            }

            if normalizedProjects.isEmpty == false {
                guard normalizedProjects.contains(preparedTask.normalizedProjectName) else {
                    return false
                }
            }

            if priorities.isEmpty == false {
                guard priorities.contains(preparedTask.mappedPriority) else {
                    return false
                }
            }

            return true
        }
        .sorted(by: { lhs, rhs in
            if lhs.task.isComplete != rhs.task.isComplete {
                return lhs.task.isComplete == false
            }
            switch (lhs.task.dueDate, rhs.task.dueDate) {
            case let (l?, r?):
                return l < r
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            case (nil, nil):
                return lhs.task.dateAdded < rhs.task.dateAdded
            }
        })
    }
}
