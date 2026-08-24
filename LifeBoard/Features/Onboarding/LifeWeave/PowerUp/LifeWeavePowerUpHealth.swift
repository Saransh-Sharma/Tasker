import Foundation
import Observation

/// What LifeBoard can honestly say about Apple Health during the first run.
///
/// HealthKit deliberately never reveals per-type *read* denial. Once the system
/// sheet returns, all we know is that it was presented — never that reading was
/// granted, and never that it was refused. So no case here means "connected" or
/// "denied"; every one of them describes what LifeBoard has actually observed.
///
/// `.reviewedNoDataYet` is therefore a correct, finished state rather than a
/// failure: a person can review the sheet on a phone that simply has no recent
/// Health data, and telling them "connected" would be a claim we cannot support.
enum HealthFirstSyncOutcome: Equatable {
    /// HealthKit is not present on this device (or the integration is off).
    case unavailable
    /// The sheet has never been presented and nothing has ever been observed.
    case notRequested
    /// The system sheet is up, or the authorization call is still in flight.
    case requesting
    /// The sheet returned and the first import is running.
    case syncing
    /// Data was genuinely observed. Counts only — never values.
    case ready(metricCount: Int, lastSync: Date?)
    /// Reviewed, finished, and nothing readable came back. Not a failure.
    case reviewedNoDataYet
    /// Something in the import did not complete. The code is non-sensitive.
    case partial(errorCode: String?)
    /// The device locked mid-import, so reads were blocked by the system.
    case protectedDataLocked
}

/// The pure resolver behind the Health power-up screen.
///
/// Deliberately a free function over plain values rather than a method on the
/// store: every interesting case here (locked device, partial import, reviewed
/// but empty) is impossible to stage in a simulator, and a resolver that reads
/// `HealthConnectionStore` directly could only be tested by running HealthKit.
enum LifeWeaveHealthFirstSync {

    /// Non-sensitive codes that mean the import itself did not complete.
    ///
    /// Deliberately a small allow-list rather than "any non-nil code". The store
    /// also reports write-preference problems (`preference_write`), which cannot
    /// be caused by this screen — onboarding never writes — and reporting one as
    /// a read problem would send people to fix something that is not broken.
    static let syncBlockingErrorCodes: Set<String> = [
        "authorization_request",
        "sync_partial",
        "sync_failed",
        "local_migration"
    ]

    /// - Parameter isAuthorizationInFlight: The one fact the store cannot
    ///   report. `HealthConnectionStore` records nothing between the moment the
    ///   system sheet is presented and the moment it returns, so "the sheet is
    ///   up" has to be supplied by the caller that presented it. Defaults to
    ///   `false` so the six store-derived inputs alone resolve a settled state.
    static func resolve(
        statuses: [HealthDomain: HealthDomainStatus],
        aggregates: [HealthMetric: HealthAggregateValue],
        isRefreshing: Bool,
        lastSuccessfulSync: Date?,
        nonSensitiveErrorCode: String?,
        isAvailable: Bool,
        isAuthorizationInFlight: Bool = false
    ) -> HealthFirstSyncOutcome {
        guard isAvailable else { return .unavailable }
        if isAuthorizationInFlight { return .requesting }

        let observedMetricCount = aggregates.count
        let hasReviewed = statuses.values.contains(where: { $0.readRequestState != .neverRequested })
        // `receivingData` counts as observation for deciding whether anything has
        // happened at all — but see below for why it cannot, on its own, carry a
        // readiness claim.
        let hasObservedSomething = observedMetricCount > 0
            || statuses.values.contains(where: { $0.readRequestState == .receivingData })

        if hasReviewed == false && hasObservedSomething == false { return .notRequested }

        if isRefreshing { return .syncing }

        // A locked device outranks every settled state. It is a temporary block
        // on reading, not an answer about whether data exists, and "unlock and
        // come back" is the one useful thing a person can do about it — which is
        // exactly why it must never collapse into `.reviewedNoDataYet`.
        if statuses.values.contains(where: { $0.signal == .protectedDataLocked }) {
            return .protectedDataLocked
        }

        if let code = nonSensitiveErrorCode, syncBlockingErrorCodes.contains(code) {
            return .partial(errorCode: code)
        }

        // Readiness needs at least one observed aggregate. `receivingData` is
        // necessary but not sufficient: `HealthConnectionStore.runSync` sets it
        // whenever a sync completed without being skipped, including a sync that
        // came back with nothing — so treating it as proof would put "Health is
        // ready" on a screen that has observed no health data at all, which is
        // the exact false positive this whole screen exists to avoid.
        if observedMetricCount > 0 {
            return .ready(metricCount: observedMetricCount, lastSync: lastSuccessfulSync)
        }

        // Deliberately *not* derived from `lastSuccessfulSync`. A completed sync
        // that read nothing still stamps a date, so a date alone proves only that
        // we asked — never that anything came back.
        return .reviewedNoDataYet
    }

