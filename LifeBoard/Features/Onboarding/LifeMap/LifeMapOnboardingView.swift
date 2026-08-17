import AuthenticationServices
import LifeBoardTokens
import LifeBoardUI
import SwiftUI
import UIKit

/// The Life Map flow shell.
///
/// This type owns layout, chrome, sheets, and lifecycle only. Every step body
/// lives in its own `struct … : View` (see `LifeMapOnboardingIntentSteps`,
/// `…ShapeSteps`, `…RevealSteps`) so that Debug — which gives every SwiftUI
/// temporary its own stack slot and inlines computed `some View` properties into
/// their caller's frame — never has to materialise the whole flow inside one
/// stack frame. The step router below is intentionally shallow: each branch is a
/// single struct initialiser, not a view tree.
struct LifeMapOnboardingView: View {
    @StateObject var model: LifeMapOnboardingModel
    let onDismissFlow: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var firstLightTrigger = 0
    @State private var clayTrigger = 0
    @State private var cardMorphTrigger = 0
    @State private var completionTrigger = 0
    @State private var showTuneSheet = false
    @State private var evaAccount = EvaCloudAccountState.shared
    @State private var evaIsWorking = false
    @State private var evaErrorMessage: String?
    @State private var contentSafeAreaInsets = LifeMapOnboardingView.windowSafeAreaInsets
    @State private var bridgedScenePhase: ScenePhase =
        UIApplication.shared.applicationState == .background ? .background : .active

    private var reduceMotion: Bool { MotionOverride.resolve(systemReduceMotion) }

    var body: some View {
        ZStack {
            LifeMapOnboardingBackground()

            GeometryReader { proxy in
                let isWide = horizontalSizeClass == .regular && proxy.size.width > 760
                let usableHeight = max(
                    0,
                    proxy.size.height - contentSafeAreaInsets.top - contentSafeAreaInsets.bottom
                )
                Group {
                    if isWide {
                        wideLayout()
                    } else {
                        compactLayout(availableHeight: usableHeight)
                    }
                }
                .frame(width: proxy.size.width, height: usableHeight, alignment: .top)
                .padding(.top, contentSafeAreaInsets.top)
                .padding(.bottom, contentSafeAreaInsets.bottom)
            }

            if model.isCommitting {
                LifeMapAssemblyOverlay()
            }
        }
        .lifeboardFirstLight(trigger: firstLightTrigger, tint: Color.lifeboard(.accentPrimary))
        .lifeboardCompletionBurst(trigger: completionTrigger)
        .accessibilityIdentifier(LifeMapAccessibilityID.flow)
        .sheet(item: $model.inspectedRoot) { root in
            LifeMapProductPreview(destination: root)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTuneSheet) {
            LifeMapModuleTuneSheet(
                selectedIDs: model.selectedModuleIDs,
                onToggle: model.toggleModule
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            refreshContentSafeAreaInsets()
            firstLightTrigger += 1
            model.feedback.prepare()
        }
        .onChange(of: model.step) { old, new in
            cardMorphTrigger += 1
            // Fires only on the transition *into* reveal, and only after
            // `assemble()` has committed — celebration must follow persistence,
            // never precede or predict it.
            if old != .reveal && new == .reveal { completionTrigger += 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            bridgedScenePhase = .active
            refreshContentSafeAreaInsets()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            bridgedScenePhase = .inactive
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            bridgedScenePhase = .background
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            refreshContentSafeAreaInsets()
        }
        .task(id: model.step) {
            guard model.step == .evaPowerUp,
                  (try? await EvaCloudSessionStore.shared.load()) != nil else { return }
            await evaAccount.refresh()
        }
        // UIHostingController-backed flows do not participate in a SwiftUI App
        // scene, so their raw `scenePhase` can read `.background` while fully
        // visible. Bridging UIKit lifecycle keeps the shader, glass, and haptic
        // gates live while on screen and quiet once it is not.
        .environment(\.scenePhase, bridgedScenePhase)
        // The UIKit host otherwise proposes only its safe rectangle. Let the
        // media own the physical display, then re-inset controls with the real
        // window geometry captured above.
        .ignoresSafeArea(.container, edges: .all)
    }

    private static var windowSafeAreaInsets: EdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first(where: { $0.activationState == .foregroundActive })?.windows.first
        let insets = window?.safeAreaInsets ?? .zero
        return EdgeInsets(
            top: insets.top,
            leading: insets.left,
            bottom: insets.bottom,
            trailing: insets.right
        )
    }

    private func refreshContentSafeAreaInsets() {
        contentSafeAreaInsets = Self.windowSafeAreaInsets
    }

    // MARK: - Layout

    private func wideLayout() -> some View {
        HStack(spacing: Theme.Spacing.xxl + 6) {
            mapCanvas
                .frame(maxWidth: 520)
            contentColumn
                .frame(maxWidth: 560)
        }
        .padding(.horizontal, Theme.Spacing.xxxl + 2)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private func compactLayout(availableHeight: CGFloat) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            mapCanvas
                .frame(height: min(390, max(250, availableHeight * 0.43)))
            contentColumn
        }
        .padding(.horizontal, Theme.Spacing.xl - 2)
        .padding(.top, Theme.Spacing.sm)
    }

