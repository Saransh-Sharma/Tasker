import SwiftUI

/// What a completed habit's receipt may add, never more than one line.
///
/// Milestones are noted, not celebrated; a return after a lapse is welcomed;
/// a miss is never mentioned (PRD: no pressure, no shame).
enum HabitResilienceCopy {
    static let milestones: Set<Int> = [7, 30, 100, 365]

    static func note(streak: Int, previousStreak: Int, recoveredFromLapse: Bool) -> String? {
        if milestones.contains(streak), streak > previousStreak {
            return "\(streak) days of showing up"
        }
        if recoveredFromLapse, streak == 1 {
            return "Back at it"
        }
        return nil
    }

    static func receipt(title: String, note: String?) -> String {
        note.map { "\(title) done · \($0)" } ?? "\(title) done"
    }
}

/// Today's habits, loggable where they are listed.
///
/// Home used to show habits only as a link into the Habit Board. Each habit is
/// now a ring: amount habits tap for a step and hold to finish; check-ins hold
/// to complete and tap to open. The Board stays one tap away for history.
struct HomeHabitsTodaySection: View {
    let router: AppRouter
    let palette: DaypartPalette
    @StateObject private var viewModel: HabitBoardViewModel
    @State private var receipt: HomeHabitReceipt?
    /// First-seen order. Completing a habit re-sorts the board's rows; here
    /// that would slide tiles under the finger mid-interaction.
    @State private var order: [UUID] = []

