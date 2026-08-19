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
        XCTAssertEqual(LifeWeaveDraft().schemaVersion, 8)
    }

    /// The connect chain stays outside core, which is the whole product
    /// contract: core completion never depends on a permission, a download, an
    /// account, or the network.
    func testConnectorsAreNotPartOfCore() {
        for step in LifeWeaveStep.powerUps {
            XCTAssertTrue(step.isPowerUp, "\(step) should be a power-up")
            XCTAssertNil(step.coreIndex, "\(step) must not occupy a core position")
            XCTAssertFalse(LifeWeaveStep.core.contains(step))
        }
    }

    /// Numeric position is published for VoiceOver even though the sighted UI
    /// deliberately shows a track instead of a percentage.
    func testCoreIndexIsOneBasedForEveryCoreStep() {
        XCTAssertEqual(LifeWeaveStep.arrival.coreIndex, 1)
        XCTAssertEqual(LifeWeaveStep.lifeAreas.coreIndex, 3)
        XCTAssertEqual(LifeWeaveStep.reveal.coreIndex, 6)
    }

    func testPowerUpChainOmitsConnectorsNothingWouldUse() {
        let minimal = LifeWeaveStep.visiblePowerUps(
            requestablePermissions: [.calendar],
            includesEva: false
        )
        XCTAssertEqual(minimal, [.calendar])

        let full = LifeWeaveStep.visiblePowerUps(
            requestablePermissions: [.calendar, .appleHealth, .notifications],
            includesEva: true
        )
        XCTAssertEqual(full, [.calendar, .health, .reminders, .eva])
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
            (.calendar, .calendar),
            (.health, .health),
            (.reminders, .reminders),
            (.eva, .eva)
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

    // MARK: - Reveal copy

    /// Never fabricate. A skipped capture is an honest empty state.
    func testReceiptClaimsACaptureOnlyWhenOneWasReviewed() {
        var draft = LifeWeaveDraft()
        draft.orderedLifeAreaTemplateIDs = ["work-career", "health-self", "money"]

        XCTAssertFalse(LifeWeaveRevealCopy.receipt(for: draft).contains { $0.contains("captured") })

        draft.stagedCapture = LifeMapStagedCapture(text: "Renew passport", kind: .task, isReviewed: false)
        XCTAssertFalse(
            LifeWeaveRevealCopy.receipt(for: draft).contains { $0.contains("captured") },
            "an unreviewed capture is not written, so the receipt must not claim it"
        )

        draft.stagedCapture?.isReviewed = true
        XCTAssertTrue(LifeWeaveRevealCopy.receipt(for: draft).contains("1 thing captured"))
        XCTAssertTrue(LifeWeaveRevealCopy.receipt(for: draft).contains("3 life areas"))
    }

    /// The emotional high point of the first run must not be the one thing that
    /// fails offline, so the sentence is a template rather than a generation.
    func testRevealSentenceNamesThePrimaryAreaFirst() {
        var draft = LifeWeaveDraft()
        draft.orderedLifeAreaTemplateIDs = ["work-career", "health-self"]
        let sentence = LifeWeaveRevealCopy.sentence(for: draft)
        XCTAssertTrue(sentence.hasPrefix("Work & Career"))
        XCTAssertTrue(sentence.contains("Health & Self"))
    }

    // MARK: - Copy hygiene

    /// Internal vocabulary must not reach first-run copy. The user did not come
    /// to route an entity or to select a module.
    func testFirstRunCopyDoesNotLeakImplementationVocabulary() {
        let banned = ["route", "module", "canonical", "projection", "provider", "authority"]
        var copy: [String] = []
        for intent in LifeWeaveIntent.allCases {
            copy.append(intent.title)
            if let subtitle = intent.subtitle { copy.append(subtitle) }
        }
        for preset in LifeWeaveDayShapePreset.allCases { copy.append(preset.title) }
        var draft = LifeWeaveDraft()
        draft.orderedLifeAreaTemplateIDs = ["work-career", "health-self"]
        copy.append(LifeWeaveRevealCopy.sentence(for: draft))
        for intent in LifeWeaveIntent.allCases {
            if let line = LifeWeaveRevealCopy.intentLine(for: intent) { copy.append(line) }
        }

        for line in copy {
            let lower = line.lowercased()
            for word in banned {
                XCTAssertFalse(lower.contains(word), "\"\(line)\" leaks \"\(word)\" into first-run copy")
            }
        }
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
}
