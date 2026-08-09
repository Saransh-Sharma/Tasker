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

    func testEligibilityReturnsPromptOnlyForEstablishedWorkspaceWithoutState() async {
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

        let result = await service.evaluate()

        guard case .promptOnly(let snapshot) = result else {
            return XCTFail("Expected prompt-only onboarding for an established workspace.")
        }
        XCTAssertEqual(snapshot.customLifeAreaCount, 1)
        XCTAssertEqual(snapshot.customProjectCount, 1)
        XCTAssertEqual(snapshot.taskCount, 3)
    }

    func testEligibilitySuppressesWhenCurrentVersionAlreadyHandled() async {
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
        XCTAssertEqual(result, .suppressed)
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
    func testDefaultOnboardingMascotIsYesManAndEvaTransitionIsNonBlocking() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            isEvaBackgroundPreparationEnabled: false
        )

        viewModel.prepareForPresentation(snapshot: nil)
        viewModel.begin(mode: .guided)

        XCTAssertEqual(viewModel.selectedMascotID, .yesman)
        viewModel.selectGoal(.dailyExecution)
        viewModel.continueFromIntent()

        XCTAssertEqual(viewModel.step, .lifeAreas)
        XCTAssertEqual(viewModel.evaPreparationState.phase, .idle)
    }






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
    func testFlowModelCapsLifeAreaSelectionAtThree() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.begin(mode: .guided)
        viewModel.selectedLifeAreaIDs = []

        viewModel.toggleLifeArea("health-self")
        viewModel.toggleLifeArea("work-career")
        viewModel.toggleLifeArea("life-admin")
        viewModel.toggleLifeArea("learning-growth")

        XCTAssertEqual(viewModel.selectedLifeAreaIDs.count, 3)
        XCTAssertFalse(viewModel.selectedLifeAreaIDs.contains("learning-growth"))
        XCTAssertTrue(viewModel.canContinueLifeAreas)
    }

    @MainActor
    func testPrepareForPresentationRestoresJourneySnapshot() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let area = LifeArea(name: "Health")
        let project = Project(lifeAreaID: area.id, name: "Move your body")
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Put on workout clothes",
            estimatedDuration: 60
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["health-self"], mode: .guided).first
        )
        let snapshot = OnboardingJourneySnapshot(
            step: .firstWin,
            mode: .guided,
            entryContext: .establishedWorkspace,
            selectedLifeAreaIDs: ["health-self"],
            showAllLifeAreas: false,
            projectDrafts: [projectDraft],
            resolvedLifeAreas: [
                ResolvedLifeAreaSelection(templateID: "health-self", lifeArea: area, reusedExisting: true)
            ],
            resolvedProjects: [
                ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
            ],
            createdHabits: [
                HabitDefinitionRecord(
                    lifeAreaID: area.id,
                    projectID: project.id,
                    title: "Drink water after you wake up",
                    habitType: "positive_daily_check_in"
                )
            ],
            createdHabitTemplateMap: ["habit-health-water": UUID()],
            createdTasks: [task],
            createdTaskTemplateMap: ["task-health-move-clothes": task.id],
            focusTaskID: task.id,
            successSummary: nil,
            hasSeenSuccess: false
        )

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: snapshot)

        XCTAssertEqual(viewModel.step, .firstWin)
        XCTAssertEqual(viewModel.entryContext, .establishedWorkspace)
        XCTAssertEqual(viewModel.mode, .guided)
        
        XCTAssertEqual(viewModel.selectedLifeAreaIDs, Set(["health-self"]))
        XCTAssertEqual(viewModel.createdHabits.map(\.title), ["Drink water after you wake up"])
        XCTAssertEqual(viewModel.focusTaskID, task.id)
        
        XCTAssertEqual(viewModel.createdTasks.map(\.id), [task.id])
    }

    @MainActor
    func testStoreAndRestoreJourneySnapshotPreservesMidFlowState() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let area = LifeArea(name: "Health")
        let project = Project(lifeAreaID: area.id, name: "Move your body")
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Put on workout clothes",
            estimatedDuration: 60
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["health-self"], mode: .guided).first
        )
        let snapshot = OnboardingJourneySnapshot(
            step: .firstWin,
            mode: .custom,
            entryContext: .establishedWorkspace,
            selectedLifeAreaIDs: ["health-self"],
            showAllLifeAreas: true,
            projectDrafts: [projectDraft],
            expandedProjectIDs: [UUID()],
            resolvedLifeAreas: [
                ResolvedLifeAreaSelection(templateID: "health-self", lifeArea: area, reusedExisting: true)
            ],
            resolvedProjects: [
                ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
            ],
            createdHabits: [
                HabitDefinitionRecord(
                    lifeAreaID: area.id,
                    projectID: project.id,
                    title: "Put your phone on the charger before bed",
                    habitType: "positive_daily_check_in"
                )
            ],
            createdHabitTemplateMap: ["habit-health-charge": UUID()],
            createdTasks: [task],
            createdTaskTemplateMap: ["task-health-move-clothes": task.id],
            focusTaskID: task.id,
            successSummary: nil,
            hasSeenSuccess: false,
        )

        context.store.storeJourney(snapshot)

        let restoredSnapshot = tryUnwrap(context.store.load().journeySnapshot)
        XCTAssertEqual(restoredSnapshot.step, .firstWin)
        XCTAssertEqual(restoredSnapshot.entryContext, .establishedWorkspace)
        XCTAssertEqual(restoredSnapshot.selectedLifeAreaIDs, ["health-self"])

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: restoredSnapshot)

        XCTAssertEqual(viewModel.step, .firstWin)
        XCTAssertEqual(viewModel.entryContext, .establishedWorkspace)
        XCTAssertEqual(viewModel.mode, .custom)
        XCTAssertEqual(viewModel.selectedLifeAreaIDs, Set(["health-self"]))
        XCTAssertTrue(viewModel.showAllLifeAreas)
        XCTAssertEqual(viewModel.projectDrafts, [projectDraft])
        XCTAssertEqual(viewModel.createdHabits.map(\.title), ["Put your phone on the charger before bed"])
        XCTAssertEqual(viewModel.createdTasks.map(\.id), [task.id])
        XCTAssertEqual(viewModel.focusTaskID, task.id)
    }

    @MainActor
    func testPrepareForPresentationWithoutSnapshotDefaultsEntryContextToFreshFlow() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: nil)

        XCTAssertEqual(viewModel.step, .welcome)
        XCTAssertEqual(viewModel.entryContext, .freshFlow)
    }

    @MainActor
    func testPrepareForPresentationNormalizesLegacyTemplateIDs() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let area = LifeArea(name: "Career")
        let project = Project(lifeAreaID: area.id, name: "Ship one thing")
        let legacyDraft = OnboardingProjectDraft(
            lifeAreaTemplateID: "career",
            templateID: "career-ship",
            name: "Ship one thing",
            summary: "Keep the next visible output moving.",
            suggestionTemplateIDs: ["career-ship", "career-followups", "career-admin"],
            suggestionIndex: 0,
            isSelected: true
        )
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Put clothes in one basket",
            estimatedDuration: 120
        )
        let snapshot = OnboardingJourneySnapshot(
            step: .firstWin,
            mode: .guided,
            selectedLifeAreaIDs: ["career", "home", "health"],
            showAllLifeAreas: true,
            projectDrafts: [legacyDraft],
            resolvedLifeAreas: [
                ResolvedLifeAreaSelection(templateID: "career", lifeArea: area, reusedExisting: true)
            ],
            resolvedProjects: [
                ResolvedProjectSelection(draft: legacyDraft, project: project, reusedExisting: true)
            ],
            createdHabits: [],
            createdHabitTemplateMap: ["habit-home-laundry": UUID()],
            createdTasks: [task],
            createdTaskTemplateMap: ["task-home-laundry-basket": task.id],
            focusTaskID: task.id,
            successSummary: nil,
            hasSeenSuccess: false
        )

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: snapshot)

        XCTAssertEqual(viewModel.selectedLifeAreaIDs, Set(["work-career", "life-admin", "health-self"]))
        XCTAssertEqual(viewModel.projectDrafts.first?.lifeAreaTemplateID, "work-career")
        XCTAssertEqual(viewModel.projectDrafts.first?.templateID, "work-ship")
        XCTAssertNotNil(viewModel.createdHabitTemplateMap["habit-home-reset"])
        XCTAssertNotNil(viewModel.createdTaskTemplateMap["task-home-reset-five"])
    }

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
    func testPrepareEstablishedWorkspaceEntryReusesExistingWorkspaceAndStartsAtIntent() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let career = LifeArea(name: "Career")
        let home = LifeArea(name: "Home")
        let shipProject = Project(lifeAreaID: career.id, name: "Ship one thing")
        let homeReset = Project(lifeAreaID: home.id, name: "Home reset")

        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            fetchLifeAreas: { [career, home] },
            fetchProjects: { [Project.createInbox(), shipProject, homeReset] }
        )

        await viewModel.prepareEstablishedWorkspaceEntry()

        XCTAssertEqual(viewModel.step, .intent)
        XCTAssertEqual(viewModel.entryContext, .establishedWorkspace)
        XCTAssertEqual(viewModel.resolvedLifeAreas.map(\.lifeArea.name), ["Career", "Home"])
        XCTAssertEqual(viewModel.resolvedProjects.map(\.project.name), ["Ship one thing", "Home reset"])
        XCTAssertEqual(viewModel.selectedLifeAreaIDs, Set(["work-career", "life-admin"]))
    }


    func testPresentationQueuePrefersFullFlowOverPrompt() {
        var queue = OnboardingPresentationQueue()
        let snapshot = OnboardingWorkspaceSnapshot(customLifeAreaCount: 1, customProjectCount: 1, taskCount: 3)

        queue.enqueue(.prompt(snapshot: snapshot))
        XCTAssertEqual(queue.pending, .prompt(snapshot: snapshot))

        queue.enqueue(.fullFlow(source: "resume"))
        XCTAssertEqual(queue.pending, .fullFlow(source: "resume"))

        queue.markPresented(.prompt(snapshot: snapshot))
        XCTAssertEqual(queue.pending, .fullFlow(source: "resume"))

        queue.markPresented(.fullFlow(source: "resume"))
        XCTAssertNil(queue.pending)
    }

    @MainActor
    func testResetForReplayClearsPersistedJourneyAndReturnsToWelcome() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let area = LifeArea(name: "Career")
        let project = Project(lifeAreaID: area.id, name: "Ship one thing")
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Open the draft and write 3 lines",
            estimatedDuration: 120
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["work-career"], mode: .guided).first
        )
        let snapshot = OnboardingJourneySnapshot(
            step: .firstWin,
            mode: .guided,
            selectedLifeAreaIDs: ["work-career"],
            showAllLifeAreas: false,
            projectDrafts: [projectDraft],
            expandedProjectIDs: [],
            resolvedLifeAreas: [
                ResolvedLifeAreaSelection(templateID: "work-career", lifeArea: area, reusedExisting: true)
            ],
            resolvedProjects: [
                ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
            ],
            createdTasks: [task],
            createdTaskTemplateMap: [:],
            focusTaskID: task.id,
            successSummary: nil,
            hasSeenSuccess: false,
        )

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: snapshot)
        viewModel.resetForReplay()

        XCTAssertEqual(viewModel.step, .welcome)
        XCTAssertEqual(viewModel.entryContext, .freshFlow)
        XCTAssertEqual(viewModel.mode, .guided)
        
        XCTAssertTrue(viewModel.selectedLifeAreaIDs.isEmpty)
        XCTAssertTrue(viewModel.projectDrafts.isEmpty)
        XCTAssertTrue(viewModel.createdTasks.isEmpty)
        XCTAssertNil(context.store.load().journeySnapshot)
    }

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
    func testSkipToFocusRoomSeedsStarterWorkspaceAndTask() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        var createdLifeAreas: [LifeArea] = []
        var createdProjects: [Project] = []
        var createdTasks: [TaskDefinition] = []

        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            fetchLifeAreas: { [] },
            fetchProjects: { [] },
            fetchTask: { taskID in createdTasks.first(where: { $0.id == taskID }) },
            createLifeArea: { template in
                let area = LifeArea(name: template.name, color: template.colorHex, icon: template.icon)
                createdLifeAreas.append(area)
                return area
            },
            createProject: { draft, lifeArea in
                let project = Project(lifeAreaID: lifeArea.id, name: draft.name, projectDescription: draft.summary)
                createdProjects.append(project)
                return project
            },
            createTask: { request in
                let task = request.toTaskDefinition(projectName: request.projectName)
                createdTasks.append(task)
                return task
            }
        )

        await viewModel.skipToEnd()

        XCTAssertEqual(viewModel.step, .permissions)
        XCTAssertFalse(createdLifeAreas.isEmpty)
        XCTAssertFalse(createdProjects.isEmpty)
        XCTAssertEqual(createdTasks.count, 1)
        XCTAssertEqual(viewModel.createdTasks.count, 1)
        XCTAssertEqual(viewModel.focusTaskID, createdTasks.first?.id)
        XCTAssertEqual(context.store.load().journeySnapshot?.step, .permissions)
    }





    #if targetEnvironment(simulator)
    @MainActor
    func testSkipToFocusRoomBypassesBlockingEvaPreparationOnSimulator() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        var createdTasks: [TaskDefinition] = []
        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            fetchLifeAreas: { [] },
            fetchProjects: { [] },
            fetchTask: { taskID in createdTasks.first(where: { $0.id == taskID }) },
            createTask: { request in
                let task = request.toTaskDefinition(projectName: request.projectName)
                createdTasks.append(task)
                return task
            },
            isEvaBackgroundPreparationEnabled: true
        )

        await viewModel.skipToEnd()

        XCTAssertEqual(viewModel.step, .permissions)
        XCTAssertEqual(viewModel.evaPreparationState.phase, .idle)
        XCTAssertEqual(createdTasks.count, 1)
    }
    #endif



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

    /// Every retained staged flag defaults on in Release, not just on the Debug
    /// launch developers see. A deliberate `false` and a missing entry are both
    /// silent release-only omissions, so pin the value as well as membership.
    func testReachableStagedSurfacesArePromotedForRelease() throws {
        let block = try promotedBlock(flagSource())
        let stagedKeys = matches(
            in: try flagSource(),
            pattern: #"stagedFeatureEnabled\(\s*\n?\s*key: \"([^\"]+)\""#
        )
        for key in stagedKeys {
            XCTAssertTrue(
                block.contains("\"\(key)\": true"),
                "Every retained staged flag must default on in Release: \(key)"
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