    /// How many benefit areas actually produced something, for the receipt.
    /// Counts, never values: no health number is shown during onboarding.
    static func observedDomainCount(aggregates: [HealthMetric: HealthAggregateValue]) -> Int {
        Set(aggregates.keys.map(\.domain)).count
    }

    /// One settled summary for VoiceOver, posted once when the screen resolves.
    ///
    /// Returns `nil` while the outcome is still moving. Announcing each metric as
    /// it arrived turned a background import into a stream of interruptions, and
    /// the individual arrivals are not decisions anyone can act on.
    static func settledAnnouncement(for outcome: HealthFirstSyncOutcome) -> String? {
        switch outcome {
        case .ready(let metricCount, _):
            "Health sync complete. \(metricCount) metric\(metricCount == 1 ? "" : "s") available."
        case .reviewedNoDataYet:
            "Health access was reviewed. No readable Health data yet."
        case .partial:
            "Health access was reviewed. Some Health data could not be read."
        case .protectedDataLocked:
            "Health sync paused because this iPhone is locked."
        case .unavailable:
            "Apple Health isn't available on this device."
        case .notRequested, .requesting, .syncing:
            nil
        }
    }
}

/// The three reasons a person might want this, and the exact types behind each.
///
/// Grouped by benefit rather than by domain. The retired screen listed every
/// read and write category flat, which asked people to understand LifeBoard's
/// data model before they had seen a single reason to care — and the exact list
/// is still one tap away, for the people for whom that list *is* the reason.
struct HealthBenefitGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let promise: String
    let symbolName: String
    let domains: [HealthDomain]

    /// The concrete Apple Health types behind the promise, in the same order the
    /// domains are listed. `fasting` contributes nothing here because it has no
    /// HealthKit type — it is inferred locally and never read from Health.
    var readTypeNames: [String] {
        domains.flatMap(\.metrics).map { LifeWeaveHealthCopy.typeName(for: $0) }
    }
}

/// Copy owned by this screen. Kept beside the resolver so the words and the
/// states they describe are reviewed together.
enum LifeWeaveHealthCopy {

    static let benefitGroups: [HealthBenefitGroup] = [
        HealthBenefitGroup(
            id: "activity",
            title: "Activity and workouts",
            promise: "Effort you already record shows up beside your plan, so a heavy day looks heavy.",
            symbolName: "figure.walk.motion",
            domains: [.activity, .energy, .workouts]
        ),
        HealthBenefitGroup(
            id: "sleep",
            title: "Sleep and recovery",
            promise: "Last night sits next to today, so a short night can change what you take on.",
            symbolName: "bed.double",
            domains: [.sleep]
        ),
        HealthBenefitGroup(
            id: "body",
            title: "Body, nutrition, and hydration",
            promise: "What you already log stays in one place instead of being kept twice.",
            symbolName: "fork.knife",
            domains: [.body, .nutrition, .hydration]
        )
    ]

    static let privacyLine =
        "Health data is processed on this device. EVA does not use Health unless you allow that separately."

