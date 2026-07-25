@preconcurrency import CoreData
import Foundation

public struct HealthSyncCorrespondence: Codable, Hashable, Sendable, Identifiable {
    public enum Origin: String, Codable, Sendable {
        case healthKit
        case lifeBoard
    }

    public var id: UUID
    public var localID: UUID
    public var metric: HealthMetric
    public var role: String
    public var hkUUID: UUID
    public var origin: Origin
    public var syncIdentifier: String?
    public var syncVersion: Int64
    public var isRecreationSuppressed: Bool
    public var recordedAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        localID: UUID,
        metric: HealthMetric,
        role: String = "primary",
        hkUUID: UUID,
        origin: Origin,
        syncIdentifier: String? = nil,
        syncVersion: Int64 = 0,
        isRecreationSuppressed: Bool = false,
        recordedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.localID = localID
        self.metric = metric
        self.role = role
        self.hkUUID = hkUUID
        self.origin = origin
        self.syncIdentifier = syncIdentifier
        self.syncVersion = max(0, syncVersion)
        self.isRecreationSuppressed = isRecreationSuppressed
        self.recordedAt = recordedAt
        self.updatedAt = updatedAt
    }
}

public protocol HealthSyncLedgerStore: Sendable {
    func anchorData(for metric: HealthMetric) async throws -> Data?
    func setAnchorData(_ data: Data?, for metric: HealthMetric) async throws
    func correspondence(hkUUID: UUID) async throws -> HealthSyncCorrespondence?
    func correspondences(localID: UUID, metric: HealthMetric?) async throws -> [HealthSyncCorrespondence]
    func record(_ correspondence: HealthSyncCorrespondence) async throws
    func removeCorrespondence(hkUUID: UUID) async throws
    func removeCorrespondences(localID: UUID, metric: HealthMetric?) async throws
    func pendingOperations(now: Date, limit: Int) async throws -> [HealthSyncOperation]
    func save(_ operation: HealthSyncOperation) async throws
    func removeOperation(id: UUID) async throws
    func nextSyncVersion(localID: UUID, metric: HealthMetric, role: String) async throws -> Int64
    func writePreference(domain: HealthDomain, enabled: Bool, optedInAt: Date?) async throws
    func writePreference(for domain: HealthDomain) async throws -> Bool
    func cachedAggregate(metric: HealthMetric, start: Date) async throws -> HealthAggregateValue?
    func saveAggregate(_ value: HealthAggregateValue) async throws
}

