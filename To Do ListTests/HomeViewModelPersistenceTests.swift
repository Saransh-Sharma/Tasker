import XCTest
import Combine
@testable import To_Do_List

final class HomeViewModelPersistenceTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testGroupingModeAndCustomProjectOrderPersistAcrossSessions() {
        let suiteName = "HomeViewModelPersistenceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let alpha = Project(id: UUID(), name: "Alpha", icon: .folder)
        let beta = Project(id: UUID(), name: "Beta", icon: .folder)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [
            makeTask(name: "Alpha task", project: alpha, dueDate: Date()),
            makeTask(name: "Beta task", project: beta, dueDate: Date())
        ])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox, alpha, beta])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModelA = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        viewModelA.setProjectGroupingMode(.groupByProjects)
        viewModelA.setCustomProjectOrder([beta.id, alpha.id])

        let viewModelB = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        XCTAssertEqual(viewModelB.activeFilterState.projectGroupingMode, .groupByProjects)
        XCTAssertEqual(Array(viewModelB.activeFilterState.customProjectOrderIDs.prefix(2)), [beta.id, alpha.id])

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testProgressStateTracksEarnedAndRemainingXP() {
        let suiteName = "HomeViewModelPersistenceTests.ProgressState.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let highXPTask = makeTask(name: "Progress task", project: inbox, dueDate: Date(), priority: .high)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [highXPTask])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.progressState.earnedXP, viewModel.dailyScore)
        if V2FeatureFlags.gamificationV2Enabled {
            XCTAssertEqual(viewModel.progressState.remainingPotentialXP, max(0, viewModel.dailyXPCap - viewModel.dailyScore))
            XCTAssertEqual(viewModel.progressState.todayTargetXP, viewModel.dailyXPCap)
        } else {
            XCTAssertEqual(viewModel.progressState.remainingPotentialXP, viewModel.pointsPotential)
            XCTAssertEqual(
                viewModel.progressState.todayTargetXP,
                viewModel.progressState.earnedXP + viewModel.progressState.remainingPotentialXP
            )
        }
        XCTAssertEqual(viewModel.progressState.isStreakSafeToday, viewModel.progressState.earnedXP > 0)

        guard let openTask = viewModel.morningTasks.first else {
            return XCTFail("Expected open task in morning list")
        }

        viewModel.toggleTaskCompletion(openTask)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.progressState.earnedXP, viewModel.dailyScore)
        if V2FeatureFlags.gamificationV2Enabled {
            XCTAssertEqual(viewModel.progressState.remainingPotentialXP, max(0, viewModel.dailyXPCap - viewModel.dailyScore))
            XCTAssertEqual(viewModel.progressState.todayTargetXP, viewModel.dailyXPCap)
        } else {
            XCTAssertEqual(viewModel.progressState.remainingPotentialXP, viewModel.pointsPotential)
            XCTAssertEqual(
                viewModel.progressState.todayTargetXP,
                viewModel.progressState.earnedXP + viewModel.progressState.remainingPotentialXP
            )
        }
        XCTAssertEqual(viewModel.progressState.isStreakSafeToday, viewModel.progressState.earnedXP > 0)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testNeedsReplanEligibilityIncludesOnlyPastOpenTimedTasks() {
        let suiteName = "HomeViewModelPersistenceTests.NeedsReplan.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let yesterdayTimed = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: yesterday)!
        let yesterdayScheduledOnly = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: yesterday)!
        let todayTimed = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: calendar.startOfDay(for: Date()))!

        let included = makeDefinition(title: "Included", start: yesterdayTimed)
        let scheduledOnly = TaskDefinition(
            title: "Scheduled Only",
            dueDate: nil,
            scheduledStartAt: yesterdayScheduledOnly,
            scheduledEndAt: yesterdayScheduledOnly.addingTimeInterval(30 * 60),
            isAllDay: false,
            isComplete: false
        )
        let recurring = makeDefinition(title: "Recurring", start: yesterdayTimed, repeatPattern: .daily)
        let allDay = makeDefinition(title: "All day", start: yesterday, isAllDay: true)
        let habit = makeDefinition(title: "Habit", start: yesterdayTimed, habitDefinitionID: UUID())
        let completed = makeDefinition(title: "Completed", start: yesterdayTimed, isComplete: true)
        let today = makeDefinition(title: "Today", start: todayTimed)
        let inbox = TaskDefinition(
            title: "Inbox",
            type: .inbox,
            dueDate: nil,
            scheduledStartAt: nil,
            scheduledEndAt: nil,
            isAllDay: false,
            isComplete: false
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: UseCaseCoordinator(
                taskRepository: HomeViewModelMockTaskRepository(tasks: []),
                projectRepository: HomeViewModelMockProjectRepository(projects: [Project.createInbox()])
            ),
            userDefaults: defaults
        )
        waitForMainQueueFlush()

        let candidates = viewModel.needsReplanCandidatesForTesting(
            from: [included, scheduledOnly, recurring, allDay, habit, completed, today, inbox]
        )

        XCTAssertEqual(candidates.map { $0.task.title }, ["Scheduled Only", "Included"])
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testNeedsReplanTrayAppearsForPastScheduledTaskWithoutDueDate() {
        let suiteName = "HomeViewModelPersistenceTests.ScheduledReplanTray.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let yesterdayScheduled = calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .hour, value: 9, to: todayStart)!)!
        let task = TaskDefinition(
            title: "Past Timeline Task",
            dueDate: nil,
            scheduledStartAt: yesterdayScheduled,
            scheduledEndAt: yesterdayScheduled.addingTimeInterval(30 * 60),
            isAllDay: false,
            isComplete: false
        )
        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: [task]),
            projectRepository: HomeViewModelMockProjectRepository(projects: [Project.createInbox()])
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        viewModel.loadTodayTasks()
        waitForMainQueueFlush()

        guard case .trayVisible(let summary) = viewModel.homeReplanState.phase else {
            return XCTFail("Expected Needs Replan tray for past scheduled-only task")
        }
        XCTAssertEqual(summary.count, 1)

        let weekStart: Weekday = calendar.component(.weekday, from: todayStart) == 2 ? .sunday : .monday
        let weekSummary = viewModel.timelineWeekSummary(weekStartsOn: weekStart, includeCalendarEvents: false)
        let originalDay = weekSummary.days.first {
            calendar.isDate($0.date, inSameDayAs: yesterdayScheduled)
        }
        XCTAssertEqual(originalDay?.replanEligibleCount, 1)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testNeedsReplanTrayUsesMatchingOpenTasksOutsideVisibleWindow() {
        let suiteName = "HomeViewModelPersistenceTests.ScheduledReplanWindow.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let visibleTasks = (0..<370).map { index in
            TaskDefinition(
                title: "Visible \(index)",
                priority: .max,
                dueDate: calendar.date(byAdding: .minute, value: index, to: todayStart),
                isComplete: false
            )
        }
        let yesterdayScheduled = calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .hour, value: 9, to: todayStart)!)!
        let clippedCandidate = TaskDefinition(
            title: "Clipped Replan Candidate",
            dueDate: nil,
            scheduledStartAt: yesterdayScheduled,
            scheduledEndAt: yesterdayScheduled.addingTimeInterval(30 * 60),
            isAllDay: false,
            isComplete: false
        )
        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: visibleTasks + [clippedCandidate]),
            projectRepository: HomeViewModelMockProjectRepository(projects: [Project.createInbox()])
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        viewModel.loadTodayTasks()
        waitForMainQueueFlush()

        XCTAssertFalse(viewModel.morningTasks.contains(where: { $0.title == "Clipped Replan Candidate" }))
        guard case .trayVisible(let summary) = viewModel.homeReplanState.phase else {
            return XCTFail("Expected Needs Replan tray from matchingOpenTasks outside visible window")
        }
        XCTAssertEqual(summary.count, 1)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTimelineTintHexPrefersLifeAreaColorWhenProjectBelongsToLifeArea() {
        let suiteName = "HomeViewModelPersistenceTests.TimelineTintLifeArea.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let lifeArea = LifeArea(id: UUID(), name: "Career", color: "#1A2B3C")
        let project = Project(id: UUID(), lifeAreaID: lifeArea.id, name: "Work", color: .purple, icon: .work)
        let coordinator = makeTimelineTintCoordinator(projects: [Project.createInbox(), project], lifeAreas: [lifeArea])
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()
        waitUntilProjectLoaded(project.id, in: viewModel)

        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            title: "Prepare weekly brief",
            dueDate: Date()
        )

        XCTAssertEqual(
            viewModel.timelineTintHex(for: task),
            LifeAreaColorPalette.normalizeOrMap(hex: lifeArea.color, for: lifeArea.id)
        )

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTimelineTintHexFallsBackToProjectColorWithoutLifeArea() {
        let suiteName = "HomeViewModelPersistenceTests.TimelineTintProjectFallback.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let project = Project(id: UUID(), name: "Side", color: .teal, icon: .creative)
        let coordinator = makeTimelineTintCoordinator(projects: [Project.createInbox(), project], lifeAreas: [])
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()
        waitUntilProjectLoaded(project.id, in: viewModel)

        let task = TaskDefinition(
            projectID: project.id,
            projectName: project.name,
            title: "Sketch MVP",
            dueDate: Date()
        )

        XCTAssertEqual(viewModel.timelineTintHex(for: task), project.color.hexString)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTimelineTintHexReturnsNilWhenOwningSectionCannotBeResolved() {
        let suiteName = "HomeViewModelPersistenceTests.TimelineTintUnresolved.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let coordinator = makeTimelineTintCoordinator(projects: [Project.createInbox()], lifeAreas: [])
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        let task = TaskDefinition(
            projectID: UUID(),
            projectName: "Missing Project",
            title: "Unknown color",
            priority: .high,
            dueDate: Date()
        )

        XCTAssertEqual(viewModel.timelineTintHex(for: task), task.priority.colorHex)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testNeedsReplanManualScopeLimitsToTappedPastDate() {
        let suiteName = "HomeViewModelPersistenceTests.Scope.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: Date()))!
        let yesterdayTask = makeDefinition(title: "Yesterday", start: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: yesterday)!)
        let olderTask = makeDefinition(title: "Older", start: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: twoDaysAgo)!)
        let viewModel = HomeViewModel(
            useCaseCoordinator: UseCaseCoordinator(
                taskRepository: HomeViewModelMockTaskRepository(tasks: []),
                projectRepository: HomeViewModelMockProjectRepository(projects: [Project.createInbox()])
            ),
            userDefaults: defaults
        )
        waitForMainQueueFlush()

        let scoped = viewModel.needsReplanCandidatesForTesting(from: [olderTask, yesterdayTask], scopedTo: twoDaysAgo)

        XCTAssertEqual(scoped.map { $0.task.title }, ["Older"])
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultReplanPlacementDaySwitchesAtFivePM() {
        let suiteName = "HomeViewModelPersistenceTests.Cutoff.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let viewModel = HomeViewModel(
            useCaseCoordinator: UseCaseCoordinator(
                taskRepository: HomeViewModelMockTaskRepository(tasks: []),
                projectRepository: HomeViewModelMockProjectRepository(projects: [Project.createInbox()])
            ),
            userDefaults: defaults
        )
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let beforeFive = calendar.date(bySettingHour: 16, minute: 59, second: 0, of: day)!
        let atFive = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day)!

        XCTAssertEqual(viewModel.defaultReplanPlacementDayForTesting(now: beforeFive), day)
        XCTAssertEqual(
            viewModel.defaultReplanPlacementDayForTesting(now: atFive),
            calendar.date(byAdding: .day, value: 1, to: day)
        )
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testNeedsReplanSummaryCopy() {
        let summary = NeedsReplanSummary(count: 12, dayCount: 3, newestDate: nil, oldestDate: nil)

        XCTAssertEqual(summary.title, "Needs Replan")
        XCTAssertEqual(summary.subtitle, "12 unfinished - start with the most recent")
        XCTAssertEqual(summary.callToAction, "Start")
    }

    func testAssistantSnapshotRoundTripsReplanScheduleFields() {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 9, minute: 15, second: 0, of: calendar.startOfDay(for: Date()))!
        let end = start.addingTimeInterval(45 * 60)
        let task = TaskDefinition(
            title: "Round trip",
            dueDate: start,
            scheduledStartAt: start,
            scheduledEndAt: end,
            isAllDay: false,
            replanCount: 3
        )

        let restored = AssistantTaskSnapshot(task: task).toTaskDefinition()

        XCTAssertEqual(restored.scheduledStartAt, start)
        XCTAssertEqual(restored.scheduledEndAt, end)
        XCTAssertFalse(restored.isAllDay)
        XCTAssertEqual(restored.replanCount, 3)
    }

    func testNeedsReplanBottomBarSuppressionByPhase() {
        let summary = NeedsReplanSummary(count: 2, dayCount: 1, newestDate: Date(), oldestDate: Date())
        let candidate = HomeReplanCandidate(
            task: makeDefinition(title: "Replan", start: Date()),
            originalDate: Date(),
            originalEndDate: nil,
            projectName: nil
        )
        let outcomes = HomeReplanOutcomeSummary()

        func state(_ phase: HomeReplanSessionPhase) -> HomeReplanSessionState {
            HomeReplanSessionState(
                phase: phase,
                summary: summary,
                currentCandidate: candidate,
                candidateIndex: 1,
                candidateTotal: 2,
                canUndo: false,
                outcomes: outcomes,
                skippedCount: 0,
                isApplying: false,
                applyingAction: nil,
                errorMessage: nil
            )
        }

        XCTAssertFalse(state(.trayHidden).suppressesBottomBar)
        XCTAssertFalse(state(.trayVisible(summary)).suppressesBottomBar)
        XCTAssertFalse(state(.launcher(summary)).suppressesBottomBar)
        XCTAssertTrue(state(.card(candidateIndex: 1)).suppressesBottomBar)
        XCTAssertTrue(state(.placement(candidate, defaultDay: Date())).suppressesBottomBar)
        XCTAssertTrue(state(.summary(outcomes, skippedCount: 0)).suppressesBottomBar)
        XCTAssertTrue(state(.skippedReview).suppressesBottomBar)
    }

    func testCancelCurrentReplanPlacementReturnsToSameCard() {
        let suiteName = "HomeViewModelPersistenceTests.ReplanCancel.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: calendar.startOfDay(for: Date()))!
        let candidate = HomeReplanCandidate(
            task: makeDefinition(title: "Place me", start: start),
            originalDate: start,
            originalEndDate: start.addingTimeInterval(30 * 60),
            projectName: "Home"
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: UseCaseCoordinator(
                taskRepository: HomeViewModelMockTaskRepository(tasks: []),
                projectRepository: HomeViewModelMockProjectRepository(projects: [Project.createInbox()])
            ),
            userDefaults: defaults
        )

        viewModel.beginReplanPlacementForTesting(candidate: candidate)
        viewModel.cancelCurrentReplanPlacement()

        if case .card(let index) = viewModel.homeReplanState.phase {
            XCTAssertEqual(index, 1)
        } else {
            XCTFail("Expected card phase after canceling placement")
        }
        XCTAssertEqual(viewModel.homeReplanState.currentCandidate?.id, candidate.id)
        XCTAssertEqual(viewModel.homeReplanState.outcomes.totalResolved, 0)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testNeedsReplanApplyingStateBlocksSkipAndPlacementCancel() {
        let suiteName = "HomeViewModelPersistenceTests.ReplanApplying.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: calendar.startOfDay(for: Date()))!
        let candidate = HomeReplanCandidate(
            task: makeDefinition(title: "Busy", start: start),
            originalDate: start,
            originalEndDate: start.addingTimeInterval(30 * 60),
            projectName: nil
        )
        let viewModel = HomeViewModel(
            useCaseCoordinator: UseCaseCoordinator(
                taskRepository: HomeViewModelMockTaskRepository(tasks: []),
                projectRepository: HomeViewModelMockProjectRepository(projects: [Project.createInbox()])
            ),
            userDefaults: defaults
        )

        viewModel.beginReplanPlacementForTesting(candidate: candidate)
        viewModel.setReplanApplyingForTesting(.reschedule)
        viewModel.skipCurrentReplanCandidate()
        viewModel.cancelCurrentReplanPlacement()

        XCTAssertTrue(viewModel.homeReplanState.isApplying)
        XCTAssertEqual(viewModel.homeReplanState.currentCandidate?.id, candidate.id)
        if case .placement(let activeCandidate, _) = viewModel.homeReplanState.phase {
            XCTAssertEqual(activeCandidate.id, candidate.id)
        } else {
            XCTFail("Applying state should keep placement active")
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testInsightsViewModelIsRetainedAcrossRequests() {
        let suiteName = "HomeViewModelPersistenceTests.InsightsRetention.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: [makeTask(name: "Task", project: inbox)]),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertTrue(viewModel.makeInsightsViewModel() === viewModel.makeInsightsViewModel())

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testInsightsViewModelIsReleasedWhenSurfaceCloses() {
        let suiteName = "HomeViewModelPersistenceTests.InsightsRelease.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: [makeTask(name: "Task", project: inbox)]),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        let first = viewModel.makeInsightsViewModel()
        viewModel.releaseInsightsViewModel()
        let second = viewModel.makeInsightsViewModel()

        XCTAssertFalse(first === second)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSearchViewModelIsRetainedAcrossRequests() {
        let suiteName = "HomeViewModelPersistenceTests.SearchRetention.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: [makeTask(name: "Task", project: inbox)]),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertTrue(viewModel.makeHomeSearchViewModel() === viewModel.makeHomeSearchViewModel())

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSearchViewModelIsReleasedWhenSurfaceCloses() {
        let suiteName = "HomeViewModelPersistenceTests.SearchRelease.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: [makeTask(name: "Task", project: inbox)]),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        let first = viewModel.makeHomeSearchViewModel()
        viewModel.releaseHomeSearchViewModel()
        let second = viewModel.makeHomeSearchViewModel()

        XCTAssertFalse(first === second)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFocusTasksRankingPrioritizesOverdueThenDueTodayThenXP() {
        let suiteName = "HomeViewModelPersistenceTests.FocusRanking.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? now
        let todayMorning = calendar.date(byAdding: .hour, value: 9, to: startOfToday) ?? now
        let todayEvening = calendar.date(byAdding: .hour, value: 18, to: startOfToday) ?? now

        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Today Low", project: inbox, dueDate: todayMorning, priority: .low),
            makeTask(name: "Overdue Low", project: inbox, dueDate: yesterday, priority: .low),
            makeTask(name: "Today High", project: inbox, dueDate: todayEvening, priority: .high),
            makeTask(name: "Overdue High", project: inbox, dueDate: yesterday, priority: .high)
        ]

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        if V2FeatureFlags.evaFocusEnabled {
            XCTAssertEqual(viewModel.focusTasks.map(\.title), ["Today High", "Overdue High", "Today Low"])
        } else {
            XCTAssertEqual(viewModel.focusTasks.map(\.title), ["Overdue High", "Overdue Low", "Today High"])
        }

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFocusTasksTieBreakUsesStableUUIDOrdering() {
        let suiteName = "HomeViewModelPersistenceTests.FocusStableID.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let idA = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let inbox = Project.createInbox()

        let taskA = makeTask(id: idA, name: "A", project: inbox, dueDate: now, priority: .low)
        let taskB = makeTask(id: idB, name: "B", project: inbox, dueDate: now, priority: .low)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [taskB, taskA])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.focusTasks.map(\.id), [idA, idB])

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPinnedFocusTasksPersistAcrossSessions() {
        let suiteName = "HomeViewModelPersistenceTests.PinnedPersist.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let pinCandidate = makeTask(name: "Pin me", project: inbox, dueDate: Date(), priority: .low)
        let supportA = makeTask(name: "Support A", project: inbox, dueDate: Date(), priority: .high)
        let supportB = makeTask(name: "Support B", project: inbox, dueDate: Date(), priority: .high)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [pinCandidate, supportA, supportB])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModelA = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModelA.pinTaskToFocus(pinCandidate.id), .pinned)
        XCTAssertEqual(viewModelA.pinnedFocusTaskIDs.first, pinCandidate.id)

        let viewModelB = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModelB.pinnedFocusTaskIDs, [pinCandidate.id])
        XCTAssertEqual(viewModelB.focusTasks.first?.id, pinCandidate.id)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFocusTasksComposePinnedFirstWithAutofillRanking() {
        let suiteName = "HomeViewModelPersistenceTests.FocusComposed.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? now
        let evening = calendar.date(byAdding: .hour, value: 18, to: startOfToday) ?? now

        let inbox = Project.createInbox()
        let pinnedLow = makeTask(name: "Pinned Low", project: inbox, dueDate: evening, priority: .low)
        let overdueHigh = makeTask(name: "Overdue High", project: inbox, dueDate: yesterday, priority: .high)
        let overdueLow = makeTask(name: "Overdue Low", project: inbox, dueDate: yesterday, priority: .low)
        let todayHigh = makeTask(name: "Today High", project: inbox, dueDate: evening, priority: .high)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [todayHigh, overdueLow, overdueHigh, pinnedLow])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.pinTaskToFocus(pinnedLow.id), .pinned)
        if V2FeatureFlags.evaFocusEnabled {
            XCTAssertEqual(viewModel.focusTasks.map(\.title), ["Pinned Low", "Today High", "Overdue High"])
        } else {
            XCTAssertEqual(viewModel.focusTasks.map(\.title), ["Pinned Low", "Overdue High", "Overdue Low"])
        }

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPinTaskRejectsFourthPinAtCapacity() {
        let suiteName = "HomeViewModelPersistenceTests.PinCapacity.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let tasks = (1...4).map { index in
            makeTask(name: "Pin \(index)", project: inbox, dueDate: Date(), priority: .low)
        }

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[0].id), .pinned)
        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[1].id), .pinned)
        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[2].id), .pinned)
        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[3].id), .capacityReached(limit: 3))
        XCTAssertEqual(viewModel.pinnedFocusTaskIDs, [tasks[0].id, tasks[1].id, tasks[2].id])

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPromoteTaskToFocusPinsTaskWhenCapacityIsAvailable() {
        let suiteName = "HomeViewModelPersistenceTests.PromoteAvailable.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let promoted = makeTask(name: "Agenda Promote", project: inbox, dueDate: Date(), priority: .low)
        let support = makeTask(name: "Support", project: inbox, dueDate: Date(), priority: .high)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [promoted, support])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.promoteTaskToFocus(promoted.id), .promoted)
        XCTAssertEqual(viewModel.pinnedFocusTaskIDs, [promoted.id])
        let focusedTaskIDs = viewModel.focusRows.compactMap { row -> UUID? in
            guard case .task(let task) = row else { return nil }
            return task.id
        }
        XCTAssertEqual(focusedTaskIDs.first, promoted.id)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTodayHomeExcludesPinnedFocusTasksFromAgendaAndSections() {
        let suiteName = "HomeViewModelPersistenceTests.FocusDedupPinned.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let pinnedLow = makeTask(name: "Pinned Low", project: inbox, dueDate: Date(), priority: .low)
        let highA = makeTask(name: "High A", project: inbox, dueDate: Date(), priority: .high)
        let highB = makeTask(name: "High B", project: inbox, dueDate: Date(), priority: .high)
        let backlog = makeTask(name: "Backlog", project: inbox, dueDate: Date(), priority: .low)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [pinnedLow, highA, highB, backlog])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.pinTaskToFocus(pinnedLow.id), .pinned)
        waitForMainQueueFlush()

        let focusTaskIDs = visibleFocusTaskIDs(in: viewModel.focusRows)
        XCTAssertTrue(focusTaskIDs.contains(pinnedLow.id))

        let agendaTaskIDs = taskIDs(in: viewModel.todaySections)
        let dueTodayTaskIDs = taskIDs(in: viewModel.dueTodayRows)

        XCTAssertFalse(agendaTaskIDs.contains(pinnedLow.id))
        XCTAssertFalse(dueTodayTaskIDs.contains(pinnedLow.id))
        XCTAssertTrue(agendaTaskIDs.isDisjoint(with: focusTaskIDs))
        XCTAssertTrue(dueTodayTaskIDs.isDisjoint(with: focusTaskIDs))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTodayHomeExcludesAllVisibleFocusTasksFromAgenda() {
        let suiteName = "HomeViewModelPersistenceTests.FocusDedupAllVisible.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Focus A", project: inbox, dueDate: Date(), priority: .high),
            makeTask(name: "Focus B", project: inbox, dueDate: Date(), priority: .high),
            makeTask(name: "Focus C", project: inbox, dueDate: Date(), priority: .high),
            makeTask(name: "List A", project: inbox, dueDate: Date(), priority: .low),
            makeTask(name: "List B", project: inbox, dueDate: Date(), priority: .low)
        ]

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        let focusTaskIDs = visibleFocusTaskIDs(in: viewModel.focusRows)
        let agendaTaskIDs = taskIDs(in: viewModel.todaySections)
        let dueTodayTaskIDs = taskIDs(in: viewModel.dueTodayRows)

        XCTAssertEqual(focusTaskIDs.count, 3)
        XCTAssertTrue(agendaTaskIDs.isDisjoint(with: focusTaskIDs))
        XCTAssertTrue(dueTodayTaskIDs.isDisjoint(with: focusTaskIDs))
        XCTAssertEqual(agendaTaskIDs.count, 2)
        XCTAssertEqual(dueTodayTaskIDs.count, 2)
        XCTAssertEqual(viewModel.todayOpenTaskCount, 5)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTodayHomeDropsProjectSectionWhenFocusDedupLeavesOnlyThreeTasks() {
        let suiteName = "HomeViewModelPersistenceTests.FocusDedupProjectThreshold.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let work = Project(id: UUID(), name: "Work", icon: .work)
        let side = Project(id: UUID(), name: "Side", icon: .creative)

        let pinnedWork = makeTask(name: "Work 1", project: work, dueDate: Date(), priority: .low)
        let work2 = makeTask(name: "Work 2", project: work, dueDate: Date(), priority: .low)
        let work3 = makeTask(name: "Work 3", project: work, dueDate: Date(), priority: .low)
        let work4 = makeTask(name: "Work 4", project: work, dueDate: Date(), priority: .low)
        let inboxHigh = makeTask(name: "Inbox High", project: inbox, dueDate: Date(), priority: .high)
        let sideHigh = makeTask(name: "Side High", project: side, dueDate: Date(), priority: .high)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [pinnedWork, work2, work3, work4, inboxHigh, sideHigh])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox, work, side])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.pinTaskToFocus(pinnedWork.id), .pinned)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.todaySections.count, 1)
        XCTAssertFalse(viewModel.todaySections[0].showsHeader)
        XCTAssertEqual(taskTitles(in: viewModel.todaySections), ["Work 2", "Work 3", "Work 4"])

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTodayHomeDropsInboxSectionWhenFocusDedupLeavesOnlyThreeInboxTasks() {
        let suiteName = "HomeViewModelPersistenceTests.FocusDedupInboxThreshold.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let work = Project(id: UUID(), name: "Work", icon: .work)
        let side = Project(id: UUID(), name: "Side", icon: .creative)

        let pinnedInbox = makeTask(name: "Inbox 1", project: inbox, dueDate: Date(), priority: .low)
        let inbox2 = makeTask(name: "Inbox 2", project: inbox, dueDate: Date(), priority: .low)
        let inbox3 = makeTask(name: "Inbox 3", project: inbox, dueDate: Date(), priority: .low)
        let inbox4 = makeTask(name: "Inbox 4", project: inbox, dueDate: Date(), priority: .low)
        let workHigh = makeTask(name: "Work High", project: work, dueDate: Date(), priority: .high)
        let sideHigh = makeTask(name: "Side High", project: side, dueDate: Date(), priority: .high)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [pinnedInbox, inbox2, inbox3, inbox4, workHigh, sideHigh])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox, work, side])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.pinTaskToFocus(pinnedInbox.id), .pinned)
        waitForMainQueueFlush()

        XCTAssertFalse(viewModel.todaySections.contains { $0.showsHeader && $0.anchor.isInboxProject })
        XCTAssertEqual(taskTitles(in: viewModel.todaySections), ["Inbox 2", "Inbox 3", "Inbox 4"])

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testVisibleFocusTaskExclusionIgnoresHabitRows() {
        let inbox = Project.createInbox()
        let task = makeTask(name: "Task", project: inbox, dueDate: Date(), priority: .low)
        let habit = HomeHabitRow(
            habitID: UUID(),
            title: "Habit",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaName: "Health",
            projectID: inbox.id,
            projectName: inbox.name,
            iconSymbolName: "drop.fill",
            dueAt: Date(),
            state: .overdue
        )

        let filtered = HomeViewModel.excludingVisibleFocusTasks(
            from: [task],
            focusRows: [.habit(habit)]
        )

        XCTAssertEqual(filtered.map(\.id), [task.id])
    }

    func testPromoteTaskToFocusRequestsReplacementWhenHeroIsFull() {
        let suiteName = "HomeViewModelPersistenceTests.PromoteReplacePrompt.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let tasks = (1...4).map { index in
            makeTask(name: "Focus \(index)", project: inbox, dueDate: Date(), priority: .high)
        }

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[0].id), .pinned)
        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[1].id), .pinned)
        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[2].id), .pinned)

        let result = viewModel.promoteTaskToFocus(tasks[3].id)
        XCTAssertEqual(result, .replacementRequired(currentFocusTaskIDs: [tasks[0].id, tasks[1].id, tasks[2].id]))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testReplaceFocusTaskSwapsVisibleHeroSelection() {
        let suiteName = "HomeViewModelPersistenceTests.ReplaceFocus.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let tasks = (1...4).map { index in
            makeTask(name: "Replace \(index)", project: inbox, dueDate: Date(), priority: .high)
        }

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[0].id), .pinned)
        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[1].id), .pinned)
        XCTAssertEqual(viewModel.pinTaskToFocus(tasks[2].id), .pinned)

        XCTAssertEqual(viewModel.replaceFocusTask(with: tasks[3].id, replacing: tasks[1].id), .promoted)
        XCTAssertEqual(viewModel.pinnedFocusTaskIDs, [tasks[3].id, tasks[0].id, tasks[2].id])
        let focusedTaskIDs = viewModel.focusRows.compactMap { row -> UUID? in
            guard case .task(let task) = row else { return nil }
            return task.id
        }
        XCTAssertTrue(focusedTaskIDs.contains(tasks[3].id))
        XCTAssertFalse(focusedTaskIDs.contains(tasks[1].id))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPinnedTaskPrunesAfterCompletion() {
        let suiteName = "HomeViewModelPersistenceTests.PinPruneCompletion.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let pinnedTask = makeTask(name: "Pinned", project: inbox, dueDate: Date(), priority: .low)
        let highA = makeTask(name: "High A", project: inbox, dueDate: Date(), priority: .high)
        let highB = makeTask(name: "High B", project: inbox, dueDate: Date(), priority: .high)
        let highC = makeTask(name: "High C", project: inbox, dueDate: Date(), priority: .high)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [pinnedTask, highA, highB, highC])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.pinTaskToFocus(pinnedTask.id), .pinned)
        viewModel.toggleTaskCompletion(pinnedTask)
        waitForMainQueueFlush()

        XCTAssertFalse(viewModel.pinnedFocusTaskIDs.contains(pinnedTask.id))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPinnedTaskPrunesAfterDelete() {
        let suiteName = "HomeViewModelPersistenceTests.PinPruneDelete.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let pinnedTask = makeTask(name: "Pinned Delete", project: inbox, dueDate: Date(), priority: .low)
        let otherTask = makeTask(name: "Other", project: inbox, dueDate: Date(), priority: .high)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [pinnedTask, otherTask])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.pinTaskToFocus(pinnedTask.id), .pinned)
        viewModel.deleteTask(pinnedTask)
        waitForMainQueueFlush()

        XCTAssertFalse(viewModel.pinnedFocusTaskIDs.contains(pinnedTask.id))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPinTaskIneligibleOutsideTodayScope() {
        let suiteName = "HomeViewModelPersistenceTests.PinScopeGate.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let upcomingDueDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        let task = makeTask(name: "Upcoming", project: inbox, dueDate: upcomingDueDate, priority: .low)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [task])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        viewModel.setQuickView(.upcoming)
        waitForMainQueueFlush()

        XCTAssertFalse(viewModel.canUseManualFocusDrag)
        XCTAssertEqual(viewModel.pinTaskToFocus(task.id), .taskIneligible)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSelectingCustomDateDoesNotRetainCompletedTasksFromDifferentDay() {
        let suiteName = "HomeViewModelPersistenceTests.CustomDateCompletedScope.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let todayDue = calendar.date(byAdding: .hour, value: 9, to: startOfToday) ?? now
        let todayCompleted = calendar.date(byAdding: .hour, value: 10, to: startOfToday) ?? now

        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let tomorrowDue = calendar.date(byAdding: .hour, value: 9, to: tomorrowStart) ?? tomorrowStart

        let inbox = Project.createInbox()
        let completedToday = makeTask(
            name: "Completed Today",
            project: inbox,
            dueDate: todayDue,
            priority: .high,
            isComplete: true,
            dateCompleted: todayCompleted
        )
        let openTomorrow = makeTask(
            name: "Open Tomorrow",
            project: inbox,
            dueDate: tomorrowDue,
            priority: .low,
            isComplete: false
        )

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [completedToday, openTomorrow])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)

        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertTrue(viewModel.completedTasks.contains(where: { $0.title == "Completed Today" }))

        viewModel.selectDate(tomorrowDue)
        waitForMainQueueFlush()

        XCTAssertTrue(viewModel.completedTasks.isEmpty)
        XCTAssertFalse(viewModel.morningTasks.contains(where: { $0.title == "Completed Today" }))
        XCTAssertFalse(viewModel.eveningTasks.contains(where: { $0.title == "Completed Today" }))
        XCTAssertFalse(viewModel.overdueTasks.contains(where: { $0.title == "Completed Today" }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTodayCompletionRateIncludesOverdueTasksAfterAnalyticsRefresh() {
        let suiteName = "HomeViewModelPersistenceTests.TodayCompletionRate.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let overdueDate = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let dueToday = calendar.date(byAdding: .hour, value: 10, to: startOfToday)!
        let completedTodayAt = calendar.date(byAdding: .hour, value: 14, to: startOfToday)!

        let overdueOpen = makeTask(
            name: "Overdue Open",
            project: inbox,
            dueDate: overdueDate,
            priority: .high,
            isComplete: false
        )
        let dueTodayOpen = makeTask(
            name: "Due Today Open",
            project: inbox,
            dueDate: dueToday,
            priority: .low,
            isComplete: false
        )
        let completedToday = makeTask(
            name: "Completed Today",
            project: inbox,
            dueDate: dueToday,
            priority: .low,
            isComplete: true,
            dateCompleted: completedTodayAt
        )

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [overdueOpen, dueTodayOpen, completedToday])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.completionRate, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.viewState.completionRate, 1.0 / 3.0, accuracy: 0.0001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCustomDateCompletionRateIncludesOverdueRelativeToSelectedDate() {
        let suiteName = "HomeViewModelPersistenceTests.CustomDateCompletionRate.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let anchorDate = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let dueOnAnchor = calendar.date(byAdding: .hour, value: 9, to: anchorDate)!
        let overdueRelativeToAnchor = calendar.date(byAdding: .day, value: -1, to: dueOnAnchor)!
        let completedOnAnchorAt = calendar.date(byAdding: .hour, value: 15, to: anchorDate)!

        let openOnAnchor = makeTask(
            name: "Open On Anchor",
            project: inbox,
            dueDate: dueOnAnchor,
            priority: .high,
            isComplete: false
        )
        let overdueOpen = makeTask(
            name: "Overdue Relative Anchor",
            project: inbox,
            dueDate: overdueRelativeToAnchor,
            priority: .low,
            isComplete: false
        )
        let completedOnAnchor = makeTask(
            name: "Completed On Anchor",
            project: inbox,
            dueDate: dueOnAnchor,
            priority: .low,
            isComplete: true,
            dateCompleted: completedOnAnchorAt
        )

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [openOnAnchor, overdueOpen, completedOnAnchor])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueueFlush()
        viewModel.selectDate(anchorDate)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.completionRate, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.viewState.completionRate, 1.0 / 3.0, accuracy: 0.0001)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testEvaShuffleExcludesRecentSelectionsWhenPoolIsLargeEnough() {
        let suiteName = "HomeViewModelPersistenceTests.EvaShuffle.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let baseDue = calendar.date(byAdding: .hour, value: 9, to: startOfToday) ?? now

        let tasks: [Task] = (0..<6).map { index in
            makeTask(
                name: "Shuffle \(index)",
                project: inbox,
                dueDate: calendar.date(byAdding: .minute, value: index, to: baseDue),
                priority: .high,
                isComplete: false
            )
        }

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        viewModel.shuffleFocusNow()
        waitForMainQueueFlush()
        let firstShuffle = Set(viewModel.focusTasks.map(\.id))

        viewModel.shuffleFocusNow()
        waitForMainQueueFlush()
        let secondShuffle = Set(viewModel.focusTasks.map(\.id))

        XCTAssertEqual(firstShuffle.count, 3)
        XCTAssertEqual(secondShuffle.count, 3)
        XCTAssertTrue(firstShuffle.isDisjoint(with: secondShuffle))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testEvaFocusRationaleRemainsStableAcrossReload() {
        let suiteName = "HomeViewModelPersistenceTests.EvaRationale.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let now = Date()
        let overdue = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now

        let target = makeTask(
            name: "Rationale target",
            project: inbox,
            dueDate: overdue,
            priority: .high,
            isComplete: false
        )
        let supportA = makeTask(name: "Support A", project: inbox, dueDate: now, priority: .low, isComplete: false)
        let supportB = makeTask(name: "Support B", project: inbox, dueDate: now, priority: .low, isComplete: false)

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [target, supportA, supportB])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        guard let firstRationale = viewModel.evaFocusInsight(for: target.id)?.rationale.map(\.factor),
              !firstRationale.isEmpty else {
            return XCTFail("Expected initial Eva rationale for target task")
        }

        viewModel.loadTodayTasks()
        waitForMainQueueFlush()

        let secondRationale = viewModel.evaFocusInsight(for: target.id)?.rationale.map(\.factor)
        XCTAssertEqual(secondRationale, firstRationale)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testOpenFocusWhyPresentsWhySheet() {
        let suiteName = "HomeViewModelPersistenceTests.EvaWhySheet.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let task = makeTask(
            name: "Focus candidate",
            project: inbox,
            dueDate: Date(),
            priority: .high,
            isComplete: false
        )

        let taskRepository = HomeViewModelMockTaskRepository(tasks: [task])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertFalse(viewModel.evaFocusWhySheetPresented)

        viewModel.openFocusWhy()

        XCTAssertTrue(viewModel.evaFocusWhySheetPresented)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testOpenFocusWhyPopulatesShuffleCandidatesFromNonFocusedTasks() {
        let suiteName = "HomeViewModelPersistenceTests.EvaWhyCandidates.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Focus A", project: inbox, dueDate: now, priority: .high, updatedAt: now),
            makeTask(name: "Focus B", project: inbox, dueDate: Calendar.current.date(byAdding: .minute, value: 30, to: now), priority: .high, updatedAt: now),
            makeTask(name: "Focus C", project: inbox, dueDate: Calendar.current.date(byAdding: .hour, value: 1, to: now), priority: .high, updatedAt: now),
            makeTask(name: "Candidate D", project: inbox, dueDate: Calendar.current.date(byAdding: .hour, value: 3, to: now), priority: .low, updatedAt: now)
        ]

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        let visibleFocusIDs = Set(viewModel.focusTasks.map(\.id))

        viewModel.openFocusWhy()

        XCTAssertTrue(viewModel.evaFocusWhySheetPresented)
        XCTAssertFalse(viewModel.focusWhyShuffleCandidates.isEmpty)
        XCTAssertTrue(viewModel.focusWhyShuffleCandidates.allSatisfy { !visibleFocusIDs.contains($0.id) })

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRefreshingWhyShuffleCandidatesDoesNotMutateFocusSelection() {
        let suiteName = "HomeViewModelPersistenceTests.EvaWhyRefresh.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Pinned One", project: inbox, dueDate: now, priority: .high, updatedAt: now),
            makeTask(name: "Pinned Two", project: inbox, dueDate: Calendar.current.date(byAdding: .minute, value: 20, to: now), priority: .high, updatedAt: now),
            makeTask(name: "Pinned Three", project: inbox, dueDate: Calendar.current.date(byAdding: .minute, value: 40, to: now), priority: .high, updatedAt: now),
            makeTask(name: "Swap Candidate", project: inbox, dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: now), priority: .low, updatedAt: now),
            makeTask(name: "Swap Candidate Two", project: inbox, dueDate: Calendar.current.date(byAdding: .hour, value: 4, to: now), priority: .low, updatedAt: now)
        ]

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        let originalFocusIDs = viewModel.focusTasks.map(\.id)
        let candidates = viewModel.refreshFocusWhyShuffleCandidates()

        XCTAssertEqual(viewModel.focusTasks.map(\.id), originalFocusIDs)
        XCTAssertEqual(viewModel.focusWhyShuffleCandidates.map(\.id), candidates.map(\.id))
        XCTAssertTrue(candidates.allSatisfy { originalFocusIDs.contains($0.id) == false })

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFocusWhyCandidatesRefreshWhenOpenTaskPoolChangesWhileSheetIsPresented() {
        let suiteName = "HomeViewModelPersistenceTests.EvaWhyRefreshWhilePresented.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Pinned One", project: inbox, dueDate: now, priority: .high, updatedAt: now),
            makeTask(name: "Pinned Two", project: inbox, dueDate: Calendar.current.date(byAdding: .minute, value: 20, to: now), priority: .high, updatedAt: now),
            makeTask(name: "Pinned Three", project: inbox, dueDate: Calendar.current.date(byAdding: .minute, value: 40, to: now), priority: .high, updatedAt: now),
            makeTask(name: "Swap Candidate", project: inbox, dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: now), priority: .low, updatedAt: now)
        ]

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        viewModel.openFocusWhy()
        guard let candidate = viewModel.focusWhyShuffleCandidates.first else {
            defaults.removePersistentDomain(forName: suiteName)
            return XCTFail("Expected a shuffle candidate before mutating the open-task pool")
        }

        viewModel.toggleTaskCompletion(candidate)
        waitForMainQueueFlush()

        XCTAssertFalse(viewModel.focusWhyShuffleCandidates.contains(where: { $0.id == candidate.id }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testGroupedOverlayStateCoalescesSynchronousMutationsIntoSinglePublish() {
        let suiteName = "HomeViewModelPersistenceTests.GroupedOverlayCoalescing.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let taskRepository = HomeViewModelMockTaskRepository(tasks: [])
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        var emittedStates: [HomeOverlayState] = []
        viewModel.$homeRenderTransaction
            .map(\.overlay)
            .dropFirst()
            .sink { emittedStates.append($0) }
            .store(in: &cancellables)

        let xpResult = XPEventResult(
            awardedXP: 12,
            totalXP: 120,
            level: 2,
            previousLevel: 1,
            currentStreak: 3,
            didLevelUp: false,
            dailyXPSoFar: 12,
            dailyCap: 100,
            unlockedAchievements: [],
            crossedMilestone: nil,
            celebration: nil
        )

        viewModel.openFocusWhy()
        viewModel.dispatchCelebration(xpResult)
        waitForMainQueueFlush()

        XCTAssertEqual(emittedStates.count, 1)
        XCTAssertEqual(emittedStates.last?.focusWhyPresented, true)
        XCTAssertEqual(emittedStates.last?.lastXPResult?.awardedXP, xpResult.awardedXP)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testGroupedHomeStatesStayAlignedAfterGroupingMutation() {
        let suiteName = "HomeViewModelPersistenceTests.GroupedStatesAligned.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let alpha = Project(id: UUID(), name: "Alpha", icon: .folder)
        let beta = Project(id: UUID(), name: "Beta", icon: .folder)
        let tasks = [
            makeTask(name: "Alpha task", project: alpha, dueDate: Date(), priority: .high),
            makeTask(name: "Beta task", project: beta, dueDate: Date(), priority: .low)
        ]

        let taskRepository = HomeViewModelMockTaskRepository(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox, alpha, beta])
        let coordinator = UseCaseCoordinator(taskRepository: taskRepository, projectRepository: projectRepository)
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        viewModel.setProjectGroupingMode(.groupByProjects)
        viewModel.setCustomProjectOrder([beta.id, alpha.id])
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.activeFilterState.projectGroupingMode, .groupByProjects)
        XCTAssertEqual(Array(viewModel.activeFilterState.customProjectOrderIDs.prefix(2)), [beta.id, alpha.id])

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRescueTailIncludesOnlyTasksOlderThanTwoWeeksAndRemovesThemFromAgendaAndFocus() {
        let suiteName = "HomeViewModelPersistenceTests.RescuePartition.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let calendar = Calendar.current
        let inbox = Project.createInbox()
        let tasks = [
            makeTask(
                name: "Rescue Older",
                project: inbox,
                dueDate: calendar.date(byAdding: .day, value: -20, to: now),
                priority: .high
            ),
            makeTask(
                name: "Rescue Old",
                project: inbox,
                dueDate: calendar.date(byAdding: .day, value: -16, to: now),
                priority: .max
            ),
            makeTask(
                name: "Agenda Overdue",
                project: inbox,
                dueDate: calendar.date(byAdding: .day, value: -5, to: now),
                priority: .high
            ),
            makeTask(
                name: "Due Today",
                project: inbox,
                dueDate: calendar.date(byAdding: .hour, value: 6, to: calendar.startOfDay(for: now)),
                priority: .low
            ),
            makeTask(
                name: "Stale Important",
                project: inbox,
                dueDate: nil,
                priority: .high,
                updatedAt: calendar.date(byAdding: .day, value: -30, to: now) ?? now
            )
        ]

        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: tasks),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        let rescueTitles = rescueTailState(from: viewModel)?.rows.map(\.title)
        let agendaTitles = viewModel.todayAgendaSectionState.sections.flatMap(\.rows).map(\.title)
        let focusTitles = viewModel.focusNowSectionState.rows.map(\.title)

        XCTAssertEqual(rescueTitles, ["Rescue Older", "Rescue Old"])
        XCTAssertTrue(agendaTitles.contains("Agenda Overdue"))
        XCTAssertTrue(agendaTitles.contains("Due Today"))
        XCTAssertFalse(agendaTitles.contains("Rescue Older"))
        XCTAssertFalse(agendaTitles.contains("Rescue Old"))
        XCTAssertFalse(agendaTitles.contains("Stale Important"))
        XCTAssertFalse(focusTitles.contains("Rescue Older"))
        XCTAssertFalse(focusTitles.contains("Rescue Old"))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testOpenRescueBuildsPlanFromTwoWeekOverdueTasksOnly() {
        let suiteName = "HomeViewModelPersistenceTests.RescueOpenFilters.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let calendar = Calendar.current
        let inbox = Project.createInbox()
        let oldRescueTask = makeTask(
            name: "Old Rescue",
            project: inbox,
            dueDate: calendar.date(byAdding: .day, value: -18, to: now),
            priority: .high
        )
        let recentOverdueTask = makeTask(
            name: "Recent Overdue",
            project: inbox,
            dueDate: calendar.date(byAdding: .day, value: -4, to: now),
            priority: .high
        )

        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: [oldRescueTask, recentOverdueTask]),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        viewModel.openRescue()
        waitForMainQueueFlush()

        let plan = viewModel.evaRescuePlan
        let doTodayIDs = (plan?.doToday ?? []).map(\.taskID)
        let moveIDs = (plan?.move ?? []).map(\.taskID)
        let splitIDs = (plan?.split ?? []).map(\.taskID)
        let dropIDs = (plan?.dropCandidate ?? []).map(\.taskID)
        let recommendedTaskIDs = Set(doTodayIDs + moveIDs + splitIDs + dropIDs)

        XCTAssertTrue(recommendedTaskIDs.contains(oldRescueTask.id))
        XCTAssertFalse(recommendedTaskIDs.contains(recentOverdueTask.id))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRescueTailUsesCompactModeForOneToThreeItems() {
        let suiteName = "HomeViewModelPersistenceTests.RescueExpandSmall.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let calendar = Calendar.current
        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Rescue A", project: inbox, dueDate: calendar.date(byAdding: .day, value: -16, to: now), priority: .high),
            makeTask(name: "Rescue B", project: inbox, dueDate: calendar.date(byAdding: .day, value: -18, to: now), priority: .low),
            makeTask(name: "Focus Candidate", project: inbox, dueDate: now, priority: .high)
        ]

        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: tasks),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        guard let rescueTail = rescueTailState(from: viewModel) else {
            return XCTFail("Expected Rescue tail state")
        }

        XCTAssertEqual(rescueTail.totalCount, 2)
        XCTAssertEqual(rescueTail.mode, .compact)
        XCTAssertFalse(rescueTail.isInlineExpanded)
        XCTAssertEqual(rescueTail.subtitle, "2 tasks are 2+ weeks overdue")

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRescueTailUsesCompactModeForThreeItems() {
        let suiteName = "HomeViewModelPersistenceTests.RescueCollapseLarge.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let calendar = Calendar.current
        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Rescue A", project: inbox, dueDate: calendar.date(byAdding: .day, value: -16, to: now), priority: .high),
            makeTask(name: "Rescue B", project: inbox, dueDate: calendar.date(byAdding: .day, value: -18, to: now), priority: .low),
            makeTask(name: "Rescue C", project: inbox, dueDate: calendar.date(byAdding: .day, value: -21, to: now), priority: .max),
            makeTask(name: "Focus Candidate", project: inbox, dueDate: now, priority: .high)
        ]

        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: tasks),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        guard let rescueTail = rescueTailState(from: viewModel) else {
            return XCTFail("Expected Rescue tail state")
        }

        XCTAssertEqual(rescueTail.totalCount, 3)
        XCTAssertEqual(rescueTail.mode, .compact)
        XCTAssertFalse(rescueTail.isInlineExpanded)
        XCTAssertFalse(viewModel.focusNowSectionState.rows.isEmpty)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRescueTailUsesExpandedModeForMoreThanThreeItems() {
        let suiteName = "HomeViewModelPersistenceTests.RescueExpandNoFocus.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let calendar = Calendar.current
        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Rescue A", project: inbox, dueDate: calendar.date(byAdding: .day, value: -16, to: now), priority: .high),
            makeTask(name: "Rescue B", project: inbox, dueDate: calendar.date(byAdding: .day, value: -18, to: now), priority: .low),
            makeTask(name: "Rescue C", project: inbox, dueDate: calendar.date(byAdding: .day, value: -21, to: now), priority: .max),
            makeTask(name: "Rescue D", project: inbox, dueDate: calendar.date(byAdding: .day, value: -23, to: now), priority: .high)
        ]

        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: tasks),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        guard let rescueTail = rescueTailState(from: viewModel) else {
            return XCTFail("Expected Rescue tail state")
        }

        XCTAssertEqual(rescueTail.totalCount, 4)
        XCTAssertEqual(rescueTail.mode, .expanded)
        XCTAssertTrue(rescueTail.isInlineExpanded)
        XCTAssertTrue(viewModel.focusNowSectionState.rows.isEmpty)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRescueTailIsAbsentWhenNoRescueItemsExist() {
        let suiteName = "HomeViewModelPersistenceTests.RescueAbsent.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let now = Date()
        let calendar = Calendar.current
        let inbox = Project.createInbox()
        let tasks = [
            makeTask(name: "Due Today", project: inbox, dueDate: now, priority: .high),
            makeTask(name: "Recent Overdue", project: inbox, dueDate: calendar.date(byAdding: .day, value: -4, to: now), priority: .low)
        ]

        let coordinator = UseCaseCoordinator(
            taskRepository: HomeViewModelMockTaskRepository(tasks: tasks),
            projectRepository: HomeViewModelMockProjectRepository(projects: [inbox])
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        XCTAssertNil(rescueTailState(from: viewModel))
        XCTAssertTrue(viewModel.agendaTailItems.isEmpty)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testHabitLastCellActionAppliesOptimisticStateImmediately() {
        let harness = makeHabitMutationHarness()
        waitForMainQueueFlush()

        let loadedRows = harness.viewModel.habitHomeSectionState.primaryRows
            + harness.viewModel.habitHomeSectionState.recoveryRows
        guard let row = loadedRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")

        XCTAssertEqual(harness.viewModel.habitHomeSectionState.primaryRows.first?.state, .completedToday)
    }

    func testHabitLastCellActionPublishesImmediateMutationFeedback() {
        let harness = makeHabitMutationHarness()
        waitForMainQueueFlush()

        guard let row = firstLoadedHabitRow(in: harness.viewModel) else {
            return XCTFail("Expected habit row after initial load")
        }

        var receivedFeedback: [HomeHabitMutationFeedback] = []
        harness.viewModel.$habitMutationFeedback
            .compactMap { $0 }
            .sink { feedback in
                receivedFeedback.append(feedback)
            }
            .store(in: &cancellables)

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")

        guard let latestFeedback = receivedFeedback.last else {
            return XCTFail("Expected an immediate mutation feedback payload")
        }
        XCTAssertEqual(latestFeedback.haptic, .success)
        XCTAssertTrue(latestFeedback.message.contains("Marked done"))
    }

    func testHabitLastCellActionUpdatesVisibleStreakAndTrailingCellImmediately() {
        let harness = makeHabitMutationHarness()
        waitForMainQueueFlush()

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")

        guard let updatedRow = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected updated habit row")
        }

        XCTAssertEqual(updatedRow.currentStreak, 1)
        if case .done = updatedRow.boardCellsCompact.last?.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected compact trailing cell to render as done immediately")
        }
        if case .done = updatedRow.boardCellsExpanded.last?.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected expanded trailing cell to render as done immediately")
        }
    }

    func testHabitMutationRollsBackOptimisticStateOnFailure() {
        let harness = makeHabitMutationHarness()
        waitForMainQueueFlush()

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")
        XCTAssertEqual(harness.viewModel.habitHomeSectionState.primaryRows.first?.state, .completedToday)

        harness.schedulingEngine.completePendingResolve(with: .failure(NSError(domain: "HabitMutation", code: 1)))
        waitForMainQueueFlush()

        XCTAssertEqual(harness.viewModel.habitHomeSectionState.primaryRows.first?.state, .due)
    }

    func testHabitMutationFailurePublishesHabitScopedErrorMessage() {
        let harness = makeHabitMutationHarness()
        waitForMainQueueFlush()

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")
        harness.schedulingEngine.completePendingResolve(with: .failure(NSError(domain: "HabitMutation", code: 11)))
        waitForMainQueueFlush()

        XCTAssertNotNil(harness.viewModel.habitMutationErrorMessage)

        harness.viewModel.clearHabitMutationErrorMessage()
        XCTAssertNil(harness.viewModel.habitMutationErrorMessage)
    }

    func testHabitMutationTriggersSingleHabitScopedReload() {
        let harness = makeHabitMutationHarness()
        waitForMainQueueFlush()

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        let initialAgendaFetches = harness.habitReadRepository.fetchAgendaCallCount
        let initialTargetedAgendaFetches = harness.habitReadRepository.fetchAgendaHabitCallCount
        let initialBroadLibraryFetches = harness.habitReadRepository.fetchHabitLibraryCallCount
        let initialFilteredLibraryFetches = harness.habitReadRepository.fetchFilteredHabitLibraryCallCount

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")
        harness.schedulingEngine.completePendingResolve(with: .success(()))
        waitForMainQueueFlush(seconds: 0.45)

        XCTAssertEqual(harness.habitReadRepository.fetchAgendaCallCount, initialAgendaFetches)
        XCTAssertEqual(harness.habitReadRepository.fetchAgendaHabitCallCount, initialTargetedAgendaFetches + 1)
        XCTAssertEqual(harness.habitReadRepository.fetchHabitLibraryCallCount, initialBroadLibraryFetches)
        XCTAssertEqual(
            harness.habitReadRepository.fetchFilteredHabitLibraryCallCount,
            initialFilteredLibraryFetches + 1
        )
    }

    func testHabitMutationDoesNotTriggerFullTaskProjectionReload() {
        let harness = makeHabitMutationHarness()
        waitForMainQueueFlush()

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        let initialProjectionFetches = harness.taskReadRepository.fetchHomeProjectionCallCount

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")
        harness.schedulingEngine.completePendingResolve(with: .success(()))
        waitForMainQueueFlush(seconds: 0.45)

        XCTAssertEqual(harness.taskReadRepository.fetchHomeProjectionCallCount, initialProjectionFetches)
    }

    func testHabitMutationDoesNotChangeTaskBackedFocusNow() {
        let now = Date()
        let harness = makeHabitMutationHarness(
            tasks: [
                TaskDefinition(
                    title: "Deep Work",
                    priority: .high,
                    dueDate: now
                )
            ]
        )
        waitForMainQueueFlush()

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        let initialFocusRows = harness.viewModel.focusNowSectionState.rows
        XCTAssertFalse(initialFocusRows.isEmpty)
        XCTAssertTrue(initialFocusRows.allSatisfy { !$0.isHabit })

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")
        XCTAssertEqual(harness.viewModel.focusNowSectionState.rows, initialFocusRows)

        harness.schedulingEngine.completePendingResolve(with: .success(()))
        waitForMainQueueFlush(seconds: 0.45)

        XCTAssertEqual(harness.viewModel.focusNowSectionState.rows, initialFocusRows)
    }

    func testHabitMutationKeepsTodayAgendaShellStableWhenOnlyHabitRowChanges() {
        let now = Date()
        let inbox = Project.createInbox()
        let harness = makeHabitMutationHarness(
            tasks: [
                makeTask(name: "Agenda Task", project: inbox, dueDate: now, priority: .high)
            ]
        )
        waitForMainQueueFlush()

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        let initialTodaySections = harness.viewModel.todaySections
        let initialTodayAgendaSectionState = harness.viewModel.todayAgendaSectionState
        let initialAgendaTailItems = harness.viewModel.agendaTailItems

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")

        XCTAssertEqual(harness.viewModel.todaySections, initialTodaySections)
        XCTAssertEqual(harness.viewModel.todayAgendaSectionState, initialTodayAgendaSectionState)
        XCTAssertEqual(harness.viewModel.agendaTailItems, initialAgendaTailItems)

        harness.schedulingEngine.completePendingResolve(with: .success(()))
        waitForMainQueueFlush(seconds: 0.45)

        XCTAssertEqual(harness.viewModel.todaySections, initialTodaySections)
        XCTAssertEqual(harness.viewModel.todayAgendaSectionState, initialTodayAgendaSectionState)
        XCTAssertEqual(harness.viewModel.agendaTailItems, initialAgendaTailItems)
    }

    func testHabitMutationOptimisticallyRemovesResolvedHabitFromAgendaWithoutTouchingTasks() {
        let now = Date()
        let inbox = Project.createInbox()
        let harness = makeHabitMutationHarness(
            tasks: [
                makeTask(name: "Keep Me", project: inbox, dueDate: now, priority: .low)
            ]
        )
        waitForMainQueueFlush()

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        let initialAgendaTitles = harness.viewModel.dueTodayRows.map { $0.title }
        XCTAssertTrue(initialAgendaTitles.contains("Hydrate"))
        XCTAssertTrue(initialAgendaTitles.contains("Keep Me"))

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")

        let optimisticAgendaTitles = harness.viewModel.dueTodayRows.map { $0.title }
        XCTAssertFalse(optimisticAgendaTitles.contains("Hydrate"))
        XCTAssertTrue(optimisticAgendaTitles.contains("Keep Me"))
    }

    func testHabitMutationPreservesStableHomeOrdering() {
        let now = Date()
        let firstHabitID = UUID()
        let secondHabitID = UUID()
        let firstOccurrenceID = UUID()
        let secondOccurrenceID = UUID()
        let lifeAreaID = UUID()
        let marks = HabitRuntimeSupport.dayMarks(from: [], endingOn: now, dayCount: 30)
        let harness = makeHabitMutationHarness(
            agendaSummaries: [
                HabitOccurrenceSummary(
                    habitID: firstHabitID,
                    occurrenceID: firstOccurrenceID,
                    title: "Alpha",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: lifeAreaID,
                    lifeAreaName: "Health",
                    cadence: .daily(),
                    dueAt: now,
                    state: .pending,
                    currentStreak: 1,
                    bestStreak: 3,
                    riskState: .stable,
                    last14Days: marks
                ),
                HabitOccurrenceSummary(
                    habitID: secondHabitID,
                    occurrenceID: secondOccurrenceID,
                    title: "Bravo",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: lifeAreaID,
                    lifeAreaName: "Health",
                    cadence: .daily(),
                    dueAt: now,
                    state: .pending,
                    currentStreak: 20,
                    bestStreak: 20,
                    riskState: .stable,
                    last14Days: marks
                )
            ]
        )
        waitForMainQueueFlush()

        XCTAssertEqual(harness.viewModel.habitHomeSectionState.primaryRows.map(\.title), ["Alpha", "Bravo"])

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first(where: { $0.title == "Alpha" }) else {
            return XCTFail("Expected Alpha habit row")
        }

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")
        XCTAssertEqual(harness.viewModel.habitHomeSectionState.primaryRows.map(\.title), ["Alpha", "Bravo"])

        harness.schedulingEngine.completePendingResolve(with: .success(()))
        waitForMainQueueFlush(seconds: 0.45)
        XCTAssertEqual(harness.viewModel.habitHomeSectionState.primaryRows.map(\.title), ["Alpha", "Bravo"])
    }

    func testHabitMutationKeepsRecoveryRowInPlaceWhenStateBecomesStable() {
        let now = Date()
        let habitID = UUID()
        let occurrenceID = UUID()
        let lifeAreaID = UUID()
        let marks = HabitRuntimeSupport.dayMarks(from: [], endingOn: now, dayCount: 30)
        let harness = makeHabitMutationHarness(
            agendaSummaries: [
                HabitOccurrenceSummary(
                    habitID: habitID,
                    occurrenceID: occurrenceID,
                    title: "Recovery Habit",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: lifeAreaID,
                    lifeAreaName: "Health",
                    cadence: .daily(),
                    dueAt: now,
                    state: .pending,
                    currentStreak: 0,
                    bestStreak: 3,
                    riskState: .atRisk,
                    last14Days: marks
                ),
                HabitOccurrenceSummary(
                    habitID: UUID(),
                    occurrenceID: UUID(),
                    title: "Stable Habit",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: lifeAreaID,
                    lifeAreaName: "Health",
                    cadence: .daily(),
                    dueAt: now,
                    state: .pending,
                    currentStreak: 4,
                    bestStreak: 4,
                    riskState: .stable,
                    last14Days: marks
                )
            ]
        )
        waitForMainQueueFlush()

        XCTAssertEqual(harness.viewModel.habitHomeSectionState.recoveryRows.map(\.title), ["Recovery Habit"])
        XCTAssertEqual(harness.viewModel.habitHomeSectionState.primaryRows.map(\.title), ["Stable Habit"])

        guard let row = harness.viewModel.habitHomeSectionState.recoveryRows.first else {
            return XCTFail("Expected a visible recovery habit row")
        }

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")

        XCTAssertEqual(harness.viewModel.habitHomeSectionState.recoveryRows.map(\.title), ["Recovery Habit"])
        XCTAssertEqual(harness.viewModel.habitHomeSectionState.recoveryRows.first?.state, .completedToday)
        XCTAssertEqual(harness.viewModel.habitHomeSectionState.primaryRows.map(\.title), ["Stable Habit"])

        harness.schedulingEngine.completePendingResolve(with: .success(()))
        waitForMainQueueFlush(seconds: 0.45)

        XCTAssertEqual(harness.viewModel.habitHomeSectionState.recoveryRows.map(\.title), ["Recovery Habit"])
        XCTAssertEqual(harness.viewModel.habitHomeSectionState.recoveryRows.first?.state, .completedToday)
        XCTAssertEqual(harness.viewModel.habitHomeSectionState.primaryRows.map(\.title), ["Stable Habit"])
    }

    func testHabitMutationKeepsRescueTasksOutOfAgendaAndFocus() {
        let now = Date()
        let calendar = Calendar.current
        let inbox = Project.createInbox()
        let harness = makeHabitMutationHarness(
            tasks: [
                makeTask(
                    name: "Rescue Old",
                    project: inbox,
                    dueDate: calendar.date(byAdding: .day, value: -18, to: now),
                    priority: .high
                ),
                makeTask(
                    name: "Focus Candidate",
                    project: inbox,
                    dueDate: now,
                    priority: .high
                )
            ]
        )
        waitForMainQueueFlush()

        guard let row = harness.viewModel.habitHomeSectionState.primaryRows.first else {
            return XCTFail("Expected habit row after initial load")
        }

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")

        let agendaTitles = harness.viewModel.dueTodayRows.map(\.title)
        let focusTitles = harness.viewModel.focusNowSectionState.rows.map(\.title)
        let rescueTitles = rescueTailState(from: harness.viewModel)?.rows.map(\.title)

        XCTAssertFalse(agendaTitles.contains("Rescue Old"))
        XCTAssertFalse(focusTitles.contains("Rescue Old"))
        XCTAssertEqual(rescueTitles, ["Rescue Old"])
    }

    func testHabitMutationRecomputesHabitBackedFocusFallback() {
        let now = Date()
        let calendar = Calendar.current
        let firstHabitID = UUID()
        let secondHabitID = UUID()
        let firstOccurrenceID = UUID()
        let secondOccurrenceID = UUID()
        let lifeAreaID = UUID()
        let marks = HabitRuntimeSupport.dayMarks(from: [], endingOn: now, dayCount: 30)
        let harness = makeHabitMutationHarness(
            agendaSummaries: [
                HabitOccurrenceSummary(
                    habitID: firstHabitID,
                    occurrenceID: firstOccurrenceID,
                    title: "Overdue A",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: lifeAreaID,
                    lifeAreaName: "Health",
                    cadence: .daily(),
                    dueAt: calendar.date(byAdding: .day, value: -3, to: now),
                    state: .pending,
                    currentStreak: 2,
                    bestStreak: 4,
                    riskState: .stable,
                    last14Days: marks
                ),
                HabitOccurrenceSummary(
                    habitID: secondHabitID,
                    occurrenceID: secondOccurrenceID,
                    title: "Overdue B",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: lifeAreaID,
                    lifeAreaName: "Health",
                    cadence: .daily(),
                    dueAt: calendar.date(byAdding: .day, value: -2, to: now),
                    state: .pending,
                    currentStreak: 1,
                    bestStreak: 3,
                    riskState: .stable,
                    last14Days: marks
                )
            ]
        )
        waitForMainQueueFlush()

        XCTAssertEqual(harness.viewModel.focusNowSectionState.rows.map(\.title), ["Overdue A"])

        guard let row = harness.viewModel.habitHomeSectionState.recoveryRows.first(where: { $0.title == "Overdue A" }) else {
            return XCTFail("Expected Overdue A habit row")
        }

        harness.schedulingEngine.deferResolveCompletion = true
        harness.viewModel.performHabitLastCellAction(row, source: "test")
        XCTAssertEqual(harness.viewModel.focusNowSectionState.rows.map(\.title), ["Overdue B"])
    }

    func testRefreshCurrentScopeContentKeepsTodayScopeStable() {
        let suiteName = "HomeViewModelPersistenceTests.ScopeStableAfterHabitDetailMutation.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let inbox = Project.createInbox()
        let taskRepository = HomeViewModelMockTaskRepository(
            tasks: [makeTask(name: "Scope Stability Task", project: inbox, dueDate: Date())]
        )
        let projectRepository = HomeViewModelMockProjectRepository(projects: [inbox])
        let coordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)
        waitForMainQueueFlush()

        viewModel.setQuickView(.today)
        waitForMainQueueFlush()

        XCTAssertEqual(viewModel.activeScope, .today)
        let baselineSelectedDate = viewModel.selectedDate

        viewModel.refreshCurrentScopeContent(source: "test_habit_detail_mutation")
        waitForMainQueueFlush(seconds: 0.45)

        XCTAssertEqual(viewModel.activeScope, .today)
        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: baselineSelectedDate))

        defaults.removePersistentDomain(forName: suiteName)
    }

    private func rescueTailState(from viewModel: HomeViewModel) -> RescueTailState? {
        viewModel.agendaTailItems.compactMap { item in
            guard case .rescue(let state) = item else { return nil }
            return state
        }.first
    }

    private func makeHabitMutationHarness(
        tasks: [TaskDefinition] = [],
        habitID: UUID = UUID(),
        occurrenceID: UUID = UUID(),
        agendaSummaries: [HabitOccurrenceSummary]? = nil
    ) -> HomeHabitMutationHarness {
        let now = Date()
        let lifeAreaID = UUID()
        let last14Days = HabitRuntimeSupport.dayMarks(from: [], endingOn: now, dayCount: 30)
        let resolvedAgendaSummaries = agendaSummaries ?? [
            HabitOccurrenceSummary(
                habitID: habitID,
                occurrenceID: occurrenceID,
                title: "Hydrate",
                kind: .positive,
                trackingMode: .dailyCheckIn,
                lifeAreaID: lifeAreaID,
                lifeAreaName: "Health",
                icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "health"),
                cadence: .daily(),
                dueAt: now,
                state: .pending,
                currentStreak: 0,
                bestStreak: 3,
                riskState: .stable,
                last14Days: last14Days
            )
        ]

        let taskReadRepository = HomeHabitTaskReadRepositorySpy(tasks: tasks)
        let projectRepository = HomeViewModelMockProjectRepository(projects: [Project.createInbox()])
        let habitRepository = HomeHabitRepositoryStub(
            habits: resolvedAgendaSummaries.map { summary in
                HabitDefinitionRecord(
                    id: summary.habitID,
                    lifeAreaID: summary.lifeAreaID,
                    projectID: summary.projectID,
                    title: summary.title,
                    habitType: summary.kind == .positive ? "positive_daily" : "negative_daily",
                    kindRaw: summary.kind.rawValue,
                    trackingModeRaw: summary.trackingMode.rawValue,
                    iconSymbolName: summary.icon?.symbolName ?? "drop.fill",
                    iconCategoryKey: summary.icon?.categoryKey,
                    colorHex: summary.colorHex,
                    isPaused: false,
                    archivedAt: nil,
                    streakCurrent: summary.currentStreak,
                    streakBest: summary.bestStreak,
                    createdAt: now,
                    updatedAt: now
                )
            }
        )
        let occurrenceRepository = HomeHabitOccurrenceRepositoryStub(
            occurrences: resolvedAgendaSummaries.compactMap { summary in
                guard let resolvedOccurrenceID = summary.occurrenceID else { return nil }
                let dueAt = summary.dueAt ?? now
                return OccurrenceDefinition(
                    id: resolvedOccurrenceID,
                    occurrenceKey: "habit-\(summary.habitID.uuidString)",
                    scheduleTemplateID: UUID(),
                    sourceType: .habit,
                    sourceID: summary.habitID,
                    scheduledAt: dueAt,
                    dueAt: dueAt,
                    state: summary.state,
                    isGenerated: true,
                    generationWindow: "test",
                    createdAt: now,
                    updatedAt: now
                )
            }
        )
        let schedulingEngine = HomeHabitDeferredResolveSchedulingEngine()
        let libraryRows = resolvedAgendaSummaries.map { summary in
            HabitLibraryRow(
                habitID: summary.habitID,
                title: summary.title,
                kind: summary.kind,
                trackingMode: summary.trackingMode,
                cadence: summary.cadence,
                lifeAreaID: summary.lifeAreaID,
                lifeAreaName: summary.lifeAreaName,
                projectID: summary.projectID,
                projectName: summary.projectName,
                icon: summary.icon,
                colorHex: summary.colorHex,
                isPaused: false,
                isArchived: false,
                currentStreak: summary.currentStreak,
                bestStreak: summary.bestStreak,
                last14Days: summary.last14Days,
                nextDueAt: summary.dueAt,
                lastCompletedAt: nil
            )
        }
        let habitReadRepository = HomeHabitRuntimeReadRepositorySpy(
            agendaSummaries: resolvedAgendaSummaries,
            historyWindows: resolvedAgendaSummaries.map {
                HabitHistoryWindow(habitID: $0.habitID, marks: $0.last14Days)
            },
            libraryRows: libraryRows
        )
        schedulingEngine.onResolve = { occurrenceID, resolution in
            habitReadRepository.applyResolution(
                occurrenceID: occurrenceID,
                resolution: resolution
            )
        }
        occurrenceRepository.onSave = { occurrences in
            habitReadRepository.applySavedOccurrences(occurrences)
        }

        let coordinator = V3TestHarness.makeCoordinator(
            taskDefinitionRepository: InMemoryTaskDefinitionRepositoryStub(seed: []),
            taskReadModelRepository: taskReadRepository,
            projectRepository: projectRepository,
            habitRepository: habitRepository,
            habitRuntimeReadRepository: habitReadRepository,
            scheduleRepository: HomeHabitScheduleRepositoryStub(),
            scheduleEngine: schedulingEngine,
            occurrenceRepository: occurrenceRepository
        )

        let suiteName = "HomeViewModelPersistenceTests.HabitMutation.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create test UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = HomeViewModel(
            useCaseCoordinator: coordinator,
            userDefaults: defaults
        )

        return HomeHabitMutationHarness(
            viewModel: viewModel,
            taskReadRepository: taskReadRepository,
            habitReadRepository: habitReadRepository,
            schedulingEngine: schedulingEngine
        )
    }

    private func waitForMainQueueFlush() {
        let expectation = expectation(description: "MainQueueFlush")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func waitForMainQueueFlush(seconds: TimeInterval) {
        let expectation = expectation(description: "MainQueueFlushCustom")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: seconds + 1.0)
    }

    private func waitUntilProjectLoaded(_ projectID: UUID, in viewModel: HomeViewModel, timeout: TimeInterval = 1.0) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if viewModel.projects.contains(where: { $0.id == projectID }) {
                return
            }
            waitForMainQueueFlush(seconds: 0.05)
        }
        XCTFail("Expected project \(projectID) to be loaded in HomeViewModel.projects")
    }

    private func firstLoadedHabitRow(
        in viewModel: HomeViewModel,
        timeout: TimeInterval = 1.2
    ) -> HomeHabitRow? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let rows = viewModel.habitHomeSectionState.primaryRows
                + viewModel.habitHomeSectionState.recoveryRows
            if let row = rows.first {
                return row
            }
            waitForMainQueueFlush(seconds: 0.05)
        } while Date() < deadline
        return nil
    }

    private func visibleFocusTaskIDs(in rows: [HomeTodayRow]) -> Set<UUID> {
        Set(rows.compactMap { row in
            guard case .task(let task) = row else { return nil }
            return task.id
        })
    }

    private func taskIDs(in sections: [HomeListSection]) -> Set<UUID> {
        Set(sections.flatMap(\.rows).compactMap { row in
            guard case .task(let task) = row else { return nil }
            return task.id
        })
    }

    private func taskIDs(in rows: [HomeTodayRow]) -> Set<UUID> {
        Set(rows.compactMap { row in
            guard case .task(let task) = row else { return nil }
            return task.id
        })
    }

    private func taskTitles(in sections: [HomeListSection]) -> [String] {
        sections.flatMap(\.rows).compactMap { row in
            guard case .task(let task) = row else { return nil }
            return task.title
        }
    }

    private func makeTimelineTintCoordinator(
        projects: [Project],
        lifeAreas: [LifeArea]
    ) -> UseCaseCoordinator {
        V3TestHarness.makeCoordinator(
            taskDefinitionRepository: InMemoryTaskDefinitionRepositoryStub(seed: []),
            taskReadModelRepository: InMemoryTaskReadModelRepositoryStub(tasks: []),
            projectRepository: HomeViewModelMockProjectRepository(projects: projects),
            lifeAreaRepository: HomeViewModelMockLifeAreaRepository(areas: lifeAreas)
        )
    }

    private func makeTask(
        id: UUID = UUID(),
        name: String,
        project: Project,
        dueDate: Date? = Date(),
        priority: TaskPriority = .low,
        isComplete: Bool = false,
        dateCompleted: Date? = nil,
        updatedAt: Date = Date()
    ) -> Task {
        Task(
            id: id,
            projectID: project.id,
            name: name,
            priority: priority,
            dueDate: dueDate,
            project: project.name,
            isComplete: isComplete,
            dateCompleted: dateCompleted,
            updatedAt: updatedAt
        )
    }

    private func makeDefinition(
        title: String,
        start: Date,
        isAllDay: Bool = false,
        isComplete: Bool = false,
        repeatPattern: TaskRepeatPattern? = nil,
        habitDefinitionID: UUID? = nil
    ) -> TaskDefinition {
        TaskDefinition(
            habitDefinitionID: habitDefinitionID,
            title: title,
            dueDate: start,
            scheduledStartAt: isAllDay ? nil : start,
            scheduledEndAt: isAllDay ? nil : start.addingTimeInterval(30 * 60),
            isAllDay: isAllDay,
            isComplete: isComplete,
            repeatPattern: repeatPattern
        )
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
}

