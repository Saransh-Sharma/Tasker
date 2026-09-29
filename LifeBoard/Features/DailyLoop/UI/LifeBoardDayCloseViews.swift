import SwiftUI

/// Which end of the day this surface is for.
public enum DayCloseMode: String, Sendable {
    /// The evening ritual: reconcile, reflect, anchor, close.
    case close
    /// The morning counterpart. It reports what last night decided and confirms
    /// today's explicit proposal as one receipt with one Undo.
    case open
}

/// Close the Day.
///
/// Five beats on one scroll rather than a wizard: a person ending their day
/// should be able to see the whole thing at once and stop wherever they like.
/// Paging would make "I only wanted to write the line" into four taps.
struct DayCloseRoute: View {
    let mode: DayCloseMode
    @State var store: DayCloseStore
    private let reflections: (any ReflectionNoteRepositoryProtocol)?
    /// The journal the close is mirrored into (see `JournalDayCloseWriter`).
    private let journal: (any PhaseIIRepository)?
    let onFinished: () -> Void

    /// Unset until the person picks one: a preset 3 was recorded as a real
    /// rating for everyone who never touched it.
    @State private var energy: Int?
    @State private var note = ""
    /// The note saved but its journal copy did not; said once, in the card.
    @State private var journalMirrorFailed = false
    @State private var reflectionPhase: AsyncActionPhase<UUID> = .idle
    @State private var closeTrigger = 0
    /// Advanced once when the morning commit lands, driving the light sweep.
    @State var firstLightTrigger = 0
    @State private var releaseDissolve: Double = 0
    @Namespace private var anchorNamespace

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        store: DayCloseStore,
        mode: DayCloseMode,
        reflections: (any ReflectionNoteRepositoryProtocol)?,
        journal: (any PhaseIIRepository)? = nil,
        onFinished: @escaping () -> Void
    ) {
        _store = State(initialValue: store)
        self.mode = mode
        self.reflections = reflections
        self.journal = journal
        self.onFinished = onFinished
    }

    /// Mirror the saved note into today's journal. The review keeps reading
    /// `ReflectionNote`; the journal is where the words are read back later.
    private func mirrorToJournal(_ saved: ReflectionNote) async {
        guard let journal else { return }
        do {
            let existing = try await journal.fetchJournalDay(containing: Date()) ?? JournalDayValue(day: Date())
            guard let merged = JournalDayCloseWriter.merged(day: existing, noteID: saved.id, text: note, energy: energy) else { return }
            try await journal.saveJournalDay(merged)
            journalMirrorFailed = false
        } catch {
            // The line itself is saved; only its copy in the journal is not.
            journalMirrorFailed = true
        }
    }

    private var reflectionSaved: Bool {
        if case .success = reflectionPhase { return true }
        return false
    }

    /// Something was written or rated and has not been saved yet. Closing
    /// the day saves it first.
    private var needsReflectionSave: Bool {
        guard reflections != nil, reflectionSaved == false else { return false }
        return note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || energy != nil
    }

    private var reflectionFailureMessage: String? {
        if case let .recoverableFailure(failure) = reflectionPhase { return failure.message }
        return nil
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
        // One name for the morning ritual, the same one Home's row uses.
        .navigationTitle(mode == .close ? "Close the day" : "Start the day")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("dayClose.root")
        .task { await store.load() }
        // The one-shot night handoff. Its documented role, and the reason no new
        // shader was needed for the closing moment.
        .lifeboardDaypartCrossDissolve(trigger: closeTrigger, daypart: .night)
    }

    // MARK: - Loading and failure

    /// Skeleton lanes that occupy the ribbon's real geometry rather than
    /// covering it, so the content does not jump when it lands.
    private var loadingLanes: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(SemanticColorTokens.metricRingTrack))
                    .frame(height: 18)
            }
        }
        .dayCloseCard()
        .accessibilityLabel("Loading…")
    }

    /// Deliberately unlike the empty state: a day we could not read must never
    /// look like a day that was clear.
    private func failure(_ message: String) -> some View {
        StatusSurface(
            state: .recoverableError,
            title: String(localized: "Couldn’t load your day"),
            message: message,
            actionTitle: String(localized: "Try again"),
            action: { Task { await store.load() } }
        )
        .accessibilityIdentifier("dayClose.load.failed")
    }

    // MARK: - Act 1 — the ribbon

    /// Nothing planned, finished, or left open: a ring of zeros says nothing.
    private func ribbonIsEmpty(_ ribbon: DayCloseRibbon) -> Bool {
        ribbon.summary.completedCount == 0 && ribbon.summary.unfinishedCount == 0 && ribbon.segments.isEmpty
    }

    @ViewBuilder
    private var ribbonAct: some View {
        if let ribbon = store.ribbon, ribbonIsEmpty(ribbon) {
            // The morning drops an empty yesterday entirely; the evening says
            // it in one line instead of "0 finished · 0 still open".
            if mode == .close {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(DayCloseAct.ribbon.title)
                    Text("Nothing planned today")
                        .font(Typography.body())
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                .dayCloseCard()
                .accessibilityIdentifier("dayClose.ribbon")
            }
        } else if let ribbon = store.ribbon {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(DayCloseAct.ribbon.title)

                HStack(alignment: .center, spacing: 20) {
                    DayRing(
                        plannedMinutes: ribbon.summary.plannedMinutes,
                        focusedMinutes: ribbon.summary.focusedMinutes,
                        closedProgress: store.alreadyClosed ? 1 : 0,
                        // Rises as cards are decided, so the ring at the top of
                        // the ritual answers to the deck at the bottom of it.
                        settledLevel: store.reconciliationProgress
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        factLine(String(localized: "\(ribbon.summary.completedCount) done"))
                        factLine(String(localized: "\(ribbon.summary.unfinishedCount) open"))
                        if ribbon.externalCalendarUnavailable {
                            // Absent data is never reported as a confident
                            // value: this says we did not look, not that the
                            // calendar was clear.
                            factLine(String(localized: "Calendar not connected"))
                        }
                    }
                }

                if ribbon.segments.isEmpty {
                    Text("Nothing scheduled")
                        .font(Typography.body())
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                } else {
                    DayCloseRibbonStrip(ribbon: ribbon)
                }
            }
            // Home's panoramic scene. It used to sit behind the Home root
            // header, competing with the live atmosphere; the day's ribbon is
            // the one place in the loop with a quiet canvas behind it. Applied
            // before the card material so the paint lands on the clay rather
            // than behind it.
            .featureHeaderArtwork(.home, cornerRadius: Radius.card)
            .dayCloseCard()
            .accessibilityIdentifier("dayClose.ribbon")
        }
    }

    // MARK: - Act 2 — reconcile

    @ViewBuilder
    private var reconcileAct: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(DayCloseAct.reconcile.title)

            if let card = store.currentCard {
                DirectionalDeck(
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
                        Haptic.pick.play()
                    },
                    card: { task, armed in
                        DayCloseCard(task: task, armedDirection: armed)
                    }
                )
                .accessibilityIdentifier("dayClose.deck")

                DayCloseDirectionPad(armed: nil) { direction in
                    store.record(direction, for: card.id)
                    Haptic.pick.play()
                }

                HStack(spacing: 4) {
                    // Rolls rather than swapping: the count is the one number
                    // that changes on every decision, and a hard cut makes the
                    // deck feel like it is resetting rather than advancing.
                    NumericRoll(value: Double(store.remainingCount))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    Text("left")
                        .font(Typography.metadata())
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    Spacer()
                    if store.decisionOrder.isEmpty == false {
                        Button("Undo last") {
                            store.bringBackLastCard()
                            Haptic.lift.play()
                        }
                        .font(Typography.metric())
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
        // No outer card. `DESIGN.md`: don't nest cards — the deck's own cards
        // are the raised objects here, and wrapping them in a second clay
        // surface made a card-on-card stack.
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
            ZStack {
                ActThread(progress: actProgress)
                    .stroke(
                        Color(SemanticColorTokens.foundationSunAccent).opacity(0.5),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 2)
                ActThreadKnots(progress: actProgress, count: 4)
            }
                .frame(width: 10)
                .background {
                    // The unfilled remainder, so the thread reads as a length
                    // you are moving along rather than a bar that grows.
                    Capsule()
                        .fill(Color(SemanticColorTokens.foundationHairline))
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
        VStack(alignment: .leading, spacing: 8) {
            Label(
                store.decidedCount > 0 ? "All sorted" : "All done",
                systemImage: "checkmark.seal"
            )
            .font(Typography.sectionTitle())
            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            if store.summaryLines.isEmpty == false {
                ForEach(store.summaryLines, id: \.self) { line in
                    Text(line)
                        .font(Typography.metric())
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("dayClose.deck.settled")
    }

    private var staleNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your plan changed.")
                .font(Typography.metric())
            Button("Review again") { Task { await store.reviewAfterConflict() } }
                .buttonStyle(.lifeBoardChip)
        }
        .accessibilityIdentifier("dayClose.conflict")
    }

    // MARK: - Act 3 — one line

    private var reflectAct: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(DayCloseAct.reflect.title)

            // Was `.pickerStyle(.segmented)`, the stock grey segmented control.
            // `OptionRail` keeps the semantics: one selection, per-value
            // accessibility identifiers, and reflow at accessibility text sizes.
            OptionRail(
                "End-of-day energy",
                // 0 matches no chip, so nothing reads as chosen until it is.
                selection: Binding(get: { energy ?? 0 }, set: { energy = $0 }),
                values: Array(1...5),
                identifierPrefix: "dayClose.reflect.energy",
                title: { "\($0)" }
            )
            .accessibilityValue(energy.map { "\($0) out of 5" } ?? "Not chosen")

            TextField("Note", text: $note, prompt: Text("Note").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("dayClose.reflection.note")

            // Closing the day saves the line with it. A separate Save is only
            // offered once the day is already closed, or after a save failed.
            if store.alreadyClosed && needsReflectionSave || reflectionFailureMessage != nil {
                CommitControl(
                    title: String(localized: "Save note"),
                    runningTitle: "Saving…",
                    successTitle: "Saved",
                    phase: reflectionPhase
                ) {
                    Task {
                        await saveReflection()
                        if reflectionSaved { Haptic.commit.play() }
                    }
                }
                .accessibilityIdentifier("dayClose.reflection.commit")
            } else if reflectionSaved {
                Label("Note saved", systemImage: "checkmark")
                    .font(Typography.metadata())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }

            if journalMirrorFailed {
                Text("Couldn’t add note to your journal.")
                    .font(Typography.metadata())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .accessibilityIdentifier("dayClose.reflection.journalFailed")
            }

            if reflections == nil {
                Text("Couldn’t load notes. You can still close the day.")
                    .font(Typography.metadata())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
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
            // No haptic here: closing the day plays the one commit for both.
            reflectionPhase = .success(receipt: saved.id)
            await mirrorToJournal(saved)
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
                // Not an error, not a nag — and not a dead end: the morning
                // asks again.
                Text("Nothing open. Pick a first task in the morning.")
                    .font(Typography.body())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
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
            Haptic.pick.play()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isAnchor ? "sunrise.fill" : "circle")
                    .foregroundStyle(
                        isAnchor
                            ? Color(SemanticColorTokens.foundationSunAccent)
                            : Color(SemanticColorTokens.inkTertiary)
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
                    .font(Typography.body())
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
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
                Text("Day closed at \(closedAt.formatted(date: .omitted, time: .shortened))")
                    .font(Typography.body())
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
                    .font(Typography.metadata())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                Button("Done") { onFinished() }
                    .buttonStyle(.lifeBoardPrimary)
            } else {
                ForEach(store.summary) { line in
                    Text(line.text)
                        .font(Typography.metric())
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        // Released rows erode rather than fade — the effect's
                        // documented role, applied to the nearest true meaning.
                        // Scoped to `.release`: this ran over every line, so
                        // work that was *carried to tomorrow* also eroded, which
                        // says the opposite of what happened to it.
                        .lifeboardDissolveAway(
                            progress: line.direction == .release ? releaseDissolve : 0,
                            tint: Color(SemanticColorTokens.foundationApricotAccent)
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

                if needsReflectionSave {
                    Text("Your note saves when you close the day.")
                        .font(Typography.metadata())
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .accessibilityIdentifier("dayClose.unsavedNote")
                }

                CommitControl(
                    title: "Close the day",
                    runningTitle: "Closing…",
                    successTitle: String(localized: "Day closed"),
                    phase: store.applyPhase
                ) {
                    Task {
                        // Saving the line is part of closing. If it fails,
                        // the day stays open and the reflection card says why,
                        // with the words still in the field.
                        if needsReflectionSave {
                            await saveReflection()
                            guard reflectionSaved else {
                                Haptic.fail.play()
                                return
                            }
                        }
                        await store.close()
                        if case .success = store.applyPhase {
                            closeTrigger += 1
                            Haptic.commit.play()
                            withAnimation(
                                MotionProfile.celebration.animation(reduceMotion: reduceMotion)
                            ) { releaseDissolve = 1 }
                        }
                    }
                }
                .accessibilityIdentifier("dayClose.commit")
            }
        }
        .dayCloseCard()
    }
}

// MARK: - SurfaceCard surface

extension View {
    /// Local twin of Plan's `foundationClayCard`, which is `fileprivate` to its
    /// own file. Same primitive, same radius, same padding — deliberately not a
    /// new shadow geometry, and not worth widening Plan's access just to share
    /// four lines.
    func dayCloseCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
    }
}
