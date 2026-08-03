import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct AppOnboardingState: Codable, Equatable {
    /// Version 3 is the rebuilt nine-step flow.
    ///
    /// Bumping this invalidates in-flight journey snapshots from the old flow,
    /// which is intended — their steps no longer exist. It must **not** re-onboard
    /// someone who already finished: `OnboardingEligibilityService` treats any
    /// recorded completion as handled, so a finished user stays finished.
    static let currentVersion = 3

    var outcome: OnboardingOutcome?
    var completedVersion: Int?
    var establishedWorkspacePromptDismissedVersion: Int?
    var journeySnapshot: OnboardingJourneySnapshot?

    var hasHandledCurrentVersion: Bool {
        completedVersion == Self.currentVersion && outcome != nil
    }
}
