import SwiftUI
import UIKit

/// The distraction-free focus session.
///
/// `DESIGN.md` asks Focus for "one commitment, tactile dial, clear pause/resume/
/// finish actions, minimal chrome, and a persisted completion receipt". What
/// shipped instead was `FocusSessionRouteView` re-hosting `PlanRootView(initialLens: .day)`
/// — the entire Plan Day surface, lens picker and all, with the running session
/// as one card inside it. That is the opposite of distraction-free.
///
/// No routing or contract change was needed to fix it. `AppRoute.focusSession`
/// already maps to `ScreenMode.focused` (`AppRouter.swift:101`), and
/// `showsFloatingComposer` already returns false for `.focused`
/// (`FoundationShell.swift:337`), so the dock and capture composer drop away on
/// their own. The only thing missing was a surface worth showing there.
///
/// Composition is four small sections rather than one body. That is the
/// -Onone stack budget, not taste: a body that inlines this much walks the
/// main-thread stack and crashes on the guard page at launch, before a pixel is
/// drawn, and never shows up in a Release smoke test.
struct FocusSurface: View {
    let store: PlanStore
    let session: FocusSessionV2
    let onClose: () -> Void
    /// Opens focus history from the settled receipt; nil hides the link.
    var onOpenHistory: (() -> Void)? = nil

    @State private var pendingOutcome: FocusCompletionOutcome?
    @State private var receipt: ActionReceiptPresentation?
    @State private var completionTrigger = 0
    /// When the ending was persisted. Non-nil means the surface has settled into
    /// its receipt: the clock freezes, the transport leaves, and the one primary
    /// action becomes the way back.
    @State private var settledAt: Date?
    /// Done or Skip on the in-place reflection; the way back stays available
    /// throughout, this only decides whether the reflection is still shown.
    @State private var reflectionFinished = false

    /// The route loads its session once, so reading `session` alone left the
    /// dial and the pause button saying "In focus" after a pause succeeded. The
    /// store's copy is the live one whenever it describes the same session.
    private var liveSession: FocusSessionV2 {
        guard let active = store.activeFocusSession, active.id == session.id else { return session }
        return active
    }

