import HealthKit
import CoreData
import XCTest
@testable import LifeBoard

final class HealthSyncTests: XCTestCase {
    func testCatalogUnitsPercentConversionAndWorkoutFallback() {
        XCTAssertEqual(
            HealthKitTypeCatalog.healthKitValue(18.5, for: .bodyFatPercentage),
            0.185,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            HealthKitTypeCatalog.lifeBoardValue(0.185, for: .bodyFatPercentage),
            18.5,
            accuracy: 0.000_001
        )
        XCTAssertNotNil(HealthKitTypeCatalog.unit(for: .water))
        XCTAssertTrue(HealthKitTypeCatalog.writableMetrics.contains(.workout))
        XCTAssertFalse(HealthKitTypeCatalog.writableMetrics.contains(.sleep))
        XCTAssertEqual(HealthWorkoutActivityMapper.activityType(for: "Unlisted movement"), .other)
    }

    func testOneLocalRecordKeepsSeveralCorrespondenceRoles() async throws {
        let ledger = InMemoryHealthSyncLedger()
        let localID = UUID()
        try await ledger.record(.init(
            localID: localID,
            metric: .workout,
            role: "primary",
            hkUUID: UUID(),
            origin: .lifeBoard
        ))
        try await ledger.record(.init(
            localID: localID,
            metric: .workout,
            role: "energy",
            hkUUID: UUID(),
            origin: .lifeBoard
        ))
        try await ledger.record(.init(
            localID: localID,
            metric: .workout,
            role: "distance",
            hkUUID: UUID(),
            origin: .lifeBoard
        ))

        let values = try await ledger.correspondences(localID: localID, metric: .workout)
        XCTAssertEqual(Set(values.map(\.role)), ["primary", "energy", "distance"])
    }

