import Foundation

@MainActor
public final class HabitBoardViewModel: ObservableObject {
    @Published public private(set) var boardRows: [HabitBoardRowPresentation] = []
    @Published public private(set) var aggregateDays: [HabitBoardAggregateDay] = []
    @Published public private(set) var libraryRows: [HabitLibraryRow] = []
    /// Long-window rows (≈6 months) that back the Graph lens. Loaded lazily the
    /// first time Graph mode is opened so the default Day/Week lenses stay light.
    @Published public private(set) var graphRows: [HabitBoardRowPresentation] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var endingOn: Date
    @Published public private(set) var viewportColumnCount: Int
    @Published public private(set) var historySpan: Int

    private let getHabitLibraryUseCase: GetHabitLibraryUseCase
    private let getHabitHistoryUseCase: GetHabitHistoryUseCase
    private let resolveHabitOccurrenceUseCase: ResolveHabitOccurrenceUseCase?
    private let logHabitAmountUseCase: LogHabitAmountUseCase?
    private let resetHabitOccurrenceUseCase: ResetHabitOccurrenceUseCase?
    /// Today's logged amount per amount habit, for the Day lens rings.
    @Published public private(set) var todayAmounts: [UUID: Double] = [:]
    /// Habits being logged right now, so a second tap cannot double-log.
    @Published public private(set) var loggingHabitIDs: Set<UUID> = []
    private var hasLoadedOnce = false
    private var hasLoadedGraph = false
    private let graphSpan = 182
    private var latestHistoryByHabitID: [UUID: [HabitDayMark]] = [:]
    private var refreshGeneration = 0

    /// Library row backing a board/graph row, for group-by and scope resolution.
    public func libraryRow(for habitID: UUID) -> HabitLibraryRow? {
        libraryRows.first(where: { $0.habitID == habitID })
    }

    public init(
        getHabitLibraryUseCase: GetHabitLibraryUseCase,
        getHabitHistoryUseCase: GetHabitHistoryUseCase,
        resolveHabitOccurrenceUseCase: ResolveHabitOccurrenceUseCase? = nil,
        logHabitAmountUseCase: LogHabitAmountUseCase? = nil,
        resetHabitOccurrenceUseCase: ResetHabitOccurrenceUseCase? = nil,
        endingOn: Date = Date(),
        viewportColumnCount: Int = 7,
        historySpan: Int = 28
    ) {
        self.getHabitLibraryUseCase = getHabitLibraryUseCase
        self.getHabitHistoryUseCase = getHabitHistoryUseCase
        self.resolveHabitOccurrenceUseCase = resolveHabitOccurrenceUseCase
        self.logHabitAmountUseCase = logHabitAmountUseCase
        self.resetHabitOccurrenceUseCase = resetHabitOccurrenceUseCase
        self.endingOn = endingOn
        let resolvedViewport = max(1, viewportColumnCount)
        self.viewportColumnCount = resolvedViewport
        self.historySpan = max(historySpan, resolvedViewport)
    }

    /// Logging on the board. The board used to be view-only — every tap opened
    /// detail, and the only place to check a habit off was a Home row.
    public var canLogFromBoard: Bool { resolveHabitOccurrenceUseCase != nil }

    /// The action "done for today" means for this habit: complete a build habit,
    /// record a clean day for a quit habit.
    public func todayAction(for habitID: UUID) -> HabitOccurrenceAction {
        libraryRow(for: habitID)?.kind == .negative ? .abstained : .complete
    }

