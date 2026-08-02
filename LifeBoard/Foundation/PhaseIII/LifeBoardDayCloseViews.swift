import SwiftUI

/// Which end of the day this surface is for.
public enum DayCloseMode: String, Sendable {
    /// The evening ritual: reconcile, reflect, anchor, close.
    case close
    /// The morning counterpart. Read-only — it reports what last night decided
    /// and never mutates, so there is nothing here to undo.
    case open
}

/// Close the Day.
///
/// Five beats on one scroll rather than a wizard: a person ending their day
/// should be able to see the whole thing at once and stop wherever they like.
/// Paging would make "I only wanted to write the line" into four taps.
struct LifeBoardDayCloseRoute: View {
    let mode: DayCloseMode
    @State private var store: DayCloseStore
    private let reflections: (any ReflectionNoteRepositoryProtocol)?
    private let onFinished: () -> Void

    @State private var energy = 3
    @State private var note = ""
    @State private var reflectionPhase: AsyncActionPhase<UUID> = .idle
    @State private var closeTrigger = 0
    /// Advanced once when the morning commit lands, driving the light sweep.
    @State private var firstLightTrigger = 0
    @State private var releaseDissolve: Double = 0
    @Namespace private var anchorNamespace

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        store: DayCloseStore,
        mode: DayCloseMode,
        reflections: (any ReflectionNoteRepositoryProtocol)?,
        onFinished: @escaping () -> Void
    ) {
        _store = State(initialValue: store)
        self.mode = mode
        self.reflections = reflections
        self.onFinished = onFinished
    }

    private var reflectionSaved: Bool {
        if case .success = reflectionPhase { return true }
        return false
    }

    private var hasUnsavedNote: Bool {
        note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && reflectionSaved == false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                switch store.loadState {
                case .loading:
                    loadingLanes
                case let .failed(message):
                    failure(message)
                case .ready, .empty:
                    ribbonAct
                    if mode == .close {
                        // A thread beside the acts, not a step indicator: the
                        // ritual stays one scroll, but you can see how much of
                        // it is left before you start.
                        actThread(reconcileAct, reflectAct, anchorAct, closeAct)
                    } else {
                        // Commit first: the morning's job is to agree to a day,
                        // and the retrospective is context for that decision
                        // rather than the point of the screen.
                        if V2FeatureFlags.dayOpenCommitV1Enabled { commitAct }
                        carriedSummary
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(alignment: .top) { backdrop }
        .navigationTitle(mode == .close ? "Close the day" : "Today")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("dayClose.root")
        .task { await store.load() }
        // The one-shot night handoff. Its documented role, and the reason no new
        // shader was needed for the closing moment.
        .lifeboardDaypartCrossDissolve(trigger: closeTrigger, daypart: .night)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Color(LifeBoardColorTokens.foundationCanvas)
            .lifeboardPaperGrain()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    // MARK: - Loading and failure

    /// Skeleton lanes that occupy the ribbon's real geometry rather than
    /// covering it, so the content does not jump when it lands.
    private var loadingLanes: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(LifeBoardColorTokens.metricRingTrack))
                    .frame(height: 18)
            }
        }
        .dayCloseCard()
        .accessibilityLabel("Loading your day")
    }

    /// Deliberately unlike the empty state: a day we could not read must never
    /// look like a day that was clear.
    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("The day's shape couldn't be loaded", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again") { Task { await store.load() } }
                .buttonStyle(.lifeBoardPrimary)
        }
        .accessibilityIdentifier("dayClose.load.failed")
    }

    // MARK: - Act 1 — the ribbon

    @ViewBuilder
    private var ribbonAct: some View {
        if let ribbon = store.ribbon {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(DayCloseAct.ribbon.title)

                HStack(alignment: .center, spacing: 20) {
                    LifeBoardDayRing(
                        plannedMinutes: ribbon.summary.plannedMinutes,
                        focusedMinutes: ribbon.summary.focusedMinutes,
                        closedProgress: store.alreadyClosed ? 1 : 0,
                        // Rises as cards are decided, so the ring at the top of
                        // the ritual answers to the deck at the bottom of it.
                        settledLevel: store.reconciliationProgress
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        factLine("\(ribbon.summary.completedCount) finished")
                        factLine("\(ribbon.summary.unfinishedCount) still open")
                        if ribbon.externalCalendarUnavailable {
                            // Absent data is never reported as a confident
                            // value: this says we did not look, not that the
                            // calendar was clear.
                            factLine("External calendar isn't connected")
                        }
                    }
                }

                if ribbon.segments.isEmpty {
                    Text("Nothing was scheduled today.")
                        .font(LifeBoardFoundationTypography.body())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                } else {
                    DayCloseRibbonStrip(ribbon: ribbon)
                }
            }
            .dayCloseCard()
            .accessibilityIdentifier("dayClose.ribbon")
        }
    }

    private func factLine(_ text: String) -> some View {
        Text(text)
            .font(LifeBoardFoundationTypography.metric())
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
    }

    // MARK: - Act 2 — reconcile

    @ViewBuilder
    private var reconcileAct: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(DayCloseAct.reconcile.title)

            if let card = store.currentCard {
                LifeBoardDirectionalDeck(
                    // The whole remaining queue, not just the front card: the
                    // deck draws one card but sizes its stack from the count.
                    items: store.remainingCards,
                    candidates: { _ in DayCloseDirection.allCases },
                    actionLabel: { $0.accessibilityLabel(for: card.title) },
                    onCommit: { task, direction in
                        store.record(direction, for: task.id)
                        // Selection, not success: nothing is persisted until the
                        // day is closed, and the design contract puts a
                        // persisted-state boundary before success feedback.
                        LifeBoardHaptic.pick.play()
                    },
                    card: { task, armed in
                        DayCloseCard(task: task, armedDirection: armed)
                    }
                )
                .accessibilityIdentifier("dayClose.deck")

                DayCloseDirectionPad(armed: nil) { direction in
                    store.record(direction, for: card.id)
                    LifeBoardHaptic.pick.play()
                }

                HStack(spacing: 4) {
                    // Rolls rather than swapping: the count is the one number
                    // that changes on every decision, and a hard cut makes the
                    // deck feel like it is resetting rather than advancing.
                    LifeBoardNumericRoll(value: Double(store.remainingCount))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    Text("left")
                        .font(LifeBoardFoundationTypography.metadata())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    Spacer()
                    if store.decisionOrder.isEmpty == false {
                        Button("Bring back the last card") {
                            store.bringBackLastCard()
                            LifeBoardHaptic.lift.play()
                        }
                        .font(LifeBoardFoundationTypography.metric())
                        .accessibilityIdentifier("dayClose.deck.bringBack")
                    }
                }
            } else {
                everythingSettled
            }

            if store.staleTaskIDs.isEmpty == false {
                staleNotice
            }
        }
        .dayCloseCard()
        .lifeBoardMotion(.cardReflow, value: store.decidedCount)
    }

    /// Lays the four close acts out with a progress thread down their left.
    @ViewBuilder
    private func actThread(
        _ reconcile: some View,
        _ reflect: some View,
        _ anchor: some View,
        _ close: some View
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            LifeBoardActThread(progress: actProgress)
                .stroke(
                    Color(LifeBoardColorTokens.foundationSunAccent).opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 2)
                .background(alignment: .top) {
                    // The unfilled remainder, so the thread reads as a length
                    // you are moving along rather than a bar that grows.
                    Capsule()
                        .fill(Color(LifeBoardColorTokens.foundationHairline))
                        .frame(width: 2)
                }
                .lifeBoardMotion(.threadAdvance, value: actProgress)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 28) {
                reconcile
                reflect
                anchor
                close
            }
        }
    }

    /// How far through the evening's four acts this is.
    ///
    /// Each act counts once and only when it is genuinely settled — a saved
    /// note, a chosen anchor. Deliberately not "how far you have scrolled":
    /// scrolling past the reflection without writing one has not settled it.
    private var actProgress: Double {
        var settled = 0.0
        if store.remainingCount == 0 { settled += 1 }
        if reflectionSaved { settled += 1 }
        if store.anchorTaskID != nil { settled += 1 }
        if store.alreadyClosed { settled += 1 }
        return settled / 4
    }

    /// An empty deck is a **success**, and must not read as a void. A filled,
    /// warm card — never a `ContentUnavailableView`, which is what a failure
    /// looks like here.
    private var everythingSettled: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                store.decidedCount > 0 ? "Everything is settled." : "Everything you committed to is done.",
                systemImage: "checkmark.seal"
            )
            .font(LifeBoardFoundationTypography.sectionTitle())
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            if store.summaryLines.isEmpty == false {
                ForEach(store.summaryLines, id: \.self) { line in
                    Text(line)
                        .font(LifeBoardFoundationTypography.metric())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("dayClose.deck.settled")
    }

    private var staleNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your plan changed while this was open.")
                .font(LifeBoardFoundationTypography.metric())
            Button("Review again") { Task { await store.reviewAfterConflict() } }
                .buttonStyle(.lifeBoardChip)
        }
        .accessibilityIdentifier("dayClose.conflict")
    }

    // MARK: - Act 3 — one line

    private var reflectAct: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(DayCloseAct.reflect.title)

            Picker("Energy at the end of the day", selection: $energy) {
                ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityValue("\(energy) out of 5")

            TextField("Anything worth remembering?", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("dayClose.reflection.note")

            LifeBoardCommitControl(
                title: "Save this line",
                runningTitle: "Saving…",
                successTitle: "Saved",
                phase: reflectionPhase
            ) {
                Task { await saveReflection() }
            }
            .accessibilityIdentifier("dayClose.reflection.commit")
            .disabled(reflections == nil)

            if reflections == nil {
                Text("Notes can't be saved right now. The rest of the day still closes.")
                    .font(LifeBoardFoundationTypography.metadata())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
        }
        .dayCloseCard()
    }

    private func saveReflection() async {
        guard let reflections else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        // Energy alone is a valid record. A day someone had no words for is
        // still a day worth keeping.
        let entry = ReflectionNote(
            id: UUID(),
            kind: .dayClose,
            energy: energy,
            // Stored empty rather than skipped: the energy rating is the record,
            // and a day someone had no words for is still a day worth keeping.
            noteText: trimmed,
            createdAt: Date()
        )
        reflectionPhase = .running(progress: nil)
        let result: Result<ReflectionNote, Error> = await withCheckedContinuation { continuation in
            reflections.saveNote(entry) { continuation.resume(returning: $0) }
        }
        switch result {
        case let .success(saved):
            reflectionPhase = .success(receipt: saved.id)
            LifeBoardHaptic.commit.play()
        case let .failure(error):
            // Keeps the text mounted. Losing what someone just wrote because a
            // save failed is the worst outcome available here.
            reflectionPhase = .recoverableFailure(
                AsyncActionFailure(message: error.localizedDescription, recovery: .retry)
            )
        }
    }

    // MARK: - Act 4 — tomorrow's first thing

    @ViewBuilder
    private var anchorAct: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(DayCloseAct.anchor.title)

            if store.anchorCandidates.isEmpty {
                // Not an error, not a nag.
                Text("Nothing to anchor tomorrow yet.")
                    .font(LifeBoardFoundationTypography.body())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                ForEach(store.anchorCandidates) { candidate in
                    anchorRow(candidate)
                }
            }
        }
        .dayCloseCard()
        .lifeBoardMotion(.controlMorph, value: store.anchorTaskID)
        .accessibilityIdentifier("dayClose.anchor")
    }

    private func anchorRow(_ candidate: PlanningTaskSummary) -> some View {
        let isAnchor = store.anchorTaskID == candidate.id
        return Button {
            store.setAnchor(isAnchor ? nil : candidate.id)
            LifeBoardHaptic.pick.play()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isAnchor ? "sunrise.fill" : "circle")
                    .foregroundStyle(
                        isAnchor
                            ? Color(LifeBoardColorTokens.foundationSunAccent)
                            : Color(LifeBoardColorTokens.inkTertiary)
                    )
                    // The geometry carries the meaning: the chosen task's marker
                    // travels to the anchor slot rather than one icon fading out
                    // while another fades in somewhere else.
                    .matchedGeometryEffect(
                        id: isAnchor ? "dayClose.anchor.marker" : "dayClose.anchor.\(candidate.id)",
                        in: anchorNamespace,
                        isSource: isAnchor
                    )
                Text(candidate.title)
                    .font(LifeBoardFoundationTypography.body())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isAnchor ? [.isSelected] : [])
        .accessibilityIdentifier("dayClose.anchor.\(candidate.id.uuidString)")
    }

    // MARK: - Act 5 — close

    private var closeAct: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.alreadyClosed, let closedAt = store.closedAt {
                Text("You closed this day at \(closedAt.formatted(date: .omitted, time: .shortened)).")
                    .font(LifeBoardFoundationTypography.body())
                Button("Undo") {
                    Task {
                        await store.undoClose()
                        // The release dissolve is a one-shot that ran on close.
                        // Without this reset it stays fully eroded, so reopening
                        // the day shows an empty summary block where the
                        // decisions should be — they are still pending, just
                        // invisible.
                        releaseDissolve = 0
                    }
                }
                .buttonStyle(.lifeBoardChip)
                .accessibilityIdentifier("dayClose.undo")
                // Stated plainly, because the two writes really are separate and
                // pretending otherwise would be the lie.
                Text("Undo puts your tasks back. Your note stays.")
                    .font(LifeBoardFoundationTypography.metadata())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Button("Done") { onFinished() }
                    .buttonStyle(.lifeBoardPrimary)
            } else {
                ForEach(store.summary) { line in
                    Text(line.text)
                        .font(LifeBoardFoundationTypography.metric())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        // Released rows erode rather than fade — the effect's
                        // documented role, applied to the nearest true meaning.
                        // Scoped to `.release`: this ran over every line, so
                        // work that was *carried to tomorrow* also eroded, which
                        // says the opposite of what happened to it.
                        .lifeboardDissolveAway(
                            progress: line.direction == .release ? releaseDissolve : 0,
                            tint: Color(LifeBoardColorTokens.foundationApricotAccent)
                        )
                        // The other half of `.doneAnyway`'s vocabulary. The card
                        // only settles while armed; the burst is success
                        // feedback, so it waits for `store.close()` to land and
                        // fires here, on the line that records it, because by
                        // commit time the card itself is long gone.
                        .lifeboardCompletionBurst(
                            trigger: line.direction == .doneAnyway ? closeTrigger : 0
                        )
                }

                if hasUnsavedNote {
                    Text("Your line isn't saved yet. Save it, or close and keep just the plan changes.")
                        .font(LifeBoardFoundationTypography.metadata())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .accessibilityIdentifier("dayClose.unsavedNote")
                }

                LifeBoardCommitControl(
                    title: "Close the day",
                    runningTitle: "Closing…",
                    successTitle: "Closed",
                    phase: store.applyPhase
                ) {
                    Task {
                        await store.close()
                        if case .success = store.applyPhase {
                            closeTrigger += 1
                            LifeBoardHaptic.commit.play()
                            withAnimation(
                                LifeBoardMotionProfile.celebration.animation(reduceMotion: reduceMotion)
                            ) { releaseDissolve = 1 }
                        }
                    }
                }
                .accessibilityIdentifier("dayClose.commit")
            }
        }
        .dayCloseCard()
    }

    // MARK: - Morning variant

    /// The morning's whole point: agree with a day that has already been
    /// computed. Editing is available and secondary.
    @ViewBuilder
    private var commitAct: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Today")

            if store.alreadyCommitted {
                Label("Today is set.", systemImage: "checkmark.seal")
                    .font(LifeBoardFoundationTypography.sectionTitle())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                Button("Undo") { Task { await store.undoOpen() } }
                    .buttonStyle(.lifeBoardChip)
                    .accessibilityIdentifier("dayOpen.undo")
            } else if store.openProposal.isEmpty {
                Text("Nothing is waiting. Today is yours to shape.")
                    .font(LifeBoardFoundationTypography.body())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                LifeBoardCommitControl(
                    title: "Start with a clear day",
                    runningTitle: "Setting today…",
                    successTitle: "Today is set",
                    phase: store.openCommitPhase
                ) {
                    Task {
                        await store.commitOpen()
                        // The boundary: the sweep and the haptic wait for the
                        // receipt, not for the tap.
                        if store.alreadyCommitted {
                            firstLightTrigger += 1
                            LifeBoardHaptic.commit.play()
                        }
                    }
                }
                .accessibilityIdentifier("dayOpen.commit")
            } else {
                ForEach(Array(store.openProposal.enumerated()), id: \.element.id) { index, candidate in
                    proposalRow(candidate)
                        // Loose until committed, then square.
                        //
                        // The morning act is agreeing to a shape for the day, so
                        // the proposal arrives as a set of loose possibilities
                        // and settles into an ordered list at the moment you say
                        // yes. Chaos to intention, which is what the act means.
                        .offset(
                            x: store.alreadyCommitted ? 0 : proposalLean(index),
                            y: 0
                        )
                        .rotationEffect(
                            .degrees(store.alreadyCommitted ? 0 : proposalLean(index) * 0.22)
                        )
                }
                LifeBoardCommitControl(
                    title: "Yes, start with this",
                    runningTitle: "Setting today…",
                    successTitle: "Today is set",
                    phase: store.openCommitPhase
                ) {
                    Task {
                        await store.commitOpen()
                        // The boundary: the sweep and the haptic wait for the
                        // receipt, not for the tap.
                        if store.alreadyCommitted {
                            firstLightTrigger += 1
                            LifeBoardHaptic.commit.play()
                        }
                    }
                }
                .accessibilityIdentifier("dayOpen.commit")
                Text("Tap any line to leave it out.")
                    .font(LifeBoardFoundationTypography.metadata())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
        }
        .dayCloseCard()
        .lifeBoardMotion(.controlMorph, value: store.openSelection.count)
        .lifeBoardMotion(.firstLight, value: store.alreadyCommitted)
        // One warm sweep across the committed day. Fires on the persisted-state
        // boundary — never on selection, which would promise something the
        // ledger has not been told yet.
        .lifeboardFirstLight(
            trigger: firstLightTrigger,
            tint: Color(LifeBoardColorTokens.foundationSunAccent)
        )
        .accessibilityIdentifier("dayOpen.commitAct")
    }

    /// Deterministic per-row lean, so the loose stack does not reshuffle itself
    /// on every re-render. Small enough to read as "not yet filed" rather than
    /// as a layout bug.
    private func proposalLean(_ index: Int) -> CGFloat {
        let magnitudes: [CGFloat] = [6, -4, 9, -7, 3]
        return magnitudes[index % magnitudes.count]
    }

    private func proposalRow(_ candidate: DayOpenCandidate) -> some View {
        let isSelected = store.openSelection.contains(candidate.id)
        return Button {
            store.toggleOpenSelection(candidate.id)
            LifeBoardHaptic.pick.play()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isSelected
                            ? Color(LifeBoardColorTokens.foundationSunAccent)
                            : Color(LifeBoardColorTokens.inkTertiary)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.task.title)
                        .font(LifeBoardFoundationTypography.body())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                    if candidate.origin == .anchor {
                        Text("You chose this last night")
                            .font(LifeBoardFoundationTypography.metadata())
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("dayOpen.proposal.\(candidate.id.uuidString)")
    }

    @ViewBuilder
    private var carriedSummary: some View {
        // The anchor first and named, because it is the one thing a person
        // deliberately chose. Everything else is what merely survived.
        if let anchor = store.carriedAnchor {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("You said start here")
                HStack(spacing: 10) {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationSunAccent))
                    Text(anchor.title)
                        .font(LifeBoardFoundationTypography.sectionTitle())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                }
                Text("Chosen when you closed yesterday.")
                    .font(LifeBoardFoundationTypography.metadata())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .dayCloseCard()
            .accessibilityIdentifier("dayOpen.anchor")
        }

        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("What carried")
            if store.unfinished.isEmpty {
                Text("Nothing carried over. Today starts clear.")
                    .font(LifeBoardFoundationTypography.body())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else if store.retrospectiveDayWasClosed == false {
                // Honest about provenance: these are today's commitments, not
                // the outcome of a close that never happened.
                Text("Yesterday wasn't closed, so nothing was carried deliberately. Here's what's open today.")
                    .font(LifeBoardFoundationTypography.metadata())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            ForEach(store.unfinished) { task in
                Text(task.title)
                    .font(LifeBoardFoundationTypography.body())
                    .foregroundStyle(
                        task.id == store.carriedAnchorTaskID
                            ? Color(LifeBoardColorTokens.inkTertiary)
                            : Color(LifeBoardColorTokens.inkPrimary)
                    )
            }
            Button("Open plan") { onFinished() }
                .buttonStyle(.lifeBoardPrimary)
        }
        .dayCloseCard()
        .accessibilityIdentifier("dayOpen.carried")
    }

    // MARK: - Shared

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(LifeBoardFoundationTypography.sectionTitle())
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
    }
}

