//
//  TaskRepositoryProtocol.swift
//  Tasker
//
//  Protocol defining the interface for Task data operations
//

import Foundation

/// Protocol defining all task-related data operations
/// This abstraction allows for different implementations (Core Data, Mock, etc.)
public protocol TaskRepositoryProtocol {
    
    // MARK: - Fetch Operations
    
    /// Fetch all tasks
    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Fetch tasks for a specific date
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Fetch tasks for today
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Fetch tasks by project
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Fetch overdue tasks
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Fetch upcoming tasks
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Fetch completed tasks
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Fetch tasks by type
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Fetch a single task by ID
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void)
    
    /// Fetch tasks in a date range
    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void)
    
    // MARK: - Create Operations
    
    /// Create a new task
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void)
    
    // MARK: - Update Operations
    
    /// Update an existing task
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void)
    
    /// Mark a task as complete
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void)
    
    /// Mark a task as incomplete
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void)
    
    /// Reschedule a task to a new date
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void)
    
    // MARK: - Delete Operations
    
    /// Delete a task
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Delete all completed tasks
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void)
    
    // MARK: - Batch Operations
    
    /// Create multiple tasks
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Update multiple tasks
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void)
    
    /// Delete multiple tasks
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void)
}
