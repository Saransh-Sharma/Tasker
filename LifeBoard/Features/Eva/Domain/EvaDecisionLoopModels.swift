import Foundation

enum EvaRitualPhase: String, Codable, CaseIterable, Sendable {
    case loading
    case evidence
    case choosing
    case previewing
    case applying
    case receipt
    case degraded
    case recoverableFailure
}

@MainActor
final class EvaRitualDraftStore {
    static let shared = EvaRitualDraftStore()

    private let defaults: UserDefaults
    private let storageKey = "eva.decision_ritual.drafts.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(_ kind: EvaDecisionRitualKind) -> EvaRitualDraftReference? {
        loadAll()[kind]
    }

    func save(_ draft: EvaRitualDraftReference) {
        var drafts = loadAll()
        drafts[draft.kind] = draft
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func clear(_ kind: EvaDecisionRitualKind) {
        var drafts = loadAll()
        drafts[kind] = nil
        guard drafts.isEmpty == false else {
            defaults.removeObject(forKey: storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(drafts) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func loadAll() -> [EvaDecisionRitualKind: EvaRitualDraftReference] {
        guard let data = defaults.data(forKey: storageKey),
              let drafts = try? JSONDecoder().decode(
                [EvaDecisionRitualKind: EvaRitualDraftReference].self,
                from: data
              ) else { return [:] }
        return drafts
    }
}

enum MakeItFitDestination: String, Codable, CaseIterable, Hashable, Sendable {
    case keepToday
    case tomorrow
    case later
    case someday
    case inbox
}

struct MakeItFitChoice: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID { taskID }
    let taskID: UUID
    var destination: MakeItFitDestination
}

struct CommitmentRealismSnapshot: Equatable, Sendable {
    let day: PlanningDay
    let usableMinutes: Int
    let plannedKnownMinutes: Int
    let overloadMinutes: Int
    let missingEstimateCount: Int
    let fixedCommitments: [PlanningFixedCommitment]
    let flexibleTasks: [PlanningTaskSummary]
    let anchorTaskID: UUID?

    var canAssertOverload: Bool { overloadMinutes > 0 && missingEstimateCount <= 2 }
    var orientation: String {
        if canAssertOverload {
            return "You have \(Self.duration(usableMinutes)) usable and \(Self.duration(plannedKnownMinutes)) planned. About \(Self.duration(overloadMinutes)) needs another home."
        }
        if missingEstimateCount > 2 {
            return "Today may be tighter than it looks. \(missingEstimateCount) tasks still need an estimate."
        }
        return "Today fits the known capacity. You can still renegotiate what deserves the day."
    }

    static func duration(_ minutes: Int) -> String {
        let value = max(0, minutes)
        let hours = value / 60
        let remainder = value % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}

enum CommitmentRealismEngine {
    static func snapshot(from day: PlanDaySnapshot) -> CommitmentRealismSnapshot {
        let tasks = day.plannedTasks.sorted(by: taskPrecedes)
        return CommitmentRealismSnapshot(
            day: day.day,
            usableMinutes: Int(day.capacity.usableDuration / 60),
            plannedKnownMinutes: Int(day.capacity.plannedEstimatedDuration / 60),
            overloadMinutes: Int(day.capacity.overloadDuration / 60),
            missingEstimateCount: day.capacity.missingEstimateCount,
            fixedCommitments: day.commitments.sorted { $0.startAt < $1.startAt },
            flexibleTasks: tasks,
            anchorTaskID: tasks.first?.id
        )
    }

    static func remainingOverloadMinutes(
        snapshot: CommitmentRealismSnapshot,
        choices: [UUID: MakeItFitDestination]
    ) -> Int {
        let movedKnownMinutes = snapshot.flexibleTasks.reduce(0) { result, task in
            guard choices[task.id] != nil,
                  choices[task.id] != .keepToday,
                  let estimate = task.estimatedDuration else { return result }
            return result + Int(estimate / 60)
        }
        return max(0, snapshot.overloadMinutes - movedKnownMinutes)
    }

    private static func taskPrecedes(_ lhs: PlanningTaskSummary, _ rhs: PlanningTaskSummary) -> Bool {
        let left = (
            lhs.metadata.commitmentLevel == .mustDo ? 0 : 1,
            priorityOrder(lhs.priority),
            lhs.alignsWithWeeklyOutcome ? 0 : 1,
            lhs.dueDate ?? .distantFuture,
            lhs.title.localizedLowercase
        )
        let right = (
            rhs.metadata.commitmentLevel == .mustDo ? 0 : 1,
            priorityOrder(rhs.priority),
            rhs.alignsWithWeeklyOutcome ? 0 : 1,
            rhs.dueDate ?? .distantFuture,
            rhs.title.localizedLowercase
        )
        return left < right
    }

    private static func priorityOrder(_ value: FocusPriorityBand) -> Int {
        switch value { case .urgent: 0; case .high: 1; case .medium: 2; case .low: 3 }
    }
}

struct FrictionEvidenceSnapshot: Equatable, Sendable {
    let taskID: UUID
    let evidence: [Insight.Evidence]
    let distinctEventCount: Int
    let possibleReasons: [FrictionReason]

    var isProactivelyEligible: Bool { distinctEventCount >= 3 }
}

enum FrictionEvidenceIndex {
    static func analyze(
        task: TaskDefinition,
        uniqueActionRunCount: Int = 0
    ) -> FrictionEvidenceSnapshot {
        let fallbackCount = max(task.deferredCount, task.replanCount)
        let eventCount = max(uniqueActionRunCount, fallbackCount)
        let reference = EvaRecordReference(
            kind: .task,
            recordID: task.id,
            title: task.title,
            subtitle: task.projectName,
            occurredAt: task.updatedAt
        )
        var evidence: [Insight.Evidence] = []
        if eventCount > 0 {
            evidence.append(.init(
                reference: reference,
                reason: eventCount == 1 ? "Replanned once" : "Replanned \(eventCount) times",
                signalKey: "replan_count"
            ))
        }
        if task.estimatedDuration == nil {
            evidence.append(.init(
                reference: reference,
                reason: "No duration estimate yet",
                signalKey: "missing_estimate"
            ))
        } else if (task.estimatedDuration ?? 0) >= 90 * 60 {
            evidence.append(.init(
                reference: reference,
                reason: "Estimated at least 90 minutes",
                signalKey: "large_scope"
            ))
        }
        if task.dependencies.isEmpty == false {
            evidence.append(.init(
                reference: reference,
                reason: "Linked dependencies may affect readiness",
                signalKey: "dependencies"
            ))
        }

        var possibilities: [FrictionReason] = []
        if task.estimatedDuration == nil || (task.estimatedDuration ?? 0) >= 90 * 60 {
            possibilities.append(.scopeTooLarge)
            possibilities.append(.nextStepUnclear)
        }
        if task.dependencies.isEmpty == false { possibilities.append(.blockedOrWaiting) }
        possibilities.append(.timingOrEnergy)
        possibilities.append(.priorityChanged)

        return FrictionEvidenceSnapshot(
            taskID: task.id,
            evidence: evidence,
            distinctEventCount: eventCount,
            possibleReasons: Array(possibilities.uniqued().prefix(3))
        )
    }
}

/// The deterministic inverse data for one confirmed Friction Detective change.
/// The finding and optional reflection identifiers are added after the task
/// mutation succeeds so the receipt can reverse the entire ritual.
public struct FrictionInterventionReceipt: Equatable, Sendable {
    public let originalTask: TaskDefinition
    public let createdChildTaskID: UUID?
    public var findingID: UUID?
    public var reflectionNoteID: UUID?

    public init(
        originalTask: TaskDefinition,
        createdChildTaskID: UUID?,
        findingID: UUID? = nil,
        reflectionNoteID: UUID? = nil
    ) {
        self.originalTask = originalTask
        self.createdChildTaskID = createdChildTaskID
        self.findingID = findingID
        self.reflectionNoteID = reflectionNoteID
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
