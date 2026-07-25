import CoreData
import Foundation
import HealthKit
import Observation

@MainActor
public final class LifeBoardHealthRuntime {
    public static let shared = LifeBoardHealthRuntime()

    public let gateway: HealthKitGateway
    public let observers: HealthObserverCoordinator
    public let connectionStore: HealthConnectionStore

    /// Owns the "should we offer to connect right now?" decision and the single
    /// in-flight priming prompt, so any health feature can invite a not-yet-
    /// connected user without stacking sheets. See `HealthJustInTimeCoordinator`.
    public let jitCoordinator: HealthJustInTimeCoordinator

    private let state = State()

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var engine: HealthSyncEngine?
        var ledger: (any HealthSyncLedgerStore)?
    }

    private init() {
        let gateway = HealthKitGateway()
        self.gateway = gateway
        observers = HealthObserverCoordinator(gateway: gateway)
        let store = HealthConnectionStore(
            gateway: gateway,
            engineProvider: { [state] in state.lock.withLock { state.engine } },
            ledgerProvider: { [state] in state.lock.withLock { state.ledger } }
        )
        connectionStore = store
        jitCoordinator = HealthJustInTimeCoordinator(connectionStore: store)
    }

    /// Called before persistent-store bootstrap so observer wakes are buffered.
    public func prepareForLaunch() {
        guard V2FeatureFlags.healthIntegrationsV1Enabled else { return }
        observers.installObservers()
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
            observers.attach(engine: engine)
            await connectionStore.refreshAuthorization()
        }
    }
}

// MARK: - Just-in-time connect

/// One pending "Connect Apple Health" invitation. `leadDomain` is the feature the
/// user just touched (so the priming can be contextual); `trigger` is an
/// analytics-friendly source id.
public struct HealthConnectPrompt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let leadDomain: HealthDomain
    public let trigger: String

    public init(id: UUID = UUID(), leadDomain: HealthDomain, trigger: String) {
        self.id = id
        self.leadDomain = leadDomain
        self.trigger = trigger
    }
}

/// Cross-launch memory of whether we've already asked for Health access, so the
/// just-in-time invitation appears at most once until the user decides, respects
/// a "Not now", and stops offering after two declines. Persisted in the App Group
/// so the app, widgets, and extensions agree.
public enum HealthAuthorizationPromptState {
    /// Two weeks — long enough not to nag, short enough to re-surface if the user
    /// keeps using health features and simply wasn't ready the first time.
    public static let snoozeInterval: TimeInterval = 14 * 24 * 60 * 60
    public static let maxAutoOffers = 2

    private enum Key {
        static let hasRequested = "feature.life_os.health.jit.has_requested"
        static let snoozedUntil = "feature.life_os.health.jit.snoozed_until"
        static let declineCount = "feature.life_os.health.jit.decline_count"
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
    }

    /// True once any connect path (onboarding, Settings, hub, or a JIT prompt) has
    /// invoked `requestAuthorization` — success or denial. HealthKit hides
    /// read-denial, so this flag is our only durable "we already asked" signal.
    public static var hasRequested: Bool {
        get { defaults.bool(forKey: Key.hasRequested) }
        set { defaults.set(newValue, forKey: Key.hasRequested) }
    }

    public static var snoozedUntil: Date? {
        get { defaults.object(forKey: Key.snoozedUntil) as? Date }
        set { defaults.set(newValue, forKey: Key.snoozedUntil) }
    }

    public static var declineCount: Int {
        get { defaults.integer(forKey: Key.declineCount) }
        set { defaults.set(newValue, forKey: Key.declineCount) }
    }

    public static func shouldOffer(now: Date = Date()) -> Bool {
        guard hasRequested == false else { return false }
        guard declineCount < maxAutoOffers else { return false }
        if let snoozedUntil, now < snoozedUntil { return false }
        return true
    }

    public static func recordRequested() {
        hasRequested = true
        snoozedUntil = nil
    }

    public static func recordDecline(now: Date = Date()) {
        declineCount += 1
        snoozedUntil = now.addingTimeInterval(snoozeInterval)
    }

    /// Test hook — clears the persisted gate.
    public static func reset() {
        defaults.removeObject(forKey: Key.hasRequested)
        defaults.removeObject(forKey: Key.snoozedUntil)
        defaults.removeObject(forKey: Key.declineCount)
    }
}

/// Presents a single, contextual "Connect Apple Health" priming prompt when a
/// not-yet-connected user uses a health feature. It never blocks the underlying
/// action — callers save locally first and only then offer to connect.
@MainActor
@Observable
public final class HealthJustInTimeCoordinator {
    public private(set) var pendingPrompt: HealthConnectPrompt?

    private let connectionStore: HealthConnectionStore

    init(connectionStore: HealthConnectionStore) {
        self.connectionStore = connectionStore
    }

    /// Offer to connect for the feature the user just used, if — and only if —
    /// Health is available, the feature is enabled, we have never asked, the user
    /// hasn't snoozed us, they haven't already declined twice, and nothing is
    /// already showing. Safe to call on every health interaction.
    public func offerConnectIfNeeded(leadDomain: HealthDomain, trigger: String) {
        guard V2FeatureFlags.healthIntegrationsV1Enabled,
              HKHealthStore.isHealthDataAvailable(),
              pendingPrompt == nil,
              HealthAuthorizationPromptState.shouldOffer() else { return }
        pendingPrompt = HealthConnectPrompt(leadDomain: leadDomain, trigger: trigger)
    }

    /// Reward-first variant: waits for the feature's own confirmation animation
    /// to settle (~450 ms) before offering, so logging always feels instant and
    /// the invitation is a gentle follow-on rather than an interruption.
    public func offerConnectAfterReward(leadDomain: HealthDomain, trigger: String) async {
        try? await Task.sleep(nanoseconds: 450_000_000)
        offerConnectIfNeeded(leadDomain: leadDomain, trigger: trigger)
    }

    /// The prompt's primary action. Clears the prompt and runs the real connect
    /// flow (which shows the system sheet and marks us as having asked).
    public func connect(domains: Set<HealthDomain>) async {
        pendingPrompt = nil
        await connectionStore.connect(domains: domains)
    }

    /// "Not now" / swipe-dismiss — snooze and count the decline, but only if a
    /// prompt is actually showing. Idempotent so the explicit button *and* the
    /// interactive-dismiss binding can both call it without double-counting.
    public func decline() {
        guard pendingPrompt != nil else { return }
        pendingPrompt = nil
        HealthAuthorizationPromptState.recordDecline()
    }
}