    var body: some View {
        ScreenScaffold(mode: .focused, bottomClearance: 12) {
            ScrollView {
                VStack(spacing: 28) {
                    // Focus's hero. `DESIGN.md` names the object this screen
                    // exists to present — "one commitment, tactile dial, clear
                    // pause/resume/finish controls" — and this is it: the
                    // commitment as the title, the mode line as its one line of
                    // context, the dial as the progress control, and
                    // pause/resume as the single primary action.
                    //
                    // The commitment, dial and transport used to be three
                    // sibling sections at equal weight, so the screen had no
                    // dominant object at all. Finish, next phase and
                    // interruption logging stay below in clay: a hero may hold
                    // one primary action and at most one quiet alternative, and
                    // those are three more.
                    DecisionSurface(
                        title: FocusSurfaceCommitmentSection.headline(
                            companion: store.focusCompanion,
                            taskTitle: liveSession.taskID.flatMap { store.task(for: $0)?.title }
                        ),
                        context: FocusSurfaceCommitmentSection.context(
                            session: liveSession,
                            companion: store.focusCompanion
                        ),
                        accessibilityID: "focus.hero",
                        progressControl: {
                            FocusSurfaceDialSection(
                                store: store,
                                session: liveSession,
                                completionTrigger: completionTrigger,
                                settledAt: settledAt
                            )
                        },
                        primary: {
                            if settledAt == nil {
                                FocusPauseResumeButton(store: store, session: liveSession)
                            } else {
                                Button("Back to Plan", systemImage: "arrow.uturn.backward", action: onClose)
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .buttonStyle(.lifeBoardPrimary)
                                    .accessibilityIdentifier("focus.surface.done")
                            }
                        }
                    )

                    // The reflection happens here, right after the ending is
                    // persisted, rather than as a card waiting on Plan. The
                    // store's pending receipt is the source of truth, so a
                    // session that ended elsewhere still gets Plan's card.
                    if settledAt != nil, reflectionFinished == false,
                       let pending = store.pendingFocusReflection, pending.sessionID == liveSession.id {
                        FocusReflectionSection(
                            store: store,
                            receipt: pending,
                            taskTitle: liveSession.taskID.flatMap { store.task(for: $0)?.title },
                            onFinished: { reflectionFinished = true }
                        )
                    }

                    if settledAt == nil {
                        FocusSurfaceTransportSection(
                            store: store,
                            session: liveSession,
                            pendingOutcome: $pendingOutcome
                        )
                    }

                    if pendingOutcome != nil {
                        FocusSurfaceCloseSection(
                            store: store,
                            pendingOutcome: $pendingOutcome,
                            onCommitted: handleCommitted
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .lifeBoardMotion(.contentInsertion, value: pendingOutcome)
        .lifeBoardMotion(.contentInsertion, value: settledAt)
        .lifeBoardMotion(.contentInsertion, value: reflectionFinished)
        .lifeBoardReceipt(
            $receipt,
            destination: onOpenHistory.map { open in ReceiptBar.Destination(title: "History", action: open) }
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // A pushed screen, so not the sheet-dismiss chevron; Esc closes
                // it from a hardware keyboard and the Mac.
                Button("Close", systemImage: "xmark", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("focus.surface.close")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("focus.surface")
        // A running session keeps the screen awake, the way a timer on a desk
        // would; paused, settled, or gone, the system decides again.
        .onAppear { updateIdleTimer() }
        .onChange(of: liveSession.state) { _, _ in updateIdleTimer() }
        .onChange(of: settledAt) { _, _ in updateIdleTimer() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        // Pomodoro phases used to wait for someone to press "Next phase", so a
        // rest could silently run an hour. The phase now turns over at its end
        // while the surface is open; the store ends the session after the last.
        // Keyed on state too: a phase paused past its end must re-check on resume.
        .task(id: PomodoroWaitKey(endsAt: store.focusCompanion?.pomodoroPhase?.phaseEndsAt, state: liveSession.state)) {
            await advancePomodoroWhenPhaseEnds()
        }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = settledAt == nil && liveSession.state == .running
    }

    private func advancePomodoroWhenPhaseEnds() async {
        guard let endsAt = store.focusCompanion?.pomodoroPhase?.phaseEndsAt else { return }
        let wait = endsAt.timeIntervalSinceNow
        if wait > 0 {
            try? await Task.sleep(for: .seconds(wait))
        }
        guard Task.isCancelled == false,
              FocusPomodoroAutoAdvance.shouldAdvance(
                  session: liveSession,
                  companion: store.focusCompanion,
                  isSettled: settledAt != nil,
                  now: Date()
              ) else { return }
        Haptic.threshold.play()
        await store.advancePomodoro()
    }

    /// Success motion and the receipt both begin *after* the store reports the
    /// commit succeeded — `DESIGN.md`: "Persistence precedes success motion and
    /// haptics." Firing the burst optimistically is how an app ends up
    /// celebrating a write that failed.
    ///
    /// The surface no longer closes itself here. It used to call `onClose()` in
    /// the same breath as setting the receipt and the burst, which unmounted the
    /// view that presents both — the "persisted completion receipt" the design
    /// asks for was never on screen. It now settles in place and the person
    /// leaves when they are ready.
    private func handleCommitted(_ outcome: FocusCompletionOutcome) {
        settledAt = Date()
        completionTrigger &+= 1
        Haptic.commit.play()
        receipt = ActionReceiptPresentation(message: Self.receiptMessage(for: outcome))
    }

    static func receiptMessage(for outcome: FocusCompletionOutcome) -> String {
        switch outcome {
        case .completed: String(localized: "Focus done")
        case .continueLater: String(localized: "Saved for later")
        case .abandoned, .stopped: String(localized: "Focus stopped")
        case .interrupted: String(localized: "Focus interrupted")
        case .intentionallyDeferred: String(localized: "Moved to later")
        }
    }
}

/// When a Pomodoro phase should turn over on its own.
enum FocusPomodoroAutoAdvance {
    static func shouldAdvance(
        session: FocusSessionV2,
        companion: FocusSessionCompanion?,
        isSettled: Bool,
        now: Date
    ) -> Bool {
        guard isSettled == false,
              session.state == .running,
              case .pomodoro = companion?.mode,
              let phase = companion?.pomodoroPhase else { return false }
        return now >= phase.phaseEndsAt
    }
}

private struct PomodoroWaitKey: Equatable {
    let endsAt: Date?
    let state: FocusSessionState
}

/// The words for the one thing you said you were doing. `FocusSurface`'s
/// hero renders them through `DecisionSurface`; the standalone section body
/// that once duplicated that hero is gone, and only the copy rules remain.
enum FocusSurfaceCommitmentSection {
    /// The intention if one was stated, else the task the session is on, else
    /// "Focusing". A session started on a task used to read "Focusing" — the
    /// screen whose one job is holding a commitment did not say what it was.
    static func headline(companion: FocusSessionCompanion?, taskTitle: String? = nil) -> String {
        if let intention = companion?.intention.trimmingCharacters(in: .whitespacesAndNewlines),
           intention.isEmpty == false {
            return intention
        }
        if let taskTitle = taskTitle?.trimmingCharacters(in: .whitespacesAndNewlines), taskTitle.isEmpty == false {
            return taskTitle
        }
        // No stated intention is a real state, not a blank. Naming it keeps
        // the dominant line from collapsing to empty space.
        return "Focusing"
    }

    /// Mode and round, folded into one quiet line. Two separate metadata rows
    /// competed with the intention above them for no added meaning.
    static func context(session: FocusSessionV2, companion: FocusSessionCompanion?) -> String? {
        guard let companion else { return nil }
        var parts: [String] = []
        switch companion.mode {
        case .countdown:
            parts.append("Countdown")
        case .stopwatch:
            parts.append("Stopwatch")
        case .openEnded:
            parts.append("Open-ended")
        case let .pomodoro(_, _, rounds):
            if let phase = companion.pomodoroPhase {
                parts.append(phase.kind == .focus ? "Focus" : "Rest")
                parts.append("round \(phase.round) of \(rounds)")
            } else {
                parts.append("Pomodoro")
            }
        }
        if session.state == .paused {
            parts.append("paused")
        }
        return parts.joined(separator: " · ")
    }
}
