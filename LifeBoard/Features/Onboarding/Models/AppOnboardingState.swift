import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct AppOnboardingState: Codable, Equatable {
    /// Version 5 is the Life Map flow with EVA activation merged into it.
    ///
    /// Bumping this invalidates in-flight journey snapshots from the old flow,
    /// which is intended — their steps no longer exist. It must **not** re-onboard
    /// someone who already finished: `OnboardingEligibilityService` treats any
    /// recorded completion as handled, so a finished user stays finished.
    static let currentVersion = 5

    var outcome: OnboardingOutcome?
    var completedVersion: Int?
    var establishedWorkspacePromptDismissedVersion: Int?
    var journeySnapshot: OnboardingJourneySnapshot?
    /// Schema 7 is intentionally a separate payload. Version-3 snapshots remain
    /// decodable but are never resumed into the Life Map step graph.
    var lifeMapJourneySnapshot: LifeMapDraft?

    var hasHandledCurrentVersion: Bool {
        completedVersion == Self.currentVersion && outcome != nil
    }
}
