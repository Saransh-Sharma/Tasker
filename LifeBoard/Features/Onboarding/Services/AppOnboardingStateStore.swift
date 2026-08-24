import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

final class AppOnboardingStateStore: @unchecked Sendable {
    static let shared = AppOnboardingStateStore()

    let userDefaults: UserDefaults
    let key = "app_onboarding_state_v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AppOnboardingState {
        guard let data = userDefaults.data(forKey: key),
              let state = try? JSONDecoder().decode(AppOnboardingState.self, from: data) else {
            return AppOnboardingState()
        }
        return state
    }

    func markHandled(outcome: OnboardingOutcome, version: Int = AppOnboardingState.currentVersion) {
        var state = load()
        state.outcome = outcome
        state.completedVersion = version
        state.journeySnapshot = nil
        state.lifeMapJourneySnapshot = nil
        state.lifeWeaveJourneySnapshot = nil
        save(state)
    }

    func markEstablishedWorkspacePromptDismissed(version: Int = AppOnboardingState.currentVersion) {
        var state = load()
        state.establishedWorkspacePromptDismissedVersion = version
        state.dismissedRefreshVersion = AppOnboardingState.currentLifeWeaveRefreshVersion
        state.refreshDraft = nil
        save(state)
    }

    func markRefreshDismissed(version: Int = AppOnboardingState.currentLifeWeaveRefreshVersion) {
        var state = load()
        state.dismissedRefreshVersion = version
        state.refreshDraft = nil
        save(state)
        Task { await ProductTelemetry.shared.record(.refreshDeferred, flowVersion: version, audience: "existing") }
    }

    func storeRefreshDraft(_ snapshot: LifeWeaveDraft?) {
        var state = load()
        state.refreshDraft = snapshot
        save(state)
    }

    /// Core is complete and durable. The journey may still be running.
    ///
    /// Split out of `finalizeLifeWeave` because the optional Power-Up phase runs
    /// *after* the product's completion promise has already been kept. The
    /// promise is that a finished LifeBoard depends on no permission, account, or
    /// network — so completion has to be recorded before the first connector is
    /// offered, not after the last one resolves. A person who force-quits midway
    /// through Calendar has a finished LifeBoard, and must not be re-onboarded.
    ///
    /// Deliberately keeps the journey snapshot. Between this and
    /// `finalizeLifeWeave` a journey is legitimately both *completed* and
    /// *resumable*, which is what lets the launch path put someone back on the
    /// power-up step they left rather than on Home with the phase silently lost.
    ///
    /// Idempotent, including its telemetry: re-entering the reveal must not
    /// record a second core completion.
    @discardableResult
    func completeCore(entryContext: OnboardingEntryContext) -> Bool {
        var state = load()
        let wasAlreadyComplete = state.outcome == .completed
            && state.completedVersion == AppOnboardingState.currentVersion
            && state.completedLifeWeave == true

        if entryContext == .establishedWorkspace {
            state.completedRefreshVersion = AppOnboardingState.currentLifeWeaveRefreshVersion
        } else {
            SetupCenterHomeCardPreference.resetForNewOnboarding()
            state.outcome = .completed
            state.completedVersion = AppOnboardingState.currentVersion
            state.completedLifeWeave = true
            state.completedRefreshVersion = AppOnboardingState.currentLifeWeaveRefreshVersion
        }
        // The v5 payloads are cleared here rather than at finalization: the
        // canonical commit has already succeeded, so there is no v5 journey left
        // to resume even if the power-up phase is abandoned.
        state.journeySnapshot = nil
        state.lifeMapJourneySnapshot = nil
        save(state)

        guard entryContext != .establishedWorkspace, wasAlreadyComplete == false else { return false }
        Task {
            await ProductTelemetry.shared.record(
                .coreFinalized,
                flowVersion: AppOnboardingState.currentVersion,
                audience: "fresh"
            )
        }
        return true
    }

    /// The journey is over and the host may be dismissed.
    ///
    /// Distinct from `completeCore`: this is what clears the resumable snapshot
    /// and names where the user lands. Calling it without a prior `completeCore`
    /// still completes core, so the "Start now" exit straight off the reveal
    /// behaves exactly as it did before the power-up phase existed.
    func finalizeLifeWeave(
        entryContext: OnboardingEntryContext,
        destination: LifeWeaveCompletionDestination
    ) {
        completeCore(entryContext: entryContext)
        var state = load()
        if entryContext == .establishedWorkspace {
            state.refreshDraft = nil
        } else {
            state.lifeWeaveJourneySnapshot = nil
        }
        state.finalizedLifeWeaveDestination = destination
        state.needsFinalizedDestinationDelivery = true
        save(state)
        Task {
            await ProductTelemetry.shared.record(
                entryContext == .establishedWorkspace ? .refreshCompleted : .onboardingStepCompleted,
                flowVersion: AppOnboardingState.currentVersion,
                audience: entryContext == .establishedWorkspace ? "existing" : "fresh",
                outcome: destination.rawValue
            )
        }
    }

    func markFinalizedDestinationDelivered() {
        var state = load()
        state.needsFinalizedDestinationDelivery = false
        save(state)
    }

    func storeJourney(_ snapshot: OnboardingJourneySnapshot?) {
        var state = load()
        state.journeySnapshot = snapshot
        save(state)
    }

    func storeLifeMapJourney(_ snapshot: LifeMapDraft?) {
        var state = load()
        state.lifeMapJourneySnapshot = snapshot
        save(state)
    }

    func clearLifeMapJourney() {
        var state = load()
        state.lifeMapJourneySnapshot = nil
        save(state)
    }

    func markCompletedLifeWeave() {
        var state = load()
        state.completedLifeWeave = true
        save(state)
    }

    func storeLifeWeaveJourney(_ snapshot: LifeWeaveDraft?) {
        var state = load()
        state.lifeWeaveJourneySnapshot = snapshot
        save(state)
    }

    func clearLifeWeaveJourney() {
        var state = load()
        state.lifeWeaveJourneySnapshot = nil
        save(state)
    }

    func clearJourney() {
        var state = load()
        state.journeySnapshot = nil
        state.lifeMapJourneySnapshot = nil
        state.lifeWeaveJourneySnapshot = nil
        save(state)
    }

    func clear() {
        userDefaults.removeObject(forKey: key)
    }

    func save(_ state: AppOnboardingState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: key)
    }
}
