import Foundation

struct WeeklyReviewOutcomeSnapshot: Equatable, Identifiable {
    let outcome: WeeklyOutcome
    let selectedStatus: WeeklyOutcomeStatus
    let linkedTaskCount: Int

    var id: UUID { outcome.id }
}

struct WeeklyReviewSnapshot: Equatable {
    let completedTasks: [TaskDefinition]
    let unfinishedTasks: [TaskDefinition]
    let selectedHabits: [HabitLibraryRow]
    let outcomeSnapshots: [WeeklyReviewOutcomeSnapshot]
    let reflectionNotes: [ReflectionNote]
    let reviewSteps: [WeeklyRitualStep]
    let completionSummaryText: String

    static func == (lhs: WeeklyReviewSnapshot, rhs: WeeklyReviewSnapshot) -> Bool {
        lhs.completedTasks == rhs.completedTasks
            && lhs.unfinishedTasks == rhs.unfinishedTasks
            && lhs.selectedHabits == rhs.selectedHabits
            && lhs.outcomeSnapshots == rhs.outcomeSnapshots
            && lhs.reflectionNotes == rhs.reflectionNotes
            && lhs.completionSummaryText == rhs.completionSummaryText
            && lhs.reviewSteps.map(\.id) == rhs.reviewSteps.map(\.id)
            && lhs.reviewSteps.map(\.title) == rhs.reviewSteps.map(\.title)
            && lhs.reviewSteps.map(\.isComplete) == rhs.reviewSteps.map(\.isComplete)
    }
}

struct WeeklyReviewFooterSnapshot: Equatable {
    let completionSummaryText: String
    let canFinishReview: Bool
}

private struct WeeklyReviewRenderCache {
    var unfinishedTasks: [TaskDefinition] = []
    var completedTasks: [TaskDefinition] = []
    var selectedHabits: [HabitLibraryRow] = []
    var outcomeStatuses: [UUID: WeeklyOutcomeStatus] = [:]
    var reviewSteps: [WeeklyRitualStep] = []
    var completionSummaryText: String = "0 done, 0 still needing a decision, 0 reflections captured."
    var reviewReflectionIsFilled = false
    var outcomeLinkedTaskCounts: [UUID: Int] = [:]
    var taskIDsByOutcomeID: [UUID: [UUID]] = [:]
}

private struct WeeklyReviewDraftPayload: Equatable {
    let wins: String?
    let blockers: String?
    let lessons: String?
    let nextWeekPrepNotes: String?
    let perceivedWeekRating: Int?
    let taskDecisions: [UUID: WeeklyReviewTaskDisposition]
    let outcomeStatuses: [UUID: WeeklyOutcomeStatus]
}

