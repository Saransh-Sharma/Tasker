//
//  SearchTasksUseCase.swift
//  Tasker
//
//  Use case for searching tasks with advanced capabilities
//  Replaces search functionality scattered across ViewControllers
//

import Foundation

/// Use case for searching tasks with advanced search capabilities
/// This replaces direct search logic in ViewControllers
public final class SearchTasksUseCase {
    
    // MARK: - Supporting Types
    
    public enum TagMatchMode: Codable {
        case any
        case all
    }
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let cacheService: CacheServiceProtocol?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        cacheService: CacheServiceProtocol? = nil
    ) {
        self.taskRepository = taskRepository
        self.cacheService = cacheService
    }
    
    // MARK: - Search Methods
    
    /// Perform comprehensive search with advanced criteria
    public func searchTasks(
        query: SearchQuery,
        completion: @escaping (Result<SearchResult, SearchError>) -> Void
    ) {
        // Generate cache key for search
        let cacheKey = query.cacheKey
        
        // Check cache first for recent searches
        if let cached = cacheService?.getCachedSearchResult(key: cacheKey) {
            completion(.success(cached))
            return
        }
        
        // Fetch base tasks based on scope
        fetchBaseTasks(for: query.scope) { [weak self] (result: Result<[Task], Error>) in
            switch result {
            case .success(let tasks):
                let searchResults = self?.performSearch(in: tasks, query: query) ?? []
                let result = SearchResult(
                    tasks: searchResults,
                    query: query,
                    totalMatches: searchResults.count,
                    searchTime: Date()
                )
                
                // Cache the result
                self?.cacheService?.cacheSearchResult(result, key: cacheKey)
                
                completion(.success(result))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Simple text search in task names and details
    public func simpleSearch(
        text: String,
        in scope: TaskSearchScope = TaskSearchScope.all,
        completion: @escaping (Result<[Task], SearchError>) -> Void
    ) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(.emptyQuery))
            return
        }
        
        let query = SearchQuery(
            text: text,
            scope: scope,
            fields: [SearchField.name, SearchField.details],
            matchMode: SearchMatchMode.contains,
            caseSensitive: false,
            exactPhrase: false
        )
        
        searchTasks(query: query) { result in
            switch result {
            case .success(let searchResult):
                completion(.success(searchResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Search by task name only
    public func searchByName(
        _ name: String,
        exactMatch: Bool = false,
        completion: @escaping (Result<[Task], SearchError>) -> Void
    ) {
        let query = SearchQuery(
            text: name,
            scope: TaskSearchScope.all,
            fields: [SearchField.name],
            matchMode: exactMatch ? SearchMatchMode.exact : SearchMatchMode.contains,
            caseSensitive: false,
            exactPhrase: exactMatch
        )
        
        searchTasks(query: query) { result in
            switch result {
            case .success(let searchResult):
                completion(.success(searchResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Search by tags
    public func searchByTags(
        _ tags: [String],
        matchMode: SearchTasksUseCase.TagMatchMode = SearchTasksUseCase.TagMatchMode.any,
        completion: @escaping (Result<[Task], SearchError>) -> Void
    ) {
        let query = SearchQuery(
            text: "",
            scope: TaskSearchScope.all,
            fields: [SearchField.tags],
            matchMode: SearchMatchMode.contains,
            caseSensitive: false,
            exactPhrase: false,
            tags: tags,
            tagMatchMode: matchMode
        )
        
        searchTasks(query: query) { result in
            switch result {
            case .success(let searchResult):
                completion(.success(searchResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Search within a specific project
    public func searchInProject(
        _ projectName: String,
        text: String,
        completion: @escaping (Result<[Task], SearchError>) -> Void
    ) {
        let query = SearchQuery(
            text: text,
            scope: TaskSearchScope.project(projectName),
            fields: [SearchField.name, SearchField.details],
            matchMode: SearchMatchMode.contains,
            caseSensitive: false,
            exactPhrase: false
        )
        
        searchTasks(query: query) { result in
            switch result {
            case .success(let searchResult):
                completion(.success(searchResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Advanced search with multiple criteria
    public func advancedSearch(
        text: String? = nil,
        priority: TaskPriority? = nil,
        category: TaskCategory? = nil,
        context: TaskContext? = nil,
        energy: TaskEnergy? = nil,
        tags: [String] = [],
        hasEstimate: Bool? = nil,
        isOverdue: Bool? = nil,
        completion: @escaping (Result<[Task], SearchError>) -> Void
    ) {
        let query = SearchQuery(
            text: text ?? "",
            scope: TaskSearchScope.all,
            fields: [SearchField.name, SearchField.details],
            matchMode: SearchMatchMode.contains,
            caseSensitive: false,
            exactPhrase: false,
            priority: priority,
            category: category,
            context: context,
            energy: energy,
            tags: tags,
            hasEstimate: hasEstimate,
            isOverdue: isOverdue
        )
        
        searchTasks(query: query) { result in
            switch result {
            case .success(let searchResult):
                completion(.success(searchResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Search for tasks due in a specific time frame
    public func searchByDueDate(
        from startDate: Date,
        to endDate: Date,
        text: String? = nil,
        completion: @escaping (Result<[Task], SearchError>) -> Void
    ) {
        let query = SearchQuery(
            text: text ?? "",
            scope: TaskSearchScope.dateRange(startDate, endDate),
            fields: [SearchField.name, SearchField.details],
            matchMode: SearchMatchMode.contains,
            caseSensitive: false,
            exactPhrase: false
        )
        
        searchTasks(query: query) { result in
            switch result {
            case .success(let searchResult):
                completion(.success(searchResult.tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get search suggestions based on partial input
    public func getSearchSuggestions(
        partialText: String,
        maxSuggestions: Int = 10,
        completion: @escaping (Result<[SearchSuggestion], SearchError>) -> Void
    ) {
        guard partialText.count >= 2 else {
            completion(.success([]))
            return
        }
        
        taskRepository.fetchAllTasks { result in
            switch result {
            case .success(let tasks):
                var suggestions: [SearchSuggestion] = []
                
                // Task name suggestions
                let nameSuggestions = tasks.compactMap { task -> SearchSuggestion? in
                    if task.name.localizedCaseInsensitiveContains(partialText) {
                        return SearchSuggestion(
                            text: task.name,
                            type: .taskName,
                            task: task
                        )
                    }
                    return nil
                }
                suggestions.append(contentsOf: nameSuggestions)
                
                // Project suggestions
                let uniqueProjects = Set(tasks.compactMap { $0.project })
                let projectSuggestions = uniqueProjects.compactMap { project -> SearchSuggestion? in
                    if project.localizedCaseInsensitiveContains(partialText) {
                        return SearchSuggestion(
                            text: project,
                            type: .project,
                            task: nil
                        )
                    }
                    return nil
                }
                suggestions.append(contentsOf: projectSuggestions)
                
                // Tag suggestions
                let allTags = Set(tasks.flatMap { $0.tags })
                let tagSuggestions = allTags.compactMap { tag -> SearchSuggestion? in
                    if tag.localizedCaseInsensitiveContains(partialText) {
                        return SearchSuggestion(
                            text: tag,
                            type: .tag,
                            task: nil
                        )
                    }
                    return nil
                }
                suggestions.append(contentsOf: tagSuggestions)
                
                // Limit and sort suggestions
                let sortedSuggestions = suggestions
                    .sorted { $0.text.count < $1.text.count }
                    .prefix(maxSuggestions)
                
                completion(.success(Array(sortedSuggestions)))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchBaseTasks(
        for scope: TaskSearchScope,
        completion: @escaping (Result<[Task], Error>) -> Void
    ) {
        switch scope {
        case TaskSearchScope.all:
            taskRepository.fetchAllTasks(completion: completion)
        case TaskSearchScope.today:
            taskRepository.fetchTodayTasks(completion: completion)
        case TaskSearchScope.upcoming:
            taskRepository.fetchUpcomingTasks(completion: completion)
        case TaskSearchScope.overdue:
            taskRepository.fetchOverdueTasks(completion: completion)
        case TaskSearchScope.project(let name):
            taskRepository.fetchTasks(for: name, completion: completion)
        case TaskSearchScope.dateRange(let start, let end):
            taskRepository.fetchTasks(from: start, to: end, completion: completion)
        case TaskSearchScope.completed:
            taskRepository.fetchCompletedTasks(completion: completion)
        }
    }
    
    private func performSearch(in tasks: [Task], query: SearchQuery) -> [Task] {
        return tasks.filter { task in
            var matches = true
            
            // Text search in specified fields
            if !query.text.isEmpty {
                var textMatches = false
                
                for field in query.fields {
                    let fieldText: String
                    switch field {
                    case SearchField.name:
                        fieldText = task.name
                    case SearchField.details:
                        fieldText = task.details ?? ""
                    case SearchField.project:
                        fieldText = task.project ?? ""
                    case SearchField.tags:
                        fieldText = task.tags.joined(separator: " ")
                    }
                    
                    let searchText = query.caseSensitive ? query.text : query.text.lowercased()
                    let targetText = query.caseSensitive ? fieldText : fieldText.lowercased()
                    
                    switch query.matchMode {
                    case SearchMatchMode.exact:
                        if targetText == searchText {
                            textMatches = true
                            break
                        }
                    case SearchMatchMode.contains:
                        if query.exactPhrase {
                            if targetText.contains(searchText) {
                                textMatches = true
                                break
                            }
                        } else {
                            let searchWords = searchText.components(separatedBy: .whitespacesAndNewlines)
                            let hasAllWords = searchWords.allSatisfy { word in
                                targetText.contains(word)
                            }
                            if hasAllWords {
                                textMatches = true
                                break
                            }
                        }
                    case .startsWith:
                        if targetText.hasPrefix(searchText) {
                            textMatches = true
                            break
                        }
                    case .endsWith:
                        if targetText.hasSuffix(searchText) {
                            textMatches = true
                            break
                        }
                    }
                }
                
                if !textMatches {
                    matches = false
                }
            }
            
            // Filter by priority
            if let priority = query.priority, task.priority != priority {
                matches = false
            }
            
            // Filter by category
            if let category = query.category, task.category != category {
                matches = false
            }
            
            // Filter by context
            if let context = query.context, task.context != context {
                matches = false
            }
            
            // Filter by energy
            if let energy = query.energy, task.energy != energy {
                matches = false
            }
            
            // Filter by tags
            if !query.tags.isEmpty {
                switch query.tagMatchMode {
                case SearchTasksUseCase.TagMatchMode.any:
                    let hasAnyTag = query.tags.contains { tag in
                        task.tags.contains(tag)
                    }
                    if !hasAnyTag {
                        matches = false
                    }
                case SearchTasksUseCase.TagMatchMode.all:
                    let hasAllTags = query.tags.allSatisfy { tag in
                        task.tags.contains(tag)
                    }
                    if !hasAllTags {
                        matches = false
                    }
                }
            }
            
            // Filter by estimate
            if let hasEstimate = query.hasEstimate {
                if hasEstimate && task.estimatedDuration == nil {
                    matches = false
                }
                if !hasEstimate && task.estimatedDuration != nil {
                    matches = false
                }
            }
            
            // Filter by overdue status
            if let isOverdue = query.isOverdue {
                if isOverdue != task.isOverdue {
                    matches = false
                }
            }
            
            return matches
        }
    }
}

// MARK: - Supporting Models

public struct SearchQuery: Codable {
    public let text: String
    public let scope: TaskSearchScope
    public let fields: [SearchField]
    public let matchMode: SearchMatchMode
    public let caseSensitive: Bool
    public let exactPhrase: Bool

    // Advanced filters
    public let priority: TaskPriority?
    public let category: TaskCategory?
    public let context: TaskContext?
    public let energy: TaskEnergy?
    public let tags: [String]
    public let tagMatchMode: SearchTasksUseCase.TagMatchMode
    public let hasEstimate: Bool?
    public let isOverdue: Bool?
    
    public init(
        text: String,
        scope: TaskSearchScope,
        fields: [SearchField],
        matchMode: SearchMatchMode,
        caseSensitive: Bool,
        exactPhrase: Bool,
        priority: TaskPriority? = nil,
        category: TaskCategory? = nil,
        context: TaskContext? = nil,
        energy: TaskEnergy? = nil,
        tags: [String] = [],
        tagMatchMode: SearchTasksUseCase.TagMatchMode = SearchTasksUseCase.TagMatchMode.any,
        hasEstimate: Bool? = nil,
        isOverdue: Bool? = nil
    ) {
        self.text = text
        self.scope = scope
        self.fields = fields
        self.matchMode = matchMode
        self.caseSensitive = caseSensitive
        self.exactPhrase = exactPhrase
        self.priority = priority
        self.category = category
        self.context = context
        self.energy = energy
        self.tags = tags
        self.tagMatchMode = tagMatchMode
        self.hasEstimate = hasEstimate
        self.isOverdue = isOverdue
    }
    
    var cacheKey: String {
        var components: [String] = []
        components.append("text:\(text)")
        components.append("scope:\(scope)")
        components.append("fields:\(fields)")
        components.append("mode:\(matchMode)")
        if caseSensitive { components.append("caseSensitive") }
        if exactPhrase { components.append("exactPhrase") }
        if let priority = priority { components.append("priority:\(priority.rawValue)") }
        if let category = category { components.append("category:\(category.rawValue)") }
        if let context = context { components.append("context:\(context.rawValue)") }
        if let energy = energy { components.append("energy:\(energy.rawValue)") }
        if !tags.isEmpty { components.append("tags:\(tags.joined(separator:","))") }
        if let hasEstimate = hasEstimate { components.append("estimate:\(hasEstimate)") }
        if let isOverdue = isOverdue { components.append("overdue:\(isOverdue)") }
        
        return components.joined(separator:"|")
    }
}

public enum TaskSearchScope: Codable {
    case all
    case today
    case upcoming
    case overdue
    case completed
    case project(String)
    case dateRange(Date, Date)
}

public enum SearchField: Codable {
    case name
    case details
    case project
    case tags
}

public enum SearchMatchMode: Codable {
    case exact
    case contains
    case startsWith
    case endsWith
}

public struct SearchResult: Codable {
    public let tasks: [Task]
    public let query: SearchQuery
    public let totalMatches: Int
    public let searchTime: Date
}

public struct SearchSuggestion {
    public let text: String
    public let type: SuggestionType
    public let task: Task?
    
    public enum SuggestionType {
        case taskName
        case project
        case tag
    }
}

// MARK: - Error Types

public enum SearchError: LocalizedError {
    case repositoryError(Error)
    case emptyQuery
    case invalidScope
    case tooManyResults(Int)
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .emptyQuery:
            return "Search query cannot be empty"
        case .invalidScope:
            return "Invalid search scope specified"
        case .tooManyResults(let count):
            return "Too many results (\(count)). Please refine your search."
        }
    }
}