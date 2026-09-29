import XCTest
@testable import LifeBoard

/// The v6 "Life Weave" journey.
///
/// The bar these hold is not "the six screens render". It is that a person who
/// answered four questions and closed the app does not lose them, that the
/// commit cannot write something they did not approve, and that nothing the
/// reveal claims is untrue.
final class LifeWeaveOnboardingTests: XCTestCase {

    // MARK: - Shape of the flow

    func testCoreIsSixStepsAndEndsAtTheReveal() {
        XCTAssertEqual(LifeWeaveStep.core.count, 6)
        XCTAssertEqual(LifeWeaveStep.core.first, .arrival)
        XCTAssertEqual(LifeWeaveStep.core.last, .reveal)
        XCTAssertEqual(LifeWeaveDraft().schemaVersion, LifeWeaveDraft.currentSchemaVersion)
    }

    func testStepEnumContainsOnlyTheSixCoreStages() {
        XCTAssertEqual(LifeWeaveStep.allCases, [.arrival, .intent, .lifeAreas, .dayShape, .firstCapture, .reveal])
    }

    /// Numeric position is published for VoiceOver even though the sighted UI
    /// deliberately shows a track instead of a percentage.
    func testCoreIndexIsOneBasedForEveryLegacyStep() {
        XCTAssertEqual(LifeWeaveStep.arrival.coreIndex, 1)
        XCTAssertEqual(LifeWeaveStep.lifeAreas.coreIndex, 3)
        XCTAssertEqual(LifeWeaveStep.reveal.coreIndex, 6)
    }

    /// Renaming a case must not silently rename a published identifier, because
    /// the snapshot in `scripts/accessibility-identifiers.sha256` would move with
    /// it and nobody would know which test broke.
    func testEveryStepPublishesAStableIdentifierSuffix() {
        var seen: Set<String> = []
        for step in LifeWeaveStep.allCases {
            XCTAssertFalse(step.identifierSuffix.isEmpty)
            XCTAssertTrue(seen.insert(step.identifierSuffix).inserted, "duplicate suffix for \(step)")
        }
    }

    // MARK: - Migration from v5

    /// The rule: somebody who answered four questions and backgrounded the app
    /// does not get asked them again because we shipped a redesign.
    func testMigrationCarriesEveryAnswerForward() {
        var legacy = LifeMapDraft()
        legacy.step = .capacity
        legacy.entryContext = .establishedWorkspace
        legacy.desiredChange = .clearHead
        legacy.frictionIDs = [LifeMapFriction.scattered.id, LifeMapFriction.plansBreak.id]
        legacy.orderedLifeAreaTemplateIDs = ["health-self", "work-career", "money"]
        legacy.dayShape.weekdayStartMinute = 7 * 60
        legacy.dayShape.weekdayEndMinute = 15 * 60
        legacy.didEditDayShape = true
        legacy.stagedCapture = LifeMapStagedCapture(text: "Renew passport", kind: .task, isReviewed: true)
        legacy.resolvedLifeAreaIDsByTemplate = ["work-career": UUID()]
        legacy.grantedPermissionIDs = [PermissionKind.calendar.id]
        legacy.deniedPermissionIDs = [PermissionKind.notifications.id]
        legacy.selectedCalendarIDs = ["cal-1"]
        legacy.healthWriteBackDomainIDs = ["hydration"]
        legacy.evaCloudReady = true
        legacy.evaDeferred = true
        legacy.didWriteEvaProfile = true
        legacy.commitPhase = .capacityWritten

        let migrated = LifeWeaveMigration.draft(fromV5: legacy)

        XCTAssertEqual(migrated.intent, .reduceMentalLoad)
        XCTAssertEqual(migrated.blockerIDs, legacy.frictionIDs)
        XCTAssertEqual(migrated.orderedLifeAreaTemplateIDs, legacy.orderedLifeAreaTemplateIDs)
        // v5's drag ranking is a superset of v6's one-tap primary: whatever the
        // user dragged to the top is the area that needed the clearest path.
        XCTAssertEqual(migrated.primaryLifeAreaTemplateID, "health-self")
        XCTAssertEqual(migrated.dayShape, legacy.dayShape)
        XCTAssertTrue(migrated.didEditDayShape)
        XCTAssertEqual(migrated.dayShapePreset, .early)
        XCTAssertEqual(migrated.stagedCapture, legacy.stagedCapture)
        XCTAssertEqual(migrated.resolvedLifeAreaIDsByTemplate, legacy.resolvedLifeAreaIDsByTemplate)
        XCTAssertEqual(migrated.grantedPermissionIDs, legacy.grantedPermissionIDs)
        XCTAssertEqual(migrated.deniedPermissionIDs, legacy.deniedPermissionIDs)
        XCTAssertEqual(migrated.selectedCalendarIDs, legacy.selectedCalendarIDs)
        XCTAssertEqual(migrated.healthWriteBackDomainIDs, legacy.healthWriteBackDomainIDs)
        XCTAssertTrue(migrated.evaCloudReady)
        XCTAssertTrue(migrated.evaDeferred)
        XCTAssertTrue(migrated.didWriteEvaProfile)
        XCTAssertEqual(migrated.entryContext, .establishedWorkspace)
    }

