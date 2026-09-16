import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// The four-screen first run.
///
/// One persistent background, one persistent weave, and a step-shaped content
/// column between them. Welcome and intent, life areas, one real thing, Ready.
/// Connections open as sheets over Ready and return there.
struct LifeWeaveOnboardingView: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    let onComplete: (LifeWeaveCompletionDestination) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var clayTrigger = 0
    /// Which way the last step change went, so content arrives from the side
    /// the user is travelling toward.
    @State private var isMovingForward = true
    /// The capture sentence travels from its field to the receipt through this.
    @Namespace private var pillNamespace

    /// Connections open as sheets over the Ready screen, so the flow itself only
    /// ever shows one of the four core screens.
    private var displayedStep: LifeWeaveStep {
        if model.powerUpStep != nil { return .reveal }
        return LifeWeaveMigration.streamlinedStep(for: model.step)
    }

    // The dock's titles are derived from connector state, and connector state
    // does not live in the draft. Without these the primary button would keep a
    // stale label through a permission return, a first sync, or an EVA
    // activation completing — none of which is a draft write.
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @StateObject private var calendarSession = CalendarPowerUpSession.shared

    /// The map shows up where it has something to say.
    ///
    /// On the areas screen it grows a node for every pick; on the Ready screen
    /// it holds the finished result. The welcome has nothing on it yet, and on
    /// the capture screen the keyboard needs the room.
    private var weaveHeightFraction: CGFloat {
        if dynamicTypeSize >= .accessibility3 { return 0 }
        switch displayedStep {
        case .lifeAreas, .dayShape: return dynamicTypeSize >= .accessibility1 ? 0.10 : 0.16
        case .reveal: return dynamicTypeSize >= .accessibility1 ? 0.11 : 0.20
        case .arrival, .intent, .firstCapture: return 0
        }
    }

    /// A share of the window on a phone, but a capped height on iPad, where a
    /// fraction of a tall window is mostly empty field.
    private func weaveHeight(in size: CGSize) -> CGFloat {
        let proportional = size.height * weaveHeightFraction
        guard horizontalSizeClass == .regular else { return proportional }
        return min(proportional, displayedStep == .reveal ? 240 : 200)
    }

    private var stepTransition: AnyTransition {
        guard MotionOverride.resolve(systemReduceMotion) == false else { return .opacity }
        let edge: Edge = isMovingForward ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .opacity
        )
    }

    var body: some View {
        ZStack {
            LifeMapOnboardingBackground()
            GeometryReader { proxy in
                VStack(spacing: Theme.Spacing.md) {
                    LifeWeaveTopBar(
                        step: displayedStep,
                        canGoBack: model.previousStep != nil,
                        onBack: goBack
                    )

                    if weaveHeightFraction > 0 {
                        LifeWeaveCanvas(presentation: LifeWeavePresentation.make(from: model.draft))
                            .frame(height: weaveHeight(in: proxy.size))
                            .accessibilityIdentifier(LifeWeaveAccessibilityID.canvas)
                            .transition(.opacity)
                    }

                    ScrollView {
                        stepContent
                            .padding(.bottom, Theme.Spacing.lg)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
                    // The system edge effect drew a hard-edged band behind the
                    // dock over the hero video. The glass dock already separates
                    // itself from the content scrolling under it.
                    .scrollEdgeEffectHidden(true, for: .bottom)
                    // The dock rides the keyboard. As a VStack sibling it was
                    // only incidentally above it; as an inset it is guaranteed,
                    // and the scroll content gets the right bottom clearance.
                    .safeAreaInset(edge: .bottom, spacing: Theme.Spacing.sm) {
                        VStack(spacing: Theme.Spacing.sm) {
                            if model.errorMessage != nil {
                                LifeWeaveErrorBanner(onRetry: performPrimary)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                            .lifeBoardMotion(.controlMorph, value: primaryTitle)
                        }
                        .lifeBoardMotion(.contentInsertion, value: model.errorMessage)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .lifeBoardMotion(.route, value: displayedStep)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LifeWeaveAccessibilityID.flow)
        .task { _ = await evaAccess.ensureActivated(source: .onboarding) }
        .onChange(of: model.step) { previous, next in
            let order = LifeWeaveStep.streamlined
            let from = order.firstIndex(of: LifeWeaveMigration.streamlinedStep(for: previous)) ?? 0
            let to = order.firstIndex(of: LifeWeaveMigration.streamlinedStep(for: next)) ?? 0
            isMovingForward = to >= from
        }
        .sheet(item: Binding(
            get: { model.powerUpStep },
            set: { if $0 == nil { model.deferCurrentPowerUp() } }
        )) { connector in
            connectorSheet(connector)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch displayedStep {
            case .arrival, .intent: LifeWeaveIntentStep(model: model)
            case .lifeAreas, .dayShape: LifeWeaveLifeAreasStep(model: model)
            case .firstCapture: LifeWeaveCaptureStep(model: model, pillNamespace: pillNamespace)
            case .reveal: LifeWeaveRevealStep(model: model, pillNamespace: pillNamespace)
            }
        }
        .id(displayedStep)
        .transition(stepTransition)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LifeWeaveAccessibilityID.step(displayedStep))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func powerUpContent(_ step: LifeWeavePowerUpStep) -> some View {
        switch step {
        case .calendar: CalendarPowerUpView(model: model)
        // Health opens the shared `HealthConnectionSheet`; see `connectorSheet`.
        case .health: EmptyView()
        case .eva: EvaPowerUpView(model: model)
        }
    }

    // MARK: - Dock

    private var trimmedCaptureText: String {
        model.captureText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// One stable verb per screen. When the primary cannot act yet, it says
    /// what is missing instead of greying out a "Continue" that explains nothing.
    private var primaryTitle: String {
        switch displayedStep {
        case .arrival, .intent:
            model.draft.intent == nil ? LifeWeaveCopy.Dock.pickOne : LifeWeaveCopy.Dock.continue
        case .lifeAreas, .dayShape:
            model.lifeAreasStillNeeded > 0
                ? LifeWeaveCopy.Dock.pickMore(model.lifeAreasStillNeeded)
                : LifeWeaveCopy.Dock.continue
        case .firstCapture:
            // After a skip there is nothing to save; the same button finishes.
            model.draft.skippedCapture && trimmedCaptureText.isEmpty
                ? LifeWeaveCopy.Dock.continue
                : LifeWeaveCopy.Dock.save
        case .reveal:
            LifeWeaveCopy.Dock.startMyDay
        }
    }

    private var secondaryTitle: String? {
        switch displayedStep {
        case .firstCapture:
            model.draft.isCaptureResolved ? nil : LifeWeaveCopy.Dock.skip
        default:
            nil
        }
    }

    private var isPrimaryDisabled: Bool {
        guard model.isCommitting == false else { return true }
        switch displayedStep {
        case .arrival, .intent: return model.draft.intent == nil
        case .lifeAreas, .dayShape: return model.draft.isLifeAreaSelectionValid == false
        case .firstCapture:
            return trimmedCaptureText.isEmpty && model.draft.isCaptureResolved == false
        case .reveal: return false
        }
    }

    private func goBack() {
        isMovingForward = false
        model.goBack()
    }

    private func performPrimary() {
        clayTrigger += 1
        isMovingForward = true
        Task { @MainActor in
            switch displayedStep {
            case .firstCapture:
                if trimmedCaptureText.isEmpty == false, model.draft.stagedCapture?.isReviewed != true {
                    await model.saveCapture()
                }
                await model.advance()
            case .reveal:
                if model.deferAllPowerUpsAndFinish() { onComplete(.home) }
            default:
                await model.advance()
            }
        }
    }

    private func performSecondary() {
        guard displayedStep == .firstCapture else { return }
        isMovingForward = true
        model.skipCapture()
        Task { await model.advance() }
    }

    private func performPowerUpPrimary(_ step: LifeWeavePowerUpStep) async {
        switch step {
        case .calendar: await model.performCalendarPrimary()
        case .health: break
        case .eva: await model.performEvaPrimary()
        }
    }

    /// One layout for every connection: what it gives, one trust line, one
    /// primary, and Not now. Health keeps its own shared sheet, which already
    /// follows the same shape and is reused outside onboarding.
    @ViewBuilder
    private func connectorSheet(_ connector: LifeWeavePowerUpStep) -> some View {
        if connector == .health {
            HealthConnectionSheet(context: .init(.health, from: .onboarding), onAuthorizationResult: { outcome in
                guard model.powerUpStep == .health, outcome != .failed else { return }
                model.finishConnector()
            })
        } else {
            NavigationStack {
                ScrollView {
                    powerUpContent(connector)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.sm)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: Theme.Spacing.xs) {
                        Button(connector == .eva ? model.evaPrimaryTitle : model.calendarPrimaryTitle) {
                            Task { await performPowerUpPrimary(connector) }
                        }
                        .buttonStyle(.lifeBoardPrimary)
                        .disabled(connector == .eva ? model.isEvaPrimaryDisabled : model.isCalendarPrimaryDisabled)
                        .accessibilityIdentifier("onboarding.connection.primary")
                        Button(LifeWeaveCopy.Dock.notNow) { model.deferCurrentPowerUp() }
                            .lifeboardFont(.bodyStrong)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier("onboarding.connection.notNow")
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Color.lifeboard(.bgElevated))
                }
                .background(Color.lifeboard(.bgElevated))
                .onChange(of: evaAccess.state) { _, state in
                    if connector == .eva, state == .ready {
                        model.recordEvaActivation(ready: true, pending: false)
                        model.finishConnector()
                    }
                }
                .navigationTitle(LifeWeaveCopy.Connection.name(connector))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button(LifeWeaveCopy.Dock.close) { model.deferCurrentPowerUp() }
                } }
                .sheet(isPresented: $model.showsOfflineSetup) {
                    NavigationStack {
                        ModelsSettingsView().toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button(LifeWeaveCopy.Dock.done) { model.showsOfflineSetup = false }
                        } }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.lifeboard(.bgElevated))
            .presentationCornerRadius(30)
        }
    }
}

/// Failure keeps the user's work mounted and offers the one thing to do next.
///
/// It used to append the raw `localizedDescription`, which on a first run is
/// the least helpful sentence the app could say. That now goes to the log.
private struct LifeWeaveErrorBanner: View {
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .lifeboardFont(.title3)
                .foregroundStyle(Color.lifeboard(.statusWarning))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(LifeWeaveCopy.Failure.title)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(LifeWeaveCopy.Failure.body)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Spacing.xs)
            Button(LifeWeaveCopy.Failure.retry, action: onRetry)
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .frame(minHeight: 44)
                .accessibilityIdentifier("onboarding.lifeweave.error.retry")
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LifeWeaveAccessibilityID.errorBanner)
    }
}