private final class HomeViewModelMockLifeAreaRepository: LifeAreaRepositoryProtocol {
    private var areas: [LifeArea]

    init(areas: [LifeArea]) {
        self.areas = areas
    }

    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        completion(.success(areas))
    }

    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        areas.append(area)
        completion(.success(area))
    }

    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        if let index = areas.firstIndex(where: { $0.id == area.id }) {
            areas[index] = area
        }
        completion(.success(area))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        areas.removeAll { $0.id == id }
        completion(.success(()))
    }
}

private final class HomeViewModelMockProjectRepository: ProjectRepositoryProtocol {
    private var projects: [Project]

    init(projects: [Project]) {
        self.projects = projects
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(projects))
    }

    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.id == id })))
    }

    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.name == name })))
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.isInbox }) ?? Project.createInbox()))
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(projects.filter { !$0.isInbox }))
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        projects.append(project)
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        if let inbox = projects.first(where: { $0.isInbox }) {
            completion(.success(inbox))
        } else {
            let inbox = Project.createInbox()
            projects.append(inbox)
            completion(.success(inbox))
        }
    }

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(
            scanned: projects.count,
            merged: 0,
            deleted: 0,
            inboxCandidates: projects.filter { $0.isInbox }.count,
            warnings: []
        )))
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        var updated = projects[index]
        updated.name = newName
        projects[index] = updated
        completion(.success(updated))
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        projects.removeAll { $0.id == id }
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.success(0))
    }

    func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        let exists = projects.contains { project in
            if let excludingId, project.id == excludingId {
                return false
            }
            return project.name.caseInsensitiveCompare(name) == .orderedSame
        }
        completion(.success(!exists))
    }
}

