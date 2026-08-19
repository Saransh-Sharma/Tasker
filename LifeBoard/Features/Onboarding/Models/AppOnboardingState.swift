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

    /// The v6 "Life Weave" journey, schema 8.
    ///
    /// A third payload rather than a replacement, and `currentVersion` stays at
    /// 5 on purpose. The v6 rollout is a flag, not a version bump: bumping would
    /// invalidate every in-flight v5 snapshot the moment the flag flipped, and
    /// turning the flag back off has to leave a half-finished v5 journey exactly
    /// where its owner left it. `LifeWeaveMigration` translates one into the
    /// other on read; neither erases the other on write.
    var lifeWeaveJourneySnapshot: LifeWeaveDraft?

    /// Which journey recorded the completion.
    ///
    /// The contextual root cues exist because v6 deleted the five-beat tour. A
    /// user who finished under v5 has already been told those four things, so
    /// replaying them would be the product forgetting what it had said. Absent
    /// on every pre-v6 install, which reads correctly as "not the Life Weave".
    var completedLifeWeave: Bool?

    /// A journey is in flight under either flow. The launch path resumes on this
    /// rather than on one snapshot, so a person who started v5 and relaunched
    /// after the flag flipped is resumed instead of restarted.
    var hasResumableJourney: Bool {
        lifeMapJourneySnapshot != nil || lifeWeaveJourneySnapshot != nil
    }

    var hasHandledCurrentVersion: Bool {
        completedVersion == Self.currentVersion && outcome != nil
    }
}
