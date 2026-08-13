import Foundation
import HealthKit
import Observation
import SwiftUI

// MARK: - Kinds

/// Every system permission LifeBoard can ask for, in one vocabulary.
///
/// Health already had a well-behaved just-in-time path; the other five were
/// requested ad-hoc at their call sites with no priming, no memory of a refusal,
/// and no recovery route once iOS had recorded a denial. This enum is the seam
/// that lets all six share the same "ask once, respect the answer" policy.
public enum PermissionKind: String, CaseIterable, Sendable, Identifiable {
    case notifications
    case calendar
    case appleHealth
    case microphone
    case speech
    case camera

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .notifications: "Turn on reminders"
        case .calendar: "Connect your calendar"
        case .appleHealth: "Connect Apple Health"
        case .microphone: "Microphone is off"
        case .speech: "Transcription is off"
        case .camera: "Camera is off"
        }
    }

    /// One line. What the user gets — not how the feature works.
    public var blurb: String {
        switch self {
        case .notifications: "A nudge when something is due."
        case .calendar: "See your real day, not a guess."
        case .appleHealth: "Sync what you log. Nothing leaves your device."
        case .microphone: "Needed to record an audio entry."
        case .speech: "Needed to turn recordings into text."
        case .camera: "Needed to scan a document or barcode."
        }
    }

    /// SF Symbol only — never an emoji (design contract).
    public var symbolName: String {
        switch self {
        case .notifications: "bell.badge"
        case .calendar: "calendar"
        case .appleHealth: "heart.text.square"
        case .microphone: "mic.slash"
        case .speech: "waveform"
        case .camera: "camera"
        }
    }

    public var allowTitle: String {
        switch self {
        case .appleHealth: "Connect"
        default: "Allow"
        }
    }

    /// True when iOS shows this permission's prompt at the moment the feature is
    /// first used. Those kinds are never primed ahead of time — priming them
    /// would mean two dialogs for one action — but they still get a recovery
    /// route once denied.
    public var isSystemPromptedAtPointOfUse: Bool {
        switch self {
        case .microphone, .speech, .camera: true
        case .notifications, .calendar, .appleHealth: false
        }
    }

    /// Whether the device and current build can service this at all.
    public var isSupportedOnThisDevice: Bool {
        switch self {
        case .appleHealth:
            return V2FeatureFlags.healthIntegrationsV1Enabled && HKHealthStore.isHealthDataAvailable()
        default:
            return true
        }
    }
}

// MARK: - Durable prompt state

