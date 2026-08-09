import LifeBoardContracts
import LifeBoardDomain
import LifeBoardPersistence
import LifeBoardTokens
import LifeBoardUI
//
//  PersonalKnowledgeGraph.swift
//  KnowledgeGraphKit
//
//  Your world — people, places, topics, and their connections — with
//  importance decay. Persisted as an app-owned blob via KnowledgeGraphStore.
//

import Foundation

public struct PersonalKnowledgeGraph: Codable, Sendable {
    public var nodes: [String: KnowledgeNode] = [:]
    public var edges: [KnowledgeEdge] = []

    public init() {}

    public struct KnowledgeNode: Codable, Identifiable, Sendable {
        public let id: String  // Unique identifier (lowercased name)
        public var label: String  // Display name
        public var type: NodeType
        public var mentions: Int
        public var firstSeen: Date
        public var lastSeen: Date
        public var sentimentAssociation: Double  // How you feel about this
        public var importance: Double  // Calculated importance score

        public enum NodeType: String, Codable, Sendable, CaseIterable {
            case person, place, topic, activity, goal, fear, value, event
        }

        public init(
            id: String,
            label: String,
            type: NodeType,
            mentions: Int = 0,
            firstSeen: Date,
            lastSeen: Date,
            sentimentAssociation: Double = 0,
            importance: Double = 0
        ) {
            self.id = id
            self.label = label
            self.type = type
            self.mentions = mentions
            self.firstSeen = firstSeen
            self.lastSeen = lastSeen
            self.sentimentAssociation = sentimentAssociation
            self.importance = importance
        }
    }

    public struct KnowledgeEdge: Codable, Sendable {
        public var from: String
        public var to: String
        public var weight: Double
        public var relationship: String?  // e.g., "friend", "coworker", "causes", "related to"

        public init(from: String, to: String, weight: Double = 1.0, relationship: String? = nil) {
            self.from = from
            self.to = to
            self.weight = weight
            self.relationship = relationship
        }
    }

    public mutating func addOrUpdate(id: String, label: String, type: KnowledgeNode.NodeType, sentiment: Double = 0) {
        let key = id.lowercased()
        if var node = nodes[key] {
            node.mentions += 1
            node.lastSeen = Date()
            node.sentimentAssociation = node.sentimentAssociation * 0.8 + sentiment * 0.2
            node.importance = Self.calculateImportance(mentions: node.mentions, lastSeen: node.lastSeen, sentiment: node.sentimentAssociation)
            nodes[key] = node
        } else {
            let now = Date()
            nodes[key] = KnowledgeNode(
                id: key,
                label: label,
                type: type,
                mentions: 1,
                firstSeen: now,
                lastSeen: now,
                sentimentAssociation: sentiment,
                importance: 0.1
            )
        }
    }

    public mutating func connect(_ from: String, to: String, relationship: String? = nil) {
        let fromKey = from.lowercased()
        let toKey = to.lowercased()

        if let idx = edges.firstIndex(where: { $0.from == fromKey && $0.to == toKey }) {
            edges[idx].weight += 0.1
        } else {
            edges.append(KnowledgeEdge(from: fromKey, to: toKey, weight: 1.0, relationship: relationship))
        }
    }

    static func calculateImportance(mentions: Int, lastSeen: Date, sentiment: Double) -> Double {
        let days = Calendar.current.dateComponents([.day], from: lastSeen, to: Date()).day ?? 0
        let recency = exp(-Double(days) / 14.0)
        let frequency = min(1.0, Double(mentions) / 20.0)
        let emotionalWeight = abs(sentiment) * 0.3
        return (frequency * 0.4 + recency * 0.4 + emotionalWeight * 0.2)
    }

    public func topNodes(ofType type: KnowledgeNode.NodeType? = nil, limit: Int = 10) -> [KnowledgeNode] {
        let filtered = type == nil ? Array(nodes.values) : nodes.values.filter { $0.type == type }
        return filtered.sorted { $0.importance > $1.importance }.prefix(limit).map { $0 }
    }

    public func connections(for nodeId: String) -> [(node: KnowledgeNode, relationship: String?)] {
        let key = nodeId.lowercased()
        let connectedIds = edges.filter { $0.from == key || $0.to == key }
        return connectedIds.compactMap { edge in
            let otherId = edge.from == key ? edge.to : edge.from
            guard let node = nodes[otherId] else { return nil }
            return (node, edge.relationship)
        }
    }
}

/// App-owned persistence seam: OffRecord stores the graph in its AIState
/// entity; LifeBoard stores it in the LocalOnly DerivedBlobStore entity.
public protocol KnowledgeGraphStore: Sendable {
    func loadGraph() async throws -> PersonalKnowledgeGraph?
    func saveGraph(_ graph: PersonalKnowledgeGraph) async throws
}
