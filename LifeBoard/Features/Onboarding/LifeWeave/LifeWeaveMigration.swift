import Foundation

/// Translates an interrupted v5 Life Map draft into the v6 journey.
///
/// The rule this exists to honour is that a person who answered four questions
/// and then backgrounded the app does not get asked them again because we
/// shipped a redesign. Everything v6 still asks for is carried across;
/// everything it no longer asks for is either dropped or, where it is real user
/// signal, kept dormant rather than resurfaced on a screen that no longer exists.
///
/// Migration is one-way. A v6 draft is never translated back into v5: turning
/// the flag off mid-journey leaves the v5 snapshot exactly where it was, which
/// is a resume, not a rollback of work.
enum LifeWeaveMigration {

    /// The nearest v6 step for a v5 step.
    ///
    /// v5's `friction` and `priorities` folded into the screens above them, and
    /// `connections` was deleted outright, so each resumes at the screen that now
    /// owns its question. Resuming *earlier* than the user got to is the safe
    /// direction: they re-confirm an answer they already gave rather than having
    /// a screen they never saw silently skipped.
    static func step(forV5 step: LifeMapOnboardingStep) -> LifeWeaveStep {
        switch step {
        case .welcome: .arrival
        case .desiredChange, .friction: .intent
        case .lifeAreas, .priorities: .lifeAreas
        // `connections` asked which modules to switch on. v6 infers that, so a
        // draft interrupted there resumes at the next thing it would have been
        // asked rather than at a screen that is gone.
        case .capacity, .connections: .dayShape
        case .capture: .firstCapture
        case .reveal, .calendar, .health, .reminders, .eva, .tour, .firstWin: .reveal
        }
    }

    /// Translates the whole draft.
    ///
    /// `commitPhase` is carried across deliberately: a v5 draft that died between
    /// `lifeAreasWritten` and `captureWritten` has real canonical records behind
    /// it, and resetting the phase would make the v6 commit replay writes the
    /// coordinator is only idempotent about because it is told where it got to.
    static func draft(fromV5 legacy: LifeMapDraft) -> LifeWeaveDraft {
        var draft = LifeWeaveDraft()
        draft.step = step(forV5: legacy.step)
        draft.entryContext = legacy.entryContext

        draft.intent = legacy.desiredChange.map(LifeWeaveIntent.init(desiredChange:))
        // Kept, not shown. The blockers still shape the stored profile and the
        // EVA opening prompts; v6 simply never charges a screen for them again.
        draft.blockerIDs = Array(legacy.frictionIDs.prefix(LifeWeaveDraft.maximumBlockers))

        draft.orderedLifeAreaTemplateIDs = legacy.orderedLifeAreaTemplateIDs
        // v5's drag ranking is a superset of v6's one-tap primary: the area the
        // user dragged to the top *is* the one that needed the clearest path.
        draft.primaryLifeAreaTemplateID = legacy.orderedLifeAreaTemplateIDs.first

        draft.dayShape = legacy.dayShape
        draft.didEditDayShape = legacy.didEditDayShape
        draft.dayShapePreset = preset(matching: legacy.dayShape, wasEdited: legacy.didEditDayShape)

        draft.stagedCapture = legacy.stagedCapture
        draft.skippedCapture = legacy.skippedCapture
        draft.resolvedLifeAreaIDsByTemplate = legacy.resolvedLifeAreaIDsByTemplate

        draft.grantedPermissionIDs = legacy.grantedPermissionIDs
        draft.deniedPermissionIDs = legacy.deniedPermissionIDs
        draft.selectedCalendarIDs = legacy.selectedCalendarIDs
        draft.healthWriteBackDomainIDs = legacy.healthWriteBackDomainIDs
        draft.evaCloudReady = legacy.evaCloudReady
        draft.evaDeferred = legacy.evaDeferred
        draft.didWriteEvaProfile = legacy.didWriteEvaProfile

        draft.commitPhase = legacy.commitPhase
        draft.lifecyclePhase = legacy.commitPhase >= .captureWritten ? .revealReady : .editing
        return draft
    }

    /// Schema 8 had no explicit lifecycle. Infer only from durable facts, then
    /// persist the result as schema 9 before the flow renders.
    static func draft(fromEarlierSchema snapshot: LifeWeaveDraft) -> LifeWeaveDraft {
        var migrated = snapshot
        migrated.schemaVersion = LifeWeaveDraft.currentSchemaVersion
        if migrated.evaSelectedGrantIDs == nil {
            migrated.evaSelectedGrantIDs = EvaConsentPolicy.Grant.allCases.map(\.rawValue)
        }
        if migrated.evaActivationPending == nil {
            migrated.evaActivationPending = false
        }
        migrated.lifecyclePhase = snapshot.lifecyclePhase ?? lifecyclePhase(forV8: snapshot)
        if migrated.lifecyclePhase == .revealReady { migrated.step = .reveal }
        return migrated
    }

    static func draft(fromV8 snapshot: LifeWeaveDraft) -> LifeWeaveDraft {
        draft(fromEarlierSchema: snapshot)
    }

    static func lifecyclePhase(forV8 snapshot: LifeWeaveDraft) -> LifeWeaveLifecyclePhase {
        if snapshot.step == .reveal { return .revealReady }
        if snapshot.commitPhase >= .captureWritten { return .captureWritten }
        if snapshot.commitPhase > .notStarted { return .committing }
        return .editing
    }

    /// Recovers which preset a stored window corresponds to.
    ///
    /// An untouched v5 draft carries the flow's own 9–17 default, which is
    /// `typical` — presenting that as "custom hours" would tell the user they
    /// made a choice they never made. A window the user actually edited is only
    /// called a preset when it matches one exactly.
    static func preset(
        matching dayShape: OnboardingDayShapeDraft,
        wasEdited: Bool
    ) -> LifeWeaveDayShapePreset {
        let window = (start: dayShape.weekdayStartMinute, end: dayShape.weekdayEndMinute)
        let match = LifeWeaveDayShapePreset.allCases.first { candidate in
            guard let candidateWindow = candidate.weekdayWindow else { return false }
            return candidateWindow.start == window.start && candidateWindow.end == window.end
        }
        if let match { return match }
        return wasEdited ? .custom : .typical
    }
}