// MARK: - Ribbon strip

/// The day as a horizontal band: three stacked tracks, drawn in on appear.
///
/// Scrolls rather than compressing. A twelve-hour day squeezed into 350 points
/// makes a twenty-minute block one pixel wide, which is a chart that cannot be
/// read and therefore is not worth drawing.
private struct DayCloseRibbonStrip: View {
    let ribbon: DayCloseRibbon

    @State private var reveal: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pointsPerHour: CGFloat = 64
    private static let laneHeight: CGFloat = 22

    private var width: CGFloat {
        max(CGFloat(ribbon.duration / 3_600) * Self.pointsPerHour, 320)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                ForEach(ribbon.segments) { segment in
                    segmentView(segment)
                }
                ForEach(ribbon.completionMarks) { mark in
                    completionView(mark)
                }
            }
            .frame(
                width: width,
                height: CGFloat(max(ribbon.laneCount, 1)) * (Self.laneHeight + 6) + 18,
                alignment: .topLeading
            )
            .lifeboardChartRevealSweep(progress: reveal)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your day, hour by hour")
        .accessibilityValue(prose)
        .onAppear {
            guard reduceMotion == false else { return reveal = 1 }
            withAnimation(.easeOut(duration: 0.55)) { reveal = 1 }
        }
    }

    /// Charts always ship a prose equivalent.
    private var prose: String {
        let planned = ribbon.segments.count { $0.kind == .planned }
        let focused = ribbon.segments.count { $0.kind == .focused }
        return "\(planned) planned blocks, \(focused) focus sessions, \(ribbon.completionMarks.count) finished tasks."
    }

    private func segmentView(_ segment: DayCloseRibbonSegment) -> some View {
        let start = ribbon.position(of: segment.startAt) ?? 0
        let end = ribbon.position(of: segment.endAt) ?? start
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(fill(for: segment.kind))
            .frame(
                width: max(CGFloat(end - start) * width, 3),
                height: Self.laneHeight
            )
            .offset(
                x: CGFloat(start) * width,
                y: CGFloat(segment.lane) * (Self.laneHeight + 6)
            )
    }

    private func completionView(_ mark: DayCloseCompletionMark) -> some View {
        Circle()
            .fill(Color(LifeBoardColorTokens.foundationSunAccent))
            .frame(width: 7, height: 7)
            .offset(
                x: CGFloat(ribbon.position(of: mark.completedAt) ?? 0) * width,
                y: CGFloat(max(ribbon.laneCount, 1)) * (Self.laneHeight + 6) + 4
            )
    }

    /// External commitments read differently from authored blocks — the ribbon
    /// must never imply LifeBoard scheduled someone else's meeting.
    private func fill(for kind: DayCloseRibbonSegment.Kind) -> Color {
        switch kind {
        case .planned: Color(LifeBoardColorTokens.foundationApricotAccent)
        case .commitment: Color(LifeBoardColorTokens.foundationSageAccent)
        case .focused: Color(LifeBoardColorTokens.foundationSunAccent)
        }
    }
}

