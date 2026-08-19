import Foundation

/// Translates a v6 draft into the shape `LifeMapCommitCoordinator` already
/// commits, and absorbs the result back.
///
/// The commit path is the one part of v5 worth keeping verbatim: it is phased,
/// resumable, and idempotent where it has to be, and it is the only code in
/// onboarding that writes canonical records. Forking it for v6 would mean two
/// implementations of "upsert the life areas, then working hours, then the Home
/// layout, then the profile, then the capture, then completion" — and the second
/// one would be the one that loses somebody's first task.
///
/// So v6 does not fork it. It hands the coordinator a `LifeMapDraft` assembled
/// from v6 state, and takes back the two fields the commit owns.
extension LifeWeaveDraft {

    /// The v5-shaped draft the coordinator commits.
    ///
    /// `moduleIDs` is the derived set rather than a user answer — that is the
    /// entire point of deleting the module screen — and it is passed in so the
    /// coordinator's Home-layout write is unchanged.
    func makeCommitDraft(moduleIDs: Set<String>) -> LifeMapDraft {
        var legacy = LifeMapDraft()
        legacy.entryContext = entryContext
        legacy.desiredChange = desiredChange
        legacy.frictionIDs = blockerIDs
        legacy.orderedLifeAreaTemplateIDs = orderedLifeAreaTemplateIDs
        legacy.dayShape = dayShape
        legacy.didEditDayShape = didEditDayShape
        legacy.moduleIDs = moduleIDs.sorted()
        legacy.moduleGroupIDs = []
        legacy.stagedCapture = stagedCapture
        legacy.skippedCapture = skippedCapture
        legacy.resolvedLifeAreaIDsByTemplate = resolvedLifeAreaIDsByTemplate
        legacy.didWriteEvaProfile = didWriteEvaProfile

        // Carried so a resumed commit picks up where it stopped instead of
        // replaying writes the coordinator only skips because it is told to.
        legacy.commitPhase = commitPhase

        legacy.grantedPermissionIDs = grantedPermissionIDs
        legacy.deniedPermissionIDs = deniedPermissionIDs
        legacy.selectedCalendarIDs = selectedCalendarIDs
        legacy.healthWriteBackDomainIDs = healthWriteBackDomainIDs
        legacy.evaCloudReady = evaCloudReady
        legacy.evaDeferred = evaDeferred
        return legacy
    }

    /// Takes back only what the commit is the authority on.
    ///
    /// Deliberately narrow. The coordinator receives a projection of v6 state and
    /// must not be able to write v6 state back wholesale — if it could, a field
    /// the bridge does not set (the intent, the primary area, the day-shape
    /// preset) would be silently reset to a `LifeMapDraft` default on every
    /// commit, and the reveal would describe a workspace nobody chose.
    mutating func absorbCommitResult(_ committed: LifeMapDraft) {
        commitPhase = committed.commitPhase
        resolvedLifeAreaIDsByTemplate = committed.resolvedLifeAreaIDsByTemplate
        didWriteEvaProfile = committed.didWriteEvaProfile
    }
}
