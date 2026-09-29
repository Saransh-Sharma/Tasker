import SwiftUI
import LifeBoardDomain

/// The ritual row's content, resolved once by `AdaptiveHome`.
struct HomeDayRitual {
    let route: AppRoute
    let title: String
    let subtitle: String
    let symbol: String
    let isEvening: Bool
}

/// The way into the end-of-day ritual, and the morning's read-only echo.
///
/// A section-level affordance rather than a `DashboardWidgetKind`: it is not
/// a readout, it cannot be reordered or pinned, and registering it as a
/// widget would oblige it to render at all five size presets for no benefit.
///
/// Deliberately *not* wired to `DayCompassService`'s `eveningReview` card —
/// that card's only consumer is the legacy Sunrise home, which this shell
/// replaces. Reusing the engine's window predicate and its snooze ledger
/// gives the same tested behaviour without shipping to a screen nobody sees.
struct HomeDayRitualRow: View {
    let ritual: HomeDayRitual?
    let router: AppRouter
    @Binding var dayRitualSnoozeGeneration: Int

    var body: some View {
        if V2FeatureFlags.dayCloseV1Enabled, let ritual {
            Button {
                router.push(ritual.route, in: .home)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: ritual.symbol)
                        .font(.title3)
                        .foregroundStyle(Color(SemanticColorTokens.foundationSunInk))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ritual.title)
                            .font(.headline)
                            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        if ritual.subtitle.isEmpty == false {
                            Text(ritual.subtitle)
                                .font(.caption)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(16)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
            // The ritual grows out of the row you tapped rather than sliding in
            // from the edge as an unrelated screen — it is the same day, opened.
            // Already gated on Reduce Motion, Catalyst and -UI_TESTING inside.
            .lifeBoardTransitionSource(DayLoopTransition.id(for: ritual.route))
            .accessibilityIdentifier("home.dayRitual")
            .contextMenu {
                if ritual.isEvening {
                    Button("Not tonight") {
                        DayCompassSnoozeStore().snoozeUntilEndOfDay(flow: .eveningReview)
                        dayRitualSnoozeGeneration += 1
                    }
                }
            }
            // The snooze was a context menu only; VoiceOver gets it by name.
            .accessibilityActions {
                if ritual.isEvening {
                    Button("Not tonight") {
                        DayCompassSnoozeStore().snoozeUntilEndOfDay(flow: .eveningReview)
                        dayRitualSnoozeGeneration += 1
                    }
                }
            }
        }
    }
}