    func testSyncVersionsAreMonotonicPerMetricRole() async throws {
        let ledger = InMemoryHealthSyncLedger()
        let id = UUID()
        let first = try await ledger.nextSyncVersion(localID: id, metric: .water, role: "primary")
        let second = try await ledger.nextSyncVersion(localID: id, metric: .water, role: "primary")
        let otherRole = try await ledger.nextSyncVersion(localID: id, metric: .water, role: "secondary")
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)
        XCTAssertEqual(otherRole, 1)
    }

    func testNutritionProjectionExcludesLifeBoardEchoAndKeepsExactTimestamp() {
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = first.addingTimeInterval(900)
        let samples = [
            HealthSampleEnvelope(
                id: UUID(),
                metric: .dietaryEnergy,
                value: .quantity(420),
                startDate: first,
                endDate: first
            ),
            HealthSampleEnvelope(
                id: UUID(),
                metric: .dietaryEnergy,
                value: .quantity(180),
                startDate: second,
                endDate: second,
                syncIdentifier: "com.lifeboard.dietaryEnergy.local.primary"
            )
        ]

        let aggregate = HealthNutritionProjection.aggregate(samples: samples, metric: .dietaryEnergy)
        XCTAssertEqual(aggregate?.value, 420)
        XCTAssertEqual(aggregate?.lastSampleAt, first)
    }

    func testFastingSuggestionUsesLatestTimestampWithoutCreatingMeal() {
        let local = Date(timeIntervalSince1970: 100)
        let external = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(
            HealthFastingSuggestion.latestStart(localMealAt: local, externalDietaryEnergyAt: external),
            external
        )
    }

    func testSleepPresentationDoesNotDoubleCountOverlaps() {
        let start = Date(timeIntervalSince1970: 0)
        let samples = [
            HealthSampleEnvelope(
                id: UUID(),
                metric: .sleep,
                value: .category(1),
                startDate: start,
                endDate: start.addingTimeInterval(3_600)
            ),
            HealthSampleEnvelope(
                id: UUID(),
                metric: .sleep,
                value: .category(3),
                startDate: start.addingTimeInterval(1_800),
                endDate: start.addingTimeInterval(5_400)
            )
        ]
        XCTAssertEqual(
            HealthSleepPresentation.overlapSafeTotal(
                samples: samples,
                from: start,
                to: start.addingTimeInterval(7_200)
            ),
            5_400
        )
    }

    func testAnchorAdvancesOnlyAfterProjectionReconciliation() async throws {
        let gateway = HealthGatewayFake()
        let ledger = InMemoryHealthSyncLedger()
        let projections = HealthProjectionFake()
        gateway.changes[.water] = .init(
            samples: [.init(
                id: UUID(),
                metric: .water,
                value: .quantity(250),
                startDate: Date(),
                endDate: Date()
            )],
            deletedObjectIDs: [],
            newAnchorData: Data([7])
        )
        await projections.setFailureEnabled(true)
        let engine = HealthSyncEngine(
            gateway: gateway,
            ledger: ledger,
            projections: projections,
            featureFlags: { (true, false) }
        )

        do {
            _ = try await engine.refresh(metrics: [.water])
            XCTFail("Expected projection failure")
        } catch {}
        let failedAnchor = try await ledger.anchorData(for: .water)
        XCTAssertNil(failedAnchor)

        await projections.setFailureEnabled(false)
        _ = try await engine.refresh(metrics: [.water])
        let committedAnchor = try await ledger.anchorData(for: .water)
        XCTAssertEqual(committedAnchor, Data([7]))
    }

    func testLifeBoardEchoIsNotImported() async throws {
        let gateway = HealthGatewayFake()
        let ledger = InMemoryHealthSyncLedger()
        let projections = HealthProjectionFake()
        gateway.changes[.water] = .init(
            samples: [.init(
                id: UUID(),
                metric: .water,
                value: .quantity(250),
                startDate: Date(),
                endDate: Date(),
                syncIdentifier: "com.lifeboard.water.local.primary"
            )],
            deletedObjectIDs: [],
            newAnchorData: Data([1])
        )
        let engine = HealthSyncEngine(
            gateway: gateway,
            ledger: ledger,
            projections: projections,
            featureFlags: { (true, false) }
        )
        _ = try await engine.refresh(metrics: [.water])
        let reconciledCount = await projections.reconciledCount
        XCTAssertEqual(reconciledCount, 0)
    }

    func testHealthSideDeletionSuppressesRecreationUntilEdit() async throws {
        let gateway = HealthGatewayFake()
        let ledger = InMemoryHealthSyncLedger()
        let projections = HealthProjectionFake()
        let healthID = UUID()
        let localID = UUID()
        try await ledger.record(.init(
            localID: localID,
            metric: .water,
            hkUUID: healthID,
            origin: .lifeBoard
        ))
        gateway.changes[.water] = .init(
            samples: [],
            deletedObjectIDs: [healthID],
            newAnchorData: Data([2])
        )
        let engine = HealthSyncEngine(
            gateway: gateway,
            ledger: ledger,
            projections: projections,
            featureFlags: { (true, false) }
        )
        _ = try await engine.refresh(metrics: [.water])
        let suppressed = try await ledger.correspondence(hkUUID: healthID)?.isRecreationSuppressed
        XCTAssertEqual(suppressed, true)

        try await engine.localRecordWasEdited(localID: localID, metric: .water)
        let recreatedAfterEdit = try await ledger.correspondence(hkUUID: healthID)?.isRecreationSuppressed
        XCTAssertEqual(recreatedAfterEdit, false)
    }

    func testDeniedWritePausesOutboxWithoutRemovingManualRecordIntent() async throws {
        let gateway = HealthGatewayFake()
        gateway.authorization = .denied
        let ledger = InMemoryHealthSyncLedger()
        try await ledger.writePreference(domain: .hydration, enabled: true, optedInAt: Date())
        let operation = makeWaterOperation()
        try await ledger.save(operation)
        let engine = HealthSyncEngine(
            gateway: gateway,
            ledger: ledger,
            projections: HealthProjectionFake(),
            featureFlags: { (true, true) }
        )

        try await engine.processOutbox()

        let queued = try await ledger.pendingOperations(now: .distantFuture, limit: 10)
        XCTAssertEqual(queued.first?.id, operation.id)
        XCTAssertEqual(queued.first?.state, .pausedPermission)
        XCTAssertEqual(queued.first?.lastErrorCode, "write_denied")
    }

    func testTransientWriteFailureSchedulesNonSensitiveRetry() async throws {
        let gateway = HealthGatewayFake()
        gateway.saveError = HealthKitGatewayError.unavailable
        let ledger = InMemoryHealthSyncLedger()
        try await ledger.writePreference(domain: .hydration, enabled: true, optedInAt: Date())
        let operation = makeWaterOperation()
        try await ledger.save(operation)
        let engine = HealthSyncEngine(
            gateway: gateway,
            ledger: ledger,
            projections: HealthProjectionFake(),
            featureFlags: { (true, true) }
        )

        try await engine.processOutbox()

        let queued = try await ledger.pendingOperations(now: .distantFuture, limit: 10)
        XCTAssertEqual(queued.first?.id, operation.id)
        XCTAssertEqual(queued.first?.state, .retryScheduled)
        XCTAssertEqual(queued.first?.attemptCount, 1)
        XCTAssertNotNil(queued.first?.nextAttemptAt)
        XCTAssertEqual(queued.first?.lastErrorCode, "unavailable")
    }

    @MainActor
    func testConnectionStoreNeverInventsReadDeniedState() async {
        let gateway = HealthGatewayFake()
        gateway.authorization = .denied
        gateway.authorizationRequestError = HealthKitGatewayError.authorizationNotGranted
        let ledger = InMemoryHealthSyncLedger()
        let store = HealthConnectionStore(
            gateway: gateway,
            engineProvider: { nil },
            ledgerProvider: { ledger }
        )

        await store.connect(domains: [.hydration])
        XCTAssertEqual(store.statuses[.hydration]?.readRequestState, .requestCompleted)
        XCTAssertEqual(store.statuses[.hydration]?.writeAuthorizations[.water], .denied)
    }

    @MainActor
    func testConnectionReturnsWhileInitialHealthImportContinues() async {
        let previousReadFlag = V2FeatureFlags.healthIntegrationsV1Enabled
        V2FeatureFlags.healthIntegrationsV1Enabled = true
        HealthAuthorizationPromptState.reset()
        defer {
            V2FeatureFlags.healthIntegrationsV1Enabled = previousReadFlag
            HealthAuthorizationPromptState.reset()
        }

        let gateway = HealthGatewayFake()
        let importGate = HealthImportGate()
        gateway.anchoredChangesGate = importGate
        let ledger = InMemoryHealthSyncLedger()
        let engine = HealthSyncEngine(
            gateway: gateway,
            ledger: ledger,
            projections: HealthProjectionFake(),
            featureFlags: { (true, false) }
        )
        let store = HealthConnectionStore(
            gateway: gateway,
            engineProvider: { engine },
            ledgerProvider: { ledger }
        )
        let connectionReturned = expectation(description: "Connection returns before initial import")

        let connectionTask = _Concurrency.Task { @MainActor in
            await store.connect(domains: [.hydration])
            connectionReturned.fulfill()
        }

        await importGate.waitUntilEntered()
        await fulfillment(of: [connectionReturned], timeout: 1)
        XCTAssertTrue(store.isRefreshing)
        XCTAssertNil(store.lastSuccessfulSync)
        XCTAssertEqual(store.statuses[.hydration]?.readRequestState, .requestCompleted)

        await importGate.open()
        await connectionTask.value
        for _ in 0..<100 where store.isRefreshing {
            try? await _Concurrency.Task.sleep(for: .milliseconds(10))
        }

        XCTAssertFalse(store.isRefreshing)
        XCTAssertNotNil(store.lastSuccessfulSync)
    }

    func testHydrationBackwardDecodeDefaultsToManual() throws {
        let id = UUID()
        let timestamp = Date(timeIntervalSinceReferenceDate: 100)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacy: [String: Any] = [
            "id": id.uuidString,
            "amount": 250.0,
            "unit": "milliliters",
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HydrationLog.self, from: data)
        XCTAssertEqual(decoded.source, .manual)
        XCTAssertEqual(decoded.createdAt, decoded.timestamp)
    }

    func testCloudToLocalMigrationIsIdempotentAndManualSaveQueuesAtomically() async throws {
        let previousReadFlag = V2FeatureFlags.healthIntegrationsV1Enabled
        let previousWriteFlag = V2FeatureFlags.healthWriteBackV1Enabled
        V2FeatureFlags.healthIntegrationsV1Enabled = true
        V2FeatureFlags.healthWriteBackV1Enabled = true
        defer {
            V2FeatureFlags.healthIntegrationsV1Enabled = previousReadFlag
            V2FeatureFlags.healthWriteBackV1Enabled = previousWriteFlag
        }

        let container = try await makeInMemoryHealthContainer()
        let context = container.newBackgroundContext()
        let sourceID = UUID()
        try await context.perform {
            let cloud = try XCTUnwrap(container.persistentStoreCoordinator.persistentStores.first {
                $0.configurationName == "CloudSync"
            })
            let object = NSEntityDescription.insertNewObject(forEntityName: "HydrationLog", into: context)
            context.assign(object, to: cloud)
            object.setValue(sourceID, forKey: "id")
            object.setValue(300.0, forKey: "amount")
            object.setValue(HydrationUnit.milliliters.rawValue, forKey: "unitRaw")
            object.setValue(Date(), forKey: "timestamp")
            try context.save()
        }

        let migration = HealthPrivacyMigrationCoordinator(container: container)
        let firstMigration = try await migration.migrate()
        let resumedMigration = try await migration.migrate()
        XCTAssertEqual(firstMigration, .validated)
        XCTAssertEqual(resumedMigration, .validated)

        let ledger = CoreDataHealthSyncLedger(container: container)
        try await ledger.writePreference(domain: .hydration, enabled: true, optedInAt: Date())
        let repository = CoreDataTrackFoundationRepository(container: container)
        let manual = HydrationLog(amount: 425, unit: .milliliters, source: .manual)
        try await repository.saveHydrationLog(manual)

        let verification = container.newBackgroundContext()
        let result: (Int, Int) = try await verification.perform {
            let local = try XCTUnwrap(container.persistentStoreCoordinator.persistentStores.first {
                $0.configurationName == "LocalOnly"
            })
            let hydration = NSFetchRequest<NSManagedObject>(entityName: "HydrationLog")
            hydration.affectedStores = [local]
            let operations = NSFetchRequest<NSManagedObject>(entityName: "HealthSyncOperation")
            operations.affectedStores = [local]
            return (try verification.count(for: hydration), try verification.count(for: operations))
        }
        XCTAssertEqual(result.0, 2)
        XCTAssertEqual(result.1, 1)
    }

    func testJustInTimeGateOffersUntilAskedThenRespectsDeclineAndSnooze() {
        HealthAuthorizationPromptState.reset()
        defer { HealthAuthorizationPromptState.reset() }
        let now = Date()

        // Never asked, never declined → offer.
        XCTAssertTrue(HealthAuthorizationPromptState.shouldOffer(now: now))

        // First "Not now" snoozes: no offer inside the window, offer again after it.
        HealthAuthorizationPromptState.recordDecline(now: now)
        XCTAssertFalse(HealthAuthorizationPromptState.shouldOffer(now: now.addingTimeInterval(60)))
        XCTAssertTrue(HealthAuthorizationPromptState.shouldOffer(
            now: now.addingTimeInterval(HealthAuthorizationPromptState.snoozeInterval + 1)
        ))

        // Second decline caps auto-offers permanently.
        HealthAuthorizationPromptState.recordDecline(now: now)
        XCTAssertFalse(HealthAuthorizationPromptState.shouldOffer(
            now: now.addingTimeInterval(HealthAuthorizationPromptState.snoozeInterval * 5)
        ))
    }

    func testJustInTimeGateStopsOnceAuthorizationRequested() {
        HealthAuthorizationPromptState.reset()
        defer { HealthAuthorizationPromptState.reset() }
        XCTAssertTrue(HealthAuthorizationPromptState.shouldOffer())
        HealthAuthorizationPromptState.recordRequested()
        XCTAssertFalse(HealthAuthorizationPromptState.shouldOffer())
    }

    private func makeInMemoryHealthContainer() async throws -> NSPersistentContainer {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main]))
        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let cloud = NSPersistentStoreDescription()
        cloud.type = NSInMemoryStoreType
        cloud.url = URL(fileURLWithPath: "/dev/null/lifeboard-health-cloud-\(UUID().uuidString)")
        cloud.configuration = "CloudSync"
        cloud.shouldAddStoreAsynchronously = false
        let local = NSPersistentStoreDescription()
        local.type = NSInMemoryStoreType
        local.url = URL(fileURLWithPath: "/dev/null/lifeboard-health-local-\(UUID().uuidString)")
        local.configuration = "LocalOnly"
        local.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [cloud, local]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            var remaining = 2
            var firstError: (any Error)?
            container.loadPersistentStores { _, error in
                if firstError == nil { firstError = error }
                remaining -= 1
                guard remaining == 0 else { return }
                if let firstError {
                    continuation.resume(throwing: firstError)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        return container
    }

    private func makeWaterOperation() -> HealthSyncOperation {
        let localID = UUID()
        let timestamp = Date()
        return HealthSyncOperation(
            localID: localID,
            metric: .water,
            kind: .write,
            payload: .init(
                localID: localID,
                metric: .water,
                value: 250,
                startDate: timestamp
            )
        )
    }
}

