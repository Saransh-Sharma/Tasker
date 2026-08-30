import SwiftUI
import UIKit

struct SetupCenterView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject private var appManager: AppManager
    let onNavigate: (SettingsDetailRoute) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @State private var expandedIntegration: SetupCenterIntegration?
    @State private var scrollTarget: String?
    @State private var showsHealthPrompt = false
    @State private var showsCalendarChooser = false
    @State private var providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference()

    init(
        settingsViewModel: SettingsViewModel,
        onNavigate: @escaping (SettingsDetailRoute) -> Void
    ) {
        self.settingsViewModel = settingsViewModel
        _appManager = ObservedObject(wrappedValue: settingsViewModel.assistantAppManager)
        self.onNavigate = onNavigate
    }

    private var offlineModelReady: Bool {
        guard let current = appManager.currentModelName else { return false }
        return appManager.installedModels.contains(current)
    }

    private var status: SetupCenterStatus {
        SetupCenterStatus.resolve(
            calendarAuthorization: settingsViewModel.calendarAuthorizationStatus,
            selectedCalendarCount: SetupCenterStatus.validCalendarSelectionCount(
                selectedIDs: settingsViewModel.selectedCalendarIDs,
                availableIDs: settingsViewModel.calendarService.snapshot.availableCalendars.map(\.id)
            ),
            calendarIsLoading: settingsViewModel.calendarService.snapshot.isLoading,
            calendarError: settingsViewModel.calendarService.snapshot.errorMessage,
            healthStatuses: healthStore.statuses,
            healthHasObservableData: !healthStore.aggregates.isEmpty,
            healthIsRefreshing: healthStore.isRefreshing,
            healthErrorCode: healthStore.nonSensitiveErrorCode,
            evaAccessState: evaAccess.state,
            evaUsesOfflineProvider: providerPreference == .offline,
            offlineModelReady: offlineModelReady
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect what helps")
                        .lifeboardFont(.screenTitle)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text("All integrations are optional and can be changed later.")
                        .lifeboardFont(.support)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                    Text(status.summary)
                        .lifeboardFont(.meta)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        .padding(.top, 4)
                        .accessibilityIdentifier("setupCenter.summary")
                }
                .padding(.bottom, 4)

                calendarCard(status.calendar).id(SetupCenterIntegration.calendar.rawValue)
                healthCard(status.health).id(SetupCenterIntegration.health.rawValue)
                evaCard(status.eva).id(SetupCenterIntegration.eva.rawValue)
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(reduceMotion ? nil : .snappy) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
        .navigationTitle("Setup Center")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("setupCenter.root")
        .task { await refreshAll(selectRecommended: true) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await ProductTelemetry.shared.record(.connectorResult, outcome: "settings_recovery_return")
                await refreshAll(selectRecommended: false)
            }
        }
        .onChange(of: status) { previous, current in
            let completed = previous.snapshots.first { $0.integration == expandedIntegration }?.state.isReady == false
                && current.snapshots.first { $0.integration == expandedIntegration }?.state.isReady == true
            guard completed else { return }
            UIAccessibility.post(notification: .announcement, argument: "Integration ready")
            withAnimation(reduceMotion ? nil : .snappy) {
                expandedIntegration = current.recommendedNextAction
                scrollTarget = current.recommendedNextAction?.rawValue
            }
        }
        .sheet(isPresented: $showsHealthPrompt) {
            SetupCenterHealthDisclosureSheet(
                initialWritableDomains: Set(healthStore.statuses.values.filter(\.writeEnabled).map(\.domain)),
                onCancel: { showsHealthPrompt = false },
                onConfirm: connectHealth
            )
        }
        .sheet(isPresented: $showsCalendarChooser) {
            EventKitCalendarChooserContainerView(
                service: settingsViewModel.calendarService,
                initialSelectedCalendarIDs: settingsViewModel.selectedCalendarIDs,
                requiresAtLeastOneSelection: true,
                onCancel: {
                    Task { await ProductTelemetry.shared.record(.connectorResult, outcome: "calendar_chooser_cancelled") }
                },
                onCommit: settingsViewModel.updateSelectedCalendarIDs
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private extension SetupCenterView {
    func calendarCard(_ snapshot: SetupCenterIntegrationSnapshot) -> some View {
        SetupCenterDisclosureCard(snapshot: snapshot, isExpanded: expandedIntegration == .calendar, onToggle: { toggle(.calendar) }) {
            VStack(alignment: .leading, spacing: 14) {
                explanation(snapshot)
                SetupCenterPrimaryAction(
                    title: snapshot.recoveryAction.isEmpty ? "Checking calendars…" : snapshot.recoveryAction,
                    identifier: "setupCenter.calendar.action",
                    isEnabled: snapshot.state != .checking,
                    action: { handleCalendarAction(snapshot.recoveryActionKind) }
                )
                .id("calendar.action")
            }
        }
    }

    func healthCard(_ snapshot: SetupCenterIntegrationSnapshot) -> some View {
        SetupCenterDisclosureCard(snapshot: snapshot, isExpanded: expandedIntegration == .health, onToggle: { toggle(.health) }) {
            VStack(alignment: .leading, spacing: 14) {
                explanation(snapshot)
                Text("Health data stays on this device and is not shared with Cloud EVA unless you separately enable Health in EVA’s grants.")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                if healthStore.isRefreshing {
                    ProgressView("Syncing Apple Health…")
                        .accessibilityIdentifier("setupCenter.health.loading")
                } else {
                    SetupCenterPrimaryAction(title: snapshot.recoveryAction, identifier: "setupCenter.health.action") {
                        handleHealthAction(snapshot.recoveryActionKind)
                    }
                    .id("health.action")
                    if HealthAuthorizationPromptState.hasRequested {
                        Button("Manage Health access") { openSystemSettings() }
                            .buttonStyle(.lifeBoardChip)
                            .accessibilityIdentifier("setupCenter.health.settings")
                    }
                }
            }
        }
    }

    func evaCard(_ snapshot: SetupCenterIntegrationSnapshot) -> some View {
        SetupCenterDisclosureCard(snapshot: snapshot, isExpanded: expandedIntegration == .eva, onToggle: { toggle(.eva) }) {
            VStack(alignment: .leading, spacing: 14) {
                explanation(snapshot)
                if providerPreference == .cloud, evaAccess.state == .needsDisclosure {
                    SetupCenterEvaGrantsSection(grants: grantBindings)
                }
                if evaAccess.isWorking && providerPreference == .cloud {
                    ProgressView(evaAccess.account.activationStage.progressCaption ?? "Connecting Cloud EVA…")
                        .accessibilityIdentifier("setupCenter.eva.loading")
                } else {
                    evaPrimaryAction(snapshot)
                        .id("eva.action")
                }
                if let error = evaAccess.errorMessage {
                    Text(error)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.statusWarning))
                        .accessibilityIdentifier("setupCenter.eva.error")
                }
                evaAlternativeActions
            }
        }
    }

    func explanation(_ snapshot: SetupCenterIntegrationSnapshot) -> some View {
        Text(snapshot.explanation)
            .lifeboardFont(.support)
            .foregroundStyle(Color.lifeboard(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    func evaPrimaryAction(_ snapshot: SetupCenterIntegrationSnapshot) -> some View {
        if providerPreference == .offline {
            SetupCenterPrimaryAction(title: offlineModelReady ? "Manage Offline EVA" : "Choose a local model", identifier: "setupCenter.eva.offline") {
                onNavigate(.llm)
            }
        } else {
            switch evaAccess.state {
            case .needsDisclosure:
                SetupCenterPrimaryAction(title: "Continue with Cloud EVA", identifier: "setupCenter.eva.activate", action: activateCloudEva)
            case .temporarilyUnavailable:
                SetupCenterPrimaryAction(title: "Retry Cloud EVA", identifier: "setupCenter.eva.retry", action: retryCloudEva)
            case .appleReauthenticationRequired:
                SetupCenterPrimaryAction(title: "Reconnect with Apple", identifier: "setupCenter.eva.reconnectApple", action: reconnectAppleEva)
            case .quotaExhausted, .ageBlocked:
                SetupCenterPrimaryAction(title: "Use Offline EVA", identifier: "setupCenter.eva.offline", action: chooseOfflineEva)
            case .ready:
                SetupCenterPrimaryAction(title: "Manage EVA", identifier: "setupCenter.eva.manage") { onNavigate(.llm) }
            case .hydrating, .activating:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    var evaAlternativeActions: some View {
        if providerPreference == .cloud {
            Button("Use Offline EVA", action: chooseOfflineEva)
                .buttonStyle(.lifeBoardChip)
                .accessibilityIdentifier("setupCenter.eva.provider.offline")
            if evaAccess.state == .needsDisclosure {
                Button("Not now") { expandedIntegration = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("setupCenter.eva.notNow")
            }
        } else {
            Button("Use Cloud EVA") {
                evaAccess.selectCloud()
                providerPreference = .cloud
                Task { _ = await evaAccess.hydrate() }
            }
            .buttonStyle(.lifeBoardChip)
            .accessibilityIdentifier("setupCenter.eva.provider.cloud")
        }
    }

    func toggle(_ integration: SetupCenterIntegration) {
        withAnimation(reduceMotion ? nil : .snappy) {
            expandedIntegration = expandedIntegration == integration ? nil : integration
            if expandedIntegration != nil {
                scrollTarget = integration.rawValue
                Task { @MainActor in
                    await Task.yield()
                    await Task.yield()
                    scrollTarget = "\(integration.rawValue).action"
                }
            }
        }
    }

    func handleCalendarAction(_ action: SetupCenterRecoveryAction) {
        Task { await ProductTelemetry.shared.record(.connectorResult, outcome: "calendar_started") }
        switch action {
        case .chooseCalendars:
            settingsViewModel.calendarService.refreshContext(reason: "setup_center_chooser_requested")
            showsCalendarChooser = true
        case .refreshCalendars:
            settingsViewModel.calendarService.refreshAuthorizationStatus()
            settingsViewModel.calendarService.refreshContext(reason: "setup_center_retry")
        case .openSystemSettings:
            openSystemSettings()
        case .requestCalendarAccess:
            settingsViewModel.requestCalendarPermission { granted in
                Task { await ProductTelemetry.shared.record(.connectorResult, outcome: granted ? "calendar_permission_completed" : "calendar_permission_failed") }
                guard granted else { return }
                settingsViewModel.calendarService.refreshContext(reason: "setup_center_permission_granted")
                showsCalendarChooser = true
            }
        case .none, .requestHealthAccess, .syncHealth:
            break
        }
    }

    func handleHealthAction(_ action: SetupCenterRecoveryAction) {
        switch action {
        case .requestHealthAccess:
            showsHealthPrompt = true
        case .syncHealth:
            Task {
                await ProductTelemetry.shared.record(.connectorResult, outcome: "health_sync_retry_started")
                await healthStore.syncNow()
                await ProductTelemetry.shared.record(
                    .connectorResult,
                    outcome: healthStore.nonSensitiveErrorCode == nil ? "health_sync_retry_completed" : "health_sync_retry_failed",
                    errorCode: healthStore.nonSensitiveErrorCode
                )
            }
        case .openSystemSettings:
            openSystemSettings()
        case .none, .requestCalendarAccess, .chooseCalendars, .refreshCalendars:
            break
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func connectHealth(_ selectedWritableDomains: Set<HealthDomain>) {
        showsHealthPrompt = false
        Task {
            await ProductTelemetry.shared.record(.connectorResult, outcome: "health_started")
            await healthStore.connect(domains: selectedWritableDomains, enableWriteBack: true)
            for domain in HealthDomain.allCases where domain.supportsWriteBack && !selectedWritableDomains.contains(domain) {
                await healthStore.setWriteEnabled(false, for: domain)
            }
            await ProductTelemetry.shared.record(
                .connectorResult,
                outcome: healthStore.nonSensitiveErrorCode == nil ? "health_completed" : "health_failed",
                errorCode: healthStore.nonSensitiveErrorCode
            )
        }
    }

    func activateCloudEva() {
        Task {
            await ProductTelemetry.shared.record(.connectorResult, outcome: "eva_cloud_started")
            let succeeded = await evaAccess.confirmAndActivate(grants: evaAccess.selectedGrants, source: .setupCenter)
            await ProductTelemetry.shared.record(.connectorResult, outcome: succeeded ? "eva_cloud_completed" : "eva_cloud_failed")
        }
    }
    func retryCloudEva() {
        evaAccess.selectCloud()
        Task { _ = await evaAccess.resumeConfirmedActivation(source: .setupCenter) }
    }
    func reconnectAppleEva() { Task { _ = await evaAccess.reconnectApple() } }
    func chooseOfflineEva() {
        evaAccess.selectOffline()
        providerPreference = .offline
        if !offlineModelReady { onNavigate(.llm) }
    }

    var grantBindings: [(grant: EvaConsentPolicy.Grant, title: String, isOn: Binding<Bool>)] {
        EvaConsentPolicy.Grant.allCases.map { grant in
            (grant, grantTitle(grant), Binding(
                get: { evaAccess.selectedGrants.contains(grant) },
                set: { enabled in
                    if enabled { evaAccess.selectedGrants.insert(grant) }
                    else { evaAccess.selectedGrants.remove(grant) }
                }
            ))
        }
    }
    func grantTitle(_ grant: EvaConsentPolicy.Grant) -> String {
        switch grant { case .journal: "Journal"; case .health: "Health"; case .lifeMoments: "Life Moments"; case .personalMemory: "Personal Memory" }
    }

    func refreshAll(selectRecommended: Bool) async {
        settingsViewModel.calendarService.refreshAuthorizationStatus()
        if settingsViewModel.calendarService.snapshot.authorizationStatus.isAuthorizedForRead {
            settingsViewModel.calendarService.refreshContext(reason: "setup_center_refresh")
        }
        settingsViewModel.reload()
        providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference()
        await healthStore.bootstrap()
        _ = await evaAccess.hydrate()
        if selectRecommended && expandedIntegration == nil {
            expandedIntegration = status.recommendedNextAction
            scrollTarget = status.recommendedNextAction?.rawValue
            if let recommendation = status.recommendedNextAction {
                Task { @MainActor in
                    await Task.yield()
                    await Task.yield()
                    scrollTarget = "\(recommendation.rawValue).action"
                }
            }
        }
        let resolved = status
        let outcome = resolved.snapshots
            .map { "\($0.integration.rawValue)_\(telemetryLabel($0.state))" }
            .joined(separator: "_")
        await ProductTelemetry.shared.record(.connectorResult, outcome: "final_state_\(outcome)")
        await ProductTelemetry.shared.record(.setupCenterOpened)
    }

    func telemetryLabel(_ state: SetupCenterConnectorState) -> String {
        switch state {
        case .notStarted: "not_started"
        case .actionRequired: "action_required"
        case .checking: "checking"
        case .waiting: "waiting"
        case .ready: "ready"
        case .limited: "limited"
        case .attention: "attention"
        }
    }
}
