//
//  CacheServiceProtocol.swift
//  Tasker
//
//  Protocol defining the interface for caching operations
//

import Foundation

/// Protocol defining caching operations for performance optimization
public protocol CacheServiceProtocol {
    
    // MARK: - Cache Operations
    
    /// Store an object in cache
    func set<T: Codable>(_ object: T, forKey key: String, expiration: CacheExpiration?)
    
    /// Retrieve an object from cache
    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T?
    
    /// Remove an object from cache
    func remove(forKey key: String)
    
    /// Check if a key exists in cache
    func exists(forKey key: String) -> Bool
    
    /// Clear all cached data
    func clearAll()
    
    /// Clear expired cache entries
    func clearExpired()
    
    // MARK: - Task-specific Caching
    
    /// Cache tasks for a specific date
    func cacheTasks(_ tasks: [Task], forDate date: Date)
    
    /// Get cached tasks for a specific date
    func getCachedTasks(forDate date: Date) -> [Task]?
    
    /// Cache tasks for a specific project
    func cacheTasks(_ tasks: [Task], forProject projectName: String)
    
    /// Get cached tasks for a specific project
    func getCachedTasks(forProject projectName: String) -> [Task]?
    
    // MARK: - Project-specific Caching
    
    /// Cache all projects
    func cacheProjects(_ projects: [Project])
    
    /// Get cached projects
    func getCachedProjects() -> [Project]?
    
    // MARK: - Advanced Caching for Use Cases
    
    /// Cache filter results
    func cacheFilterResult(_ result: FilteredTasksResult, key: String)
    
    /// Get cached filter result
    func getCachedFilterResult(key: String) -> FilteredTasksResult?
    
    /// Cache search results
    func cacheSearchResult(_ result: SearchResult, key: String)
    
    /// Get cached search result
    func getCachedSearchResult(key: String) -> SearchResult?
    
    /// Cache statistics
    func cacheStatistics(_ statistics: TaskStatistics, key: String)
    
    /// Get cached statistics
    func getCachedStatistics(key: String) -> TaskStatistics?
    
    // MARK: - Cache Statistics
    
    /// Get the current cache size in bytes
    func getCacheSize() -> Int
    
    /// Get the number of cached items
    func getCacheItemCount() -> Int
    
    /// Get cache hit rate statistics
    func getCacheStatistics() -> CacheStatistics
}

// MARK: - Supporting Types

/// Cache expiration policy
public enum CacheExpiration {
    case never
    case seconds(TimeInterval)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case date(Date)
    
    var expirationDate: Date? {
        switch self {
        case .never:
            return nil
        case .seconds(let interval):
            return Date().addingTimeInterval(interval)
        case .minutes(let minutes):
            return Date().addingTimeInterval(TimeInterval(minutes * 60))
        case .hours(let hours):
            return Date().addingTimeInterval(TimeInterval(hours * 3600))
        case .days(let days):
            return Date().addingTimeInterval(TimeInterval(days * 86400))
        case .date(let date):
            return date
        }
    }
}

/// Cache statistics
public struct CacheStatistics {
    public let totalRequests: Int
    public let cacheHits: Int
    public let cacheMisses: Int
    public let hitRate: Double
    public let averageResponseTime: TimeInterval
    public let cacheSize: Int
    public let itemCount: Int
    
    public init(
        totalRequests: Int = 0,
        cacheHits: Int = 0,
        cacheMisses: Int = 0,
        averageResponseTime: TimeInterval = 0,
        cacheSize: Int = 0,
        itemCount: Int = 0
    ) {
        self.totalRequests = totalRequests
        self.cacheHits = cacheHits
        self.cacheMisses = cacheMisses
        self.hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
        self.averageResponseTime = averageResponseTime
        self.cacheSize = cacheSize
        self.itemCount = itemCount
    }
}
