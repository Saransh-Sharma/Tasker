//
//  LifeBoardKnowledgeGraphStore.swift
//  LifeBoard
//
//  Phase V journal parity: persists the shared PersonalKnowledgeGraph as a
//  LocalOnly blob in the DerivedBlobStore entity. The graph is derived data —
//  rebuildable from journal entries, never synced, and (via the ingest gates)
//  never contains excluded entries' content.
//

import CoreData
import Foundation
import JournalFoundation
import KnowledgeGraphKit
import NaturalLanguage

public final class LifeBoardKnowledgeGraphStore: KnowledgeGraphStore, @unchecked Sendable {
    public static let blobKey = "journal-knowledge-graph"
    public static let blobNamespace = "journal"
    static let schemaVersion = 1

    private let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    public func loadGraph() async throws -> PersonalKnowledgeGraph? {
        let context = container.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "DerivedBlobStore")
            request.predicate = NSPredicate(
                format: "key == %@ AND namespace == %@",
                Self.blobKey, Self.blobNamespace
            )
            request.fetchLimit = 1
            guard let object = try context.fetch(request).first,
                  let payload = object.value(forKey: "payloadData") as? Data else { return nil }
            return try? JSONDecoder().decode(PersonalKnowledgeGraph.self, from: payload)
        }
    }

    public func saveGraph(_ graph: PersonalKnowledgeGraph) async throws {
        let payload = try JSONEncoder().encode(graph)
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "DerivedBlobStore")
            request.predicate = NSPredicate(
                format: "key == %@ AND namespace == %@",
                Self.blobKey, Self.blobNamespace
            )
            request.fetchLimit = 1
            let object = try context.fetch(request).first
                ?? NSEntityDescription.insertNewObject(forEntityName: "DerivedBlobStore", into: context)
            object.setValue(Self.blobKey, forKey: "key")
            object.setValue(Self.blobNamespace, forKey: "namespace")
            object.setValue(payload, forKey: "payloadData")
            object.setValue(Self.schemaVersion, forKey: "schemaVersion")
            object.setValue(Date(), forKey: "updatedAt")
            if context.hasChanges { try context.save() }
        }
    }
}

/// Rebuilds the graph from canonical snapshots instead of applying lossy
/// incremental mutations. Exclusion changes and deletion reconciliation are
/// therefore deterministic and idempotent.
public enum JournalKnowledgeGraphReconciler {
    private struct Aggregate {
        var label: String
        var type: PersonalKnowledgeGraph.KnowledgeNode.NodeType
        var mentions: Int
        var firstSeen: Date
        var lastSeen: Date
        var sentimentTotal: Double
    }

    public static func makeGraph(from snapshots: [JournalEntrySnapshot]) -> PersonalKnowledgeGraph {
        let permitted = snapshots
            .filter { $0.aiExclusion.permitsSemanticIndexing }
            .sorted { lhs, rhs in
                lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date < rhs.date
            }
        let referenceDate = permitted.map(\.date).max() ?? Date(timeIntervalSinceReferenceDate: 0)
        var aggregates: [String: Aggregate] = [:]
        var edgeWeights: [String: Double] = [:]

        for snapshot in permitted {
            let extracted = entities(in: snapshot.text)
            let entrySentiment = sentiment(in: snapshot.text)
            var entryKeys: [String] = []
            for entity in extracted {
                let key = normalizedKey(entity.label, type: entity.type)
                guard key.isEmpty == false else { continue }
                entryKeys.append(key)
                if var aggregate = aggregates[key] {
                    aggregate.mentions += 1
                    aggregate.firstSeen = min(aggregate.firstSeen, snapshot.date)
                    aggregate.lastSeen = max(aggregate.lastSeen, snapshot.date)
                    aggregate.sentimentTotal += entrySentiment
                    aggregates[key] = aggregate
                } else {
                    aggregates[key] = Aggregate(
                        label: entity.label,
                        type: entity.type,
                        mentions: 1,
                        firstSeen: snapshot.date,
                        lastSeen: snapshot.date,
                        sentimentTotal: entrySentiment
                    )
                }
            }

            let uniqueKeys = Array(Set(entryKeys)).sorted()
            for firstIndex in uniqueKeys.indices {
                for secondIndex in uniqueKeys.indices where secondIndex > firstIndex {
                    let pair = "\(uniqueKeys[firstIndex])|\(uniqueKeys[secondIndex])"
                    edgeWeights[pair, default: 0] += 1
                }
            }
        }

        var graph = PersonalKnowledgeGraph()
        graph.nodes = Dictionary(uniqueKeysWithValues: aggregates.map { key, aggregate in
            let averageSentiment = aggregate.sentimentTotal / Double(max(1, aggregate.mentions))
            let ageDays = max(0, referenceDate.timeIntervalSince(aggregate.lastSeen) / 86_400)
            let recency = exp(-ageDays / 14)
            let frequency = min(1, Double(aggregate.mentions) / 20)
            let importance = frequency * 0.4 + recency * 0.4 + abs(averageSentiment) * 0.06
            return (
                key,
                PersonalKnowledgeGraph.KnowledgeNode(
                    id: key,
                    label: aggregate.label,
                    type: aggregate.type,
                    mentions: aggregate.mentions,
                    firstSeen: aggregate.firstSeen,
                    lastSeen: aggregate.lastSeen,
                    sentimentAssociation: averageSentiment,
                    importance: min(1, importance)
                )
            )
        })
        graph.edges = edgeWeights.keys.sorted().compactMap { pair in
            let components = pair.split(separator: "|", maxSplits: 1).map(String.init)
            guard components.count == 2 else { return nil }
            return PersonalKnowledgeGraph.KnowledgeEdge(
                from: components[0],
                to: components[1],
                weight: edgeWeights[pair] ?? 1,
                relationship: "appears with"
            )
        }
        return graph
    }

