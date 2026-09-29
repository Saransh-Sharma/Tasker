import SwiftUI

/// What a completed habit's receipt may add, never more than one line.
///
/// Milestones are noted, not celebrated; a return after a lapse is welcomed;
/// a miss is never mentioned (PRD: no pressure, no shame).
enum HabitResilienceCopy {
    static let milestones: Set<Int> = [7, 30, 100, 365]

    static func note(streak: Int, previousStreak: Int, recoveredFromLapse: Bool) -> String? {
        if milestones.contains(streak), streak > previousStreak {
            return String(localized: "\(streak)-day streak")
        }
        if recoveredFromLapse, streak == 1 {
            return String(localized: "Back at it")
        }
        return nil
    }

    static func receipt(title: String, note: String?) -> String {
        note.map { note in String(localized: "\(title) done · \(note)") } ?? String(localized: "\(title) done")
    }
}

/// Today's habits, loggable where they are listed.
///
/// A horizontal row of cards, one per habit due today, each in the habit's own
/// colour: build habits hold to finish, amount habits tap a step, quit habits
/// show their clean count and record a slip only when there is one. The row
/// scrolls edge to edge so the next card always peeks, and ends at the Board.
/// At accessibility text sizes the cards stack instead of truncating.
struct HomeHabitsTodaySection: View {
    let router: AppRouter
    let palette: DaypartPalette
    @StateObject private var viewModel: HabitBoardViewModel
    @State private var receipt: HomeHabitReceipt?
    @State private var amountEntry: HabitAmountEntryContext?
    @State private var slipCandidate: HabitBoardRowPresentation?
    /// First-seen order. Completing a habit re-sorts the board's rows; here
    /// that would slide cards under the finger mid-interaction.
    @State private var order: [UUID] = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    /// Every habit today is done, reached, or (for a quit habit) still clean.
    private var allHandled: Bool {
        todayRows.allSatisfy { row in
            switch viewModel.homeKind(for: row.habitID) {
            case .quitLapseOnly:
                guard let today = row.cells.last(where: \.isToday) else { return true }
                if case .missed = today.state { return false }
                return true
            case .buildAmount:
                guard let target = viewModel.amountTarget(for: row.habitID),
                      let goal = HabitAmountRule.target(for: target) else { return row.isDoneToday }
                return (viewModel.todayAmounts[row.habitID] ?? 0) >= goal
            case .buildCheckIn, .quitCheckIn:
                return row.isDoneToday
            }
        }
    }

