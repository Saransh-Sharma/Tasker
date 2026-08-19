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
    let onDismissFlow: () -> Void

    @StateObject private var eva = LifeWeaveEvaActivation()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var clayTrigger = 0

    /// The map yields before the copy does, always.
    ///
    /// `DESIGN.md`: "At large text sizes, use one content column … Never shrink
    /// type to preserve a layout." So the weave gives up its height first, then
    /// its labels, then itself — the question is what the screen is for.
    private var weaveHeightFraction: CGFloat {
        if dynamicTypeSize >= .accessibility3 { return 0 }
        if dynamicTypeSize >= .accessibility1 { return 0.14 }
        switch model.step {
        case .arrival, .reveal: return 0.30
        default: return 0.22
        }
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

                    if weaveHeightFraction > 0, model.step.isPowerUp == false {
                        LifeWeaveCanvas(presentation: LifeWeavePresentation.make(from: model.draft))
                            .frame(height: proxy.size.height * weaveHeightFraction)
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
        .task {
            await eva.refresh()
        }
        .onDisappear { eva.cancel() }
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
            case .calendar:
                LifeMapCalendarStep(
                    isGranted: model.isGranted(.calendar),
                    isDenied: model.isDenied(.calendar),
                    isBusy: model.permissionInFlight != nil,
                    sections: CalendarPresentation.chooserSections(from: model.availableCalendars),
                    selectedIDs: model.draft.selectedCalendarIDs,
                    onRequest: { Task { await model.requestPermission(.calendar) } },
                    onToggle: model.toggleCalendar,
                    onSkip: { model.deferPermission(.calendar) }
                )
            case .health:
                LifeMapHealthStep(
                    isConnected: model.isGranted(.appleHealth),
                    isBusy: model.permissionInFlight != nil,
                    writableDomains: model.writableHealthDomains,
                    writeBackDomainIDs: model.draft.healthWriteBackDomainIDs,
                    onConnect: { Task { await model.requestPermission(.appleHealth) } },
                    onToggleWriteBack: { domain, enabled in
                        Task { await model.setHealthWriteBack(enabled, for: domain) }
                    },
                    onSkip: { model.deferPermission(.appleHealth) }
                )
            case .reminders:
                LifeMapRemindersStep(
                    isGranted: model.isGranted(.notifications),
                    isDenied: model.isDenied(.notifications),
                    isBusy: model.permissionInFlight != nil,
                    onRequest: { Task { await model.requestPermission(.notifications) } },
                    onSkip: { model.deferPermission(.notifications) }
                )
            case .eva:
                LifeMapEvaStep(
                    isAuthenticated: eva.account.isAuthenticated,
                    isAdultEligible: eva.account.isAdultEligible,
                    isCloudReady: eva.account.canUseCloud,
                    isWorking: eva.isWorking,
                    progressCaption: eva.account.activationStage.progressCaption,
                    errorMessage: eva.errorMessage,
                    selectedGrants: eva.grants,
                    onToggleGrant: eva.toggleGrant,
                    onChooseOffline: { Task { await model.chooseOfflineEva() } }
                )
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
        case .calendar, .health, .reminders: "Continue"
        case .eva:
            if eva.isWorking { "Connecting…" }
            else if eva.account.canUseCloud { "Continue" }
            else { "Connect EVA" }
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
        case .reveal: model.visiblePowerUpChain.isEmpty ? nil : "Set up connections"
        case .calendar, .health, .reminders, .eva: "Not now"
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
        case .eva: eva.isWorking
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

            if model.step == .eva, eva.account.canUseCloud == false {
                eva.activate { model.feedback.successSignature() }
                return
            }

            if await model.advance() {
                onDismissFlow()
            }
        }
    }

    private func performSecondary() {
        switch model.step {
        case .firstCapture:
            model.skipCapture()
        case .reveal:
            model.enterPowerUps()
        case .calendar, .health, .reminders, .eva:
            Task { @MainActor in
                if await model.advance() { onDismissFlow() }
            }
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
