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
                            session: session,
                            companion: store.focusCompanion
                        ),
                        accessibilityID: "focus.hero",
                        progressControl: {
                            FocusSurfaceDialSection(
                                store: store,
                                session: session,
                                completionTrigger: completionTrigger
                            )
                        },
                        primary: {
                            FocusPauseResumeButton(store: store, session: session)
                        }
                    )

                    FocusSurfaceTransportSection(
                        store: store,
                        session: session,
                        pendingOutcome: $pendingOutcome
                    )

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
    private func handleCommitted(_ outcome: FocusCompletionOutcome) {
        completionTrigger &+= 1
        Haptic.commit.play()
        receipt = ActionReceiptPresentation(
            message: Self.receiptMessage(for: outcome),
            detail: "Saved to your focus history."
        )
        onClose()
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
