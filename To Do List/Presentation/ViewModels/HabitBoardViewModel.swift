import Foundation

@MainActor
public final class HabitBoardViewModel: ObservableObject {
    @Published public private(set) var boardRows: [HabitBoardRowPresentation] = []
    @Published public private(set) var aggregateDays: [HabitBoardAggregateDay] = []
    @Published public private(set) var libraryRows: [HabitLibraryRow] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public var summaryMode: HabitBoardSummaryMode = .streaks
    @Published public private(set) var endingOn: Date
    @Published public private(set) var visibleDayCount: Int

    private let getHabitLibraryUseCase: GetHabitLibraryUseCase
    private let getHabitHistoryUseCase: GetHabitHistoryUseCase
    private let historyDayCount = 365
    private var hasLoadedOnce = false
    private var latestHistoryByHabitID: [UUID: [HabitDayMark]] = [:]

    public init(
        getHabitLibraryUseCase: GetHabitLibraryUseCase,
        getHabitHistoryUseCase: GetHabitHistoryUseCase,
        endingOn: Date = Date(),
        visibleDayCount: Int = 14
    ) {
        self.getHabitLibraryUseCase = getHabitLibraryUseCase
        self.getHabitHistoryUseCase = getHabitHistoryUseCase
        self.endingOn = endingOn
        self.visibleDayCount = visibleDayCount
    }

    public func loadIfNeeded() {
        guard hasLoadedOnce == false else { return }
        hasLoadedOnce = true
        refresh()
    }

    public func refresh() {
        isLoading = true
        errorMessage = nil

        getHabitLibraryUseCase.execute(includeArchived: false) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                case .success(let rows):
                    let activeRows = rows.filter { !$0.isArchived }
                    self.libraryRows = activeRows
                    self.loadHistory(for: activeRows)
                }
            }
        }
    }

    public func moveWindow(byDays offset: Int) {
        let calendar = Calendar.current
        endingOn = calendar.date(byAdding: .day, value: offset, to: endingOn) ?? endingOn
        refresh()
    }

    public func setVisibleDayCount(_ dayCount: Int) {
        let clamped = max(14, min(dayCount, 28))
        guard visibleDayCount != clamped else { return }
        visibleDayCount = clamped
        rebuildPresentations(using: latestHistoryByHabitID)
    }

    public func row(for habitID: UUID) -> HabitLibraryRow? {
        libraryRows.first(where: { $0.habitID == habitID })
    }

    private func loadHistory(for rows: [HabitLibraryRow]) {
        guard rows.isEmpty == false else {
            boardRows = []
            aggregateDays = []
            isLoading = false
            return
        }

        getHabitHistoryUseCase.execute(
            habitIDs: rows.map(\.habitID),
            endingOn: endingOn,
            dayCount: historyDayCount
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.rebuildPresentations(using: [:])
                case .success(let windows):
                    let historyByHabitID = windows.reduce(into: [UUID: [HabitDayMark]]()) { partial, window in
                        partial[window.habitID] = window.marks
                    }
                    self.latestHistoryByHabitID = historyByHabitID
                    self.rebuildPresentations(using: historyByHabitID)
                }
            }
        }
    }

    private func rebuildPresentations(using historyByHabitID: [UUID: [HabitDayMark]]) {
        let calendar = Calendar.current
        let presentations = libraryRows.map { row -> HabitBoardRowPresentation in
            let marks = historyByHabitID[row.habitID] ?? row.last14Days
            let allCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: row.cadence,
                referenceDate: endingOn,
                dayCount: max(marks.count, visibleDayCount),
                calendar: calendar
            )
            let metrics = HabitBoardPresentationBuilder.metrics(for: allCells)
            let visibleCells = Array(allCells.suffix(visibleDayCount))
            return HabitBoardRowPresentation(
                habitID: row.habitID,
                title: row.title,
                iconSymbolName: row.icon?.symbolName ?? "circle.dashed",
                accentHex: row.colorHex,
                colorFamily: HabitColorFamily.family(for: row.colorHex, fallback: row.kind == .positive ? .green : .coral),
                currentStreak: metrics.currentStreak,
                bestStreak: metrics.bestStreak,
                cells: visibleCells,
                metrics: metrics
            )
        }
        .sorted { lhs, rhs in
            if lhs.currentStreak != rhs.currentStreak {
                return lhs.currentStreak > rhs.currentStreak
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        boardRows = presentations
        aggregateDays = HabitBoardPresentationBuilder.aggregateDays(
            from: presentations,
            dayCount: visibleDayCount
        )
    }
}
