import XCTest
@testable import To_Do_List

final class WeeklyOperatingLayerViewModelTests: XCTestCase {
    @MainActor
    func testPlannerCompactSummaryReflectsWizardInputs() {
        let viewModel = makePlannerViewModel()
        let habitID = UUID()
        let outcomeID = UUID()

        viewModel.focusStatement = "Protect launch week"
        viewModel.selectedHabitIDs = [habitID]
        viewModel.outcomeDrafts = [
            WeeklyOutcomeDraft(
                id: outcomeID,
                title: "Ship launch prep",
                whyItMatters: "It removes last-minute scramble.",
                successDefinition: "Draft and review the launch note."
            ),
            WeeklyOutcomeDraft()
        ]
        viewModel.thisWeekTasks = [
            TaskDefinition(
                title: "Draft launch note",
                planningBucket: .thisWeek,
                weeklyOutcomeID: outcomeID
            )
        ]
        viewModel.nextWeekTasks = [
            TaskDefinition(title: "Archive test builds", planningBucket: .nextWeek)
        ]

        XCTAssertEqual(viewModel.plannerSteps.map(\.isComplete), [true, true, true, true])
        XCTAssertEqual(viewModel.reviewSummary.compactSummary, "1 outcomes · 1 this week · 1 habits")
    }

    @MainActor
    func testPlannerLoadPreselectsHabitsAndSeedsTriageQueue() {
        let habitOne = HabitLibraryRow(
            habitID: UUID(),
            title: "Morning reset",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            icon: HabitIconMetadata(symbolName: "sun.max", categoryKey: "health"),
            colorHex: "#FFAA00",
            isPaused: false,
            isArchived: false,
            currentStreak: 5,
            bestStreak: 8,
            lastCompletedAt: fixedWeekStart
        )
        let habitTwo = HabitLibraryRow(
            habitID: UUID(),
            title: "Inbox sweep",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Work",
            icon: HabitIconMetadata(symbolName: "tray.full", categoryKey: "work"),
            colorHex: "#3366FF",
            isPaused: false,
            isArchived: false,
            currentStreak: 2,
            bestStreak: 4,
            lastCompletedAt: fixedWeekStart
        )
        let openTask = TaskDefinition(
            id: UUID(),
            title: "Finalize roadmap notes",
            priority: .high,
            dueDate: fixedWeekStart,
            planningBucket: .later
        )

        let viewModel = makePlannerViewModel(
            seedTasks: [openTask],
            habitRows: [habitOne, habitTwo]
        )

        loadPlanner(viewModel)

        XCTAssertEqual(viewModel.currentStep, .direction)
        XCTAssertEqual(viewModel.selectedHabitIDs, Set([habitOne.habitID, habitTwo.habitID]))
        XCTAssertEqual(viewModel.currentTriageTask?.id, openTask.id)
        XCTAssertEqual(viewModel.triageSnapshot.cardModel?.task.id, openTask.id)
        XCTAssertEqual(viewModel.taskSourceSnapshot(for: .weeklyCandidates).tasks.first?.id, openTask.id)
    }

    @MainActor
    func testPlannerStepGatingAndNavigationFollowWizardFlow() {
        let openTask = TaskDefinition(
            id: UUID(),
            title: "Ship weekly launch draft",
            priority: .high,
            dueDate: fixedWeekStart,
            planningBucket: .later
        )
        let viewModel = makePlannerViewModel(seedTasks: [openTask])

        loadPlanner(viewModel)

        XCTAssertFalse(viewModel.canMoveForward)

        viewModel.minimumViableWeekEnabled = true
        XCTAssertTrue(viewModel.canMoveForward)

        viewModel.moveForward()
        XCTAssertEqual(viewModel.currentStep, .outcomes)
        XCTAssertFalse(viewModel.canMoveForward)

        viewModel.outcomeDrafts[0].title = "Ship the weekly launch draft"
        XCTAssertTrue(viewModel.canMoveForward)

        viewModel.moveForward()
        XCTAssertEqual(viewModel.currentStep, .tasks)
        XCTAssertFalse(viewModel.canMoveForward)

        _ = viewModel.assignCurrentTriageTask(to: .thisWeek)
        XCTAssertTrue(viewModel.canMoveForward)

        viewModel.moveForward()
        XCTAssertEqual(viewModel.currentStep, .review)
    }

