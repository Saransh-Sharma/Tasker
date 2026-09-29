import SwiftUI
import LifeBoardDomain

/// Coalesces Home invalidations into one cancellation-aware generation.
/// The coordinator intentionally owns no view data: expensive provider work
/// happens in the supplied operation and only the current generation may
/// publish its result.
enum HomeRefreshUrgency: Sendable { case automatic, immediate }

typealias HomeRefreshReason = HomeContextRefreshBoundary

struct HomeRefreshRequest {
    var now: Date
    var boundary: HomeRefreshReason
    var reasons: Set<HomeRefreshReason>
    var urgency: HomeRefreshUrgency
}

@MainActor
final class AdaptiveHomeRefreshCoordinator {
    typealias Request = HomeRefreshRequest
    private var task: Task<Void, Never>?
    private var generation = 0
    private var isDebouncing = false
    private let debounce: @MainActor () async throws -> Void

    init(debounce: @escaping @MainActor () async throws -> Void = {
        try await Task.sleep(for: .milliseconds(100))
    }) { self.debounce = debounce }
    private var pending: Request?
    private var activeRequest: Request?
    private var deferred = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private(set) var requestCount = 0
    private(set) var executedCount = 0
    private(set) var completedCount = 0

    func request(now: Date, boundary: HomeRefreshReason, immediate: Bool, deferred: Bool,
                 operation: @escaping @MainActor (Request, Int) async -> Void) {
        requestCount += 1
        generation += 1
        var reasons = pending?.reasons ?? []
        reasons.insert(boundary)
        pending = Request(now: now, boundary: boundary, reasons: reasons,
            urgency: immediate || pending?.urgency == .immediate ? .immediate : .automatic)
        self.deferred = deferred && !immediate
        PerformanceTrace.event("HomeRefreshRequested", value: requestCount)
        if immediate, isDebouncing {
            task?.cancel()
            task = nil
            isDebouncing = false
        }
        startIfNeeded(operation: operation)
    }

    func resume(operation: @escaping @MainActor (Request, Int) async -> Void) {
        deferred = false
        startIfNeeded(operation: operation)
    }

    func isCurrent(_ candidate: Int) -> Bool { candidate == generation && !Task.isCancelled }

    func cancel() {
        // Cancelling presentation must not forget a read already removed from
        // the pending slot. Reactivation needs to retry its dirty domains.
        if let activeRequest {
            if let queued = pending {
                pending = Request(now: queued.now, boundary: queued.boundary,
                    reasons: queued.reasons.union(activeRequest.reasons),
                    urgency: queued.urgency == .immediate || activeRequest.urgency == .immediate
                        ? .immediate : .automatic)
            } else {
                pending = activeRequest
            }
        }
        activeRequest = nil
        generation += 1
        task?.cancel()
        task = nil
        isDebouncing = false
        deferred = true
        finishWaiters()
    }

    func waitUntilSettled() async {
        guard task != nil || pending != nil, !Task.isCancelled else { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled || (task == nil && pending == nil) { continuation.resume() }
                else { waiters[id] = continuation }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.waiters.removeValue(forKey: id)?.resume() }
        }
    }

    private func finishWaiters() {
        let values = waiters.values
        waiters.removeAll()
        values.forEach { $0.resume() }
    }

    private func startIfNeeded(operation: @escaping @MainActor (Request, Int) async -> Void) {
        guard task == nil, pending != nil, !deferred else { return }
        task = Task { [weak self] in
            guard let self else { return }
            if pending?.urgency == .automatic {
                isDebouncing = true
                do { try await debounce(); try Task.checkCancellation() } catch { return }
                isDebouncing = false
            }
            while let request = pending, !deferred, !Task.isCancelled {
                pending = nil
                activeRequest = request
                let current = generation
                executedCount += 1
                PerformanceTrace.event("HomeRefreshExecuted", value: executedCount)
                await operation(request, current)
                guard !Task.isCancelled else { return }
                activeRequest = nil
                if isCurrent(current) {
                    completedCount += 1
                    PerformanceTrace.event("HomeRefreshCompleted", value: completedCount)
                }
            }
            task = nil
            if pending == nil { finishWaiters() }
        }
    }
}
/// The candidates Home derives on its own, next to what the providers return:
/// the hero snapshot as a card, and the Low Energy reduction to one gentle
/// step plus one care check-in.
@MainActor
enum HomeContextCandidateDerivation {
    static func lowEnergyCandidates(
        from candidates: [HomeContextCandidate],
        now: Date
    ) -> [HomeContextCandidate] {
        let care = candidates
            .filter { $0.resolvedSemanticRole == .care }
            .sorted { $0.priority > $1.priority }
            .first
            ?? .init(
                id: "low-energy-essential-care",
                widgetKind: .care,
                title: String(localized: "Care check-in"),
                reason: .init(
                    message: String(localized: "Water, food or planned medication."),
                    signal: String(localized: "low energy mode")
                ),
                destination: .track,
                priority: 900,
                relevantFrom: now,
                semanticRole: .care
            )
        let sourceAction = candidates
            .filter { $0.resolvedSemanticRole == .primaryNow }
            .sorted { $0.priority > $1.priority }
            .first
        let smallAction = HomeContextCandidate(
            id: "low-energy-small-action:\(sourceAction?.id ?? "choose")",
            widgetKind: .focusNow,
            title: sourceAction.map { action in String(localized: "Next: \(action.title)") } ?? String(localized: "Pick a 5-minute task"),
            reason: .init(
                message: String(localized: "Low energy mode keeps the list short."),
                signal: String(localized: "low energy mode")
            ),
            destination: sourceAction?.destination ?? .plan,
            sensitivity: sourceAction?.sensitivity ?? .privateStandard,
            priority: 1_000,
            relevantFrom: now,
            relevantUntil: sourceAction?.relevantUntil,
            semanticRole: .primaryNow
        )
        return [smallAction, care]
    }