private final class HomeViewModelMockTaskRepository: LegacyTaskRepositoryShim {
    private let tasks: [Task]

    init(tasks: [Task]) {
        self.tasks = tasks
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.projectName == project })) }
    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.projectID == projectID })) }
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.isOverdue })) }
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.isComplete })) }
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.type == type })) }
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) { completion(.success(tasks.first { $0.id == id })) }
    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) { completion(.success(task)) }
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) { completion(.success(task)) }
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        guard var task = tasks.first(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        task.isComplete = true
        task.dateCompleted = Date()
        completion(.success(task))
    }
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        guard var task = tasks.first(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        task.isComplete = false
        task.dateCompleted = nil
        completion(.success(task))
    }
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        guard var task = tasks.first(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "mock", code: 404)))
            return
        }
        task.dueDate = date
        completion(.success(task))
    }
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks.filter { $0.projectID == ProjectConstants.inboxProjectID })) }
}

private struct HomeHabitMutationHarness {
    let viewModel: HomeViewModel
    let taskReadRepository: HomeHabitTaskReadRepositorySpy
    let habitReadRepository: HomeHabitRuntimeReadRepositorySpy
    let schedulingEngine: HomeHabitDeferredResolveSchedulingEngine
}

private final class HomeHabitDeferredResolveSchedulingEngine: SchedulingEngineProtocol {
    var deferResolveCompletion = false
    var onResolve: ((UUID, OccurrenceResolutionType) -> Void)?
    private var pendingResolveCompletions: [(id: UUID, resolution: OccurrenceResolutionType, completion: (Result<Void, Error>) -> Void)] = []

