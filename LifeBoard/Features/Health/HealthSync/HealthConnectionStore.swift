import Foundation
import Observation
import OSLog
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
public final class HealthConnectionStore {
    public private(set) var statuses: [HealthDomain: HealthDomainStatus]
    public private(set) var aggregates: [HealthMetric: HealthAggregateValue] = [:]
    public private(set) var isRefreshing = false
    public private(set) var lastSuccessfulSync: Date?
    public private(set) var nonSensitiveErrorCode: String?
    public private(set) var isInitialSyncPending = false

    private let gateway: any HealthKitGatewayProtocol
    public let coordinator: HealthSyncCoordinator
    private let ledgerProvider: @Sendable () async -> (any HealthSyncLedgerStore)?
    private let invalidationHub: HealthSyncInvalidationService
    private var readRequestState: HealthReadRequestState
    @ObservationIgnored private var initialSyncTask: Task<Void, Never>?
    @ObservationIgnored private var invalidationTask: Task<Void, Never>?
    private static let logger = Logger(subsystem: "com.lifeboard.health", category: "connection")

    public init(
        gateway: any HealthKitGatewayProtocol,
        engineProvider: @escaping @Sendable () async -> HealthSyncService?,
        ledgerProvider: @escaping @Sendable () async -> (any HealthSyncLedgerStore)?,
        coordinator: HealthSyncCoordinator? = nil,
        invalidationHub: HealthSyncInvalidationService = .shared
    ) {
        self.gateway = gateway
        self.ledgerProvider = ledgerProvider
        self.invalidationHub = invalidationHub
        self.coordinator = coordinator ?? HealthSyncCoordinator(
            gateway: gateway,
            engineProvider: engineProvider,
            ledgerProvider: ledgerProvider
        )
        let initialReadRequestState: HealthReadRequestState = HealthAuthorizationPromptState.hasRequested
            ? .requestCompleted
            : .neverRequested
        readRequestState = initialReadRequestState
        statuses = Dictionary(uniqueKeysWithValues: HealthDomain.allCases.map {
            ($0, HealthDomainStatus(
                domain: $0,
                readRequestState: initialReadRequestState,
                signal: initialReadRequestState == .neverRequested ? .setupRequired : .noRecord
            ))
        })
        observeInvalidations()
    }

    deinit {
        initialSyncTask?.cancel()
        invalidationTask?.cancel()
    }

    /// Requests HealthKit authorization and records the resulting local
    /// connection state. The initial HealthKit import starts afterward as a
    /// managed task; callers do not wait for that potentially long-running work.
    /// Observe `isRefreshing` and `lastSuccessfulSync` for import progress.
    /// - Parameter enableWriteBack: Whether a granted writable domain should
    ///   also have its write preference switched on. Defaults to `true`, which
    ///   is what every in-app "Connect Health" affordance means — the user
    ///   reached it through a surface that named writing explicitly. Onboarding
    ///   passes `false`: it asks for read authorization up front, and treats
    ///   letting LifeBoard write *into* Apple Health as a separate, opt-in
    ///   answer. Without this the first run silently enabled write-back for
    ///   every writable domain the user had never been asked about.
    public func connect(domains: Set<HealthDomain>, enableWriteBack: Bool = true) async {
        await connect(
            domains: domains,
            writableDomains: Set(domains.filter(\.supportsWriteBack)),
            enableWriteBack: enableWriteBack
        )
    }

    /// Asks for read access and nothing else.
    ///
    /// `enableWriteBack: false` was never enough on its own: it skipped the
    /// ledger preference but still handed the full writable set to the gateway,
    /// so Apple's sheet still offered write toggles for categories the user had
    /// not been asked about. A primer that promises "we'll read what you already
    /// log" followed by a sheet asking for write permission is the kind of small
    /// dishonesty that costs the whole permission.
    ///
    /// Write-back stays a separate, later, explicit opt-in.
    public func connectReadOnly(domains: Set<HealthDomain> = Set(HealthDomain.allCases)) async {
        await connect(domains: domains, writableDomains: [], enableWriteBack: false)
    }

