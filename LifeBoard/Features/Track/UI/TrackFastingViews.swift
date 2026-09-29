import Charts
import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

// The fasting surfaces, extracted from `LifeBoardTrackFoundationViews.swift`.
//
// Fasting appears three times in the product — a Home card, a Track module and
// its own destination — and two of those live here. Keeping them adjacent is
// what stops them drifting into three different designs again, which is exactly
// what had happened before this pass.
//
// The extraction itself is for the file-size ratchet, whose `largest` metric
// tracks the `-Onone` launch stack budget. Track's root file is the largest
// view tree in the app.

private struct TrackFastingSurface: ViewModifier {
    let isHero: Bool
    let palette: DaypartPalette

    func body(content: Content) -> some View {
        if isHero {
            content.lifeBoardHeroSurface(palette: palette)
        } else {
            content.lifeBoardClaySurface(.raised)
        }
    }
}

struct TrackFastingSection: View {
    let fastingTimerStore: FastingTimerStore
    let sessions: [FastingSessionValue]
    @Binding var fastingError: String?
    @Binding var showsFastingComposer: Bool
    @Binding var showsFastingHistory: Bool
    let reloadFasting: () async -> Void
    /// Cancelling ends a running session, so it asks first — and reports a
    /// failure instead of swallowing it with `try?`.
    @State private var confirmsCancellation = false
    /// The fast as it was before Finish, so the receipt can reopen it.
    @State private var finishedSession: FastingSessionValue?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Whether this lens has nominated fasting as its one hero.
    ///
    /// Decided by the root rather than here: a section cannot know what else is
    /// on screen beside it, and `DESIGN.md`'s one-hero rule is a property of the
    /// composition. `HeroSurface`'s environment claim catches nesting on its
    /// own; sibling sections need the screen to choose between them.
    var isHero = false

    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var activeFast: FastingSessionValue? {
        sessions.first { $0.endedAt == nil }
    }

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader("Fasting", symbol: "timer")

            VStack(alignment: .leading, spacing: 12) {
                if let activeFast {
                    ActiveVisibleTimeline(every: 1) { context in
                        let elapsed = max(0, activeFast.elapsed(at: context.date))
                        HStack(spacing: 14) {
                            let fraction = activeFast.targetDuration.map { target in
                                target > 0 ? min(1, elapsed / target) : 0
                            } ?? 0
                            ProgressRing(
                                fraction: fraction,
                                tint: Color(SemanticColorTokens.foundationSunInk),
                                trackTint: Color(SemanticColorTokens.foundationSurfaceRecessed),
                                lineWidth: 7
                            )
                            .frame(width: 56, height: 56)
                            .lifeboardFastingEmberRing(
                                progress: fraction,
                                tint: Color(SemanticColorTokens.foundationSunAccent)
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(TrackSectionCopy.fastingClock(elapsed))
                                    .lifeboardFont(.metric)
                                    .monospacedDigit()
                                Text(TrackSectionCopy.fastingTargetText(activeFast.targetDuration))
                                    .lifeboardFont(.caption1)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            Spacer(minLength: 0)
                        }
                        // "3:12:07" read aloud is three numbers; say what it means.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(TrackSectionCopy.fastingSpokenElapsed(elapsed))
                        .accessibilityValue(TrackSectionCopy.fastingTargetText(activeFast.targetDuration))
                    }

                    HStack(spacing: 12) {
                        Button("End fast") {
                            let before = activeFast
                            Task {
                                do {
                                    _ = try await fastingTimerStore.finish()
                                    Haptic.commit.play()
                                    withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                                        finishedSession = before
                                    }
                                } catch {
                                    fastingError = TrackSectionCopy.fastingFailure(error)
                                    Haptic.fail.play()
                                }
                                await reloadFasting()
                            }
                        }
                        .buttonStyle(.lifeBoardPrimary)
                        Button("Cancel fast") { confirmsCancellation = true }
                            .buttonStyle(.lifeBoardChip)
                    }
                    .frame(minHeight: 44)
                    .confirmationDialog(
                        "Cancel fast?",
                        isPresented: $confirmsCancellation,
                        titleVisibility: .visible
                    ) {
                        Button("Cancel fast", role: .destructive) {
                            Task {
                                do {
                                    _ = try await fastingTimerStore.cancel()
                                    finishedSession = nil
                                } catch {
                                    fastingError = TrackSectionCopy.fastingFailure(error)
                                    Haptic.fail.play()
                                }
                                await reloadFasting()
                            }
                        }
                        Button("Keep fasting", role: .cancel) {}
                    } message: {
                        Text("It stays in history as cancelled.")
                    }
                } else {
                    // Finishing is reversible, so it runs at once and offers
                    // Undo here, under the control that finished it.
                    if let finishedSession {
                        ReceiptBar(
                            ActionReceiptPresentation(
                                id: finishedSession.id,
                                message: String(localized: "Fast ended"),
                                detail: TrackSectionCopy.fastingSpokenElapsed(finishedSession.elapsed(at: Date()))
                            ),
                            undo: { Task { await undoFinish(finishedSession) } },
                            onDismiss: { self.finishedSession = nil }
                        )
                        .accessibilityIdentifier("track.fasting.finishReceipt")
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Text("No fast running")
                        .lifeboardFont(.support)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    Button("Start fast") { showsFastingComposer = true }
                        .buttonStyle(.lifeBoardPrimary)
                }

                if let message = fastingError {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(message)
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color(SemanticColorTokens.foundationDanger))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Try again") {
                            fastingError = nil
                            Task { await reloadFasting() }
                        }
                        .lifeboardFont(.buttonSmall)
                        .minimumHitTarget()
                    }
                }

                if sessions.contains(where: { $0.endedAt != nil }) {
                    Divider()
                    Button {
                        showsFastingHistory = true
                    } label: {
                        HStack {
                            Text("Fasting history")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(isHero ? 20 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .featureHeaderArtwork(.fasting)
            .modifier(TrackFastingSurface(isHero: isHero, palette: DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)))
            .accessibilityIdentifier("track.fasting")
        }
    }

    /// Reopens the fast Finish just closed, with its original start, target
    /// and note — and so its reminders.
    private func undoFinish(_ session: FastingSessionValue) async {
        do {
            _ = try await fastingTimerStore.correct(
                sessionID: session.id,
                startedAt: session.startedAt,
                endedAt: nil,
                targetDuration: session.targetDuration,
                note: session.note
            )
            finishedSession = nil
            Haptic.pick.play()
        } catch {
            fastingError = TrackSectionCopy.fastingFailure(error)
            Haptic.fail.play()
        }
        await reloadFasting()
    }
}