    func generateOccurrences(
        windowStart: Date,
        windowEnd: Date,
        sourceFilter: ScheduleSourceType?,
        completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func resolveOccurrence(
        id: UUID,
        resolution: OccurrenceResolutionType,
        actor: OccurrenceActor,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if deferResolveCompletion {
            pendingResolveCompletions.append((id: id, resolution: resolution, completion: completion))
            return
        }
        onResolve?(id, resolution)
        completion(.success(()))
    }

    func rebuildFutureOccurrences(
        templateID: UUID,
        effectiveFrom: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }

    func applyScheduleException(
        templateID: UUID,
        occurrenceKey: String,
        action: ScheduleExceptionAction,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }

    func completePendingResolve(with result: Result<Void, Error>) {
        let completions = pendingResolveCompletions
        pendingResolveCompletions.removeAll()
        completions.forEach { pending in
            if case .success = result {
                onResolve?(pending.id, pending.resolution)
            }
            pending.completion(result)
        }
    }
}

private final class HomeHabitRepositoryStub: HabitRepositoryProtocol {
    private let habits: [HabitDefinitionRecord]

    init(habits: [HabitDefinitionRecord]) {
        self.habits = habits
    }

    func fetchAll(completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void) {
        completion(.success(habits))
    }

    func create(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        completion(.success(habit))
    }

