import CoreData
import Foundation
import HealthKit
import Observation

@MainActor
public final class LifeBoardHealthRuntime {
    public static let shared = LifeBoardHealthRuntime()

    public let gateway: HealthKitGateway
    public let observers: HealthObserverCoordinator
    public let coordinator: HealthSyncCoordinator
    public let connectionStore: HealthConnectionStore

    /// Owns the "should we offer to connect right now?" decision and the single
    /// in-flight priming prompt, so any health feature can invite a not-yet-
    /// connected user without stacking sheets. See `HealthJustInTimeCoordinator`.
    public let jitCoordinator: HealthJustInTimeCoordinator

    private let state = State()
    private var outboxObserver: NSObjectProtocol?
    private var pendingOutboxMetrics = Set<HealthMetric>()
    private var outboxFlushTask: Task<Void, Never>?

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var engine: HealthSyncEngine?
        var ledger: (any HealthSyncLedgerStore)?
    }

    private init() {
        let gateway = HealthKitGateway()
        self.gateway = gateway
        let coordinator = HealthSyncCoordinator(
            gateway: gateway,
            engineProvider: { [state] in state.lock.withLock { state.engine } },
            ledgerProvider: { [state] in state.lock.withLock { state.ledger } }
        )
        self.coordinator = coordinator
        observers = HealthObserverCoordinator(gateway: gateway)
        let store = HealthConnectionStore(
            gateway: gateway,
            engineProvider: { [state] in state.lock.withLock { state.engine } },
            ledgerProvider: { [state] in state.lock.withLock { state.ledger } },
            coordinator: coordinator
        )
        connectionStore = store
        jitCoordinator = HealthJustInTimeCoordinator(connectionStore: store)
    }

    /// Called before persistent-store bootstrap so observer wakes are buffered.
    public func prepareForLaunch() {
        guard V2FeatureFlags.healthIntegrationsV1Enabled else { return }
        observers.installObservers()
        Task { await coordinator.prepareForLaunch() }
    }

    /// Attaches the local ledger only after both persistent stores are ready.
    public func attach(container: NSPersistentContainer) {
        guard V2FeatureFlags.healthIntegrationsV1Enabled else { return }
        Task {
            let migration = HealthPrivacyMigrationCoordinator(container: container)
            guard (try? await migration.migrate()) == .validated else {
                connectionStore.markMigrationUnavailable()
                return
            }
            _ = try? await migration.purgeLegacyCloudRowsIfEligible()
            let ledger = CoreDataHealthSyncLedger(container: container)
            let projections = CoreDataHealthProjectionRepository(container: container)
            let engine = HealthSyncEngine(
                gateway: gateway,
                ledger: ledger,
                projections: projections,
                surfaceRefresh: {
                    await LifeBoardSystemSurfaceRefresher.requestRefresh()
                }
            )
            state.lock.withLock {
                state.ledger = ledger
                state.engine = engine
            }
            observers.attach(coordinator: coordinator)
            observeOutboxCommits(in: container)
            await connectionStore.bootstrap()
            await connectionStore.syncIfNeededOnForeground()
        }
    }

    public func applicationDidBecomeActive() {
        guard V2FeatureFlags.healthIntegrationsV1Enabled else { return }
        Task { await connectionStore.syncIfNeededOnForeground() }
    }

    private func observeOutboxCommits(in container: NSPersistentContainer) {
        guard outboxObserver == nil else { return }
        outboxObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { [weak self, weak container] notification in
            guard let self, let container,
                  let context = notification.object as? NSManagedObjectContext,
                  context.persistentStoreCoordinator === container.persistentStoreCoordinator,
                  context.transactionAuthor != "HealthKitSyncLedger",
                  context.transactionAuthor != "HealthKitImport" else {
                return
            }
            let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
            let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
            let metrics = inserted.union(updated).compactMap { object -> HealthMetric? in
                guard object.entity.name == "HealthSyncOperation",
                      let raw = object.value(forKey: "metricRaw") as? String else { return nil }
                return HealthMetric(rawValue: raw)
            }
            guard metrics.isEmpty == false else { return }
            Task { @MainActor in self.scheduleOutboxFlush(metrics: Set(metrics)) }
        }
    }

    private func scheduleOutboxFlush(metrics: Set<HealthMetric>) {
        pendingOutboxMetrics.formUnion(metrics)
        outboxFlushTask?.cancel()
        outboxFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard Task.isCancelled == false, let self else { return }
            let metrics = pendingOutboxMetrics
            pendingOutboxMetrics.removeAll()
            _ = await coordinator.sync(.outbox(metrics))
        }
    }
}

