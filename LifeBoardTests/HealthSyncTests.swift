import HealthKit
@preconcurrency import CoreData
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
        await ledger.record(.init(
            localID: localID,
            metric: .workout,
            role: "primary",
            hkUUID: UUID(),
            origin: .lifeBoard
        ))
        await ledger.record(.init(
            localID: localID,
            metric: .workout,
            role: "energy",
            hkUUID: UUID(),
            origin: .lifeBoard
        ))
        await ledger.record(.init(
            localID: localID,
            metric: .workout,
            role: "distance",
            hkUUID: UUID(),
            origin: .lifeBoard
        ))

        let values = await ledger.correspondences(localID: localID, metric: .workout)
        XCTAssertEqual(Set(values.map(\.role)), ["primary", "energy", "distance"])
    }

    func testSyncVersionsAreMonotonicPerMetricRole() async throws {
        let ledger = InMemoryHealthSyncLedger()
        let id = UUID()
        let first = await ledger.nextSyncVersion(localID: id, metric: .water, role: "primary")
        let second = await ledger.nextSyncVersion(localID: id, metric: .water, role: "primary")
        let otherRole = await ledger.nextSyncVersion(localID: id, metric: .water, role: "secondary")
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

    func testSleepNotesAreGroupedIntoOneOverlapSafeNight() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let notes = [
            try SleepNote(
                startedAt: start,
                endedAt: start.addingTimeInterval(3_600),
                source: .healthKit,
                healthStageValue: 3
            ),
            try SleepNote(
                startedAt: start.addingTimeInterval(1_800),
                endedAt: start.addingTimeInterval(5_400),
                source: .healthKit,
                healthStageValue: 4
            )
        ]

        let nights = HealthSleepPresentation.nightlySummaries(notes: notes)
        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].totalDuration, 5_400)
        XCTAssertEqual(nights[0].samples.count, 2)
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
        let engine = HealthSyncService(
            gateway: gateway,
            ledger: ledger,
            projections: projections,
            featureFlags: { (true, false) }
        )

        do {
            _ = try await engine.refresh(metrics: [.water])
            XCTFail("Expected projection failure")
        } catch {}
        let failedAnchor = await ledger.anchorData(for: .water)
        XCTAssertNil(failedAnchor)

        await projections.setFailureEnabled(false)
        _ = try await engine.refresh(metrics: [.water])
        let committedAnchor = await ledger.anchorData(for: .water)
        XCTAssertEqual(committedAnchor, Data([7]))
    }

    func testMetricFailureDoesNotBlockIndependentMetricOrOutbox() async throws {
        let gateway = HealthGatewayFake()
        gateway.anchoredErrors[.water] = HealthKitGatewayError.invalidPayload
        let ledger = InMemoryHealthSyncLedger()
        let projections = HealthProjectionFake()
        let engine = HealthSyncService(
            gateway: gateway,
            ledger: ledger,
            projections: projections,
            featureFlags: { (true, false) }
        )

        let result = try await engine.refresh(metrics: [.water, .steps])

        XCTAssertEqual(result.refreshedMetrics, [.steps])
        XCTAssertEqual(result.failures[.water], "invalid_payload")
        XCTAssertNil(result.failures[.steps])
    }

    func testDailyAggregateCacheReturnsOnlyRequestedMetricAndRange() async throws {
        let ledger = InMemoryHealthSyncLedger()
        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        let next = start.addingTimeInterval(86_400)
        await ledger.saveAggregate(.init(metric: .steps, value: 1_000, start: start, end: next))
        await ledger.saveAggregate(.init(metric: .steps, value: 2_000, start: next, end: next.addingTimeInterval(86_400)))
        await ledger.saveAggregate(.init(metric: .water, value: 500, start: start, end: next))

        let values = await ledger.cachedAggregates(
            metric: .steps,
            from: start,
            to: next.addingTimeInterval(1)
        )

        XCTAssertEqual(values.map(\.value), [1_000, 2_000])
        XCTAssertTrue(values.allSatisfy { $0.metric == .steps })
    }

    func testCoordinatorThrottlesForegroundAfterSuccessfulManualSync() async throws {
        let previousReadFlag = V2FeatureFlags.healthIntegrationsV1Enabled
        V2FeatureFlags.healthIntegrationsV1Enabled = true
        HealthAuthorizationPromptState.reset()
        HealthAuthorizationPromptState.recordRequested()
        let suite = "HealthSyncCoordinatorTests.\(UUID().uuidString)"
        defer {
            V2FeatureFlags.healthIntegrationsV1Enabled = previousReadFlag
            HealthAuthorizationPromptState.reset()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }

        let gateway = HealthGatewayFake()
        let ledger = InMemoryHealthSyncLedger()
        let engine = HealthSyncService(
            gateway: gateway,
            ledger: ledger,
            projections: HealthProjectionFake(),
            featureFlags: { (true, false) }
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let coordinator = HealthSyncCoordinator(
            gateway: gateway,
            engineProvider: { engine },
            ledgerProvider: { ledger },
            defaultsSuiteName: suite,
            calendar: calendar
        )
        let now = Date(timeIntervalSince1970: 1_735_732_800) // 2025-01-01 12:00:00 UTC

        let manual = await coordinator.sync(.manual, now: now)
        let requestCount = gateway.anchoredRequestCount
        let foreground = await coordinator.sync(.foreground, now: now.addingTimeInterval(60))
        let persistedLastSync = await coordinator.lastSuccessfulSync()

        XCTAssertFalse(manual.skipped)
        XCTAssertTrue(foreground.skipped)
        XCTAssertEqual(gateway.anchoredRequestCount, requestCount)
        XCTAssertEqual(persistedLastSync, now)
    }

    func testObserverCompletionWaitsForCoordinatedRefresh() async {
        let gateway = HealthGatewayFake()
        let gate = HealthImportGate()
        gateway.anchoredChangesGate = gate
        let ledger = InMemoryHealthSyncLedger()
        let engine = HealthSyncService(
            gateway: gateway,
            ledger: ledger,
            projections: HealthProjectionFake(),
            featureFlags: { (true, false) }
        )
        let coordinator = HealthSyncCoordinator(
            gateway: gateway,
            engineProvider: { engine },
            ledgerProvider: { ledger }
        )
        let observers = HealthObserverCoordinator(gateway: gateway)
        observers.installObservers()
        observers.attach(coordinator: coordinator)
        let completed = expectation(description: "HealthKit observer completion")

        gateway.fireObserver(metric: .water) { completed.fulfill() }
        await gate.waitUntilEntered()
        XCTAssertEqual(gateway.anchoredRequestCount, 1)
        XCTAssertEqual(completed.expectedFulfillmentCount, 1)
        await gate.open()
        await fulfillment(of: [completed], timeout: 1)
    }

    /// Onboarding's Health primer promises LifeBoard will read what the user
    /// already logs. `connect(enableWriteBack: false)` did not keep that promise:
    /// it skipped the ledger preference but still handed Apple the full writable
    /// set, so the system sheet asked for write access anyway.
    @MainActor
    func testConnectReadOnlyAsksAppleForNoWriteAccessAtAll() async {
        HealthAuthorizationPromptState.reset()
        defer { HealthAuthorizationPromptState.reset() }
        let gateway = HealthGatewayFake()
        let store = HealthConnectionStore(
            gateway: gateway,
            engineProvider: { nil },
            ledgerProvider: { InMemoryHealthSyncLedger() }
        )

        await store.connectReadOnly()

        XCTAssertEqual(gateway.requestedWriteDomains.count, 1)
        XCTAssertEqual(gateway.requestedWriteDomains.first, [], "read-only must request an empty share set")
    }

    /// The ordinary in-app affordance is unchanged: a surface that named writing
    /// explicitly still asks for it.
    @MainActor
    func testConnectStillRequestsWritableDomainsWhenWriteBackIsWanted() async {
        HealthAuthorizationPromptState.reset()
        defer { HealthAuthorizationPromptState.reset() }
        let gateway = HealthGatewayFake()
        let store = HealthConnectionStore(
            gateway: gateway,
            engineProvider: { nil },
            ledgerProvider: { InMemoryHealthSyncLedger() }
        )

        let domains = Set(HealthDomain.allCases)
        await store.connect(domains: domains, enableWriteBack: true)

        XCTAssertEqual(gateway.requestedWriteDomains.count, 1)
        XCTAssertEqual(
            gateway.requestedWriteDomains.first,
            Set(domains.filter(\.supportsWriteBack)),
            "the writable domains are still requested when the user asked to write"
        )
        XCTAssertFalse(gateway.requestedWriteDomains.first?.isEmpty ?? true)
    }

    @MainActor
    func testConnectionStoreRestoresDurableReadRequestState() {
        HealthAuthorizationPromptState.reset()
        HealthAuthorizationPromptState.recordRequested()
        defer { HealthAuthorizationPromptState.reset() }
        let ledger = InMemoryHealthSyncLedger()
        let store = HealthConnectionStore(
            gateway: HealthGatewayFake(),
            engineProvider: { nil },
            ledgerProvider: { ledger }
        )

        XCTAssertEqual(store.statuses[.activity]?.readRequestState, .requestCompleted)
        XCTAssertNotEqual(store.statuses[.activity]?.signal, .setupRequired)
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
        let engine = HealthSyncService(
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
        await ledger.record(.init(
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
        let engine = HealthSyncService(
            gateway: gateway,
            ledger: ledger,
            projections: projections,
            featureFlags: { (true, false) }
        )
        _ = try await engine.refresh(metrics: [.water])
        let suppressed = await ledger.correspondence(hkUUID: healthID)?.isRecreationSuppressed
        XCTAssertEqual(suppressed, true)

        try await engine.localRecordWasEdited(localID: localID, metric: .water)
        let recreatedAfterEdit = await ledger.correspondence(hkUUID: healthID)?.isRecreationSuppressed
        XCTAssertEqual(recreatedAfterEdit, false)
    }

    func testDeniedWritePausesOutboxWithoutRemovingManualRecordIntent() async throws {
        let gateway = HealthGatewayFake()
        gateway.authorization = .denied
        let ledger = InMemoryHealthSyncLedger()
        await ledger.writePreference(domain: .hydration, enabled: true, optedInAt: Date())
        let operation = makeWaterOperation()
        await ledger.save(operation)
        let engine = HealthSyncService(
            gateway: gateway,
            ledger: ledger,
            projections: HealthProjectionFake(),
            featureFlags: { (true, true) }
        )

        try await engine.processOutbox()

        let queued = await ledger.pendingOperations(now: .distantFuture, limit: 10)
        XCTAssertEqual(queued.first?.id, operation.id)
        XCTAssertEqual(queued.first?.state, .pausedPermission)
        XCTAssertEqual(queued.first?.lastErrorCode, "write_denied")
    }

    func testTransientWriteFailureSchedulesNonSensitiveRetry() async throws {
        let gateway = HealthGatewayFake()
        gateway.saveError = HealthKitGatewayError.unavailable
        let ledger = InMemoryHealthSyncLedger()
        await ledger.writePreference(domain: .hydration, enabled: true, optedInAt: Date())
        let operation = makeWaterOperation()
        await ledger.save(operation)
        let engine = HealthSyncService(
            gateway: gateway,
            ledger: ledger,
            projections: HealthProjectionFake(),
            featureFlags: { (true, true) }
        )

        try await engine.processOutbox()

        let queued = await ledger.pendingOperations(now: .distantFuture, limit: 10)
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
        let engine = HealthSyncService(
            gateway: gateway,
            ledger: ledger,
            projections: HealthProjectionFake(),
            featureFlags: { (true, false) }
        )
        let hub = HealthSyncInvalidationService()
        let suite = "HealthConnectionStoreTests.\(UUID().uuidString)"
        let coordinator = HealthSyncCoordinator(
            gateway: gateway,
            engineProvider: { engine },
            ledgerProvider: { ledger },
            defaultsSuiteName: suite,
            invalidationHub: hub
        )
        let store = HealthConnectionStore(
            gateway: gateway,
            engineProvider: { engine },
            ledgerProvider: { ledger },
            coordinator: coordinator,
            invalidationHub: hub
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
        let model = try PersistenceTestModel.model()
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
    var anchoredErrors: [HealthMetric: any Error] = [:]
    var anchoredChangesGate: HealthImportGate?
    private let requestLock = NSLock()
    private var anchoredRequests: [HealthMetric] = []
    private var observerUpdates: [HealthMetric: @Sendable (@escaping () -> Void) -> Void] = [:]

    var anchoredRequestCount: Int { requestLock.withLock { anchoredRequests.count } }

    private(set) var requestedWriteDomains: [Set<HealthDomain>] = []

    func requestAuthorization(writeDomains: Set<HealthDomain>) async throws {
        requestLock.withLock { requestedWriteDomains.append(writeDomains) }
        if let authorizationRequestError { throw authorizationRequestError }
    }

    func writeAuthorization(for metric: HealthMetric) async -> HealthWriteAuthorization {
        authorization
    }

    func anchoredChanges(metric: HealthMetric, anchorData: Data?) async throws -> HealthAnchoredChanges {
        requestLock.withLock { anchoredRequests.append(metric) }
        await anchoredChangesGate?.wait()
        if let error = anchoredErrors[metric] { throw error }
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
    func installObserver(metric: HealthMetric, update: @escaping @Sendable (@escaping () -> Void) -> Void) {
        requestLock.withLock { observerUpdates[metric] = update }
    }
    func fireObserver(metric: HealthMetric, completion: @escaping () -> Void) {
        requestLock.withLock { observerUpdates[metric] }?(completion)
    }
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

/// Regression cover for the intermittent launch crash in which
/// `HealthSyncCoordinator`'s background aggregate refresh reached
/// `+[_NSPredicateUtilities _parserableDateDescription:]` and faulted with
/// `SIGSEGV` inside `__dtoa`'s bignum path. HealthKit formats predicate dates
/// with `%f`; a non-finite or astronomically large interval makes that
/// expansion unbounded, so the range has to be rejected before a predicate is
/// built rather than after.
final class HealthDateRangeValidatorTests: XCTestCase {
    func testOrdinaryRangesAreUsable() {
        XCTAssertTrue(HealthDateRangeValidator.isUsable(Date()))
        XCTAssertTrue(HealthDateRangeValidator.isUsable(Date(timeIntervalSinceReferenceDate: 0)))
        XCTAssertNoThrow(
            try HealthDateRangeValidator.validate(
                start: Date(timeIntervalSinceReferenceDate: 0),
                end: Date()
            )
        )
    }

    func testNonFiniteDatesAreRejected() {
        for interval in [Double.nan, .infinity, -.infinity] {
            let date = Date(timeIntervalSinceReferenceDate: interval)
            XCTAssertFalse(
                HealthDateRangeValidator.isUsable(date),
                "interval \(interval) must not reach an HKQuery predicate"
            )
        }
    }

    func testAstronomicalDatesAreRejected() {
        // The magnitude that actually crashed: the decimal expansion HealthKit
        // has to allocate grows with the exponent.
        let huge = Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude)
        XCTAssertFalse(HealthDateRangeValidator.isUsable(huge))
        XCTAssertThrowsError(try HealthDateRangeValidator.validate(start: Date(), end: huge)) { error in
            XCTAssertEqual(error as? HealthKitGatewayError, .invalidDateRange)
        }
        XCTAssertThrowsError(try HealthDateRangeValidator.validate(start: huge, end: Date()))
    }

    func testBoundaryIsWideEnoughForRealProductRanges() throws {
        // A decade of history either side of now must remain queryable.
        let now = Date()
        let tenYears: TimeInterval = 10 * 365 * 24 * 60 * 60
        XCTAssertNoThrow(
            try HealthDateRangeValidator.validate(
                start: now.addingTimeInterval(-tenYears),
                end: now.addingTimeInterval(tenYears)
            )
        )
    }
}
