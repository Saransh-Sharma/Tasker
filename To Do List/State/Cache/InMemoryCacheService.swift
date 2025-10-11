//
//  InMemoryCacheService.swift
//  Tasker
//
//  In-memory implementation of CacheServiceProtocol
//

import Foundation

/// In-memory cache implementation with TTL support
final class InMemoryCacheService: CacheServiceProtocol {
    
    // MARK: - Properties
    
    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "com.tasker.cache", attributes: .concurrent)
    private var statistics = CacheStatistics()
    
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
    
    func set<T: Codable>(_ object: T, forKey key: String, expiration: CacheExpiration?) {
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
                print("❌ Cache encoding error for key \(key): \(error)")
            }
        }
    }
    
    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        var result: T?
        
        queue.sync {
            statistics.totalRequests += 1
            
            guard let entry = cache[key] else {
                statistics.cacheMisses += 1
                return
            }
            
            if entry.isExpired {
                statistics.cacheMisses += 1
                // Remove expired entry
                queue.async(flags: .barrier) {
                    self.cache.removeValue(forKey: key)
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                result = try decoder.decode(type, from: entry.data)
                statistics.cacheHits += 1
            } catch {
                print("❌ Cache decoding error for key \(key): \(error)")
                statistics.cacheMisses += 1
            }
        }
        
        return result
    }
    
    func remove(forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    func exists(forKey key: String) -> Bool {
        var exists = false
        
        queue.sync {
            if let entry = cache[key], !entry.isExpired {
                exists = true
            }
        }
        
        return exists
    }
    
    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            self.statistics = CacheStatistics()
        }
    }
    
    func clearExpired() {
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
    
    func cacheTasks(_ tasks: [Task], forDate date: Date) {
        let key = "tasks_\(date.cacheKey)"
        set(tasks, forKey: key, expiration: .minutes(15))
    }
    
    func getCachedTasks(forDate date: Date) -> [Task]? {
        let key = "tasks_\(date.cacheKey)"
        return get([Task].self, forKey: key)
    }
    
    func cacheTasks(_ tasks: [Task], forProject projectName: String) {
        let key = "tasks_project_\(projectName.lowercased())"
        set(tasks, forKey: key, expiration: .minutes(10))
    }
    
    func getCachedTasks(forProject projectName: String) -> [Task]? {
        let key = "tasks_project_\(projectName.lowercased())"
        return get([Task].self, forKey: key)
    }
    
    // MARK: - Project-specific Caching
    
    func cacheProjects(_ projects: [Project]) {
        set(projects, forKey: "all_projects", expiration: .minutes(30))
    }
    
    func getCachedProjects() -> [Project]? {
        return get([Project].self, forKey: "all_projects")
    }
    
    // MARK: - Cache Statistics
    
    func getCacheSize() -> Int {
        var totalSize = 0
        
        queue.sync {
            totalSize = cache.values.reduce(0) { $0 + $1.data.count }
        }
        
        return totalSize
    }
    
    func getCacheItemCount() -> Int {
        var count = 0
        
        queue.sync {
            count = cache.count
        }
        
        return count
    }
    
    func getCacheStatistics() -> CacheStatistics {
        var stats: CacheStatistics!
        
        queue.sync {
            stats = CacheStatistics(
                totalRequests: statistics.totalRequests,
                cacheHits: statistics.cacheHits,
                cacheMisses: statistics.cacheMisses,
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
