import SwiftUI

/// One action a connector offers, resolved once by the screen.
///
/// The screen hands this to whichever surface should own it: the hero when the
/// connector is the focus, its own card otherwise. That is what keeps the
/// primary action singular — the same button never appears twice — and what
/// keeps each accessibility identifier existing exactly once no matter which
/// connector is currently being asked about.
struct SetupCenterAction {
    let title: String
    let identifier: String
    let isEnabled: Bool
    let perform: () -> Void
}

struct SetupCenterView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    let onOpenCalendarChooser: () -> Void
    let onNavigate: (SettingsDetailRoute) -> Void

    @Environment(PresentationPreferences.self) private var preferences
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @State private var showsHealthDisclosure = false
    @State private var showsEvaDismissNudge = false

    private var status: SetupCenterStatus {
        SetupCenterStatus.resolve(
            calendarAuthorization: settingsViewModel.calendarAuthorizationStatus,
            notificationPermissionRequested: PermissionPromptState.hasRequested(.notifications),
            notificationPermissionDenied: settingsViewModel.isPermissionDenied,
            healthStatuses: healthStore.statuses,
            healthHasObservableData: healthStore.aggregates.isEmpty == false,
            evaIsActivated: evaAccess.state == .ready
        )
    }

    // The screen does not paint its own canvas or scaffold: pushed routes are
    // already wrapped in `ScreenScaffold` and the daypart atmosphere by
    // `FoundationShellDestinations`. Adding a second one here would nest a
    // scaffold inside a scaffold, which resolves to an inert canvas and buys
    // nothing — the same doctrine `TrackFoundationRootView` states at length.
    var body: some View {
        let status = status
        let focus = SetupCenterFocus.resolve(status)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                SetupCenterFocusSection(
                    focus: focus,
                    palette: DaypartTokens.palette(for: preferences.resolvedDaypart()),
                    action: focusAction(for: focus)
                )
                SetupCenterCalendarSection(
                    state: status.calendar,
                    summary: settingsViewModel.calendarStatusSummary,
                    action: focus.target == .calendar ? nil : calendarAction(focus)
                )
                SetupCenterHealthSection(
                    state: status.health,
                    access: status.healthAccess,
                    action: focus.target == .health ? nil : healthAction(focus)
                )
                SetupCenterRemindersSection(
                    state: status.reminders,
                    action: focus.target == .reminders ? nil : remindersAction(focus)
                )
                SetupCenterEvaSection(
                    state: status.eva,
                    accessState: evaAccess.state,
                    progressCaption: evaAccess.account.activationStage.progressCaption,
                    errorMessage: evaAccess.errorMessage,
                    grants: grantBindings,
                    action: focus.target == .eva ? nil : evaAction,
                    onDecline: { showsEvaDismissNudge = true },
                    onChooseOffline: chooseOfflineEva
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            // Measured clearance for the floating dock. `DESIGN.md`: "content
            // must never disappear behind the dock or composer." At 32pt the
            // Reminders and EVA cards sat underneath it.
            .padding(.bottom, ClayLayoutMetrics.bottomDockClearance)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Setup Center")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("setupCenter.root")
        .task {
            await ProductTelemetry.shared.record(.setupCenterOpened)
            settingsViewModel.reload()
            await healthStore.bootstrap()
            let accessState = await evaAccess.hydrate()
            if accessState != .ready {
                await ProductTelemetry.shared.record(.evaSetupCenterCTAShown)
            }
        }
        .sheet(isPresented: $showsHealthDisclosure) {
            SetupCenterHealthDisclosureSheet(
                readState: status.healthAccess.readState,
                onCancel: { showsHealthDisclosure = false },
                onConfirm: {
                    showsHealthDisclosure = false
                    Task {
                        await healthStore.connect(
                            domains: Set(HealthDomain.allCases),
                            enableWriteBack: true
                        )
                    }
                }
            )
        }
        .confirmationDialog(
            "Use EVA’s smart layer?",
            isPresented: $showsEvaDismissNudge,
            titleVisibility: .visible
        ) {
            Button("Continue with Cloud EVA") { activateGuestEva() }
            Button("Set up Offline EVA") {
                Task { await ProductTelemetry.shared.record(.evaActivationDismissed, outcome: "offline_settings") }
                evaAccess.selectOffline()
                onNavigate(.llm)
            }
            Button("Not now", role: .cancel) {
                Task { await ProductTelemetry.shared.record(.evaActivationDismissed, outcome: "not_now") }
            }
        } message: {
            Text("Cloud EVA can plan with the LifeBoard context you choose, ground suggestions in your day, and carry forward only memories you approve.")
        }
    }
}

// MARK: - Actions

