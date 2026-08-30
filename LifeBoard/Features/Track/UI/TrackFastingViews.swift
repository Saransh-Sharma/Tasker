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
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = max(0, activeFast.elapsed(at: context.date))
                        HStack(spacing: 14) {
                            let fraction = activeFast.targetDuration.map { target in
                                target > 0 ? min(1, elapsed / target) : 0
                            } ?? 0
                            ProgressRing(
                                fraction: fraction,
                                tint: Color(SemanticColorTokens.foundationSunAccent),
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
                                Text(
                                    activeFast.targetDuration
                                        .map { "Target \(Int($0 / 3_600))h" } ?? "No target set"
                                )
                                .font(.caption)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Finish") {
                            Task {
                                _ = try? await fastingTimerStore.finish()
                                await reloadFasting()
                            }
                        }
                        .buttonStyle(.lifeBoardPrimary)
                        Button("Cancel fast") {
                            Task {
                                _ = try? await fastingTimerStore.cancel()
                                await reloadFasting()
                            }
                        }
                        .buttonStyle(.lifeBoardChip)
                    }
                    .frame(minHeight: 44)
                } else {
                    Text("No fast is running.")
                        .font(.subheadline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    Button("Start a fast") { showsFastingComposer = true }
                        .buttonStyle(.lifeBoardPrimary)
                }

                if let fastingError {
                    Text(fastingError)
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.foundationDanger))
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
            .modifier(TrackFastingSurface(isHero: isHero, palette: DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)))
            .accessibilityIdentifier("track.fasting")
        }
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
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .confirmationDialog("Cancel this fast?", isPresented: $confirmsCancellation) {
            Button("Cancel fast", role: .destructive) { Task { await cancel() } }
            Button("Keep fasting", role: .cancel) {}
        } message: {
            Text("The session remains in history as cancelled.")
        }
        .alert("Fasting needs attention", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
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
            SectionHeader("Current session")
            if let activeFast {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = max(0, activeFast.elapsed(at: context.date))
                    let progress = activeFast.targetDuration.map { $0 > 0 ? min(1, elapsed / $0) : 0 } ?? 0
                    HStack(spacing: 16) {
                        ProgressRing(
                            fraction: progress,
                            tint: Color(SemanticColorTokens.foundationSunAccent),
                            trackTint: Color(SemanticColorTokens.foundationSurfaceRecessed),
                            lineWidth: 8
                        )
                        .frame(width: 76, height: 76)
                        .lifeboardFastingEmberRing(progress: progress, tint: Color(SemanticColorTokens.foundationSunAccent))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TrackSectionCopy.fastingClock(elapsed))
                                .lifeboardFont(.metric)
                                .monospacedDigit()
                            Text(activeFast.targetDuration.map { "Your target: \(Int($0 / 3_600)) hours" } ?? "No target set")
                                .lifeboardFont(.caption2)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Active fast")
                    .accessibilityValue("\(TrackSectionCopy.fastingClock(elapsed)) elapsed")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { finishButton; cancelButton }
                    VStack(alignment: .leading, spacing: 10) { finishButton; cancelButton }
                }
            } else {
                StatusSurface(
                    state: .noRecord,
                    title: "No fast is running",
                    message: "Start a neutral timer with an optional target you choose."
                )
                Button("Start a fast") { showsComposer = true }
                    .buttonStyle(.lifeBoardPrimary)
                    .accessibilityIdentifier("fasting.start")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardHeroSurface(palette: palette)
    }

    private var finishButton: some View {
        Button("Finish fast") { Task { await finish() } }
            .buttonStyle(.lifeBoardPrimary)
            .accessibilityIdentifier("fasting.finish")
    }

    private var cancelButton: some View {
        Button("Cancel fast", role: .destructive) { confirmsCancellation = true }
            .buttonStyle(.lifeBoardChip)
            .accessibilityIdentifier("fasting.cancel")
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History").font(Typography.sectionTitle())
                Spacer()
                if finishedUndoSession != nil {
                    Button("Undo finish") { Task { await undoFinish() } }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }
            if finishedSessions.isEmpty {
                Text("Finished and cancelled sessions will appear here.")
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
                            Button("Start 15 minutes earlier") { Task { await correct(session, startDelta: -900, endDelta: 0) } }
                            Button("Start 15 minutes later") { Task { await correct(session, startDelta: 900, endDelta: 0) } }
                            Button("End 15 minutes earlier") { Task { await correct(session, startDelta: 0, endDelta: -900) } }
                            Button("End 15 minutes later") { Task { await correct(session, startDelta: 0, endDelta: 900) } }
                            if correctionReceipts[session.id] != nil {
                                Button("Undo last correction", systemImage: "arrow.uturn.backward") { Task { await undoCorrection(for: session.id) } }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Correct fasting session")
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
        } catch { errorMessage = error.localizedDescription }
    }

    private func finish() async {
        do {
            finishedUndoSession = activeFast
            _ = try await store.finish()
            await reload()
        } catch { errorMessage = error.localizedDescription }
    }

    private func cancel() async {
        do {
            _ = try await store.cancel()
            finishedUndoSession = nil
            await reload()
        } catch { errorMessage = error.localizedDescription }
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
        } catch { errorMessage = error.localizedDescription }
    }

    private func correct(_ session: FastingSessionValue, startDelta: TimeInterval, endDelta: TimeInterval) async {
        guard let endedAt = session.endedAt else { return }
        do {
            let receipt = try await store.correctWithReceipt(
                sessionID: session.id,
                startedAt: session.startedAt.addingTimeInterval(startDelta),
                endedAt: endedAt.addingTimeInterval(endDelta),
                targetDuration: session.targetDuration,
                note: session.note
            )
            correctionReceipts[session.id] = receipt
            await reload()
        } catch { errorMessage = error.localizedDescription }
    }

    private func undoCorrection(for sessionID: UUID) async {
        guard let receipt = correctionReceipts[sessionID] else { return }
        do {
            try await store.undo(receipt)
            correctionReceipts[sessionID] = nil
            await reload()
        } catch { errorMessage = error.localizedDescription }
    }

    private func durationText(_ session: FastingSessionValue) -> String {
        let minutes = max(0, Int(session.elapsed() / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func completionTitle(_ kind: FastingCompletionKind?) -> String {
        switch kind {
        case .planned: "Completed"
        case .early: "Ended early"
        case .cancelled: "Cancelled"
        case .corrected: "Corrected"
        case nil: "Recorded"
        }
    }
}