    private func connect(
        domains: Set<HealthDomain>,
        writableDomains: Set<HealthDomain>,
        enableWriteBack: Bool
    ) async {
        guard V2FeatureFlags.healthIntegrationsV1Enabled else { return }
        // Durably record that we've asked (across launches) before the system
        // sheet appears, so the just-in-time invitation never re-fires regardless
        // of how this connect was reached (onboarding, Settings, hub, or JIT).
        HealthAuthorizationPromptState.recordRequested()
        let writable = writableDomains
        do {
            try await gateway.requestAuthorization(writeDomains: writable)
            readRequestState = .requestCompleted
            if enableWriteBack, let ledger = await ledgerProvider() {
                for domain in writable {
                    try await ledger.writePreference(domain: domain, enabled: true, optedInAt: Date())
                }
            }
            await refreshAuthorization()
            isInitialSyncPending = true
            scheduleInitialSync(trigger: .authorization)
        } catch {
            readRequestState = .requestCompleted
            nonSensitiveErrorCode = "authorization_request"
            await refreshAuthorization()
        }
    }

    private func scheduleInitialSync(trigger: HealthSyncTrigger) {
        guard initialSyncTask == nil else { return }
        initialSyncTask = Task { [weak self] in
            guard let self else { return }
            await self.runSync(trigger)
            self.initialSyncTask = nil
        }
    }

    public func setWriteEnabled(_ enabled: Bool, for domain: HealthDomain) async {
        guard V2FeatureFlags.healthIntegrationsV1Enabled,
              enabled == false || V2FeatureFlags.healthWriteBackV1Enabled else {
            return
        }
        if enabled {
            let authorizations = await withTaskGroup(of: HealthWriteAuthorization.self) { group in
                for metric in domain.metrics {
                    group.addTask { [gateway] in await gateway.writeAuthorization(for: metric) }
                }
                var values: [HealthWriteAuthorization] = []
                for await value in group { values.append(value) }
                return values
            }
            if authorizations.contains(.notDetermined) {
                await connect(domains: [domain])
                return
            }
        }
        guard domain.supportsWriteBack, let ledger = await ledgerProvider() else { return }
        do {
            try await ledger.writePreference(domain: domain, enabled: enabled, optedInAt: enabled ? Date() : nil)
            statuses[domain]?.writeEnabled = enabled
            await refreshAuthorization()
        } catch {
            nonSensitiveErrorCode = "preference_write"
        }
    }

    public func syncNow() async {
        await runSync(.manual)
    }

    public func syncIfNeededOnForeground() async {
        await runSync(.foreground)
    }

    public func bootstrap() async {
        readRequestState = HealthAuthorizationPromptState.hasRequested ? .requestCompleted : .neverRequested
        aggregates = await coordinator.cachedCurrentAggregates()
        lastSuccessfulSync = await coordinator.lastSuccessfulSync()
        await refreshAuthorization()
        applySignals(failures: [:])
    }

    /// Called after the local Health engine and ledger become available.
    /// Authorization can complete before Core Data migration/attachment; in
    /// that window the coordinator deliberately returns a skipped outcome. A
    /// skipped authorization import remains pending and is replayed here.
    public func runtimeDidAttach() async {
        await bootstrap()
        if let initialSyncTask {
            await initialSyncTask.value
        }
        if HealthAuthorizationPromptState.hasRequested,
           isInitialSyncPending || lastSuccessfulSync == nil {
            Self.logger.info("health_initial_sync_replayed runtime_attached=true")
            await runSync(.authorization)
        } else {
            await runSync(.foreground)
        }
    }

    private func runSync(_ trigger: HealthSyncTrigger) async {
        isRefreshing = true
        nonSensitiveErrorCode = nil
        for domain in HealthDomain.allCases {
            statuses[domain]?.signal = .loading
        }
        let result = await coordinator.sync(trigger)
        if result.skipped {
            if HealthAuthorizationPromptState.hasRequested,
               isInitialSyncPending || lastSuccessfulSync == nil {
                isInitialSyncPending = true
            }
            Self.logger.info("health_sync_skipped trigger=\(String(describing: trigger), privacy: .public) pending=\(self.isInitialSyncPending, privacy: .public)")
        } else {
            isInitialSyncPending = false
            if result.refreshedMetrics.isEmpty == false || result.aggregates.isEmpty == false {
                lastSuccessfulSync = result.completedAt
            }
            readRequestState = .receivingData
            aggregates.merge(result.aggregates) { _, new in new }
        }
        if result.failures.isEmpty == false {
            nonSensitiveErrorCode = result.isPartial ? "sync_partial" : "sync_failed"
            applySignals(failures: result.failures)
            for domain in HealthDomain.allCases
            where domain.metrics.contains(where: { result.failures[$0] != nil })
                && domain.metrics.compactMap({ aggregates[$0] }).isEmpty {
                #if canImport(UIKit)
                if UIApplication.shared.isProtectedDataAvailable == false {
                    statuses[domain]?.signal = .protectedDataLocked
                } else {
                    statuses[domain]?.signal = gateway.isHealthDataAvailable ? .stale : .unavailable
                }
                #else
                statuses[domain]?.signal = gateway.isHealthDataAvailable ? .stale : .unavailable
                #endif
            }
        } else { applySignals(failures: result.failures) }
        isRefreshing = false
        Self.logger.info("health_sync_finished trigger=\(String(describing: trigger), privacy: .public) skipped=\(result.skipped, privacy: .public) failure_count=\(result.failures.count, privacy: .public)")
    }