    static func homeContextCandidates(lifeOSStore: HomeLifeOSProjectionStore, now: Date) -> [HomeContextCandidate] {
        var candidates: [HomeContextCandidate] = []
        if let hero = lifeOSStore.heroSnapshot {
            let destination: Destination = switch hero.priority {
            case .safetySensitiveCare, .timedRoutine: .track
            case .activeFocus, .fixedCommitment, .urgentPlannedWork, .generalFocus, .recovery: .plan
            }
            let kind: DashboardWidgetKind = switch hero.priority {
            case .safetySensitiveCare: .care
            case .timedRoutine: .routines
            case .fixedCommitment: .compactTimeline
            default: .focusNow
            }
            candidates.append(
                .init(
                    id: hero.id,
                    widgetKind: kind,
                    title: hero.title,
                    reason: .init(
                        message: hero.detail ?? String(localized: "Next on your plan."),
                        signal: hero.priority == .activeFocus ? String(localized: "active focus") : String(localized: "today’s plan")
                    ),
                    destination: destination,
                    sensitivity: hero.priority == .safetySensitiveCare ? .privateSensitive : .privateStandard,
                    priority: hero.priority.rawValue,
                    relevantFrom: now,
                    isUserStartedActiveState: hero.priority == .activeFocus
                )
            )
        }
        return candidates
    }
}

extension HomeContextCandidateProviderRegistry {
    /// The providers Home listens to, one per repository it was given. Kept
    /// out of `AdaptiveHome.init` so the view's own span stays small.
    static func forHome(
        planningRepository: CoreDataPlanningRepository?,
        phaseIIRepository: (any PhaseIIRepository)?,
        trackFoundationRepository: CoreDataTrackFoundationRepository?,
        lifeMomentRepository: (any LifeMomentRepository)?
    ) -> HomeContextCandidateProviderRegistry {
        var candidateProviders: [any HomeContextCandidateSource] = []
        if let planningRepository {
            candidateProviders.append(PlanningHomeContextCandidateSource(repository: planningRepository))
        }
        if let phaseIIRepository {
            candidateProviders.append(JournalHomeContextCandidateSource(repository: phaseIIRepository))
            candidateProviders.append(WeeklyReflectionHomeContextCandidateSource(repository: phaseIIRepository))
            candidateProviders.append(JournalMemoryHomeContextCandidateSource(repository: phaseIIRepository))
            candidateProviders.append(FastingHomeContextCandidateSource(
                repository: FastingRepositoryAdapter(repository: phaseIIRepository)
            ))
        }
        if let trackFoundationRepository {
            candidateProviders.append(GoalHomeContextCandidateSource(repository: trackFoundationRepository))
            candidateProviders.append(RoutineHomeContextCandidateSource(repository: trackFoundationRepository))
        }
        if let lifeMomentRepository {
            candidateProviders.append(LifeMomentContextCandidateSource(repository: lifeMomentRepository))
        }
        return HomeContextCandidateProviderRegistry(providers: candidateProviders)
    }
}