    /// A draft that died mid-commit has real canonical records behind it.
    /// Resetting the phase would make the v6 commit replay writes the
    /// coordinator only skips because it is told where it got to.
    func testMigrationPreservesCommitPhase() {
        var legacy = LifeMapDraft()
        legacy.commitPhase = .profileWritten
        XCTAssertEqual(LifeWeaveMigration.draft(fromV5: legacy).commitPhase, .profileWritten)
    }

    func testSchemaEightLifecycleMigrationUsesDurableCommitFacts() {
        var editing = LifeWeaveDraft()
        editing.schemaVersion = 8
        editing.lifecyclePhase = nil
        XCTAssertEqual(LifeWeaveMigration.draft(fromV8: editing).lifecyclePhase, .editing)

        var written = editing
        written.commitPhase = .captureWritten
        let migrated = LifeWeaveMigration.draft(fromV8: written)
        XCTAssertEqual(migrated.schemaVersion, LifeWeaveDraft.currentSchemaVersion)
        XCTAssertEqual(migrated.lifecyclePhase, .captureWritten)
    }

    func testSchemaNineMigrationAddsCloudActivationDefaultsWithoutChangingEarlierAnswers() {
        var earlier = LifeWeaveDraft()
        earlier.schemaVersion = 9
        earlier.intent = .reduceMentalLoad
        earlier.evaSelectedGrantIDs = nil
        earlier.evaActivationPending = nil

        let migrated = LifeWeaveMigration.draft(fromEarlierSchema: earlier)

        XCTAssertEqual(migrated.schemaVersion, LifeWeaveDraft.currentSchemaVersion)
        XCTAssertEqual(migrated.intent, .reduceMentalLoad)
        XCTAssertEqual(migrated.resolvedEvaGrants, Set(EvaConsentPolicy.Grant.allCases))
        XCTAssertEqual(migrated.evaActivationPending, false)
    }

    /// Resuming earlier than the user reached is the safe direction: they
    /// re-confirm an answer they already gave, rather than having a screen they
    /// never saw silently skipped.
    func testMigrationMapsEveryV5StepToALivingV6Step() {
        let expectations: [(LifeMapOnboardingStep, LifeWeaveStep)] = [
            (.welcome, .arrival),
            (.desiredChange, .intent),
            (.friction, .intent),
            (.lifeAreas, .lifeAreas),
            (.priorities, .lifeAreas),
            (.capacity, .dayShape),
            (.connections, .dayShape),
            (.capture, .firstCapture),
            (.reveal, .reveal),
            (.tour, .reveal),
            (.firstWin, .reveal),
            (.calendar, .reveal),
            (.health, .reveal),
            (.reminders, .reveal),
            (.eva, .reveal)
        ]
        for (legacy, expected) in expectations {
            XCTAssertEqual(LifeWeaveMigration.step(forV5: legacy), expected, "for \(legacy)")
        }
        // Every v5 case is covered, so a new one cannot slip through untranslated.
        XCTAssertEqual(expectations.count, LifeMapOnboardingStep.allCases.count)
    }

    /// An untouched v5 draft carries the flow's own 9–17 default. Calling that
    /// "custom hours" would tell the user they made a choice they never made.
    func testUntouchedDefaultWindowIsNotReportedAsCustom() {
        let untouched = LifeWeaveMigration.preset(matching: LifeMapDraft().dayShape, wasEdited: false)
        XCTAssertEqual(untouched, .typical)

        var odd = OnboardingDayShapeDraft()
        odd.weekdayStartMinute = 6 * 60 + 30
        odd.weekdayEndMinute = 13 * 60 + 45
        XCTAssertEqual(LifeWeaveMigration.preset(matching: odd, wasEdited: true), .custom)
    }

    // MARK: - Derived module set

    /// Deleting the module screen must not mean every user gets the same Home.
    func testModuleDerivationRespondsToAreasAndIsDeterministic() {
        let health = OnboardingModuleCatalog.recommendedModuleIDs(
            intent: .steadyRoutines,
            lifeAreaTemplateIDs: ["health-self"]
        )
        let work = OnboardingModuleCatalog.recommendedModuleIDs(
            intent: .steadyRoutines,
            lifeAreaTemplateIDs: ["work-career"]
        )
        XCTAssertNotEqual(health, work, "areas must change what Home contains")
        XCTAssertTrue(health.contains(OnboardingModuleCatalog.bodyID))

        // A Home layout that shuffled between two launches would be a bug, not
        // personalisation.
        let repeated = OnboardingModuleCatalog.recommendedModuleIDs(
            intent: .steadyRoutines,
            lifeAreaTemplateIDs: ["health-self"]
        )
        XCTAssertEqual(health, repeated)
    }

