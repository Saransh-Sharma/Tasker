import Foundation

public actor HealthSyncCoordinator {
    public static let foregroundRefreshInterval: TimeInterval = 15 * 60

    private let gateway: any HealthKitGatewayProtocol
    private let engineProvider: @Sendable () async -> HealthSyncEngine?
    private let ledgerProvider: @Sendable () async -> (any HealthSyncLedgerStore)?
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let invalidationHub: HealthSyncInvalidationHub
    private var pendingTrigger: HealthSyncTrigger?
    private var pendingWaiters: [CheckedContinuation<HealthSyncOutcome, Never>] = []
    private var worker: Task<Void, Never>?

    private static let lastSuccessfulSyncKey = "health.sync.lastSuccessfulAt.v1"
    private static let lastAggregateDayKey = "health.sync.lastAggregateDay.v1"
    private static let deliveryErrorKey = "health.sync.backgroundDeliveryError.v1"

    public init(
        gateway: any HealthKitGatewayProtocol,
        engineProvider: @escaping @Sendable () async -> HealthSyncEngine?,
        ledgerProvider: @escaping @Sendable () async -> (any HealthSyncLedgerStore)?,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        invalidationHub: HealthSyncInvalidationHub = .shared
    ) {
        self.gateway = gateway
        self.engineProvider = engineProvider
        self.ledgerProvider = ledgerProvider
        self.defaults = defaults
        self.calendar = calendar
        self.invalidationHub = invalidationHub
    }

    public init(
        gateway: any HealthKitGatewayProtocol,
        engineProvider: @escaping @Sendable () async -> HealthSyncEngine?,
        ledgerProvider: @escaping @Sendable () async -> (any HealthSyncLedgerStore)?,
        defaultsSuiteName: String,
        calendar: Calendar = .autoupdatingCurrent,
        invalidationHub: HealthSyncInvalidationHub = .shared
    ) {
        self.gateway = gateway
        self.engineProvider = engineProvider
        self.ledgerProvider = ledgerProvider
        defaults = UserDefaults(suiteName: defaultsSuiteName) ?? .standard
        self.calendar = calendar
        self.invalidationHub = invalidationHub
    }

    public func sync(_ trigger: HealthSyncTrigger, now: Date = Date()) async -> HealthSyncOutcome {
        await withCheckedContinuation { continuation in
            pendingTrigger = Self.merge(pendingTrigger, trigger)
            pendingWaiters.append(continuation)
            guard worker == nil else { return }
            worker = Task { await self.drain(now: now) }
        }
    }

    public func lastSuccessfulSync() -> Date? {
        defaults.object(forKey: Self.lastSuccessfulSyncKey) as? Date
    }

    public func prepareForLaunch() async {
        guard HealthAuthorizationPromptState.hasRequested else { return }
        await ensureBackgroundDelivery()
    }

    public func cachedCurrentAggregates(now: Date = Date()) async -> [HealthMetric: HealthAggregateValue] {
        guard let ledger = await ledgerProvider() else { return [:] }
        let start = calendar.startOfDay(for: now)
        var result: [HealthMetric: HealthAggregateValue] = [:]
        for metric in Self.aggregateMetrics {
            if let value = try? await ledger.cachedAggregate(metric: metric, start: start) {
                result[metric] = value
            }
        }
        return result
    }

    public func cachedHistory(
        domain: HealthInsightDomain,
        range: HealthHistoryRange,
        now: Date = Date()
    ) async -> [HealthMetric: [HealthAggregateValue]] {
        guard let ledger = await ledgerProvider() else { return [:] }
        let start = range.startDate(now: now, calendar: calendar)
        let end = now
        var result: [HealthMetric: [HealthAggregateValue]] = [:]
        for metric in domain.metrics where Self.aggregateMetrics.contains(metric) {
            result[metric] = (try? await ledger.cachedAggregates(metric: metric, from: start, to: end)) ?? []
        }
        return result
    }

    private func drain(now: Date) async {
        while let trigger = pendingTrigger {
            let waiters = pendingWaiters
            pendingTrigger = nil
            pendingWaiters = []
            let outcome = await perform(trigger, now: now)
            waiters.forEach { $0.resume(returning: outcome) }
        }
        worker = nil
    }

    private func perform(_ trigger: HealthSyncTrigger, now: Date) async -> HealthSyncOutcome {
        if case .foreground = trigger {
            guard HealthAuthorizationPromptState.hasRequested else {
                return .init(trigger: trigger, completedAt: now, skipped: true)
            }
            let last = lastSuccessfulSync()
            let dayChanged = last.map { calendar.isDate($0, inSameDayAs: now) == false } ?? true
            if dayChanged == false,
               let last,
               now.timeIntervalSince(last) < Self.foregroundRefreshInterval {
                return .init(
                    trigger: trigger,
                    aggregates: await cachedCurrentAggregates(now: now),
                    completedAt: now,
                    skipped: true
                )
            }
        }

        if case .historyBackfill(let metrics, let range) = trigger {
            return await backfill(metrics: metrics, range: range, trigger: trigger, now: now)
        }

        guard let engine = await engineProvider(), let ledger = await ledgerProvider() else {
            return .init(trigger: trigger, completedAt: now, skipped: true)
        }

        if trigger == .authorization || trigger == .manual || trigger == .foreground {
            await ensureBackgroundDelivery()
        }

        var refreshed = Set<HealthMetric>()
        var failures: [HealthMetric: String] = [:]
        do {
            switch trigger {
            case .outbox:
                refreshed = try await engine.processOutbox(now: now)
            default:
                let result = try await engine.refresh(metrics: trigger.metrics)
                refreshed = result.refreshedMetrics.union(result.writtenMetrics)
                failures = result.failures
                if let code = result.outboxErrorCode {
                    trigger.metrics.subtracting(result.refreshedMetrics).forEach { failures[$0] = code }
                }
            }
        } catch HealthSyncEngineError.allMetricsFailed(let metricFailures) {
            failures = metricFailures
        } catch {
            trigger.metrics.forEach { failures[$0] = "sync_failed" }
        }

        let aggregateTargets = trigger.metrics.intersection(Self.aggregateMetrics)
        let aggregateResult = await refreshCurrentAggregates(
            metrics: aggregateTargets,
            ledger: ledger,
            now: now
        )
        failures.merge(aggregateResult.failures) { existing, _ in existing }
        let aggregates = aggregateResult.values

        let shouldBackfill: Bool = switch trigger {
        case .authorization: true
        case .foreground:
            (defaults.object(forKey: Self.lastAggregateDayKey) as? Date)
                .map { calendar.isDate($0, inSameDayAs: now) == false } ?? true
        default: false
        }
        if shouldBackfill {
            defaults.set(calendar.startOfDay(for: now), forKey: Self.lastAggregateDayKey)
            Task {
                _ = await self.sync(
                    .historyBackfill(Set(Self.aggregateMetrics), .ninetyDays),
                    now: now
                )
            }
        }

        if refreshed.isEmpty == false || aggregates.isEmpty == false {
            defaults.set(now, forKey: Self.lastSuccessfulSyncKey)
        }
        let outcome = HealthSyncOutcome(
            trigger: trigger,
            refreshedMetrics: refreshed,
            aggregates: aggregates,
            failures: failures,
            completedAt: now
        )
        await invalidationHub.publish(.init(
            trigger: trigger,
            metrics: refreshed.union(aggregateTargets),
            completedAt: now,
            isPartial: outcome.isPartial
        ))
        return outcome
    }

    private func refreshCurrentAggregates(
        metrics: Set<HealthMetric>,
        ledger: any HealthSyncLedgerStore,
        now: Date
    ) async -> (values: [HealthMetric: HealthAggregateValue], failures: [HealthMetric: String]) {
        let start = calendar.startOfDay(for: now)
        var values: [HealthMetric: HealthAggregateValue] = [:]
        var failures: [HealthMetric: String] = [:]
        await withTaskGroup(of: (HealthMetric, HealthAggregateValue?, String?).self) { group in
            for metric in metrics {
                group.addTask { [gateway] in
                    do {
                        return (metric, try await gateway.aggregate(metric: metric, from: start, to: now), nil)
                    } catch {
                        return (metric, nil, "aggregate_failed")
                    }
                }
            }
            for await (metric, value, errorCode) in group {
                if let value {
                    values[metric] = value
                } else if let cached = try? await ledger.cachedAggregate(metric: metric, start: start) {
                    values[metric] = cached
                }
                if let errorCode { failures[metric] = errorCode }
            }
        }
        do {
            try await ledger.saveAggregates(Array(values.values))
        } catch {
            for metric in values.keys { failures[metric] = failures[metric] ?? "aggregate_cache_failed" }
        }
        return (values, failures)
    }

    private func backfill(
        metrics: Set<HealthMetric>,
        range: HealthHistoryRange,
        trigger: HealthSyncTrigger,
        now: Date,
        publishesEvent: Bool = true
    ) async -> HealthSyncOutcome {
        guard let ledger = await ledgerProvider() else {
            return .init(trigger: trigger, completedAt: now, skipped: true)
        }
        let start = range.startDate(now: now, calendar: calendar)
        var refreshed = Set<HealthMetric>()
        var failures: [HealthMetric: String] = [:]
        for metric in metrics.intersection(Self.aggregateMetrics) {
            do {
                let values = try await gateway.dailyAggregates(metric: metric, from: start, to: now)
                try await ledger.saveAggregates(values)
                refreshed.insert(metric)
            } catch {
                failures[metric] = "history_failed"
            }
        }
        let outcome = HealthSyncOutcome(
            trigger: trigger,
            refreshedMetrics: refreshed,
            failures: failures,
            completedAt: now
        )
        if publishesEvent {
            await invalidationHub.publish(.init(
                trigger: trigger,
                metrics: refreshed,
                completedAt: now,
                isPartial: outcome.isPartial
            ))
        }
        return outcome
    }

    private func ensureBackgroundDelivery() async {
        var firstFailure: String?
        for metric in HealthKitTypeCatalog.readableMetrics {
            do {
                try await gateway.enableBackgroundDelivery(for: metric)
            } catch {
                firstFailure = firstFailure ?? metric.rawValue
            }
        }
        if let firstFailure {
            defaults.set(firstFailure, forKey: Self.deliveryErrorKey)
        } else {
            defaults.removeObject(forKey: Self.deliveryErrorKey)
        }
    }

    private static let aggregateMetrics: Set<HealthMetric> = [
        .steps, .walkingRunningDistance, .activeEnergy, .restingEnergy,
        .water, .dietaryEnergy, .dietaryProtein, .dietaryCarbohydrates,
        .dietaryFat, .bodyMass, .bodyFatPercentage, .waistCircumference,
        .restingHeartRate
    ]

    private static func merge(_ current: HealthSyncTrigger?, _ incoming: HealthSyncTrigger) -> HealthSyncTrigger {
        guard let current else { return incoming }
        if current == .manual || incoming == .manual { return .manual }
        if current == .authorization || incoming == .authorization { return .authorization }
        if current == .foreground || incoming == .foreground { return .foreground }
        switch (current, incoming) {
        case (.observer(let lhs), .observer(let rhs)):
            return .observer(lhs.union(rhs))
        case (.outbox(let lhs), .outbox(let rhs)):
            return .outbox(lhs.union(rhs))
        case (.observer(let lhs), .outbox(let rhs)), (.outbox(let rhs), .observer(let lhs)):
            return .observer(lhs.union(rhs))
        case (.historyBackfill(let lhs, let range), .historyBackfill(let rhs, _)):
            return .historyBackfill(lhs.union(rhs), range)
        default:
            return incoming
        }
    }
}

