import Combine
import Foundation

@MainActor
final class HomeNeedsReplanCoordinator: ObservableObject {
    static let dismissedDayKey = "home.needsReplan.dismissedDayKey.v1"

    @Published var passiveCandidates: [HomeReplanCandidate] = []
    @Published var activeCandidates: [HomeReplanCandidate] = []
    @Published var skippedCandidates: [HomeReplanCandidate] = []
    var undoStack: [HomeReplanUndoEntry] = []
    var outcomes = HomeReplanOutcomeSummary()
    var sessionTotal: Int = 0
    var sessionProgress: Int = 0
    var scopedDate: Date?
    var applyingAction: HomeReplanApplyingAction?
    var errorMessage: String?

    private let buildCandidatesUseCase: BuildNeedsReplanCandidatesUseCase
    private let userDefaults: UserDefaults
    private let nowProvider: () -> Date
    private let calendarProvider: () -> Calendar

    init(
        buildCandidatesUseCase: BuildNeedsReplanCandidatesUseCase = BuildNeedsReplanCandidatesUseCase(),
        userDefaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init,
        calendarProvider: @escaping () -> Calendar = { .current }
    ) {
        self.buildCandidatesUseCase = buildCandidatesUseCase
        self.userDefaults = userDefaults
        self.nowProvider = nowProvider
        self.calendarProvider = calendarProvider
    }

    var isApplying: Bool {
        applyingAction != nil
    }

    func replacePassiveCandidates(_ candidates: [HomeReplanCandidate]) {
        passiveCandidates = candidates
    }

    func beginSession(with candidates: [HomeReplanCandidate], scopedTo date: Date?) {
        activeCandidates = candidates
        skippedCandidates = []
        undoStack = []
        outcomes = HomeReplanOutcomeSummary()
        sessionTotal = candidates.count
        sessionProgress = 0
        scopedDate = date
        applyingAction = nil
        errorMessage = nil
    }

    func resetSession(keepPassiveCandidates: Bool) {
        activeCandidates = []
        skippedCandidates = []
        undoStack = []
        outcomes = HomeReplanOutcomeSummary()
        sessionTotal = 0
        sessionProgress = 0
        scopedDate = nil
        applyingAction = nil
        errorMessage = nil
        if keepPassiveCandidates == false {
            passiveCandidates = []
        }
    }

    func phaseForStartingSession() -> HomeReplanSessionPhase? {
        guard isApplying == false else { return nil }
        errorMessage = nil
        guard activeCandidates.isEmpty == false else {
            return .summary(outcomes, skippedCount: 0)
        }
        return .card(candidateIndex: sessionProgress + 1)
    }

    func dismissLater() -> Bool {
        guard isApplying == false else { return false }
        if scopedDate == nil, activeCandidates.isEmpty == false || passiveCandidates.isEmpty == false {
            userDefaults.set(dayKey(for: nowProvider(), calendar: calendarProvider()), forKey: Self.dismissedDayKey)
        }
        resetSession(keepPassiveCandidates: true)
        return true
    }

    func finishSession() -> Bool {
        guard isApplying == false else { return false }
        if skippedCandidates.isEmpty == false, scopedDate == nil {
            userDefaults.set(dayKey(for: nowProvider(), calendar: calendarProvider()), forKey: Self.dismissedDayKey)
        }
        resetSession(keepPassiveCandidates: true)
        return true
    }

    func dismissSessionUI() -> Bool {
        guard isApplying == false else { return false }
        resetSession(keepPassiveCandidates: true)
        return true
    }

    func phaseForReviewingSkippedCandidates() -> HomeReplanSessionPhase? {
        guard isApplying == false else { return nil }
        guard skippedCandidates.isEmpty == false else {
            return nil
        }
        errorMessage = nil
        activeCandidates = skippedCandidates
        skippedCandidates = []
        sessionTotal = activeCandidates.count
        sessionProgress = 0
        return .card(candidateIndex: 1)
    }

    func skipCurrentCandidate() -> HomeReplanSessionPhase? {
        guard isApplying == false else { return nil }
        guard let candidate = activeCandidates.first else { return nil }
        errorMessage = nil
        skippedCandidates.append(candidate)
        activeCandidates.removeFirst()
        sessionProgress += 1
        return nextPhaseAfterCurrentCandidate()
    }

    func phaseForBeginningPlacement(defaultDay: Date) -> HomeReplanSessionPhase? {
        guard isApplying == false else { return nil }
        guard let candidate = activeCandidates.first else { return nil }
        errorMessage = nil
        return .placement(candidate, defaultDay: defaultDay)
    }

    func phaseForCancellingPlacement(currentPhase: HomeReplanSessionPhase) -> HomeReplanSessionPhase? {
        guard isApplying == false else { return nil }
        guard case .placement = currentPhase else { return nil }
        errorMessage = nil
        return .card(candidateIndex: sessionProgress + 1)
    }

    func shouldShowPassiveTray(selectedDate: Date) -> Bool {
        let calendar = calendarProvider()
        let summary = Self.summary(for: passiveCandidates, calendar: calendar)
        guard calendar.isDate(selectedDate, inSameDayAs: nowProvider()),
              summary.count > 0,
              userDefaults.string(forKey: Self.dismissedDayKey) != dayKey(for: nowProvider(), calendar: calendar) else {
            return false
        }
        return true
    }

    func beginApplying(_ action: HomeReplanApplyingAction) {
        applyingAction = action
        errorMessage = nil
    }

    func endApplying() {
        applyingAction = nil
        errorMessage = nil
    }