/// `.repair` states what the day did, and offers a way to answer it.
///
/// Not paired with `nowSection`: the deck already names the work, and
/// restating the same projection twice under one heading reads as two
/// separate asks.
///
/// The copy reports and stops: the deck is an offer, and a person who reads
/// this and does nothing has lost nothing. No count styled as a badge, no
/// red, and none of
/// "missed", "late", "behind" or "overdue": these blocks did not happen when
/// they were planned, which is a fact about a day, not about a person.
struct HomeSpineRepairBody: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let repairStore: PlanStore?
    /// Reported to Home so the loop spine keeps this body mounted while the
    /// applied receipt — and its Undo — is on screen.
    @Binding var receiptIsShowing: Bool
    @State private var phase: HomeRepairPhase = .deck
    /// The last previewed diff, kept after Apply clears the scenario so the
    /// rows can show old → new resolving before they fold into the receipt.
    @State private var stagedDiff: [PlanningScenarioDiff] = []
    @State private var showsResolution = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let count = lifeOSStore.driftCount
        VStack(alignment: .leading, spacing: 12) {
            switch phase {
            case .deck, .staging:
                Text(
                    count == 1
                        ? String(localized: "1 time block didn’t start")
                        : String(localized: "\(count) time blocks didn’t start")
                )
                .font(Typography.body())
                // On the scene, not a card: secondary ink vanished against the
                // night sky, so it flips to the on-scenic ink after dark.
                .nightSkyAwareForeground(
                    Color(SemanticColorTokens.inkSecondary),
                    inverse: Color(SemanticColorTokens.foundationOnScenicDarkSecondary)
                )
                .fixedSize(horizontal: false, vertical: true)

                PlanRepairDeck(
                    proposals: lifeOSStore.repairProposals,
                    // The spine already says "Worth a look"; a second header here
                    // would title the same thing twice.
                    header: nil,
                    // The service's own wording — "this planned block has passed
                    // without a completion receipt" — is a sentence about our data
                    // model, not about the person's day.
                    explanationOverride: String(localized: "Didn’t start as planned")
                ) { action, proposal in
                    choose(action, proposal: proposal)
                }
                .disabled(phase == .staging || repairStore == nil)
                .overlay {
                    if phase == .staging {
                        ProgressView("Loading…")
                            .lifeboardFont(.support)
                    }
                }
            case .preview:
                if let repairStore {
                    // The preview takes the deck's place: one decision on Home,
                    // answered here, with Plan as the quiet way out.
                    PlanMinimumViableDayCard(store: repairStore)
                    Button("Open in Plan") {
                        if let scenario = repairStore.pendingScenario {
                            HomePlanningHandoff.pending = (repairStore.selectedDay, scenario)
                            router.navigate(.planDay, in: .plan)
                        }
                    }
                    .lifeboardFont(.buttonSmall)
                    .frame(minHeight: 44)
                    .accessibilityHint("Opens the day in Plan")
                }
            case .applied:
                if showsResolution {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(stagedDiff) { change in
                            PlanScenarioDiffRow(change: change, isResolved: true)
                        }
                    }
                    .padding(16)
                    .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
                    .transition(.opacity)
                }
                ReceiptBar(
                    ActionReceiptPresentation(
                        message: stagedDiff.count == 1
                            ? (stagedDiff.first?.receipt ?? String(localized: "Plan updated"))
                            : String(localized: "\(stagedDiff.count) changes applied"),
                        detail: stagedDiff.count == 1
                            ? PlanRepairCopy.previousWindowDetail(stagedDiff.first?.before)
                            : nil
                    ),
                    undo: {
                        guard let repairStore else { return }
                        Task {
                            if await repairStore.undoLastMutation() {
                                await lifeOSStore.load()
                            }
                            advance(.undone)
                        }
                    },
                    destination: .init(title: "Open") { router.navigate(.planDay, in: .plan) },
                    onDismiss: { advance(.dismissedReceipt) }
                )
            }
            if let error = repairStore?.errorMessage, phase != .applied {
                Text(error)
                    .lifeboardFont(.support)
                    .nightSkyAwareForeground(
                        Color(SemanticColorTokens.inkPrimary),
                        inverse: Color(SemanticColorTokens.foundationOnScenicDark)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: repairStore?.pendingScenario?.id) { _, scenarioID in
            if let diff = repairStore?.pendingScenario?.diff { stagedDiff = diff }
            // Apply and "Not now" both clear the scenario; the receipt ID is
            // what tells them apart.
            if phase == .preview, scenarioID == nil {
                advance(repairStore?.lastMutationReceiptID != nil ? .applied : .notNow)
            }
        }
        .onDisappear { receiptIsShowing = false }
        // A container: the deck (`plan.repair`), the preview and the receipt
        // inside keep their own identifiers instead of inheriting this one.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.loopSpine.repair.body")
    }

    private func choose(_ action: PlanRepairAction, proposal: PlanRepairProposal?) {
        guard let repairStore, phase == .deck else { return }
        if action == .askEva {
            // Eva with context is a sheet about today, not a trip to the
            // empty Eva root.
            Haptic.pick.play()
            router.presentEva(context: EvaLaunchContext(kind: .day, date: Date()), prompt: nil)
            return
        }
        Haptic.pick.play()
        advance(.chose)
        Task { @MainActor in
            await repairStore.load()
            if let proposal { repairStore.previewRepair(proposal, action: action) }
            else { repairStore.previewMinimumViableDay() }
            if let scenario = repairStore.pendingScenario {
                stagedDiff = scenario.diff
                advance(.staged)
            } else {
                advance(.stagingFailed)
            }
        }
    }

    private func advance(_ event: HomeRepairPhase.Event) {
        let next = phase.next(event)
        guard next != phase else { return }
        if next == .applied {
            // The commit haptic is the preview card's, played once the apply
            // has persisted. Show old → new resolving, then fold into the
            // one-line receipt inside `DESIGN.md`'s ~800 ms signature budget.
            showsResolution = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 700))
                withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                    showsResolution = false
                }
                await lifeOSStore.load()
            }
        }
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            phase = next
        }
        receiptIsShowing = next == .applied
    }
}

/// Home's in-place repair, as a value: the deck, a preview being prepared, the
/// preview awaiting an answer, and the applied receipt. Every transition not
/// listed is ignored, so a late event (a second tap, a stale apply) can never
/// skip the preview or resurrect a dismissed receipt.
enum HomeRepairPhase: Equatable {
    case deck
    case staging
    case preview
    case applied

    enum Event {
        case chose, staged, stagingFailed, notNow, applied, undone, dismissedReceipt
    }

    func next(_ event: Event) -> HomeRepairPhase {
        switch (self, event) {
        case (.deck, .chose): .staging
        case (.staging, .staged): .preview
        case (.staging, .stagingFailed): .deck
        case (.preview, .notNow): .deck
        case (.preview, .applied): .applied
        case (.applied, .undone), (.applied, .dismissedReceipt): .deck
        default: self
        }
    }
}

