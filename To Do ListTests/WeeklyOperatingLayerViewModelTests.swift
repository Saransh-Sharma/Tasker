import XCTest
@testable import To_Do_List

final class WeeklyOperatingLayerViewModelTests: XCTestCase {
    @MainActor
    func testPlannerDerivedProgressAndSummaryReflectCurrentInputs() {
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
        XCTAssertEqual(
            viewModel.reviewSummaryText,
            "1 outcomes, 1 tasks in This Week, 1 habits supporting the week."
        )
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
    private func makePlannerViewModel() -> WeeklyPlannerViewModel {
        let taskRepository = InMemoryTaskDefinitionRepositoryStub()
        let buildSnapshot = BuildWeeklyPlanSnapshotUseCase(
            weeklyPlanRepository: StubWeeklyPlanRepository(),
            weeklyOutcomeRepository: StubWeeklyOutcomeRepository(),
            weeklyReviewRepository: StubWeeklyReviewRepository(),
            reflectionNoteRepository: StubReflectionNoteRepository(),
            taskDefinitionRepository: taskRepository
        )
        let estimateCapacity = EstimateWeeklyCapacityUseCase(taskDefinitionRepository: taskRepository)
        let getHabitLibrary = GetHabitLibraryUseCase(readRepository: StubHabitRuntimeReadRepository())
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
            projectRepository: StubProjectRepository(),
            saveWeeklyPlanUseCase: savePlan
        )
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
        completion(.success([]))
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