@MainActor
public final class WeeklyReviewViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var snapshot: WeeklyPlanSnapshot?
    @Published public private(set) var reflectionNotes: [ReflectionNote] = []
    @Published public private(set) var selectedHabits: [HabitLibraryRow] = []
    @Published public private(set) var saveMessage: String?
    @Published private(set) var reviewSnapshot: WeeklyReviewSnapshot?
    @Published private(set) var footerSnapshot = WeeklyReviewFooterSnapshot(
        completionSummaryText: "0 done, 0 still needing a decision, 0 reflections captured.",
        canFinishReview: false
    )
    @Published public var outcomeStatusesByID: [UUID: WeeklyOutcomeStatus] = [:] {
        didSet {
            guard outcomeStatusesByID != oldValue else { return }
            handleInteractiveStateChange()
        }
    }
    @Published public var wins: String = "" {
        didSet {
            guard wins != oldValue else { return }
            handleInteractiveStateChange()
        }
    }
    @Published public var blockers: String = "" {
        didSet {
            guard blockers != oldValue else { return }
            handleInteractiveStateChange()
        }
    }
    @Published public var lessons: String = "" {
        didSet {
            guard lessons != oldValue else { return }
            handleInteractiveStateChange()
        }
    }
    @Published public var nextWeekPrepNotes: String = "" {
        didSet {
            guard nextWeekPrepNotes != oldValue else { return }
            handleInteractiveStateChange()
        }
    }
    @Published public var perceivedWeekRating: Int = 3 {
        didSet {
            guard perceivedWeekRating != oldValue else { return }
            handleInteractiveStateChange()
        }
    }
    @Published public var taskDecisions: [UUID: WeeklyReviewTaskDisposition] = [:] {
        didSet {
            guard taskDecisions != oldValue else { return }
            handleInteractiveStateChange()
        }
    }

    public let weekStartDate: Date
    public let weekStartsOn: Weekday

    private let buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase
    private let getHabitLibraryUseCase: GetHabitLibraryUseCase
    private let completeWeeklyReviewUseCase: CompleteWeeklyReviewUseCase
    private let draftStore: WeeklyReviewDraftStoreProtocol
    private let reflectionNoteRepository: ReflectionNoteRepositoryProtocol
    private let gamificationEngine: GamificationEngine?
    private var autosaveWorkItem: DispatchWorkItem?
    private var renderCache = WeeklyReviewRenderCache()
    private var isHydratingLocalState = false
    private var lastPersistedDraftPayload: WeeklyReviewDraftPayload?

    public init(
        referenceDate: Date = Date(),
        weekStartsOn: Weekday = TaskerWorkspacePreferencesStore.shared.load().weekStartsOn,
        buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase,
        getHabitLibraryUseCase: GetHabitLibraryUseCase,
        completeWeeklyReviewUseCase: CompleteWeeklyReviewUseCase,
        draftStore: WeeklyReviewDraftStoreProtocol,
        reflectionNoteRepository: ReflectionNoteRepositoryProtocol,
        gamificationEngine: GamificationEngine? = nil
    ) {
        self.weekStartsOn = weekStartsOn
        self.weekStartDate = XPCalculationEngine.startOfWeek(
            for: referenceDate,
            startingOn: weekStartsOn
        )
        self.buildWeeklyPlanSnapshot = buildWeeklyPlanSnapshot
        self.getHabitLibraryUseCase = getHabitLibraryUseCase
        self.completeWeeklyReviewUseCase = completeWeeklyReviewUseCase
        self.draftStore = draftStore
        self.reflectionNoteRepository = reflectionNoteRepository
        self.gamificationEngine = gamificationEngine
    }

    public var unfinishedTasks: [TaskDefinition] { renderCache.unfinishedTasks }
    public var completedTasks: [TaskDefinition] { renderCache.completedTasks }

    public var weekRangeText: String {
        WeeklyCopy.weekRangeText(for: weekStartDate)
    }

    var reviewSteps: [WeeklyRitualStep] { renderCache.reviewSteps }
    public var completionSummaryText: String { renderCache.completionSummaryText }
    public var reviewReflectionIsFilled: Bool { renderCache.reviewReflectionIsFilled }

    public func load() {
        isLoading = true
        errorMessage = nil
        fetchReviewPayload { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .failure(let error):
                    self.errorMessage = self.presentationErrorMessage(for: error)
                case .success(let payload):
                    self.applyLoadedPayload(payload)
                }
            }
        }
    }

    public func setDecision(_ disposition: WeeklyReviewTaskDisposition, for taskID: UUID) {
        var updatedDecisions = taskDecisions
        updatedDecisions[taskID] = disposition
        taskDecisions = updatedDecisions
    }

    public func setOutcomeStatus(_ status: WeeklyOutcomeStatus, for outcomeID: UUID) {
        var updatedStatuses = outcomeStatusesByID
        updatedStatuses[outcomeID] = status
        outcomeStatusesByID = updatedStatuses
    }

    public func applyDecisionToAllUnfinished(_ disposition: WeeklyReviewTaskDisposition) {
        var updatedDecisions = taskDecisions
        for task in unfinishedTasks {
            updatedDecisions[task.id] = disposition
        }
        taskDecisions = updatedDecisions
    }

    public func clearError() {
        errorMessage = nil
    }

    public func scheduleDraftAutosave() {
        scheduleDraftAutosaveIfNeeded()
    }

    public func saveReflectionNote(
        _ note: ReflectionNote,
        completion: ((Result<ReflectionNote, Error>) -> Void)? = nil
    ) {
        reflectionNoteRepository.saveNote(note) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self.errorMessage = self.presentationErrorMessage(for: error)
                case .success(let savedNote):
                    self.reflectionNotes.insert(savedNote, at: 0)
                    self.reflectionNotes = Array(self.reflectionNotes.prefix(12))
                    self.refreshDerivedState()
                    self.awardReflectionCaptureXP(linkedTaskID: savedNote.linkedTaskID, linkedHabitID: savedNote.linkedHabitID)
                }
                completion?(result)
            }
        }
    }

    public func completeReview(completion: ((String) -> Void)? = nil) {
        guard let plan = snapshot?.plan else {
            errorMessage = "Create the weekly plan before reviewing it."
            return
        }

        isSaving = true
        errorMessage = nil
        saveMessage = nil

        let decisions = taskDecisions
            .map { WeeklyReviewTaskDecision(taskID: $0.key, disposition: $0.value) }
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
                switch result {
                case .failure(let error):
                    self.isSaving = false
                    self.errorMessage = self.presentationErrorMessage(for: error)
                case .success(let completionResult):
                    let skippedTaskIDs = Set(completionResult.skippedTaskIDs)
                    let persistedDecisions = decisions.filter { skippedTaskIDs.contains($0.taskID) == false }
                    self.persistCompletionLocalState(decisions: persistedDecisions) {
                        self.awardWeeklyReviewXP(using: persistedDecisions)
                        self.reloadAfterCompletion { reloadResult in
                            self.isSaving = false
                            switch reloadResult {
                            case .failure(let error):
                                self.saveMessage = self.completionMessage(for: completionResult)
                                self.errorMessage = self.presentationErrorMessage(for: error)
                            case .success:
                                let message = self.completionMessage(for: completionResult)
                                self.saveMessage = message
                                completion?(message)
                            }
                        }
                    }
                }
            }
        }
    }

    private struct LoadedReviewPayload {
        let snapshot: WeeklyPlanSnapshot
        let habitRows: [HabitLibraryRow]
    }

    private func fetchReviewPayload(
        completion: @escaping (Result<LoadedReviewPayload, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var fetchedSnapshot: WeeklyPlanSnapshot?
        var habitRows: [HabitLibraryRow] = []
        var firstError: Error?

        func capture(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        group.enter()
        buildWeeklyPlanSnapshot.execute(referenceDate: weekStartDate) { result in
            switch result {
            case .success(let snapshot):
                fetchedSnapshot = snapshot
            case .failure(let error):
                capture(error)
            }
            group.leave()
        }

        group.enter()
        getHabitLibraryUseCase.execute(includeArchived: true) { result in
            switch result {
            case .success(let habits):
                habitRows = habits
            case .failure(let error):
                capture(error)
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            guard let fetchedSnapshot else {
                completion(.failure(
                    NSError(
                        domain: "WeeklyReviewViewModel",
                        code: 800,
                        userInfo: [NSLocalizedDescriptionKey: "We couldn't refresh the weekly review right now."]
                    )
                ))
                return
            }
            completion(.success(LoadedReviewPayload(snapshot: fetchedSnapshot, habitRows: habitRows)))
        }
    }

    private func applyLoadedPayload(_ payload: LoadedReviewPayload) {
        snapshot = payload.snapshot
        reflectionNotes = payload.snapshot.reflectionNotes

        let selectedHabitIDs = Set(payload.snapshot.plan?.selectedHabitIDs ?? [])
        selectedHabits = payload.habitRows
            .filter { selectedHabitIDs.contains($0.habitID) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        refreshDerivedState()
        loadLocalState(for: payload.snapshot)
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
                self.isHydratingLocalState = true
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
                self.isHydratingLocalState = false
                self.lastPersistedDraftPayload = self.currentDraftPayload()
                self.refreshDerivedState()
            }
        }
    }

    private func reloadAfterCompletion(completion: @escaping (Result<Void, Error>) -> Void) {
        fetchReviewPayload { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    completion(.failure(
                        NSError(
                            domain: "WeeklyReviewViewModel",
                            code: 900,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Review saved, but we couldn't refresh the latest state.",
                                NSUnderlyingErrorKey: error
                            ]
                        )
                    ))
                case .success(let payload):
                    self.applyLoadedPayload(payload)
                    completion(.success(()))
                }
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

    private func refreshDerivedState() {
        guard let snapshot else {
            renderCache = WeeklyReviewRenderCache()
            assignReviewSnapshot(nil)
            assignFooterSnapshot(
                WeeklyReviewFooterSnapshot(
                    completionSummaryText: renderCache.completionSummaryText,
                    canFinishReview: false
                )
            )
            return
        }

        var outcomeLinkedTaskCounts: [UUID: Int] = [:]
        var taskIDsByOutcomeID: [UUID: [UUID]] = [:]
        for task in snapshot.thisWeekTasks {
            guard let outcomeID = task.weeklyOutcomeID else { continue }
            outcomeLinkedTaskCounts[outcomeID, default: 0] += 1
            taskIDsByOutcomeID[outcomeID, default: []].append(task.id)
        }

        let unfinishedTasks = snapshot.thisWeekTasks.filter { !$0.isComplete }
        let completedTasks = snapshot.thisWeekTasks.filter(\.isComplete)
        let reviewReflectionIsFilled = [wins, blockers, lessons, nextWeekPrepNotes]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let outcomeSnapshots = snapshot.outcomes.map { outcome in
            WeeklyReviewOutcomeSnapshot(
                outcome: outcome,
                selectedStatus: outcomeStatusesByID[outcome.id] ?? outcome.status,
                linkedTaskCount: outcomeLinkedTaskCounts[outcome.id] ?? 0
            )
        }
        let completionSummaryText = "\(completedTasks.count) done, \(unfinishedTasks.count) still needing a decision, \(reflectionNotes.count) reflections captured."
        let reviewSteps = [
            WeeklyRitualStep(id: 0, title: WeeklyCopy.reviewSteps[0], isComplete: true),
            WeeklyRitualStep(
                id: 1,
                title: WeeklyCopy.reviewSteps[1],
                isComplete: outcomeStatusesByID.isEmpty == false || snapshot.outcomes.isEmpty
            ),
            WeeklyRitualStep(
                id: 2,
                title: WeeklyCopy.reviewSteps[2],
                isComplete: unfinishedTasks.allSatisfy { taskDecisions[$0.id] != nil }
            ),
            WeeklyRitualStep(id: 3, title: WeeklyCopy.reviewSteps[3], isComplete: reviewReflectionIsFilled)
        ]

        renderCache = WeeklyReviewRenderCache(
            unfinishedTasks: unfinishedTasks,
            completedTasks: completedTasks,
            selectedHabits: selectedHabits,
            outcomeStatuses: outcomeStatusesByID,
            reviewSteps: reviewSteps,
            completionSummaryText: completionSummaryText,
            reviewReflectionIsFilled: reviewReflectionIsFilled,
            outcomeLinkedTaskCounts: outcomeLinkedTaskCounts,
            taskIDsByOutcomeID: taskIDsByOutcomeID
        )

        assignReviewSnapshot(
            WeeklyReviewSnapshot(
                completedTasks: completedTasks,
                unfinishedTasks: unfinishedTasks,
                selectedHabits: selectedHabits,
                outcomeSnapshots: outcomeSnapshots,
                reflectionNotes: reflectionNotes,
                reviewSteps: reviewSteps,
                completionSummaryText: completionSummaryText
            )
        )
        assignFooterSnapshot(
            WeeklyReviewFooterSnapshot(
                completionSummaryText: completionSummaryText,
                canFinishReview: snapshot.plan != nil
            )
        )
    }

    private func assignReviewSnapshot(_ snapshot: WeeklyReviewSnapshot?) {
        guard reviewSnapshot != snapshot else { return }
        reviewSnapshot = snapshot
    }

    private func assignFooterSnapshot(_ snapshot: WeeklyReviewFooterSnapshot) {
        guard footerSnapshot != snapshot else { return }
        footerSnapshot = snapshot
    }

    private func handleInteractiveStateChange() {
        refreshDerivedState()
        scheduleDraftAutosaveIfNeeded()
    }

    private func scheduleDraftAutosaveIfNeeded() {
        guard isHydratingLocalState == false else { return }
        let draftPayload = currentDraftPayload()
        guard draftPayload != lastPersistedDraftPayload else { return }

        autosaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistDraftIfNeeded()
        }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func persistDraftIfNeeded() {
        guard snapshot != nil else { return }
        let draftPayload = currentDraftPayload()
        guard draftPayload != lastPersistedDraftPayload else { return }

        let draft = WeeklyReviewDraft(
            weekStartDate: weekStartDate,
            wins: draftPayload.wins,
            blockers: draftPayload.blockers,
            lessons: draftPayload.lessons,
            nextWeekPrepNotes: draftPayload.nextWeekPrepNotes,
            perceivedWeekRating: draftPayload.perceivedWeekRating,
            taskDecisions: draftPayload.taskDecisions,
            outcomeStatuses: draftPayload.outcomeStatuses,
            updatedAt: Date()
        )
        draftStore.saveDraft(draft) { result in
            DispatchQueue.main.async {
                guard case .success = result else { return }
                self.lastPersistedDraftPayload = draftPayload
                self.saveMessage = nil
            }
        }
    }

    private func currentDraftPayload() -> WeeklyReviewDraftPayload {
        let unfinishedTaskIDs = Set(renderCache.unfinishedTasks.map(\.id))
        let outcomeIDs = Set(snapshot?.outcomes.map(\.id) ?? [])

        return WeeklyReviewDraftPayload(
            wins: wins.nilIfBlank,
            blockers: blockers.nilIfBlank,
            lessons: lessons.nilIfBlank,
            nextWeekPrepNotes: nextWeekPrepNotes.nilIfBlank,
            perceivedWeekRating: perceivedWeekRating,
            taskDecisions: taskDecisions.filter { unfinishedTaskIDs.contains($0.key) },
            outcomeStatuses: outcomeStatusesByID.filter { outcomeIDs.contains($0.key) }
        )
    }

    private func persistCompletionLocalState(
        decisions: [WeeklyReviewTaskDecision],
        completion: @escaping () -> Void
    ) {
        autosaveWorkItem?.cancel()
        draftStore.saveCompletedTaskDecisions(decisions, weekStartDate: weekStartDate) { _ in
            self.draftStore.clearDraft(weekStartDate: self.weekStartDate) { _ in
                DispatchQueue.main.async {
                    self.lastPersistedDraftPayload = nil
                    completion()
                }
            }
        }
    }

    private func completionMessage(for result: CompleteWeeklyReviewResult) -> String {
        let staleCount = result.skippedTaskIDs.count + result.skippedOutcomeIDs.count
        guard staleCount > 0 else {
            return WeeklyCopy.reviewSaveSuccess
        }
        if staleCount == 1 {
            return "Review saved. 1 stale item was skipped."
        }
        return "Review saved. \(staleCount) stale items were skipped."
    }

    private func presentationErrorMessage(for error: Error) -> String {
        if error is SyncWriteClosedError {
            return "Review is unavailable right now because the app is temporarily in read-only mode. Try again after sync recovers."
        }

        let nsError = error as NSError
        if nsError.domain == "WeeklyReviewViewModel", nsError.code == 900 {
            return "Review saved, but we couldn't refresh the latest state. Close and reopen to confirm."
        }
        if nsError.domain == "CoreDataWeeklyReviewMutationRepository", nsError.code == 500 {
            return "This review couldn't be saved right now. Try again in a moment."
        }

        return error.localizedDescription
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
