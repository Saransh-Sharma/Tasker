import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// The v6 flow shell.
///
/// One persistent background, one persistent weave, and a step-shaped content
/// column between them. The weave is deliberately *not* replaced between steps:
/// the payoff only reads if the user watches one object accumulate their
/// answers rather than nine unrelated screens going by.
struct LifeWeaveOnboardingView: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    let onComplete: (LifeWeaveCompletionDestination) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var clayTrigger = 0
    // The dock's titles are derived from connector state, and connector state
    // does not live in the draft. Without these three the primary button would
    // keep a stale label through a permission return, a first sync, or an EVA
    // activation completing — none of which is a draft write.
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @StateObject private var calendarSession = CalendarPowerUpSession.shared
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @State private var healthPowerUp = LifeWeaveHealthPowerUpState.shared

    /// The map yields before the copy does, always.
    ///
    /// `DESIGN.md`: "At large text sizes, use one content column … Never shrink
    /// type to preserve a layout." So the weave gives up its height first, then
    /// its labels, then itself — the question is what the screen is for.
    private var weaveHeightFraction: CGFloat {
        if dynamicTypeSize >= .accessibility3 { return 0 }
        if dynamicTypeSize >= .accessibility1 { return 0.11 }
        switch model.draft.route {
        // Arrival and Reveal are the two beats where the map *is* the content,
        // so they keep a little more room. Every question screen gives it back:
        // the map is there to acknowledge the answer, not to compete with it.
        case .core(.arrival), .core(.reveal): return 0.22
        case .core: return 0.16
        // The summary is a receipt about the map, so it earns the taller frame.
        // The connectors are dense — primer, chooser, sync states — and the map
        // has nothing to say about a permission sheet.
        case .powerUp(.complete): return 0.22
        case .powerUp: return 0.12
        }
    }

    /// A share of the window on a phone, but a *capped* height on iPad.
    ///
    /// A fraction of a 1180-point window is 350 points of mostly-empty field
    /// above six short rows — `DESIGN.md` is explicit that extra iPad space is
    /// not to be filled just because it exists. The proper answer is the
    /// two-pane composition (map beside the question); until that lands, the map
    /// takes what it needs and gives the rest back.
    private func weaveHeight(in size: CGSize) -> CGFloat {
        let proportional = size.height * weaveHeightFraction
        guard horizontalSizeClass == .regular else { return proportional }
        let isTallBeat = model.draft.route == .core(.reveal)
            || model.draft.route == .powerUp(.complete)
        return min(proportional, isTallBeat ? 240 : 200)
    }

    var body: some View {
        ZStack {
            LifeMapOnboardingBackground()
            GeometryReader { proxy in
                VStack(spacing: Theme.Spacing.md) {
                    LifeWeaveTopBar(
                        route: model.draft.route,
                        canGoBack: model.canGoBackInFlow,
                        onBack: model.goBackInFlow
                    )

                    if weaveHeightFraction > 0 {
                        LifeWeaveCanvas(presentation: LifeWeavePresentation.make(from: model.draft))
                            .frame(height: weaveHeight(in: proxy.size))
                            .accessibilityIdentifier(LifeWeaveAccessibilityID.canvas)
                    }

                    ScrollView {
                        stepContent
                            .padding(.bottom, Theme.Spacing.lg)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    if let errorMessage = model.errorMessage {
                        LifeWeaveErrorBanner(message: errorMessage)
                    }

                    LifeMapBottomDock(
                        primaryTitle: primaryTitle,
                        secondaryTitle: secondaryTitle,
                        isPrimaryDisabled: isPrimaryDisabled,
                        clayTrigger: clayTrigger,
                        onPrimary: performPrimary,
                        onSecondary: performSecondary,
                        primaryAccessibilityID: LifeWeaveAccessibilityID.primaryAction,
                        secondaryAccessibilityID: LifeWeaveAccessibilityID.secondaryAction
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LifeWeaveAccessibilityID.flow)
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch model.draft.route {
            case .core(let step): coreContent(step)
            case .powerUp(let step): powerUpContent(step)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LifeWeaveAccessibilityID.route(model.draft.route))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func coreContent(_ step: LifeWeaveStep) -> some View {
        switch step {
        case .arrival: LifeWeaveArrivalStep()
        case .intent: LifeWeaveIntentStep(model: model)
        case .lifeAreas: LifeWeaveLifeAreasStep(model: model)
        case .dayShape: LifeWeaveDayShapeStep(model: model)
        case .firstCapture: LifeWeaveCaptureStep(model: model)
        case .reveal: LifeWeaveRevealStep(model: model)
        }
    }

    @ViewBuilder
    private func powerUpContent(_ step: LifeWeavePowerUpStep) -> some View {
        switch step {
        case .calendar: CalendarPowerUpView(model: model)
        case .health: HealthPowerUpView(model: model)
        case .eva: EvaPowerUpView(model: model)
        case .complete: PowerUpSummaryView(model: model)
        }
    }

    // MARK: - Dock

    private var primaryTitle: String {
        switch model.draft.route {
        case .core(.arrival): "Build my LifeBoard"
        case .core(.intent): "Continue"
        case .core(.lifeAreas): "Shape my map"
        case .core(.dayShape): "Use this rhythm"
        case .core(.firstCapture): capturePrimaryTitle
        // No longer "Start with Cloud EVA". The reveal's job is to hand over a
        // finished LifeBoard, not to spend the one dominant action on a network
        // call that can fail.
        case .core(.reveal): model.isPowerUpAvailable ? "Power up LifeBoard" : "Start my day"
        // Each connector owns its own verbs, because the primary means something
        // different in every one of its states.
        case .powerUp(.calendar): model.calendarPrimaryTitle
        case .powerUp(.health): model.healthPrimaryTitle
        case .powerUp(.eva): model.evaPrimaryTitle
        case .powerUp(.complete): summaryPrimaryTitle
        }
    }

    /// Only offered when EVA can actually answer. Routing someone to a planning
    /// partner that is not ready would be a worse ending than Home.
    private var summaryPrimaryTitle: String {
        model.draft.evaCloudReady ? "Ask EVA where to start" : "Start my day"
    }

    /// The capture step's primary means three different things in sequence, and
    /// a fourth once the step has been skipped.
    ///
    /// Skipping used to leave the label on "Make sense of this" with nothing to
    /// make sense of, and `isPrimaryDisabled` kept it disabled — so "Skip for
    /// now" stranded the user on the one screen they had just declined.
    private var capturePrimaryTitle: String {
        if model.captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
           model.draft.stagedCapture == nil {
            return "Make sense of this"
        }
        if let capture = model.draft.stagedCapture {
            return capture.isReviewed ? "Finish setup" : "Keep this"
        }
        return model.draft.skippedCapture ? "Finish setup" : "Make sense of this"
    }

    private var secondaryTitle: String? {
        switch model.draft.route {
        case .core(.firstCapture):
            model.draft.stagedCapture == nil && model.draft.skippedCapture == false ? "Skip for now" : nil
        case .core(.reveal): model.isPowerUpAvailable ? "Start now" : nil
        // Every connector is skippable — but each decides when offering "Not now"
        // still makes sense. Once a system permission has been answered there is
        // nothing left for this screen to decline.
        case .powerUp(.calendar): model.calendarSecondaryTitle
        case .powerUp(.health): model.healthSecondaryTitle
        case .powerUp(.eva): model.evaSecondaryTitle
        case .powerUp(.complete): model.draft.evaCloudReady ? "Start my day" : nil
        default: nil
        }
    }

    private var isPrimaryDisabled: Bool {
        switch model.draft.route {
        case .core(.intent): model.draft.intent == nil
        case .core(.lifeAreas): model.draft.isLifeAreaSelectionValid == false
        case .core(.firstCapture):
            // A resolved step — skipped, or reviewed — can always continue. Without
            // the `isCaptureResolved` term, "Skip for now" left the primary
            // disabled and stranded the user on the screen they had just declined.
            model.isResolvingCapture
                || (model.draft.isCaptureResolved == false
                    && model.draft.stagedCapture == nil
                    && model.captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case .powerUp(.calendar): model.isCalendarPrimaryDisabled
        case .powerUp(.health): model.isHealthPrimaryDisabled
        case .powerUp(.eva): model.isEvaPrimaryDisabled
        default: model.isCommitting
        }
    }

    private func performPrimary() {
        clayTrigger += 1
        Task { @MainActor in
            // The capture step's primary action means three different things in
            // sequence — interpret, keep, finish — so it is resolved here rather
            // than by `advance()`, which owns step transitions only.
            // Only while the step is still unresolved. Without that guard a
            // skipped capture routed back into `resolveCapture()`, which no-ops
            // on empty text — so "Finish setup" did nothing at all and the user
            // was stuck one screen from the end.
            if model.step == .firstCapture, model.draft.isCaptureResolved == false {
                if model.draft.stagedCapture == nil {
                    await model.resolveCapture()
                    return
                }
                if model.draft.stagedCapture?.isReviewed == false {
                    model.keepCapture(
                        kind: model.draft.stagedCapture?.kind ?? .task,
                        areaTemplateID: model.draft.stagedCapture?.lifeAreaTemplateID
                    )
                    return
                }
            }

            if case .powerUp(let powerUpStep) = model.draft.route {
                await performPowerUpPrimary(powerUpStep)
                return
            }

            if model.step == .reveal {
                if model.isPowerUpAvailable {
                    model.beginPowerUp()
                } else if model.finalize(destination: .home) {
                    onComplete(.home)
                }
                return
            }

            _ = await model.advance()
        }
    }

    private func performPowerUpPrimary(_ step: LifeWeavePowerUpStep) async {
        switch step {
        case .calendar: await model.performCalendarPrimary()
        case .health: await model.performHealthPrimary()
        case .eva: await model.performEvaPrimary()
        case .complete:
            finishJourney(destination: model.draft.evaCloudReady ? .eva : .home)
        }
    }

    private func finishJourney(destination: LifeWeaveCompletionDestination) {
        // Reaching the summary having declined all three is still a decision,
        // not an interruption, so Home must not ask again.
        model.suppressHomeCardIfEverythingWasDeclined()
        guard model.finalize(destination: destination) else { return }
        onComplete(destination)
    }

    private func performSecondary() {
        switch model.draft.route {
        case .core(.firstCapture):
            model.skipCapture()
        case .core(.reveal):
            // An explicit "not now" for everything, so Home shows no nag card.
            if model.deferAllPowerUpsAndFinish() { onComplete(.home) }
        // Not always a plain deferral: a connector may need to record an outcome
        // or step out of a recovery state, so each owns what its secondary means.
        case .powerUp(.calendar): model.performCalendarSecondary()
        case .powerUp(.health): model.performHealthSecondary()
        case .powerUp(.eva): model.performEvaSecondary()
        case .powerUp(.complete):
            finishJourney(destination: .home)
        default:
            break
        }
    }

}

/// Failure keeps the user's work mounted and says what can be retried.
private struct LifeWeaveErrorBanner: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("We couldn't finish setting up LifeBoard.")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Text("Your choices are still here. \(message)")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 18)
        .accessibilityIdentifier(LifeWeaveAccessibilityID.errorBanner)
        .accessibilityElement(children: .combine)
    }
}
