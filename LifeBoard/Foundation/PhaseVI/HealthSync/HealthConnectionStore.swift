import Foundation
import Observation
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

    private let gateway: any HealthKitGatewayProtocol
    private let engineProvider: @Sendable () async -> HealthSyncEngine?
    private let ledgerProvider: @Sendable () async -> (any HealthSyncLedgerStore)?
    private var readRequestState: HealthReadRequestState = .neverRequested
    @ObservationIgnored private var initialSyncTask: Task<Void, Never>?

    public init(
        gateway: any HealthKitGatewayProtocol,
        engineProvider: @escaping @Sendable () async -> HealthSyncEngine?,
        ledgerProvider: @escaping @Sendable () async -> (any HealthSyncLedgerStore)?
    ) {
        self.gateway = gateway
        self.engineProvider = engineProvider
        self.ledgerProvider = ledgerProvider
        statuses = Dictionary(uniqueKeysWithValues: HealthDomain.allCases.map {
            ($0, HealthDomainStatus(domain: $0))
        })
    }

    deinit {
        initialSyncTask?.cancel()
    }

    /// Requests HealthKit authorization and records the resulting local
    /// connection state. The initial HealthKit import starts afterward as a
    /// managed task; callers do not wait for that potentially long-running work.
    /// Observe `isRefreshing` and `lastSuccessfulSync` for import progress.
    public func connect(domains: Set<HealthDomain>) async {
        guard V2FeatureFlags.healthIntegrationsV1Enabled else { return }
        // Durably record that we've asked (across launches) before the system
        // sheet appears, so the just-in-time invitation never re-fires regardless
        // of how this connect was reached (onboarding, Settings, hub, or JIT).
        HealthAuthorizationPromptState.recordRequested()
        let writable = Set(domains.filter(\.supportsWriteBack))
        do {
            try await gateway.requestAuthorization(writeDomains: writable)
            readRequestState = .requestCompleted
            if let ledger = await ledgerProvider() {
                for domain in writable {
                    try await ledger.writePreference(domain: domain, enabled: true, optedInAt: Date())
                }
            }
            await refreshAuthorization()
            scheduleInitialSync()
        } catch {
            readRequestState = .requestCompleted
            nonSensitiveErrorCode = "authorization_request"
            await refreshAuthorization()
        }
    }

    private func scheduleInitialSync() {
        guard initialSyncTask == nil else { return }
        initialSyncTask = Task { [weak self] in
            await self?.syncNow()
            guard Task.isCancelled == false else { return }
            self?.initialSyncTask = nil
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
        guard isRefreshing == false, let engine = await engineProvider() else { return }
        isRefreshing = true
        nonSensitiveErrorCode = nil
        for domain in HealthDomain.allCases {
            statuses[domain]?.signal = .loading
        }
        do {
            let result = try await engine.refresh()
            lastSuccessfulSync = result.successfulAt
            readRequestState = .receivingData
            await refreshTodayAggregates()
            for domain in HealthDomain.allCases {
                statuses[domain]?.readRequestState = readRequestState
                statuses[domain]?.lastSuccessfulSync = result.successfulAt
                let domainValues = domain.metrics.compactMap { aggregates[$0] }
                if domainValues.isEmpty {
                    statuses[domain]?.signal = readRequestState == .neverRequested ? .setupRequired : .unavailable
                } else if domainValues.allSatisfy({ $0.value == 0 }) {
                    statuses[domain]?.signal = .explicitZero
                } else {
                    statuses[domain]?.signal = .recorded
                }
            }
        } catch {
            nonSensitiveErrorCode = "sync_failed"
            for domain in HealthDomain.allCases where statuses[domain]?.signal == .loading {
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
        }
        isRefreshing = false
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
}