    var body: some View {
        // A VStack rather than a Group: an empty Group never appears, so a
        // section waiting for its first load would never trigger that load.
        VStack(alignment: .leading, spacing: 0) {
            if todayRows.isEmpty == false {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 12) {
                            ForEach(todayRows) { row in card(for: row, width: nil) }
                            HomeHabitsAllHabitsCard(fixedWidth: nil, action: openBoard)
                        }
                    } else if layoutClass.isPad {
                        // At iPad and Mac widths every habit fits on screen, so
                        // they wrap into a grid. A sideways carousel there hid
                        // cards past the edge that a mouse wheel cannot reach.
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: HomeHabitCard.width, maximum: 240), spacing: 12, alignment: .top)],
                            alignment: .leading,
                            spacing: 12
                        ) {
                            ForEach(todayRows) { row in card(for: row, width: nil) }
                            HomeHabitsAllHabitsCard(fixedWidth: nil, action: openBoard)
                        }
                        .accessibilityIdentifier("home.habitsToday.row")
                    } else {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(todayRows) { row in
                                    card(for: row, width: HomeHabitCard.width)
                                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                                }
                                HomeHabitsAllHabitsCard(action: openBoard)
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        // Edge to edge, with the first card on Home's reading
                        // margin: the next card always peeks past the screen
                        // edge, so the row visibly continues.
                        .contentMargins(.horizontal, 20, for: .scrollContent)
                        .scrollClipDisabled()
                        .padding(.horizontal, -20)
                        .accessibilityIdentifier("home.habitsToday.row")
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
        .animation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion), value: receipt?.id)
        .sheet(item: $amountEntry) { context in
            HabitAmountEntrySheet(context: context) { value in
                await setAmount(context: context, to: value)
            }
        }
        .confirmationDialog(
            HomeHabitCopy.slipConfirmTitle,
            isPresented: Binding(get: { slipCandidate != nil }, set: { if $0 == false { slipCandidate = nil } }),
            titleVisibility: .visible,
            presenting: slipCandidate
        ) { row in
            Button(HomeHabitCopy.slipConfirmAction) {
                Task { await logSlip(row) }
            }
            .accessibilityIdentifier("home.habitsToday.slip.confirm")
            Button("Cancel", role: .cancel) { slipCandidate = nil }
        } message: { _ in
            Text(HomeHabitCopy.slipConfirmMessage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { viewModel.loadIfNeeded() }
        .onChange(of: viewModel.boardRows.map(\.habitID)) { _, ids in
            order = HomeHabitsTodayOrder.merged(order, with: ids)
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeHabitMutation)) { _ in viewModel.refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(HomeHabitCopy.sectionTitle)
                    .lifeboardFont(.sectionTitle)
                    .foregroundStyle(palette.color(for: .foreground))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button(HomeHabitCopy.allHabits, action: openBoard)
                    .lifeboardFont(.buttonSmall)
                    .frame(minHeight: 44)
                    .accessibilityHint("Opens all habits")
                    .accessibilityIdentifier("home.habitsToday.board")
            }
            if allHandled {
                Text(HomeHabitCopy.allHandled)
                    .lifeboardFont(.meta)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .transition(.opacity)
                    .accessibilityIdentifier("home.habitsToday.allHandled")
            }
        }
        .animation(MotionProfile.localState.animation(reduceMotion: reduceMotion), value: allHandled)
    }

    private func card(for row: HabitBoardRowPresentation, width: CGFloat?) -> some View {
        let target = viewModel.amountTarget(for: row.habitID)
        return HomeHabitCard(
            row: row,
            kind: viewModel.homeKind(for: row.habitID),
            amountTarget: target,
            amount: viewModel.todayAmounts[row.habitID] ?? 0,
            fixedWidth: width,
            // Opens on Home's own stack, like a task does: the habit is the
            // subject, and Back returns to the day it was tapped from.
            onOpen: { router.navigate(.habitDetail(row.habitID), in: .home) },
            onLog: { change in await log(row: row, change: change) },
            onEnterAmount: target.map { target in
                {
                    amountEntry = HabitAmountEntryContext(
                        habitID: row.habitID,
                        title: row.title,
                        target: target,
                        current: viewModel.todayAmounts[row.habitID] ?? 0
                    )
                }
            },
            onLogSlip: {
                Haptic.pick.play()
                slipCandidate = row
            },
            onUndoSlip: { Task { await undoSlip(row) } }
        )
    }

    private func openBoard() {
        router.navigate(.habitBoard, in: .track)
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

    /// The typed amount goes through the same path as the ring, so crossing
    /// the target celebrates once; anything short of it gets a plain receipt.
    private func setAmount(context: HabitAmountEntryContext, to value: Double) async -> Bool {
        guard let row = viewModel.boardRows.first(where: { $0.habitID == context.habitID }) else { return false }
        let before = viewModel.todayAmounts[row.habitID] ?? 0
        let goal = HabitAmountRule.target(for: context.target) ?? .infinity
        let saved = await viewModel.logAmount(habitID: row.habitID, change: .set(value))
        guard saved else { return false }
        if before < goal, value >= goal {
            await announceCompletion(of: row, previousStreak: row.currentStreak, undo: .amount(before))
        } else {
            receipt = HomeHabitReceipt(
                habitID: row.habitID,
                message: HabitAmountEntry.receipt(title: row.title, value: value, target: context.target),
                undo: .amount(before)
            )
        }
        return true
    }

    private func announceCompletion(of row: HabitBoardRowPresentation, previousStreak: Int, undo: HomeHabitReceipt.Undo) async {
        // The receipt arrives with the save, not after a fixed pause. The board
        // refreshes in the background, so the streak is the one the completion
        // just extended.
        if viewModel.homeKind(for: row.habitID) == .quitCheckIn {
            receipt = HomeHabitReceipt(habitID: row.habitID, message: HomeHabitCopy.stayedCleanReceipt(row.title), undo: undo)
            return
        }
        let note = HabitResilienceCopy.note(
            streak: previousStreak + 1,
            previousStreak: previousStreak,
            recoveredFromLapse: HomeHabitsTodayOrder.isReturnAfterLapse(row.cells)
        )
        receipt = HomeHabitReceipt(
            habitID: row.habitID,
            message: HabitResilienceCopy.receipt(title: row.title, note: note),
            undo: undo
        )
    }

    /// Persistence first, then a quiet haptic and a receipt that can take it
    /// back. A slip is a fact about a day, so nothing here buzzes like failure.
    private func logSlip(_ row: HabitBoardRowPresentation) async {
        slipCandidate = nil
        guard await viewModel.logLapse(habitID: row.habitID) else {
            Haptic.fail.play()
            return
        }
        Haptic.decline.play()
        receipt = HomeHabitReceipt(habitID: row.habitID, message: HomeHabitCopy.slipReceipt(row.title), undo: .slip)
    }

    private func undoSlip(_ row: HabitBoardRowPresentation) async {
        if await viewModel.resetToday(habitID: row.habitID) {
            Haptic.pick.play()
            if receipt?.habitID == row.habitID { receipt = nil }
        } else {
            Haptic.fail.play()
        }
    }

    /// `ReceiptBar` already played the undo haptic and dismissed itself. A
    /// reversal that did not persist says so and keeps Undo within reach.
    private func undo(_ receipt: HomeHabitReceipt) async {
        let undone: Bool
        switch receipt.undo {
        case .checkIn, .slip:
            undone = await viewModel.resetToday(habitID: receipt.habitID)
        case .amount(let before):
            undone = await viewModel.logAmount(habitID: receipt.habitID, change: .set(before))
        }
        guard undone == false else { return }
        Haptic.fail.play()
        self.receipt = HomeHabitReceipt(
            habitID: receipt.habitID,
            message: String(localized: "Couldn’t undo that. Try again."),
            undo: receipt.undo
        )
    }
}

private struct HomeHabitReceipt: Equatable {
    enum Undo: Equatable {
        case checkIn
        case amount(Double)
        case slip
    }

    let id = UUID()
    let habitID: UUID
    let message: String
    let undo: Undo
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
