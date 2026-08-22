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
    @State private var evaActivationTask: Task<Void, Never>?
    @State private var evaGrants = Set(EvaConsentPolicy.Grant.allCases)
    @State private var tourIndex = 0
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
            if model.step == .eva, (try? await EvaCloudSessionStore.shared.load()) != nil {
                await evaAccount.refresh()
                evaGrants = Set(evaAccount.consent?.grants ?? [])
            }
            if model.step == .firstWin {
                await model.prepareEvaHandoff()
            }
        }
        .onDisappear {
            evaActivationTask?.cancel()
            evaActivationTask = nil
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
            LifeMapTopBar(step: model.step, canGoBack: model.canGoBack, onBack: model.goBack)
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if let error = model.errorMessage {
                        LifeMapErrorBanner(message: error)
                    }
                    stepContent
                        .id(stepContentIdentity)
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
                isAuthenticated: evaAccount.isAuthenticated,
                isAdultEligible: evaAccount.isAdultEligible,
                isCloudReady: evaAccount.canUseCloud,
                isWorking: evaIsWorking,
                progressCaption: evaAccount.activationStage.progressCaption,
                errorMessage: evaErrorMessage,
                selectedGrants: evaGrants,
                onToggleGrant: toggleEvaGrant,
                onChooseOffline: chooseOfflineEva
            )
        case .tour:
            LifeMapTourStep(
                destination: tourDestination,
                index: tourIndex,
                total: Destination.allCases.count
            )
        case .firstWin:
            LifeMapFirstWinStep(
                isCloudReady: evaAccount.canUseCloud,
                prompts: model.openingPrompts
            )
        }
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