    @MainActor
    func testPlannerTriageUndoRestoresQueueAndBucketState() {
        let task = TaskDefinition(
            id: UUID(),
            title: "Follow up on design review",
            priority: .high,
            dueDate: fixedWeekStart,
            planningBucket: .later
        )
        let viewModel = makePlannerViewModel(seedTasks: [task])

        loadPlanner(viewModel)

        let decision = viewModel.assignCurrentTriageTask(to: .nextWeek)

        XCTAssertEqual(decision?.task.id, task.id)
        XCTAssertNil(viewModel.currentTriageTask)
        XCTAssertEqual(viewModel.triageReviewedCount, 1)
        XCTAssertEqual(viewModel.nextWeekTasks.map(\.id), [task.id])

        let undone = viewModel.undoLastTriageDecision()

        XCTAssertEqual(undone?.task.id, task.id)
        XCTAssertEqual(viewModel.currentTriageTask?.id, task.id)
        XCTAssertEqual(viewModel.triageReviewedCount, 0)
        XCTAssertTrue(viewModel.nextWeekTasks.isEmpty)
        XCTAssertEqual(viewModel.triageSnapshot.cardModel?.task.id, task.id)
    }

    @MainActor
    func testPlannerOverloadCountOnlyTracksOpenThisWeekTasks() {
        let viewModel = makePlannerViewModel()
        viewModel.targetCapacity = 1
        viewModel.thisWeekTasks = [
            TaskDefinition(title: "Finish launch note", isComplete: false, planningBucket: .thisWeek),
            TaskDefinition(title: "Send launch note", isComplete: false, planningBucket: .thisWeek),
            TaskDefinition(title: "Already done", isComplete: true, planningBucket: .thisWeek)
        ]
        viewModel.nextWeekTasks = [
            TaskDefinition(title: "Plan retro", isComplete: false, planningBucket: .nextWeek)
        ]

        XCTAssertEqual(viewModel.overloadCount, 1)
    }

    @MainActor
    func testPlannerOutcomeAndTaskSourceSnapshotsRefreshWhenPlanChanges() {
        let task = TaskDefinition(
            id: UUID(),
            title: "Finalize roadmap notes",
            priority: .high,
            dueDate: fixedWeekStart,
            planningBucket: .later
        )
        let projectID = UUID()
        let viewModel = makePlannerViewModel(
            seedTasks: [task],
            projects: [Project(id: projectID, name: "Roadmap", color: .blue)]
        )

        loadPlanner(viewModel)

        viewModel.outcomeDrafts[0].title = "Protect roadmap clarity"
        viewModel.outcomeDrafts[0].sourceProjectID = projectID
        _ = viewModel.assignCurrentTriageTask(to: TaskPlanningBucket.thisWeek)
        viewModel.assignWeeklyOutcome(viewModel.outcomeDrafts[0].id, to: task.id)

        XCTAssertEqual(viewModel.reviewSummary.outcomes.first?.projectName, "Roadmap")
        XCTAssertEqual(viewModel.reviewSummary.outcomes.first?.linkedTaskCount, 1)
        XCTAssertTrue(viewModel.taskSourceSnapshot(for: WeeklyTaskSourceMode.suggested).tasks.isEmpty)
    }

    @MainActor
    func testPlannerHabitSnapshotAndFooterRefreshWhenHabitSelectionChanges() {
        let habitOne = HabitLibraryRow(
            habitID: UUID(),
            title: "Morning reset",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            icon: HabitIconMetadata(symbolName: "sun.max", categoryKey: "health"),
            colorHex: "#FFAA00",
            isPaused: false,
            isArchived: false,
            currentStreak: 5,
            bestStreak: 8,
            lastCompletedAt: fixedWeekStart
        )
        let viewModel = makePlannerViewModel(habitRows: [habitOne])

        loadPlanner(viewModel)

        XCTAssertEqual(viewModel.selectedHabits.count, 1)

        viewModel.toggleHabit(habitOne.habitID)

        XCTAssertTrue(viewModel.selectedHabits.isEmpty)
        XCTAssertEqual(viewModel.footerSnapshot.title, WeeklyPlannerStep.direction.stepLabel)
    }

