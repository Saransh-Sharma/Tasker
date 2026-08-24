import XCTest
import UserNotifications
import SwiftUI
@testable import LifeBoard

final class AppOnboardingTests: XCTestCase {

    func testEligibilityReturnsFullFlowForEffectivelyEmptyWorkspace() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let service = OnboardingEligibilityService(
            stateStore: context.store,
            launchArguments: [],
            fetchLifeAreas: { [LifeArea(name: "General")] },
            fetchProjects: { [Project.createInbox()] },
            fetchTasks: { [] }
        )

        let result = await service.evaluate()

        guard case .fullFlow(let snapshot) = result else {
            return XCTFail("Expected full-flow onboarding for an effectively empty workspace.")
        }
        XCTAssertEqual(snapshot.customLifeAreaCount, 0)
        XCTAssertEqual(snapshot.customProjectCount, 0)
        XCTAssertEqual(snapshot.taskCount, 0)
    }

    /// `-SKIP_ONBOARDING` has to hold even when a partial journey is stored.
    ///
    /// The coordinator's resume branch runs ahead of `evaluate()`, so it never
    /// saw the argument and a seeded run that had stored a journey snapshot
    /// presented onboarding anyway — which made every seeded UI journey after a
    /// partial setup unreliable. Both paths now read this one property, so this
    /// covers the property rather than only the `evaluate()` path that already
    /// worked.
    func testSkipOnboardingLaunchArgumentSuppressesEveryPresentationPath() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let service = OnboardingEligibilityService(
            stateStore: context.store,
            launchArguments: ["-SKIP_ONBOARDING"],
            fetchLifeAreas: { [] },
            fetchProjects: { [] },
            fetchTasks: { [] }
        )

        XCTAssertTrue(
            service.isSuppressedByLaunchArgument,
            "The resume path consults this directly and cannot call evaluate()"
        )
        guard case .suppressed = await service.evaluate() else {
            return XCTFail("An empty workspace with -SKIP_ONBOARDING must stay suppressed")
        }

        let withoutArgument = OnboardingEligibilityService(
            stateStore: context.store,
            launchArguments: [],
            fetchLifeAreas: { [] },
            fetchProjects: { [] },
            fetchTasks: { [] }
        )
        XCTAssertFalse(
            withoutArgument.isSuppressedByLaunchArgument,
            "Suppression must come from the argument, not from being the default"
        )
    }

    func testEligibilityDoesNotInterruptEstablishedWorkspace() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let service = OnboardingEligibilityService(
            stateStore: context.store,
            launchArguments: [],
            fetchLifeAreas: { [LifeArea(name: "General"), LifeArea(name: "Career")] },
            fetchProjects: { [Project.createInbox(), Project(name: "Ship one thing")] },
            fetchTasks: {
                [
                    TaskDefinition(title: "Draft update"),
                    TaskDefinition(title: "Send recap"),
                    TaskDefinition(title: "Plan next step")
                ]
            }
        )

        // `.promptOnly` no longer means "present a modal". The coordinator routes
        // it to a dismissible Home invitation and the permanent Life Map card in
        // Life Management, so an established workspace is offered the map without
        // its launch being seized. Asserting `.suppressed` here would lock in the
        // behaviour where existing users were never told the Life Map exists.
        let result = await service.evaluate()
        // One custom area, not two: `isCustomLifeArea` excludes "General".
        XCTAssertEqual(result, .promptOnly(OnboardingWorkspaceSnapshot(
            customLifeAreaCount: 1,
            customProjectCount: 1,
            taskCount: 3
        )))

        // And "Not now" has to stick. This is the assertion that was missing
        // while `establishedWorkspacePromptDismissedVersion` was written by
        // `markEstablishedWorkspacePromptDismissed()` and read by nothing.
        context.store.markEstablishedWorkspacePromptDismissed()
        let afterDismissal = await service.evaluate()
        XCTAssertEqual(afterDismissal, .suppressed)
    }

    func testCompletedUserReceivesTheCurrentRefreshOnce() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        context.store.markHandled(outcome: .completed)

        let service = OnboardingEligibilityService(
            stateStore: context.store,
            launchArguments: [],
            fetchLifeAreas: { [LifeArea(name: "Career")] },
            fetchProjects: { [Project.createInbox(), Project(name: "Ship one thing")] },
            fetchTasks: { [TaskDefinition(title: "Draft update")] }
        )

        let result = await service.evaluate()
        XCTAssertEqual(result, .promptOnly(OnboardingWorkspaceSnapshot(
            customLifeAreaCount: 1,
            customProjectCount: 1,
            taskCount: 1
        )))

        context.store.markRefreshDismissed()
        let resultAfterDismissal = await service.evaluate()
        XCTAssertEqual(resultAfterDismissal, .suppressed)
    }

    @MainActor
    func testHealthAccessReportsRequestPresentationWithoutClaimingReadGrant() {
        var statuses = Dictionary(uniqueKeysWithValues: HealthDomain.allCases.map {
            ($0, HealthDomainStatus(domain: $0, readRequestState: .requestCompleted))
        })
        statuses[.hydration]?.writeAuthorizations[.water] = .authorized

        let access = HealthAccessState.resolve(statuses: statuses, hasObservableData: false)

        XCTAssertEqual(access.readState, .requestPresented)
        XCTAssertEqual(access.authorizedWriteCount, 1)
    }

    @MainActor
    func testSetupCenterExcludesDeferredNotificationsFromItsConnectionModel() {
        let statuses = Dictionary(uniqueKeysWithValues: HealthDomain.allCases.map {
            ($0, HealthDomainStatus(domain: $0, readRequestState: .requestCompleted))
        })
        let status = SetupCenterStatus.resolve(
            calendarAuthorization: .authorized,
            selectedCalendarCount: 1,
            healthStatuses: statuses,
            healthHasObservableData: false,
            evaAccessState: .ready,
            evaUsesOfflineProvider: false,
            offlineModelReady: false
        )

        XCTAssertEqual(status.snapshots.map(\.integration), [.calendar, .health, .eva])
        XCTAssertTrue(status.allRowsHandled)
    }

    func testDefaultLifeAreaSelectionRespectsFrictionProfileAndMode() {
        XCTAssertEqual(
            StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: .starting, mode: .guided),
            ["work-career", "health-self", "life-admin"]
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: .overwhelmed, mode: .guided),
            ["life-admin", "health-self", "work-career"]
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: .remembering, mode: .custom),
            ["life-admin"]
        )
    }

    func testOnboardingStepOrderUsesExplicitReorderedFlow() {
        XCTAssertEqual(
            OnboardingStep.orderedFlow,
            [.welcome, .intent, .lifeAreas, .guide, .dayShape, .modules, .firstWin, .permissions, .success]
        )
    }

    func testOnboardingProgressUsesOrderedFlowAsSingleSource() {
        XCTAssertEqual(OnboardingProgress(step: .welcome)?.label, "Step 1 of 9")
        XCTAssertEqual(OnboardingProgress(step: .intent)?.label, "Step 2 of 9")
        XCTAssertEqual(OnboardingProgress(step: .permissions)?.label, "Step 8 of 9")
        XCTAssertEqual(OnboardingProgress(step: .success)?.label, "Step 9 of 9")
        XCTAssertEqual(OnboardingStep.intent.accessibilitySummary, "Choose what needs attention. Step 2 of 9. Select one to continue.")
        XCTAssertEqual(OnboardingStep.success.accessibilitySummary, "Setup complete. Step 9 of 9. Go to Home.")
    }


    func testOnboardingCopyAvoidsGenericAIPhrases() {
        for copy in OnboardingCopy.reviewedStrings {
            XCTAssertFalse(copy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertLessThanOrEqual(copy.count, 120)
            for phrase in OnboardingCopy.regressionPhrases {
                XCTAssertFalse(
                    copy.localizedCaseInsensitiveContains(phrase),
                    "Copy should avoid generic phrase '\(phrase)': \(copy)"
                )
            }
        }
        XCTAssertEqual(OnboardingCopy.Welcome.changeLaterChip, "Change anything later")
    }

    @MainActor
    func testOnboardingAccentPairsMeetWCAGContrast() {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let tokens = Theme(index: 0).tokens.color

        XCTAssertGreaterThanOrEqual(contrast(tokens.actionPrimary, tokens.accentOnPrimary, traits: lightTraits), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(tokens.actionPrimary, tokens.accentOnPrimary, traits: darkTraits), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(tokens.actionPrimary, tokens.surfacePrimary, traits: lightTraits), 3.0)
        XCTAssertGreaterThanOrEqual(contrast(tokens.actionPrimary, tokens.surfacePrimary, traits: darkTraits), 3.0)
        XCTAssertGreaterThanOrEqual(contrast(tokens.textPrimary, tokens.surfacePrimary, traits: lightTraits), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(tokens.textPrimary, tokens.surfacePrimary, traits: darkTraits), 4.5)
    }

    func testVisibleLifeAreasCollapseToCoreAreasUntilExpanded() {
        XCTAssertEqual(
            StarterWorkspaceCatalog.visibleLifeAreas(for: .starting, showAll: false).map(\.id),
            ["work-career", "health-self", "life-admin"]
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.visibleLifeAreas(for: .starting, showAll: true).map(\.id),
            ["work-career", "health-self", "life-admin", "relationships", "learning-growth", "creativity-fun", "money"]
        )
    }


    @MainActor
    func testCatalogReuseMatchesAliasesForExistingLifeAreasAndProjects() {
        let healthTemplate = tryUnwrap(StarterWorkspaceCatalog.lifeAreaTemplate(id: "health-self"))
        let existingLifeArea = LifeArea(name: "Wellness")

        let matchedLifeArea = StarterWorkspaceCatalog.matchingLifeArea(
            for: healthTemplate,
            in: [existingLifeArea]
        )

        XCTAssertEqual(matchedLifeArea?.id, existingLifeArea.id)

        let careerDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["work-career"], mode: .guided).first
        )
        let lifeAreaID = UUID()
        let existingProject = Project(lifeAreaID: lifeAreaID, name: "Deliverable")

        let matchedProject = StarterWorkspaceCatalog.matchingProject(
            for: careerDraft,
            lifeAreaID: lifeAreaID,
            in: [existingProject]
        )

        XCTAssertEqual(matchedProject?.id, existingProject.id)
    }

    func testHabitSuggestionsStayPositiveFirstWithAtMostOneNegative() {
        let healthDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["health-self"], mode: .guided).first
        )
        let careerDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["work-career"], mode: .guided).first
        )

        let selections = [
            ResolvedProjectSelection(
                draft: healthDraft,
                project: Project(name: healthDraft.name),
                reusedExisting: false
            ),
            ResolvedProjectSelection(
                draft: careerDraft,
                project: Project(name: careerDraft.name),
                reusedExisting: false
            )
        ]

        let suggestions = StarterWorkspaceCatalog.habitSuggestions(for: selections, frictionProfile: .remembering)

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.first?.isPositive == true)
        XCTAssertLessThanOrEqual(suggestions.filter { $0.isPositive == false }.count, 1)
    }

    func testPrimaryRecommendationsMatchFrictionProfiles() {
        func selections(for profile: OnboardingFrictionProfile) -> [ResolvedProjectSelection] {
            let areaIDs = StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: profile, mode: .guided)
            return StarterWorkspaceCatalog.defaultProjectDrafts(
                for: areaIDs,
                frictionProfile: profile,
                mode: .guided
            ).map { draft in
                ResolvedProjectSelection(draft: draft, project: Project(name: draft.name), reusedExisting: false)
            }
        }

        XCTAssertEqual(
            StarterWorkspaceCatalog.taskSuggestions(for: selections(for: .starting), frictionProfile: .starting).first?.title,
            "Open the draft and write 3 lines"
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.taskSuggestions(for: selections(for: .choosing), frictionProfile: .choosing).first?.title,
            "Open one bill and check the due date"
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.taskSuggestions(for: selections(for: .remembering), frictionProfile: .remembering).first?.title,
            "Add one appointment to calendar"
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.taskSuggestions(for: selections(for: .finishing), frictionProfile: .finishing).first?.title,
            "Clear one surface"
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.taskSuggestions(for: selections(for: .overwhelmed), frictionProfile: .overwhelmed).first?.title,
            "Put away 5 things"
        )

        XCTAssertEqual(
            StarterWorkspaceCatalog.habitSuggestions(for: selections(for: .starting), frictionProfile: .starting).first?.title,
            "Drink water after you wake up"
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.habitSuggestions(for: selections(for: .choosing), frictionProfile: .choosing).first?.title,
            "Choose tomorrow's first work step"
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.habitSuggestions(for: selections(for: .remembering), frictionProfile: .remembering).first?.title,
            "Check appointments twice a week"
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.habitSuggestions(for: selections(for: .finishing), frictionProfile: .finishing).first?.title,
            "End the day by naming one \"must move\" item"
        )
        XCTAssertEqual(
            StarterWorkspaceCatalog.habitSuggestions(for: selections(for: .overwhelmed), frictionProfile: .overwhelmed).first?.title,
            "Do a 2-minute reset after work"
        )
    }

    func testStarterTaskMetadataUsesSpecificCategoryContextAndDueIntent() {
        let task = tryUnwrap(
            StarterWorkspaceCatalog.projectTemplate(id: "work-ship")?
                .taskTemplates
                .first(where: { $0.id == "task-career-ship-draft" })
        )

        XCTAssertEqual(task.category, .work)
        XCTAssertEqual(task.context, .computer)
        XCTAssertEqual(task.energy, .low)
        XCTAssertEqual(task.type, .morning)
        XCTAssertEqual(task.durationMinutes, 2)
        XCTAssertEqual(task.dueDateIntent, .today)
        XCTAssertTrue(task.isQuickWin)
    }

    func testOptionalAreaSelectionsStillProduceTaskAndHabitSuggestions() {
        let drafts = StarterWorkspaceCatalog.defaultProjectDrafts(
            for: ["relationships", "creativity-fun"],
            mode: .guided
        )
        let selections = drafts.map {
            ResolvedProjectSelection(draft: $0, project: Project(name: $0.name), reusedExisting: false)
        }

        XCTAssertFalse(StarterWorkspaceCatalog.taskSuggestions(for: selections, frictionProfile: nil).isEmpty)
        XCTAssertFalse(StarterWorkspaceCatalog.habitSuggestions(for: selections, frictionProfile: nil).isEmpty)
    }

    @MainActor
    func testJourneySnapshotDecodeDefaultsMissingEntryContextToFreshFlow() throws {
        let snapshot = OnboardingJourneySnapshot(
            step: .intent,
            mode: .guided,
            selectedLifeAreaIDs: ["health-self"],
            showAllLifeAreas: false,
            projectDrafts: [],
            resolvedLifeAreas: [],
            resolvedProjects: [],
            createdTasks: [],
            createdTaskTemplateMap: [:],
            hasSeenSuccess: false
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var legacyObject = object
        legacyObject.removeValue(forKey: "entryContext")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let decoded = try JSONDecoder().decode(OnboardingJourneySnapshot.self, from: legacyData)
        XCTAssertEqual(decoded.entryContext, .freshFlow)
    }





    @MainActor
    func testMarkHandledClearsPersistedJourneySnapshot() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let snapshot = OnboardingJourneySnapshot(
            step: .welcome,
            mode: .guided,
            selectedLifeAreaIDs: [],
            showAllLifeAreas: false,
            projectDrafts: [],
            expandedProjectIDs: [],
            resolvedLifeAreas: [],
            resolvedProjects: [],
            createdTasks: [],
            createdTaskTemplateMap: [:],
            focusTaskID: nil,
            successSummary: nil,
            hasSeenSuccess: false,
        )

        context.store.storeJourney(snapshot)
        context.store.markHandled(outcome: .completed)

        let state = context.store.load()
        XCTAssertEqual(state.outcome, .completed)
        XCTAssertEqual(state.completedVersion, AppOnboardingState.currentVersion)
        XCTAssertNil(state.journeySnapshot)
        XCTAssertTrue(state.hasHandledCurrentVersion)
    }

    @MainActor
    func testLifeWeaveFinalizationIsTheOnlyCoreCompletionBoundary() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        var draft = LifeWeaveDraft()
        draft.step = .reveal
        draft.lifecyclePhase = .revealReady
        context.store.storeLifeWeaveJourney(draft)

        XCTAssertNil(context.store.load().outcome)
        context.store.finalizeLifeWeave(entryContext: .freshFlow, destination: .setupCenter)

        let finalized = context.store.load()
        XCTAssertEqual(finalized.outcome, .completed)
        XCTAssertEqual(finalized.completedVersion, AppOnboardingState.currentVersion)
        XCTAssertEqual(finalized.finalizedLifeWeaveDestination, .setupCenter)
        XCTAssertEqual(finalized.needsFinalizedDestinationDelivery, true)
        XCTAssertNil(finalized.lifeWeaveJourneySnapshot)
    }

    /// The whole reason the boundary is split.
    ///
    /// Core is a promise that a finished LifeBoard needs no permission, account,
    /// or network — so it has to be recorded *before* the first connector is
    /// offered. Between here and finalization a journey is legitimately both
    /// completed and resumable, which is what puts someone who force-quits during
    /// Calendar back on Calendar rather than on Home with the phase lost.
    @MainActor
    func testCompleteCoreRecordsCompletionButKeepsTheJourneyResumable() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        var draft = LifeWeaveDraft()
        draft.step = .reveal
        draft.lifecyclePhase = .poweringUp
        draft.powerUpStep = .calendar
        context.store.storeLifeWeaveJourney(draft)

        context.store.completeCore(entryContext: .freshFlow)

        let state = context.store.load()
        XCTAssertEqual(state.outcome, .completed)
        XCTAssertEqual(state.completedVersion, AppOnboardingState.currentVersion)
        XCTAssertEqual(state.completedLifeWeave, true)
        XCTAssertNotNil(state.lifeWeaveJourneySnapshot, "the power-up phase is still resumable")
        XCTAssertEqual(state.lifeWeaveJourneySnapshot?.powerUpStep, .calendar)
        XCTAssertTrue(state.hasResumableJourney)
        XCTAssertNil(state.finalizedLifeWeaveDestination, "nothing has ended yet")
        XCTAssertNil(state.needsFinalizedDestinationDelivery)
    }

    /// Re-entering the reveal must not record a second core completion.
    @MainActor
    func testCompleteCoreIsIdempotent() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        XCTAssertTrue(context.store.completeCore(entryContext: .freshFlow))
        XCTAssertFalse(context.store.completeCore(entryContext: .freshFlow))
        XCTAssertEqual(context.store.load().completedVersion, AppOnboardingState.currentVersion)
    }

    /// Finishing after a power-up phase clears the snapshot and names where the
    /// user lands, without disturbing the completion already on record.
    @MainActor
    func testFinalizationAfterCompleteCoreClearsTheSnapshotAndNamesADestination() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        var draft = LifeWeaveDraft()
        draft.powerUpStep = .complete
        context.store.storeLifeWeaveJourney(draft)
        context.store.completeCore(entryContext: .freshFlow)
        context.store.finalizeLifeWeave(entryContext: .freshFlow, destination: .eva)

        let state = context.store.load()
        XCTAssertEqual(state.outcome, .completed)
        XCTAssertEqual(state.finalizedLifeWeaveDestination, .eva)
        XCTAssertEqual(state.needsFinalizedDestinationDelivery, true)
        XCTAssertNil(state.lifeWeaveJourneySnapshot)
        XCTAssertFalse(state.hasResumableJourney)
    }

    /// The version bump to 7 must not drag finished users back through setup.
    /// Eligibility asks whether a completion exists, never whether it matches
    /// the current number.
    @MainActor
    func testAUserWhoFinishedUnderVersionSixIsNotReOnboarded() {
        let context = makeStoreContext()
        defer { context.cleanup() }
        context.store.markHandled(outcome: .completed, version: 6)

        let state = context.store.load()
        XCTAssertNotNil(state.completedVersion)
        XCTAssertNotNil(state.outcome)
        XCTAssertFalse(state.hasHandledCurrentVersion, "not the current version…")
        XCTAssertNotEqual(state.completedVersion, AppOnboardingState.currentVersion)
        // …but eligibility keys off existence, which is what keeps them finished.
        XCTAssertTrue(state.completedVersion != nil && state.outcome != nil)
    }

    @MainActor
    func testRefreshFinalizationDoesNotRewriteCoreCompletion() {
        let context = makeStoreContext()
        defer { context.cleanup() }
        context.store.markHandled(outcome: .completed, version: 4)

        var refresh = LifeWeaveDraft()
        refresh.entryContext = .establishedWorkspace
        refresh.lifecyclePhase = .revealReady
        context.store.storeRefreshDraft(refresh)
        context.store.finalizeLifeWeave(entryContext: .establishedWorkspace, destination: .home)

        let state = context.store.load()
        XCTAssertEqual(state.completedVersion, 4)
        XCTAssertEqual(state.completedRefreshVersion, AppOnboardingState.currentLifeWeaveRefreshVersion)
        XCTAssertNil(state.refreshDraft)
    }

    private func makeStoreContext() -> StoreContext {
        let suiteName = "AppOnboardingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = AppOnboardingStateStore(userDefaults: defaults)
        return StoreContext(store: store) {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected value to exist", file: file, line: line)
            fatalError("Unreachable after XCTFail")
        }
        return value
    }

    private func contrast(_ foreground: UIColor, _ background: UIColor, traits: UITraitCollection) -> CGFloat {
        let fg = foreground.resolvedColor(with: traits)
        let bg = background.resolvedColor(with: traits)
        return contrastRatio(fg, bg)
    }
}

