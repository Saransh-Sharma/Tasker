import Foundation

@MainActor
public final class WeeklyReviewViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var snapshot: WeeklyPlanSnapshot?
    @Published public private(set) var reflectionNotes: [ReflectionNote] = []
    @Published public private(set) var selectedHabits: [HabitLibraryRow] = []
    @Published public private(set) var saveMessage: String?
    @Published public var outcomeStatusesByID: [UUID: WeeklyOutcomeStatus] = [:]
    @Published public var wins: String = ""
    @Published public var blockers: String = ""
    @Published public var lessons: String = ""
    @Published public var nextWeekPrepNotes: String = ""
    @Published public var perceivedWeekRating: Int = 3
    @Published public var taskDecisions: [UUID: WeeklyReviewTaskDisposition] = [:]

    public let weekStartDate: Date

    private let buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase
    private let getHabitLibraryUseCase: GetHabitLibraryUseCase
    private let completeWeeklyReviewUseCase: CompleteWeeklyReviewUseCase
    private let draftStore: WeeklyReviewDraftStoreProtocol
    private let reflectionNoteRepository: ReflectionNoteRepositoryProtocol
    private let gamificationEngine: GamificationEngine?
    private var autosaveWorkItem: DispatchWorkItem?

    public init(
        referenceDate: Date = Date(),
        buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase,
        getHabitLibraryUseCase: GetHabitLibraryUseCase,
        completeWeeklyReviewUseCase: CompleteWeeklyReviewUseCase,
        draftStore: WeeklyReviewDraftStoreProtocol,
        reflectionNoteRepository: ReflectionNoteRepositoryProtocol,
        gamificationEngine: GamificationEngine? = nil
    ) {
        let calendar = XPCalculationEngine.mondayCalendar()
        self.weekStartDate = XPCalculationEngine.mondayStartOfWeek(for: referenceDate, calendar: calendar)
        self.buildWeeklyPlanSnapshot = buildWeeklyPlanSnapshot
        self.getHabitLibraryUseCase = getHabitLibraryUseCase
        self.completeWeeklyReviewUseCase = completeWeeklyReviewUseCase
        self.draftStore = draftStore
        self.reflectionNoteRepository = reflectionNoteRepository
        self.gamificationEngine = gamificationEngine
    }

    public var unfinishedTasks: [TaskDefinition] {
        snapshot?.thisWeekTasks.filter { !$0.isComplete } ?? []
    }

    public var completedTasks: [TaskDefinition] {
        snapshot?.thisWeekTasks.filter(\.isComplete) ?? []
    }

    public var weekRangeText: String {
        WeeklyCopy.weekRangeText(for: weekStartDate)
    }

    var reviewSteps: [WeeklyRitualStep] {
        [
            WeeklyRitualStep(id: 0, title: WeeklyCopy.reviewSteps[0], isComplete: snapshot != nil),
            WeeklyRitualStep(id: 1, title: WeeklyCopy.reviewSteps[1], isComplete: outcomeStatusesByID.isEmpty == false || snapshot?.outcomes.isEmpty == true),
            WeeklyRitualStep(id: 2, title: WeeklyCopy.reviewSteps[2], isComplete: unfinishedTasks.allSatisfy { taskDecisions[$0.id] != nil }),
            WeeklyRitualStep(id: 3, title: WeeklyCopy.reviewSteps[3], isComplete: reviewReflectionIsFilled)
        ]
    }

    public var completionSummaryText: String {
        "\(completedTasks.count) done, \(unfinishedTasks.count) still needing a decision, \(reflectionNotes.count) reflections captured."
    }

    public var reviewReflectionIsFilled: Bool {
        [wins, blockers, lessons, nextWeekPrepNotes]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public func load() {
        isLoading = true
        errorMessage = nil
        let group = DispatchGroup()
        let lock = NSLock()
        var fetchedSnapshot: WeeklyPlanSnapshot?
        var habitRows: [HabitLibraryRow] = []
        var firstError: Error?

        func capture(_ error: Error) {
            lock.lock()
            if firstError == nil { firstError = error }
            lock.unlock()
        }

        group.enter()
        buildWeeklyPlanSnapshot.execute(referenceDate: weekStartDate) { result in
            if case .success(let snapshot) = result {
                fetchedSnapshot = snapshot
            } else if case .failure(let error) = result {
                capture(error)
            }
            group.leave()
        }

        group.enter()
        getHabitLibraryUseCase.execute(includeArchived: true) { result in
            if case .success(let habits) = result {
                habitRows = habits
            } else if case .failure(let error) = result {
                capture(error)
            }
            group.leave()
        }

        group.notify(queue: .main) {
            self.isLoading = false
            if let firstError {
                self.errorMessage = firstError.localizedDescription
                return
            }
            guard let snapshot = fetchedSnapshot else {
                self.snapshot = nil
                self.selectedHabits = []
                return
            }

            self.snapshot = snapshot
            self.reflectionNotes = snapshot.reflectionNotes
            let selectedHabitIDs = Set(snapshot.plan?.selectedHabitIDs ?? [])
            self.selectedHabits = habitRows.filter { selectedHabitIDs.contains($0.habitID) }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            self.loadLocalState(for: snapshot)
        }
    }

    public func setDecision(_ disposition: WeeklyReviewTaskDisposition, for taskID: UUID) {
        taskDecisions[taskID] = disposition
        scheduleDraftAutosave()
    }

    public func setOutcomeStatus(_ status: WeeklyOutcomeStatus, for outcomeID: UUID) {
        outcomeStatusesByID[outcomeID] = status
        scheduleDraftAutosave()
    }

    public func applyDecisionToAllUnfinished(_ disposition: WeeklyReviewTaskDisposition) {
        unfinishedTasks.forEach { task in
            taskDecisions[task.id] = disposition
        }
        scheduleDraftAutosave()
    }

    public func clearError() {
        errorMessage = nil
    }

    public func scheduleDraftAutosave() {
        autosaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistDraft()
        }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    public func saveReflectionNote(
        _ note: ReflectionNote,
        completion: ((Result<ReflectionNote, Error>) -> Void)? = nil
    ) {
        reflectionNoteRepository.saveNote(note) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success(let savedNote):
                    self.reflectionNotes.insert(savedNote, at: 0)
                    self.reflectionNotes = Array(self.reflectionNotes.prefix(12))
                    self.awardReflectionCaptureXP(linkedTaskID: savedNote.linkedTaskID, linkedHabitID: savedNote.linkedHabitID)
                }
                completion?(result)
            }
        }
    }

    public func completeReview(completion: (() -> Void)? = nil) {
        guard let plan = snapshot?.plan else {
            errorMessage = "Create the weekly plan before reviewing it."
            return
        }

        isSaving = true
        errorMessage = nil
        saveMessage = nil

        let decisions = taskDecisions.map { WeeklyReviewTaskDecision(taskID: $0.key, disposition: $0.value) }
            .sorted { $0.taskID.uuidString < $1.taskID.uuidString }

        completeWeeklyReviewUseCase.execute(
            request: CompleteWeeklyReviewRequest(
                weeklyPlanID: plan.id,
                wins: wins.nilIfBlank,
                blockers: blockers.nilIfBlank,
                lessons: lessons.nilIfBlank,
                nextWeekPrepNotes: nextWeekPrepNotes.nilIfBlank,
                perceivedWeekRating: perceivedWeekRating,
                taskDecisions: decisions,
                outcomeStatusesByOutcomeID: outcomeStatusesByID
            )
        ) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success:
                    self.persistCompletionLocalState(decisions: decisions) {
                        self.saveMessage = WeeklyCopy.reviewSaveSuccess
                        self.awardWeeklyReviewXP(using: decisions)
                        self.load()
                        completion?()
                    }
                }
            }
        }
    }

    private func loadLocalState(for snapshot: WeeklyPlanSnapshot) {
        let fallbackTaskDecisions = Dictionary(
            uniqueKeysWithValues: snapshot.thisWeekTasks
                .filter { !$0.isComplete }
                .map { ($0.id, WeeklyReviewTaskDisposition.carry) }
        )
        let persistedOutcomeStatuses = Dictionary(uniqueKeysWithValues: snapshot.outcomes.map { ($0.id, $0.status) })

        draftStore.fetchDraft(weekStartDate: weekStartDate) { result in
            DispatchQueue.main.async {
                let draft = (try? result.get()) ?? nil
                self.wins = draft?.wins ?? snapshot.review?.wins ?? ""
                self.blockers = draft?.blockers ?? snapshot.review?.blockers ?? ""
                self.lessons = draft?.lessons ?? snapshot.review?.lessons ?? ""
                self.nextWeekPrepNotes = draft?.nextWeekPrepNotes ?? snapshot.review?.nextWeekPrepNotes ?? ""
                self.perceivedWeekRating = max(draft?.perceivedWeekRating ?? snapshot.review?.perceivedWeekRating ?? 3, 1)

                self.taskDecisions = fallbackTaskDecisions.merging(draft?.taskDecisions ?? [:]) { _, newValue in newValue }
                self.outcomeStatusesByID = Dictionary(uniqueKeysWithValues: snapshot.outcomes.map { outcome in
                    let derivedStatus = draft?.outcomeStatuses[outcome.id]
                        ?? persistedOutcomeStatuses[outcome.id]
                        ?? self.derivedOutcomeStatus(for: outcome, in: snapshot)
                    return (outcome.id, derivedStatus)
                })
            }
        }
    }

    private func derivedOutcomeStatus(
        for outcome: WeeklyOutcome,
        in snapshot: WeeklyPlanSnapshot
    ) -> WeeklyOutcomeStatus {
        let linkedTasks = snapshot.thisWeekTasks.filter { $0.weeklyOutcomeID == outcome.id }
        guard linkedTasks.isEmpty == false else { return .planned }
        return linkedTasks.allSatisfy(\.isComplete) ? .completed : .inProgress
    }

    private func persistDraft() {
        guard let snapshot else { return }
        let unfinishedTaskIDs = Set(snapshot.thisWeekTasks.filter { !$0.isComplete }.map(\.id))
        let outcomeIDs = Set(snapshot.outcomes.map(\.id))
        let draft = WeeklyReviewDraft(
            weekStartDate: weekStartDate,
            wins: wins.nilIfBlank,
            blockers: blockers.nilIfBlank,
            lessons: lessons.nilIfBlank,
            nextWeekPrepNotes: nextWeekPrepNotes.nilIfBlank,
            perceivedWeekRating: perceivedWeekRating,
            taskDecisions: taskDecisions.filter { unfinishedTaskIDs.contains($0.key) },
            outcomeStatuses: outcomeStatusesByID.filter { outcomeIDs.contains($0.key) },
            updatedAt: Date()
        )
        draftStore.saveDraft(draft) { _ in }
    }

    private func persistCompletionLocalState(
        decisions: [WeeklyReviewTaskDecision],
        completion: @escaping () -> Void
    ) {
        autosaveWorkItem?.cancel()
        draftStore.saveCompletedTaskDecisions(decisions, weekStartDate: weekStartDate) { _ in
            self.draftStore.clearDraft(weekStartDate: self.weekStartDate) { _ in
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    private func awardWeeklyReviewXP(using decisions: [WeeklyReviewTaskDecision]) {
        guard let gamificationEngine else { return }

        let weekKey = XPCalculationEngine.periodKey(for: weekStartDate)
        gamificationEngine.recordEvent(
            context: XPEventContext(
                category: .weeklyReview,
                source: .manual,
                completedAt: Date(),
                fromDay: weekKey
            )
        ) { _ in }

        let cleanupCount = decisions.filter { $0.disposition == .later || $0.disposition == .drop }.count
        guard cleanupCount > 0 else { return }

        gamificationEngine.recordEvent(
            context: XPEventContext(
                category: .weeklyCarryCleanup,
                source: .manual,
                completedAt: Date(),
                fromDay: weekKey
            )
        ) { _ in }
    }

    private func awardReflectionCaptureXP(linkedTaskID: UUID?, linkedHabitID: UUID?) {
        guard let gamificationEngine else { return }
        gamificationEngine.recordEvent(
            context: XPEventContext(
                category: .reflectionCapture,
                source: .manual,
                taskID: linkedTaskID,
                habitID: linkedHabitID,
                completedAt: Date()
            )
        ) { _ in }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