/// `.rest` asks for nothing.
///
/// Closing a day must not open a new obligation, so this states the fact and
/// stops. No CTA, no next step, no offer to plan tomorrow.
struct HomeSpineRestBody: View {
    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            // The day, closed — the same ring from the ritual, small and
            // finished. Its completion mark is already drawn at closedProgress 1,
            // so this is a record rather than a second celebration.
            DayRing(
                plannedMinutes: nil,
                focusedMinutes: nil,
                closedProgress: 1,
                diameter: 64
            )
            .accessibilityHidden(true)

            Text("Nothing more today.")
                .font(Typography.body())
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        // Arrives, settles, and stops. A closed day must not shimmer, so there
        // is deliberately no TimelineView, no repeatForever, and no CTA — the
        // whole point of `.rest` is that it asks for nothing.
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day closed. Nothing more today.")
        .accessibilityIdentifier("home.loopSpine.rest")
    }
}
/// The loop-spine stage and the ritual door, as pure functions of the day's
/// recorded state. Home reads its own `@State` into these; nothing here
/// reaches back into Home.
enum HomeDayLoopResolution {
    /// Loop state first, clock second — see `DayLoopStageResolver`. `.repair`
    /// arrives through the drift count and is held while its receipt is on
    /// screen (`holdsRepair`).
    static func stage(
        closedToday: Bool,
        openedToday: Bool,
        driftCount: Int,
        suppressesRepair: Bool,
        holdsRepair: Bool,
        now: Date
    ) -> DayLoopStage {

        let engine = DayCompassService()
        let calendar = Calendar.current

        #if DEBUG
        // The morning and evening windows leave the ritual unreachable for most
        // of the working day, which would force a seeded journey to either
        // mutate the device clock or wait until 18:00. Neither is a
        // condition-based wait, so the stage is forceable in Debug only.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-LIFEBOARD_FORCE_DAY_CLOSE") { return .close }
        if arguments.contains("-LIFEBOARD_FORCE_DAY_OPEN") { return .commit }
        // Repair needs two drifted blocks that are both over 15 minutes old,
        // which a seeded journey cannot arrange without waiting out the clock.
        if arguments.contains("-LIFEBOARD_FORCE_DAY_REPAIR") { return .repair }
        #endif

        let resolved = DayLoopStageResolver.resolve(
            closedToday: closedToday,
            openedToday: openedToday,
            isMorningWindow: engine.isMorningPlanWindow(now, calendar: calendar),
            isEveningWindow: engine.isEveningReviewWindow(now, calendar: calendar),
            // Already filtered by `PlanDriftPolicy`: one slipped block is a
            // normal day and stays at 0, so this only rises when the day has a
            // shape worth looking at.
            driftCount: driftCount,
            // Low Energy changes the spine's *stage set*, not its visibility.
            // Repair is the one stage that asks something extra of a day already
            // going badly, so it is the one Low Energy drops.
            suppressesRepair: suppressesRepair
        )
        // Applying a repair is exactly what makes the drift disappear, so the
        // resolver's honest answer right after Apply is `.act`. Holding
        // `.repair` until the receipt is dismissed is what lets the person
        // read the receipt and press Undo where they made the change.
        if holdsRepair, resolved == .act { return .repair }
        return resolved
    
    }

    /// The ritual row, or `nil` when the day is already closed or the evening
    /// offer was snoozed.
    ///
    /// The door is open at every stage except `.rest`. Previously it existed
    /// only between 05:00–11:00 and 18:00–midnight, so a day finished early —
    /// or a day whose owner works nights — had nowhere to put it down.
    static func ritual(for stage: DayLoopStage, now: Date) -> HomeDayRitual? {

        guard stage.offersClose else { return nil }

        if stage == .commit {
            return HomeDayRitual(
                route: .dayOpen(now),
                // One name for the morning ritual: its own title says the same.
                title: String(localized: "Start the day"),
                // No subtitle: the title already names the ritual, and a line
                // describing it restated the same thing.
                subtitle: "",
                symbol: "sunrise",
                isEvening: false
            )
        }

        let snoozes = DayCompassSnoozeStore().load(now: now, calendar: .current)
        guard snoozes.isSnoozed(.eveningReview, at: now) == false else { return nil }
        return HomeDayRitual(
            route: .dayClose(now),
            // Matches the wording already shipped in `DayCompassCard` rather
            // than inventing a second voice for the same moment.
            title: String(localized: "Close the day"),
            // No subtitle, before evening or after: the title is the whole
            // offer, and nothing here implies the day is over or late.
            subtitle: "",
            symbol: "moon.stars",
            isEvening: stage == .close
        )
    
    }
}