@MainActor
final class LifeMapOnboardingTests: XCTestCase {
    /// Core still ends at the reveal.
    ///
    /// The connect chain and EVA activation stay *outside* core. Version 7 adds
    /// an optional Power-Up phase after the commit, which does not weaken this:
    /// core completion is recorded by `completeCore` before the first connector
    /// is offered, so it still depends on no permission, download, or network.
    func testDraftUsesV5SnapshotSchemaAndCoreStillEndsAtReveal() {
        XCTAssertEqual(AppOnboardingState.currentVersion, 7)
        XCTAssertEqual(LifeMapDraft().schemaVersion, 7)
        XCTAssertEqual(LifeMapOnboardingStep.core.first, .welcome)
        XCTAssertEqual(LifeMapOnboardingStep.core.last, .reveal)
        XCTAssertFalse(LifeMapOnboardingStep.reveal.isPowerUp)
        XCTAssertTrue(LifeMapOnboardingStep.calendar.isPowerUp)
        XCTAssertTrue(LifeMapOnboardingStep.eva.isPowerUp)
        XCTAssertFalse(LifeMapOnboardingStep.tour.isPowerUp)
        XCTAssertTrue(LifeMapOnboardingStep.tour.isClosing)
        XCTAssertTrue(LifeMapOnboardingStep.firstWin.isClosing)
    }