    @discardableResult
    public func logToday(habitID: UUID) async -> Bool {
        guard let resolveHabitOccurrenceUseCase, loggingHabitIDs.contains(habitID) == false else { return false }
        loggingHabitIDs.insert(habitID)
        defer { loggingHabitIDs.remove(habitID) }
        let action = todayAction(for: habitID)
        let result: Result<Void, Error> = await withCheckedContinuation { continuation in
            resolveHabitOccurrenceUseCase.execute(habitID: habitID, action: action, on: Date()) {
                continuation.resume(returning: $0)
            }
        }
        switch result {
        case .success:
            refresh()
            Self.postDailyCommitment(habitID: habitID)
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// A completion that persisted is a commitment; `FirstLightGate` decides
    /// whether it is the day's first. Resets and partial amounts never post.
    static func postDailyCommitment(habitID: UUID) {
        NotificationCenter.default.post(
            name: .lifeboardDailyCommitment,
            object: nil,
            userInfo: ["habitID": habitID.uuidString, FirstLightCommitment.sourceKey: FirstLightCommitment.Source.habit.rawValue]
        )
    }

    /// A slip on a quit habit, recorded for today. Lapse-only habits are clean
    /// by default and never asked for a daily tap; this is the one thing a
    /// person records. Undo is `resetToday`. Never posts a daily commitment.
    @discardableResult
    public func logLapse(habitID: UUID) async -> Bool {
        guard let resolveHabitOccurrenceUseCase, loggingHabitIDs.contains(habitID) == false else { return false }
        loggingHabitIDs.insert(habitID)
        defer { loggingHabitIDs.remove(habitID) }
        let result: Result<Void, Error> = await withCheckedContinuation { continuation in
            resolveHabitOccurrenceUseCase.execute(habitID: habitID, action: .lapsed, on: Date()) {
                continuation.resume(returning: $0)
            }
        }
        switch result {
        case .success:
            refresh()
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// How Home presents and logs a habit; the board rows carry neither kind
    /// nor tracking mode, so this reads the library row behind them.
    public func homeKind(for habitID: UUID) -> HomeHabitKind {
        HomeHabitKind.resolve(
            kind: libraryRow(for: habitID)?.kind ?? .positive,
            trackingMode: libraryRow(for: habitID)?.trackingMode ?? .dailyCheckIn,
            hasAmountTarget: amountTarget(for: habitID) != nil
        )
    }

    /// Undo for a check-in: today goes back to not done.
    @discardableResult
    public func resetToday(habitID: UUID) async -> Bool {
        guard let resetHabitOccurrenceUseCase else { return false }
        let result: Result<Void, Error> = await withCheckedContinuation { continuation in
            resetHabitOccurrenceUseCase.execute(habitID: habitID, on: Date()) { continuation.resume(returning: $0) }
        }
        switch result {
        case .success:
            refresh()
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// The amount target a habit is logged against, if it has one.
    public func amountTarget(for habitID: UUID) -> HabitTarget? {
        guard let target = libraryRow(for: habitID)?.targetConfig?.effectiveTarget,
              HabitAmountRule.target(for: target) != nil else { return nil }
        return target
    }

    /// Log part of an amount from the board. Returns once it is saved, so the
    /// ring only celebrates a completion that persisted.
    @discardableResult
    public func logAmount(habitID: UUID, change: HabitAmountChange) async -> Bool {
        guard let logHabitAmountUseCase else { return false }
        do {
            let receipt = try await logHabitAmountUseCase.execute(habitID: habitID, change: change)
            todayAmounts[habitID] = receipt.after
            if receipt.resolvedNow || receipt.unresolvedNow { refresh() }
            if receipt.resolvedNow { Self.postDailyCommitment(habitID: habitID) }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func loadTodayAmounts(for rows: [HabitLibraryRow]) {
        guard let logHabitAmountUseCase else { return }
        let amountHabitIDs = rows.compactMap { row -> UUID? in
            guard let target = row.targetConfig?.effectiveTarget, HabitAmountRule.target(for: target) != nil else { return nil }
            return row.habitID
        }
        Task { @MainActor [weak self] in
            var amounts: [UUID: Double] = [:]
            for habitID in amountHabitIDs {
                amounts[habitID] = await logHabitAmountUseCase.currentAmount(habitID: habitID)
            }
            self?.todayAmounts = amounts
        }
    }

    public func loadIfNeeded() {
        guard hasLoadedOnce == false else { return }
        hasLoadedOnce = true
        refresh()
    }

    public func clearError() {
        errorMessage = nil
    }

    public func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        errorMessage = nil
        hasLoadedGraph = false

        getHabitLibraryUseCase.execute(includeArchived: false) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard generation == self.refreshGeneration else { return }
                switch result {
                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                case .success(let rows):
                    let activeRows = rows.filter { !$0.isArchived && !$0.isPaused }
                    self.libraryRows = activeRows
                    self.loadTodayAmounts(for: activeRows)
                    self.loadHistory(for: activeRows, generation: generation)
                }
            }
        }
    }

    public func moveWindow(byDays offset: Int) {
        let calendar = Calendar.current
        endingOn = calendar.date(byAdding: .day, value: offset, to: endingOn) ?? endingOn
        refresh()
    }

    public func configureViewport(columnCount: Int, historySpan: Int) {
        let resolvedViewport = max(1, columnCount)
        let resolvedHistorySpan = max(historySpan, resolvedViewport)
        let changed = viewportColumnCount != resolvedViewport || self.historySpan != resolvedHistorySpan
        guard changed else { return }

        viewportColumnCount = resolvedViewport
        self.historySpan = resolvedHistorySpan

        guard hasLoadedOnce else { return }
        refresh()
    }

    public func row(for habitID: UUID) -> HabitLibraryRow? {
        libraryRows.first(where: { $0.habitID == habitID })
    }

    /// Lazily loads the ≈6-month window that backs the Graph lens. Safe to call
    /// repeatedly; it no-ops once loaded and re-arms after any `refresh()`.
    public func loadGraphIfNeeded() {
        guard hasLoadedGraph == false, libraryRows.isEmpty == false else { return }
        hasLoadedGraph = true
        let rows = libraryRows
        let generation = refreshGeneration
        let referenceDate = endingOn
        let span = graphSpan

        getHabitHistoryUseCase.execute(
            habitIDs: rows.map(\.habitID),
            endingOn: referenceDate,
            dayCount: span
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard generation == self.refreshGeneration else { return }
                switch result {
                case .failure:
                    // Leave graphRows empty so the view shows an honest "collecting" state.
                    self.hasLoadedGraph = false
                case .success(let windows):
                    let historyByHabitID = windows.reduce(into: [UUID: [HabitDayMark]]()) { partial, window in
                        partial[window.habitID] = window.marks
                    }
                    let calendar = Calendar.current
                    self.graphRows = rows.map { row in
                        let marks = historyByHabitID[row.habitID] ?? row.last14Days
                        let cells = HabitBoardPresentationBuilder.buildCells(
                            marks: marks,
                            cadence: row.cadence,
                            referenceDate: referenceDate,
                            dayCount: span,
                            calendar: calendar
                        )
                        let metrics = HabitBoardPresentationBuilder.metrics(for: cells)
                        return HabitBoardRowPresentation(
                            habitID: row.habitID,
                            title: row.title,
                            iconSymbolName: row.icon?.symbolName ?? "circle.dashed",
                            accentHex: row.colorHex,
                            colorFamily: HabitColorFamily.family(for: row.colorHex, fallback: row.kind == .positive ? .green : .coral),
                            currentStreak: metrics.currentStreak,
                            bestStreak: metrics.bestStreak,
                            cells: cells,
                            metrics: metrics
                        )
                    }
                }
            }
        }
    }

    private func loadHistory(for rows: [HabitLibraryRow], generation: Int) {
        guard rows.isEmpty == false else {
            boardRows = []
            aggregateDays = []
            isLoading = false
            return
        }

        getHabitHistoryUseCase.execute(
            habitIDs: rows.map(\.habitID),
            endingOn: endingOn,
            dayCount: historySpan
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard generation == self.refreshGeneration else { return }
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
            let historyCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: row.cadence,
                referenceDate: endingOn,
                dayCount: max(historySpan, viewportColumnCount),
                calendar: calendar
            )
            let metrics = HabitBoardPresentationBuilder.metrics(for: historyCells)
            let visibleCells = HabitBoardPresentationBuilder.remapVisibleDisplayDepths(
                in: Array(historyCells.suffix(viewportColumnCount))
            )
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
            dayCount: viewportColumnCount
        )
    }
}