/// Focused fasting destination used by Home and URL deep links. The Track root
/// keeps its compact module, while this surface owns the complete lifecycle and
/// history so a card never has to drop the person on a generic overview.
struct FastingDestinationView: View {
    private let store: FastingTimerStore
    @State private var sessions: [FastingSessionValue] = []
    @State private var showsComposer = false
    @State private var confirmsCancellation = false
    @State private var errorMessage: String?
    @State private var finishedUndoSession: FastingSessionValue?
    @State private var correctionReceipts: [UUID: FastingSessionMutationReceipt] = [:]
    /// The history session whose times are open in the exact-time editor.
    @State private var editingTimesSession: FastingSessionValue?
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    init(repository: any FastingSessionRepository) {
        store = FastingTimerStore(repository: repository)
    }

    private var activeFast: FastingSessionValue? {
        sessions.first { $0.endedAt == nil }
    }

    private var finishedSessions: [FastingSessionValue] {
        sessions.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                statusSection
                historySection
            }
            .padding(20)
        }
        .accessibilityIdentifier("fasting.workspace")
        .background { GrainedCanvas() }
        .navigationTitle("Fasting")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showsComposer) {
            FastingComposer { target, reminders in
                Task {
                    do {
                        _ = try await store.start(targetDuration: target, reminderOffsets: reminders)
                        await reload()
                    } catch {
                        errorMessage = TrackSectionCopy.fastingFailure(error)
                    }
                }
            }
        }
        .sheet(item: $editingTimesSession) { session in
            FastingTimesEditor(session: session) { startedAt, endedAt in
                Task { await correct(session, startedAt: startedAt, endedAt: endedAt) }
            }
        }
        .confirmationDialog("Cancel fast?", isPresented: $confirmsCancellation) {
            Button("Cancel fast", role: .destructive) { Task { await cancel() } }
            Button("Keep fasting", role: .cancel) {}
        } message: {
            Text("It stays in history as cancelled.")
        }
        .alert("Couldn’t update fast", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Try again") { Task { await reload() } }
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    /// The running fast is the one thing this screen exists to show, so it is
    /// the hero. History below stays clay.
    ///
    /// The ember ring is bound to the *session*, not to the view: it burns while
    /// a fast is running and is simply absent otherwise. `DESIGN.md` — "if it is
    /// animating, something is happening right now".
    private var statusSection: some View {
        let palette = DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)
        return VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Current fast")
            if let activeFast {
                ActiveVisibleTimeline(every: 1) { context in
                    let elapsed = max(0, activeFast.elapsed(at: context.date))
                    let progress = activeFast.targetDuration.map { $0 > 0 ? min(1, elapsed / $0) : 0 } ?? 0
                    HStack(spacing: 16) {
                        ProgressRing(
                            fraction: progress,
                            tint: Color(SemanticColorTokens.foundationSunInk),
                            trackTint: Color(SemanticColorTokens.foundationSurfaceRecessed),
                            lineWidth: 8
                        )
                        .frame(width: 76, height: 76)
                        .lifeboardFastingEmberRing(progress: progress, tint: Color(SemanticColorTokens.foundationSunAccent))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TrackSectionCopy.fastingClock(elapsed))
                                .lifeboardFont(.metric)
                                .monospacedDigit()
                            Text(TrackSectionCopy.fastingTargetText(activeFast.targetDuration))
                                .lifeboardFont(.caption2)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(TrackSectionCopy.fastingSpokenElapsed(elapsed))
                    .accessibilityValue(TrackSectionCopy.fastingTargetText(activeFast.targetDuration))
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { finishButton; cancelButton }
                    VStack(alignment: .leading, spacing: 12) { finishButton; cancelButton }
                }
            } else {
                StatusSurface(
                    state: .noRecord,
                    title: String(localized: "No fast running"),
                    message: ""
                )
                Button("Start fast") { showsComposer = true }
                    .buttonStyle(.lifeBoardPrimary)
                    .accessibilityIdentifier("fasting.start")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .featureHeaderArtwork(.fasting)
        .lifeBoardHeroSurface(palette: palette)
    }

    private var finishButton: some View {
        Button("End fast") { Task { await finish() } }
            .buttonStyle(.lifeBoardPrimary)
            .accessibilityIdentifier("fasting.finish")
    }

    private var cancelButton: some View {
        // A quiet text action, not a clay chip. This row sits on the hero's
        // system glass, and the chip's clay material rendered there as a bare
        // white capsule around an unfilled label in every appearance. A
        // secondary, destructive action beside a strong primary reads better
        // as text anyway.
        Button("Cancel fast", role: .destructive) { confirmsCancellation = true }
            .buttonStyle(.plain)
            .lifeboardFont(.buttonSmall)
            .foregroundStyle(Color(SemanticColorTokens.foundationDanger))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("fasting.cancel")
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History").font(Typography.sectionTitle())
            if let finished = finishedUndoSession {
                ReceiptBar(
                    ActionReceiptPresentation(id: finished.id, message: String(localized: "Fast ended")),
                    undo: { Task { await undoFinish() } },
                    onDismiss: { finishedUndoSession = nil }
                )
                .accessibilityIdentifier("fasting.finishReceipt")
            }
            if finishedSessions.isEmpty {
                Text("No past fasts")
                    .font(.subheadline)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            } else {
                ForEach(finishedSessions) { session in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.body.weight(.medium))
                            Text("\(durationText(session)) · \(completionTitle(session.completionKind))")
                                .font(.caption)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            if let note = session.note { Text(note).font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary)) }
                        }
                        Spacer(minLength: 8)
                        Menu {
                            // The 15-minute steps only reach a time that is a
                            // multiple of 15 away — a fast started at 7:40 PM
                            // could never be recorded as 7:40. The editor sets
                            // the exact time through the same correction.
                            Button("Edit times…", systemImage: "clock") { editingTimesSession = session }
                            Section("Start") {
                                Button("15 min earlier") { Task { await correct(session, startDelta: -900, endDelta: 0) } }
                                Button("15 min later") { Task { await correct(session, startDelta: 900, endDelta: 0) } }
                            }
                            Section("End") {
                                Button("15 min earlier") { Task { await correct(session, startDelta: 0, endDelta: -900) } }
                                Button("15 min later") { Task { await correct(session, startDelta: 0, endDelta: 900) } }
                            }
                            if correctionReceipts[session.id] != nil {
                                Button("Undo correction", systemImage: "arrow.uturn.backward") { Task { await undoCorrection(for: session.id) } }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Correct times")
                    }
                    .padding(14)
                    .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
                    .accessibilityElement(children: .contain)
                }
            }
        }
    }

    private func reload() async {
        do {
            sessions = try await store.sessions(limit: 60)
            errorMessage = nil
        } catch { errorMessage = TrackSectionCopy.fastingFailure(error) }
    }

    private func finish() async {
        do {
            finishedUndoSession = activeFast
            _ = try await store.finish()
            await reload()
        } catch { errorMessage = TrackSectionCopy.fastingFailure(error) }
    }

    private func cancel() async {
        do {
            _ = try await store.cancel()
            finishedUndoSession = nil
            await reload()
        } catch { errorMessage = TrackSectionCopy.fastingFailure(error) }
    }

    private func undoFinish() async {
        guard let session = finishedUndoSession else { return }
        do {
            _ = try await store.correct(
                sessionID: session.id,
                startedAt: session.startedAt,
                endedAt: nil,
                targetDuration: session.targetDuration,
                note: session.note
            )
            finishedUndoSession = nil
            await reload()
        } catch { errorMessage = TrackSectionCopy.fastingFailure(error) }
    }

    private func correct(_ session: FastingSessionValue, startDelta: TimeInterval, endDelta: TimeInterval) async {
        guard let endedAt = session.endedAt else { return }
        await correct(
            session,
            startedAt: session.startedAt.addingTimeInterval(startDelta),
            endedAt: endedAt.addingTimeInterval(endDelta)
        )
    }

    /// The one write path for both the 15-minute steps and the exact-time
    /// editor, so either leaves an undoable receipt and the same validation
    /// (end after start) runs in the store.
    private func correct(_ session: FastingSessionValue, startedAt: Date, endedAt: Date?) async {
        do {
            let receipt = try await store.correctWithReceipt(
                sessionID: session.id,
                startedAt: startedAt,
                endedAt: endedAt,
                targetDuration: session.targetDuration,
                note: session.note
            )
            correctionReceipts[session.id] = receipt
            await reload()
        } catch { errorMessage = TrackSectionCopy.fastingFailure(error) }
    }

    private func undoCorrection(for sessionID: UUID) async {
        guard let receipt = correctionReceipts[sessionID] else { return }
        do {
            try await store.undo(receipt)
            correctionReceipts[sessionID] = nil
            await reload()
        } catch { errorMessage = TrackSectionCopy.fastingFailure(error) }
    }

    private func durationText(_ session: FastingSessionValue) -> String {
        LifeBoardDuration.text(seconds: session.elapsed())
    }

    private func completionTitle(_ kind: FastingCompletionKind?) -> String {
        switch kind {
        case .planned: String(localized: "Completed")
        case .early: String(localized: "Ended early")
        case .cancelled: String(localized: "Cancelled")
        case .corrected: String(localized: "Corrected")
        case nil: String(localized: "Logged")
        }
    }
}

