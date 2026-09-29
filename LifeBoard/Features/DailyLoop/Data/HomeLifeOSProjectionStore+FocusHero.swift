import Foundation

extension HomeLifeOSProjectionStore {
    /// Reads the day's drift from `PlanStore`, which has already removed the
    /// repairs this person resolved.
    ///
    /// A failed load leaves `repairProposals` holding either the previous day's
    /// values or an unfiltered list, so a partial load must surface nothing at
    /// all. Absent is not zero drift, but the honest rendering of "we don't
    /// know" on the spine is the same as "nothing to show" — and it is far
    /// better than asking someone to repair a day we failed to read.
    func rebuildDrift(now: Date = HomeReferenceClock.now) {
        guard let snapshot = planSnapshot else {
            if repairProposals.isEmpty == false { repairProposals = [] }
            if driftCount != 0 { driftCount = 0 }
            return
        }
        let nextProposals = loadedRepairProposals
        let nextDriftCount = PlanDriftPolicy.default.surfacedCount(
            proposals: nextProposals,
            in: snapshot,
            now: now
        )
        if repairProposals != nextProposals { repairProposals = nextProposals }
        if driftCount != nextDriftCount { driftCount = nextDriftCount }
    }

    func rebuildFocus() {
        guard let snapshot = planSnapshot else {
            if focusTask != nil { focusTask = nil }
            if focusResult != nil { focusResult = nil }
            return
        }
        let currentTasks = Dictionary(planningTasks.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        let tasks = (snapshot.plannedTasks + snapshot.unscheduledTasks).compactMap { currentTasks[$0.id] }
        let candidates = tasks.map { task in
            FocusRankCandidate(
                id: task.id,
                title: task.title,
                availability: task.metadata.availability,
                dependenciesReady: task.dependenciesReady,
                pinOrder: task.metadata.pinOrder,
                commitmentLevel: task.metadata.commitmentLevel,
                priority: task.metadata.commitmentLevel == .mustDo ? .urgent : .medium,
                planningDay: task.metadata.planningDay,
                dueDate: task.dueDate,
                estimatedDuration: task.estimatedDuration,
                planningContext: task.metadata.planningContext
            )
        }
        let results = rankingService.rank(
            candidates,
            context: FocusRankContext(
                freeWindowDuration: snapshot.capacity.remainingKnownCapacity,
                availableEnergy: latestMood?.energy,
                planningContext: nil
            )
        )
        guard let first = results.first(where: \.isEligible) else {
            if focusTask != nil { focusTask = nil }
            if focusResult != nil { focusResult = nil }
            return
        }
        let nextTask = tasks.first { $0.id == first.candidateID }
        if focusResult != first { focusResult = first }
        if focusTask != nextTask { focusTask = nextTask }
    }

    func rebuildHero(now: Date = HomeReferenceClock.now) {
        if let session = activeFocusSession, session.state == .running || session.state == .paused {
            publishHero(.init(
                id: "active-focus:\(session.id.uuidString)", priority: .activeFocus,
                title: session.state == .paused ? String(localized: "Focus paused") : String(localized: "Focus in progress"),
                primaryActionTitle: session.state == .paused ? "Resume" : "Open focus",
                secondaryActionTitles: ["End"], sourceID: session.id, generatedAt: now
            ))
            return
        }
        if let event = trackSnapshot?.unresolvedMedicationEvents.first(where: { $0.status == .unresolved }) {
            publishHero(.init(
                id: "care:\(event.id.uuidString)", priority: .safetySensitiveCare,
                title: String(localized: "Dose to log"),
                detail: String(localized: "Due \(event.scheduledAt.formatted(date: .omitted, time: .shortened))"),
                primaryActionTitle: "Review", secondaryActionTitles: ["Later"],
                sourceID: event.id, generatedAt: now
            ))
            return
        }
        if let commitment = planSnapshot?.commitments
            .filter({ $0.endAt > now })
            .sorted(by: { $0.startAt < $1.startAt }).first {
            publishHero(.init(
                id: "commitment:\(commitment.id)", priority: .fixedCommitment,
                title: commitment.startAt <= now ? commitment.title : String(localized: "Next: \(commitment.title)"),
                detail: commitment.startAt.formatted(date: .omitted, time: .shortened),
                primaryActionTitle: "Open day", sourceID: nil, generatedAt: now
            ))
            return
        }
        let currentTasks = Dictionary(planningTasks.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        if let mustDo = planSnapshot?.plannedTasks.compactMap({ currentTasks[$0.id] })
            .first(where: { $0.metadata.commitmentLevel == .mustDo }) {
            publishHero(.init(
                id: "must-do:\(mustDo.id.uuidString)", priority: .urgentPlannedWork,
                title: mustDo.title, detail: String(localized: "Must do today"),
                primaryActionTitle: "Start", secondaryActionTitles: ["Why this?"],
                sourceID: mustDo.id, generatedAt: now
            ))
            return
        }
        if let routine = trackSnapshot?.dueRoutines.first {
            publishHero(.init(
                id: "routine:\(routine.id.uuidString)", priority: .timedRoutine,
                title: routine.title, detail: String(localized: "Ready now"),
                primaryActionTitle: "Begin", sourceID: routine.id, generatedAt: now
            ))
            return
        }
        if let task = focusTask {
            publishHero(.init(
                id: "focus:\(task.id.uuidString)", priority: .generalFocus,
                title: task.title, detail: focusResult?.reasons.first?.text,
                primaryActionTitle: "Start", secondaryActionTitles: ["Why this?"],
                sourceID: task.id, generatedAt: now
            ))
            return
        }
        publishHero(.init(
            id: "choose-focus", priority: .generalFocus,
            title: String(localized: "Pick what’s next"),
            primaryActionTitle: "Choose a focus", generatedAt: now
        ))
    }

    private func publishHero(_ next: AdaptiveHeroSnapshot) {
        if let current = heroSnapshot,
           current.id == next.id,
           current.priority == next.priority,
           current.title == next.title,
           current.detail == next.detail,
           current.primaryActionTitle == next.primaryActionTitle,
           current.secondaryActionTitles == next.secondaryActionTitles,
           current.sourceID == next.sourceID {
            return
        }
        heroSnapshot = next
    }
}