    /// A power-up whose module was never chosen must not appear.
    func testPowerUpChainOmitsStepsNoChosenModuleNeeds() {
        let noExtras = LifeMapOnboardingStep.visiblePowerUps(
            requestablePermissions: [.calendar],
            includesEva: false
        )
        XCTAssertEqual(noExtras, [.calendar])

        let everything = LifeMapOnboardingStep.visiblePowerUps(
            requestablePermissions: [.notifications, .calendar, .appleHealth],
            includesEva: true
        )
        XCTAssertEqual(everything, [.calendar, .health, .reminders, .eva])
    }

    func testLifeAreaSelectionStaysBetweenTwoAndFiveAndPreservesOrder() {
        let harness = makeLifeMapHarness()
        let areas = StarterWorkspaceCatalog.allLifeAreas
        for area in areas.prefix(6) { harness.model.toggleLifeArea(area) }
        XCTAssertEqual(harness.model.draft.orderedLifeAreaTemplateIDs.count, 5)
        XCTAssertEqual(harness.model.draft.orderedLifeAreaTemplateIDs, areas.prefix(5).map(\.id))

        for area in areas.prefix(4) { harness.model.toggleLifeArea(area) }
        XCTAssertEqual(harness.model.draft.orderedLifeAreaTemplateIDs.count, 2)
        harness.cleanup()
    }