    /// A disabled surface must never contribute a Home card or pull in a
    /// permission nothing would consume.
    func testDerivedModulesAreAlwaysAvailableOnes() {
        let derived = OnboardingModuleCatalog.recommendedModuleIDs(
            intent: .wholeLifeView,
            lifeAreaTemplateIDs: StarterWorkspaceCatalog.allLifeAreas.map(\.id)
        )
        let available = Set(OnboardingModuleCatalog.all.map(\.id))
        XCTAssertTrue(derived.isSubset(of: available))
    }

    // MARK: - Draft rules

    func testCaptureIsResolvedOnlyBySkipOrReview() {
        var draft = LifeWeaveDraft()
        XCTAssertFalse(draft.isCaptureResolved)

        draft.stagedCapture = LifeMapStagedCapture(text: "Call Mum", kind: .task, isReviewed: false)
        XCTAssertFalse(
            draft.isCaptureResolved,
            "a typed-but-unreviewed capture must never satisfy the step — that is what stops the commit writing something nobody approved"
        )

        draft.stagedCapture?.isReviewed = true
        XCTAssertTrue(draft.isCaptureResolved)

        var skipped = LifeWeaveDraft()
        skipped.skippedCapture = true
        XCTAssertTrue(skipped.isCaptureResolved)
    }

    func testAreaSelectionBoundsMatchTheCopy() {
        var draft = LifeWeaveDraft()
        draft.orderedLifeAreaTemplateIDs = ["work-career"]
        XCTAssertFalse(draft.isLifeAreaSelectionValid)

        draft.orderedLifeAreaTemplateIDs = ["work-career", "health-self"]
        XCTAssertTrue(draft.isLifeAreaSelectionValid)

        draft.orderedLifeAreaTemplateIDs = StarterWorkspaceCatalog.allLifeAreas.map(\.id)
        XCTAssertFalse(draft.isLifeAreaSelectionValid, "seven exceeds the stated maximum of five")
    }

    // MARK: - Commit bridge

    /// The coordinator receives a projection of v6 state and must not be able to
    /// write v6 state back wholesale — otherwise a field the bridge does not set
    /// would reset to a `LifeMapDraft` default on every commit, and the reveal
    /// would describe a workspace nobody chose.
    func testCommitResultOnlyWritesBackWhatTheCommitOwns() {
        var draft = LifeWeaveDraft()
        draft.intent = .resilientPlanning
        draft.primaryLifeAreaTemplateID = "work-career"
        draft.dayShapePreset = .later
        draft.blockerIDs = ["scattered"]

        var committed = LifeMapDraft()
        committed.commitPhase = .captureWritten
        committed.resolvedLifeAreaIDsByTemplate = ["work-career": UUID()]
        committed.didWriteEvaProfile = true

        draft.absorbCommitResult(committed)

        XCTAssertEqual(draft.commitPhase, .captureWritten)
        XCTAssertEqual(draft.resolvedLifeAreaIDsByTemplate, committed.resolvedLifeAreaIDsByTemplate)
        XCTAssertTrue(draft.didWriteEvaProfile)
        XCTAssertEqual(draft.intent, .resilientPlanning)
        XCTAssertEqual(draft.primaryLifeAreaTemplateID, "work-career")
        XCTAssertEqual(draft.dayShapePreset, .later)
        XCTAssertEqual(draft.blockerIDs, ["scattered"])
    }

    func testCommitDraftCarriesTheDerivedModulesAndThePhase() {
        var draft = LifeWeaveDraft()
        draft.intent = .clarityToday
        draft.orderedLifeAreaTemplateIDs = ["work-career", "health-self"]
        draft.commitPhase = .layoutWritten

        let legacy = draft.makeCommitDraft(moduleIDs: ["focus", "habits"])
        XCTAssertEqual(Set(legacy.moduleIDs), ["focus", "habits"])
        XCTAssertEqual(legacy.commitPhase, .layoutWritten)
        XCTAssertEqual(legacy.desiredChange, .knowNext)
        XCTAssertEqual(legacy.orderedLifeAreaTemplateIDs, draft.orderedLifeAreaTemplateIDs)
    }

    // MARK: - Ready copy

    /// Never fabricate. A skipped or unreviewed capture is an honest empty
    /// state, and the receipt says so in plain words.
    func testReceiptClaimsACaptureOnlyWhenOneWasReviewed() {
        var draft = LifeWeaveDraft()
        draft.orderedLifeAreaTemplateIDs = ["work-career", "health-self", "money"]

        XCTAssertEqual(LifeWeaveRevealCopy.receipt(for: draft).first, LifeWeaveCopy.Ready.emptyCapture)

        draft.stagedCapture = LifeMapStagedCapture(text: "Renew passport", kind: .task, isReviewed: false)
        XCTAssertEqual(
            LifeWeaveRevealCopy.receipt(for: draft).first,
            LifeWeaveCopy.Ready.emptyCapture,
            "an unreviewed capture is not written, so the receipt must not claim it"
        )

        draft.stagedCapture?.isReviewed = true
        let receipt = LifeWeaveRevealCopy.receipt(for: draft)
        XCTAssertEqual(receipt.first, "Renew passport · Task")
        XCTAssertTrue(receipt.contains("Work & Career first, plus 2 more"))
    }

