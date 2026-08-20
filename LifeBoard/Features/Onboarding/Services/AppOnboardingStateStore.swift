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
    }

    func storeRefreshDraft(_ snapshot: LifeWeaveDraft?) {
        var state = load()
        state.refreshDraft = snapshot
        save(state)
    }

    func finalizeLifeWeave(
        entryContext: OnboardingEntryContext,
        destination: LifeWeaveCompletionDestination
    ) {
        var state = load()
        if entryContext == .establishedWorkspace {
            state.completedRefreshVersion = AppOnboardingState.currentLifeWeaveRefreshVersion
            state.refreshDraft = nil
        } else {
            SetupCenterHomeCardPreference.resetForNewOnboarding()
            state.outcome = .completed
            state.completedVersion = AppOnboardingState.currentVersion
            state.completedLifeWeave = true
            state.completedRefreshVersion = AppOnboardingState.currentLifeWeaveRefreshVersion
            state.lifeWeaveJourneySnapshot = nil
        }
        state.journeySnapshot = nil
        state.lifeMapJourneySnapshot = nil
        state.finalizedLifeWeaveDestination = destination
        state.needsFinalizedDestinationDelivery = true
        save(state)
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
