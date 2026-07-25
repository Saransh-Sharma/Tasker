import Foundation

public actor HealthSyncEngine {
    public struct RefreshResult: Sendable {
        public let refreshedMetrics: Set<HealthMetric>
        public let successfulAt: Date
    }

    private let gateway: any HealthKitGatewayProtocol
    private let ledger: any HealthSyncLedgerStore
    private let projections: any HealthProjectionRepository
    private let featureFlags: @Sendable () -> (read: Bool, write: Bool)
    private let surfaceRefresh: @Sendable () async -> Void

    public init(
        gateway: any HealthKitGatewayProtocol,
        ledger: any HealthSyncLedgerStore,
        projections: any HealthProjectionRepository,
        featureFlags: @escaping @Sendable () -> (read: Bool, write: Bool) = {
            (
                V2FeatureFlags.healthIntegrationsV1Enabled,
                V2FeatureFlags.healthIntegrationsV1Enabled && V2FeatureFlags.healthWriteBackV1Enabled
            )
        },
        surfaceRefresh: @escaping @Sendable () async -> Void = {}
    ) {
        self.gateway = gateway
        self.ledger = ledger
        self.projections = projections
        self.featureFlags = featureFlags
        self.surfaceRefresh = surfaceRefresh
    }

    @discardableResult
    public func refresh(metrics: Set<HealthMetric> = Set(HealthKitTypeCatalog.readableMetrics)) async throws -> RefreshResult {
        guard featureFlags().read, gateway.isHealthDataAvailable else {
            throw HealthKitGatewayError.unavailable
        }
        var committed = Set<HealthMetric>()
        for metric in metrics {
            try await ingest(metric)
            committed.insert(metric)
        }
        try await processOutbox()
        if committed.isEmpty == false {
            await surfaceRefresh()
        }
        return .init(refreshedMetrics: committed, successfulAt: Date())
    }

    public func processOutbox(now: Date = Date()) async throws {
        guard featureFlags().write else { return }
        let operations = try await ledger.pendingOperations(now: now, limit: 64)
        for var operation in operations {
            guard operation.metric.domain.supportsWriteBack,
                  try await ledger.writePreference(for: operation.metric.domain) else {
                continue
            }
            let requiredMetrics: [HealthMetric]
            if operation.metric == .workout {
                var metrics: [HealthMetric] = [.workout]
                if operation.payload?.workout?.energyKilocalories != nil { metrics.append(.activeEnergy) }
                if operation.payload?.workout?.distanceMeters != nil { metrics.append(.walkingRunningDistance) }
                requiredMetrics = metrics
            } else {
                requiredMetrics = [operation.metric]
            }
            var authorizations: [HealthWriteAuthorization] = []
            for metric in requiredMetrics {
                authorizations.append(await gateway.writeAuthorization(for: metric))
            }
            guard authorizations.allSatisfy({ $0 == .authorized }) else {
                operation.state = .pausedPermission
                operation.updatedAt = now
                operation.nextAttemptAt = nil
                operation.lastErrorCode = authorizations.contains(.denied) ? "write_denied" : "write_not_determined"
                try await ledger.save(operation)
                continue
            }

            operation.state = .processing
            operation.updatedAt = now
            try await ledger.save(operation)
            do {
                switch operation.kind {
                case .write, .update:
                    guard let payload = operation.payload else {
                        throw HealthKitGatewayError.invalidPayload
                    }
                    let existing = try await ledger.correspondences(
                        localID: operation.localID,
                        metric: operation.metric
                    ).first { $0.role == operation.role }
                    if existing?.isRecreationSuppressed == true, operation.kind == .write {
                        try await ledger.removeOperation(id: operation.id)
                        continue
                    }
                    let savedObjects = try await gateway.save(payload, syncVersion: operation.syncVersion)
                    for saved in savedObjects {
                        try await ledger.record(.init(
                            localID: operation.localID,
                            metric: operation.metric,
                            role: saved.role,
                            hkUUID: saved.uuid,
                            origin: .lifeBoard,
                            syncIdentifier: syncIdentifier(for: payload, role: saved.role),
                            syncVersion: operation.syncVersion
                        ))
                    }

                case .delete:
                    let correspondences = try await ledger.correspondences(
                        localID: operation.localID,
                        metric: operation.metric
                    ).filter { $0.origin == .lifeBoard }
                    for correspondence in correspondences {
                        do {
                            try await gateway.deleteObject(
                                uuid: correspondence.hkUUID,
                                metric: correspondence.metric
                            )
                        } catch HealthKitGatewayError.objectNotFound {
                            // Already absent is a successful idempotent delete.
                        }
                        try await ledger.removeCorrespondence(hkUUID: correspondence.hkUUID)
                    }
                }
                try await ledger.removeOperation(id: operation.id)
            } catch {
                operation.state = .retryScheduled
                operation.attemptCount += 1
                operation.updatedAt = Date()
                operation.nextAttemptAt = Date().addingTimeInterval(Self.retryDelay(attempt: operation.attemptCount))
                operation.lastErrorCode = Self.safeErrorCode(error)
                try await ledger.save(operation)
            }
        }
    }

    public func localRecordWasEdited(localID: UUID, metric: HealthMetric) async throws {
        let values = try await ledger.correspondences(localID: localID, metric: metric)
        for var value in values where value.isRecreationSuppressed {
            value.isRecreationSuppressed = false
            value.updatedAt = Date()
            try await ledger.record(value)
        }
    }

    private func ingest(_ metric: HealthMetric) async throws {
        let anchor = try await ledger.anchorData(for: metric)
        let changes = try await gateway.anchoredChanges(metric: metric, anchorData: anchor)

        for deletedID in changes.deletedObjectIDs {
            guard var correspondence = try await ledger.correspondence(hkUUID: deletedID) else { continue }
            if correspondence.origin == .healthKit {
                try await projections.deleteImportedProjection(
                    localID: correspondence.localID,
                    metric: correspondence.metric
                )
                try await ledger.removeCorrespondence(hkUUID: deletedID)
            } else {
                correspondence.isRecreationSuppressed = true
                correspondence.updatedAt = Date()
                try await ledger.record(correspondence)
            }
        }

        for sample in changes.samples {
            if let correspondence = try await ledger.correspondence(hkUUID: sample.id),
               correspondence.origin == .lifeBoard {
                continue
            }
            if sample.syncIdentifier?.hasPrefix("com.lifeboard.") == true {
                continue
            }
            let existing = try await ledger.correspondence(hkUUID: sample.id)
            guard let localID = try await projections.reconcileImportedSample(sample, existing: existing) else {
                continue
            }
            try await ledger.record(.init(
                id: existing?.id ?? UUID(),
                localID: localID,
                metric: metric,
                role: "primary",
                hkUUID: sample.id,
                origin: .healthKit,
                syncIdentifier: sample.syncIdentifier,
                syncVersion: sample.syncVersion ?? 0,
                recordedAt: existing?.recordedAt ?? Date(),
                updatedAt: Date()
            ))
        }

        // The anchor is deliberately the final write. Any failed projection or
        // correspondence reconciliation leaves the previous anchor intact.
        try await ledger.setAnchorData(changes.newAnchorData, for: metric)
    }

    private func syncIdentifier(for payload: HealthWritePayload, role: String) -> String {
        "com.lifeboard.\(payload.metric.rawValue).\(payload.localID.uuidString.lowercased()).\(role)"
    }

    private static func retryDelay(attempt: Int) -> TimeInterval {
        min(6 * 60 * 60, pow(2, Double(min(attempt, 10))) * 30)
    }

    private static func safeErrorCode(_ error: any Error) -> String {
        switch error {
        case HealthKitGatewayError.authorizationNotGranted: "authorization"
        case HealthKitGatewayError.unavailable: "unavailable"
        case HealthKitGatewayError.invalidPayload: "invalid_payload"
        case HealthKitGatewayError.objectNotFound: "object_missing"
        default: "healthkit_error"
        }
    }
}