    @MainActor
    func testPlannerWarmCacheReadsStayStable() {
        let task = TaskDefinition(
            id: UUID(),
            title: "Draft launch note",
            priority: .high,
            dueDate: fixedWeekStart,
            planningBucket: .later
        )
        let viewModel = makePlannerViewModel(seedTasks: [task])

        loadPlanner(viewModel)
        viewModel.focusStatement = "Protect launch week"
        viewModel.outcomeDrafts[0].title = "Ship launch prep"

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = viewModel.reviewSummary
            _ = viewModel.taskSourceSnapshot(for: .weeklyCandidates)
            _ = viewModel.currentTriageTask
            _ = viewModel.currentTriagePlacementText
        }
    }

    @MainActor
    func testReviewDerivedSummaryAndBulkDecisionReflectLoadedSnapshot() {
        let weekStart = fixedWeekStart
        let planID = UUID()
        let outcomeID = UUID()
        let unfinishedOne = TaskDefinition(
            id: UUID(),
            title: "Draft launch note",
            isComplete: false,
            planningBucket: .thisWeek,
            weeklyOutcomeID: outcomeID
        )
        let unfinishedTwo = TaskDefinition(
            id: UUID(),
            title: "Share draft for review",
            isComplete: false,
            planningBucket: .thisWeek,
            weeklyOutcomeID: outcomeID
        )
        let completed = TaskDefinition(
            id: UUID(),
            title: "Outline launch note",
            isComplete: true,
            dateCompleted: weekStart,
            planningBucket: .thisWeek,
            weeklyOutcomeID: outcomeID
        )
        let plan = WeeklyPlan(
            id: planID,
            weekStartDate: weekStart,
            weekEndDate: Calendar(identifier: .gregorian).date(byAdding: .day, value: 6, to: weekStart) ?? weekStart,
            selectedHabitIDs: [UUID()],
            targetCapacity: 3,
            reviewStatus: .ready
        )
        let outcome = WeeklyOutcome(
            id: outcomeID,
            weeklyPlanID: planID,
            title: "Ship launch prep",
            successDefinition: "Draft, review, and queue the note."
        )
        let reflection = ReflectionNote(
            kind: .weeklyReview,
            linkedWeeklyPlanID: planID,
            prompt: "What should next week remember?",
            noteText: "Start with stakeholder feedback first."
        )
        let snapshot = WeeklyPlanSnapshot(
            weekStartDate: weekStart,
            plan: plan,
            outcomes: [outcome],
            review: nil,
            thisWeekTasks: [unfinishedOne, unfinishedTwo, completed],
            nextWeekTasks: [],
            laterTasks: [],
            reflectionNotes: [reflection]
        )

        let viewModel = makeReviewViewModel(snapshot: snapshot)
        let loaded = expectation(description: "weekly review loaded")

        viewModel.load()
        func waitForSnapshot() {
            if viewModel.snapshot != nil {
                loaded.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    waitForSnapshot()
                }
            }
        }
        DispatchQueue.main.async(execute: waitForSnapshot)
        wait(for: [loaded], timeout: 1.0)

        XCTAssertEqual(
            viewModel.completionSummaryText,
            "1 done, 2 still needing a decision, 1 reflections captured."
        )
        XCTAssertEqual(viewModel.reviewSteps.map(\.isComplete), [true, true, true, false])

        viewModel.applyDecisionToAllUnfinished(.later)
        XCTAssertTrue(viewModel.unfinishedTasks.allSatisfy { viewModel.taskDecisions[$0.id] == .later })

        viewModel.wins = "Kept the scope believable."
        XCTAssertTrue(viewModel.reviewSteps[3].isComplete)
    }

    @MainActor
    private func makePlannerViewModel(
        seedTasks: [TaskDefinition] = [],
        habitRows: [HabitLibraryRow] = [],
        projects: [Project] = []
    ) -> WeeklyPlannerViewModel {
        let taskRepository = InMemoryTaskDefinitionRepositoryStub(seed: seedTasks)
        let buildSnapshot = BuildWeeklyPlanSnapshotUseCase(
            weeklyPlanRepository: StubWeeklyPlanRepository(),
            weeklyOutcomeRepository: StubWeeklyOutcomeRepository(),
            weeklyReviewRepository: StubWeeklyReviewRepository(),
            reflectionNoteRepository: StubReflectionNoteRepository(),
            taskDefinitionRepository: taskRepository
        )
        let estimateCapacity = EstimateWeeklyCapacityUseCase(taskDefinitionRepository: taskRepository)
        let getHabitLibrary = GetHabitLibraryUseCase(
            readRepository: StubHabitRuntimeReadRepository(libraryRows: habitRows)
        )
        let updateTask = UpdateTaskDefinitionUseCase(repository: taskRepository)
        let savePlan = SaveWeeklyPlanUseCase(
            weeklyPlanRepository: StubWeeklyPlanRepository(),
            weeklyOutcomeRepository: StubWeeklyOutcomeRepository(),
            updateTaskDefinitionUseCase: updateTask,
            taskDefinitionRepository: taskRepository
        )

        return WeeklyPlannerViewModel(
            referenceDate: fixedWeekStart,
            buildWeeklyPlanSnapshot: buildSnapshot,
            estimateWeeklyCapacity: estimateCapacity,
            getHabitLibraryUseCase: getHabitLibrary,
            projectRepository: StubProjectRepository(customProjects: projects),
            taskDefinitionRepository: taskRepository,
            saveWeeklyPlanUseCase: savePlan
        )
    }

    @MainActor
    private func loadPlanner(_ viewModel: WeeklyPlannerViewModel) {
        let loaded = expectation(description: "weekly planner loaded")

        viewModel.load()

        func waitForLoad() {
            if viewModel.isLoading == false {
                loaded.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    waitForLoad()
                }
            }
        }

        DispatchQueue.main.async(execute: waitForLoad)
        wait(for: [loaded], timeout: 1.0)
    }

    @MainActor
    private func makeReviewViewModel(snapshot: WeeklyPlanSnapshot) -> WeeklyReviewViewModel {
        let buildSnapshot = BuildWeeklyPlanSnapshotUseCase(
            weeklyPlanRepository: StubWeeklyPlanRepository(plan: snapshot.plan),
            weeklyOutcomeRepository: StubWeeklyOutcomeRepository(outcomesByPlanID: snapshot.plan.map { [$0.id: snapshot.outcomes] } ?? [:]),
            weeklyReviewRepository: StubWeeklyReviewRepository(review: snapshot.review),
            reflectionNoteRepository: StubReflectionNoteRepository(notes: snapshot.reflectionNotes),
            taskDefinitionRepository: InMemoryTaskDefinitionRepositoryStub(seed: snapshot.thisWeekTasks + snapshot.nextWeekTasks + snapshot.laterTasks)
        )
        let getHabitLibrary = GetHabitLibraryUseCase(
            readRepository: StubHabitRuntimeReadRepository(
                libraryRows: snapshot.plan?.selectedHabitIDs.map {
                    HabitLibraryRow(
                        habitID: $0,
                        title: "Morning reset",
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        lifeAreaID: UUID(),
                        lifeAreaName: "Health",
                        icon: HabitIconMetadata(symbolName: "sun.max", categoryKey: "health"),
                        colorHex: "#FFAA00",
                        isPaused: false,
                        isArchived: false,
                        currentStreak: 4,
                        bestStreak: 7,
                        lastCompletedAt: fixedWeekStart,
                    )
                } ?? []
            )
        )

        return WeeklyReviewViewModel(
            referenceDate: fixedWeekStart,
            buildWeeklyPlanSnapshot: buildSnapshot,
            getHabitLibraryUseCase: getHabitLibrary,
            completeWeeklyReviewUseCase: CompleteWeeklyReviewUseCase(
                reviewMutationRepository: StubWeeklyReviewMutationRepository()
            ),
            draftStore: StubWeeklyReviewDraftStore(),
            reflectionNoteRepository: StubReflectionNoteRepository(notes: snapshot.reflectionNotes)
        )
    }

    private var fixedWeekStart: Date {
        Date(timeIntervalSince1970: 1_712_592_000) // 2024-04-01 Monday UTC
    }
}