/// The dock, the EVA activation legs, and the hand-off.
///
/// A same-file extension, not a separate type: `check_file_size_guardrails.rb`
/// measures the largest *top-level declaration*, which is the number that
/// predicts the `-Onone` launch crash — Debug inlines computed `some View`
/// properties into their caller's stack frame. Keeping it in this file
/// preserves access to the view's `private` state.
extension LifeMapOnboardingView {
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
        case .reveal: "Show me around"
        case .calendar, .health, .reminders: "Continue"
        case .eva:
            if evaIsWorking { "Connecting…" }
            else if evaAccount.canUseCloud { "Continue" }
            else { "Continue with Cloud EVA" }
        case .tour: tourIndex + 1 < Destination.allCases.count ? "Next" : "Meet EVA"
        case .firstWin: evaAccount.canUseCloud ? "Open EVA" : "Go to LifeBoard"
        default: "Continue"
        }
    }

    /// Entering the app is always available once the map exists — the core
    /// payoff is complete at `.reveal`, and everything after it is optional.
    private var secondaryTitle: String? {
        switch model.step {
        case .reveal: "Power it up"
        case .calendar, .health, .reminders: "Enter LifeBoard"
        case .eva: "Finish later"
        case .tour: "Skip the tour"
        default: nil
        }
    }

    private var isPrimaryDisabled: Bool {
        switch model.step {
        case .desiredChange: model.draft.desiredChange == nil
        case .friction: model.draft.frictionIDs.isEmpty
        case .lifeAreas: model.draft.isLifeAreaSelectionValid == false
        case .capture: model.draft.isCaptureResolved == false
        case .eva: evaIsWorking
        default: false
        }
    }

    private func performPrimary() {
        switch model.step {
        case .eva:
            // Signing in is the primary action only until it has succeeded;
            // after that the primary simply moves on, so a connected user is
            // never invited to re-run an activation that spends an exchange.
            if evaAccount.canUseCloud {
                advance()
            } else {
                enableCloudEva()
            }
        case .tour:
            if tourIndex + 1 < Destination.allCases.count {
                tourIndex += 1
                model.feedback.light()
            } else {
                advance()
            }
        case .firstWin:
            handOffToEva()
        default:
            advance()
        }
    }

    private func performSecondary() {
        switch model.step {
        case .reveal:
            model.enterPowerUps()
        case .calendar, .health, .reminders, .eva:
            // "Enter LifeBoard" / "Finish later" still runs the closing phase —
            // the tour and the staged openers are the part every user gets.
            model.skipToClosing()
        case .tour:
            advance()
        default:
            break
        }
    }

    private func advance() {
        Task {
            if await model.advance() { onDismissFlow() }
        }
    }

    private func enableCloudEva() {
        guard evaIsWorking == false else { return }
        evaIsWorking = true
        evaErrorMessage = nil
        // Owned rather than fire-and-forget: a detached task outlives the flow and
        // keeps writing to torn-down state after the user taps "Finish later".
        evaActivationTask = Task { @MainActor in
            defer {
                evaIsWorking = false
                evaActivationTask = nil
            }
            do {
                try await evaAccount.activateCloud(
                    grants: evaGrants.sorted { $0.rawValue < $1.rawValue }
                )
                if let readinessError = evaAccount.readinessError() { throw readinessError }
                model.feedback.successSignature()
            } catch is CancellationError {
                evaErrorMessage = nil
            } catch let error as ASAuthorizationError where error.code == .canceled {
                evaErrorMessage = "Sign in was cancelled. You can try again or finish later."
            } catch {
                evaErrorMessage = Self.activationMessage(for: error)
            }
        }
    }

    /// A stalled request reads to the user as "the app is broken", so name the
    /// cause and the remedy instead of surfacing Foundation's bare
    /// "The request timed out."
    private static func activationMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return "EVA's server didn’t respond in time. Tap to try again — you won’t have to sign in twice."
            case .notConnectedToInternet, .networkConnectionLost:
                return "You’re offline. Reconnect and tap to try again, or finish later."
            default:
                break
            }
        }
        if let envelope = error as? EvaErrorEnvelope, envelope.retryable {
            return "\(envelope.message) Tap to try again."
        }
        return error.localizedDescription
    }

    /// Consent is a compare-and-swap on the server's revision, so it is written
    /// one toggle at a time and never retried — a replayed write would fail the
    /// CAS and read to the user as the switch refusing to move.
    private func toggleEvaGrant(_ grant: EvaConsentPolicy.Grant, enabled: Bool) {
        guard evaIsWorking == false else { return }
        var replacement = evaGrants
        if enabled { replacement.insert(grant) } else { replacement.remove(grant) }
        guard let policy = evaAccount.consent else {
            evaGrants = replacement
            return
        }
        evaIsWorking = true
        evaActivationTask = Task { @MainActor in
            defer {
                evaIsWorking = false
                evaActivationTask = nil
            }
            do {
                let updated = try await EvaCloudTransport.shared.updateConsent(
                    expectedRevision: policy.revision,
                    grants: replacement.sorted { $0.rawValue < $1.rawValue }
                )
                await evaAccount.refresh()
                evaGrants = Set(updated.grants)
            } catch is CancellationError {
                evaErrorMessage = nil
            } catch {
                evaErrorMessage = Self.activationMessage(for: error)
                evaGrants = Set(evaAccount.consent?.grants ?? [])
            }
        }
    }

    private func chooseOfflineEva() {
        Task {
            await model.chooseOfflineEva()
            model.skipToClosing()
        }
    }

    /// Stage the openers, mark EVA activation handled, then open the tab.
    ///
    /// `markCompleted` runs whether or not cloud is ready: the point of merging
    /// the flows is that nobody meets a second activation wizard, and a user who
    /// declined here would otherwise land straight back in the one this replaces.
    private func handOffToEva() {
        model.completeEvaHandoff()
        if evaAccount.canUseCloud {
            NotificationCenter.default.post(name: .lifeboardOpenChatDeepLink, object: nil)
        }
        onDismissFlow()
    }

    /// Tour beats are five screens inside one step, so the transition has to
    /// key on the beat as well or four of the five would appear without motion.
    private var stepContentIdentity: String {
        model.step == .tour ? "tour.\(tourIndex)" : "step.\(model.step.rawValue)"
    }

    private var tourDestination: Destination {
        let all = Destination.allCases
        return all[min(max(0, tourIndex), all.count - 1)]
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