/// Cross-launch memory of what we have already asked for, so an invitation
/// appears at most once until the user decides, respects a "Not now", and stops
/// offering after two refusals. Persisted in the App Group so the app, widgets,
/// and extensions agree.
///
/// This generalises the Health-only `HealthAuthorizationPromptState`; that type
/// now forwards here so there is exactly one source of truth, and the three
/// legacy Health keys are migrated in place on first read.
public enum PermissionPromptState {
    /// Two weeks — long enough not to nag, short enough to re-surface if the
    /// user keeps using the feature and simply was not ready the first time.
    public static let snoozeInterval: TimeInterval = 14 * 24 * 60 * 60
    public static let maxAutoOffers = 2

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
    }

    private static func key(_ kind: PermissionKind, _ suffix: String) -> String {
        "feature.life_os.permission.\(kind.rawValue).\(suffix)"
    }

    /// True once any path — onboarding, Settings, a hub, or a priming prompt —
    /// has actually invoked the system request, granted or denied. HealthKit
    /// hides read-denial, so for that kind this is our only durable signal.
    public static func hasRequested(_ kind: PermissionKind) -> Bool {
        migrateLegacyHealthKeysIfNeeded()
        return defaults.bool(forKey: key(kind, "has_requested"))
    }

    public static func snoozedUntil(_ kind: PermissionKind) -> Date? {
        migrateLegacyHealthKeysIfNeeded()
        return defaults.object(forKey: key(kind, "snoozed_until")) as? Date
    }

    public static func declineCount(_ kind: PermissionKind) -> Int {
        migrateLegacyHealthKeysIfNeeded()
        return defaults.integer(forKey: key(kind, "decline_count"))
    }

    /// Set when the user passed on this permission during onboarding. This is
    /// deliberately *not* a decline: it does not count against `maxAutoOffers`
    /// and sets no snooze, so the first genuine use of the feature may still
    /// offer once. Skipping a wall of permissions you have not seen the value of
    /// yet is not the same as refusing one in context.
    public static func wasDeferredInOnboarding(_ kind: PermissionKind) -> Bool {
        defaults.bool(forKey: key(kind, "onboarding_deferred"))
    }

    public static func shouldOffer(_ kind: PermissionKind, now: Date = Date()) -> Bool {
        guard kind.isSupportedOnThisDevice else { return false }
        guard kind.isSystemPromptedAtPointOfUse == false else { return false }
        guard hasRequested(kind) == false else { return false }
        guard declineCount(kind) < maxAutoOffers else { return false }
        if let snoozedUntil = snoozedUntil(kind), now < snoozedUntil { return false }
        return true
    }

    public static func recordRequested(_ kind: PermissionKind) {
        migrateLegacyHealthKeysIfNeeded()
        defaults.set(true, forKey: key(kind, "has_requested"))
        defaults.removeObject(forKey: key(kind, "snoozed_until"))
        defaults.removeObject(forKey: key(kind, "onboarding_deferred"))
    }

    public static func recordDecline(_ kind: PermissionKind, now: Date = Date()) {
        migrateLegacyHealthKeysIfNeeded()
        defaults.set(declineCount(kind) + 1, forKey: key(kind, "decline_count"))
        defaults.set(now.addingTimeInterval(snoozeInterval), forKey: key(kind, "snoozed_until"))
    }

    public static func recordOnboardingDeferral(_ kind: PermissionKind) {
        defaults.set(true, forKey: key(kind, "onboarding_deferred"))
    }

    /// Test hook — clears the persisted gate for one kind.
    public static func reset(_ kind: PermissionKind) {
        for suffix in ["has_requested", "snoozed_until", "decline_count", "onboarding_deferred"] {
            defaults.removeObject(forKey: key(kind, suffix))
        }
    }

    public static func resetAll() {
        PermissionKind.allCases.forEach(reset)
        defaults.removeObject(forKey: legacyMigrationKey)
    }

    // MARK: Legacy Health migration

    private static let legacyMigrationKey = "feature.life_os.permission.migrated_health_v1"

    /// Folds the three original `feature.life_os.health.jit.*` keys into the
    /// namespaced store exactly once, so an existing user who already connected
    /// Health — or already declined twice — is not asked again.
    public static func migrateLegacyHealthKeysIfNeeded() {
        let store = defaults
        guard store.bool(forKey: legacyMigrationKey) == false else { return }
        store.set(true, forKey: legacyMigrationKey)

        let legacyRequested = "feature.life_os.health.jit.has_requested"
        let legacySnoozed = "feature.life_os.health.jit.snoozed_until"
        let legacyDeclines = "feature.life_os.health.jit.decline_count"

        if store.bool(forKey: legacyRequested) {
            store.set(true, forKey: key(.appleHealth, "has_requested"))
        }
        if let snoozed = store.object(forKey: legacySnoozed) as? Date {
            store.set(snoozed, forKey: key(.appleHealth, "snoozed_until"))
        }
        let declines = store.integer(forKey: legacyDeclines)
        if declines > 0 {
            store.set(declines, forKey: key(.appleHealth, "decline_count"))
        }
    }
}

// MARK: - Pending prompt

/// One pending invitation. `leadHealthDomain` is the health feature the user
/// just touched, so Apple Health priming can name the right thing; `trigger` is
/// an analytics-friendly source id.
public struct PermissionPrompt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: PermissionKind
    public let trigger: String
    public let leadHealthDomain: HealthDomain?

    public init(
        id: UUID = UUID(),
        kind: PermissionKind,
        trigger: String,
        leadHealthDomain: HealthDomain? = nil
    ) {
        self.id = id
        self.kind = kind
        self.trigger = trigger
        self.leadHealthDomain = leadHealthDomain
    }
}

