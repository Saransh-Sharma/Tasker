import Foundation
import Observation

@MainActor
@Observable
final class HomeLifeOSProjectionStore {
    private(set) var planSnapshot: PlanDaySnapshot?
    private(set) var trackSnapshot: TrackTodaySnapshot?
    private(set) var focusTask: PlanningTaskSummary?
    private(set) var focusResult: FocusRankResult?
    private(set) var latestMood: LifeBoardMoodEnergyCheckInValue?
    private(set) var isLoading = false

    private let planStore: PlanStore?
    private let trackStore: TrackFoundationStore?
    private let rankingService: any FocusRankingService

    init(
        planningRepository: CoreDataPlanningRepository?,
        trackRepository: CoreDataTrackFoundationRepository?,
        phaseIIRepository: (any LifeBoardPhaseIIRepository)?,
        rankingService: any FocusRankingService = DeterministicFocusRankingService()
    ) {
        if let planningRepository {
            planStore = PlanStore(planningRepository: planningRepository, blockRepository: planningRepository)
        } else {
            planStore = nil
        }
        if let trackRepository, let phaseIIRepository {
            trackStore = TrackFoundationStore(repository: trackRepository, phaseIIRepository: phaseIIRepository)
        } else {
            trackStore = nil
        }
        self.rankingService = rankingService
    }

    func load() async {
        guard isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }
        if let planStore { await planStore.load() }
        if let trackStore { await trackStore.load() }
        planSnapshot = planStore?.daySnapshot
        trackSnapshot = trackStore?.snapshot
        latestMood = trackStore?.checkIns.first
        rebuildFocus()
    }

    func saveMood(_ mood: LifeBoardJournalMood, energy: Int?) async {
        await trackStore?.saveMood(mood, energy: energy)
        await load()
    }

    func quickAddHydration(_ milliliters: Double) async {
        await trackStore?.quickAddHydration(milliliters)
        await load()
    }

    private func rebuildFocus() {
        guard let snapshot = planSnapshot else { focusTask = nil; focusResult = nil; return }
        let tasks = snapshot.plannedTasks + snapshot.unscheduledTasks
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
        guard let first = results.first(where: \.isEligible) else { focusTask = nil; focusResult = nil; return }
        focusResult = first
        focusTask = tasks.first { $0.id == first.candidateID }
    }
}