    func testLifeMapSnapshotResumesAndVersionThreeJourneyDoesNot() {
        let harness = makeLifeMapHarness()
        var draft = LifeMapDraft()
        draft.step = .capacity
        draft.desiredChange = .clearHead
        draft.orderedLifeAreaTemplateIDs = ["life-admin", "work-career"]
        harness.model.prepareForPresentation(snapshot: draft)
        XCTAssertEqual(harness.model.step, .capacity)
        XCTAssertEqual(harness.model.sceneModel.lifeAreas.map(\.id), ["life-admin", "work-career"])

        var invalid = draft
        invalid.schemaVersion = 3
        harness.model.prepareForPresentation(snapshot: invalid)
        XCTAssertEqual(harness.model.step, .welcome)

        // Schema 6 held the two retired power-up steps and an optimistic
        // permission list; there is no honest translation, so it restarts too.
        var schemaSix = draft
        schemaSix.schemaVersion = 6
        harness.model.prepareForPresentation(snapshot: schemaSix)
        XCTAssertEqual(harness.model.step, .welcome)
        harness.cleanup()
    }

    func testCommitRetryDoesNotDuplicateAreasOrCaptureOrFinalizeOnCanonicalWrite() async throws {
        enum InjectedFailure: Error { case workingHours }

        let suite = "life.map.commit.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let stateStore = AppOnboardingStateStore(userDefaults: defaults)
        var areas: [LifeArea] = []
        var createdAreaCount = 0
        var createdTaskCount = 0
        var failWorkingHoursOnce = true

        let coordinator = LifeMapCommitCoordinator(
            dependencies: .init(
                fetchLifeAreas: { areas },
                createLifeArea: { template in
                    createdAreaCount += 1
                    let area = LifeArea(name: template.name, color: template.colorHex, icon: template.icon)
                    areas.append(area)
                    return area
                },
                updateLifeArea: { updated in
                    if let index = areas.firstIndex(where: { $0.id == updated.id }) { areas[index] = updated }
                    return updated
                },
                fetchTask: { _ in nil },
                createTask: { request in
                    createdTaskCount += 1
                    return request.toTaskDefinition(projectName: request.projectName)
                },
                fetchReflection: { _ in nil },
                saveReflection: { $0 },
                saveWorkingHours: { _ in
                    if failWorkingHoursOnce {
                        failWorkingHoursOnce = false
                        throw InjectedFailure.workingHours
                    }
                },
                fetchHomeLayout: { nil },
                saveHomeLayout: { _ in }
            ),
            stateStore: stateStore,
            profileStore: LifeMapProfileStore(defaults: defaults),
            preferencesStore: WorkspacePreferencesStore(defaults: defaults)
        )

        var draft = LifeMapDraft()
        draft.desiredChange = .seeWeek
        draft.frictionIDs = [LifeMapFriction.scattered.id]
        draft.orderedLifeAreaTemplateIDs = ["work-career", "life-admin"]
        draft.moduleGroupIDs = [LifeMapModuleGroup.planFocus.id]
        draft.stagedCapture = LifeMapStagedCapture(
            id: UUID(),
            text: "Book a dentist appointment",
            kind: .task,
            lifeAreaTemplateID: "life-admin",
            isReviewed: true
        )

        do {
            _ = try await coordinator.commit(draft)
            XCTFail("The injected write failure should escape")
        } catch InjectedFailure.workingHours {
            XCTAssertNil(stateStore.load().outcome)
            XCTAssertEqual(createdTaskCount, 0, "Capture must remain the final write")
        }

        _ = try await coordinator.commit(draft)
        XCTAssertEqual(createdAreaCount, 2, "Retry must match canonical areas instead of duplicating them")
        XCTAssertEqual(createdTaskCount, 1)
        XCTAssertNil(stateStore.load().outcome, "The reveal exit owns finalization, not the canonical writer")
    }

    /// The regression that made every Metal effect invisible.
    ///
    /// `ShaderReadiness` was a `@MainActor enum` with `static var` storage. Warm-up
    /// runs on a detached task and completes *after* first render, so when it
    /// flipped `engineReady` there was nothing to invalidate — a `static var`
    /// read is not an observation-tracked access. Every view gated on it kept
    /// its "not ready" answer for the whole session.
    ///
    /// This asserts the observation, not the value: the value was always
    /// correct, and that is exactly why the bug survived.
    @MainActor
    func testShaderReadinessPublishesAnObservableChange() {
        let store = ShaderReadinessStore.shared
        store.publishEngineReady(false, reason: "test reset")
        XCTAssertFalse(store.allowsShaderRendering)

        // `onChange` is `@Sendable`, so the signal has to leave the closure
        // through something concurrency-safe.
        let observed = expectation(description: "readiness change invalidates observers")
        withObservationTracking {
            _ = store.allowsShaderRendering
        } onChange: {
            observed.fulfill()
        }

        store.publishEngineReady(true)
        wait(for: [observed], timeout: 1)
        XCTAssertTrue(store.allowsShaderRendering)
        XCTAssertNil(store.unavailabilityReason)

        store.publishEngineReady(false, reason: "Low Power Mode.")
        XCTAssertEqual(store.unavailabilityReason, "Low Power Mode.")
        store.publishEngineReady(true)
    }

    /// Calm must still suppress shaders through the observable path.
    @MainActor
    func testCalmComfortProfileSuppressesShaderRendering() {
        let store = ShaderReadinessStore.shared
        store.publishEngineReady(true)
        store.publishComfort(profile: .calm)
        XCTAssertFalse(store.allowsShaderRendering, "Calm drops the Metal layer")
        store.publishComfort(profile: .balanced)
        XCTAssertTrue(store.allowsShaderRendering)
    }

