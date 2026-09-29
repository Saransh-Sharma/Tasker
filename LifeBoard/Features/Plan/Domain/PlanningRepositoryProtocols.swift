import Foundation

// MARK: - Repository and service contracts

public protocol PlanningRepository: Sendable {
    func fetchTaskMetadata(taskIDs: Set<UUID>?) async throws -> [PlanningTaskMetadata]
    func saveTaskMetadata(_ value: PlanningTaskMetadata) async throws
    func saveTaskMetadata(_ values: [PlanningTaskMetadata]) async throws
}

public protocol PlanningProjectionRepository: Sendable {
    func fetchOpenPlanningTasks() async throws -> [PlanningTaskSummary]
    func fetchPlanningTasks(includeCompleted: Bool) async throws -> [PlanningTaskSummary]
    func fetchPlanningProjects() async throws -> [PlanningProjectSummary]
}

public extension PlanningProjectionRepository {
    /// Compatibility default for projections that predate completed-task
    /// queries. Production persistence overrides this so Completed and All are
    /// backed by the same canonical rows as every other task scope.
    func fetchPlanningTasks(includeCompleted: Bool) async throws -> [PlanningTaskSummary] {
        try await fetchOpenPlanningTasks()
    }
}

public protocol PlanningCalendarContextRepository: Sendable {
    func authorization() async -> PlanningCalendarAuthorization
    func requestAccess() async -> PlanningCalendarAuthorization
    func fetchCommitments(from: Date, to: Date) async throws -> PlanningCalendarContext
}

public protocol PlanningMutationRepository: Sendable {
    func prepare(_ mutation: PlanMutation, source: String, summary: String) async throws -> PlanMutationReceipt
    func apply(receiptID: UUID) async throws
    func undo(receiptID: UUID) async throws
    func hasAppliedReceipt(source: String) async throws -> Bool
    func appliedReceiptSources(in sources: Set<String>) async throws -> Set<String>
    func fetchMutationReceipts(since: Date?) async throws -> [PlanningReceiptRecord]
}

public protocol FocusExecutionCoordinator: Sendable {
    func activeSession() async throws -> FocusSessionV2?
    func session(id: UUID) async throws -> FocusSessionV2?
    func sessions(since: Date?) async throws -> [FocusSessionV2]
    func commandReceipts(since: Date?) async throws -> [FocusCommandReceipt]
    func start(taskID: UUID?, timeBlockID: UUID?, targetDuration: TimeInterval, at: Date) async throws -> FocusSessionV2
    func handle(_ command: FocusSessionCommand) async throws -> FocusSessionV2
    func updateReflection(sessionID: UUID, energyAfter: Int?, reflection: String?) async throws -> FocusSessionV2
}

public protocol InternalTimeBlockRepository: Sendable {
    func fetchTimeBlocks(from: Date, to: Date) async throws -> [InternalTimeBlock]
    func saveTimeBlock(_ value: InternalTimeBlock) async throws
    func deleteTimeBlock(id: UUID) async throws
    func fetchWorkingHoursProfiles() async throws -> [WorkingHoursProfile]
    func saveWorkingHoursProfile(_ value: WorkingHoursProfile) async throws
}

public protocol FocusRankingService: Sendable {
    func rank(_ candidates: [FocusRankCandidate], context: FocusRankContext) -> [FocusRankResult]
}

public protocol PlanRepairService: Sendable {
    func proposals(for snapshot: PlanDaySnapshot, now: Date) -> [PlanRepairProposal]
}

public protocol PlanningScenarioCoordinating: Sendable {
    func apply(_ scenario: PlanningScenario) async throws -> PlanMutationReceipt
}

public extension PlanningMutationRepository {
    func appliedReceiptSources(in sources: Set<String>) async throws -> Set<String> {
        var result: Set<String> = []
        for source in sources where try await hasAppliedReceipt(source: source) { result.insert(source) }
        return result
    }
}