    func update(_ habit: HabitDefinitionRecord, completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        completion(.success(habit))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private final class HomeHabitScheduleRepositoryStub: ScheduleRepositoryProtocol {
    func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) { completion(.success([])) }
    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void) { completion(.success(template)) }
    func deleteTemplate(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func replaceRules(templateID: UUID, rules: [ScheduleRuleDefinition], completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) { completion(.success(rules)) }
    func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void) { completion(.success([])) }
    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void) { completion(.success(exception)) }
}

private final class HomeHabitOccurrenceRepositoryStub: OccurrenceRepositoryProtocol {
    var onSave: (([OccurrenceDefinition]) -> Void)?
    private(set) var occurrences: [OccurrenceDefinition]

    init(occurrences: [OccurrenceDefinition]) {
        self.occurrences = occurrences
    }

    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) {
        completion(.success(occurrences))
    }

    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void) {
        for occurrence in occurrences {
            if let index = self.occurrences.firstIndex(where: { $0.id == occurrence.id }) {
                self.occurrences[index] = occurrence
            } else {
                self.occurrences.append(occurrence)
            }
        }
        onSave?(occurrences)
        completion(.success(()))
    }

    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private final class HomeHabitTaskReadRepositorySpy: TaskReadModelRepositoryProtocol {
    let tasks: [TaskDefinition]
    private(set) var fetchHomeProjectionCallCount = 0

    init(tasks: [TaskDefinition]) {
        self.tasks = tasks
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: tasks, totalCount: tasks.count, limit: max(query.limit, 1), offset: query.offset)))
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: tasks, totalCount: tasks.count, limit: max(query.limit, 1), offset: query.offset)))
    }

    func searchTasks(query: TaskRepositorySearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: tasks, totalCount: tasks.count, limit: max(query.limit, 1), offset: query.offset)))
    }

    func fetchHomeProjection(query: HomeProjectionQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        fetchHomeProjectionCallCount += 1
        completion(.success(TaskDefinitionSliceResult(tasks: tasks, totalCount: tasks.count, limit: max(query.limit, 1), offset: query.offset)))
    }

    func fetchInsightsTodayProjection(referenceDate: Date, completion: @escaping (Result<InsightsTodayTaskProjection, Error>) -> Void) {
        completion(.success(InsightsTodayTaskProjection(dueWindowTasks: tasks, recentTasks: tasks)))
    }

    func fetchInsightsWeekProjection(referenceDate: Date, completion: @escaping (Result<InsightsWeekTaskProjection, Error>) -> Void) {
        completion(.success(InsightsWeekTaskProjection(recentTasks: tasks, dueWindowTasks: tasks, projectScores: [:])))
    }

    func fetchWeekChartProjection(referenceDate: Date, completion: @escaping (Result<WeekChartProjection, Error>) -> Void) {
        completion(.success(WeekChartProjection(weekStart: referenceDate, dayScores: [:], projectScores: [:])))
    }

    func fetchProjectTaskCounts(includeCompleted: Bool, completion: @escaping (Result<[UUID: Int], Error>) -> Void) {
        completion(.success([:]))
    }

    func fetchProjectCompletionScoreTotals(from startDate: Date, to endDate: Date, completion: @escaping (Result<[UUID: Int], Error>) -> Void) {
        completion(.success([:]))
    }
}