private extension SetupCenterView {
    /// The hero's action is whichever connector it is asking about.
    func focusAction(for focus: SetupCenterFocus) -> SetupCenterAction? {
        switch focus.target {
        case .calendar: calendarAction(focus)
        case .health: healthAction(focus)
        case .reminders: remindersAction(focus)
        case .eva: evaAction
        case .complete: nil
        }
    }

    func calendarAction(_ focus: SetupCenterFocus) -> SetupCenterAction {
        let isAuthorized = settingsViewModel.calendarAuthorizationStatus.isAuthorizedForRead
        return SetupCenterAction(
            title: focus.target == .calendar
                ? (focus.primaryTitle ?? "Connect Calendar")
                : (isAuthorized ? "Choose calendars" : "Connect Calendar"),
            identifier: "setupCenter.calendar.action",
            isEnabled: true
        ) {
            if isAuthorized {
                onOpenCalendarChooser()
            } else {
                settingsViewModel.requestCalendarPermission()
            }
        }
    }

    func healthAction(_ focus: SetupCenterFocus) -> SetupCenterAction {
        SetupCenterAction(
            title: focus.target == .health
                ? (focus.primaryTitle ?? "Review Health access")
                : (status.healthAccess.readState == .notRequested ? "Review Health access" : "Review Health settings"),
            identifier: "setupCenter.health.action",
            isEnabled: true
        ) {
            showsHealthDisclosure = true
        }
    }

    func remindersAction(_ focus: SetupCenterFocus) -> SetupCenterAction {
        SetupCenterAction(
            title: "Open Reminders",
            identifier: "setupCenter.reminders.action",
            isEnabled: true
        ) {
            onNavigate(.reminders)
        }
    }

    /// EVA's action is whatever its activation state currently affords, so the
    /// hero and the card can never disagree about what pressing it does.
    /// `nil` while a request is in flight or once it is ready: neither state has
    /// an action, and inventing one would be a button that does nothing.
    var evaAction: SetupCenterAction? {
        switch evaAccess.state {
        case .needsDisclosure:
            SetupCenterAction(
                title: "Continue with Cloud EVA",
                identifier: "setupCenter.eva.activate",
                isEnabled: evaAccess.isWorking == false,
                perform: activateGuestEva
            )
        case .temporarilyUnavailable:
            SetupCenterAction(
                title: "Retry Cloud EVA",
                identifier: "setupCenter.eva.retry",
                isEnabled: evaAccess.isWorking == false,
                perform: retryGuestEva
            )
        case .appleReauthenticationRequired:
            SetupCenterAction(
                title: "Reconnect with Apple",
                identifier: "setupCenter.eva.reconnectApple",
                isEnabled: evaAccess.isWorking == false,
                perform: reconnectAppleEva
            )
        case .quotaExhausted, .ageBlocked:
            SetupCenterAction(
                title: "Use Offline EVA",
                identifier: "setupCenter.eva.offline",
                isEnabled: true,
                perform: chooseOfflineEva
            )
        case .hydrating, .activating, .ready:
            nil
        }
    }

    var grantBindings: [(grant: EvaConsentPolicy.Grant, title: String, isOn: Binding<Bool>)] {
        EvaConsentPolicy.Grant.allCases.map { grant in
            (grant, grantTitle(grant), grantBinding(grant))
        }
    }

    func activateGuestEva() {
        guard evaAccess.isWorking == false else { return }
        evaAccess.clearError()
        Task { @MainActor in
            _ = await evaAccess.confirmAndActivate(
                grants: evaAccess.selectedGrants,
                source: .setupCenter
            )
        }
    }

    func retryGuestEva() {
        guard evaAccess.isWorking == false else { return }
        evaAccess.selectCloud()
        Task { @MainActor in
            _ = await evaAccess.resumeConfirmedActivation(source: .setupCenter)
        }
    }

    func reconnectAppleEva() {
        guard evaAccess.isWorking == false else { return }
        Task { @MainActor in
            _ = await evaAccess.reconnectApple()
        }
    }

    func chooseOfflineEva() {
        evaAccess.selectOffline()
        onNavigate(.llm)
    }

    func grantBinding(_ grant: EvaConsentPolicy.Grant) -> Binding<Bool> {
        Binding(
            get: { evaAccess.selectedGrants.contains(grant) },
            set: { enabled in
                if enabled { evaAccess.selectedGrants.insert(grant) }
                else { evaAccess.selectedGrants.remove(grant) }
            }
        )
    }

    func grantTitle(_ grant: EvaConsentPolicy.Grant) -> String {
        switch grant {
        case .journal: "Journal"
        case .health: "Health"
        case .lifeMoments: "Life Moments"
        case .personalMemory: "Personal Memory"
        }
    }
}