    /// Pick order is the ranking, so the receipt names the first pick. Hours
    /// are never asked, so the receipt must not claim them.
    func testReceiptNamesTheFirstPickAndTheHours() {
        var draft = LifeWeaveDraft()
        draft.orderedLifeAreaTemplateIDs = ["health-self"]
        let receipt = LifeWeaveRevealCopy.receipt(for: draft)
        XCTAssertTrue(receipt.contains("Health & Self first"))
        XCTAssertFalse(receipt.contains { $0.hasPrefix("Weekdays ") }, "hours are never asked, so Ready must not list them")
    }

    // MARK: - Copy hygiene

    /// Every visible first-run string, gathered from the one file that owns them.
    private var firstRunCopy: [String] {
        var copy: [String] = [
            LifeWeaveCopy.Welcome.title, LifeWeaveCopy.Welcome.privacy,
            LifeWeaveCopy.Areas.title, LifeWeaveCopy.Areas.support,
            LifeWeaveCopy.Capture.title, LifeWeaveCopy.Capture.support, LifeWeaveCopy.Capture.saveAs,
            LifeWeaveCopy.Ready.title, LifeWeaveCopy.Ready.emptyCapture, LifeWeaveCopy.Ready.connectHeader,
            LifeWeaveCopy.Ready.evaNotice, LifeWeaveCopy.Ready.evaNoticeLink,
            LifeWeaveCopy.Hours.title, LifeWeaveCopy.Hours.support,
            LifeWeaveCopy.Failure.title, LifeWeaveCopy.Failure.body
        ]
        copy += LifeWeaveIntent.allCases.map(\.title)
        copy += LifeWeaveDayShapePreset.allCases.map(\.title)
        copy += LifeWeavePowerUpStep.connectors.map(LifeWeaveCopy.Connection.value)
        copy += LifeWeaveCopy.EvaData.bullets
        return copy
    }

    /// Internal vocabulary must not reach first-run copy. The user did not come
    /// to route an entity, select a module, or power anything up.
    func testFirstRunCopyDoesNotLeakImplementationVocabulary() {
        let banned = [
            "route", "module", "canonical", "projection", "provider", "authority",
            "clearest path", "life map", "weave", "power up", "boundary"
        ]
        for line in firstRunCopy {
            let lower = line.lowercased()
            for word in banned {
                XCTAssertFalse(lower.contains(word), "\"\(line)\" leaks \"\(word)\" into first-run copy")
            }
        }
    }

    /// The budgets the redesign was held to. A title is the question, an option
    /// is a label, a button is a verb — and none of them is a paragraph.
    func testFirstRunCopyStaysWithinItsWordBudgets() {
        func words(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }

        let titles = [
            LifeWeaveCopy.Welcome.title, LifeWeaveCopy.Areas.title,
            LifeWeaveCopy.Capture.title, LifeWeaveCopy.Ready.title, LifeWeaveCopy.Hours.title
        ]
        for title in titles { XCTAssertLessThanOrEqual(words(title), 6, "title too long: \(title)") }

        let options = LifeWeaveIntent.allCases.map(\.title)
            + LifeWeaveDayShapePreset.allCases.map(\.title)
            + StarterWorkspaceCatalog.allLifeAreas.map(\.name)
        for option in options { XCTAssertLessThanOrEqual(words(option), 4, "option too long: \(option)") }

        let buttons = [
            LifeWeaveCopy.Dock.continue, LifeWeaveCopy.Dock.pickOne, LifeWeaveCopy.Dock.save,
            LifeWeaveCopy.Dock.skip, LifeWeaveCopy.Dock.startMyDay, LifeWeaveCopy.Dock.pickMore(2),
            LifeWeaveCopy.Dock.notNow
        ]
        for button in buttons { XCTAssertLessThanOrEqual(words(button), 3, "button too long: \(button)") }

        let supports = [LifeWeaveCopy.Areas.support, LifeWeaveCopy.Capture.support, LifeWeaveCopy.Hours.support]
        for line in supports { XCTAssertLessThanOrEqual(words(line), 10, "support too long: \(line)") }
    }

    // MARK: - Life-area identity

    /// The old seven hexes were trait-blind, and `#293A18` sat at roughly 1.3:1
    /// on the dark canvas. Every catalog area now resolves to a token that has a
    /// dark and an Increase Contrast variant.
    func testEveryStarterAreaResolvesToAnAccentRole() {
        for template in StarterWorkspaceCatalog.allLifeAreas {
            XCTAssertNotNil(
                LifeAreaAccentRole(lifeAreaTemplateID: template.id),
                "no accent role for \(template.id)"
            )
        }
        XCTAssertNil(
            LifeAreaAccentRole(lifeAreaTemplateID: "a-user-created-area"),
            "a custom area has no role and keeps its own stored colour"
        )
    }