/// Local-only Core Data ledger. Every fetch is restricted to the `LocalOnly`
/// store, and every write is committed in one context save. Repositories can use
/// `performLocalMutation` to place their model change and outbox rows in the same
/// SQLite transaction.
public actor CoreDataHealthSyncLedger: HealthSyncLedgerStore {
    public typealias LocalMutation = @Sendable (NSManagedObjectContext) throws -> Void

    private struct SendablePredicate: @unchecked Sendable {
        let value: NSPredicate
    }

    private let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    public func performLocalMutation(
        _ mutation: @escaping LocalMutation,
        operations: [HealthSyncOperation],
        transactionAuthor: String = "LifeBoardManualMutation"
    ) async throws {
        let context = container.newBackgroundContext()
        context.transactionAuthor = transactionAuthor
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        try await context.perform {
            try mutation(context)
            for operation in operations {
                try Self.upsert(operation, in: context)
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }

    public func anchorData(for metric: HealthMetric) async throws -> Data? {
        try await read(entity: "HealthSyncAnchor") { request in
            request.predicate = NSPredicate(format: "metricRaw == %@", metric.rawValue)
            request.fetchLimit = 1
        } transform: {
            $0.first?.value(forKey: "anchorData") as? Data
        }
    }

    public func setAnchorData(_ data: Data?, for metric: HealthMetric) async throws {
        try await write(author: "HealthKitImport") { context in
            let object = try Self.upsert(
                entity: "HealthSyncAnchor",
                predicate: NSPredicate(format: "metricRaw == %@", metric.rawValue),
                in: context
            )
            object.setValue(metric.rawValue, forKey: "metricRaw")
            object.setValue(data, forKey: "anchorData")
            object.setValue(Date(), forKey: "updatedAt")
        }
    }

    public func correspondence(hkUUID: UUID) async throws -> HealthSyncCorrespondence? {
        return try await read(entity: "HealthSyncCorrespondence") { request in
            request.predicate = NSPredicate(format: "hkUUID == %@", hkUUID as CVarArg)
            request.fetchLimit = 1
        } transform: {
            $0.first.flatMap(Self.correspondence)
        }
    }

    public func correspondences(
        localID: UUID,
        metric: HealthMetric? = nil
    ) async throws -> [HealthSyncCorrespondence] {
        return try await read(entity: "HealthSyncCorrespondence") { request in
            var predicates = [NSPredicate(format: "localID == %@", localID as CVarArg)]
            if let metric {
                predicates.append(NSPredicate(format: "metricRaw == %@", metric.rawValue))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        } transform: {
            $0.compactMap(Self.correspondence)
        }
    }

    public func record(_ correspondence: HealthSyncCorrespondence) async throws {
        try await write(author: "HealthKitSyncLedger") { context in
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "localID == %@", correspondence.localID as CVarArg),
                NSPredicate(format: "metricRaw == %@", correspondence.metric.rawValue),
                NSPredicate(format: "roleRaw == %@", correspondence.role)
            ])
            let object = try Self.upsert(entity: "HealthSyncCorrespondence", predicate: predicate, in: context)
            Self.apply(correspondence, to: object)
        }
    }

    public func removeCorrespondence(hkUUID: UUID) async throws {
        try await delete(entity: "HealthSyncCorrespondence", predicate: NSPredicate(format: "hkUUID == %@", hkUUID as CVarArg))
    }

    public func removeCorrespondences(localID: UUID, metric: HealthMetric? = nil) async throws {
        var predicates = [NSPredicate(format: "localID == %@", localID as CVarArg)]
        if let metric {
            predicates.append(NSPredicate(format: "metricRaw == %@", metric.rawValue))
        }
        try await delete(
            entity: "HealthSyncCorrespondence",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        )
    }

    public func pendingOperations(now: Date = Date(), limit: Int = 64) async throws -> [HealthSyncOperation] {
        return try await read(entity: "HealthSyncOperation") { request in
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "stateRaw IN %@", [
                    HealthSyncOperationState.pending.rawValue,
                    HealthSyncOperationState.retryScheduled.rawValue,
                    HealthSyncOperationState.pausedPermission.rawValue
                ]),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "nextAttemptAt == nil"),
                    NSPredicate(format: "nextAttemptAt <= %@", now as NSDate)
                ])
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            request.fetchLimit = max(1, limit)
        } transform: {
            $0.compactMap(Self.operation)
        }
    }

    public func save(_ operation: HealthSyncOperation) async throws {
        try await write(author: "HealthKitSyncLedger") { context in
            try Self.upsert(operation, in: context)
        }
    }

    public func removeOperation(id: UUID) async throws {
        try await delete(entity: "HealthSyncOperation", predicate: NSPredicate(format: "id == %@", id as CVarArg))
    }

    public func nextSyncVersion(localID: UUID, metric: HealthMetric, role: String) async throws -> Int64 {
        let context = container.newBackgroundContext()
        context.transactionAuthor = "HealthKitSyncLedger"
        return try await context.perform {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "localID == %@", localID as CVarArg),
                NSPredicate(format: "metricRaw == %@", metric.rawValue),
                NSPredicate(format: "roleRaw == %@", role)
            ])
            let object = try Self.upsert(entity: "HealthSyncVersion", predicate: predicate, in: context)
            let current = (object.value(forKey: "version") as? NSNumber)?.int64Value ?? 0
            let next = current == Int64.max ? Int64.max : current + 1
            object.setValue(localID, forKey: "localID")
            object.setValue(metric.rawValue, forKey: "metricRaw")
            object.setValue(role, forKey: "roleRaw")
            object.setValue(next, forKey: "version")
            object.setValue(Date(), forKey: "updatedAt")
            try context.save()
            return next
        }
    }

    public func writePreference(domain: HealthDomain, enabled: Bool, optedInAt: Date?) async throws {
        try await write(author: "HealthSettings") { context in
            let object = try Self.upsert(
                entity: "HealthSyncPreference",
                predicate: NSPredicate(format: "domainRaw == %@", domain.rawValue),
                in: context
            )
            object.setValue(domain.rawValue, forKey: "domainRaw")
            object.setValue(enabled, forKey: "writeEnabled")
            if object.value(forKey: "optedInAt") == nil {
                object.setValue(optedInAt, forKey: "optedInAt")
            }
            object.setValue(Date(), forKey: "updatedAt")
        }
    }

    public func writePreference(for domain: HealthDomain) async throws -> Bool {
        return try await read(entity: "HealthSyncPreference") { request in
            request.predicate = NSPredicate(format: "domainRaw == %@", domain.rawValue)
            request.fetchLimit = 1
        } transform: {
            $0.first?.value(forKey: "writeEnabled") as? Bool ?? false
        }
    }

    public func cachedAggregate(metric: HealthMetric, start: Date) async throws -> HealthAggregateValue? {
        let id = Self.aggregateID(metric: metric, start: start)
        return try await read(entity: "HealthAggregateCache") { request in
            request.predicate = NSPredicate(format: "id == %@", id)
            request.fetchLimit = 1
        } transform: { objects in
            guard let object = objects.first,
                  let value = (object.value(forKey: "value") as? NSNumber)?.doubleValue,
                  let cachedStart = object.value(forKey: "startAt") as? Date,
                  let end = object.value(forKey: "endAt") as? Date else {
                return nil
            }
            return .init(
                metric: metric,
                value: value,
                start: cachedStart,
                end: end,
                lastSampleAt: object.value(forKey: "lastSampleAt") as? Date,
                sourceLabel: object.value(forKey: "sourceLabel") as? String ?? "Apple Health"
            )
        }
    }

    public func saveAggregate(_ value: HealthAggregateValue) async throws {
        try await write(author: "HealthKitImport") { context in
            let id = Self.aggregateID(metric: value.metric, start: value.start)
            let object = try Self.upsert(
                entity: "HealthAggregateCache",
                predicate: NSPredicate(format: "id == %@", id),
                in: context
            )
            object.setValue(id, forKey: "id")
            object.setValue(value.metric.rawValue, forKey: "metricRaw")
            object.setValue(value.start, forKey: "startAt")
            object.setValue(value.end, forKey: "endAt")
            object.setValue(value.value, forKey: "value")
            object.setValue(value.sourceLabel, forKey: "sourceLabel")
            object.setValue(value.lastSampleAt, forKey: "lastSampleAt")
            object.setValue(Date(), forKey: "updatedAt")
        }
    }

    private func read<T: Sendable>(
        entity: String,
        configure: @escaping @Sendable (NSFetchRequest<NSManagedObject>) -> Void,
        transform: @escaping @Sendable ([NSManagedObject]) -> T
    ) async throws -> T {
        let context = container.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.affectedStores = Self.localStores(in: self.container)
            configure(request)
            return transform(try context.fetch(request))
        }
    }

    private func write(
        author: String,
        mutation: @escaping @Sendable (NSManagedObjectContext) throws -> Void
    ) async throws {
        let context = container.newBackgroundContext()
        context.transactionAuthor = author
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        try await context.perform {
            try mutation(context)
            if context.hasChanges {
                try context.save()
            }
        }
    }

    private func delete(entity: String, predicate: NSPredicate) async throws {
        let predicateBox = SendablePredicate(value: predicate)
        try await write(author: "HealthKitSyncLedger") { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.affectedStores = Self.localStores(in: self.container)
            request.predicate = predicateBox.value
            try context.fetch(request).forEach(context.delete)
        }
    }

    private static func localStores(in container: NSPersistentContainer) -> [NSPersistentStore] {
        container.persistentStoreCoordinator.persistentStores.filter { $0.configurationName == "LocalOnly" }
    }

    private static func aggregateID(metric: HealthMetric, start: Date) -> String {
        "\(metric.rawValue):\(Int(start.timeIntervalSinceReferenceDate))"
    }

    private static func upsert(
        entity: String,
        predicate: NSPredicate,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first {
            return existing
        }
        return NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    private static func upsert(_ operation: HealthSyncOperation, in context: NSManagedObjectContext) throws {
        let object = try upsert(
            entity: "HealthSyncOperation",
            predicate: NSPredicate(format: "id == %@", operation.id as CVarArg),
            in: context
        )
        object.setValue(operation.id, forKey: "id")
        object.setValue(operation.localID, forKey: "localID")
        object.setValue(operation.metric.rawValue, forKey: "metricRaw")
        object.setValue(operation.role, forKey: "roleRaw")
        object.setValue(operation.kind.rawValue, forKey: "kindRaw")
        object.setValue(operation.state.rawValue, forKey: "stateRaw")
        object.setValue(try operation.payload.map { try JSONEncoder().encode($0) }, forKey: "payloadData")
        object.setValue(operation.syncVersion, forKey: "syncVersion")
        object.setValue(operation.attemptCount, forKey: "attemptCount")
        object.setValue(operation.nextAttemptAt, forKey: "nextAttemptAt")
        object.setValue(operation.lastErrorCode, forKey: "lastErrorCode")
        object.setValue(operation.createdAt, forKey: "createdAt")
        object.setValue(operation.updatedAt, forKey: "updatedAt")
    }

    private static func apply(_ value: HealthSyncCorrespondence, to object: NSManagedObject) {
        object.setValue(value.id, forKey: "id")
        object.setValue(value.localID, forKey: "localID")
        object.setValue(value.metric.rawValue, forKey: "metricRaw")
        object.setValue(value.role, forKey: "roleRaw")
        object.setValue(value.hkUUID, forKey: "hkUUID")
        object.setValue(value.origin.rawValue, forKey: "originRaw")
        object.setValue(value.syncIdentifier, forKey: "syncIdentifier")
        object.setValue(value.syncVersion, forKey: "syncVersion")
        object.setValue(value.isRecreationSuppressed, forKey: "isRecreationSuppressed")
        object.setValue(value.recordedAt, forKey: "recordedAt")
        object.setValue(value.updatedAt, forKey: "updatedAt")
    }

    private static func correspondence(_ object: NSManagedObject) -> HealthSyncCorrespondence? {
        guard let id = object.value(forKey: "id") as? UUID,
              let localID = object.value(forKey: "localID") as? UUID,
              let metricRaw = object.value(forKey: "metricRaw") as? String,
              let metric = HealthMetric(rawValue: metricRaw),
              let role = object.value(forKey: "roleRaw") as? String,
              let hkUUID = object.value(forKey: "hkUUID") as? UUID,
              let originRaw = object.value(forKey: "originRaw") as? String,
              let origin = HealthSyncCorrespondence.Origin(rawValue: originRaw) else {
            return nil
        }
        return .init(
            id: id,
            localID: localID,
            metric: metric,
            role: role,
            hkUUID: hkUUID,
            origin: origin,
            syncIdentifier: object.value(forKey: "syncIdentifier") as? String,
            syncVersion: (object.value(forKey: "syncVersion") as? NSNumber)?.int64Value ?? 0,
            isRecreationSuppressed: object.value(forKey: "isRecreationSuppressed") as? Bool ?? false,
            recordedAt: object.value(forKey: "recordedAt") as? Date ?? .distantPast,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? .distantPast
        )
    }

    private static func operation(_ object: NSManagedObject) -> HealthSyncOperation? {
        guard let id = object.value(forKey: "id") as? UUID,
              let localID = object.value(forKey: "localID") as? UUID,
              let metricRaw = object.value(forKey: "metricRaw") as? String,
              let metric = HealthMetric(rawValue: metricRaw),
              let role = object.value(forKey: "roleRaw") as? String,
              let kindRaw = object.value(forKey: "kindRaw") as? String,
              let kind = HealthSyncOperationKind(rawValue: kindRaw),
              let stateRaw = object.value(forKey: "stateRaw") as? String,
              let state = HealthSyncOperationState(rawValue: stateRaw) else {
            return nil
        }
        let payload = (object.value(forKey: "payloadData") as? Data)
            .flatMap { try? JSONDecoder().decode(HealthWritePayload.self, from: $0) }
        return .init(
            id: id,
            localID: localID,
            metric: metric,
            role: role,
            kind: kind,
            state: state,
            payload: payload,
            syncVersion: (object.value(forKey: "syncVersion") as? NSNumber)?.int64Value ?? 1,
            attemptCount: (object.value(forKey: "attemptCount") as? NSNumber)?.intValue ?? 0,
            nextAttemptAt: object.value(forKey: "nextAttemptAt") as? Date,
            lastErrorCode: object.value(forKey: "lastErrorCode") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }
}

/// Fast deterministic ledger for unit tests and previews.
public actor InMemoryHealthSyncLedger: HealthSyncLedgerStore {
    private var anchors: [HealthMetric: Data] = [:]
    private var correspondenceValues: [HealthSyncCorrespondence] = []
    private var operationValues: [HealthSyncOperation] = []
    private var versions: [String: Int64] = [:]
    private var preferences: [HealthDomain: Bool] = [:]
    private var aggregateValues: [String: HealthAggregateValue] = [:]

    public init() {}

    public func anchorData(for metric: HealthMetric) -> Data? { anchors[metric] }
    public func setAnchorData(_ data: Data?, for metric: HealthMetric) {
        anchors[metric] = data
    }
    public func correspondence(hkUUID: UUID) -> HealthSyncCorrespondence? {
        correspondenceValues.first { $0.hkUUID == hkUUID }
    }
    public func correspondences(localID: UUID, metric: HealthMetric?) -> [HealthSyncCorrespondence] {
        correspondenceValues.filter { $0.localID == localID && (metric == nil || $0.metric == metric) }
    }
    public func record(_ value: HealthSyncCorrespondence) {
        correspondenceValues.removeAll {
            $0.localID == value.localID && $0.metric == value.metric && $0.role == value.role
        }
        correspondenceValues.append(value)
    }
    public func removeCorrespondence(hkUUID: UUID) {
        correspondenceValues.removeAll { $0.hkUUID == hkUUID }
    }
    public func removeCorrespondences(localID: UUID, metric: HealthMetric?) {
        correspondenceValues.removeAll { $0.localID == localID && (metric == nil || $0.metric == metric) }
    }
    public func pendingOperations(now: Date, limit: Int) -> [HealthSyncOperation] {
        Array(operationValues.filter {
            [.pending, .retryScheduled, .pausedPermission].contains($0.state)
                && ($0.nextAttemptAt == nil || $0.nextAttemptAt! <= now)
        }.prefix(limit))
    }
    public func save(_ operation: HealthSyncOperation) {
        operationValues.removeAll { $0.id == operation.id }
        operationValues.append(operation)
    }
    public func removeOperation(id: UUID) {
        operationValues.removeAll { $0.id == id }
    }
    public func nextSyncVersion(localID: UUID, metric: HealthMetric, role: String) -> Int64 {
        let key = "\(localID):\(metric.rawValue):\(role)"
        let next = (versions[key] ?? 0) + 1
        versions[key] = next
        return next
    }
    public func writePreference(domain: HealthDomain, enabled: Bool, optedInAt: Date?) {
        preferences[domain] = enabled
    }
    public func writePreference(for domain: HealthDomain) -> Bool {
        preferences[domain] ?? false
    }
    public func cachedAggregate(metric: HealthMetric, start: Date) -> HealthAggregateValue? {
        aggregateValues["\(metric.rawValue):\(Int(start.timeIntervalSinceReferenceDate))"]
    }
    public func saveAggregate(_ value: HealthAggregateValue) {
        aggregateValues["\(value.metric.rawValue):\(Int(value.start.timeIntervalSinceReferenceDate))"] = value
    }
}