private final class HomeHabitRuntimeReadRepositorySpy: HabitRuntimeReadRepositoryProtocol {
    private var agendaSummaries: [HabitOccurrenceSummary]
    private let historyWindows: [HabitHistoryWindow]
    private let libraryRows: [HabitLibraryRow]
    private(set) var fetchAgendaCallCount = 0
    private(set) var fetchAgendaHabitCallCount = 0
    private(set) var fetchHistoryCallCount = 0
    private(set) var fetchHabitLibraryCallCount = 0
    private(set) var fetchFilteredHabitLibraryCallCount = 0

    init(
        agendaSummaries: [HabitOccurrenceSummary],
        historyWindows: [HabitHistoryWindow] = [],
        libraryRows: [HabitLibraryRow] = []
    ) {
        self.agendaSummaries = agendaSummaries
        self.historyWindows = historyWindows
        self.libraryRows = libraryRows
    }

    func fetchAgendaHabits(
        for date: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        fetchAgendaCallCount += 1
        completion(.success(agendaSummaries))
    }

    func fetchAgendaHabit(
        habitID: UUID,
        for date: Date,
        completion: @escaping (Result<HabitOccurrenceSummary?, Error>) -> Void
    ) {
        fetchAgendaHabitCallCount += 1
        completion(.success(agendaSummaries.first(where: { $0.habitID == habitID })))
    }