private final class HealthObserverCompletion: @unchecked Sendable {
    private let completion: () -> Void

    init(_ completion: @escaping () -> Void) {
        self.completion = completion
    }

    func call() {
        completion()
    }
}

public final class HealthObserverCoordinator: @unchecked Sendable {
    private let gateway: any HealthKitGatewayProtocol
    private let lock = NSLock()
    private var coordinator: HealthSyncCoordinator?
    private var dirtyMetrics = Set<HealthMetric>()
    private var installed = false

    public init(gateway: any HealthKitGatewayProtocol) {
        self.gateway = gateway
    }

    public func installObservers() {
        let shouldInstall = lock.withLock {
            guard installed == false else { return false }
            installed = true
            return true
        }
        guard shouldInstall else { return }

        for metric in HealthKitTypeCatalog.readableMetrics {
            gateway.installObserver(metric: metric) { [weak self] completion in
                let completionBox = HealthObserverCompletion(completion)
                guard let self else {
                    completionBox.call()
                    return
                }
                Task {
                    await self.handle(metric: metric)
                    completionBox.call()
                }
            }
        }
    }

    public func attach(coordinator: HealthSyncCoordinator) {
        let buffered = lock.withLock {
            self.coordinator = coordinator
            let result = dirtyMetrics
            dirtyMetrics.removeAll()
            return result
        }
        guard buffered.isEmpty == false else { return }
        Task {
            _ = await coordinator.sync(.observer(buffered))
        }
    }

    private func handle(metric: HealthMetric) async {
        let coordinator = lock.withLock {
            let result = self.coordinator
            if result == nil {
                dirtyMetrics.insert(metric)
            }
            return result
        }
        guard let coordinator else { return }
        _ = await coordinator.sync(.observer([metric]))
    }
}