// MARK: - Deck card

private struct DayCloseCard: View {
    let task: PlanningTaskSummary
    let armedDirection: LifeBoardDeckDirection?

    private var armed: DayCloseDirection? {
        armedDirection.flatMap {
            LifeBoardDeckPhysics.action(for: $0, candidates: DayCloseDirection.allCases)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.title)
                .font(LifeBoardFoundationTypography.sectionTitle())
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                .multilineTextAlignment(.leading)

            if let estimate = task.estimatedDuration {
                Text("\(Int(estimate / 60)) min planned")
                    .font(LifeBoardFoundationTypography.metadata())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }

            // The armed direction has to be visible before the finger lifts. A
            // gesture that mutates the plan and cannot be seen resolving is a
            // guess, not a decision.
            Label(armed?.title ?? "Flick to decide", systemImage: armed?.symbolName ?? "hand.draw")
                .font(LifeBoardFoundationTypography.metric())
                .foregroundStyle(
                    armed == nil
                        ? Color(LifeBoardColorTokens.inkTertiary)
                        : Color(LifeBoardColorTokens.inkPrimary)
                )
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(18)
        .lifeBoardClaySurface(armedDepth, cornerRadius: LifeBoardFoundationRadius.largeCard)
        // Preview the consequence while the finger is still down.
        //
        // All four directions used to differ only by a label. Letting the card
        // *behave* like the decision — receding when it is being put off,
        // starting to erode when it is being let go — means you feel what you
        // are choosing before you commit to it, and can back out by returning
        // to centre. Nothing here is persisted; the deck still commits only on
        // release, and success feedback still waits for the batch.
        .scaleEffect(previewScale, anchor: .center)
        .opacity(previewOpacity)
        .lifeboardDissolveAway(progress: erosionPreview, tint: releaseTint)
        .lifeBoardMotion(.deckSettle, value: armed)
    }