    /// Mirrors the labels used by the Health detail screens, so the same type is
    /// never called two different things in two places.
    static func typeName(for metric: HealthMetric) -> String {
        switch metric {
        case .steps: "Steps"
        case .walkingRunningDistance: "Walking distance"
        case .activeEnergy: "Active energy"
        case .restingEnergy: "Resting energy"
        case .water: "Hydration"
        case .dietaryEnergy: "Dietary energy"
        case .dietaryProtein: "Protein"
        case .dietaryCarbohydrates: "Carbohydrates"
        case .dietaryFat: "Fat"
        case .bodyMass: "Weight"
        case .bodyFatPercentage: "Body fat"
        case .waistCircumference: "Waist"
        case .restingHeartRate: "Resting heart rate"
        case .workout: "Workouts"
        case .sleep: "Sleep"
        }
    }
}

/// The transient facts about this screen that no service owns.
///
/// Every one of them describes the *presentation*, not Health: whether the
/// system sheet is up, whether the import we just asked for has had a chance to
/// start, and whether the person has waited long enough to be offered a way
/// past it. None belongs in `LifeWeaveDraft` — they must not survive a relaunch —
/// and none belongs in `HealthConnectionStore`, which is shared with Settings
/// and the Health hub and knows nothing about onboarding.
///
/// Shared rather than view-local because the bottom dock is rendered by the
/// flow shell, not by this screen, and the two have to agree about what the
/// primary button says.
@MainActor
@Observable
final class LifeWeaveHealthPowerUpState {
    static let shared = LifeWeaveHealthPowerUpState()

    /// The system sheet is up (or the authorization call has not returned).
    var isAuthorizationInFlight = false

    /// The sheet returned and the import has been asked for, but the store's
    /// managed task may not have flipped `isRefreshing` yet. Without this, the
    /// screen shows the settled "no readable data yet" line for a frame or two
    /// before the sync it just started begins — the one sentence on this screen
    /// that must never appear before we have actually looked.
    var isFirstSyncExpected = false

    /// The eight-second handoff: the import is allowed to keep running while the
    /// person moves on.
    var isHandoffOffered = false

    /// The last summary posted to VoiceOver, so one settled announcement is not
    /// repeated on every re-render.
    var lastAnnouncedSummary: String?

    @ObservationIgnored private var firstSyncGraceTask: Task<Void, Never>?

    /// Called when the screen appears, so a second pass through onboarding (or a
    /// step revisited by the back affordance) never inherits a stale spinner.
    func resetForVisit() {
        firstSyncGraceTask?.cancel()
        firstSyncGraceTask = nil
        isAuthorizationInFlight = false
        isFirstSyncExpected = false
        isHandoffOffered = false
        lastAnnouncedSummary = nil
    }

    /// Bridges the gap between `connectReadOnly` returning and the store's own
    /// sync task starting. One sleep, not a poll: if the sync starts inside the
    /// window the real `isRefreshing` takes over, and if it never starts the flag
    /// clears itself instead of stranding the screen on a spinner.
    func beginExpectingFirstSync() {
        isFirstSyncExpected = true
        firstSyncGraceTask?.cancel()
        firstSyncGraceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard Task.isCancelled == false else { return }
            self?.isFirstSyncExpected = false
        }
    }
}

/// Health power-up behaviour, as an extension on the one journey model.
///
/// A separate file rather than a separate model: the journey has one owner, and
/// splitting by connector here is only so three people can work at once without
/// editing the same 400 lines. Canonical Health truth stays in its own service —
/// this file reads `HealthConnectionStore` and never re-derives, caches, or
/// second-guesses it, and it never touches HealthKit.
@MainActor
extension LifeWeaveOnboardingModel {

