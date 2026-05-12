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
            [.goal, .pain, .evaValue, .lifeAreas, .habitSetup, .evaStyle, .workBlockers, .weeklyOutcomes, .firstTask, .homeDemo, .calendarPermission, .notificationPermission, .success]
        )
    }

    func testOnboardingProgressUsesOrderedFlowAsSingleSource() {
        XCTAssertEqual(OnboardingProgress(step: .goal)?.label, "Step 1 of 13")
        XCTAssertEqual(OnboardingProgress(step: .success)?.label, "Step 13 of 13")
        XCTAssertEqual(OnboardingStep.goal.accessibilitySummary, "Choose goal. Step 1 of 13. Select one goal to continue.")
        XCTAssertEqual(OnboardingStep.success.accessibilitySummary, "Setup complete. Step 13 of 13. Go to Home.")
        XCTAssertNil(OnboardingProgress(step: .welcome))
    }

    func testLegacyOnboardingStepsNormalizeBeforeRendering() {
        XCTAssertEqual(OnboardingStep.blocker.normalizedForCurrentFlow, .goal)
        XCTAssertEqual(OnboardingStep.projects.normalizedForCurrentFlow, .lifeAreas)
        XCTAssertEqual(OnboardingStep.habits.normalizedForCurrentFlow, .habitSetup)
        XCTAssertEqual(OnboardingStep.streakPreview.normalizedForCurrentFlow, .evaStyle)
        XCTAssertEqual(OnboardingStep.processing.normalizedForCurrentFlow, .firstTask)
        XCTAssertEqual(OnboardingStep.focusRoom.normalizedForCurrentFlow, .homeDemo)
        XCTAssertEqual(OnboardingStep.habitCheckIn.normalizedForCurrentFlow, .homeDemo)
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
        XCTAssertEqual(OnboardingCopy.Welcome.changeLaterChip, "Change this later")
    }

    @MainActor
    func testOnboardingAccentPairsMeetWCAGContrast() {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let tokens = LifeBoardTheme(index: 0).tokens.color

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

    func testLegacyRawValuesStillDecodeExistingStepOrder() {
        XCTAssertEqual(OnboardingStep(rawValue: 0), .welcome)
        XCTAssertEqual(OnboardingStep(rawValue: 1), .lifeAreas)
        XCTAssertEqual(OnboardingStep(rawValue: 2), .projects)
        XCTAssertEqual(OnboardingStep(rawValue: 3), .habits)
        XCTAssertEqual(OnboardingStep(rawValue: 4), .firstTask)
        XCTAssertEqual(OnboardingStep(rawValue: 5), .focusRoom)
        XCTAssertEqual(OnboardingStep(rawValue: 6), .blocker)
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
        viewModel.continueFromGoal()
        viewModel.togglePainPoint(.overwhelm)
        viewModel.continueFromPain()
        viewModel.continueFromEvaValue()

        XCTAssertEqual(viewModel.step, .lifeAreas)
        XCTAssertEqual(viewModel.evaPreparationState.phase, .idle)
    }

    @MainActor
    func testAssistantPreferenceScreensAcceptCustomValuesAndAdvance() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(
            snapshot: OnboardingJourneySnapshot(
                step: .evaStyle,
                mode: .guided,
                selectedLifeAreaIDs: [],
                showAllLifeAreas: false,
                projectDrafts: [],
                resolvedLifeAreas: [],
                resolvedProjects: [],
                createdTasks: [],
                createdTaskTemplateMap: [:],
                focusIsActive: false,
                hasSeenSuccess: false
            )
        )

        viewModel.addCustomEvaWorkingStyle("Deep work mornings")
        viewModel.continueFromEvaStyle()
        XCTAssertEqual(viewModel.step, .workBlockers)

        viewModel.addCustomEvaMomentumBlocker("Too many pings")
        viewModel.continueFromWorkBlockers()
        XCTAssertEqual(viewModel.step, .weeklyOutcomes)

        viewModel.updateEvaGoal(at: 0, text: "Finish the launch checklist")
        viewModel.continueFromWeeklyOutcomes()
        XCTAssertEqual(viewModel.step, .firstTask)
        XCTAssertEqual(viewModel.evaProfileDraft.selectedWorkingStyleIDs, ["Deep work mornings"])
        XCTAssertEqual(viewModel.evaProfileDraft.selectedMomentumBlockerIDs, ["Too many pings"])
        XCTAssertEqual(viewModel.evaProfileDraft.goals, ["Finish the launch checklist"])
    }

    @MainActor
    func testReplaceEvaGoalsTrimsEmptyValuesAndPersists() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(
            snapshot: OnboardingJourneySnapshot(
                step: .weeklyOutcomes,
                mode: .guided,
                selectedLifeAreaIDs: [],
                showAllLifeAreas: false,
                projectDrafts: [],
                resolvedLifeAreas: [],
                resolvedProjects: [],
                createdTasks: [],
                createdTaskTemplateMap: [:],
                focusIsActive: false,
                hasSeenSuccess: false
            )
        )

        viewModel.replaceEvaGoals(["  Ship launch  ", "", " Protect workouts "])

        XCTAssertEqual(viewModel.evaProfileDraft.goals, ["Ship launch", "Protect workouts"])
        XCTAssertEqual(context.store.load().journeySnapshot?.evaProfileDraft.goals, ["Ship launch", "Protect workouts"])
    }

    func testHomeDemoSnapshotFactoryUsesHomeTimelineAndHabitModels() {
        let snapshot = OnboardingHomeDemoSnapshotFactory.snapshot(taskDone: false)
        let habitRows = OnboardingHomeDemoSnapshotFactory.habitRows(habitDone: false)

        XCTAssertEqual(snapshot.day.wakeAnchor.title, "Rise and shine")
        XCTAssertEqual(snapshot.day.sleepAnchor.title, "Wind down")
        XCTAssertGreaterThanOrEqual(snapshot.day.timedItems.filter { $0.source == .calendarEvent }.count, 2)
        XCTAssertGreaterThanOrEqual(snapshot.day.timedItems.filter { $0.source == .task }.count, 2)
        XCTAssertTrue(snapshot.day.timedItems.contains { $0.taskID == OnboardingHomeDemoSnapshotFactory.demoTaskID })
        XCTAssertGreaterThanOrEqual(habitRows.count, 2)
        XCTAssertTrue(habitRows.contains { $0.habitID == OnboardingHomeDemoSnapshotFactory.demoHabitID })
    }

    @MainActor
    func testNotificationPermissionRequestsOnlyFromNotificationStep() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let notificationService = TestNotificationService(status: .notDetermined)
        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            notificationService: notificationService
        )

        await viewModel.continueFromCalendarPermission(skipped: true)
        XCTAssertEqual(notificationService.requestPermissionCallCount, 0)

        await viewModel.continueFromNotificationPermission()
        XCTAssertEqual(notificationService.requestPermissionCallCount, 1)
        XCTAssertEqual(viewModel.step, .success)
    }

    @MainActor
    func testPrepareForPresentationRemapsLegacyStoredSteps() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let snapshot = OnboardingJourneySnapshot(
            step: .projects,
            mode: .guided,
            selectedLifeAreaIDs: ["health-self"],
            showAllLifeAreas: false,
            projectDrafts: [],
            resolvedLifeAreas: [],
            resolvedProjects: [],
            createdTasks: [],
            createdTaskTemplateMap: [:],
            focusIsActive: false,
            hasSeenSuccess: false
        )

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: snapshot)

        XCTAssertEqual(viewModel.step, .lifeAreas)
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
            frictionProfile: nil,
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
            step: .habitSetup,
            mode: .guided,
            entryContext: .establishedWorkspace,
            frictionProfile: .starting,
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
            parentFocusTaskID: nil,
            focusStartedAt: Date(timeIntervalSince1970: 1_700_000_000),
            focusIsActive: true,
            successSummary: nil,
            hasSeenSuccess: false
        )

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: snapshot)

        XCTAssertEqual(viewModel.step, .habitSetup)
        XCTAssertEqual(viewModel.entryContext, .establishedWorkspace)
        XCTAssertEqual(viewModel.mode, .guided)
        XCTAssertEqual(viewModel.frictionProfile, .starting)
        XCTAssertEqual(viewModel.selectedLifeAreaIDs, Set(["health-self"]))
        XCTAssertEqual(viewModel.createdHabits.map(\.title), ["Drink water after you wake up"])
        XCTAssertEqual(viewModel.focusTaskID, task.id)
        XCTAssertTrue(viewModel.focusIsActive)
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
            step: .habitSetup,
            mode: .custom,
            entryContext: .establishedWorkspace,
            frictionProfile: .choosing,
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
            parentFocusTaskID: nil,
            focusStartedAt: Date(timeIntervalSince1970: 1_700_000_000),
            focusIsActive: false,
            successSummary: nil,
            hasSeenSuccess: false,
            reminderPromptDismissed: false
        )

        context.store.storeJourney(snapshot)

        let restoredSnapshot = tryUnwrap(context.store.load().journeySnapshot)
        XCTAssertEqual(restoredSnapshot.step, .habitSetup)
        XCTAssertEqual(restoredSnapshot.entryContext, .establishedWorkspace)
        XCTAssertEqual(restoredSnapshot.selectedLifeAreaIDs, ["health-self"])

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: restoredSnapshot)

        XCTAssertEqual(viewModel.step, .habitSetup)
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
            step: .habitSetup,
            mode: .guided,
            frictionProfile: .starting,
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
            parentFocusTaskID: nil,
            focusStartedAt: nil,
            focusIsActive: false,
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
            step: .goal,
            mode: .guided,
            selectedLifeAreaIDs: ["health-self"],
            showAllLifeAreas: false,
            projectDrafts: [],
            resolvedLifeAreas: [],
            resolvedProjects: [],
            createdTasks: [],
            createdTaskTemplateMap: [:],
            focusIsActive: false,
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
    func testSelectFrictionUpdatesProfileAndLifeAreaDefaults() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: nil)
        viewModel.begin(mode: .guided)

        viewModel.selectFriction(.remembering)

        XCTAssertEqual(viewModel.frictionProfile, .remembering)
        XCTAssertEqual(
            viewModel.selectedLifeAreaIDs,
            Set(StarterWorkspaceCatalog.defaultLifeAreaSelectionIDs(for: .remembering, mode: .guided))
        )
    }

    func testFrictionSelectorUsesStackedLayoutOnCompactWidth() {
        XCTAssertEqual(
            OnboardingFrictionSelectorLayout.preferredLayout(
                for: 393,
                dynamicTypeSize: .large
            ),
            .stacked
        )
    }

    func testFrictionSelectorUsesStackedLayoutForAccessibilitySizes() {
        XCTAssertEqual(
            OnboardingFrictionSelectorLayout.preferredLayout(
                for: 430,
                dynamicTypeSize: .accessibility3
            ),
            .stacked
        )
    }

    func testFrictionSelectorUsesTwoColumnLayoutOnWideStandardWidth() {
        XCTAssertEqual(
            OnboardingFrictionSelectorLayout.preferredLayout(
                for: 700,
                dynamicTypeSize: .large
            ),
            .twoColumn
        )
    }

    @MainActor
    func testPrepareEstablishedWorkspaceEntryReusesExistingWorkspaceAndStartsAtBlocker() async {
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

        XCTAssertEqual(viewModel.step, .goal)
        XCTAssertEqual(viewModel.entryContext, .establishedWorkspace)
        XCTAssertEqual(viewModel.resolvedLifeAreas.map(\.lifeArea.name), ["Career", "Home"])
        XCTAssertEqual(viewModel.resolvedProjects.map(\.project.name), ["Ship one thing", "Home reset"])
        XCTAssertEqual(viewModel.selectedLifeAreaIDs, Set(["work-career", "life-admin"]))
    }

    @MainActor
    func testPrepareForPresentationRestoresSuccessStateAndReminderPrompt() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let notificationService = TestNotificationService(status: .notDetermined)
        let area = LifeArea(name: "Health")
        let project = Project(lifeAreaID: area.id, name: "Move your body")
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Fill your water bottle",
            estimatedDuration: 60
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["health-self"], mode: .guided).first
        )
        let summary = AppOnboardingSummary(
            lifeAreaCount: 1,
            projectCount: 1,
            createdTaskCount: 1,
            completedTaskCount: 1,
            completedTaskTitle: task.title,
            nextTaskTitle: nil,
            evaState: OnboardingEvaPreparationState(phase: .ready, selectedModelName: "fast", progress: 1, cellularConsentGranted: false, statusMessage: nil)
        )
        let snapshot = OnboardingJourneySnapshot(
            step: .success,
            mode: .guided,
            frictionProfile: .starting,
            selectedLifeAreaIDs: ["health-self"],
            showAllLifeAreas: false,
            projectDrafts: [projectDraft],
            expandedProjectIDs: [],
            resolvedLifeAreas: [
                ResolvedLifeAreaSelection(templateID: "health-self", lifeArea: area, reusedExisting: true)
            ],
            resolvedProjects: [
                ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
            ],
            createdTasks: [task],
            createdTaskTemplateMap: ["task-health-meal-snack": task.id],
            focusTaskID: task.id,
            parentFocusTaskID: nil,
            focusStartedAt: Date(timeIntervalSince1970: 1_700_000_000),
            focusIsActive: false,
            successSummary: summary,
            hasSeenSuccess: true,
            reminderPromptDismissed: false
        )

        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            notificationService: notificationService
        )
        viewModel.prepareForPresentation(snapshot: snapshot)

        XCTAssertEqual(viewModel.step, .success)
        XCTAssertEqual(viewModel.successSummary, summary)
        XCTAssertEqual(viewModel.resolvedLifeAreas.map(\.lifeArea.name), ["Health"])
        XCTAssertEqual(viewModel.resolvedProjects.map(\.project.name), ["Move your body"])

        for _ in 0..<10 where viewModel.reminderPromptState != .prompt {
            try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(viewModel.reminderPromptState, .prompt)
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
            step: .firstTask,
            mode: .guided,
            frictionProfile: .starting,
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
            parentFocusTaskID: nil,
            focusStartedAt: nil,
            focusIsActive: false,
            successSummary: nil,
            hasSeenSuccess: false,
            reminderPromptDismissed: false
        )

        let viewModel = OnboardingFlowModel(stateStore: context.store)
        viewModel.prepareForPresentation(snapshot: snapshot)
        viewModel.resetForReplay()

        XCTAssertEqual(viewModel.step, .welcome)
        XCTAssertEqual(viewModel.entryContext, .freshFlow)
        XCTAssertEqual(viewModel.mode, .guided)
        XCTAssertNil(viewModel.frictionProfile)
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
            frictionProfile: nil,
            selectedLifeAreaIDs: [],
            showAllLifeAreas: false,
            projectDrafts: [],
            expandedProjectIDs: [],
            resolvedLifeAreas: [],
            resolvedProjects: [],
            createdTasks: [],
            createdTaskTemplateMap: [:],
            focusTaskID: nil,
            parentFocusTaskID: nil,
            focusStartedAt: nil,
            focusIsActive: false,
            successSummary: nil,
            hasSeenSuccess: false,
            reminderPromptDismissed: false
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

        await viewModel.skipToFocusRoom()

        XCTAssertEqual(viewModel.step, .homeDemo)
        XCTAssertFalse(createdLifeAreas.isEmpty)
        XCTAssertFalse(createdProjects.isEmpty)
        XCTAssertEqual(createdTasks.count, 1)
        XCTAssertEqual(viewModel.createdTasks.count, 1)
        XCTAssertEqual(viewModel.focusTaskID, createdTasks.first?.id)
        XCTAssertEqual(context.store.load().journeySnapshot?.step, .homeDemo)
    }

    @MainActor
    func testHomeDemoContinueAdvancesWithoutCompletingDemoActions() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let viewModel = makeHomeDemoViewModel(stateStore: context.store)

        viewModel.continueFromHomeDemo()

        XCTAssertEqual(viewModel.step, .calendarPermission)
        XCTAssertFalse(viewModel.didCompleteHomeDemoTask)
        XCTAssertFalse(viewModel.didCompleteHomeDemoHabit)
        XCTAssertFalse(viewModel.createdTasks.first?.isComplete ?? true)
        XCTAssertEqual(context.store.load().journeySnapshot?.step, .calendarPermission)
    }

    @MainActor
    func testHomeDemoContinueAfterOneDemoTaskMarksTaskComplete() {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let viewModel = makeHomeDemoViewModel(stateStore: context.store)

        viewModel.markHomeDemoTaskDone()
        viewModel.continueFromHomeDemo()

        XCTAssertEqual(viewModel.step, .calendarPermission)
        XCTAssertTrue(viewModel.didCompleteHomeDemoTask)
        XCTAssertTrue(viewModel.createdTasks.first?.isComplete ?? false)
        XCTAssertEqual(viewModel.successSummary?.completedTaskTitle, "Open the draft and write 3 lines")
    }

    @MainActor
    private func makeHomeDemoViewModel(stateStore: AppOnboardingStateStore) -> OnboardingFlowModel {
        let area = LifeArea(name: "Career")
        let project = Project(lifeAreaID: area.id, name: "Ship one thing")
        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Open the draft and write 3 lines"
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["work-career"], mode: .guided).first
        )

        let viewModel = OnboardingFlowModel(stateStore: stateStore)
        viewModel.prepareForPresentation(
            snapshot: OnboardingJourneySnapshot(
                step: .homeDemo,
                mode: .guided,
                frictionProfile: .starting,
                selectedLifeAreaIDs: ["work-career"],
                showAllLifeAreas: false,
                projectDrafts: [projectDraft],
                resolvedLifeAreas: [
                    ResolvedLifeAreaSelection(templateID: "work-career", lifeArea: area, reusedExisting: true)
                ],
                resolvedProjects: [
                    ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
                ],
                createdTasks: [task],
                createdTaskTemplateMap: [:],
                focusTaskID: task.id,
                focusIsActive: false,
                hasSeenSuccess: false
            )
        )
        return viewModel
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

        await viewModel.skipToFocusRoom()

        XCTAssertEqual(viewModel.step, .homeDemo)
        XCTAssertEqual(viewModel.evaPreparationState.phase, .idle)
        XCTAssertEqual(createdTasks.count, 1)
    }
    #endif

    @MainActor
    func testBreakdownPromotesFirstAddedChildTaskIntoFocus() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let area = LifeArea(name: "Career")
        let project = Project(lifeAreaID: area.id, name: "Ship one thing")
        let focusTask = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Open the draft and write 3 lines",
            estimatedDuration: 120
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["work-career"], mode: .guided).first
        )

        var createdChildren: [TaskDefinition] = []
        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            createTask: { request in
                let child = request.toTaskDefinition(projectName: request.projectName)
                createdChildren.append(child)
                return child
            }
        )
        viewModel.prepareForPresentation(
            snapshot: OnboardingJourneySnapshot(
                step: .focusRoom,
                mode: .guided,
                frictionProfile: .starting,
                selectedLifeAreaIDs: ["work-career"],
                showAllLifeAreas: false,
                projectDrafts: [projectDraft],
                resolvedLifeAreas: [
                    ResolvedLifeAreaSelection(templateID: "work-career", lifeArea: area, reusedExisting: true)
                ],
                resolvedProjects: [
                    ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
                ],
                createdTasks: [focusTask],
                createdTaskTemplateMap: [:],
                focusTaskID: focusTask.id,
                parentFocusTaskID: nil,
                focusStartedAt: nil,
                focusIsActive: false,
                successSummary: nil,
                hasSeenSuccess: false
            )
        )
        viewModel.breakdownSteps = [
            OnboardingBreakdownStep(title: "Open the draft", isSelected: true),
            OnboardingBreakdownStep(title: "Write one sentence", isSelected: true)
        ]

        await viewModel.applySelectedBreakdownSteps()

        XCTAssertEqual(createdChildren.count, 2)
        XCTAssertEqual(viewModel.parentFocusTaskID, focusTask.id)
        XCTAssertEqual(viewModel.focusTask?.title, "Open the draft")
        XCTAssertEqual(createdChildren.first?.parentTaskID, focusTask.id)
    }

    @MainActor
    func testCompleteFocusTaskBuildsSuccessSummaryAndReminderPrompt() async {
        let context = makeStoreContext()
        defer { context.cleanup() }

        let notificationService = TestNotificationService(status: .notDetermined)
        let area = LifeArea(name: "Health")
        let project = Project(lifeAreaID: area.id, name: "Move your body")
        let task = TaskDefinition(
            id: UUID(),
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: area.id,
            title: "Fill your water bottle",
            estimatedDuration: 60
        )
        let projectDraft = tryUnwrap(
            StarterWorkspaceCatalog.defaultProjectDrafts(for: ["health-self"], mode: .guided).first
        )

        let viewModel = OnboardingFlowModel(
            stateStore: context.store,
            notificationService: notificationService,
            setTaskCompletion: { taskID, isComplete in
                var completed = task
                completed.isComplete = isComplete
                completed.dateCompleted = isComplete ? Date() : nil
                return completed
            }
        )
        viewModel.prepareForPresentation(
            snapshot: OnboardingJourneySnapshot(
                step: .focusRoom,
                mode: .guided,
                frictionProfile: .starting,
                selectedLifeAreaIDs: ["health-self"],
                showAllLifeAreas: false,
                projectDrafts: [projectDraft],
                resolvedLifeAreas: [
                    ResolvedLifeAreaSelection(templateID: "health-self", lifeArea: area, reusedExisting: true)
                ],
                resolvedProjects: [
                    ResolvedProjectSelection(draft: projectDraft, project: project, reusedExisting: true)
                ],
                createdTasks: [task],
                createdTaskTemplateMap: [:],
                focusTaskID: task.id,
                parentFocusTaskID: nil,
                focusStartedAt: Date(),
                focusIsActive: true,
                successSummary: nil,
                hasSeenSuccess: false
            )
        )

        await viewModel.completeFocusTask()

        XCTAssertEqual(viewModel.step, .calendarPermission)
        XCTAssertEqual(viewModel.successSummary?.completedTaskTitle, "Fill your water bottle")
        XCTAssertEqual(viewModel.successSummary?.completedTaskCount, 1)
        XCTAssertNil(viewModel.successSummary?.nextTaskTitle)
        XCTAssertEqual(viewModel.successSummary?.evaState.phase, .idle)
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
        let lighter = max(relativeLuminance(fg), relativeLuminance(bg))
        let darker = min(relativeLuminance(fg), relativeLuminance(bg))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))

        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }
}

private struct StoreContext {
    let store: AppOnboardingStateStore
    let cleanup: () -> Void
}

private final class TestNotificationService: NotificationServiceProtocol {
    var status: LifeBoardNotificationAuthorizationStatus
    var permissionGranted = true
    private(set) var requestPermissionCallCount = 0

    init(status: LifeBoardNotificationAuthorizationStatus) {
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
    func schedule(request: LifeBoardLocalNotificationRequest) {}
    func cancel(ids: [String]) {}
    func pendingRequests(completion: @escaping @Sendable ([LifeBoardPendingNotificationRequest]) -> Void) { completion([]) }
    func registerCategories(_ categories: Set<UNNotificationCategory>) {}
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate?) {}
    func fetchAuthorizationStatus(completion: @escaping @Sendable (LifeBoardNotificationAuthorizationStatus) -> Void) {
        completion(status)
    }
}
