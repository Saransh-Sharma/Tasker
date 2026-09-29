import LifeBoardDomain
import Foundation

final class WriteClosedWeeklyPlanRepositoryAdapter: WeeklyPlanRepositoryProtocol {
    private let base: WeeklyPlanRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: WeeklyPlanRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchPlan(id: UUID, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void) {
        base.fetchPlan(id: id, completion: completion)
    }

    func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void) {
        base.fetchPlan(forWeekStarting: weekStartDate, completion: completion)
    }

    func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[WeeklyPlan], Error>) -> Void) {
        base.fetchPlans(from: startDate, to: endDate, completion: completion)
    }

    func savePlan(_ plan: WeeklyPlan, completion: @escaping @Sendable (Result<WeeklyPlan, Error>) -> Void) {
        gate.performWrite(operation: "WeeklyPlanRepository.savePlan", completion: completion) {
            self.base.savePlan(plan, completion: completion)
        }
    }
}

final class WriteClosedWeeklyOutcomeRepositoryAdapter: WeeklyOutcomeRepositoryProtocol {
    private let base: WeeklyOutcomeRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: WeeklyOutcomeRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void) {
        base.fetchOutcomes(weeklyPlanID: weeklyPlanID, completion: completion)
    }

    func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping @Sendable (Result<WeeklyOutcome, Error>) -> Void) {
        gate.performWrite(operation: "WeeklyOutcomeRepository.saveOutcome", completion: completion) {
            self.base.saveOutcome(outcome, completion: completion)
        }
    }

    func replaceOutcomes(
        weeklyPlanID: UUID,
        outcomes: [WeeklyOutcome],
        completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void
    ) {
        gate.performWrite(operation: "WeeklyOutcomeRepository.replaceOutcomes", completion: completion) {
            self.base.replaceOutcomes(
                weeklyPlanID: weeklyPlanID,
                outcomes: outcomes,
                completion: completion
            )
        }
    }

    func deleteOutcome(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "WeeklyOutcomeRepository.deleteOutcome", completion: completion) {
            self.base.deleteOutcome(id: id, completion: completion)
        }
    }
}

final class WriteClosedWeeklyReviewRepositoryAdapter: WeeklyReviewRepositoryProtocol {
    private let base: WeeklyReviewRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: WeeklyReviewRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchReview(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<WeeklyReview?, Error>) -> Void) {
        base.fetchReview(weeklyPlanID: weeklyPlanID, completion: completion)
    }

    func saveReview(_ review: WeeklyReview, completion: @escaping @Sendable (Result<WeeklyReview, Error>) -> Void) {
        gate.performWrite(operation: "WeeklyReviewRepository.saveReview", completion: completion) {
            self.base.saveReview(review, completion: completion)
        }
    }
}

final class WriteClosedWeeklyReviewMutationRepositoryAdapter: WeeklyReviewMutationRepositoryProtocol {
    private let base: WeeklyReviewMutationRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: WeeklyReviewMutationRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping @Sendable (Result<CompleteWeeklyReviewResult, Error>) -> Void
    ) {
        gate.performWrite(operation: "WeeklyReviewMutationRepository.finalizeReview", completion: completion) {
            self.base.finalizeReview(request: request, completion: completion)
        }
    }
}

final class WriteClosedReflectionNoteRepositoryAdapter: ReflectionNoteRepositoryProtocol {
    private let base: ReflectionNoteRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: ReflectionNoteRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchNotes(query: ReflectionNoteQuery, completion: @escaping @Sendable (Result<[ReflectionNote], Error>) -> Void) {
        base.fetchNotes(query: query, completion: completion)
    }

    func saveNote(_ note: ReflectionNote, completion: @escaping @Sendable (Result<ReflectionNote, Error>) -> Void) {
        gate.performWrite(operation: "ReflectionNoteRepository.saveNote", completion: completion) {
            self.base.saveNote(note, completion: completion)
        }
    }

    func deleteNote(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "ReflectionNoteRepository.deleteNote", completion: completion) {
            self.base.deleteNote(id: id, completion: completion)
        }
    }
}

final class WriteClosedFrictionFindingRepositoryAdapter: FrictionFindingRepositoryProtocol {
    private let base: FrictionFindingRepositoryProtocol
    private let gate: SyncWriteGate

    init(base: FrictionFindingRepositoryProtocol, gate: SyncWriteGate) {
        self.base = base
        self.gate = gate
    }

    func fetchFindings(
        query: FrictionFindingQuery,
        completion: @escaping @Sendable (Result<[FrictionFinding], Error>) -> Void
    ) {
        base.fetchFindings(query: query, completion: completion)
    }

    func saveFinding(
        _ finding: FrictionFinding,
        completion: @escaping @Sendable (Result<FrictionFinding, Error>) -> Void
    ) {
        gate.performWrite(operation: "FrictionFindingRepository.saveFinding", completion: completion) {
            self.base.saveFinding(finding, completion: completion)
        }
    }

    func deleteFinding(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        gate.performWrite(operation: "FrictionFindingRepository.deleteFinding", completion: completion) {
            self.base.deleteFinding(id: id, completion: completion)
        }
    }
}