    // MARK: - Connections shape

    /// The core promise needs no permission. Connections must be a second axis,
    /// never more cases on `LifeWeaveStep` — that would turn "3 of 4" into
    /// "3 of 7" and recast an optional phase as mandatory.
    func testConnectionsAreASeparateAxisFromTheCoreSteps() {
        XCTAssertEqual(LifeWeaveStep.streamlined.count, 4)
        XCTAssertEqual(LifeWeavePowerUpStep.connectors, [.calendar, .health, .eva])
        XCTAssertEqual(LifeWeavePowerUpStep.allCases, LifeWeavePowerUpStep.connectors)
    }

    func testEveryConnectorCarriesAPosition() {
        XCTAssertEqual(LifeWeavePowerUpStep.calendar.connectorIndex, 1)
        XCTAssertEqual(LifeWeavePowerUpStep.health.connectorIndex, 2)
        XCTAssertEqual(LifeWeavePowerUpStep.eva.connectorIndex, 3)
    }

    func testEveryPowerUpStepPublishesAStableUniqueIdentifierSuffix() {
        let suffixes = LifeWeavePowerUpStep.allCases.map(\.identifierSuffix)
        XCTAssertEqual(Set(suffixes).count, suffixes.count)
        XCTAssertFalse(suffixes.contains { $0.isEmpty })
    }

    // MARK: - Connector position

    /// Opening a connector must not rewrite the core position. The reveal is
    /// still where the user was, which is what makes the phase additive.
    func testOpeningAConnectorLeavesTheCoreStepAtTheReveal() {
        var draft = LifeWeaveDraft()
        draft.step = .reveal
        XCTAssertNil(draft.resolvedPowerUpStep)

        draft.powerUpStep = LifeWeavePowerUpStep.calendar.rawValue
        XCTAssertEqual(draft.resolvedPowerUpStep, .calendar)
        XCTAssertEqual(draft.step, .reveal, "core position survives the phase change")
    }

    /// The retired `complete` receipt step is still on disk for some users. It
    /// must decode as "not in a connector", never throw and re-onboard them.
    func testALegacyCompletePowerUpStepDecodesToNilInsteadOfThrowing() throws {
        var draft = LifeWeaveDraft()
        draft.step = .reveal
        draft.lifecyclePhase = .poweringUp
        draft.powerUpStep = "complete"
        let data = try JSONEncoder().encode(draft)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["powerUpStep"] as? String, "complete")
        object["powerUpStep"] = "complete"
        let decoded = try JSONDecoder().decode(LifeWeaveDraft.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.resolvedPowerUpStep)
        XCTAssertEqual(decoded.step, .reveal)

        object.removeValue(forKey: "powerUpStep")
        let withoutKey = try JSONDecoder().decode(LifeWeaveDraft.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(withoutKey.resolvedPowerUpStep)
    }

    func testDeferralsResolveFromRawValuesAndIgnoreUnknownOnes() {
        var draft = LifeWeaveDraft()
        XCTAssertTrue(draft.resolvedDeferredPowerUps.isEmpty)
        draft.deferredPowerUpIDs = ["calendar", "eva", "not-a-connector"]
        XCTAssertEqual(draft.resolvedDeferredPowerUps, [.calendar, .eva])
    }

    // MARK: - Progress vocabulary

    /// Four anonymous segments; VoiceOver hears the position in words.
    /// Connections open as sheets over Ready and never take a position.
    func testProgressCountsFourScreensAndNamesThemForVoiceOver() {
        let areas = LifeWeaveProgressModel.resolve(.lifeAreas)
        XCTAssertEqual(areas.index, 2)
        XCTAssertEqual(areas.total, 4)
        XCTAssertEqual(areas.spokenLabel, "Setup, step 2 of 4, Life areas")

        XCTAssertEqual(LifeWeaveProgressModel.resolve(.dayShape).index, 2, "a legacy position maps onto its streamlined screen")
        XCTAssertEqual(LifeWeaveProgressModel.resolve(.reveal).index, 4, "a connection sits over Ready and never takes a position")
        XCTAssertEqual(LifeWeaveProgressModel.resolve(.arrival).spokenLabel, "Setup, step 1 of 4, Welcome")
    }

    // MARK: - Schema 11 migration

