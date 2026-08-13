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
        save(state)
    }

    func markEstablishedWorkspacePromptDismissed(version: Int = AppOnboardingState.currentVersion) {
        var state = load()
        state.establishedWorkspacePromptDismissedVersion = version
        save(state)
    }

    func storeJourney(_ snapshot: OnboardingJourneySnapshot?) {
        var state = load()
        state.journeySnapshot = snapshot
        save(state)
    }

    func clearJourney() {
        var state = load()
        state.journeySnapshot = nil
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
