import Foundation

public protocol WeeklyPlanRepositoryProtocol: Sendable {
    func fetchPlan(id: UUID, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void)
    func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void)
    func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[WeeklyPlan], Error>) -> Void)
    func savePlan(_ plan: WeeklyPlan, completion: @escaping @Sendable (Result<WeeklyPlan, Error>) -> Void)
}

public protocol WeeklyOutcomeRepositoryProtocol: Sendable {
    func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void)
    func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping @Sendable (Result<WeeklyOutcome, Error>) -> Void)
    func replaceOutcomes(
        weeklyPlanID: UUID,
        outcomes: [WeeklyOutcome],
        completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void
    )
    func deleteOutcome(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public protocol WeeklyReviewRepositoryProtocol: Sendable {
    func fetchReview(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<WeeklyReview?, Error>) -> Void)
    func saveReview(_ review: WeeklyReview, completion: @escaping @Sendable (Result<WeeklyReview, Error>) -> Void)
}

public protocol WeeklyReviewMutationRepositoryProtocol: Sendable {
    func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping @Sendable (Result<CompleteWeeklyReviewResult, Error>) -> Void
    )
}

public protocol WeeklyReviewDraftStoreProtocol: Sendable {
    func fetchDraft(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<WeeklyReviewDraft?, Error>) -> Void
    )
    func saveDraft(
        _ draft: WeeklyReviewDraft,
        completion: @escaping @Sendable (Result<WeeklyReviewDraft, Error>) -> Void
    )
    func clearDraft(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    )
    func fetchCompletedTaskDecisions(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    )
    func saveCompletedTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    )
}

public protocol ReflectionNoteRepositoryProtocol: Sendable {
    func fetchNotes(query: ReflectionNoteQuery, completion: @escaping @Sendable (Result<[ReflectionNote], Error>) -> Void)
    func saveNote(_ note: ReflectionNote, completion: @escaping @Sendable (Result<ReflectionNote, Error>) -> Void)
    func deleteNote(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}

public protocol FrictionFindingRepositoryProtocol: Sendable {
    func fetchFindings(
        query: FrictionFindingQuery,
        completion: @escaping @Sendable (Result<[FrictionFinding], Error>) -> Void
    )
    func saveFinding(
        _ finding: FrictionFinding,
        completion: @escaping @Sendable (Result<FrictionFinding, Error>) -> Void
    )
    func deleteFinding(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}
