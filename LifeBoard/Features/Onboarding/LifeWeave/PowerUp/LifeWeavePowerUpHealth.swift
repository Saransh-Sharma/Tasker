import Foundation
import Observation

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
    @ObservationIgnored private var handoffTask: Task<Void, Never>?

    /// Called when the screen appears, so a second pass through onboarding (or a
    /// step revisited by the back affordance) never inherits a stale spinner.
    func resetForVisit() {
        firstSyncGraceTask?.cancel()
        firstSyncGraceTask = nil
        handoffTask?.cancel()
        handoffTask = nil
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

    /// The handoff belongs to the onboarding state owner rather than the view.
    /// SwiftUI may recreate the Health screen while HealthKit is importing; a
    /// view-scoped task would then be cancelled and could leave Continue
    /// disabled forever.
    func beginHandoffDeadline(after duration: Duration = .seconds(8)) {
        isHandoffOffered = false
        handoffTask?.cancel()
        handoffTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard Task.isCancelled == false else { return }
            self?.isHandoffOffered = true
            self?.handoffTask = nil
        }
    }

    func cancelHandoffDeadline() {
        handoffTask?.cancel()
        handoffTask = nil
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
        HealthCoordinator.shared.connectionStore.presentation
    }

    // MARK: - Dock seam

    var healthPrimaryTitle: String {
        switch healthFirstSyncOutcome {
        // Never a dead button: with no HealthKit there is nothing to review, so
        // the primary is simply the way onward.
        case .unavailable: "Continue"
        case .notRequested: "Connect Apple Health"
        case .authorizationFailed: "Retry Health access"
        case .requesting: "Waiting for Apple Health"
        case .syncing: "Continue while syncing"
        case .ready, .reviewedNoDataYet, .partial, .protectedDataLocked: "Continue"
        }
    }

    var healthSecondaryTitle: String? {
        switch healthFirstSyncOutcome {
        case .notRequested, .authorizationFailed: "Not now"
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
        case .syncing: false
        case .unavailable, .notRequested, .authorizationFailed, .ready, .reviewedNoDataYet,
             .partial, .protectedDataLocked:
            false
        }
    }

    func performHealthPrimary() async {
        switch healthFirstSyncOutcome {
        case .notRequested, .authorizationFailed:
            await requestHealthReadAccess()
        case .requesting:
            // Disabled in the dock; guarded here too, because a stale tap must
            // never present a second system sheet.
            break
        case .syncing:
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

        // Nothing is written to the draft on purpose. `grantedPermissionIDs`
        // would be a claim that read access was granted, and HealthKit never
        // tells us that; `healthWriteBackDomainIDs` would be a claim the user
        // opted into writing, which this screen deliberately never asks. The
        // durable record of "we asked" already lives in
        // `HealthAuthorizationPromptState`, set by the store before the sheet.
    }
}