    /// A retry must resume from the recorded phase, not replay writes that
    /// already landed. `preferencesStore.update` and `profileStore.save` are
    /// unconditional overwrites with no rollback, so replaying them would
    /// clobber state a merge-mode user already had.
    func testCommitRetryResumesFromRecordedPhaseInsteadOfReplayingWrites() async throws {
        enum InjectedFailure: Error { case layout }

        let suite = "life.map.resume.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let stateStore = AppOnboardingStateStore(userDefaults: defaults)

        var areas: [LifeArea] = []
        var workingHoursWrites = 0
        var layoutWrites = 0
        var failLayoutOnce = true

        let coordinator = LifeMapCommitCoordinator(
            dependencies: .init(
                fetchLifeAreas: { areas },
                createLifeArea: { template in
                    let area = LifeArea(name: template.name, color: template.colorHex, icon: template.icon)
                    areas.append(area)
                    return area
                },
                updateLifeArea: { updated in
                    if let index = areas.firstIndex(where: { $0.id == updated.id }) { areas[index] = updated }
                    return updated
                },
                fetchTask: { _ in nil },
                createTask: { $0.toTaskDefinition(projectName: $0.projectName) },
                fetchReflection: { _ in nil },
                saveReflection: { $0 },
                saveWorkingHours: { _ in workingHoursWrites += 1 },
                fetchHomeLayout: { nil },
                saveHomeLayout: { _ in
                    if failLayoutOnce {
                        failLayoutOnce = false
                        throw InjectedFailure.layout
                    }
                    layoutWrites += 1
                }
            ),
            stateStore: stateStore,
            profileStore: LifeMapProfileStore(defaults: defaults),
            preferencesStore: WorkspacePreferencesStore(defaults: defaults)
        )

        var draft = LifeMapDraft()
        draft.desiredChange = .seeWeek
        draft.orderedLifeAreaTemplateIDs = ["work-career", "life-admin"]

        // Capture partial progress the way `assemble()` does.
        var partial = draft
        do {
            _ = try await coordinator.commit(draft) { partial = $0 }
            XCTFail("The injected layout failure should escape")
        } catch InjectedFailure.layout {
            XCTAssertEqual(workingHoursWrites, 1)
            XCTAssertEqual(partial.commitPhase, .capacityWritten, "Progress must survive the throw")
            XCTAssertNil(stateStore.load().outcome, "Completion must not be marked early")
        }

        _ = try await coordinator.commit(partial)
        XCTAssertEqual(workingHoursWrites, 1, "Capacity already landed; the retry must not rewrite it")
        XCTAssertEqual(layoutWrites, 1)
        XCTAssertEqual(areas.count, 2, "Retry must match canonical areas rather than duplicate them")
        XCTAssertNil(stateStore.load().outcome, "The reveal exit owns finalization, not the canonical writer")
    }

    /// Merge mode must not overwrite a Home the user already arranged.
    func testEstablishedWorkspaceCommitMergesHomeLayoutInsteadOfReplacingIt() async throws {
        let suite = "life.map.merge.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let existingKind = "userArrangedCard"
        let existing = DashboardLayoutValue(
            mode: .smart,
            isDefault: false,
            placements: [DashboardWidgetPlacementValue(widgetKind: existingKind, semanticSize: .wide, ordinal: 0)]
        )
        var saved: DashboardLayoutValue?
        var workingHoursWrites = 0

        let coordinator = LifeMapCommitCoordinator(
            dependencies: .init(
                fetchLifeAreas: { [] },
                createLifeArea: { LifeArea(name: $0.name, color: $0.colorHex, icon: $0.icon) },
                updateLifeArea: { $0 },
                fetchTask: { _ in nil },
                createTask: { $0.toTaskDefinition(projectName: $0.projectName) },
                fetchReflection: { _ in nil },
                saveReflection: { $0 },
                saveWorkingHours: { _ in workingHoursWrites += 1 },
                fetchHomeLayout: { existing },
                saveHomeLayout: { saved = $0 }
            ),
            stateStore: AppOnboardingStateStore(userDefaults: defaults),
            profileStore: LifeMapProfileStore(defaults: defaults),
            preferencesStore: WorkspacePreferencesStore(defaults: defaults)
        )

        var draft = LifeMapDraft()
        draft.entryContext = .establishedWorkspace
        draft.desiredChange = .seeWeek
        draft.orderedLifeAreaTemplateIDs = ["work-career", "life-admin"]
        draft.moduleGroupIDs = [LifeMapModuleGroup.planFocus.id]

        _ = try await coordinator.commit(draft)

        let savedKinds = try XCTUnwrap(saved).placements.map(\.widgetKind)
        XCTAssertTrue(savedKinds.contains(existingKind), "The user's existing card must survive a merge-mode commit")
        XCTAssertGreaterThan(savedKinds.count, 1, "Recommended modules should still be appended")
        XCTAssertEqual(
            workingHoursWrites, 0,
            "An established user who never edited capacity must not have their week rewritten"
        )
    }

    // MARK: - Power-up chain

    /// The defect this whole step exists to fix.
    ///
    /// `FilterCalendarEventsUseCase` reads an empty selection as *no calendars*,
    /// and nothing else in the app seeds one, so granting access without also
    /// choosing calendars produced an empty schedule everywhere — including in
    /// the projection EVA reasons over.
    func testGrantingCalendarNeverLeavesTheSelectionEmpty() async {
        let harness = makeLifeMapHarness(powerUps: LifeMapPowerUpDependencies(
            requestCalendarAccess: { true },
            availableCalendars: {
                [
                    CalendarSourceSnapshot(id: "work", title: "Work", sourceTitle: "iCloud", allowsContentModifications: true),
                    CalendarSourceSnapshot(id: "home", title: "Home", sourceTitle: "iCloud", allowsContentModifications: true)
                ]
            }
        ))
        let granted = await harness.model.requestPermission(.calendar)

        XCTAssertTrue(granted)
        XCTAssertEqual(harness.model.draft.selectedCalendarIDs, ["home", "work"])
        XCTAssertTrue(harness.model.isGranted(.calendar))
        harness.cleanup()
    }

    /// A refusal used to paint a green "Connected" checkmark.
    func testDeniedPermissionIsRecordedAsDeniedNotGranted() async {
        let harness = makeLifeMapHarness(powerUps: LifeMapPowerUpDependencies(
            requestCalendarAccess: { false },
            requestNotificationAccess: { false }
        ))
        _ = await harness.model.requestPermission(.calendar)
        _ = await harness.model.requestPermission(.notifications)

        XCTAssertFalse(harness.model.isGranted(.calendar))
        XCTAssertTrue(harness.model.isDenied(.calendar))
        XCTAssertFalse(harness.model.isGranted(.notifications))
        XCTAssertTrue(harness.model.isDenied(.notifications))
        XCTAssertTrue(harness.model.draft.selectedCalendarIDs.isEmpty)
        harness.cleanup()
    }

    /// Reading is not permission to write.
    func testHealthConnectsForReadingWithoutEnablingWriteBack() async {
        var writeBackRequested: [Bool] = []
        let harness = makeLifeMapHarness(powerUps: LifeMapPowerUpDependencies(
            connectHealth: { _, enableWriteBack in writeBackRequested.append(enableWriteBack) }
        ))
        _ = await harness.model.requestPermission(.appleHealth)

        XCTAssertEqual(writeBackRequested, [false])
        XCTAssertTrue(harness.model.draft.healthWriteBackDomainIDs.isEmpty)
        harness.cleanup()
    }

