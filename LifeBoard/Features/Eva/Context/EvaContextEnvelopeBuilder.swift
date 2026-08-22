import Foundation
import LifeBoardDomain

extension EvaJSONValue {
    /// Bridges a typed record into the wire envelope.
    ///
    /// Going through `JSONEncoder.evaCloud` rather than hand-building cases keeps
    /// one date encoding (ISO-8601) and one key strategy across every section, so
    /// the Swift records and the TypeBox schemas cannot disagree about format
    /// while both being "valid JSON".
    static func encoding(_ value: some Encodable) -> EvaJSONValue {
        guard let data = try? JSONEncoder.evaCloud.encode(value),
              let decoded = try? JSONDecoder.evaCloud.decode(EvaJSONValue.self, from: data) else {
            return .null
        }
        return decoded
    }
}

/// Builds the context a single EVA turn carries.
///
/// The render mode is the enforcement point for the offline/cloud split:
///
/// - `.compact` is today's behavior, byte for byte — the plain-text planning
///   block, the same six focus tasks, under the same per-model caps. The rich
///   projectors are never even consulted, so nothing extra is computed,
///   allocated, or fetched on the device path, which also protects the 450 ms
///   projection deadline.
/// - `.rich` emits typed sections against the route's published input cap.
///
/// There is no path where a `.rich` section reaches an on-device model: the mode
/// is derived from the same resolved `EvaContextBudget` that sizes the prompt,
/// and that budget fails closed to offline.
struct EvaContextEnvelopeBuilder: Sendable {
    enum RenderMode: Sendable {
        case compact
        case rich

        init(budget: EvaContextBudget) {
            self = budget.isCloud ? .rich : .compact
        }
    }

    let mode: RenderMode
    let budget: EvaContextBudget

    init(budget: EvaContextBudget) {
        self.mode = RenderMode(budget: budget)
        self.budget = budget
    }

    /// Assembles the envelope for one turn.
    ///
    /// `compactProjection` is the existing plain-text block. It is still carried
    /// on the cloud path as a human-readable summary alongside the typed records:
    /// it is cheap, and it gives the model a rendered overview without having to
    /// reduce 200 records itself.
    func build(
        compactProjection: String,
        tasks: [EvaTaskRecord],
        summary: EvaPlanningSummary,
        projects: [EvaProjectRecord],
        lifeAreas: [EvaLifeAreaRecord],
        habits: [EvaHabitRecord],
        partialSections: [String],
        personalMemory: String?,
        evidence: EvaAuthorizedEvidenceContext,
        consent: EvaConsentPolicy?,
        now: Date = Date(),
        knowledge: [EvaKnowledgeRecord] = [],
        goals: [EvaGoalRecord] = [],
        calendar: [EvaCalendarRecord] = [],
        calendarSourceIDs: [String] = [],
        capacity: EvaCapacityRecord? = nil,
        dayLoop: EvaDayLoopRecord? = nil,
        retrospective: EvaRetrospectiveRecord? = nil
    ) -> EvaContextEnvelope {
        guard mode == .rich else {
            return EvaContextEnvelope(sections: EvaCloudContextProjection.sections(
                taskProjection: compactProjection,
                executiveState: nil,
                slashCommandState: nil,
                personalMemory: personalMemory,
                evidence: evidence,
                consent: consent
            ))
        }

        var sections: [EvaCloudContextSection] = [
            EvaContextSectionFactory.planning(
                renderedOverview: compactProjection,
                summary: summary,
                tasks: fitting(tasks),
                projects: Array(projects.prefix(40)),
                lifeAreas: Array(lifeAreas.prefix(20)),
                partialSections: Array(partialSections.prefix(12)),
                now: now
            ),
        ]

        if habits.isEmpty == false {
            sections.append(.init(category: .habits, payload: .encoding(Array(habits.prefix(40)))))
        }

        if goals.isEmpty == false {
            sections.append(.init(category: .goals, payload: .encoding(Array(goals.prefix(30)))))
        }

        if calendar.isEmpty == false {
            sections.append(.init(
                category: .calendar,
                payload: .encoding(Array(calendar.prefix(60))),
                metadata: .init(
                    availability: calendar.count > 60 ? "partial" : "complete",
                    availableCount: calendar.count,
                    includedCount: min(calendar.count, 60),
                    partialReasons: calendar.count > 60 ? ["recordLimit"] : [],
                    sourceIDs: Array(calendarSourceIDs.prefix(60)),
                    selectionReasons: ["routeBaseline"],
                    freshnessAt: now
                )
            ))
        }

        if let capacity {
            sections.append(.init(category: .capacity, payload: .encoding(capacity)))
        }

        if let dayLoop {
            sections.append(.init(
                category: .dayLoop,
                payload: .encoding(dayLoop),
                metadata: .init(
                    availability: "partial",
                    availableCount: nil,
                    includedCount: nil,
                    partialReasons: ["openAndReversalHistoryUnavailable"],
                    sourceIDs: [],
                    selectionReasons: ["routeBaseline"],
                    freshnessAt: now
                )
            ))
        }

        if let retrospective {
            sections.append(.init(category: .retrospective, payload: .encoding(retrospective)))
        }

        if knowledge.isEmpty == false {
            sections.append(.init(
                category: .knowledge,
                payload: .encoding(Array(knowledge.prefix(24))),
                metadata: .init(
                    availability: "complete",
                    availableCount: knowledge.count,
                    includedCount: min(knowledge.count, 24),
                    partialReasons: knowledge.count > 24 ? ["recordLimit"] : [],
                    sourceIDs: Array(knowledge.prefix(24)).map { $0.id.uuidString.lowercased() },
                    selectionReasons: ["semanticMatch"],
                    freshnessAt: knowledge.map(\.modifiedAt).max()
                )
            ))
        }

        let confirmedMemory = EvaMemoryDefaultsStoreV3.load().contextPayload()
        if consent?.grants.contains(.personalMemory) == true,
           let section = EvaContextSectionFactory.personalMemory(statements: confirmedMemory) {
            sections.append(section)
        }

        sections.append(contentsOf: EvaCloudContextProjection.sections(
            taskProjection: "",
            executiveState: nil,
            slashCommandState: nil,
            personalMemory: nil,
            evidence: evidence,
            consent: consent
        ).filter { $0.category != .planning && $0.category != .personalMemory })

        return EvaContextEnvelope(sections: EvaEnvelopeAllocator.allocate(sections, budget: budget))
    }