// MARK: - Just-in-time connect

/// Cross-launch memory of whether we've already asked for Health access.
///
/// The policy this once owned alone now lives in `LifeBoardPermissionPromptState`
/// and is shared by every permission LifeBoard asks for; this type remains as the
/// Health-shaped face of it so existing call sites and tests read naturally. The
/// three original `feature.life_os.health.jit.*` keys are migrated into the
/// namespaced store on first access, so a user who already connected — or already
/// declined twice — is never asked again.
public enum HealthAuthorizationPromptState {
    public static var snoozeInterval: TimeInterval { LifeBoardPermissionPromptState.snoozeInterval }
    public static var maxAutoOffers: Int { LifeBoardPermissionPromptState.maxAutoOffers }

    /// True once any connect path (onboarding, Settings, hub, or a JIT prompt) has
    /// invoked `requestAuthorization` — success or denial. HealthKit hides
    /// read-denial, so this flag is our only durable "we already asked" signal.
    public static var hasRequested: Bool {
        LifeBoardPermissionPromptState.hasRequested(.appleHealth)
    }

    public static var snoozedUntil: Date? {
        LifeBoardPermissionPromptState.snoozedUntil(.appleHealth)
    }

    public static var declineCount: Int {
        LifeBoardPermissionPromptState.declineCount(.appleHealth)
    }

    public static func shouldOffer(now: Date = Date()) -> Bool {
        LifeBoardPermissionPromptState.shouldOffer(.appleHealth, now: now)
    }

    public static func recordRequested() {
        LifeBoardPermissionPromptState.recordRequested(.appleHealth)
    }

    public static func recordDecline(now: Date = Date()) {
        LifeBoardPermissionPromptState.recordDecline(.appleHealth, now: now)
    }

    /// Test hook — clears the persisted gate.
    public static func reset() {
        LifeBoardPermissionPromptState.reset(.appleHealth)
    }
}

/// Offers a contextual "Connect Apple Health" invitation when a not-yet-connected
/// user touches a health feature. It never blocks the underlying action — callers
/// save locally first and only then offer to connect.
///
/// The prompt itself is owned by `LifeBoardPermissionPrimingCoordinator`, which
/// holds a single pending invitation across all permission kinds; logging water
/// and creating a reminder in the same breath must not stack two sheets.
@MainActor
public final class HealthJustInTimeCoordinator {
    private let connectionStore: HealthConnectionStore

    init(connectionStore: HealthConnectionStore) {
        self.connectionStore = connectionStore
    }

    /// Offer to connect for the feature the user just used, if — and only if —
    /// Health is available, the feature is enabled, we have never asked, the user
    /// hasn't snoozed us, they haven't already declined twice, and nothing is
    /// already showing. Safe to call on every health interaction.
    public func offerConnectIfNeeded(leadDomain: HealthDomain, trigger: String) {
        LifeBoardPermissionPrimingCoordinator.shared.offerIfNeeded(
            kind: .appleHealth,
            trigger: trigger,
            leadHealthDomain: leadDomain
        )
    }

    /// Reward-first variant: waits for the feature's own confirmation animation
    /// to settle (~450 ms) before offering, so logging always feels instant and
    /// the invitation is a gentle follow-on rather than an interruption.
    public func offerConnectAfterReward(leadDomain: HealthDomain, trigger: String) async {
        await LifeBoardPermissionPrimingCoordinator.shared.offerAfterReward(
            kind: .appleHealth,
            trigger: trigger,
            leadHealthDomain: leadDomain
        )
    }

    /// Runs the real connect flow, which shows the system sheet and marks us as
    /// having asked.
    public func connect(domains: Set<HealthDomain>) async {
        await connectionStore.connect(domains: domains)
    }

    public func decline() {
        LifeBoardPermissionPrimingCoordinator.shared.decline()
    }
}
