import Foundation

public struct WeeklyOutcomeDraft: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var sourceProjectID: UUID?
    public var whyItMatters: String
    public var successDefinition: String
    public var showsDetails: Bool
    public var showsProjectPicker: Bool

    public init(
        id: UUID = UUID(),
        title: String = "",
        sourceProjectID: UUID? = nil,
        whyItMatters: String = "",
        successDefinition: String = "",
        showsDetails: Bool = false,
        showsProjectPicker: Bool = false
    ) {
        self.id = id
        self.title = title
        self.sourceProjectID = sourceProjectID
        self.whyItMatters = whyItMatters
        self.successDefinition = successDefinition
        self.showsDetails = showsDetails
        self.showsProjectPicker = showsProjectPicker
    }
}

public enum WeeklyPlannerStep: Int, CaseIterable, Identifiable {
    case direction
    case outcomes
    case tasks
    case review

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .direction: return WeeklyCopy.plannerSteps[0]
        case .outcomes: return WeeklyCopy.plannerSteps[1]
        case .tasks: return WeeklyCopy.plannerSteps[2]
        case .review: return WeeklyCopy.plannerSteps[3]
        }
    }

    public var prompt: String {
        switch self {
        case .direction:
            return WeeklyCopy.directionPrompt
        case .outcomes:
            return WeeklyCopy.outcomesPrompt
        case .tasks:
            return WeeklyCopy.tasksPrompt
        case .review:
            return WeeklyCopy.reviewPrompt
        }
    }

    public var nextButtonTitle: String {
        switch self {
        case .direction:
            return WeeklyCopy.continueToOutcomes
        case .outcomes:
            return WeeklyCopy.continueToTasks
        case .tasks:
            return WeeklyCopy.reviewPlan
        case .review:
            return WeeklyCopy.savePlan
        }
    }

    public var stepLabel: String {
        "Step \(rawValue + 1) of \(Self.allCases.count)"
    }
}

public enum WeeklyTaskSourceMode: String, CaseIterable, Identifiable {
    case weeklyCandidates
    case suggested
    case allOpen

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .weeklyCandidates:
            return "Weekly candidates"
        case .suggested:
            return "Suggested"
        case .allOpen:
            return "All open"
        }
    }
}

public struct WeeklyTaskTriageDecision: Equatable {
    public let task: TaskDefinition
    public let sourceBucket: TaskPlanningBucket?
    public let destinationBucket: TaskPlanningBucket
    public let restoredQueueIndex: Int
    public let reviewedCountBefore: Int

    public init(
        task: TaskDefinition,
        sourceBucket: TaskPlanningBucket?,
        destinationBucket: TaskPlanningBucket,
        restoredQueueIndex: Int,
        reviewedCountBefore: Int
    ) {
        self.task = task
        self.sourceBucket = sourceBucket
        self.destinationBucket = destinationBucket
        self.restoredQueueIndex = restoredQueueIndex
        self.reviewedCountBefore = reviewedCountBefore
    }
}

public struct WeeklyPlannerReviewOutcomeSummary: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let projectName: String?
    public let linkedTaskCount: Int

    public init(id: UUID, title: String, projectName: String?, linkedTaskCount: Int) {
        self.id = id
        self.title = title
        self.projectName = projectName
        self.linkedTaskCount = linkedTaskCount
    }
}

public struct WeeklyPlannerReviewLaneSummary: Identifiable, Equatable {
    public let bucket: TaskPlanningBucket
    public let title: String
    public let tasks: [TaskDefinition]

    public var id: String { bucket.rawValue }

    public init(bucket: TaskPlanningBucket, title: String, tasks: [TaskDefinition]) {
        self.bucket = bucket
        self.title = title
        self.tasks = tasks
    }
}

public struct WeeklyPlannerReviewSummary: Equatable {
    public let direction: String?
    public let outcomes: [WeeklyPlannerReviewOutcomeSummary]
    public let lanes: [WeeklyPlannerReviewLaneSummary]
    public let habits: [HabitLibraryRow]
    public let compactSummary: String
    public let compactDetail: String?

    public init(
        direction: String?,
        outcomes: [WeeklyPlannerReviewOutcomeSummary],
        lanes: [WeeklyPlannerReviewLaneSummary],
        habits: [HabitLibraryRow],
        compactSummary: String,
        compactDetail: String?
    ) {
        self.direction = direction
        self.outcomes = outcomes
        self.lanes = lanes
        self.habits = habits
        self.compactSummary = compactSummary
        self.compactDetail = compactDetail
    }
}

public struct WeeklyPlannerTriageCardModel: Equatable {
    public let task: TaskDefinition
    public let currentPlacementText: String
    public let outcomeTitle: String?

    public init(task: TaskDefinition, currentPlacementText: String, outcomeTitle: String?) {
        self.task = task
        self.currentPlacementText = currentPlacementText
        self.outcomeTitle = outcomeTitle
    }
}

public struct WeeklyPlannerTriageSnapshot: Equatable {
    public let cardModel: WeeklyPlannerTriageCardModel?
    public let progressText: String
    public let sectionDetail: String

    public init(cardModel: WeeklyPlannerTriageCardModel?, progressText: String, sectionDetail: String) {
        self.cardModel = cardModel
        self.progressText = progressText
        self.sectionDetail = sectionDetail
    }
}

public struct WeeklyPlannerFooterSnapshot: Equatable {
    public let title: String
    public let detail: String
    public let warning: String?

    public init(title: String, detail: String, warning: String? = nil) {
        self.title = title
        self.detail = detail
        self.warning = warning
    }
}

public struct WeeklyPlannerTaskSourceSnapshot: Equatable {
    public let mode: WeeklyTaskSourceMode
    public let tasks: [TaskDefinition]

