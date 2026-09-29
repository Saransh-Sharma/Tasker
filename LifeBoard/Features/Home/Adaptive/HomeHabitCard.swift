import SwiftUI
import LifeBoardDomain

/// One habit on Home: its ring in the habit's own colour, its whole name, and
/// one line of state.
///
/// Replaces a 76 pt ring tile that cut every name to a word, drew every habit
/// in the same sage, and said "Hold" to a quit habit. The colour deepens with
/// the streak on the same ramp the Board and Habit Detail use, so a habit
/// looks the same everywhere it appears.
struct HomeHabitCard: View {
    static let width: CGFloat = 164

    let row: HabitBoardRowPresentation
    let kind: HomeHabitKind
    let amountTarget: HabitTarget?
    let amount: Double
    /// `nil` fills the offered width: the stacked layout at accessibility sizes.
    var fixedWidth: CGFloat? = HomeHabitCard.width
    let onOpen: () -> Void
    let onLog: (HabitAmountChange) async -> Bool
    var onEnterAmount: (() -> Void)?
    let onLogSlip: () -> Void
    let onUndoSlip: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var firstLightTrigger = 0

    private var slippedToday: Bool {
        guard kind == .quitLapseOnly, let today = row.cells.last(where: \.isToday) else { return false }
        if case .missed = today.state { return true }
        return false
    }

    private var amountReading: HomeHabitCopy.Amount? {
        guard let amountTarget, let goal = HabitAmountRule.target(for: amountTarget) else { return nil }
        let unit: String = { if case let .quantitative(_, unit) = amountTarget { return unit }; return "" }()
        let isTimed: Bool = { if case .timed = amountTarget { return true }; return false }()
        return .init(value: amount, target: goal, unit: unit, isTimed: isTimed)
    }

    private var status: String {
        HomeHabitCopy.status(
            kind: kind,
            isDoneToday: row.isDoneToday,
            slippedToday: slippedToday,
            cleanDays: row.currentStreak,
            amount: amountReading
        )
    }

    private var depth: Int { HomeHabitCopy.shadeDepth(streak: row.currentStreak) }

    /// The habit's colour at its streak's depth; a slip reads neutral, never red.
    private var tint: Color {
        if slippedToday { return Color(SemanticColorTokens.inkTertiary) }
        return HabitEverydayPalette.depthColor(for: row.colorFamily, depth: depth, colorScheme: colorScheme)
    }

