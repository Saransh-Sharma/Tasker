import AuthenticationServices
import SwiftUI

struct SetupCenterView: View {
    private enum EvaSetupPhase {
        case signIn
        case chooseGrants
        case ready
    }

    @ObservedObject var settingsViewModel: SettingsViewModel
    let onOpenCalendarChooser: () -> Void
    let onNavigate: (SettingsDetailRoute) -> Void

    @Environment(\.lifeboardTokens) private var tokens
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @State private var evaAccount = EvaCloudAccountState.shared
    @State private var evaPhase: EvaSetupPhase = .signIn
    @State private var preparedAppleSignIn: EvaAppleIdentityService.PreparedSignIn?
    @State private var selectedGrants = Set(EvaConsentPolicy.Grant.allCases)
    @State private var isEvaWorking = false
    @State private var evaErrorMessage: String?
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
            evaIsActivated: EvaActivationDefaultsStore.load().isComplete && evaAccount.canUseCloud
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.s16) {
                header
                calendarCard
                healthCard
                remindersCard
                evaCard
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
            await evaAccount.refresh()
            if EvaActivationDefaultsStore.load().isComplete, evaAccount.canUseCloud {
                evaPhase = .ready
            } else if evaAccount.isAuthenticated, evaAccount.consent != nil {
                selectedGrants = Set(EvaConsentPolicy.Grant.allCases)
                evaPhase = .chooseGrants
            } else {
                await prepareAppleSignIn()
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
            Button("Sign in with Apple") {}
            Button("Set up Offline EVA") {
                Task { await ProductTelemetry.shared.record(.evaActivationDismissed, outcome: "offline_settings") }
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
        switch evaPhase {
        case .signIn:
            VStack(alignment: .leading, spacing: spacing.s12) {
                SignInWithAppleButton(.signIn, onRequest: { request in
                    guard let preparedAppleSignIn else { return }
                    EvaAppleIdentityService.shared.configure(request, for: preparedAppleSignIn)
                }, onCompletion: { result in
                    completeAppleSignIn(result)
                })
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: 320, minHeight: 48)
                .disabled(isEvaWorking || preparedAppleSignIn == nil)
                .accessibilityIdentifier("setupCenter.eva.signIn")

                if let caption = evaAccount.activationStage.progressCaption, isEvaWorking {
                    ProgressView(caption)
                        .lifeboardFont(.caption1)
                }

                Button("Not now") { showsEvaDismissNudge = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        case .chooseGrants:
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Choose what EVA can use")
                    .lifeboardFont(.headline)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text("Everything starts selected. Turn off any category before confirming.")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                ForEach(EvaConsentPolicy.Grant.allCases, id: \.self) { grant in
                    Toggle(grantTitle(grant), isOn: grantBinding(grant))
                        .accessibilityIdentifier("setupCenter.eva.grant.\(grant.rawValue)")
                }
                Button("Confirm EVA access") { confirmEvaGrants() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isEvaWorking)
                    .accessibilityIdentifier("setupCenter.eva.confirm")
            }
        case .ready:
            Label("Cloud EVA is ready", systemImage: "checkmark.circle.fill")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.statusSuccess))
        }

        if let evaErrorMessage {
            Text(evaErrorMessage)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.statusWarning))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("setupCenter.eva.error")
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
    private func prepareAppleSignIn() async {
        guard preparedAppleSignIn == nil, isEvaWorking == false else { return }
        isEvaWorking = true
        evaErrorMessage = nil
        defer { isEvaWorking = false }
        do {
            preparedAppleSignIn = try await EvaAppleIdentityService.shared.prepareSignIn()
        } catch {
            evaErrorMessage = LifeWeaveEvaActivation.message(for: error)
        }
    }

    private func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard isEvaWorking == false, let preparedAppleSignIn else { return }
        Task { await ProductTelemetry.shared.record(.evaActivationStarted) }
        switch result {
        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            evaErrorMessage = "Sign in was cancelled. You can try again or finish later."
            self.preparedAppleSignIn = nil
            Task { await prepareAppleSignIn() }
        case .failure(let error):
            evaErrorMessage = LifeWeaveEvaActivation.message(for: error)
            Task { await ProductTelemetry.shared.record(.evaActivationFailed, errorCode: "apple_sign_in") }
            self.preparedAppleSignIn = nil
            Task { await prepareAppleSignIn() }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                evaErrorMessage = "Apple did not return a usable sign-in credential. Please try again."
                return
            }
            isEvaWorking = true
            evaErrorMessage = nil
            Task { @MainActor in
                defer { isEvaWorking = false }
                do {
                    try await evaAccount.activateCloud(
                        credential: credential,
                        preparedSignIn: preparedAppleSignIn
                    )
                    selectedGrants = Set(EvaConsentPolicy.Grant.allCases)
                    evaPhase = .chooseGrants
                    self.preparedAppleSignIn = nil
                } catch {
                    evaErrorMessage = LifeWeaveEvaActivation.message(for: error)
                    self.preparedAppleSignIn = nil
                    await prepareAppleSignIn()
                }
            }
        }
    }

    private func confirmEvaGrants() {
        guard isEvaWorking == false, let policy = evaAccount.consent else {
            evaErrorMessage = "EVA consent could not be loaded. Refresh and try again."
            return
        }
        isEvaWorking = true
        evaErrorMessage = nil
        Task { @MainActor in
            defer { isEvaWorking = false }
            do {
                _ = try await EvaCloudTransport.shared.updateConsent(
                    expectedRevision: policy.revision,
                    grants: selectedGrants.sorted { $0.rawValue < $1.rawValue }
                )
                await evaAccount.refresh(forceConfigurationRefresh: true)
                if let readinessError = evaAccount.readinessError() { throw readinessError }
                EvaActivationDefaultsStore.markCompleted()
                evaPhase = .ready
                await ProductTelemetry.shared.record(.evaActivationSucceeded)
            } catch {
                evaErrorMessage = LifeWeaveEvaActivation.message(for: error)
                await ProductTelemetry.shared.record(.evaActivationFailed, errorCode: "consent_or_readiness")
            }
        }
    }

    private func grantBinding(_ grant: EvaConsentPolicy.Grant) -> Binding<Bool> {
        Binding(
            get: { selectedGrants.contains(grant) },
            set: { enabled in
                if enabled { selectedGrants.insert(grant) } else { selectedGrants.remove(grant) }
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