/// Exact start and end times for a recorded fast.
///
/// It only gathers the two dates; the caller writes them through the same
/// receipt-producing correction as the 15-minute steps, so Undo keeps working.
/// Save stays disabled until the end falls after the start — the store would
/// reject that interval anyway, but an alert after dismissal loses the edit.
struct FastingTimesEditor: View {
    let session: FastingSessionValue
    let onSave: (Date, Date?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var startedAt: Date
    @State private var endedAt: Date

    init(session: FastingSessionValue, onSave: @escaping (Date, Date?) -> Void) {
        self.session = session
        self.onSave = onSave
        _startedAt = State(initialValue: session.startedAt)
        _endedAt = State(initialValue: session.endedAt ?? session.startedAt)
    }

    private var hasEnded: Bool { session.endedAt != nil }

    private var isValid: Bool { hasEnded == false || endedAt > startedAt }

    var body: some View {
        ComposerScaffold(
            title: String(localized: "Edit times"),
            confirmTitle: String(localized: "Save"),
            isConfirmEnabled: isValid,
            titleDisplayMode: .inline,
            detents: [.medium, .large],
            identifier: "fasting.editTimes",
            onConfirm: {
                onSave(startedAt, hasEnded ? endedAt : nil)
                dismiss()
            }
        ) {
            FastingTimesSection(
                startedAt: $startedAt,
                endedAt: $endedAt,
                hasEnded: hasEnded,
                isValid: isValid
            )
        }
    }
}

private struct FastingTimesSection: View {
    @Binding var startedAt: Date
    @Binding var endedAt: Date
    let hasEnded: Bool
    let isValid: Bool

    var body: some View {
        ComposerSection(String(localized: "Times")) {
            // Bounded by now: a recorded fast cannot have started or ended in
            // the future.
            DatePicker("Started", selection: $startedAt, in: ...Date.now)
                .accessibilityIdentifier("fasting.editTimes.start")
            if hasEnded {
                DatePicker("Ended", selection: $endedAt, in: ...Date.now)
                    .accessibilityIdentifier("fasting.editTimes.end")
                if isValid == false {
                    Text("End time must be after start.")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.foundationDanger))
                }
            }
        }
    }
}