    /// The single state this screen and the shared dock both render from.
    var healthFirstSyncOutcome: HealthFirstSyncOutcome {
        let store = HealthCoordinator.shared.connectionStore
        let state = LifeWeaveHealthPowerUpState.shared
        return LifeWeaveHealthFirstSync.resolve(
            statuses: store.statuses,
            aggregates: store.aggregates,
            isRefreshing: store.isRefreshing || state.isFirstSyncExpected,
            lastSuccessfulSync: store.lastSuccessfulSync,
            nonSensitiveErrorCode: store.nonSensitiveErrorCode,
            // Covers both "this device has no HealthKit" and "the integration is
            // switched off", which are the same thing to the person reading it.
            isAvailable: PermissionKind.appleHealth.isSupportedOnThisDevice,
            isAuthorizationInFlight: state.isAuthorizationInFlight
        )
    }

    // MARK: - Dock seam

    var healthPrimaryTitle: String {
        switch healthFirstSyncOutcome {
        // Never a dead button: with no HealthKit there is nothing to review, so
        // the primary is simply the way onward.
        case .unavailable: "Continue"
        case .notRequested: "Review Health access"
        case .requesting: "Waiting for Apple Health"
        case .syncing:
            LifeWeaveHealthPowerUpState.shared.isHandoffOffered
                ? "Continue while syncing"
                : "Reading your Health data"
        case .ready, .reviewedNoDataYet, .partial, .protectedDataLocked: "Continue"
        }
    }

    var healthSecondaryTitle: String? {
        switch healthFirstSyncOutcome {
        case .notRequested: "Not now"
        // Once the sheet has been reviewed there is nothing left to decline.
        // Offering "Not now" afterwards would imply this screen can undo a system
        // permission, which it cannot — that lives in the Health app.
        case .unavailable, .requesting, .syncing, .ready, .reviewedNoDataYet,
             .partial, .protectedDataLocked:
            nil
        }
    }

    var isHealthPrimaryDisabled: Bool {
        switch healthFirstSyncOutcome {
        // The sheet owns the screen; a second tap behind it would stack requests.
        case .requesting: true
        case .syncing: LifeWeaveHealthPowerUpState.shared.isHandoffOffered == false
        case .unavailable, .notRequested, .ready, .reviewedNoDataYet,
             .partial, .protectedDataLocked:
            false
        }
    }

    func performHealthPrimary() async {
        switch healthFirstSyncOutcome {
        case .notRequested:
            await requestHealthReadAccess()
        case .requesting:
            // Disabled in the dock; guarded here too, because a stale tap must
            // never present a second system sheet.
            break
        case .syncing:
            guard LifeWeaveHealthPowerUpState.shared.isHandoffOffered else { return }
            // The import keeps running under the store's own managed task. It is
            // not tied to this screen's lifetime, so leaving does not cancel it.
            advancePowerUp()
        case .ready:
            feedback.successSignature()
            advancePowerUp()
        case .unavailable, .reviewedNoDataYet, .partial, .protectedDataLocked:
            advancePowerUp()
        }
    }

    func performHealthSecondary() {
        deferCurrentPowerUp()
    }

    // MARK: - Internals

    private func requestHealthReadAccess() async {
        let state = LifeWeaveHealthPowerUpState.shared
        guard state.isAuthorizationInFlight == false else { return }
        state.isAuthorizationInFlight = true
        feedback.light()

        // Read-only, and read-only is a real request rather than a flag: the
        // second argument is `enableWriteBack`, and the coordinator routes
        // `false` to `HealthConnectionStore.connectReadOnly`, which hands Apple
        // an empty writable set. Write-back is a separate, later opt-in in Setup
        // Center, and asking for it here would contradict the primer.
        await powerUps.connectHealth(Set(HealthDomain.allCases), false)

        state.isAuthorizationInFlight = false
        state.beginExpectingFirstSync()

        // Nothing is written to the draft on purpose. `grantedPermissionIDs`
        // would be a claim that read access was granted, and HealthKit never
        // tells us that; `healthWriteBackDomainIDs` would be a claim the user
        // opted into writing, which this screen deliberately never asks. The
        // durable record of "we asked" already lives in
        // `HealthAuthorizationPromptState`, set by the store before the sheet.
    }
}
