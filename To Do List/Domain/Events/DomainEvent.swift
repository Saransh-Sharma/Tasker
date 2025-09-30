//
//  DomainEvent.swift
//  Tasker
//
//  Base protocol for all domain events
//

import Foundation

/// Base protocol for all domain events
public protocol DomainEvent {
    /// Unique identifier for the event
    var id: UUID { get }
    
    /// Timestamp when the event occurred
    var occurredAt: Date { get }
    
    /// Type name of the event for identification
    var eventType: String { get }
    
    /// Version of the event structure for compatibility
    var eventVersion: Int { get }
    
    /// Aggregate ID that this event relates to
    var aggregateId: UUID { get }
    
    /// User ID who triggered the event (if applicable)
    var userId: UUID? { get }
}

/// Protocol for events that can be converted to/from dictionary for persistence
public protocol SerializableDomainEvent: DomainEvent {
    /// Convert event to dictionary for storage
    func toDictionary() -> [String: Any]
    
    /// Create event from dictionary
    static func fromDictionary(_ dict: [String: Any]) -> Self?
}

/// Base implementation of domain event
public struct BaseDomainEvent: DomainEvent {
    public let id: UUID
    public let occurredAt: Date
    public let eventType: String
    public let eventVersion: Int
    public let aggregateId: UUID
    public let userId: UUID?
    
    public init(
        id: UUID = UUID(),
        occurredAt: Date = Date(),
        eventType: String,
        eventVersion: Int = 1,
        aggregateId: UUID,
        userId: UUID? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.eventType = eventType
        self.eventVersion = eventVersion
        self.aggregateId = aggregateId
        self.userId = userId
    }
}