private final class StubWeeklyPlanRepository: WeeklyPlanRepositoryProtocol {
    var plan: WeeklyPlan?

    init(plan: WeeklyPlan? = nil) {
        self.plan = plan
    }

    func fetchPlan(id: UUID, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) {
        completion(.success(plan?.id == id ? plan : nil))
    }

    func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) {
        guard let plan else { return completion(.success(nil)) }
        let calendar = Calendar(identifier: .gregorian)
        completion(.success(calendar.isDate(plan.weekStartDate, inSameDayAs: weekStartDate) ? plan : nil))
    }

    func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping (Result<[WeeklyPlan], Error>) -> Void) {
        guard let plan, plan.weekStartDate >= startDate, plan.weekStartDate <= endDate else {
            return completion(.success([]))
        }
        completion(.success([plan]))
    }

    func savePlan(_ plan: WeeklyPlan, completion: @escaping (Result<WeeklyPlan, Error>) -> Void) {
        self.plan = plan
        completion(.success(plan))
    }
}

private final class StubWeeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol {
    var outcomesByPlanID: [UUID: [WeeklyOutcome]]

    init(outcomesByPlanID: [UUID: [WeeklyOutcome]] = [:]) {
        self.outcomesByPlanID = outcomesByPlanID
    }

    func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void) {
        completion(.success(outcomesByPlanID[weeklyPlanID] ?? []))
    }

    func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping (Result<WeeklyOutcome, Error>) -> Void) {
        var outcomes = outcomesByPlanID[outcome.weeklyPlanID] ?? []
        outcomes.removeAll { $0.id == outcome.id }
        outcomes.append(outcome)
        outcomesByPlanID[outcome.weeklyPlanID] = outcomes
        completion(.success(outcome))
    }

    func replaceOutcomes(
        weeklyPlanID: UUID,
        outcomes: [WeeklyOutcome],
        completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void
    ) {
        outcomesByPlanID[weeklyPlanID] = outcomes
        completion(.success(outcomes))
    }

    func deleteOutcome(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        for key in outcomesByPlanID.keys {
            outcomesByPlanID[key]?.removeAll { $0.id == id }
        }
        completion(.success(()))
    }
}