private final class HealthGatewayFake: HealthKitGatewayProtocol, @unchecked Sendable {
    var isHealthDataAvailable = true
    var authorization: HealthWriteAuthorization = .authorized
    var authorizationRequestError: (any Error)?
    var saveError: (any Error)?
    var changes: [HealthMetric: HealthAnchoredChanges] = [:]
    var anchoredChangesGate: HealthImportGate?

    func requestAuthorization(writeDomains: Set<HealthDomain>) async throws {
        if let authorizationRequestError { throw authorizationRequestError }
    }

    func writeAuthorization(for metric: HealthMetric) async -> HealthWriteAuthorization {
        authorization
    }

    func anchoredChanges(metric: HealthMetric, anchorData: Data?) async throws -> HealthAnchoredChanges {
        await anchoredChangesGate?.wait()
        return changes[metric] ?? .init(samples: [], deletedObjectIDs: [], newAnchorData: anchorData)
    }

    func aggregate(metric: HealthMetric, from start: Date, to end: Date) async throws -> HealthAggregateValue {
        .init(metric: metric, value: 0, start: start, end: end)
    }

    func save(_ payload: HealthWritePayload, syncVersion: Int64) async throws -> [HealthSavedObject] {
        if let saveError { throw saveError }
        return [.init(role: payload.role, uuid: UUID())]
    }