    /// A schema-10 draft predates the power-up phase entirely. It must decode,
    /// keep every answer, and arrive with the phase simply not yet entered —
    /// never with a half-initialised one.
    func testSchemaTenMigrationAddsThePowerUpPhaseWithoutDisturbingEarlierAnswers() {
        var snapshot = LifeWeaveDraft()
        snapshot.schemaVersion = 10
        snapshot.step = .reveal
        snapshot.lifecyclePhase = .revealReady
        snapshot.intent = .clarityToday
        snapshot.orderedLifeAreaTemplateIDs = ["work", "health"]
        snapshot.primaryLifeAreaTemplateID = "work"
        snapshot.selectedCalendarIDs = ["cal-1"]
        snapshot.commitPhase = .captureWritten
        snapshot.powerUpStep = nil
        snapshot.deferredPowerUpIDs = nil

        let migrated = LifeWeaveMigration.draft(fromEarlierSchema: snapshot)

        XCTAssertEqual(migrated.schemaVersion, LifeWeaveDraft.currentSchemaVersion)
        XCTAssertNil(migrated.powerUpStep, "an old draft never entered the phase")
        XCTAssertEqual(migrated.deferredPowerUpIDs, [], "seeded so later writes append")
        XCTAssertEqual(migrated.step, .reveal)
        XCTAssertEqual(migrated.intent, .clarityToday)
        XCTAssertEqual(migrated.orderedLifeAreaTemplateIDs, ["work", "health"])
        XCTAssertEqual(migrated.primaryLifeAreaTemplateID, "work")
        XCTAssertEqual(migrated.selectedCalendarIDs, ["cal-1"])
        XCTAssertEqual(migrated.commitPhase, .captureWritten)
    }
}

final class SeamlessOnboardingTests: XCTestCase {
    func testFourScreensPreserveStableLegacyRawValues() {
        XCTAssertEqual(LifeWeaveStep.streamlined, [.arrival, .lifeAreas, .firstCapture, .reveal])
        XCTAssertEqual(LifeWeaveStep.dayShape.rawValue, 3)
    }

    func testMigrationPreservesChoicesCommitAndOptOuts() {
        var draft = LifeWeaveDraft()
        draft.step = .dayShape
        draft.intent = .clarityToday
        draft.evaSelectedGrantIDs = []
        draft.commitPhase = .profileWritten
        draft.dayShapePreset = .later
        let capture = LifeMapStagedCapture(text: "Book train", isReviewed: true)
        draft.stagedCapture = capture
        let migrated = LifeWeaveMigration.streamlined(draft)
        XCTAssertEqual(migrated.step, .lifeAreas)
        XCTAssertEqual(migrated.intent, draft.intent)
        XCTAssertEqual(migrated.stagedCapture, capture)
        XCTAssertEqual(migrated.commitPhase, .profileWritten)
        XCTAssertEqual(migrated.dayShapePreset, .later)
        XCTAssertTrue(migrated.resolvedEvaGrants.isEmpty)
    }

    func testInterruptedConnectionReturnsToReadyWorkspace() {
        var draft = LifeWeaveDraft()
        draft.lifecyclePhase = .poweringUp
        draft.powerUpStep = LifeWeavePowerUpStep.eva.rawValue
        draft.evaActivationPending = true
        draft.commitPhase = .captureWritten
        var state = AppOnboardingState()
        state.lifeWeaveJourneySnapshot = draft
        XCTAssertTrue(state.hasOptionalJourneyToResume)
        let migrated = LifeWeaveMigration.streamlined(draft)
        XCTAssertNil(migrated.powerUpStep)
        XCTAssertEqual(migrated.step, .reveal)
        XCTAssertEqual(migrated.evaActivationPending, true)
    }

    func testUncommittedCaptureStillResumesCore() {
        var draft = LifeWeaveDraft()
        draft.step = .firstCapture
        draft.lifecyclePhase = .editing
        var state = AppOnboardingState()
        state.lifeWeaveJourneySnapshot = draft
        XCTAssertFalse(state.hasOptionalJourneyToResume)
        XCTAssertTrue(state.hasResumableJourney)
    }

    func testNewEvaCategoriesDefaultOnButExplicitEmptySelectionStaysEmpty() {
        var draft = LifeWeaveDraft()
        XCTAssertEqual(draft.resolvedEvaGrants, Set(EvaConsentPolicy.Grant.allCases))
        draft.evaSelectedGrantIDs = []
        XCTAssertTrue(LifeWeaveMigration.draft(fromEarlierSchema: draft).resolvedEvaGrants.isEmpty)
    }

    func testPendingActivationDraftRestoresTextWithoutSendIntent() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "test.seamless.\(UUID())"))
        let thread = UUID()
        defer { EvaPendingActivationDraftStore.clear(threadID: thread, defaults: defaults) }
        EvaPendingActivationDraftStore.save("Plan tomorrow", threadID: thread, defaults: defaults)
        XCTAssertEqual(EvaPendingActivationDraftStore.load(threadID: thread, defaults: defaults), "Plan tomorrow")
        XCTAssertNil(EvaPendingActivationDraftStore.load(threadID: UUID(), defaults: defaults))
        EvaPendingActivationDraftStore.clear(threadID: thread, defaults: defaults)
        XCTAssertNil(EvaPendingActivationDraftStore.load(threadID: thread, defaults: defaults))
    }
}

/// The four-screen redesign's behaviour, exercised through the real model.
@MainActor
final class LifeWeaveRedesignTests: XCTestCase {