    func testWriteBackIsRecordedOnlyForDomainsTheUserTicked() async {
        var enabled: [String: Bool] = [:]
        let harness = makeLifeMapHarness(powerUps: LifeMapPowerUpDependencies(
            setHealthWriteEnabled: { isOn, domain in enabled[domain.id] = isOn }
        ))
        await harness.model.setHealthWriteBack(true, for: .hydration)

        XCTAssertEqual(harness.model.draft.healthWriteBackDomainIDs, ["hydration"])
        XCTAssertEqual(enabled, ["hydration": true])

        await harness.model.setHealthWriteBack(false, for: .hydration)
        XCTAssertTrue(harness.model.draft.healthWriteBackDomainIDs.isEmpty)
        XCTAssertEqual(enabled["hydration"], false)
        harness.cleanup()
    }

    /// Every power-up step was a one-way door before.
    func testBackNavigationWalksThePowerUpChain() async {
        let harness = makeLifeMapHarness()
        harness.model.enterPowerUps()
        let chain = harness.model.visiblePowerUps
        XCTAssertEqual(harness.model.step, chain.first)
        XCTAssertFalse(harness.model.canGoBack, "The first power-up has nowhere honest to go back to")

        guard chain.count > 1 else { return harness.cleanup() }
        _ = await harness.model.advance()
        XCTAssertTrue(harness.model.canGoBack)
        harness.model.goBack()
        XCTAssertEqual(harness.model.step, chain.first)
        harness.cleanup()
    }

    /// Declining every connection must still run the closing phase — that user
    /// most needs the orientation and the staged openers, not least of all.
    func testSkippingThePowerUpsStillReachesTheClosingPhase() {
        let harness = makeLifeMapHarness()
        harness.model.enterPowerUps()
        harness.model.skipToClosing()
        XCTAssertEqual(harness.model.step, .tour)
        harness.cleanup()
    }

    // MARK: - EVA hand-off

    /// The opener names only what the user actually supplied.
    func testOpeningPromptOmitsFactsTheDraftDoesNotHave() {
        var draft = LifeMapDraft()
        draft.desiredChange = .seeWeek
        draft.frictionIDs = [LifeMapFriction.scattered.id]

        let bare = LifeMapEvaOpeningPrompt.openingSubmission(for: draft, upcomingEventCount: nil)
        XCTAssertTrue(bare.contains("see my whole week clearly"))
        XCTAssertTrue(bare.contains("everything lives in different places"))
        XCTAssertFalse(bare.contains("on my calendar"), "No calendar was connected")
        XCTAssertFalse(bare.contains("I've put one thing in"), "Nothing was captured")
        XCTAssertTrue(bare.hasSuffix("where should I start?"))

        draft.stagedCapture = LifeMapStagedCapture(text: "Book dentist", kind: .task, isReviewed: true)
        let full = LifeMapEvaOpeningPrompt.openingSubmission(for: draft, upcomingEventCount: 7)
        XCTAssertTrue(full.contains("7 things already on my calendar"))
        XCTAssertTrue(full.contains("Book dentist"))
    }

    func testOpeningPromptsDropAlternatesThatHaveNoGrounding() {
        var draft = LifeMapDraft()
        draft.desiredChange = .knowNext

        let bare = LifeMapEvaOpeningPrompt.prompts(for: draft, upcomingEventCount: nil)
        XCTAssertEqual(bare.map(\.id), ["lifemap_where_to_start"])
        XCTAssertTrue(bare[0].isRecommended)

        draft.orderedLifeAreaTemplateIDs = ["health-self"]
        draft.stagedCapture = LifeMapStagedCapture(text: "Book dentist", kind: .task, isReviewed: true)
        let full = LifeMapEvaOpeningPrompt.prompts(for: draft, upcomingEventCount: 3)
        XCTAssertEqual(
            full.map(\.id),
            [
                "lifemap_where_to_start",
                "lifemap_crowding_week",
                "lifemap_break_down_capture",
                "lifemap_protect_top_area"
            ]
        )
    }

    /// The mapping is lossy, so the user's own words have to survive it.
    func testLifeMapProfileCarriesLiteralWordingAlongsideTheEnumMapping() {
        var draft = LifeMapDraft()
        draft.desiredChange = .clearHead
        draft.frictionIDs = [LifeMapFriction.scattered.id, LifeMapFriction.plansBreak.id]
        draft.orderedLifeAreaTemplateIDs = ["health-self", "work-career"]

        let profile = LifeMapEvaProfileMapper.profileDraft(from: draft)
        XCTAssertEqual(profile.selectedWorkingStyleIDs, [EvaWorkingStyleID.concise.rawValue])
        XCTAssertEqual(
            profile.selectedMomentumBlockerIDs,
            [EvaMomentumBlockerID.contextSwitching.rawValue, EvaMomentumBlockerID.loseSteamMidDay.rawValue]
        )
        XCTAssertEqual(profile.customWorkingStyleNote, LifeMapDesiredChange.clearHead.title)
        XCTAssertTrue(profile.customMomentumNote?.contains(LifeMapFriction.scattered.title) == true)
        XCTAssertTrue(profile.goals.contains { $0.contains("in that order") })

        // Stable across repeated derivation — the write is guarded, but the
        // mapping itself must not drift either.
        XCTAssertEqual(profile, LifeMapEvaProfileMapper.profileDraft(from: draft))
    }

    func testOpeningPromptStoreDrainsExactlyOnce() {
        let suite = "eva.opening.prompt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        EvaOpeningPromptStore.stage([EvaStarterPrompt.dayOverviewPrompt], defaults: defaults)
        XCTAssertEqual(EvaOpeningPromptStore.load(defaults: defaults).map(\.id), ["day_overview"])

        EvaOpeningPromptStore.clear(defaults: defaults)
        XCTAssertTrue(EvaOpeningPromptStore.load(defaults: defaults).isEmpty)
    }

    private func makeLifeMapHarness(
        powerUps: LifeMapPowerUpDependencies = LifeMapPowerUpDependencies()
    ) -> (model: LifeMapOnboardingModel, cleanup: () -> Void) {
        let suite = "life.map.tests.\(UUID().uuidString)"
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
        let model = LifeMapOnboardingModel(
            stateStore: store,
            commitCoordinator: commit,
            feedback: OnboardingFeedbackController(),
            powerUps: powerUps
        )
        model.prepareForPresentation(snapshot: nil)
        return (model, { defaults.removePersistentDomain(forName: suite) })
    }
}

private struct StoreContext {
    let store: AppOnboardingStateStore
    let cleanup: () -> Void
}

private final class TestNotificationService: NotificationServiceProtocol {
    var status: NotificationAuthorizationStatus
    var permissionGranted = true
    private(set) var requestPermissionCallCount = 0

    init(status: NotificationAuthorizationStatus) {
        self.status = status
    }

    func scheduleTaskReminder(taskId: UUID, taskName: String, at date: Date) {}
    func cancelTaskReminder(taskId: UUID) {}
    func cancelAllReminders() {}
    func send(_ notification: CollaborationNotification) {}
    func requestPermission(completion: @escaping @Sendable (Bool) -> Void) {
        requestPermissionCallCount += 1
        completion(permissionGranted)
    }
    func checkAuthorizationStatus(completion: @escaping @Sendable (Bool) -> Void) {
        completion(status == .authorized || status == .provisional || status == .ephemeral)
    }
    func schedule(request: LocalNotificationRequest) {}
    func cancel(ids: [String]) {}
    func pendingRequests(completion: @escaping @Sendable ([PendingNotificationRequest]) -> Void) { completion([]) }
    func registerCategories(_ categories: Set<UNNotificationCategory>) {}
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate?) {}
    func fetchAuthorizationStatus(completion: @escaping @Sendable (NotificationAuthorizationStatus) -> Void) {
        completion(status)
    }
}