    /// Drops whole records, lowest value first, until the roster fits.
    ///
    /// Never truncates a record: a half-written object is invalid against the
    /// server schema, and a half-written identifier is worse than an absent one
    /// because the model may still try to name it.
    private func fitting(_ tasks: [EvaTaskRecord]) -> [EvaTaskRecord] {
        let characterBudget = budget.taskContextCharacters
        guard characterBudget > 0 else { return [] }
        var kept: [EvaTaskRecord] = []
        var used = 0
        // Preserve the assembler's semantic order within each class, while
        // guaranteeing that overdue, maximum-priority, and repeatedly replanned
        // work is considered before a long merely-relevant backlog. The builder
        // is also used directly in tests and feature adapters, so this invariant
        // cannot live only in the assembler.
        let operationalRisk = tasks.filter(isOperationalRisk)
        let remainingTasks = tasks.filter { isOperationalRisk($0) == false }
        for record in operationalRisk + remainingTasks {
            let cost = (try? JSONEncoder.evaCloud.encode(record).count) ?? 400
            guard used + cost <= characterBudget, kept.count < 200 else { continue }
            used += cost
            kept.append(record)
        }
        // Restore a stable, human-meaningful order for the model to read.
        return kept.sorted { lhs, rhs in
            if lhs.bucket != rhs.bucket {
                return bucketOrder(lhs.bucket) < bucketOrder(rhs.bucket)
            }
            return (lhs.due ?? .distantFuture) < (rhs.due ?? .distantFuture)
        }
    }

    private func isOperationalRisk(_ record: EvaTaskRecord) -> Bool {
        record.bucket == .overdue
            || record.priority == "max"
            || record.deferredCount + record.replanCount >= 3
    }

    private func bucketOrder(_ bucket: EvaTaskRecord.Bucket) -> Int {
        switch bucket {
        case .overdue: 0
        case .today: 1
        case .tomorrow: 2
        case .thisWeek: 3
        case .unscheduled: 4
        case .completed: 5
        }
    }
}

struct EvaPlanningSummary: Encodable, Sendable {
    let overdue: Int
    let today: Int
    let tomorrow: Int
    let thisWeek: Int
    let unscheduled: Int
    let completedToday: Int
}

struct EvaProjectRecord: Encodable, Sendable {
    let id: UUID
    let name: String
    let lifeArea: String?
    let openTaskCount: Int
    let motivationWhy: String?
}

struct EvaLifeAreaRecord: Encodable, Sendable {
    let id: UUID
    let name: String
    let openTaskCount: Int
}