    private static func entities(
        in text: String
    ) -> [(label: String, type: PersonalKnowledgeGraph.KnowledgeNode.NodeType)] {
        guard text.isEmpty == false else { return [] }
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var result: [(String, PersonalKnowledgeGraph.KnowledgeNode.NodeType)] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            let label = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard label.count > 1 else { return true }
            switch tag {
            case .personalName: result.append((label, .person))
            case .placeName: result.append((label, .place))
            case .organizationName: result.append((label, .topic))
            default: break
            }
            return true
        }
        return result
    }

    private static func sentiment(in text: String) -> Double {
        guard text.isEmpty == false else { return 0 }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let tag = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore).0
        return tag.flatMap { Double($0.rawValue) } ?? 0
    }

    private static func normalizedKey(
        _ label: String,
        type: PersonalKnowledgeGraph.KnowledgeNode.NodeType
    ) -> String {
        let normalized = label
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .joined(separator: "-")
        return normalized.isEmpty ? "" : "\(type.rawValue):\(normalized)"
    }
}

/// Fan-out point for journal derived-data invalidation. The pipeline
/// broadcasts here after every reconcile; Home projections, Eva evidence
/// views, and reflection caches subscribe instead of polling repositories.
public actor JournalProjectionInvalidationHub {
    public enum Event: Sendable {
        case projectionsInvalidated
        case reflectionsInvalidated(Set<UUID>)
    }

    public static let shared = JournalProjectionInvalidationHub()

    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    public init() {}

    public func updates() -> AsyncStream<Event> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { _ in
                Task { await self.remove(id) }
            }
        }
    }

    public func broadcast(_ event: Event) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func remove(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

/// Serial privacy boundary for all rebuildable journal projections.
/// Canonical journal storage remains the source of truth; this coordinator
/// owns only indexes, graph blobs, and invalidation signals.
public actor JournalDerivedPipelineCoordinator {
    public typealias SnapshotProvider = @Sendable () async throws -> [JournalEntrySnapshot]
    public typealias ReflectionInvalidator = @Sendable (Set<UUID>) async -> Void
    public typealias ProjectionInvalidator = @Sendable () async -> Void

    private let derivedIndex: any JournalDerivedIndexRepository
    private let graphStore: any KnowledgeGraphStore
    private let snapshotProvider: SnapshotProvider
    private let invalidateReflections: ReflectionInvalidator
    private let invalidateHomeAndEvidence: ProjectionInvalidator
    private var scheduledRebuild: Task<Void, Error>?
    // Deletion tombstones keep late-arriving copies of a removed entry
    // (for example a Watch envelope replayed after deletion) from silently
    // re-entering derived projections. Bounded, protected, local-only.
    private var tombstones: Set<UUID> = []
    private var tombstonesLoaded = false
    private static let tombstoneLimit = 512

    public init(
        derivedIndex: any JournalDerivedIndexRepository,
        graphStore: any KnowledgeGraphStore,
        snapshotProvider: @escaping SnapshotProvider,
        invalidateReflections: @escaping ReflectionInvalidator = { _ in },
        invalidateHomeAndEvidence: @escaping ProjectionInvalidator = {}
    ) {
        self.derivedIndex = derivedIndex
        self.graphStore = graphStore
        self.snapshotProvider = snapshotProvider
        self.invalidateReflections = invalidateReflections
        self.invalidateHomeAndEvidence = invalidateHomeAndEvidence
    }

    public func processCommitted(_ snapshot: JournalEntrySnapshot) async throws {
        let interval = LifeOSPerformanceOperation.journalDerivedRebuild.begin()
        defer { LifeOSPerformanceOperation.journalDerivedRebuild.end(interval) }
        try Task.checkCancellation()
        // An explicit commit is authoritative: if this ID was previously
        // tombstoned, the user is re-creating it, so clear the tombstone and
        // index normally. (Stale async replays are deduplicated by their
        // envelope identity at the Watch import boundary, not here.)
        clearTombstone(snapshot.id)
        try await derivedIndex.upsert(entry: snapshot)
        try await reconcileGraphAndProjections(changedIDs: [snapshot.id])
    }

    public func processDeletion(entryID: UUID) async throws {
        let interval = LifeOSPerformanceOperation.journalDerivedRebuild.begin()
        defer { LifeOSPerformanceOperation.journalDerivedRebuild.end(interval) }
        try Task.checkCancellation()
        recordTombstone(entryID)
        try await derivedIndex.remove(entryID: entryID)
        try await reconcileGraphAndProjections(changedIDs: [entryID])
    }

    public func isTombstoned(_ entryID: UUID) -> Bool {
        loadTombstonesIfNeeded()
        return tombstones.contains(entryID)
    }

    public func reconcileAll() async throws {
        let interval = LifeOSPerformanceOperation.journalDerivedRebuild.begin()
        defer { LifeOSPerformanceOperation.journalDerivedRebuild.end(interval) }
        let snapshots = try await snapshotProvider()
        try Task.checkCancellation()
        try await derivedIndex.rebuild(entries: snapshots)
        try Task.checkCancellation()
        try await graphStore.saveGraph(JournalKnowledgeGraphReconciler.makeGraph(from: snapshots))
        await invalidateReflections(Set(snapshots.map(\.id)))
        await invalidateHomeAndEvidence()
    }

    public func scheduleReconciliation() {
        scheduledRebuild?.cancel()
        scheduledRebuild = Task { try await self.reconcileAll() }
    }

    public func cancelScheduledReconciliation() {
        scheduledRebuild?.cancel()
        scheduledRebuild = nil
    }

    private func reconcileGraphAndProjections(changedIDs: Set<UUID>) async throws {
        let snapshots = try await snapshotProvider()
        try Task.checkCancellation()
        try await graphStore.saveGraph(JournalKnowledgeGraphReconciler.makeGraph(from: snapshots))
        await invalidateReflections(changedIDs)
        await invalidateHomeAndEvidence()
    }

    // MARK: Tombstones

    private static var tombstoneFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("LifeBoard", isDirectory: true)
            .appendingPathComponent("JournalDerivedIndex", isDirectory: true)
            .appendingPathComponent("tombstones.json", isDirectory: false)
    }

    private func loadTombstonesIfNeeded() {
        guard tombstonesLoaded == false else { return }
        tombstonesLoaded = true
        guard let url = Self.tombstoneFileURL,
              let data = try? Data(contentsOf: url),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return }
        tombstones = Set(ids)
    }

    private func clearTombstone(_ entryID: UUID) {
        loadTombstonesIfNeeded()
        guard tombstones.remove(entryID) != nil else { return }
        persistTombstones()
    }

    private func recordTombstone(_ entryID: UUID) {
        loadTombstonesIfNeeded()
        tombstones.insert(entryID)
        if tombstones.count > Self.tombstoneLimit {
            tombstones = Set(tombstones.shuffled().prefix(Self.tombstoneLimit))
        }
        persistTombstones()
    }

    private func persistTombstones() {
        guard let url = Self.tombstoneFileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(Array(tombstones))
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = url
            try mutableURL.setResourceValues(values)
        } catch {
            // Tombstones are a defense-in-depth dedup aid; canonical deletion
            // already succeeded, so persistence failure must not surface.
        }
    }
}
