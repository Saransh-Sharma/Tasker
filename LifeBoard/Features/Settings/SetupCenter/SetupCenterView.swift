import SwiftUI

struct SetupCenterView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    let onOpenCalendarChooser: () -> Void
    let onNavigate: (SettingsDetailRoute) -> Void

    @Environment(\.lifeboardTokens) private var tokens
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @State private var showsHealthDisclosure = false
    @State private var showsEvaDismissNudge = false

    private var spacing: SemanticSpacingTokens { tokens.spacing }

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.s16) {
                header
                if evaAccess.state != .ready { evaCard }
                calendarCard
                healthCard
                remindersCard
                if evaAccess.state == .ready { evaCard }
            }
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s32)
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
            healthDisclosure
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

    private var header: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Label("Personalize LifeBoard", systemImage: "slider.horizontal.3")
                .lifeboardFont(.screenTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Text("These connections are optional. Set up what helps now, skip anything else, and return from Settings whenever you want.")
                .lifeboardFont(.callout)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var calendarCard: some View {
        connectorCard(
            title: "Calendar",
            subtitle: "See the real shape of your day so plans fit around existing events.",
            systemImage: "calendar",
            state: status.calendar
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(settingsViewModel.calendarStatusSummary)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                Button(settingsViewModel.calendarAuthorizationStatus.isAuthorizedForRead ? "Choose calendars" : "Connect Calendar") {
                    if settingsViewModel.calendarAuthorizationStatus.isAuthorizedForRead {
                        onOpenCalendarChooser()
                    } else {
                        settingsViewModel.requestCalendarPermission()
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("setupCenter.calendar.action")
            }
        }
    }

    private var healthCard: some View {
        connectorCard(
            title: "Apple Health",
            subtitle: "Bring local wellness context into LifeBoard and sync supported entries back to Health.",
            systemImage: "heart.text.square.fill",
            state: status.health
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(healthStatusText)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                Button(status.healthAccess.readState == .notRequested ? "Review Health access" : "Review Health settings") {
                    showsHealthDisclosure = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("setupCenter.health.action")
            }
        }
    }

    private var remindersCard: some View {
        connectorCard(
            title: "Reminders",
            subtitle: "Create reminders now. LifeBoard asks for notification access only when your first alert needs it.",
            systemImage: "bell.badge",
            state: status.reminders
        ) {
            Button("Open Reminders") { onNavigate(.reminders) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("setupCenter.reminders.action")
        }
    }

    private var evaCard: some View {
        connectorCard(
            title: "EVA",
            subtitle: "Use the Cloud smart layer with only the categories you approve.",
            systemImage: "sparkles",
            state: status.eva
        ) {
            evaSetupContent
        }
    }

    @ViewBuilder
    private var evaSetupContent: some View {
        switch evaAccess.state {
        case .needsDisclosure:
            VStack(alignment: .leading, spacing: spacing.s12) {
                evaDisclosureAndGrants
                Button("Continue with Cloud EVA") { activateGuestEva() }
                    .buttonStyle(.borderedProminent)
                    .disabled(evaAccess.isWorking)
                    .accessibilityIdentifier("setupCenter.eva.activate")
                Button("Not now") { showsEvaDismissNudge = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        case .hydrating, .activating:
            ProgressView(evaAccess.account.activationStage.progressCaption ?? "Checking Cloud EVA…")
                .lifeboardFont(.caption1)
                .accessibilityIdentifier("setupCenter.eva.progress")
        case .temporarilyUnavailable(let message):
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(evaAccess.errorMessage ?? message)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                Button("Retry Cloud EVA") { retryGuestEva() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("setupCenter.eva.retry")
                Button("Use Offline EVA") { chooseOfflineEva() }
                    .buttonStyle(.bordered)
            }
        case .appleReauthenticationRequired:
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Apple confirmation restores this linked account. LifeBoard won't replace it with a new guest.")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                Button("Reconnect with Apple") { reconnectAppleEva() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("setupCenter.eva.reconnectApple")
                Button("Use Offline EVA") { chooseOfflineEva() }
                    .buttonStyle(.bordered)
            }
        case .quotaExhausted(let nextAvailableAt):
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(quotaMessage(nextAvailableAt))
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                Button("Use Offline EVA") { chooseOfflineEva() }
                    .buttonStyle(.bordered)
            }
        case .ageBlocked(let message):
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(message)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                Button("Use Offline EVA") { chooseOfflineEva() }
                    .buttonStyle(.bordered)
            }
        case .ready:
            Label("Cloud EVA is ready", systemImage: "checkmark.circle.fill")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.statusSuccess))
        }
    }

    private var evaDisclosureAndGrants: some View {
        Group {
            Text("Prompts and the context you confirm pass through LifeBoard's Cloudflare service to OpenAI. Guest credentials stay on this device; protect EVA with Apple to recover the cloud account after reinstalling.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            ForEach(EvaConsentPolicy.Grant.allCases, id: \.self) { grant in
                Toggle(grantTitle(grant), isOn: grantBinding(grant))
                    .accessibilityIdentifier("setupCenter.eva.grant.\(grant.rawValue)")
            }
        }
    }
}