    private var mapCanvas: some View {
        LifeMapOrbitCanvas(
            scene: model.sceneModel,
            step: model.step,
            selectedRoot: model.inspectedRoot,
            onRootTapped: { root in
                // Roots only become inspectable once the flow has explained what
                // they are. Before that a tap would open a preview for a concept
                // the user has not met yet.
                guard model.step.rawValue >= LifeMapOnboardingStep.connections.rawValue else { return }
                model.inspectedRoot = root
                model.feedback.light()
            }
        )
        .padding(Theme.Spacing.sm)
        .accessibilityIdentifier(LifeMapAccessibilityID.canvas)
    }

    private var contentColumn: some View {
        VStack(spacing: Theme.Spacing.md + 2) {
            LifeMapTopBar(step: model.step, onBack: model.goBack)
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if let error = model.errorMessage {
                        LifeMapErrorBanner(message: error)
                    }
                    stepContent
                        .id(model.step)
                        .transition(stepTransition)
                }
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .scrollIndicators(.hidden)
            dock
        }
        .frame(maxHeight: .infinity)
        .lifeBoardMotion(.route, value: model.step)
        .lifeboardCardMorphWarp(origin: .bottom, trigger: cardMorphTrigger)
    }

    // MARK: - Step router

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .welcome:
            LifeMapWelcomeStep()
        case .desiredChange:
            LifeMapDesiredChangeStep(selected: model.draft.desiredChange) { value in
                model.selectDesiredChange(value)
                clayTrigger += 1
            }
        case .friction:
            LifeMapFrictionStep(selectedIDs: model.draft.frictionIDs) { value in
                model.toggleFriction(value)
                clayTrigger += 1
            }
        case .lifeAreas:
            LifeMapLifeAreasStep(selectedIDs: model.draft.orderedLifeAreaTemplateIDs) { template in
                model.toggleLifeArea(template)
                clayTrigger += 1
            }
        case .priorities:
            LifeMapPrioritiesStep(templates: model.selectedAreaTemplates, onMove: model.moveLifeArea)
        case .capacity:
            LifeMapCapacityStep(dayShape: model.draft.dayShape, onUpdate: model.updateDayShape)
        case .connections:
            LifeMapConnectionsStep(
                selectedGroups: model.selectedModuleGroups,
                onToggle: { group in
                    model.toggleModuleGroup(group)
                    clayTrigger += 1
                },
                onTune: { showTuneSheet = true }
            )
        case .capture:
            LifeMapCaptureStep(
                text: $model.captureText,
                staged: model.draft.stagedCapture,
                areaTemplates: model.selectedAreaTemplates,
                isResolving: model.isResolvingCapture,
                cardMorphTrigger: cardMorphTrigger,
                onInterpret: { Task { await model.resolveCapture() } },
                onReview: { kind, areaID in model.reviewCapture(kind: kind, areaID: areaID) },
                onSkip: model.skipCapture
            )
        case .reveal:
            LifeMapRevealStep(
                capture: model.draft.stagedCapture,
                placements: model.committedHomePlacements
            )
        case .permissionsPowerUp:
            LifeMapPermissionsStep(
                permissions: model.requestablePermissions,
                grantedIDs: model.draft.permissionIDs,
                inFlight: model.permissionInFlight,
                onRequest: { kind in Task { await model.requestPermission(kind) } },
                onDefer: model.deferPermission
            )
        case .evaPowerUp:
            LifeMapEvaStep(
                isAuthenticated: evaAccount.isAuthenticated,
                isAdultEligible: evaAccount.isAdultEligible,
                isCloudReady: evaAccount.canUseCloud,
                isWorking: evaIsWorking,
                errorMessage: evaErrorMessage
            )
        }
    }

    // MARK: - Dock

    private var dock: some View {
        LifeMapBottomDock(
            primaryTitle: primaryTitle,
            secondaryTitle: secondaryTitle,
            isPrimaryDisabled: isPrimaryDisabled,
            clayTrigger: clayTrigger,
            onPrimary: performPrimary,
            onSecondary: performSecondary
        )
    }

    private var primaryTitle: String {
        switch model.step {
        case .welcome: "Build my Life Map"
        case .capture: "Connect it"
        case .reveal: "Enter LifeBoard"
        case .permissionsPowerUp: "Continue to EVA"
        case .evaPowerUp:
            if evaIsWorking { "Connecting…" }
            else if evaAccount.canUseCloud { "Continue EVA setup" }
            else { "Sign in with Apple" }
        default: "Continue"
        }
    }

    /// Entering the app is always available before permissions or EVA — the core
    /// payoff is complete at `.reveal`, and everything after it is optional.
    private var secondaryTitle: String? {
        switch model.step {
        case .reveal: "Power it up"
        case .permissionsPowerUp: "Enter LifeBoard"
        case .evaPowerUp: "Finish later"
        default: nil
        }
    }

    private var isPrimaryDisabled: Bool {
        switch model.step {
        case .desiredChange: model.draft.desiredChange == nil
        case .friction: model.draft.frictionIDs.isEmpty
        case .lifeAreas: model.draft.isLifeAreaSelectionValid == false
        case .capture: model.draft.isCaptureResolved == false
        case .evaPowerUp: evaIsWorking
        default: false
        }
    }

    private func performPrimary() {
        switch model.step {
        case .reveal:
            onDismissFlow()
        case .evaPowerUp:
            if evaAccount.canUseCloud {
                openEvaSetup()
            } else {
                enableCloudEva()
            }
        default:
            Task {
                if await model.advance() { onDismissFlow() }
            }
        }
    }

    private func performSecondary() {
        switch model.step {
        case .reveal:
            Task { _ = await model.advance() }
        case .permissionsPowerUp, .evaPowerUp:
            onDismissFlow()
        default:
            break
        }
    }

    private func enableCloudEva() {
        guard evaIsWorking == false else { return }
        evaIsWorking = true
        evaErrorMessage = nil
        Task { @MainActor in
            defer { evaIsWorking = false }
            do {
                try await evaAccount.activateCloud()
                if let readinessError = evaAccount.readinessError() { throw readinessError }
                model.feedback.successSignature()
            } catch let error as ASAuthorizationError where error.code == .canceled {
                evaErrorMessage = "Sign in was cancelled. You can try again or finish later."
            } catch {
                evaErrorMessage = error.localizedDescription
            }
        }
    }

    private func openEvaSetup() {
        NotificationCenter.default.post(name: .lifeboardOpenChatDeepLink, object: nil)
        onDismissFlow()
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }
}

private struct LifeMapErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.lifeboard(.caption1))
            .foregroundStyle(Color.lifeboard(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .lifeBoardClaySurface(.resting, cornerRadius: 16, fill: Color.lifeboard(.statusDanger).opacity(0.18))
            .accessibilityIdentifier(LifeMapAccessibilityID.error)
    }
}
