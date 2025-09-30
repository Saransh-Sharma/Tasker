//
//  DomainEventPublisher.swift
//  Tasker
//
//  Domain event publisher for cross-cutting concerns
//

import Foundation
import Combine

/// Protocol for handling domain events
public protocol DomainEventHandler {
    /// Handle a domain event
    func handle(_ event: DomainEvent)
    
    /// Check if this handler can process the given event type
    func canHandle(_ eventType: String) -> Bool
}

/// Domain event publisher using Combine for reactive event handling
public final class DomainEventPublisher: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = DomainEventPublisher()
    
    // MARK: - Properties
    
    private var eventHandlers: [DomainEventHandler] = []
    private var eventStorage: [DomainEvent] = []
    private var cancellables = Set<AnyCancellable>()
    
    /// Subject for publishing domain events
    public let eventSubject = PassthroughSubject<DomainEvent, Never>()
    
    // MARK: - Initialization
    
    private init() {
        setupEventLogging()
    }
    
    // MARK: - Public Methods
    
    /// Publish a domain event
    public func publish(_ event: DomainEvent) {
        // Store event for replay/debugging
        eventStorage.append(event)
        
        // Notify handlers
        for handler in eventHandlers {
            if handler.canHandle(event.eventType) {
                handler.handle(event)
            }
        }
        
        // Publish to Combine subscribers
        eventSubject.send(event)
        
        print("📤 Domain Event Published: \(event.eventType) for aggregate \(event.aggregateId)")
    }
    
    /// Register an event handler
    public func register(handler: DomainEventHandler) {
        eventHandlers.append(handler)
        print("📝 Registered event handler for events: \(type(of: handler))")
    }
    
    /// Unregister an event handler
    public func unregister(handler: DomainEventHandler) {
        eventHandlers.removeAll { existingHandler in
            return ObjectIdentifier(existingHandler as AnyObject) == ObjectIdentifier(handler as AnyObject)
        }
    }
    
    /// Get all events for a specific aggregate
    public func getEventsForAggregate(_ aggregateId: UUID) -> [DomainEvent] {
        return eventStorage.filter { $0.aggregateId == aggregateId }
    }
    
    /// Get all events of a specific type
    public func getEventsOfType(_ eventType: String) -> [DomainEvent] {
        return eventStorage.filter { $0.eventType == eventType }
    }
    
    /// Clear all stored events (use with caution)
    public func clearEventStorage() {
        eventStorage.removeAll()
        print("🗑️ Event storage cleared")
    }
    
    /// Get recent events (last N events)
    public func getRecentEvents(limit: Int = 50) -> [DomainEvent] {
        return Array(eventStorage.suffix(limit))
    }
    
    // MARK: - Reactive Publishers
    
    /// Publisher for task-related events
    public var taskEvents: AnyPublisher<DomainEvent, Never> {
        return eventSubject
            .filter { event in
                event.eventType.hasPrefix("Task")
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for project-related events
    public var projectEvents: AnyPublisher<DomainEvent, Never> {
        return eventSubject
            .filter { event in
                event.eventType.hasPrefix("Project")
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for specific event types
    public func publisher(for eventType: String) -> AnyPublisher<DomainEvent, Never> {
        return eventSubject
            .filter { event in
                event.eventType == eventType
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for specific aggregate
    public func publisher(for aggregateId: UUID) -> AnyPublisher<DomainEvent, Never> {
        return eventSubject
            .filter { event in
                event.aggregateId == aggregateId
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func setupEventLogging() {
        eventSubject
            .sink { event in
                self.logEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func logEvent(_ event: DomainEvent) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: event.occurredAt)
        
        print("📋 [\(timestamp)] \(event.eventType) - Aggregate: \(event.aggregateId.uuidString.prefix(8))")
    }
}

// MARK: - Built-in Event Handlers

/// Analytics event handler
public final class AnalyticsEventHandler: DomainEventHandler {
    
    public func handle(_ event: DomainEvent) {
        switch event.eventType {
        case "TaskCompleted":
            if let taskEvent = event as? TaskCompletedEvent {
                recordTaskCompletion(taskEvent)
            }
        case "TaskCreated":
            if let taskEvent = event as? TaskCreatedEvent {
                recordTaskCreation(taskEvent)
            }
        case "ProjectCreated":
            if let projectEvent = event as? ProjectCreatedEvent {
                recordProjectCreation(projectEvent)
            }
        default:
            break
        }
    }
    
    public func canHandle(_ eventType: String) -> Bool {
        return ["TaskCompleted", "TaskCreated", "ProjectCreated"].contains(eventType)
    }
    
    private func recordTaskCompletion(_ event: TaskCompletedEvent) {
        // Record analytics for task completion
        print("📊 Analytics: Task completed - Score: \(event.scoreEarned)")
    }
    
    private func recordTaskCreation(_ event: TaskCreatedEvent) {
        // Record analytics for task creation
        print("📊 Analytics: Task created - Priority: \(event.taskPriority.displayName)")
    }
    
    private func recordProjectCreation(_ event: ProjectCreatedEvent) {
        // Record analytics for project creation
        print("📊 Analytics: Project created - \(event.projectName)")
    }
}

/// Notification event handler
public final class NotificationEventHandler: DomainEventHandler {
    
    public func handle(_ event: DomainEvent) {
        switch event.eventType {
        case "TaskCompleted":
            if let taskEvent = event as? TaskCompletedEvent {
                sendCompletionNotification(taskEvent)
            }
        case "ProjectArchived":
            if let projectEvent = event as? ProjectArchivedEvent {
                sendArchiveNotification(projectEvent)
            }
        default:
            break
        }
    }
    
    public func canHandle(_ eventType: String) -> Bool {
        return ["TaskCompleted", "ProjectArchived"].contains(eventType)
    }
    
    private func sendCompletionNotification(_ event: TaskCompletedEvent) {
        // Send notification for task completion
        NotificationCenter.default.post(
            name: NSNotification.Name("TaskCompletionChanged"),
            object: nil,
            userInfo: ["taskId": event.aggregateId, "score": event.scoreEarned]
        )
    }
    
    private func sendArchiveNotification(_ event: ProjectArchivedEvent) {
        // Send notification for project archive
        NotificationCenter.default.post(
            name: NSNotification.Name("ProjectArchived"),
            object: nil,
            userInfo: ["projectId": event.aggregateId, "projectName": event.projectName]
        )
    }
}