    public init(mode: WeeklyTaskSourceMode, tasks: [TaskDefinition]) {
        self.mode = mode
        self.tasks = tasks
    }
}

struct WeeklyPlannerOutcomeOption: Identifiable, Equatable {
    let outcomeID: UUID?
    let title: String

    var id: String { outcomeID?.uuidString ?? "none" }
}

struct PlannerOutcomeAttachmentSheetState: Identifiable, Equatable {
    let taskID: UUID
    let taskTitle: String
    let currentOutcomeID: UUID?
    let outcomeOptions: [WeeklyPlannerOutcomeOption]

    var id: UUID { taskID }
}

private struct WeeklyPlannerRenderCache {
    var tasksByID: [UUID: TaskDefinition] = [:]
    var bucketByTaskID: [UUID: TaskPlanningBucket] = [:]
    var projectNamesByID: [UUID: String] = [:]
    var outcomeTitlesByID: [UUID: String] = [:]
    var selectedHabits: [HabitLibraryRow] = []
    var triageTaskIDSet: Set<UUID> = []
    var weeklyCandidates: [TaskDefinition] = []
    var suggestedCandidates: [TaskDefinition] = []
    var allOpenSorted: [TaskDefinition] = []
    var outcomeLinkedTaskCounts: [UUID: Int] = [:]
    var outcomeOptions: [WeeklyPlannerOutcomeOption] = []
    var triageSnapshot = WeeklyPlannerTriageSnapshot(
        cardModel: nil,
        progressText: "0 of 0 decided",
        sectionDetail: WeeklyCopy.tasksCompleteSubtitle
    )
    var reviewSummary = WeeklyPlannerReviewSummary(
        direction: nil,
        outcomes: [],
        lanes: [],
        habits: [],
        compactSummary: "0 outcomes · 0 this week · 0 habits",
        compactDetail: nil
    )
    var footerSnapshot = WeeklyPlannerFooterSnapshot(
        title: WeeklyPlannerStep.direction.stepLabel,
        detail: "Set the tone for the week.",
        warning: nil
    )
    var taskSourceSnapshots: [WeeklyTaskSourceMode: WeeklyPlannerTaskSourceSnapshot] = [:]
}

struct WeeklyPlannerProposalState: Identifiable {
    public let id = UUID()
    var preview: HomeWeeklyProposalPreview
    var isWorking = false
    var errorMessage: String?

    init(
        preview: HomeWeeklyProposalPreview,
        isWorking: Bool = false,
        errorMessage: String? = nil
    ) {
        self.preview = preview
        self.isWorking = isWorking
        self.errorMessage = errorMessage
    }
}