// MARK: - Coordinator

/// Presents a single contextual priming prompt when someone uses a feature whose
/// permission they have not granted. It never blocks the underlying action —
/// callers save locally first and only then offer.
///
/// One `pendingPrompt` for all six kinds is the point: logging water and
/// creating a reminder in the same breath must not stack two sheets.
@MainActor
@Observable
public final class PermissionPrimingCoordinator {
    public static let shared = PermissionPrimingCoordinator()

    public private(set) var pendingPrompt: PermissionPrompt?

    private var connectHealth: (@MainActor (Set<HealthDomain>) async -> Void)?
    private var requestNotifications: (@MainActor () async -> Void)?
    private var requestCalendar: (@MainActor () -> Void)?

    init() {}

    /// Wired once at launch so the coordinator can run the real request without
    /// taking a dependency on any of the concrete services.
    public func configure(
        connectHealth: @escaping @MainActor (Set<HealthDomain>) async -> Void,
        requestNotifications: @escaping @MainActor () async -> Void,
        requestCalendar: @escaping @MainActor () -> Void
    ) {
        self.connectHealth = connectHealth
        self.requestNotifications = requestNotifications
        self.requestCalendar = requestCalendar
    }

    /// Offer for the feature the user just used, if — and only if — the kind is
    /// supported, we have never asked, they have not snoozed us, they have not
    /// already refused twice, and nothing is already showing. Safe to call on
    /// every interaction.
    public func offerIfNeeded(
        kind: PermissionKind,
        trigger: String,
        leadHealthDomain: HealthDomain? = nil
    ) {
        guard pendingPrompt == nil,
              PermissionPromptState.shouldOffer(kind) else { return }
        pendingPrompt = PermissionPrompt(
            kind: kind,
            trigger: trigger,
            leadHealthDomain: leadHealthDomain
        )
    }

    /// Reward-first variant: waits for the feature's own confirmation animation
    /// to settle before offering, so the action always feels instant and the
    /// invitation reads as a gentle follow-on rather than an interruption.
    public func offerAfterReward(
        kind: PermissionKind,
        trigger: String,
        leadHealthDomain: HealthDomain? = nil
    ) async {
        try? await Task.sleep(nanoseconds: 450_000_000)
        offerIfNeeded(kind: kind, trigger: trigger, leadHealthDomain: leadHealthDomain)
    }

    /// The prompt's primary action. Clears the prompt and runs the real request,
    /// which shows the system dialog and marks us as having asked.
    public func grant(healthDomains: Set<HealthDomain> = []) async {
        guard let prompt = pendingPrompt else { return }
        pendingPrompt = nil
        await performRequest(kind: prompt.kind, healthDomains: healthDomains)
    }

    /// Runs a request outside the prompt flow — the onboarding permissions step
    /// and Settings rows both use this so every path records state identically.
    public func performRequest(
        kind: PermissionKind,
        healthDomains: Set<HealthDomain> = []
    ) async {
        switch kind {
        case .appleHealth:
            // `HealthConnectionStore.connect` records the request itself so the
            // flag is set before the system sheet can be dismissed.
            await connectHealth?(healthDomains)
        case .notifications:
            PermissionPromptState.recordRequested(kind)
            await requestNotifications?()
        case .calendar:
            PermissionPromptState.recordRequested(kind)
            requestCalendar?()
        case .microphone, .speech, .camera:
            // Requested by the capture surface at the point of use.
            PermissionPromptState.recordRequested(kind)
        }
    }

    /// "Not now" or swipe-dismiss — snooze and count the refusal, but only if a
    /// prompt is actually showing, so the explicit button and the interactive
    /// dismiss binding cannot double-count.
    public func decline() {
        guard let prompt = pendingPrompt else { return }
        pendingPrompt = nil
        PermissionPromptState.recordDecline(prompt.kind)
    }
}