    func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        fetchHistoryCallCount += 1
        let requestedIDs = Set(habitIDs)
        completion(.success(historyWindows.filter { requestedIDs.contains($0.habitID) }))
    }

    func fetchSignals(
        start: Date,
        end: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func fetchHabitLibrary(
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        fetchHabitLibraryCallCount += 1
        completion(.success(libraryRows))
    }

    func fetchHabitLibrary(
        habitIDs: [UUID]?,
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        fetchFilteredHabitLibraryCallCount += 1
        let requestedIDs = habitIDs.map(Set.init)
        completion(.success(
            libraryRows.filter { row in
                guard let requestedIDs else { return true }
                return requestedIDs.contains(row.habitID)
            }
        ))
    }

    func applyResolution(
        occurrenceID: UUID,
        resolution: OccurrenceResolutionType
    ) {
        guard let index = agendaSummaries.firstIndex(where: { $0.occurrenceID == occurrenceID }) else {
            return
        }
        var summary = agendaSummaries[index]
        summary.state = mapOccurrenceState(from: resolution)
        summary.riskState = resolution == .lapsed ? .broken : .stable
        summary.last14Days = updatingMarks(summary.last14Days, for: summary.dueAt ?? Date(), state: mapDayState(from: resolution))
        agendaSummaries[index] = summary
    }

    func applySavedOccurrences(_ occurrences: [OccurrenceDefinition]) {
        for occurrence in occurrences {
            guard let index = agendaSummaries.firstIndex(where: { $0.occurrenceID == occurrence.id }) else {
                continue
            }
            var summary = agendaSummaries[index]
            summary.state = occurrence.state
            summary.riskState = occurrence.state == .failed ? .broken : .stable
            summary.last14Days = updatingMarks(
                summary.last14Days,
                for: occurrence.dueAt ?? occurrence.scheduledAt,
                state: mapDayState(from: occurrence.state)
            )
            agendaSummaries[index] = summary
        }
    }

    private func updatingMarks(
        _ marks: [HabitDayMark],
        for date: Date,
        state: HabitDayState
    ) -> [HabitDayMark] {
        var updatedMarks = marks
        let calendar = Calendar.current
        if let index = updatedMarks.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            updatedMarks[index] = HabitDayMark(date: updatedMarks[index].date, state: state)
        } else {
            updatedMarks.append(HabitDayMark(date: calendar.startOfDay(for: date), state: state))
            updatedMarks.sort { $0.date < $1.date }
        }
        return updatedMarks
    }

    private func mapOccurrenceState(from resolution: OccurrenceResolutionType) -> OccurrenceState {
        switch resolution {
        case .completed:
            return .completed
        case .skipped:
            return .skipped
        case .missed:
            return .missed
        case .deferred:
            return .pending
        case .lapsed:
            return .failed
        }
    }

    private func mapDayState(from resolution: OccurrenceResolutionType) -> HabitDayState {
        switch resolution {
        case .completed:
            return .success
        case .skipped:
            return .skipped
        case .missed:
            return .failure
        case .deferred:
            return .none
        case .lapsed:
            return .failure
        }
    }

    private func mapDayState(from occurrenceState: OccurrenceState) -> HabitDayState {
        switch occurrenceState {
        case .completed:
            return .success
        case .skipped:
            return .skipped
        case .missed:
            return .failure
        case .failed:
            return .failure
        case .pending:
            return .none
        }
    }
}