    func recordFailure(_ error: Error) {
        applyingAction = nil
        errorMessage = "Couldn't update this task. Try again."
    }

    func completeResolution(
        action: HomeReplanResolutionKind,
        candidate: HomeReplanCandidate,
        runID: UUID
    ) -> HomeReplanSessionPhase {
        activeCandidates.removeAll { $0.id == candidate.id }
        passiveCandidates.removeAll { $0.id == candidate.id }
        sessionProgress += 1
        incrementOutcome(for: action)
        undoStack.append(HomeReplanUndoEntry(runID: runID, action: action, candidate: candidate))
        endApplying()
        return nextPhaseAfterCurrentCandidate()
    }

    func restoreUndoEntry(_ entry: HomeReplanUndoEntry) -> HomeReplanSessionPhase {
        undoStack.removeAll { $0.runID == entry.runID }
        decrementOutcome(for: entry.action)
        if activeCandidates.contains(where: { $0.id == entry.candidate.id }) == false {
            activeCandidates.insert(entry.candidate, at: 0)
        }
        sessionProgress = max(0, sessionProgress - 1)
        endApplying()
        return .card(candidateIndex: sessionProgress + 1)
    }

    func nextPhaseAfterCurrentCandidate() -> HomeReplanSessionPhase {
        if activeCandidates.first != nil {
            return .card(candidateIndex: sessionProgress + 1)
        }
        return .summary(outcomes, skippedCount: skippedCandidates.count)
    }

    func makeState(phase: HomeReplanSessionPhase) -> HomeReplanSessionState {
        let currentCandidate = activeCandidates.first
        let candidateIndex = currentCandidate == nil ? 0 : min(max(sessionProgress + 1, 1), max(sessionTotal, 1))
        return HomeReplanSessionState(
            phase: phase,
            summary: Self.summary(for: activeCandidates + skippedCandidates),
            persistentSummary: Self.summary(for: passiveCandidates),
            currentCandidate: currentCandidate,
            candidateIndex: candidateIndex,
            candidateTotal: max(sessionTotal, activeCandidates.count + skippedCandidates.count),
            canUndo: undoStack.isEmpty == false,
            outcomes: outcomes,
            skippedCount: skippedCandidates.count,
            isApplying: applyingAction != nil,
            applyingAction: applyingAction,
            errorMessage: errorMessage
        )
    }

    nonisolated static func buildCandidates(
        from tasks: [TaskDefinition],
        projectsByID: [UUID: Project],
        now: Date = Date(),
        calendar: Calendar = .current,
        scopedTo scopedDate: Date? = nil
    ) -> [HomeReplanCandidate] {
        BuildNeedsReplanCandidatesUseCase().execute(
            tasks: tasks,
            projectsByID: projectsByID,
            now: now,
            calendar: calendar,
            scopedTo: scopedDate
        )
    }

    func buildCandidates(
        from tasks: [TaskDefinition],
        projectsByID: [UUID: Project],
        now: Date = Date(),
        calendar: Calendar = .current,
        scopedTo scopedDate: Date? = nil
    ) -> [HomeReplanCandidate] {
        buildCandidatesUseCase.execute(
            tasks: tasks,
            projectsByID: projectsByID,
            now: now,
            calendar: calendar,
            scopedTo: scopedDate
        )
    }

    nonisolated static func summary(for candidates: [HomeReplanCandidate], calendar: Calendar = .current) -> NeedsReplanSummary {
        let datedCandidates = candidates.filter { $0.anchorDate != nil }
        let dayKeys = Set(datedCandidates.compactMap { candidate in
            candidate.anchorDate.map { dayKey(for: $0, calendar: calendar) }
        })
        return NeedsReplanSummary(
            count: candidates.count,
            datedCount: datedCandidates.count,
            unscheduledCount: candidates.filter { $0.kind == .unscheduledBacklog }.count,
            dayCount: dayKeys.count,
            newestDate: datedCandidates.first?.anchorDate,
            oldestDate: datedCandidates.last?.anchorDate
        )
    }

    func summary(for candidates: [HomeReplanCandidate], calendar: Calendar = .current) -> NeedsReplanSummary {
        Self.summary(for: candidates, calendar: calendar)
    }

    nonisolated static func defaultPlacementDay(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let hour = calendar.component(.hour, from: now)
        let today = calendar.startOfDay(for: now)
        if hour < 17 { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    func defaultPlacementDay(now: Date = Date(), calendar: Calendar = .current) -> Date {
        Self.defaultPlacementDay(now: now, calendar: calendar)
    }

    nonisolated static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        Self.dayKey(for: date, calendar: calendar)
    }

    private func incrementOutcome(for action: HomeReplanResolutionKind) {
        switch action {
        case .rescheduled:
            outcomes.rescheduled += 1
        case .movedToInbox:
            outcomes.movedToInbox += 1
        case .completed:
            outcomes.completed += 1
        case .deleted:
            outcomes.deleted += 1
        }
    }

    private func decrementOutcome(for action: HomeReplanResolutionKind) {
        switch action {
        case .rescheduled:
            outcomes.rescheduled = max(0, outcomes.rescheduled - 1)
        case .movedToInbox:
            outcomes.movedToInbox = max(0, outcomes.movedToInbox - 1)
        case .completed:
            outcomes.completed = max(0, outcomes.completed - 1)
        case .deleted:
            outcomes.deleted = max(0, outcomes.deleted - 1)
        }
    }
}

typealias HomeNeedsReplanViewModel = HomeNeedsReplanCoordinator