private final class StubWeeklyReviewRepository: WeeklyReviewRepositoryProtocol {
    var review: WeeklyReview?

    init(review: WeeklyReview? = nil) {
        self.review = review
    }

    func fetchReview(weeklyPlanID: UUID, completion: @escaping (Result<WeeklyReview?, Error>) -> Void) {
        completion(.success(review?.weeklyPlanID == weeklyPlanID ? review : nil))
    }

    func saveReview(_ review: WeeklyReview, completion: @escaping (Result<WeeklyReview, Error>) -> Void) {
        self.review = review
        completion(.success(review))
    }
}

private final class StubWeeklyReviewMutationRepository: WeeklyReviewMutationRepositoryProtocol {
    func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping (Result<WeeklyReview, Error>) -> Void
    ) {
        completion(.success(WeeklyReview(weeklyPlanID: request.weeklyPlanID, completedAt: request.completedAt)))
    }
}

private final class StubWeeklyReviewDraftStore: WeeklyReviewDraftStoreProtocol {
    func fetchDraft(
        weekStartDate: Date,
        completion: @escaping (Result<WeeklyReviewDraft?, Error>) -> Void
    ) {
        completion(.success(nil))
    }

    func saveDraft(
        _ draft: WeeklyReviewDraft,
        completion: @escaping (Result<WeeklyReviewDraft, Error>) -> Void
    ) {
        completion(.success(draft))
    }

    func clearDraft(
        weekStartDate: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }

    func fetchCompletedTaskDecisions(
        weekStartDate: Date,
        completion: @escaping (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func saveCompletedTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
        weekStartDate: Date,
        completion: @escaping (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        completion(.success(decisions))
    }
}

private final class StubReflectionNoteRepository: ReflectionNoteRepositoryProtocol {
    var notes: [ReflectionNote]

    init(notes: [ReflectionNote] = []) {
        self.notes = notes
    }

    func fetchNotes(query: ReflectionNoteQuery, completion: @escaping (Result<[ReflectionNote], Error>) -> Void) {
        completion(.success(notes))
    }

    func saveNote(_ note: ReflectionNote, completion: @escaping (Result<ReflectionNote, Error>) -> Void) {
        notes.append(note)
        completion(.success(note))
    }

    func deleteNote(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        notes.removeAll { $0.id == id }
        completion(.success(()))
    }
}

private final class StubHabitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol {
    let libraryRows: [HabitLibraryRow]

    init(libraryRows: [HabitLibraryRow] = []) {
        self.libraryRows = libraryRows
    }

    func fetchAgendaHabits(
        for date: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func fetchAgendaHabit(
        habitID: UUID,
        for date: Date,
        completion: @escaping (Result<HabitOccurrenceSummary?, Error>) -> Void
    ) {
        completion(.success(nil))
    }

    func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        completion(.success([]))
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
        completion(.success(libraryRows))
    }

    func fetchHabitLibrary(
        habitIDs: [UUID]?,
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        guard let habitIDs else {
            return completion(.success(libraryRows))
        }
        let requested = Set(habitIDs)
        completion(.success(libraryRows.filter { requested.contains($0.habitID) }))
    }
}

private final class StubProjectRepository: ProjectRepositoryProtocol {
    private let inbox = Project.createInbox()
    private let customProjects: [Project]

    init(customProjects: [Project] = []) {
        self.customProjects = customProjects
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success([inbox]))
    }

    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(id == inbox.id ? inbox : nil))
    }

    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(name == inbox.name ? inbox : nil))
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(inbox))
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(customProjects))
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(inbox))
    }

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(Project(id: id, name: newName)))
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.success(0))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }
}