    private func makeModel(
        resolver: (any LifeWeaveCaptureResolving)? = nil
    ) -> (model: LifeWeaveOnboardingModel, cleanup: () -> Void) {
        let suite = "life.weave.redesign.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = AppOnboardingStateStore(userDefaults: defaults)
        let commit = LifeMapCommitCoordinator(
            dependencies: .init(
                fetchLifeAreas: { [] },
                createLifeArea: { LifeArea(name: $0.name, color: $0.colorHex, icon: $0.icon) },
                updateLifeArea: { $0 },
                fetchTask: { _ in nil },
                createTask: { $0.toTaskDefinition(projectName: $0.projectName) },
                fetchReflection: { _ in nil },
                saveReflection: { $0 },
                saveWorkingHours: { _ in },
                fetchHomeLayout: { nil },
                saveHomeLayout: { _ in }
            ),
            stateStore: store,
            profileStore: LifeMapProfileStore(defaults: defaults),
            preferencesStore: WorkspacePreferencesStore(defaults: defaults)
        )
        let model = LifeWeaveOnboardingModel(
            stateStore: store,
            commitCoordinator: commit,
            feedback: OnboardingFeedbackController(),
            captureResolver: resolver ?? UniversalInputCoordinator()
        )
        model.prepareForPresentation(snapshot: nil, legacySnapshot: nil)
        return (model, { defaults.removePersistentDomain(forName: suite) })
    }

    /// Polls until the gated resolver has seen `count` sentences.
    private func waitForRequests(_ count: Int, on resolver: GatedCaptureResolver, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = Date().addingTimeInterval(2)
        while await resolver.requestCount() < count, Date() < deadline {
            try? await _Concurrency.Task.sleep(for: .milliseconds(10))
        }
        let seen = await resolver.requestCount()
        XCTAssertGreaterThanOrEqual(seen, count, "resolver saw \(seen) request(s)", file: file, line: line)
    }

    private func settle() async {
        try? await _Concurrency.Task.sleep(for: .milliseconds(60))
    }