// MARK: - Rebuilt flow contracts

/// Covers the behaviour the nine-step flow introduced: the module selection that
/// decides the Home layout, the day shape that finally writes a working-hours
/// profile, and the permission semantics that distinguish "skipped in a wall of
/// prompts" from "refused in context".
final class OnboardingRebuiltFlowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PermissionPromptState.resetAll()
    }

    override func tearDown() {
        PermissionPromptState.resetAll()
        super.tearDown()
    }

    // MARK: Modules → Home layout

    func testHomeLayoutOmitsCardsForModulesTheUserDidNotChoose() {
        let placements = OnboardingModuleCatalog.homePlacements(for: [])
        let kinds = placements.map(\.widgetKind)

        // The spine is always present so Home is never blank.
        XCTAssertTrue(kinds.contains(DashboardWidgetKind.focusNow.rawValue))
        XCTAssertTrue(kinds.contains(DashboardWidgetKind.tasks.rawValue))
        XCTAssertTrue(kinds.contains(DashboardWidgetKind.setupChecklist.rawValue))

        // Module cards must not be placed for modules that were not selected —
        // this is what stopped seven of ten default cards rendering empty.
        XCTAssertFalse(kinds.contains(DashboardWidgetKind.journal.rawValue))
        XCTAssertFalse(kinds.contains(DashboardWidgetKind.fasting.rawValue))
        XCTAssertFalse(kinds.contains(DashboardWidgetKind.lifeMoment.rawValue))
    }

    func testChoosingAModulePlacesItsHomeCards() throws {
        let journal = try XCTUnwrap(OnboardingModuleCatalog.module(id: OnboardingModuleCatalog.journalID))
        let kinds = OnboardingModuleCatalog
            .homePlacements(for: [journal.id])
            .map(\.widgetKind)
        XCTAssertTrue(kinds.contains(DashboardWidgetKind.journal.rawValue))
    }

    func testHomeLayoutNeverPlacesTheSameCardTwice() {
        let everyModule = Set(OnboardingModuleCatalog.all.map(\.id))
        let kinds = OnboardingModuleCatalog.homePlacements(for: everyModule).map(\.widgetKind)
        XCTAssertEqual(kinds.count, Set(kinds).count, "A duplicated card would occupy two slots for one source")
    }

    // MARK: Modules → permissions

    func testCalendarIsAlwaysOfferedBecauseTwoDefaultCardsDependOnIt() {
        XCTAssertTrue(OnboardingModuleCatalog.requestablePermissions(for: []).contains(.calendar))
    }

    func testHealthIsOnlyOfferedWhenAModuleActuallyUsesIt() {
        XCTAssertFalse(OnboardingModuleCatalog.requestablePermissions(for: []).contains(.appleHealth))
        XCTAssertTrue(
            OnboardingModuleCatalog.healthDomains(for: [OnboardingModuleCatalog.hydrationID])
                .contains(.hydration)
        )
    }

    func testPointOfUsePermissionsAreNamedButNotRequestable() {
        let selection: Set<String> = [OnboardingModuleCatalog.journalID]
        XCTAssertTrue(OnboardingModuleCatalog.pointOfUsePermissions(for: selection).contains(.microphone))
        XCTAssertFalse(OnboardingModuleCatalog.requestablePermissions(for: selection).contains(.microphone))
    }

    // MARK: Day shape

    func testDayShapeWritesWeekdayIntervalsAndHonoursTheWeekendToggle() {
        var draft = OnboardingDayShapeDraft()
        draft.weekdayStartMinute = 10 * 60
        draft.weekdayEndMinute = 16 * 60
        draft.worksWeekends = false

        let profile = draft.makeProfile()
        // Calendar weekday indices: 1 = Sunday, 7 = Saturday.
        XCTAssertEqual(profile.intervalsByWeekday[2]?.first?.startMinute, 10 * 60)
        XCTAssertEqual(profile.intervalsByWeekday[2]?.first?.endMinute, 16 * 60)
        XCTAssertNil(profile.intervalsByWeekday[1])
        XCTAssertNil(profile.intervalsByWeekday[7])
    }

    func testDayShapeNeverProducesAnIntervalThatEndsBeforeItStarts() {
        var draft = OnboardingDayShapeDraft()
        draft.weekdayStartMinute = 18 * 60
        draft.weekdayEndMinute = 6 * 60

        let interval = draft.makeProfile().intervalsByWeekday[2]?.first
        XCTAssertNotNil(interval)
        XCTAssertGreaterThanOrEqual(interval?.endMinute ?? 0, interval?.startMinute ?? 0)
    }

    // MARK: Permission semantics

    func testSkippingInOnboardingIsNotCountedAsARefusal() {
        PermissionPromptState.recordOnboardingDeferral(.notifications)

        XCTAssertTrue(PermissionPromptState.wasDeferredInOnboarding(.notifications))
        XCTAssertEqual(PermissionPromptState.declineCount(.notifications), 0)
        XCTAssertNil(PermissionPromptState.snoozedUntil(.notifications))
        // The point of the distinction: the feature may still ask once, in context.
        XCTAssertTrue(PermissionPromptState.shouldOffer(.notifications))
    }

    func testRefusingInContextSnoozesAndEventuallyStopsOffering() {
        let now = Date()
        PermissionPromptState.recordDecline(.notifications, now: now)
        XCTAssertFalse(PermissionPromptState.shouldOffer(.notifications, now: now.addingTimeInterval(60)))

        let afterSnooze = now.addingTimeInterval(PermissionPromptState.snoozeInterval + 1)
        XCTAssertTrue(PermissionPromptState.shouldOffer(.notifications, now: afterSnooze))

        PermissionPromptState.recordDecline(.notifications, now: afterSnooze)
        XCTAssertFalse(
            PermissionPromptState.shouldOffer(
                .notifications,
                now: afterSnooze.addingTimeInterval(PermissionPromptState.snoozeInterval * 5)
            ),
            "Two refusals should end the invitation permanently"
        )
    }

    func testGrantingStopsAnyFurtherOffers() {
        PermissionPromptState.recordRequested(.calendar)
        XCTAssertTrue(PermissionPromptState.hasRequested(.calendar))
        XCTAssertFalse(PermissionPromptState.shouldOffer(.calendar))
    }

    func testPermissionsRequestedAtPointOfUseAreNeverPrimedAhead() {
        for kind in [PermissionKind.microphone, .speech, .camera] {
            XCTAssertFalse(
                PermissionPromptState.shouldOffer(kind),
                "\(kind.rawValue) is asked for by iOS at first use; priming it would mean two dialogs"
            )
        }
    }

    func testHealthPromptStateStillReadsThroughItsOriginalFace() {
        HealthAuthorizationPromptState.recordRequested()
        XCTAssertTrue(PermissionPromptState.hasRequested(.appleHealth))
        XCTAssertTrue(HealthAuthorizationPromptState.hasRequested)
    }
}

/// The version bump to the rebuilt flow must not disturb anyone who already
/// finished setup — the previous check compared against the current version
/// only, so every bump re-presented onboarding to established users.
final class OnboardingVersionMigrationTests: XCTestCase {

