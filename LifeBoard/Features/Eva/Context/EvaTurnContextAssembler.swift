import Foundation

/// Assembles the context sections for one turn.
///
/// This is the seam the chat view calls. It exists so the provider split lives
/// in one testable place rather than as a conditional inside a 2,500-line view,
/// and so the offline path keeps calling exactly the code it called before.
enum EvaTurnContextAssembler {
    /// Sections for a turn, sized and shaped by the resolved budget.
    ///
    /// Offline returns the v1 projection unchanged. Cloud projects the task
    /// graph into typed records and drops whole records to fit.
    ///
    /// A failed or timed-out rich projection degrades to the compact sections
    /// rather than to nothing: a smaller honest envelope still answers most
    /// questions, whereas an empty one makes EVA claim it cannot see anything.
    static func sections(
        budget: EvaContextBudget,
        compactProjection: String,
        executiveState: String?,
        slashCommandState: String?,
        personalMemory: String?,
        habitSignals: [LifeBoardHabitSignal],
        evidence: EvaAuthorizedEvidenceContext,
        consent: EvaConsentPolicy?,
        userQuery: String = "",
        now: Date = Date()
    ) async -> [EvaCloudContextSection] {
        let compact = EvaCloudContextProjection.sections(
            taskProjection: compactProjection,
            executiveState: executiveState,
            slashCommandState: slashCommandState,
            personalMemory: personalMemory,
            evidence: evidence,
            consent: consent
        )
        guard budget.isCloud, let projector = EvaPlanningProjector.makeDefault() else {
            return compact
        }

        guard let projection = await projectionWithDeadline(projector, now: now) else {
            let degraded = EvaContextSectionFactory.planning(
                renderedOverview: compactProjection,
                partialSections: ["planningProjectionDeadline"],
                now: now
            )
            return EvaEnvelopeAllocator.allocate([degraded], budget: budget)
        }
        let tasks = await semanticallyPrioritized(projection.tasks, query: userQuery)

        let envelope = EvaContextEnvelopeBuilder(budget: budget).build(
            compactProjection: compactProjection,
            tasks: tasks,
            summary: projection.summary,
            projects: projection.projects,
            lifeAreas: projection.lifeAreas,
            habits: habitSignals.map(EvaHabitRecord.init(signal:)),
            partialSections: projection.partialSections,
            personalMemory: personalMemory,
            evidence: evidence,
            consent: consent,
            now: now
        )
        return envelope.ordered()
    }

    private static func projectionWithDeadline(
        _ projector: EvaPlanningProjector,
        now: Date
    ) async -> EvaPlanningProjector.Projection? {
        let race = EvaProjectionDeadlineRace()
        return await withCheckedContinuation { continuation in
            Task { await race.resolve(await projector.project(now: now), continuation: continuation) }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                await race.resolve(nil, continuation: continuation)
            }
        }
    }

    /// Promotes records the question is actually about.
    ///
    /// The v1 projection selected context by substring matching, which misses
    /// "what should I do about the launch" against a task called "draft the
    /// announcement". The embedding index already exists and is already
    /// maintained on every task write — it was simply never used for EVA's
    /// context, only for search ranking.
    ///
    /// This reorders rather than filters. Relevance decides what survives an
    /// overflow, but it must not be able to hide overdue work from a question
    /// that did not happen to mention it.
    @MainActor
    private static func semanticallyPrioritized(
        _ tasks: [EvaTaskRecord],
        query: String
    ) -> [EvaTaskRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let service = TaskSemanticRetrievalService.shared
        guard trimmed.isEmpty == false, service.isActivated else { return tasks }

        let ranked = service.rerank(taskIDs: tasks.map(\.id), query: trimmed)
        guard ranked.isEmpty == false else { return tasks }

        let rank = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($1, $0) })
        return tasks.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = rank[lhs.element.id] ?? Int.max
                let rhsRank = rank[rhs.element.id] ?? Int.max
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

private actor EvaProjectionDeadlineRace {
    private var didResolve = false

    func resolve(
        _ projection: EvaPlanningProjector.Projection?,
        continuation: CheckedContinuation<EvaPlanningProjector.Projection?, Never>
    ) {
        guard didResolve == false else { return }
        didResolve = true
        continuation.resume(returning: projection)
    }
}