    private func template(_ id: String) -> StarterLifeAreaTemplate {
        StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }!
    }

    func testEveryNewJourneyIsTheFourScreenFlow() {
        let (model, cleanup) = makeModel()
        defer { cleanup() }
        XCTAssertEqual(model.coreSteps, [.arrival, .lifeAreas, .firstCapture, .reveal])
        XCTAssertEqual(model.draft.streamlinedJourney, true)
    }

    /// The first pick leads; deselecting it promotes the next pick.
    func testPickOrderIsThePrimaryArea() {
        let (model, cleanup) = makeModel()
        defer { cleanup() }

        model.toggleLifeArea(template("health-self"))
        model.toggleLifeArea(template("work-career"))
        XCTAssertEqual(model.draft.primaryLifeAreaTemplateID, "health-self")
        XCTAssertEqual(model.draft.orderedLifeAreaTemplateIDs, ["health-self", "work-career"])

        model.toggleLifeArea(template("health-self"))
        XCTAssertEqual(model.draft.primaryLifeAreaTemplateID, "work-career")
    }

    /// The disabled dock says what is missing.
    func testAreasStillNeededCountsDownToZero() {
        let (model, cleanup) = makeModel()
        defer { cleanup() }
        XCTAssertEqual(model.lifeAreasStillNeeded, 2)
        model.toggleLifeArea(template("money"))
        XCTAssertEqual(model.lifeAreasStillNeeded, 1)
        model.toggleLifeArea(template("relationships"))
        XCTAssertEqual(model.lifeAreasStillNeeded, 0)
        XCTAssertEqual(LifeWeaveCopy.Dock.pickMore(1), "Pick 1 more")
    }

    /// Save never needs a separate "make sense of this" tap: it interprets if
    /// the pause has not happened yet, then keeps the result as reviewed.
    // MARK: Interpretation races

    /// Type, pause (interpretation in flight), type more, Save. The saved
    /// sentence is the one on screen; the older interpretation lands late and
    /// must not overwrite it.
    func testAStaleInterpretationNeverOverwritesTheSentenceTheUserSaved() async {
        let resolver = GatedCaptureResolver()
        let (model, cleanup) = makeModel(resolver: resolver)
        defer { cleanup() }

        model.captureText = "Call Mum"
        model.scheduleCaptureInterpretation(after: .zero)
        await waitForRequests(1, on: resolver)

        model.captureText = "Call Mum Sunday"
        let save = _Concurrency.Task { await model.saveCapture() }
        await waitForRequests(2, on: resolver)

        await resolver.release("Call Mum Sunday")
        await save.value
        await resolver.release("Call Mum")
        await settle()

        XCTAssertEqual(model.draft.stagedCapture?.text, "Call Mum Sunday")
        XCTAssertEqual(model.draft.stagedCapture?.isReviewed, true)
        XCTAssertFalse(model.isResolvingCapture)
    }

    /// Save pressed while the pause-triggered interpretation is still reading
    /// joins it instead of asking the resolver the same question twice.
    func testSaveJoinsTheInFlightInterpretationInsteadOfStartingASecond() async {
        let resolver = GatedCaptureResolver()
        let (model, cleanup) = makeModel(resolver: resolver)
        defer { cleanup() }

        model.captureText = "Call Mum"
        model.scheduleCaptureInterpretation(after: .zero)
        await waitForRequests(1, on: resolver)

        let save = _Concurrency.Task { await model.saveCapture() }
        await settle()
        let seen = await resolver.requestCount()
        XCTAssertEqual(seen, 1, "Save must join the in-flight pass")

        await resolver.release("Call Mum")
        await save.value

        XCTAssertEqual(model.draft.stagedCapture?.text, "Call Mum")
        XCTAssertEqual(model.draft.stagedCapture?.isReviewed, true)
        XCTAssertFalse(model.isResolvingCapture)
    }

    /// Clearing the field while an interpretation is in flight withdraws the
    /// spinner immediately; the late answer is dropped, not staged.
    func testClearingTheFieldMidInterpretationDropsTheLateAnswer() async {
        let resolver = GatedCaptureResolver()
        let (model, cleanup) = makeModel(resolver: resolver)
        defer { cleanup() }

        model.captureText = "Call Mum"
        model.scheduleCaptureInterpretation(after: .zero)
        await waitForRequests(1, on: resolver)
        XCTAssertTrue(model.isResolvingCapture)

        model.captureText = ""
        model.scheduleCaptureInterpretation()
        XCTAssertFalse(model.isResolvingCapture)

        await resolver.release("Call Mum")
        await settle()
        XCTAssertNil(model.draft.stagedCapture)
        XCTAssertFalse(model.isResolvingCapture)
    }

    func testSaveBeforeInterpretationStillProducesAReviewedCapture() async {
        let (model, cleanup) = makeModel()
        defer { cleanup() }
        model.toggleLifeArea(template("relationships"))
        model.toggleLifeArea(template("money"))
        model.captureText = "Call Mum on Sunday"

        await model.saveCapture()

        XCTAssertEqual(model.draft.stagedCapture?.text, "Call Mum on Sunday")
        XCTAssertEqual(model.draft.stagedCapture?.isReviewed, true)
        XCTAssertTrue(model.draft.isCaptureResolved)
    }

    /// The user's own Task/Journal choice survives until Save.
    func testChosenKindIsKeptOnSave() async {
        let (model, cleanup) = makeModel()
        defer { cleanup() }
        model.captureText = "Felt calmer after the walk"
        await model.resolveCapture()
        model.chooseCaptureKind(.journal)

        await model.saveCapture()

        XCTAssertEqual(model.draft.stagedCapture?.kind, .journal)
        XCTAssertEqual(model.draft.stagedCapture?.isReviewed, true)
    }

    /// Clearing the field withdraws an unreviewed proposal rather than leaving a
    /// stale one for Save to keep.
    func testClearingTheFieldWithdrawsTheProposal() async {
        let (model, cleanup) = makeModel()
        defer { cleanup() }
        model.captureText = "Renew passport photos"
        await model.resolveCapture()
        XCTAssertNotNil(model.draft.stagedCapture)

        model.captureText = ""
        model.scheduleCaptureInterpretation()
        XCTAssertNil(model.draft.stagedCapture)
    }

    func testSixStepPositionsResumeIntoTheirStreamlinedScreen() {
        XCTAssertEqual(LifeWeaveMigration.streamlinedStep(for: .intent), .arrival)
        XCTAssertEqual(LifeWeaveMigration.streamlinedStep(for: .dayShape), .lifeAreas)
        XCTAssertEqual(LifeWeaveMigration.streamlinedStep(for: .firstCapture), .firstCapture)
    }

    func testTheWelcomeNeverSaysGoodNight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let late = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 23))!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 8))!
        XCTAssertEqual(LifeWeaveIntentStep.daypartGreeting(at: late, calendar: calendar), "Good evening")
        XCTAssertEqual(LifeWeaveIntentStep.daypartGreeting(at: morning, calendar: calendar), "Good morning")
    }
}

/// A resolver that holds every sentence until the test releases it, so the
/// order in which interpretations land is the test's to choose.
private actor GatedCaptureResolver: LifeWeaveCaptureResolving {
    private var requests: [String] = []
    private var waiters: [String: [CheckedContinuation<LifeThreadIntentResolution, Never>]] = [:]
    private var released: [String: LifeThreadIntentResolution] = [:]

    func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution {
        requests.append(input.text)
        if let answer = released[input.text] { return answer }
        return await withCheckedContinuation { continuation in
            waiters[input.text, default: []].append(continuation)
        }
    }

    func release(_ text: String, kind: CaptureKind = .task) {
        let answer = LifeThreadIntentResolution.captureDraft(
            LifeThreadCaptureDraft(kind: kind, text: text, destination: .home)
        )
        released[text] = answer
        waiters.removeValue(forKey: text)?.forEach { $0.resume(returning: answer) }
    }

    func requestCount() -> Int { requests.count }
}
