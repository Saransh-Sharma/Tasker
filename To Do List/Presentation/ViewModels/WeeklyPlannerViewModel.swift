import Foundation

public struct WeeklyOutcomeDraft: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var sourceProjectID: UUID?
    public var whyItMatters: String
    public var successDefinition: String

    public init(
        id: UUID = UUID(),
        title: String = "",
        sourceProjectID: UUID? = nil,
        whyItMatters: String = "",
        successDefinition: String = ""
    ) {
        self.id = id
        self.title = title
        self.sourceProjectID = sourceProjectID
        self.whyItMatters = whyItMatters
        self.successDefinition = successDefinition
    }
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
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var availableHabits: [HabitLibraryRow] = []
    @Published public private(set) var availableProjects: [Project] = []
    @Published public private(set) var estimatedCapacity = 3
    @Published public private(set) var saveMessage: String?
    @Published private(set) var proposalState: WeeklyPlannerProposalState?
    @Published public var focusStatement: String = ""
    @Published public var selectedHabitIDs: Set<UUID> = []
    @Published public var targetCapacity: Int = 3
    @Published public var minimumViableWeekEnabled = false
    @Published public var outcomeDrafts: [WeeklyOutcomeDraft] = []
    @Published public var thisWeekTasks: [TaskDefinition] = []
    @Published public var nextWeekTasks: [TaskDefinition] = []
    @Published public var laterTasks: [TaskDefinition] = []

    public let weekStartDate: Date

    private let buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase
    private let estimateWeeklyCapacity: EstimateWeeklyCapacityUseCase
    private let getHabitLibraryUseCase: GetHabitLibraryUseCase
    private let projectRepository: ProjectRepositoryProtocol
    private let saveWeeklyPlanUseCase: SaveWeeklyPlanUseCase
    private let homeAIActionCoordinator: HomeAIActionCoordinator?
    private let gamificationEngine: GamificationEngine?

    private var initialSnapshot: WeeklyPlanSnapshot?

    init(
        referenceDate: Date = Date(),
        buildWeeklyPlanSnapshot: BuildWeeklyPlanSnapshotUseCase,
        estimateWeeklyCapacity: EstimateWeeklyCapacityUseCase,
        getHabitLibraryUseCase: GetHabitLibraryUseCase,
        projectRepository: ProjectRepositoryProtocol,
        saveWeeklyPlanUseCase: SaveWeeklyPlanUseCase,
        homeAIActionCoordinator: HomeAIActionCoordinator? = nil,
        gamificationEngine: GamificationEngine? = nil
    ) {
        let calendar = XPCalculationEngine.mondayCalendar()
        self.weekStartDate = XPCalculationEngine.mondayStartOfWeek(for: referenceDate, calendar: calendar)
        self.buildWeeklyPlanSnapshot = buildWeeklyPlanSnapshot
        self.estimateWeeklyCapacity = estimateWeeklyCapacity
        self.getHabitLibraryUseCase = getHabitLibraryUseCase
        self.projectRepository = projectRepository
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

    public func load() {
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()
        var fetchedSnapshot: WeeklyPlanSnapshot?
        var fetchedHabits: [HabitLibraryRow] = []
        var fetchedProjects: [Project] = []
        var fetchedCapacity = 3
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

        group.notify(queue: .main) {
            self.isLoading = false
            if let firstError {
                self.errorMessage = firstError.localizedDescription
                return
            }

            self.availableHabits = fetchedHabits
            self.availableProjects = fetchedProjects
            self.estimatedCapacity = fetchedCapacity
            self.initialSnapshot = fetchedSnapshot

            if let snapshot = fetchedSnapshot {
                self.focusStatement = snapshot.plan?.focusStatement ?? ""
                self.selectedHabitIDs = Set(snapshot.plan?.selectedHabitIDs ?? [])
                self.targetCapacity = max(snapshot.plan?.targetCapacity ?? fetchedCapacity, 1)
                self.minimumViableWeekEnabled = snapshot.plan?.minimumViableWeekEnabled ?? false
                self.outcomeDrafts = snapshot.outcomes.map {
                    WeeklyOutcomeDraft(
                        id: $0.id,
                        title: $0.title,
                        sourceProjectID: $0.sourceProjectID,
                        whyItMatters: $0.whyItMatters ?? "",
                        successDefinition: $0.successDefinition ?? ""
                    )
                }
                if self.outcomeDrafts.isEmpty {
                    self.outcomeDrafts = [WeeklyOutcomeDraft()]
                }
                self.thisWeekTasks = snapshot.thisWeekTasks
                self.nextWeekTasks = snapshot.nextWeekTasks
                self.laterTasks = snapshot.laterTasks
            } else {
                self.targetCapacity = max(fetchedCapacity, 1)
                self.outcomeDrafts = [WeeklyOutcomeDraft()]
            }
        }
    }

    public func addOutcomeDraft() {
        guard canAddOutcome else { return }
        outcomeDrafts.append(WeeklyOutcomeDraft())
    }

    public func clearError() {
        errorMessage = nil
    }

    public func clearProposalError() {
        proposalState?.errorMessage = nil
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

    public func moveTask(_ taskID: UUID, to bucket: TaskPlanningBucket) {
        let allTasks = thisWeekTasks + nextWeekTasks + laterTasks
        guard let task = allTasks.first(where: { $0.id == taskID }) else { return }

        thisWeekTasks.removeAll { $0.id == taskID }
        nextWeekTasks.removeAll { $0.id == taskID }
        laterTasks.removeAll { $0.id == taskID }

        switch bucket {
        case .today:
            thisWeekTasks.append(task)
            thisWeekTasks.sort(by: taskSort)
        case .thisWeek:
            thisWeekTasks.append(task)
            thisWeekTasks.sort(by: taskSort)
        case .nextWeek:
            nextWeekTasks.append(task)
            nextWeekTasks.sort(by: taskSort)
        case .later:
            laterTasks.append(task)
            laterTasks.sort(by: taskSort)
        case .someday:
            laterTasks.append(task)
            laterTasks.sort(by: taskSort)
        }
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
                    self.saveMessage = "Week saved"
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
        proposalState = nil

        homeAIActionCoordinator.proposeWeeklyPlan(
            mode: .ask,
            weekStartDate: weekStartDate,
            taskChanges: buildProposalChanges(),
            threadID: weeklyProposalThreadID,
            weeklyOutcomeTitlesByID: weeklyOutcomeTitlesByID,
            rationale: { _ in "Review the staged weekly plan before proposing changes." }
        ) { result in
            DispatchQueue.main.async {
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
            weeklyOutcomeTitlesByID: weeklyOutcomeTitlesByID,
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
                    self.saveMessage = "Eva applied the weekly proposal"
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

        homeAIActionCoordinator.reject(runID: runID) { _ in
            DispatchQueue.main.async {
                self.proposalState = nil
            }
        }
    }

    public func dismissProposal() {
        proposalState = nil
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
        if lhs.isComplete != rhs.isComplete {
            return !lhs.isComplete && rhs.isComplete
        }
        return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
    }

    private var weeklyOutcomeTitlesByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: outcomeDrafts.map { ($0.id, $0.title.trimmingCharacters(in: .whitespacesAndNewlines)) })
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
            focusStatement: focusStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focusStatement.trimmingCharacters(in: .whitespacesAndNewlines),
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
            || !focusStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