    func testAUserWhoFinishedAnEarlierVersionIsNotOnboardedAgain() async {
        let suiteName = "onboarding.migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppOnboardingStateStore(userDefaults: defaults)

        // Someone who completed the old two-version flow.
        store.markHandled(outcome: OnboardingOutcome.completed, version: 2)
        XCTAssertNotEqual(2, AppOnboardingState.currentVersion)

        let service = OnboardingEligibilityService(
            stateStore: store,
            launchArguments: [],
            fetchLifeAreas: { [] },
            fetchProjects: { [] },
            fetchTasks: { [] }
        )

        let eligibility: OnboardingEligibility = await service.evaluate()
        XCTAssertEqual(eligibility, OnboardingEligibility.suppressed)
    }
}

/// A snapshot written by the previous flow names steps that no longer exist.
final class OnboardingSnapshotRecoveryTests: XCTestCase {

    func testAnUnknownStoredStepRestartsAtWelcomeRatherThanThrowing() throws {
        // Raw value 20 was `.homeDemo` in the previous enum.
        let json = """
        {"schemaVersion":4,"step":20,"mode":"guided","selectedLifeAreaIDs":[],
         "showAllLifeAreas":false,"projectDrafts":[],"resolvedLifeAreas":[],
         "resolvedProjects":[],"createdTasks":[],"createdTaskTemplateMap":{},
         "hasSeenSuccess":false}
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(OnboardingJourneySnapshot.self, from: json)
        XCTAssertEqual(snapshot.step, .welcome)
    }
}

/// Guards the Release rollout table.
///
/// Every staged Life OS flag resolves through `promotedDefaults` in Release. A
/// flag added without an entry there silently ships off — which is exactly how
/// Plan, Track, Insights, Eva and the rest stayed unreachable in Release builds
/// while being on for every developer.
final class FeatureFlagPromotionTests: XCTestCase {

    func testEveryStagedFlagHasAPromotedDefault() throws {
        let source = try flagSource()

        let declared = Set(
            matches(in: source, pattern: #"stagedFeatureEnabled\(\s*\n?\s*key: "([^"]+)""#)
        )
        let promoted = Set(
            matches(in: try promotedBlock(source), pattern: #""([^"]+)"\s*:"#)
        )

        XCTAssertFalse(declared.isEmpty, "Failed to parse any staged flags")
        XCTAssertEqual(
            declared.subtracting(promoted), [],
            "Staged flags missing a promoted default will be off in Release"
        )
        XCTAssertEqual(
            promoted.subtracting(declared), [],
            "Promoted entries that match no flag are dead and mask typos"
        )
    }

    func testTheLifeOSShellIsPromoted() throws {
        let block = try promotedBlock(flagSource())
        XCTAssertTrue(
            block.contains("\"debug.life_os_foundation_v1\": true"),
            "The shell must be on, or none of Plan/Track/Insights/Eva is reachable"
        )
    }

    func testEvaDecisionLoopsShipOnAndRetainIndependentSignedKillSwitches() throws {
        let source = try flagSource()
        let block = try promotedBlock(source)
        let controls = [
            ("feature.eva.make_it_fit_today_v1", "evaMakeItFitTodayV1Enabled"),
            ("feature.eva.friction_detective_v1", "evaFrictionDetectiveV1Enabled"),
            ("feature.eva.weekly_reset_v1", "evaWeeklyResetV1Enabled")
        ]

        for (key, runtimeProperty) in controls {
            XCTAssertTrue(block.contains("\"\(key)\": true"), "\(key) must ship on in Release")
            XCTAssertTrue(
                source.contains("AppRuntimeConfigurationStore.current.\(runtimeProperty)"),
                "\(key) must retain its signed production kill switch"
            )
        }
    }

    /// Flags whose Release default is deliberately `false` because their rollout
    /// is still in progress.
    ///
    /// Membership here is the *only* sanctioned way to ship a staged flag off in
    /// Release. It is spelled out by name so that holding one back stays a
    /// decision someone made and can be read in a diff — the failure this whole
    /// class exists to prevent is a flag being off in Release because nobody
    /// noticed, not a flag being off on purpose.
    private static let heldBackFromReleasePromotion: Set<String> = []

    /// Every retained staged flag defaults on in Release, not just on the Debug
    /// launch developers see. A deliberate `false` and a missing entry are both
    /// silent release-only omissions, so pin the value as well as membership —
    /// except for the flags named above, whose `false` is the decision.
    func testReachableStagedSurfacesArePromotedForRelease() throws {
        let block = try promotedBlock(flagSource())
        let stagedKeys = matches(
            in: try flagSource(),
            pattern: #"stagedFeatureEnabled\(\s*\n?\s*key: \"([^\"]+)\""#
        )
        for key in stagedKeys where Self.heldBackFromReleasePromotion.contains(key) == false {
            XCTAssertTrue(
                block.contains("\"\(key)\": true"),
                "Every retained staged flag must default on in Release: \(key)"
            )
        }
    }

    /// A held-back flag must still be *declared* off rather than merely absent,
    /// so the promotion table stays the single place a Release default is read.
    func testHeldBackFlagsAreExplicitlyDeclaredOff() throws {
        let block = try promotedBlock(flagSource())
        for key in Self.heldBackFromReleasePromotion {
            XCTAssertTrue(
                block.contains("\"\(key)\": false"),
                "A held-back flag must be pinned false, not omitted: \(key)"
            )
        }
    }

    func testExtensionPaletteDefaultsToUnifiedPresentationInRelease() throws {
        let source = try colorTokenSource()
        guard let start = source.range(of: "private static var unifiedPresentationEnabled: Bool"),
              let end = source.range(
                of: "\n    /// The canonical LifeBoard 5.0 palette",
                range: start.upperBound..<source.endIndex
              )
        else { throw XCTSkip("Extension unified-presentation resolver not found") }
        let resolver = String(source[start.lowerBound..<end.lowerBound])
        let releaseBranch = resolver.components(separatedBy: "#else").last ?? ""
        XCTAssertTrue(
            releaseBranch.contains("?? true"),
            "Widget and Watch targets must default to the same unified palette as the app"
        )
    }

    /// A flag with no call site gates nothing, so a promoted default for it is a
    /// claim the table cannot honor. `knowledge_notes_media_v2` and
    /// `knowledge_notes_flagship_v1` were exactly that and were removed; this
    /// keeps them from being reintroduced as decoration.
    func testRemovedDeadFlagsStayRemoved() throws {
        let source = try flagSource()
        for key in [
            "feature.life_os.knowledge_notes_media_v2",
            "feature.life_os.knowledge_notes_flagship_v1"
        ] {
            XCTAssertFalse(
                source.contains(key),
                "\(key) had no call site; reintroduce it only with the surface it gates"
            )
        }
    }

    // MARK: Helpers

    private func flagSource() throws -> String {
        // Walk up from this file to the repository root.
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            let candidate = url
                .appendingPathComponent("LifeBoard")
                .appendingPathComponent("Services")
                .appendingPathComponent("V2FeatureFlags.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("V2FeatureFlags.swift not reachable from the test bundle")
    }

    private func colorTokenSource() throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            let candidate = url
                .appendingPathComponent("LifeBoard")
                .appendingPathComponent("DesignSystem")
                .appendingPathComponent("ColorTokens.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("ColorTokens.swift not reachable from the test bundle")
    }

    private func promotedBlock(_ source: String) throws -> String {
        guard let start = source.range(of: "promotedDefaults: [String: Bool] = ["),
              let end = source.range(of: "\n    ]", range: start.upperBound..<source.endIndex)
        else { throw XCTSkip("promotedDefaults table not found") }
        return String(source[start.upperBound..<end.lowerBound])
    }

    private func matches(in source: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: range).compactMap { match in
            guard let captured = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[captured])
        }
    }
}