    func deleteObject(uuid: UUID, metric: HealthMetric) async throws {}
    func installObserver(metric: HealthMetric, update: @escaping @Sendable (@escaping () -> Void) -> Void) {}
    func enableBackgroundDelivery(for metric: HealthMetric) async throws {}
}

private actor HealthImportGate {
    private var isOpen = false
    private var hasEntered = false
    private var blockedContinuations: [CheckedContinuation<Void, Never>] = []
    private var entryContinuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        hasEntered = true
        entryContinuations.forEach { $0.resume() }
        entryContinuations.removeAll()
        guard isOpen == false else { return }
        await withCheckedContinuation { continuation in
            blockedContinuations.append(continuation)
        }
    }

    func waitUntilEntered() async {
        guard hasEntered == false else { return }
        await withCheckedContinuation { continuation in
            entryContinuations.append(continuation)
        }
    }

    func open() {
        isOpen = true
        blockedContinuations.forEach { $0.resume() }
        blockedContinuations.removeAll()
    }
}

private actor HealthProjectionFake: HealthProjectionRepository {
    private(set) var reconciledCount = 0
    private var fails = false

    func setFailureEnabled(_ enabled: Bool) {
        fails = enabled
    }

    func reconcileImportedSample(
        _ sample: HealthSampleEnvelope,
        existing: HealthSyncCorrespondence?
    ) async throws -> UUID? {
        if fails { throw HealthKitGatewayError.invalidPayload }
        reconciledCount += 1
        return existing?.localID ?? UUID()
    }

    func deleteImportedProjection(localID: UUID, metric: HealthMetric) async throws {}
}
