import Combine
import Foundation

final class HomeNeedsReplanViewModel: ObservableObject {
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

    init(buildCandidatesUseCase: BuildNeedsReplanCandidatesUseCase = BuildNeedsReplanCandidatesUseCase()) {
        self.buildCandidatesUseCase = buildCandidatesUseCase
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
}