private extension SetupCenterView {
    private var healthStatusText: String {
        switch status.healthAccess.readState {
        case .notRequested:
            "Not requested"
        case .requestPresented:
            "Health access requested · \(status.healthAccess.authorizedWriteCount) write categories authorized"
        case .dataAvailable:
            "Health data available · \(status.healthAccess.authorizedWriteCount) write categories authorized"
        }
    }

    private var healthDisclosure: some View {
        NavigationStack {
            List {
                Section("LifeBoard will request read access") {
                    ForEach(HealthDomain.allCases.filter { $0.metrics.isEmpty == false }) { domain in
                        Label(domain.title, systemImage: domain.symbolName)
                    }
                }
                Section("LifeBoard will request write access") {
                    ForEach(HealthDomain.allCases.filter(\.supportsWriteBack)) { domain in
                        Label(domain.title, systemImage: domain.symbolName)
                    }
                }
                Section {
                    Text("Apple does not reveal whether read access was denied. After the sheet, LifeBoard reports that access was requested and only reports readable data when data is actually observed.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Apple Health access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsHealthDisclosure = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(status.healthAccess.readState == .notRequested ? "Continue" : "Request again") {
                        showsHealthDisclosure = false
                        Task {
                            await healthStore.connect(
                                domains: Set(HealthDomain.allCases),
                                enableWriteBack: true
                            )
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("setupCenter.health.disclosure")
    }
}

private extension SetupCenterView {
    private func connectorCard<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        state: SetupCenterConnectorState,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                Image(systemName: systemImage)
                    .lifeboardFont(.headline)
                    .foregroundStyle(stateColor(state))
                    .frame(width: 40, height: 40)
                    .background(stateColor(state).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .lifeboardFont(.headline)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text(subtitle)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: stateSymbol(state))
                    .foregroundStyle(stateColor(state))
                    .accessibilityLabel(stateLabel(state))
            }
            content()
        }
        .padding(spacing.s16)
        .background(Color.lifeboard(.surfacePrimary), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.lifeboard(.borderSubtle), lineWidth: 1)
        }
    }
}

private extension SetupCenterView {
    private func activateGuestEva() {
        guard evaAccess.isWorking == false else { return }
        evaAccess.clearError()
        Task { @MainActor in
            _ = await evaAccess.confirmAndActivate(
                grants: evaAccess.selectedGrants,
                source: .setupCenter
            )
        }
    }

    private func retryGuestEva() {
        guard evaAccess.isWorking == false else { return }
        evaAccess.selectCloud()
        Task { @MainActor in
            _ = await evaAccess.resumeConfirmedActivation(source: .setupCenter)
        }
    }

    private func reconnectAppleEva() {
        guard evaAccess.isWorking == false else { return }
        Task { @MainActor in
            _ = await evaAccess.reconnectApple()
        }
    }

    private func chooseOfflineEva() {
        evaAccess.selectOffline()
        onNavigate(.llm)
    }

    private func quotaMessage(_ nextAvailableAt: Date?) -> String {
        nextAvailableAt.map {
            "Your rolling Cloud EVA allowance begins returning \($0.formatted(date: .omitted, time: .shortened))."
        } ?? "Your rolling Cloud EVA allowance is currently used."
    }

    private func grantBinding(_ grant: EvaConsentPolicy.Grant) -> Binding<Bool> {
        Binding(
            get: { evaAccess.selectedGrants.contains(grant) },
            set: { enabled in
                if enabled { evaAccess.selectedGrants.insert(grant) }
                else { evaAccess.selectedGrants.remove(grant) }
            }
        )
    }

    private func grantTitle(_ grant: EvaConsentPolicy.Grant) -> String {
        switch grant {
        case .journal: "Journal"
        case .health: "Health"
        case .lifeMoments: "Life Moments"
        case .personalMemory: "Personal Memory"
        }
    }

    private func stateSymbol(_ state: SetupCenterConnectorState) -> String {
        switch state {
        case .ready: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .requested: "checkmark.circle"
        case .deferred: "clock"
        case .notStarted: "circle"
        }
    }

    private func stateColor(_ state: SetupCenterConnectorState) -> Color {
        switch state {
        case .ready: Color.lifeboard(.statusSuccess)
        case .attention: Color.lifeboard(.statusWarning)
        case .requested, .deferred, .notStarted: Color.lifeboard(.accentPrimary)
        }
    }

    private func stateLabel(_ state: SetupCenterConnectorState) -> String {
        switch state {
        case .ready: "Ready"
        case .attention: "Needs attention"
        case .requested: "Access requested"
        case .deferred: "Deferred until needed"
        case .notStarted: "Not started"
        }
    }
}
