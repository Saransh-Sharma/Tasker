import SwiftUI

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

    @State private var pendingOutcome: FocusCompletionOutcome?
    @State private var receipt: ActionReceiptPresentation?
    @State private var completionTrigger = 0
    /// When the ending was persisted. Non-nil means the surface has settled into
    /// its receipt: the clock freezes, the transport leaves, and the one primary
    /// action becomes the way back.
    @State private var settledAt: Date?

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
                            companion: store.focusCompanion
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
        .lifeBoardReceipt($receipt)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "chevron.down", action: onClose)
                    .accessibilityIdentifier("focus.surface.close")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("focus.surface")
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
        receipt = ActionReceiptPresentation(
            message: Self.receiptMessage(for: outcome),
            detail: "Saved to your focus history."
        )
    }

    static func receiptMessage(for outcome: FocusCompletionOutcome) -> String {
        switch outcome {
        case .completed: "Focus finished."
        case .continueLater: "Focus paused for later."
        case .abandoned: "Focus stopped."
        case .stopped: "Focus stopped."
        case .interrupted: "Focus interrupted."
        case .intentionallyDeferred: "Focus deferred."
        }
    }
}
