//
//  InMemoryCacheService.swift
//  Tasker
//
//  In-memory implementation of CacheServiceProtocol
//

import Foundation

/// In-memory cache implementation with TTL support
public final class InMemoryCacheService: CacheServiceProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "com.tasker.cache", attributes: .concurrent)
    private var _statistics = CacheStatistics()
    private var statistics: CacheStatistics {
        get { queue.sync { _statistics } }
        set { queue.async(flags: .barrier) { self._statistics = newValue } }
    }
    
    // MARK: - Cache Entry
    
    private struct CacheEntry {
        let data: Data
        let expiration: Date?
        let createdAt: Date
        
        var isExpired: Bool {
            guard let expiration = expiration else { return false }
            return Date() > expiration
        }
    }
    
    // MARK: - Cache Operations
    
    public func set<T: Codable & Sendable>(_ object: T, forKey key: String, expiration: CacheExpiration?) {
        queue.async(flags: .barrier) {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(object)
                let expirationDate = expiration?.expirationDate
                
                self.cache[key] = CacheEntry(
                    data: data,
                    expiration: expirationDate,
                    createdAt: Date()
                )
            } catch {
                logError(" Cache encoding error for key \(key): \(error)")
            }
        }
    }
    
    public func get<T: Codable & Sendable>(_ type: T.Type, forKey key: String) -> T? {
        var result: T?

        queue.sync {
            guard let entry = cache[key] else {
                queue.async(flags: .barrier) {
                    self._statistics = CacheStatistics(
                        totalRequests: self._statistics.totalRequests + 1,
                        cacheHits: self._statistics.cacheHits,
                        cacheMisses: self._statistics.cacheMisses + 1
                    )
                }
                return
            }

            if entry.isExpired {
                queue.async(flags: .barrier) {
                    self._statistics = CacheStatistics(
                        totalRequests: self._statistics.totalRequests + 1,
                        cacheHits: self._statistics.cacheHits,
                        cacheMisses: self._statistics.cacheMisses + 1
                    )
                    self.cache.removeValue(forKey: key)
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                result = try decoder.decode(type, from: entry.data)
                queue.async(flags: .barrier) {
                    self._statistics = CacheStatistics(
                        totalRequests: self._statistics.totalRequests + 1,
                        cacheHits: self._statistics.cacheHits + 1,
                        cacheMisses: self._statistics.cacheMisses
                    )
                }
            } catch {
                logError(" Cache decoding error for key \(key): \(error)")
                queue.async(flags: .barrier) {
                    self._statistics = CacheStatistics(
                        totalRequests: self._statistics.totalRequests + 1,
                        cacheHits: self._statistics.cacheHits,
                        cacheMisses: self._statistics.cacheMisses + 1
                    )
                }
            }
        }

        return result
    }
    
    /// Executes remove.
    public func remove(forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    /// Executes exists.
    public func exists(forKey key: String) -> Bool {
        var exists = false
        
        queue.sync {
            if let entry = cache[key], !entry.isExpired {
                exists = true
            }
        }
        
        return exists
    }
    
    /// Executes clearAll.
    public func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            self._statistics = CacheStatistics()
        }
    }
    
    /// Executes clearExpired.
    public func clearExpired() {
        queue.async(flags: .barrier) {
            let expiredKeys = self.cache.compactMap { key, entry in
                entry.isExpired ? key : nil
            }
            
            expiredKeys.forEach { key in
                self.cache.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Task-specific Caching
    
    /// Executes cacheTasks.
    public func cacheTasks(_ tasks: [TaskDefinition], forDate date: Date) {
        let key = "tasks_\(date.cacheKey)"
        set(tasks, forKey: key, expiration: .minutes(15))
    }

    /// Executes getCachedTasks.
    public func getCachedTasks(forDate date: Date) -> [TaskDefinition]? {
        let key = "tasks_\(date.cacheKey)"
        return get([TaskDefinition].self, forKey: key)
    }

    /// Executes cacheTasks.
    public func cacheTasks(_ tasks: [TaskDefinition], forProjectID projectID: UUID) {
        let key = "tasks_project_\(projectID.uuidString.lowercased())"
        set(tasks, forKey: key, expiration: .minutes(10))
    }

    /// Executes getCachedTasks.
    public func getCachedTasks(forProjectID projectID: UUID) -> [TaskDefinition]? {
        let key = "tasks_project_\(projectID.uuidString.lowercased())"
        return get([TaskDefinition].self, forKey: key)
    }
    
    // MARK: - Project-specific Caching
    
    /// Executes cacheProjects.
    public func cacheProjects(_ projects: [Project]) {
        set(projects, forKey: "all_projects", expiration: .minutes(30))
    }
    
    /// Executes getCachedProjects.
    public func getCachedProjects() -> [Project]? {
        return get([Project].self, forKey: "all_projects")
    }
    
    // MARK: - Cache Statistics
    
    /// Executes getCacheSize.
    public func getCacheSize() -> Int {
        var totalSize = 0
        
        queue.sync {
            totalSize = cache.values.reduce(0) { $0 + $1.data.count }
        }
        
        return totalSize
    }
    
    /// Executes getCacheItemCount.
    public func getCacheItemCount() -> Int {
        var count = 0
        
        queue.sync {
            count = cache.count
        }
        
        return count
    }
    
    /// Executes getCacheStatistics.
    public func getCacheStatistics() -> CacheStatistics {
        var stats: CacheStatistics!

        queue.sync {
            stats = CacheStatistics(
                totalRequests: _statistics.totalRequests,
                cacheHits: _statistics.cacheHits,
                cacheMisses: _statistics.cacheMisses,
                averageResponseTime: 0.001, // In-memory is very fast
                cacheSize: getCacheSize(),
                itemCount: cache.count
            )
        }

        return stats
    }

}

// MARK: - Date Extension

private extension Date {
    var cacheKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}
