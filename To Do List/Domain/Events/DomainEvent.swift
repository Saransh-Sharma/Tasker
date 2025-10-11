//
//  DomainEvent.swift
//  Tasker
//
//  Protocol for domain events in the event-driven architecture
//

import Foundation

/// Protocol for domain events that represent something important that happened in the domain
public protocol DomainEvent {
    
    /// Unique identifier for the event
    var eventId: UUID { get }
    
    /// Timestamp when the event occurred
    var occurredAt: Date { get }
    
    /// Type of the event
    var eventType: String { get }
    
    /// ID of the aggregate that this event belongs to
    var aggregateId: UUID { get }
    
    /// Optional metadata associated with the event
    var metadata: [String: Any]? { get }
}

/// Protocol for serializable domain events that can be persisted or transmitted
public protocol SerializableDomainEvent: DomainEvent {
    /// Convert event to dictionary for serialization
    func toDictionary() -> [String: Any]
    
    /// Create event from dictionary for deserialization
    static func fromDictionary(_ dict: [String: Any]) -> Self?
}

/// Base implementation for domain events
public struct BaseDomainEvent: DomainEvent {
    public let eventId: UUID
    public let occurredAt: Date
    public let eventType: String
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    
    public init(eventType: String, aggregateId: UUID, metadata: [String: Any]? = nil) {
        self.eventId = UUID()
        self.occurredAt = Date()
        self.eventType = eventType
        self.aggregateId = aggregateId
        self.metadata = metadata
    }
}