@MainActor
public final class WeeklyPlannerViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var isRequestingEvaPreview = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var availableHabits: [HabitLibraryRow] = [] {
        didSet { refreshHabitSnapshotIfNeeded() }
    }
    @Published public private(set) var availableProjects: [Project] = [] {
        didSet {
            refreshProjectIndexesIfNeeded()
            refreshOutcomeIndexesIfNeeded()
            refreshReviewSnapshotIfNeeded()
        }
    }
    @Published public private(set) var estimatedCapacity = 3
    @Published public private(set) var saveMessage: String?
    @Published private(set) var proposalState: WeeklyPlannerProposalState?
    @Published public private(set) var allOpenTasks: [TaskDefinition] = [] {
        didSet {
            refreshTaskIndexesIfNeeded()
            refreshTaskSourceSnapshotIfNeeded()
            refreshTriageSnapshotIfNeeded()
        }
    }
    @Published public private(set) var triageTaskIDs: [UUID] = [] {
        didSet {
            refreshTriageQueueIndexesIfNeeded()
            refreshTaskSourceSnapshotIfNeeded()
            refreshTriageSnapshotIfNeeded()
        }
    }
    @Published public private(set) var triageReviewedCount = 0 {
        didSet {
            refreshTriageSnapshotIfNeeded()
            refreshFooterSnapshotIfNeeded()
        }
    }
    @Published public private(set) var currentStep: WeeklyPlannerStep = .direction {
        didSet { refreshFooterSnapshotIfNeeded() }
    }
    @Published public var focusStatement: String = "" {
        didSet {
            refreshReviewSnapshotIfNeeded()
            refreshFooterSnapshotIfNeeded()
        }
    }
    @Published public var selectedHabitIDs: Set<UUID> = [] {
        didSet { refreshHabitSnapshotIfNeeded() }
    }
    @Published public var targetCapacity: Int = 3 {
        didSet {
            refreshReviewSnapshotIfNeeded()
            refreshFooterSnapshotIfNeeded()
        }
    }
    @Published public var minimumViableWeekEnabled = false {
        didSet { refreshFooterSnapshotIfNeeded() }
    }
    @Published public var outcomeDrafts: [WeeklyOutcomeDraft] = [] {
        didSet {
            refreshOutcomeIndexesIfNeeded()
            refreshTaskSourceSnapshotIfNeeded()
            refreshReviewSnapshotIfNeeded()
        }
    }
    @Published public var thisWeekTasks: [TaskDefinition] = [] {
        didSet {
            refreshTaskIndexesIfNeeded()
            refreshTaskSourceSnapshotIfNeeded()
            refreshTriageSnapshotIfNeeded()
            refreshReviewSnapshotIfNeeded()
        }
    }
    @Published public var nextWeekTasks: [TaskDefinition] = [] {
        didSet {
            refreshTaskIndexesIfNeeded()
            refreshTaskSourceSnapshotIfNeeded()
            refreshTriageSnapshotIfNeeded()
            refreshReviewSnapshotIfNeeded()
        }
    }
    @Published public var laterTasks: [TaskDefinition] = [] {
        didSet {
            refreshTaskIndexesIfNeeded()
            refreshTaskSourceSnapshotIfNeeded()
            refreshTriageSnapshotIfNeeded()
            refreshReviewSnapshotIfNeeded()
        }
    }

    public let weekStartDate: Date
    public let plannerPresentation: WeeklyPlannerPresentationMode
    public let weekStartsOn: Weekday

    private let buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase
    private let estimateWeeklyCapacity: EstimateWeeklyCapacityUseCase
    private let getHabitLibraryUseCase: GetHabitLibraryUseCase
    private let projectRepository: ProjectRepositoryProtocol
    private let taskDefinitionRepository: TaskDefinitionRepositoryProtocol
    private let saveWeeklyPlanUseCase: SaveWeeklyPlanUseCase
    private let homeAIActionCoordinator: HomeAIActionCoordinator?
    private let gamificationEngine: GamificationEngine?

    private var initialSnapshot: WeeklyPlanSnapshot?
    private var lastTriageDecision: WeeklyTaskTriageDecision?
    private var renderCache = WeeklyPlannerRenderCache()
    private var suspendsRenderRefresh = false

    init(
        referenceDate: Date = Date(),
        plannerPresentation: WeeklyPlannerPresentationMode = .thisWeek,
        weekStartsOn: Weekday = TaskerWorkspacePreferencesStore.shared.load().weekStartsOn,
        buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase,
        estimateWeeklyCapacity: EstimateWeeklyCapacityUseCase,
        getHabitLibraryUseCase: GetHabitLibraryUseCase,
        projectRepository: ProjectRepositoryProtocol,
        taskDefinitionRepository: TaskDefinitionRepositoryProtocol,
        saveWeeklyPlanUseCase: SaveWeeklyPlanUseCase,
        homeAIActionCoordinator: HomeAIActionCoordinator? = nil,
        gamificationEngine: GamificationEngine? = nil
    ) {
        self.plannerPresentation = plannerPresentation
        self.weekStartsOn = weekStartsOn
        self.weekStartDate = XPCalculationEngine.startOfWeek(
            for: referenceDate,
            startingOn: weekStartsOn
        )
        self.buildWeeklyPlanSnapshot = buildWeeklyPlanSnapshot
        self.estimateWeeklyCapacity = estimateWeeklyCapacity
        self.getHabitLibraryUseCase = getHabitLibraryUseCase
        self.projectRepository = projectRepository
        self.taskDefinitionRepository = taskDefinitionRepository
        self.saveWeeklyPlanUseCase = saveWeeklyPlanUseCase
        self.homeAIActionCoordinator = homeAIActionCoordinator
        self.gamificationEngine = gamificationEngine
    }

    public var canAddOutcome: Bool {
        outcomeDrafts.count < 3
    }

    public var overloadCount: Int {
        max(0, thisWeekTasks.filter { !$0.isComplete }.count - targetCapacity)
    }

    public var weekRangeText: String {
        WeeklyCopy.weekRangeText(for: weekStartDate)
    }

    public var navigationTitle: String {
        WeeklyCopy.plannerTitle(for: plannerPresentation)
    }

    public var errorTitle: String {
        WeeklyCopy.plannerErrorTitle(for: plannerPresentation)
    }

    public var currentStepPrompt: String {
        WeeklyCopy.prompt(for: currentStep, presentation: plannerPresentation)
    }

    public var trimmedFocusStatement: String {
        focusStatement.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var activeOutcomeDraftCount: Int {
        outcomeDrafts.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    public var stagedTaskCount: Int {
        thisWeekTasks.count + nextWeekTasks.count + laterTasks.count
    }

    public var selectedHabits: [HabitLibraryRow] {
        renderCache.selectedHabits
    }

    public var currentTriageTask: TaskDefinition? {
        renderCache.triageSnapshot.cardModel?.task
    }

    public var triageProgressText: String {
        renderCache.triageSnapshot.progressText
    }

    public var currentTriagePlacementText: String {
        renderCache.triageSnapshot.cardModel?.currentPlacementText ?? "Everything in this review queue has a home."
    }

    public var canMoveForward: Bool {
        switch currentStep {
        case .direction:
            return !trimmedFocusStatement.isEmpty || minimumViableWeekEnabled
        case .outcomes:
            return activeOutcomeDraftCount > 0
        case .tasks:
            return currentTriageTask == nil
        case .review:
            return true
        }
    }

    public var reviewSummaryText: String {
        renderCache.reviewSummary.compactSummary
    }

    public var outcomeTitlesByID: [UUID: String] {
        renderCache.outcomeTitlesByID
    }

    public var projectNamesByID: [UUID: String] {
        renderCache.projectNamesByID
    }

    public var reviewSummary: WeeklyPlannerReviewSummary {
        renderCache.reviewSummary
    }

    public var triageSnapshot: WeeklyPlannerTriageSnapshot {
        renderCache.triageSnapshot
    }

    public var footerSnapshot: WeeklyPlannerFooterSnapshot {
        renderCache.footerSnapshot
    }

    var plannerSteps: [WeeklyRitualStep] {
        WeeklyPlannerStep.allCases.map { step in
            WeeklyRitualStep(
                id: step.rawValue,
                title: step.title,
                isComplete: isStepComplete(step)
            )
        }
    }

    public func load() {
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()
        var fetchedSnapshot: WeeklyPlanSnapshot?
        var fetchedHabits: [HabitLibraryRow] = []
        var fetchedProjects: [Project] = []
        var fetchedCapacity = 3
        var fetchedOpenTasks: [TaskDefinition] = []
        var firstError: Error?
        let lock = NSLock()

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
        getHabitLibraryUseCase.execute(includeArchived: false) { result in
            if case .success(let habits) = result {
                fetchedHabits = habits.filter { $0.isArchived == false }
            } else if case .failure(let error) = result {
                capture(error)
            }
            group.leave()
        }

        group.enter()
        projectRepository.fetchCustomProjects { result in
            if case .success(let projects) = result {
                fetchedProjects = projects.filter { !$0.isArchived }
            } else if case .failure(let error) = result {
                capture(error)
            }
            group.leave()
        }

        group.enter()
        estimateWeeklyCapacity.execute(referenceDate: weekStartDate) { result in
            if case .success(let capacity) = result {
                fetchedCapacity = capacity
            } else if case .failure(let error) = result {
                capture(error)
            }
            group.leave()
        }

        group.enter()
        taskDefinitionRepository.fetchAll(query: TaskDefinitionQuery(includeCompleted: false)) { result in
            if case .success(let tasks) = result {
                fetchedOpenTasks = tasks.filter { !$0.isComplete }
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

            self.performBatchedRefresh {
                self.availableHabits = fetchedHabits
                self.availableProjects = fetchedProjects
                self.estimatedCapacity = fetchedCapacity
                self.initialSnapshot = fetchedSnapshot
                self.allOpenTasks = fetchedOpenTasks.sorted(by: self.taskSort)
                self.currentStep = .direction
                self.lastTriageDecision = nil

                if let snapshot = fetchedSnapshot {
                    self.focusStatement = snapshot.plan?.focusStatement ?? ""
                    let selectedHabitIDs = snapshot.plan?.selectedHabitIDs ?? fetchedHabits.map(\.habitID)
                    self.selectedHabitIDs = Set(selectedHabitIDs)
                    self.targetCapacity = max(snapshot.plan?.targetCapacity ?? fetchedCapacity, 1)
                    self.minimumViableWeekEnabled = snapshot.plan?.minimumViableWeekEnabled ?? false
                    self.outcomeDrafts = snapshot.outcomes.map {
                        WeeklyOutcomeDraft(
                            id: $0.id,
                            title: $0.title,
                            sourceProjectID: $0.sourceProjectID,
                            whyItMatters: $0.whyItMatters ?? "",
                            successDefinition: $0.successDefinition ?? "",
                            showsDetails: ($0.whyItMatters?.isEmpty == false) || ($0.successDefinition?.isEmpty == false),
                            showsProjectPicker: $0.sourceProjectID != nil
                        )
                    }
                    if self.outcomeDrafts.isEmpty {
                        self.outcomeDrafts = [WeeklyOutcomeDraft()]
                    }
                    self.thisWeekTasks = snapshot.thisWeekTasks.filter { !$0.isComplete }.sorted(by: self.taskSort)
                    self.nextWeekTasks = snapshot.nextWeekTasks.filter { !$0.isComplete }.sorted(by: self.taskSort)
                    self.laterTasks = snapshot.laterTasks.filter { !$0.isComplete }.sorted(by: self.taskSort)
                } else {
                    self.focusStatement = ""
                    self.selectedHabitIDs = Set(fetchedHabits.map(\.habitID))
                    self.targetCapacity = max(fetchedCapacity, 1)
                    self.minimumViableWeekEnabled = false
                    self.outcomeDrafts = [WeeklyOutcomeDraft()]
                    self.thisWeekTasks = []
                    self.nextWeekTasks = []
                    self.laterTasks = []
                }

                self.resetTriageQueue()
            }
        }
    }

    public func addOutcomeDraft() {
        guard canAddOutcome else { return }
        outcomeDrafts.append(WeeklyOutcomeDraft())
    }

    public func removeOutcomeDraft(id: UUID) {
        outcomeDrafts.removeAll { $0.id == id }
        if outcomeDrafts.isEmpty {
            outcomeDrafts = [WeeklyOutcomeDraft()]
        }
    }

    public func toggleHabit(_ habitID: UUID) {
        if selectedHabitIDs.contains(habitID) {
            selectedHabitIDs.remove(habitID)
        } else {
            selectedHabitIDs.insert(habitID)
        }
    }

    public func clearError() {
        errorMessage = nil
    }

    public func clearProposalError() {
        proposalState?.errorMessage = nil
    }

    public func moveForward() {
        guard canMoveForward else { return }
        guard let nextStep = WeeklyPlannerStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextStep
    }

    public func moveBackward() {
        guard let previousStep = WeeklyPlannerStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previousStep
    }

    public func jumpToStep(_ step: WeeklyPlannerStep) {
        currentStep = step
    }

    public func taskSourceSnapshot(for mode: WeeklyTaskSourceMode) -> WeeklyPlannerTaskSourceSnapshot {
        renderCache.taskSourceSnapshots[mode] ?? WeeklyPlannerTaskSourceSnapshot(mode: mode, tasks: [])
    }

    public func taskSourceTasks(for mode: WeeklyTaskSourceMode) -> [TaskDefinition] {
        taskSourceSnapshot(for: mode).tasks
    }

    public func isTaskInReviewFlow(_ taskID: UUID) -> Bool {
        renderCache.triageTaskIDSet.contains(taskID) || renderCache.bucketByTaskID[taskID] != nil
    }

    public func taskSourceBadge(for taskID: UUID) -> String? {
        if renderCache.triageTaskIDSet.contains(taskID) {
            return "Pending review"
        }
        if let bucket = renderCache.bucketByTaskID[taskID] {
            return bucket.conciseDisplayTitle
        }
        return nil
    }

    func outcomeAttachmentState(for taskID: UUID) -> PlannerOutcomeAttachmentSheetState? {
        guard let task = renderCache.tasksByID[taskID] else { return nil }
        return PlannerOutcomeAttachmentSheetState(
            taskID: taskID,
            taskTitle: task.title,
            currentOutcomeID: task.weeklyOutcomeID,
            outcomeOptions: renderCache.outcomeOptions
        )
    }

    @discardableResult
    public func addTaskToReviewFlow(_ taskID: UUID) -> Bool {
        guard isTaskInReviewFlow(taskID) == false, task(for: taskID) != nil else { return false }
        triageTaskIDs.append(taskID)
        lastTriageDecision = nil
        return true
    }

    @discardableResult
    public func assignCurrentTriageTask(to bucket: TaskPlanningBucket) -> WeeklyTaskTriageDecision? {
        guard let task = currentTriageTask else { return nil }

        let sourceBucket = self.bucket(for: task.id)
        let decision = WeeklyTaskTriageDecision(
            task: task,
            sourceBucket: sourceBucket,
            destinationBucket: bucket,
            restoredQueueIndex: 0,
            reviewedCountBefore: triageReviewedCount
        )

        performBatchedRefresh {
            setTask(task, in: bucket)
            triageTaskIDs.removeAll { $0 == task.id }
            triageReviewedCount += 1
            lastTriageDecision = decision
        }
        return decision
    }

    public func assignWeeklyOutcome(_ outcomeID: UUID?, to taskID: UUID) {
        guard var task = task(for: taskID), bucket(for: taskID) == .thisWeek else { return }
        task.weeklyOutcomeID = outcomeID
        performBatchedRefresh {
            setTask(task, in: .thisWeek)
        }
    }

    @discardableResult
    public func undoLastTriageDecision() -> WeeklyTaskTriageDecision? {
        guard let lastTriageDecision else { return nil }

        performBatchedRefresh {
            removeTaskFromBuckets(lastTriageDecision.task.id)

            if let sourceBucket = lastTriageDecision.sourceBucket {
                var restoredTask = lastTriageDecision.task
                restoredTask.planningBucket = sourceBucket
                setTask(restoredTask, in: sourceBucket)
            }

            let insertionIndex = min(lastTriageDecision.restoredQueueIndex, triageTaskIDs.count)
            triageTaskIDs.insert(lastTriageDecision.task.id, at: insertionIndex)
            triageReviewedCount = lastTriageDecision.reviewedCountBefore
            self.lastTriageDecision = nil
        }
        return lastTriageDecision
    }

    public func save(completion: (() -> Void)? = nil) {
        isSaving = true
        errorMessage = nil
        saveMessage = nil
        saveWeeklyPlanUseCase.execute(request: buildSaveRequest()) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success:
                    self.saveMessage = WeeklyCopy.plannerSaveSuccess
                    self.awardWeeklyPlanningXPIfNeeded()
                    self.load()
                    completion?()
                }
            }
        }
    }

    public func requestEvaPreview() {
        guard let homeAIActionCoordinator else {
            errorMessage = "Eva weekly proposals are unavailable right now."
            return
        }

        errorMessage = nil
        isRequestingEvaPreview = true
        proposalState = nil

        homeAIActionCoordinator.proposeWeeklyPlan(
            mode: .ask,
            weekStartDate: weekStartDate,
            taskChanges: buildProposalChanges(),
            threadID: weeklyProposalThreadID,
            weeklyOutcomeTitlesByID: outcomeTitlesByID,
            rationale: { _ in "Review the staged weekly plan before proposing changes." }
        ) { result in
            DispatchQueue.main.async {
                self.isRequestingEvaPreview = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success(let preview):
                    self.proposalState = WeeklyPlannerProposalState(preview: preview)
                }
            }
        }
    }

    public func requestEvaSuggestion() {
        guard let homeAIActionCoordinator else {
            errorMessage = "Eva weekly proposals are unavailable right now."
            return
        }

        if var proposalState {
            proposalState.isWorking = true
            proposalState.errorMessage = nil
            self.proposalState = proposalState
        }

        homeAIActionCoordinator.proposeWeeklyPlan(
            mode: .suggest,
            weekStartDate: weekStartDate,
            taskChanges: buildProposalChanges(),
            threadID: weeklyProposalThreadID,
            weeklyOutcomeTitlesByID: outcomeTitlesByID,
            rationale: { _ in "Create a confirmation-gated weekly plan proposal from the current staged draft." }
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    if var proposalState = self.proposalState {
                        proposalState.isWorking = false
                        proposalState.errorMessage = error.localizedDescription
                        self.proposalState = proposalState
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                case .success(let preview):
                    self.proposalState = WeeklyPlannerProposalState(preview: preview)
                }
            }
        }
    }

    public func confirmEvaProposal(completion: (() -> Void)? = nil) {
        guard let runID = proposalState?.preview.run?.id,
              let homeAIActionCoordinator else {
            return
        }

        if var proposalState {
            proposalState.isWorking = true
            proposalState.errorMessage = nil
            self.proposalState = proposalState
        }

        homeAIActionCoordinator.confirmAndApply(runID: runID) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    if var proposalState = self.proposalState {
                        proposalState.isWorking = false
                        proposalState.errorMessage = error.localizedDescription
                        self.proposalState = proposalState
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                case .success:
                    self.proposalState = nil
                    self.saveMessage = WeeklyCopy.evaApplySuccess
                    self.load()
                    completion?()
                }
            }
        }
    }

    public func rejectEvaProposal() {
        guard let runID = proposalState?.preview.run?.id,
              let homeAIActionCoordinator else {
            proposalState = nil
            return
        }

        if var proposalState {
            proposalState.isWorking = true
            proposalState.errorMessage = nil
            self.proposalState = proposalState
        }

        homeAIActionCoordinator.reject(runID: runID) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    if var proposalState = self.proposalState {
                        proposalState.isWorking = false
                        proposalState.errorMessage = error.localizedDescription
                        self.proposalState = proposalState
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                case .success:
                    self.proposalState = nil
                }
            }
        }
    }

    public func dismissProposal() {
        proposalState = nil
    }

    private func isStepComplete(_ step: WeeklyPlannerStep) -> Bool {
        switch step {
        case .direction:
            return !trimmedFocusStatement.isEmpty || minimumViableWeekEnabled
        case .outcomes:
            return activeOutcomeDraftCount > 0
        case .tasks:
            return triageTaskIDs.isEmpty
        case .review:
            return activeOutcomeDraftCount > 0 || !trimmedFocusStatement.isEmpty || stagedTaskCount > 0
        }
    }

    private func resetTriageQueue() {
        performBatchedRefresh {
            triageTaskIDs = makeWeeklyCandidateTasks().map(\.id)
            triageReviewedCount = 0
            lastTriageDecision = nil
        }
    }

    private func isSuggestedCandidate(_ task: TaskDefinition) -> Bool {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let dueSoonCutoff = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
        let outcomeProjectIDs = Set(outcomeDrafts.compactMap(\.sourceProjectID))

        let overdue = task.dueDate.map { $0 < startOfToday } ?? false
        let dueSoon = task.dueDate.map { $0 >= startOfToday && $0 <= dueSoonCutoff } ?? false
        let highPriority = task.priority.isHighPriority
        let linkedProject = outcomeProjectIDs.contains(task.projectID)
        return overdue || dueSoon || highPriority || linkedProject
    }

    private func performBatchedRefresh(_ updates: () -> Void) {
        suspendsRenderRefresh = true
        updates()
        suspendsRenderRefresh = false
        refreshAllDerivedState()
    }

    private func refreshAllDerivedState() {
        refreshProjectIndexes()
        refreshOutcomeIndexes()
        refreshTaskIndexes()
        refreshHabitSnapshot()
        refreshTaskSourceSnapshot()
        refreshTriageSnapshot()
        refreshReviewSnapshot()
        refreshFooterSnapshot()
    }

    private func refreshProjectIndexesIfNeeded() {
        guard suspendsRenderRefresh == false else { return }
        refreshProjectIndexes()
    }

    private func refreshOutcomeIndexesIfNeeded() {
        guard suspendsRenderRefresh == false else { return }
        refreshOutcomeIndexes()
    }

    private func refreshHabitSnapshotIfNeeded() {
        guard suspendsRenderRefresh == false else { return }
        refreshHabitSnapshot()
        refreshReviewSnapshot()
        refreshFooterSnapshot()
    }

    private func refreshTaskIndexesIfNeeded() {
        guard suspendsRenderRefresh == false else { return }
        refreshTaskIndexes()
    }

    private func refreshTaskSourceSnapshotIfNeeded() {
        guard suspendsRenderRefresh == false else { return }
        refreshTaskSourceSnapshot()
    }

    private func refreshTriageQueueIndexesIfNeeded() {
        guard suspendsRenderRefresh == false else { return }
        renderCache.triageTaskIDSet = Set(triageTaskIDs)
    }

    private func refreshTriageSnapshotIfNeeded() {
        guard suspendsRenderRefresh == false else { return }
        refreshTriageSnapshot()
        refreshFooterSnapshot()
    }

    private func refreshReviewSnapshotIfNeeded() {
        guard suspendsRenderRefresh == false else { return }
        refreshReviewSnapshot()
        refreshFooterSnapshot()
    }

    private func refreshFooterSnapshotIfNeeded() {
        guard suspendsRenderRefresh == false else { return }
        refreshFooterSnapshot()
    }

    private func refreshProjectIndexes() {
        renderCache.projectNamesByID = Dictionary(uniqueKeysWithValues: availableProjects.map { ($0.id, $0.name) })
    }

    private func refreshOutcomeIndexes() {
        renderCache.outcomeTitlesByID = Dictionary(
            uniqueKeysWithValues: outcomeDrafts.map { ($0.id, $0.title.trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
        renderCache.outcomeOptions = outcomeDrafts.compactMap { draft in
            let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedTitle.isEmpty == false else { return nil }
            return WeeklyPlannerOutcomeOption(outcomeID: draft.id, title: normalizedTitle)
        }
    }

    private func refreshTaskIndexes() {
        var tasksByID: [UUID: TaskDefinition] = Dictionary(uniqueKeysWithValues: allOpenTasks.map { ($0.id, $0) })
        var bucketByTaskID: [UUID: TaskPlanningBucket] = [:]
        var outcomeLinkedTaskCounts: [UUID: Int] = [:]

        for task in thisWeekTasks {
            tasksByID[task.id] = task
            bucketByTaskID[task.id] = .thisWeek
            if let weeklyOutcomeID = task.weeklyOutcomeID {
                outcomeLinkedTaskCounts[weeklyOutcomeID, default: 0] += 1
            }
        }

        for task in nextWeekTasks {
            tasksByID[task.id] = task
            bucketByTaskID[task.id] = .nextWeek
        }

        for task in laterTasks {
            tasksByID[task.id] = task
            bucketByTaskID[task.id] = .later
        }

        renderCache.tasksByID = tasksByID
        renderCache.bucketByTaskID = bucketByTaskID
        renderCache.outcomeLinkedTaskCounts = outcomeLinkedTaskCounts
        renderCache.allOpenSorted = allOpenTasks
    }

    private func refreshHabitSnapshot() {
        renderCache.selectedHabits = availableHabits
            .filter { selectedHabitIDs.contains($0.habitID) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func refreshTaskSourceSnapshot() {
        let weeklyCandidates = makeWeeklyCandidateTasks()
        let suggestedCandidates = makeSuggestedTaskCandidates()

        renderCache.weeklyCandidates = weeklyCandidates
        renderCache.suggestedCandidates = suggestedCandidates
        renderCache.taskSourceSnapshots = [
            .weeklyCandidates: WeeklyPlannerTaskSourceSnapshot(mode: .weeklyCandidates, tasks: weeklyCandidates),
            .suggested: WeeklyPlannerTaskSourceSnapshot(mode: .suggested, tasks: suggestedCandidates),
            .allOpen: WeeklyPlannerTaskSourceSnapshot(mode: .allOpen, tasks: renderCache.allOpenSorted)
        ]
    }

    private func makeWeeklyCandidateTasks() -> [TaskDefinition] {
        let staged = thisWeekTasks + nextWeekTasks + laterTasks
        let stagedIDs = Set(staged.map(\.id))
        let supplemental = renderCache.allOpenSorted.filter { task in
            stagedIDs.contains(task.id) == false && isSuggestedCandidate(task)
        }

        if staged.isEmpty {
            return Array(supplemental.prefix(12))
        }

        let remainingSlots = max(0, 12 - staged.count)
        return staged + Array(supplemental.prefix(remainingSlots))
    }

    private func makeSuggestedTaskCandidates() -> [TaskDefinition] {
        renderCache.allOpenSorted.filter { task in
            renderCache.triageTaskIDSet.contains(task.id) == false
                && renderCache.bucketByTaskID[task.id] == nil
                && isSuggestedCandidate(task)
        }
    }

    private func refreshTriageSnapshot() {
        renderCache.triageTaskIDSet = Set(triageTaskIDs)

        let cardModel: WeeklyPlannerTriageCardModel? = triageTaskIDs.first.flatMap { taskID in
            guard let task = renderCache.tasksByID[taskID] else { return nil }
            let placementText: String
            if let bucket = renderCache.bucketByTaskID[taskID] {
                placementText = "Currently in \(bucket.conciseDisplayTitle)"
            } else {
                placementText = "Not placed yet"
            }
            return WeeklyPlannerTriageCardModel(
                task: task,
                currentPlacementText: placementText,
                outcomeTitle: task.weeklyOutcomeID.flatMap { renderCache.outcomeTitlesByID[$0] }
            )
        }

        let progressText = "\(triageReviewedCount) of \(triageReviewedCount + triageTaskIDs.count) decided"
        let sectionDetail = cardModel == nil
            ? WeeklyCopy.tasksCompleteSubtitle
            : "\(progressText). \(cardModel?.currentPlacementText ?? "Not placed yet")."

        renderCache.triageSnapshot = WeeklyPlannerTriageSnapshot(
            cardModel: cardModel,
            progressText: progressText,
            sectionDetail: sectionDetail
        )
    }

    private func refreshReviewSnapshot() {
        let normalizedOutcomes = outcomeDrafts.compactMap { draft -> WeeklyPlannerReviewOutcomeSummary? in
            let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedTitle.isEmpty == false else { return nil }
            return WeeklyPlannerReviewOutcomeSummary(
                id: draft.id,
                title: normalizedTitle,
                projectName: draft.sourceProjectID.flatMap { renderCache.projectNamesByID[$0] },
                linkedTaskCount: renderCache.outcomeLinkedTaskCounts[draft.id, default: 0]
            )
        }

        let lanes = [
            WeeklyPlannerReviewLaneSummary(bucket: .thisWeek, title: WeeklyCopy.thisWeek, tasks: thisWeekTasks),
            WeeklyPlannerReviewLaneSummary(bucket: .nextWeek, title: WeeklyCopy.nextWeek, tasks: nextWeekTasks),
            WeeklyPlannerReviewLaneSummary(bucket: .later, title: WeeklyCopy.later, tasks: laterTasks)
        ]

        renderCache.reviewSummary = WeeklyPlannerReviewSummary(
            direction: trimmedFocusStatement.isEmpty ? nil : trimmedFocusStatement,
            outcomes: normalizedOutcomes,
            lanes: lanes,
            habits: renderCache.selectedHabits,
            compactSummary: "\(normalizedOutcomes.count) outcomes · \(thisWeekTasks.count) this week · \(selectedHabitIDs.count) habits",
            compactDetail: overloadCount > 0 ? WeeklyCopy.overloadHelper(count: overloadCount) : nil
        )
    }

    private func refreshFooterSnapshot() {
        switch currentStep {
        case .direction:
            renderCache.footerSnapshot = WeeklyPlannerFooterSnapshot(
                title: currentStep.stepLabel,
                detail: trimmedFocusStatement.isEmpty ? "Set the tone for the week." : trimmedFocusStatement
            )
        case .outcomes:
            renderCache.footerSnapshot = WeeklyPlannerFooterSnapshot(
                title: currentStep.stepLabel,
                detail: "\(activeOutcomeDraftCount) of 3 outcomes"
            )
        case .tasks:
            renderCache.footerSnapshot = WeeklyPlannerFooterSnapshot(
                title: currentStep.stepLabel,
                detail: renderCache.triageSnapshot.cardModel == nil ? "Every queued task has a place." : renderCache.triageSnapshot.progressText
            )
        case .review:
            renderCache.footerSnapshot = WeeklyPlannerFooterSnapshot(
                title: renderCache.reviewSummary.compactSummary,
                detail: renderCache.reviewSummary.compactDetail ?? "",
                warning: renderCache.reviewSummary.compactDetail
            )
        }
    }

    private func projectName(for projectID: UUID) -> String? {
        renderCache.projectNamesByID[projectID]
    }

    private func task(for taskID: UUID) -> TaskDefinition? {
        renderCache.tasksByID[taskID]
    }

    private func bucket(for taskID: UUID) -> TaskPlanningBucket? {
        renderCache.bucketByTaskID[taskID]
    }

    private func setTask(_ task: TaskDefinition, in bucket: TaskPlanningBucket) {
        var updatedTask = task
        updatedTask.planningBucket = bucket
        if bucket != .thisWeek {
            updatedTask.weeklyOutcomeID = nil
        }

        removeTaskFromBuckets(task.id)

        switch bucket {
        case .today, .thisWeek:
            thisWeekTasks.append(updatedTask)
            thisWeekTasks.sort(by: taskSort)
        case .nextWeek:
            nextWeekTasks.append(updatedTask)
            nextWeekTasks.sort(by: taskSort)
        case .later, .someday:
            laterTasks.append(updatedTask)
            laterTasks.sort(by: taskSort)
        }
    }

    private func removeTaskFromBuckets(_ taskID: UUID) {
        thisWeekTasks.removeAll { $0.id == taskID }
        nextWeekTasks.removeAll { $0.id == taskID }
        laterTasks.removeAll { $0.id == taskID }
    }

    private func initialAssignmentsByTaskID() -> [UUID: TaskPlanningBucket] {
        guard let initialSnapshot else { return [:] }

        var mapping: [UUID: TaskPlanningBucket] = [:]
        for task in initialSnapshot.thisWeekTasks {
            mapping[task.id] = .thisWeek
        }
        for task in initialSnapshot.nextWeekTasks {
            mapping[task.id] = .nextWeek
        }
        for task in initialSnapshot.laterTasks {
            mapping[task.id] = .later
        }
        return mapping
    }

    private func taskSort(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        if lhs.isOverdue != rhs.isOverdue {
            return lhs.isOverdue && !rhs.isOverdue
        }
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }
        let lhsDue = lhs.dueDate ?? .distantFuture
        let rhsDue = rhs.dueDate ?? .distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private var weeklyProposalThreadID: String {
        "eva_weekly_\(Int(weekStartDate.timeIntervalSince1970))"
    }

    private func buildSaveRequest() -> SaveWeeklyPlanRequest {
        let normalizedOutcomes = outcomeDrafts
            .map { draft in
                var normalized = draft
                normalized.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                normalized.whyItMatters = draft.whyItMatters.trimmingCharacters(in: .whitespacesAndNewlines)
                normalized.successDefinition = draft.successDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
                return normalized
            }
            .filter { !$0.title.isEmpty }
            .prefix(3)
            .map { draft in
                SaveWeeklyPlanOutcomeInput(
                    id: draft.id,
                    title: draft.title,
                    sourceProjectID: draft.sourceProjectID,
                    whyItMatters: draft.whyItMatters.isEmpty ? nil : draft.whyItMatters,
                    successDefinition: draft.successDefinition.isEmpty ? nil : draft.successDefinition
                )
            }

        return SaveWeeklyPlanRequest(
            weekStartDate: weekStartDate,
            focusStatement: trimmedFocusStatement.isEmpty ? nil : trimmedFocusStatement,
            selectedHabitIDs: Array(selectedHabitIDs),
            targetCapacity: targetCapacity,
            minimumViableWeekEnabled: minimumViableWeekEnabled,
            outcomes: normalizedOutcomes,
            taskAssignments: (thisWeekTasks.map {
                SaveWeeklyPlanTaskAssignment(task: $0, planningBucket: .thisWeek, weeklyOutcomeID: $0.weeklyOutcomeID)
            } + nextWeekTasks.map {
                SaveWeeklyPlanTaskAssignment(task: $0, planningBucket: .nextWeek)
            } + laterTasks.map {
                SaveWeeklyPlanTaskAssignment(task: $0, planningBucket: .later)
            }),
            savedAt: Date()
        )
    }

    private func buildProposalChanges() -> [HomeWeeklyTaskProposalChange] {
        let initialAssignments = initialAssignmentsByTaskID()
        let allTasks = thisWeekTasks + nextWeekTasks + laterTasks
        return allTasks.compactMap { task in
            let targetBucket: TaskPlanningBucket = {
                if thisWeekTasks.contains(where: { $0.id == task.id }) { return .thisWeek }
                if nextWeekTasks.contains(where: { $0.id == task.id }) { return .nextWeek }
                return .later
            }()
            let normalizedOutcomeID = targetBucket == .thisWeek ? task.weeklyOutcomeID : nil
            let change = HomeWeeklyTaskProposalChange(
                task: {
                    var baseline = task
                    baseline.planningBucket = initialAssignments[task.id] ?? task.planningBucket
                    baseline.weeklyOutcomeID = baseline.planningBucket == .thisWeek ? task.weeklyOutcomeID : nil
                    return baseline
                }(),
                targetPlanningBucket: targetBucket,
                targetWeeklyOutcomeID: normalizedOutcomeID,
                deferredFromWeekStart: task.deferredFromWeekStart,
                deferredCount: task.deferredCount
            )
            return change.hasMeaningfulChange ? change : nil
        }
    }

    private func awardWeeklyPlanningXPIfNeeded() {
        guard let gamificationEngine else { return }

        let hasMeaningfulPlan = outcomeDrafts.contains { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || !trimmedFocusStatement.isEmpty
            || !thisWeekTasks.isEmpty
            || !selectedHabitIDs.isEmpty
        guard hasMeaningfulPlan else { return }

        gamificationEngine.recordEvent(
            context: XPEventContext(
                category: .weeklyPlan,
                source: .manual,
                completedAt: Date(),
                fromDay: XPCalculationEngine.periodKey(for: weekStartDate)
            )
        ) { _ in }
    }
}
