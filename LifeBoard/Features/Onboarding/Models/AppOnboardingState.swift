import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct AppOnboardingState: Codable, Equatable {
    /// Version 7 is the Life Weave flow plus the optional Power-Up phase.
    ///
    /// Bumping this invalidates in-flight journey snapshots from the old flow,
    /// which is intended — their steps no longer exist. It must **not** re-onboard
    /// someone who already finished: `OnboardingEligibilityService` decides on
    /// `completedVersion != nil`, not on equality with this number, so a user who
    /// finished under 6 stays finished. `hasHandledCurrentVersion` is the only
    /// equality reader, and it gates the established-user invitation, not the flow.
    static let currentVersion = 7
    static var currentLifeWeaveRefreshVersion: Int {
        AppRuntimeConfigurationStore.current.existingUserRefreshVersion
    }

    var outcome: OnboardingOutcome?
    var completedVersion: Int?
    var establishedWorkspacePromptDismissedVersion: Int?
    var journeySnapshot: OnboardingJourneySnapshot?
    /// Schema 7 is intentionally a separate payload. Version-3 snapshots remain
    /// decodable but are never resumed into the Life Map step graph.
    var lifeMapJourneySnapshot: LifeMapDraft?

    /// The "Life Weave" journey, currently schema 11.
    ///
    /// A third payload rather than a replacement. The v6 rollout was a flag
    /// rather than a version bump, because bumping would have invalidated every
    /// in-flight v5 snapshot the moment the flag flipped, and turning the flag
    /// back off has to leave a half-finished v5 journey exactly where its owner
    /// left it. `LifeWeaveMigration` translates one into the other on read;
    /// neither erases the other on write.
    ///
    /// This snapshot now survives core completion: while the optional Power-Up
    /// phase is in flight the journey is both *completed* and *resumable*, which
    /// is exactly the guarantee that lets a connector fail without taking the
    /// committed LifeBoard down with it.
    var lifeWeaveJourneySnapshot: LifeWeaveDraft?

    /// Which journey recorded the completion.
    ///
    /// The contextual root cues exist because v6 deleted the five-beat tour. A
    /// user who finished under v5 has already been told those four things, so
    /// replaying them would be the product forgetting what it had said. Absent
    /// on every pre-v6 install, which reads correctly as "not the Life Weave".
    var completedLifeWeave: Bool?
    var completedRefreshVersion: Int?
    var dismissedRefreshVersion: Int?
    var refreshDraft: LifeWeaveDraft?
    var finalizedLifeWeaveDestination: LifeWeaveCompletionDestination?
    var needsFinalizedDestinationDelivery: Bool?

    /// A journey is in flight under either flow. The launch path resumes on this
    /// rather than on one snapshot, so a person who started v5 and relaunched
    /// after the flag flipped is resumed instead of restarted.
    var hasResumableJourney: Bool {
        lifeMapJourneySnapshot != nil || lifeWeaveJourneySnapshot != nil || refreshDraft != nil
    }

    var needsCurrentRefresh: Bool {
        completedRefreshVersion != Self.currentLifeWeaveRefreshVersion
            && dismissedRefreshVersion != Self.currentLifeWeaveRefreshVersion
    }

    var hasHandledCurrentVersion: Bool {
        completedVersion == Self.currentVersion && outcome != nil
    }
}