    /// Light ink on the deeper half of the ramp, as Habit Detail does.
    private var markTint: Color {
        depth >= 5 ? Color.lifeboard(.textInverse) : Color(SemanticColorTokens.inkPrimary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                ring
                Spacer(minLength: 4)
                badge
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .lifeboardFont(.support)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    // Three lines with the space reserved, so a real name
                    // ("Choose tomorrow's top priority before bed") reads whole
                    // and cards in a row still align; the stacked layout at
                    // accessibility sizes never truncates.
                    .modifier(ReservedLines(count: 3, unlimited: dynamicTypeSize.isAccessibilitySize))
                    .fixedSize(horizontal: false, vertical: true)
                Text(status)
                    .lifeboardFont(.meta)
                    .monospacedDigit()
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    // Two lines reserved: "Slip logged today"
                    // and "8 of 8 glasses · done" never change a card's height.
                    .modifier(ReservedLines(count: 2, unlimited: dynamicTypeSize.isAccessibilitySize))
                    .contentTransition(.numericText())
                    .accessibilityHidden(true)
            }
            // The day's first completion lights the words of the card it
            // happened on. Text only: the sweep re-identifies what it wraps,
            // and the ring beside it holds gesture state.
            .lifeboardFirstLight(trigger: firstLightTrigger, tint: Color(SemanticColorTokens.foundationSunAccent))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            // The menu lives on the words, never on the ring: a context menu's
            // own long press would cut a hold short half-way through.
            .contextMenu { menu }
        }
        .padding(12)
        .frame(width: fixedWidth, alignment: .topLeading)
        .frame(maxWidth: fixedWidth == nil ? .infinity : nil, alignment: .topLeading)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        // The whole card opens the habit; the ring keeps its own tap and hold.
        .onTapGesture(perform: onOpen)
        .hoverableCard(cornerRadius: Radius.card)
        .onReceive(NotificationCenter.default.publisher(for: .lifeboardFirstLightFired)) { notification in
            guard FirstLightCommitment.source(of: notification) == .habit,
                  notification.userInfo?["habitID"] as? String == row.habitID.uuidString else { return }
            firstLightTrigger &+= 1
        }
        .animation(MotionProfile.localState.animation(reduceMotion: false), value: status)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.habitsToday.card.\(row.habitID.uuidString)")
    }

    // MARK: Ring

    @ViewBuilder
    private var ring: some View {
        Group {
            switch kind {
            case .buildAmount:
                if let amountTarget, let reading = amountReading {
                    HabitProgressRing(
                        title: row.title,
                        value: reading.value,
                        target: reading.target,
                        step: HabitAmountRule.step(for: amountTarget),
                        unit: reading.unit,
                        isTimed: reading.isTimed,
                        size: .card,
                        tint: tint,
                        completedMarkTint: markTint,
                        onChange: onLog
                    )
                }
            case .buildCheckIn, .quitCheckIn:
                HabitProgressRing(
                    title: row.title,
                    value: row.isDoneToday ? 1 : 0,
                    target: 1,
                    step: 1,
                    unit: "",
                    isTimed: false,
                    size: .card,
                    tapBehavior: .perform(onOpen),
                    showsCount: false,
                    tint: tint,
                    completedMarkTint: markTint,
                    centerSymbol: kind == .quitCheckIn ? "shield.lefthalf.filled" : row.iconSymbolName,
                    onChange: onLog
                )
            case .quitLapseOnly:
                // Clean by default: the ring is full and never asks for a
                // hold. A slip is recorded from the menu, with a confirmation.
                HabitProgressRing(
                    title: row.title,
                    value: slippedToday ? 0 : 1,
                    target: 1,
                    step: 1,
                    unit: "",
                    isTimed: false,
                    size: .card,
                    tapBehavior: .perform(onOpen),
                    showsCount: false,
                    tint: tint,
                    centerSymbol: "shield.lefthalf.filled",
                    holdEnabled: false,
                    showsCompletionDisc: false,
                    onChange: { _ in true }
                )
            }
        }
        .accessibilityValue(ringAccessibilityValue)
        .accessibilityHint(ringAccessibilityHint)
        .accessibilityAction(named: "Open habit", onOpen)
        .modifier(HomeHabitSlipActions(kind: kind, slippedToday: slippedToday, onLogSlip: onLogSlip, onUndoSlip: onUndoSlip))
        .accessibilityIdentifier("home.habitsToday.ring.\(row.habitID.uuidString)")
    }

    /// Check-ins and amounts keep the values the ring has always reported;
    /// quit habits say what their ring actually means.
    private var ringAccessibilityValue: String {
        switch kind {
        case .buildAmount:
            return amountReading.map {
                HabitRingGeometry.accessibilityValue(value: $0.value, target: $0.target, unit: $0.unit, isTimed: $0.isTimed)
            } ?? (row.isDoneToday ? "Done" : "Not done")
        case .buildCheckIn:
            return row.isDoneToday ? "Done" : "Not done"
        case .quitCheckIn:
            return row.isDoneToday ? "Stayed clean today" : "Not confirmed yet"
        case .quitLapseOnly:
            return status
        }
    }

    private var ringAccessibilityHint: String {
        var parts: [String] = []
        if HomeHabitCopy.showsStreakBadge(kind: kind, streak: row.currentStreak) {
            parts.append(HomeHabitCopy.streakAccessibility(row.currentStreak))
        }
        switch kind {
        case .buildCheckIn where row.isDoneToday == false: parts.append("Hold to mark done")
        case .quitCheckIn where row.isDoneToday == false: parts.append("Hold if you stayed clean")
        case .buildAmount: parts.append("Tap to add a step, hold to finish")
        default: break
        }
        return parts.joined(separator: ". ")
    }

    // MARK: Badge and menu

    @ViewBuilder
    private var badge: some View {
        HStack(spacing: 4) {
            if kind == .buildAmount {
                Image(systemName: row.iconSymbolName)
                    .foregroundStyle(tint)
            }
            if HomeHabitCopy.showsStreakBadge(kind: kind, streak: row.currentStreak) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(tint)
                Text("\(row.currentStreak)")
                    .monospacedDigit()
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .contentTransition(.numericText())
            }
        }
        .lifeboardFont(.meta)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var menu: some View {
        Button("Open habit", systemImage: "arrow.up.right.square", action: onOpen)
        switch kind {
        case .buildAmount:
            if let onEnterAmount {
                Button("Enter amount…", systemImage: "number", action: onEnterAmount)
            }
            // Completing used to need a press-and-hold on the ring — a gesture a
            // mouse, a trackpad click or a keyboard cannot make.
            if let amountTarget, let goal = HabitAmountRule.target(for: amountTarget), amount < goal {
                Button("Finish", systemImage: "checkmark.circle") {
                    Task { _ = await onLog(.set(goal)) }
                }
            }
            if let amountTarget, amount > 0 {
                let step = HabitAmountRule.step(for: amountTarget)
                Button("Undo last step", systemImage: "arrow.uturn.backward") {
                    Task { _ = await onLog(.add(-step)) }
                }
            }
        case .buildCheckIn, .quitCheckIn:
            if row.isDoneToday {
                Button(kind == .quitCheckIn ? "Clear today" : "Mark not done", systemImage: "arrow.uturn.backward") {
                    Task { _ = await onLog(.set(0)) }
                }
            } else {
                Button(kind == .quitCheckIn ? "Check in" : "Mark done", systemImage: "checkmark.circle") {
                    Task { _ = await onLog(.set(1)) }
                }
            }
        case .quitLapseOnly:
            if slippedToday {
                Button(HomeHabitCopy.undoSlip, systemImage: "arrow.uturn.backward", action: onUndoSlip)
            } else {
                Button(HomeHabitCopy.logSlip, systemImage: "arrow.uturn.backward.circle", action: onLogSlip)
            }
        }
    }
}

