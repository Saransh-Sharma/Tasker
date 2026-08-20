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

    /// The map yields before the copy does, always.
    ///
    /// `DESIGN.md`: "At large text sizes, use one content column … Never shrink
    /// type to preserve a layout." So the weave gives up its height first, then
    /// its labels, then itself — the question is what the screen is for.
    private var weaveHeightFraction: CGFloat {
        if dynamicTypeSize >= .accessibility3 { return 0 }
        if dynamicTypeSize >= .accessibility1 { return 0.11 }
        switch model.step {
        // Arrival and Reveal are the two beats where the map *is* the content,
        // so they keep a little more room. Every question screen gives it back:
        // the map is there to acknowledge the answer, not to compete with it.
        case .arrival, .reveal: return 0.22
        default: return 0.16
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
        return min(proportional, model.step == .reveal ? 240 : 200)
    }

    var body: some View {
        ZStack {
            LifeMapOnboardingBackground()
            GeometryReader { proxy in
                VStack(spacing: Theme.Spacing.md) {
                    LifeWeaveTopBar(
                        step: model.step,
                        canGoBack: model.previousStep != nil,
                        onBack: model.goBack
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
                        onSecondary: performSecondary
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier(LifeWeaveAccessibilityID.flow)
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch model.step {
            case .arrival:
                LifeWeaveArrivalStep()
            case .intent:
                LifeWeaveIntentStep(model: model)
            case .lifeAreas:
                LifeWeaveLifeAreasStep(model: model)
            case .dayShape:
                LifeWeaveDayShapeStep(model: model)
            case .firstCapture:
                LifeWeaveCaptureStep(model: model)
            case .reveal:
                LifeWeaveRevealStep(model: model)
            }
        }
        .accessibilityIdentifier(LifeWeaveAccessibilityID.step(model.step))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Dock

    private var primaryTitle: String {
        switch model.step {
        case .arrival: "Shape my LifeBoard"
        case .intent: "Continue"
        case .lifeAreas: "Shape my map"
        case .dayShape: "Use this rhythm"
        case .firstCapture: capturePrimaryTitle
        case .reveal: "Start my day"
        }
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
        switch model.step {
        case .firstCapture:
            model.draft.stagedCapture == nil && model.draft.skippedCapture == false ? "Skip for now" : nil
        case .reveal: "Personalize more"
        default: nil
        }
    }

    private var isPrimaryDisabled: Bool {
        switch model.step {
        case .intent: model.draft.intent == nil
        case .lifeAreas: model.draft.isLifeAreaSelectionValid == false
        case .firstCapture:
            // A resolved step — skipped, or reviewed — can always continue. Without
            // the `isCaptureResolved` term, "Skip for now" left the primary
            // disabled and stranded the user on the screen they had just declined.
            model.isResolvingCapture
                || (model.draft.isCaptureResolved == false
                    && model.draft.stagedCapture == nil
                    && model.captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

            if model.step == .reveal {
                guard model.finalize(destination: .home) else { return }
                onComplete(.home)
                return
            }

            _ = await model.advance()
        }
    }

    private func performSecondary() {
        switch model.step {
        case .firstCapture:
            model.skipCapture()
        case .reveal:
            guard model.finalize(destination: .setupCenter) else { return }
            onComplete(.setupCenter)
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