    public func markMigrationUnavailable() {
        nonSensitiveErrorCode = "local_migration"
        for domain in HealthDomain.allCases {
            statuses[domain]?.signal = .offline
        }
    }

    public func refreshAuthorization() async {
        let ledger = await ledgerProvider()
        for domain in HealthDomain.allCases {
            var status = statuses[domain] ?? .init(domain: domain)
            status.readRequestState = readRequestState
            if let ledger {
                status.writeEnabled = (try? await ledger.writePreference(for: domain)) ?? false
            }
            var writeStates: [HealthMetric: HealthWriteAuthorization] = [:]
            for metric in HealthKitTypeCatalog.writeAuthorizationMetrics(for: domain) {
                writeStates[metric] = await gateway.writeAuthorization(for: metric)
            }
            status.writeAuthorizations = writeStates
            if status.writeEnabled && writeStates.values.contains(.denied) {
                status.signal = .writeDenied
            } else if readRequestState == .neverRequested {
                status.signal = .setupRequired
            }
            statuses[domain] = status
        }
    }

    public func refreshTodayAggregates(now: Date = Date()) async {
        let start = Calendar.autoupdatingCurrent.startOfDay(for: now)
        let ledger = await ledgerProvider()
        let aggregateMetrics: [HealthMetric] = [
            .steps, .walkingRunningDistance, .activeEnergy, .restingEnergy,
            .water, .dietaryEnergy, .dietaryProtein, .dietaryCarbohydrates,
            .dietaryFat, .bodyMass, .bodyFatPercentage, .waistCircumference,
            .restingHeartRate
        ]
        await withTaskGroup(of: (HealthMetric, HealthAggregateValue?).self) { group in
            for metric in aggregateMetrics {
                group.addTask { [gateway] in
                    (metric, try? await gateway.aggregate(metric: metric, from: start, to: now))
                }
            }
            for await (metric, value) in group {
                if let value {
                    aggregates[value.metric] = value
                    try? await ledger?.saveAggregate(value)
                } else if let cached = try? await ledger?.cachedAggregate(metric: metric, start: start) {
                    aggregates[metric] = cached
                }
            }
        }
    }

    private func observeInvalidations() {
        invalidationTask = Task { [weak self, invalidationHub] in
            let updates = await invalidationHub.updates()
            for await event in updates {
                guard Task.isCancelled == false, let self else { return }
                let cached = await self.coordinator.cachedCurrentAggregates(now: event.completedAt)
                self.aggregates.merge(cached) { _, new in new }
                self.lastSuccessfulSync = await self.coordinator.lastSuccessfulSync()
                if self.readRequestState != .neverRequested { self.readRequestState = .receivingData }
                self.applySignals(failures: event.isPartial ? Dictionary(uniqueKeysWithValues: event.metrics.map { ($0, "partial") }) : [:])
            }
        }
    }

    private func applySignals(failures: [HealthMetric: String]) {
        for domain in HealthDomain.allCases {
            statuses[domain]?.readRequestState = readRequestState
            statuses[domain]?.lastSuccessfulSync = lastSuccessfulSync
            let values = domain.metrics.compactMap { aggregates[$0] }
            if statuses[domain]?.writeEnabled == true,
               statuses[domain]?.writeAuthorizations.values.contains(.denied) == true {
                statuses[domain]?.signal = .writeDenied
            } else if domain.metrics.contains(where: { failures[$0] != nil }), values.isEmpty == false {
                statuses[domain]?.signal = .partial
            } else if values.isEmpty || values.allSatisfy({ $0.value == 0 && $0.lastSampleAt == nil }) {
                statuses[domain]?.signal = readRequestState == .neverRequested ? .setupRequired : .noRecord
            } else if values.allSatisfy({ $0.value == 0 }) {
                statuses[domain]?.signal = .explicitZero
            } else {
                statuses[domain]?.signal = .recorded
            }
        }
    }
}