/// A fixed number of lines with the space reserved, or no limit at all.
private struct ReservedLines: ViewModifier {
    let count: Int
    let unlimited: Bool

    func body(content: Content) -> some View {
        if unlimited {
            content.lineLimit(nil)
        } else {
            content.lineLimit(count, reservesSpace: true)
        }
    }
}

/// VoiceOver's way to log or undo a slip, which sighted people reach through
/// the card's menu.
private struct HomeHabitSlipActions: ViewModifier {
    let kind: HomeHabitKind
    let slippedToday: Bool
    let onLogSlip: () -> Void
    let onUndoSlip: () -> Void

    func body(content: Content) -> some View {
        if kind == .quitLapseOnly {
            content
                .accessibilityAction(named: slippedToday ? HomeHabitCopy.undoSlip : "Log a slip") {
                    slippedToday ? onUndoSlip() : onLogSlip()
                }
        } else {
            content
        }
    }
}

/// The row's last stop: the Board, where every habit and its history live.
struct HomeHabitsAllHabitsCard: View {
    var fixedWidth: CGFloat? = 108
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "arrow.right")
                    .lifeboardFont(.headline)
                Spacer(minLength: 0)
                Text(HomeHabitCopy.allHabits)
                    .lifeboardFont(.support)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            .padding(12)
            .frame(width: fixedWidth, alignment: .topLeading)
            .frame(maxWidth: fixedWidth == nil ? .infinity : nil, minHeight: 44, maxHeight: fixedWidth == nil ? nil : .infinity, alignment: .topLeading)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    // Visible against paper at every daypart: the hairline
                    // token disappeared on the evening wash.
                    .strokeBorder(Color(SemanticColorTokens.inkTertiary).opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens all habits")
        .accessibilityIdentifier("home.habitsToday.allHabits")
    }
}