    /// Warm rather than alarming: releasing something is a legitimate outcome,
    /// not a failure, and the anti-guilt law puts no punitive red on this path.
    private var releaseTint: Color {
        Color(LifeBoardColorTokens.foundationApricotAccent)
    }

    /// A hint of erosion, never enough to hide the title being decided about.
    private var erosionPreview: Double {
        armed == .release ? 0.14 : 0
    }

    private var previewScale: CGFloat {
        switch armed {
        // Being put off — the card steps back.
        case .someday: 0.955
        // Being carried forward — it leans in.
        case .tomorrow: 1.012
        default: 1
        }
    }

    private var previewOpacity: Double {
        armed == .someday ? 0.82 : 1
    }

    /// `.doneAnyway` was the one direction with no feeling, because it is the
    /// one that is not a *change*: the work already happened and only the record
    /// is catching up. Nothing should move, so instead of leaning, receding or
    /// eroding, the card stops floating — the drop shadow shrinks from radius 10
    /// to 4 and it settles onto the canvas, which reads as "already landed".
    ///
    /// Deliberately not `LifeBoardCompletionMark`: that is success feedback, and
    /// DESIGN.md requires a persisted-state boundary before success. Arming is
    /// not a persisted state — the deck still commits one batch at the end, and
    /// returning to centre must be able to take this back.
    private var armedDepth: LifeBoardClayDepth {
        armed == .doneAnyway ? .resting : .raised
    }
}

// MARK: - Direction pad

/// The four directions, always visible and always tappable.
///
/// The deck's flick is an accelerator. This is the equal path, and it is what
/// makes the gesture legible in the first place — nobody discovers four
/// directions by guessing.
private struct DayCloseDirectionPad: View {
    let armed: DayCloseDirection?
    let onSelect: (DayCloseDirection) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DayCloseDirection.allCases, id: \.self) { direction in
                Button { onSelect(direction) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: direction.symbolName)
                        Text(direction.title)
                            .font(LifeBoardFoundationTypography.metadata())
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.lifeBoardChip)
                .accessibilityIdentifier("dayClose.direction.\(direction.rawValue)")
            }
        }
    }
}

// MARK: - Card surface

private extension View {
    /// Local twin of Plan's `foundationClayCard`, which is `fileprivate` to its
    /// own file. Same primitive, same radius, same padding — deliberately not a
    /// new shadow geometry, and not worth widening Plan's access just to share
    /// four lines.
    func dayCloseCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: LifeBoardFoundationRadius.card)
    }
}