    init(router: AppRouter, palette: DaypartPalette, viewModel: @autoclosure @escaping () -> HabitBoardViewModel) {
        self.router = router
        self.palette = palette
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    private var todayRows: [HabitBoardRowPresentation] {
        HomeHabitsTodayOrder.stable(
            viewModel.boardRows.filter { row in
                guard let today = row.cells.last(where: \.isToday) else { return false }
                if case .future = today.state { return false }
                return true
            },
            order: order
        )
    }

    var body: some View {
        // A VStack rather than a Group: an empty Group never appears, so a
        // section waiting for its first load would never trigger that load.
        VStack(alignment: .leading, spacing: 0) {
            if todayRows.isEmpty == false {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Habits today")
                            .lifeboardFont(.sectionTitle)
                            .foregroundStyle(palette.color(for: .foreground))
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 8)
                        Button("Board") { router.navigate(.habitBoard, in: .track) }
                            .lifeboardFont(.buttonSmall)
                            .frame(minHeight: 44)
                            .accessibilityHint("Opens the Habit Board with full history")
                            .accessibilityIdentifier("home.habitsToday.board")
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(todayRows) { row in
                                HomeHabitTile(
                                    row: row,
                                    amountTarget: viewModel.amountTarget(for: row.habitID),
                                    amount: viewModel.todayAmounts[row.habitID] ?? 0,
                                    onOpen: { router.navigate(.habitDetail(row.habitID), in: .track) },
                                    onLog: { change in await log(row: row, change: change) }
                                )
                                .transition(.scale(scale: 0.92).combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if let receipt {
                        ReceiptBar(
                            ActionReceiptPresentation(id: receipt.id, message: receipt.message),
                            undo: { Task { await undo(receipt) } },
                            destination: nil,
                            onDismiss: { self.receipt = nil }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.habitsToday")
            }
        }
        .animation(MotionProfile.contentInsertion.animation(reduceMotion: false), value: receipt?.id)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { viewModel.loadIfNeeded() }
        .onChange(of: viewModel.boardRows.map(\.habitID)) { _, ids in
            order = HomeHabitsTodayOrder.merged(order, with: ids)
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeHabitMutation)) { _ in viewModel.refresh() }
    }

    private func log(row: HabitBoardRowPresentation, change: HabitAmountChange) async -> Bool {
        let previousStreak = row.currentStreak
        let wasDone = row.isDoneToday
        if let target = viewModel.amountTarget(for: row.habitID), let goal = HabitAmountRule.target(for: target) {
            let before = viewModel.todayAmounts[row.habitID] ?? 0
            let saved = await viewModel.logAmount(habitID: row.habitID, change: change)
            let after = viewModel.todayAmounts[row.habitID] ?? before
            if saved, before < goal, after >= goal {
                await announceCompletion(of: row, previousStreak: previousStreak, undo: .amount(before))
            }
            return saved
        }
        // A check-in: reaching the ring's one step completes, falling back resets.
        let completing = HabitAmountRule.apply(change, to: wasDone ? 1 : 0, target: 1) >= 1
        if completing == wasDone { return true }
        let saved = completing
            ? await viewModel.logToday(habitID: row.habitID)
            : await viewModel.resetToday(habitID: row.habitID)
        if saved, completing {
            await announceCompletion(of: row, previousStreak: previousStreak, undo: .checkIn)
        }
        return saved
    }

    private func announceCompletion(of row: HabitBoardRowPresentation, previousStreak: Int, undo: HomeHabitReceipt.Undo) async {
        // Give the refreshed board a moment to report the new streak.
        try? await Task.sleep(for: .milliseconds(300))
        let refreshed = viewModel.boardRows.first { $0.habitID == row.habitID }
        let note = HabitResilienceCopy.note(
            streak: refreshed?.currentStreak ?? previousStreak + 1,
            previousStreak: previousStreak,
            recoveredFromLapse: HomeHabitsTodayOrder.isReturnAfterLapse(row.cells)
        )
        receipt = HomeHabitReceipt(
            habitID: row.habitID,
            message: HabitResilienceCopy.receipt(title: row.title, note: note),
            undo: undo
        )
    }

    private func undo(_ receipt: HomeHabitReceipt) async {
        switch receipt.undo {
        case .checkIn:
            _ = await viewModel.resetToday(habitID: receipt.habitID)
        case .amount(let before):
            _ = await viewModel.logAmount(habitID: receipt.habitID, change: .set(before))
        }
        Haptic.decline.play()
        self.receipt = nil
    }
}

private struct HomeHabitReceipt: Equatable {
    enum Undo: Equatable {
        case checkIn
        case amount(Double)
    }

    let id = UUID()
    let habitID: UUID
    let message: String
    let undo: Undo
}

/// One habit: its ring, its name, and one word of state beneath.
private struct HomeHabitTile: View {
    let row: HabitBoardRowPresentation
    let amountTarget: HabitTarget?
    let amount: Double
    let onOpen: () -> Void
    let onLog: (HabitAmountChange) async -> Bool

    var body: some View {
        VStack(spacing: 8) {
            if let amountTarget, let goal = HabitAmountRule.target(for: amountTarget) {
                HabitProgressRing(
                    title: row.title,
                    value: amount,
                    target: goal,
                    step: HabitAmountRule.step(for: amountTarget),
                    unit: { if case let .quantitative(_, unit) = amountTarget { return unit }; return "" }(),
                    isTimed: { if case .timed = amountTarget { return true }; return false }(),
                    size: .board,
                    onChange: onLog
                )
            } else {
                HabitProgressRing(
                    title: row.title,
                    value: row.isDoneToday ? 1 : 0,
                    target: 1,
                    step: 1,
                    unit: "",
                    isTimed: false,
                    size: .board,
                    tapBehavior: .perform(onOpen),
                    showsCount: false,
                    onChange: onLog
                )
            }
            VStack(spacing: 4) {
                Text(row.title)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    .lineLimit(1)
                    .frame(width: 76)
                Text(caption)
                    .lifeboardFont(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .contentTransition(.numericText())
            }
            .accessibilityHidden(true)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            // Secondary actions live on the label, away from the ring's hold.
            .contextMenu {
                Button("Open habit", systemImage: "arrow.up.right.square", action: onOpen)
                if let amountTarget {
                    let step = HabitAmountRule.step(for: amountTarget)
                    if amount > 0 {
                        Button("Undo last step", systemImage: "arrow.uturn.backward") {
                            Task { _ = await onLog(.add(-step)) }
                        }
                    }
                } else if row.isDoneToday {
                    Button("Mark not done", systemImage: "arrow.uturn.backward") {
                        Task { _ = await onLog(.set(0)) }
                    }
                }
            }
        }
        .frame(width: 76)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.habitsToday.tile.\(row.habitID.uuidString)")
    }

    private var caption: String {
        if let amountTarget, let goal = HabitAmountRule.target(for: amountTarget) {
            let isTimed: Bool = { if case .timed = amountTarget { return true }; return false }()
            return HabitRingGeometry.centerText(value: amount, target: goal, isTimed: isTimed)
        }
        return row.isDoneToday ? "Done" : "Hold"
    }
}

extension HabitBoardRowPresentation {
    /// Whether today's cell already counts as done.
    var isDoneToday: Bool {
        guard let today = cells.last(where: \.isToday) else { return false }
        if case .done = today.state { return true }
        return false
    }
}

/// Keeps Home's habit tiles where the person last saw them.
enum HomeHabitsTodayOrder {
    static func merged(_ order: [UUID], with ids: [UUID]) -> [UUID] {
        order.filter(ids.contains) + ids.filter { order.contains($0) == false }
    }

    static func stable(_ rows: [HabitBoardRowPresentation], order: [UUID]) -> [HabitBoardRowPresentation] {
        rows.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.habitID) ?? Int.max
            let right = order.firstIndex(of: rhs.habitID) ?? Int.max
            return left < right
        }
    }

    /// Today follows a miss that itself followed real progress. A habit's
    /// first-ever completion is not a return.
    static func isReturnAfterLapse(_ cells: [HabitBoardCell]) -> Bool {
        let past = cells.filter { $0.isToday == false }
        guard let lastPast = past.last, case .missed = lastPast.state else { return false }
        return past.dropLast().contains { if case .done = $0.state { return true }; return false }
    }
}
