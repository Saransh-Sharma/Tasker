import SwiftUI

struct EvaCloudSettingsView: View {
    @Environment(\.lifeboardTokens) private var tokens
    @State private var account = EvaCloudAccountState.shared
    @AppStorage("eva.provider.preference.v1") private var providerPreference = EvaProviderRouter.Preference.cloud.rawValue
    @State private var selectedGrants = Set(EvaConsentPolicy.Grant.allCases)
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var confirmsAccountDeletion = false

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsHeroCard(
                    eyebrow: String(localized: "Cloud EVA"),
                    title: account.isAuthenticated ? String(localized: "Connected to Luna") : String(localized: "Use EVA without a model download"),
                    subtitle: String(localized: "Luna generates text in the cloud. Spoken output uses an AI-generated voice; dictation stays on Apple's stack."),
                    statusItems: statusItems,
                    accessibilityIdentifier: "evaCloudSettings.hero"
                )
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s16)

                SettingsSectionView(
                    title: String(localized: "Provider"),
                    subtitle: String(localized: "Cloud failures are shown directly. EVA never switches providers without your choice.")
                ) {
                    SettingsFieldCard(
                        title: String(localized: "Choose where EVA runs"),
                        subtitle: String(localized: "A request keeps the same provider from start to finish. Offline EVA remains available when an MLX model is installed.")
                    ) {
                        Picker("EVA provider", selection: $providerPreference) {
                            Text("Cloud").tag(EvaProviderRouter.Preference.cloud.rawValue)
                            Text("Offline").tag(EvaProviderRouter.Preference.offline.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("evaCloudSettings.providerPicker")
                    }
                }

                SettingsSectionView(
                    title: String(localized: "Cloud Account"),
                    subtitle: String(localized: "Start with a pseudonymous guest session. Protect it with Apple later for cross-device access and reinstall recovery.")
                ) {
                    SettingsFieldCard(
                        title: account.isAuthenticated ? String(localized: "Cloud EVA is connected") : String(localized: "Activate Cloud EVA"),
                        subtitle: accountSubtitle,
                        footer: String(localized: "Prompts and authorized context are sent to OpenAI through LifeBoard's Cloudflare backend. No cloud chat or audio history is kept by LifeBoard.")
                    ) {
                        if isWorking {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else if account.isAuthenticated {
                            VStack(spacing: spacing.s12) {
                              HStack {
                                Label(
                                    account.identityKind == .guest ? "Guest account · recovery not protected" : "Protected with Apple",
                                    systemImage: account.identityKind == .guest ? "person.crop.circle.dashed" : "checkmark.shield.fill"
                                )
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard(.statusSuccess))
                                Spacer()
                                Button("Refresh") { run { await account.refresh() } }
                                    .buttonStyle(.bordered)
                              }
                              if account.identityKind == .guest {
                                Button("Protect & sync EVA") {
                                    run { try await account.protectWithApple() }
                                }
                                .buttonStyle(.lifeBoardPrimaryCompact)
                                .accessibilityIdentifier("evaCloudSettings.protectWithApple")
                              }
                            }
                        } else {
                            VStack(spacing: spacing.s12) {
                              Text("Confirm which sensitive categories may be included in bounded Cloud EVA requests. No prompt or LifeBoard context is sent before you continue.")
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                              ForEach(EvaConsentPolicy.Grant.allCases, id: \.self) { grant in
                                activationGrantToggle(grant)
                              }
                              Button("Continue with Cloud EVA") {
                                run {
                                  try await account.activateCloud(
                                    grants: selectedGrants.sorted { $0.rawValue < $1.rawValue }
                                  )
                                }
                              }
                              .buttonStyle(.lifeBoardPrimaryCompact)
                              .tint(Color.lifeboard(.accentPrimary))
                              .accessibilityIdentifier("evaCloudSettings.activateButton")
                            }
                        }
                    }
                }

                if account.isAuthenticated {
                    SettingsSectionView(
                        title: String(localized: "Rolling answer allowance"),
                        subtitle: quotaPolicyDescription
                    ) {
                        SettingsFieldCard(
                            title: quotaTitle,
                            subtitle: quotaSubtitle,
                            footer: quotaFooter
                        ) {
                            ProgressView(
                                value: Double(account.quota?.remaining ?? 0),
                                total: Double(max(account.quota?.limit ?? 20, 1))
                            )
                            .tint(Color.lifeboard(.accentPrimary))
                            .accessibilityLabel("Cloud EVA answers remaining")
                            .accessibilityValue(quotaTitle)
                        }
                    }

                    SettingsSectionView(
                        title: String(localized: "Sensitive Context"),
                        subtitle: String(localized: "You control each category. Activation choices are preselected for review; changes apply account-wide before the next cloud request.")
                    ) {
                        SettingsFieldCard(
                            title: String(localized: "Choose what may leave this device"),
                            subtitle: String(localized: "Tasks, projects, habits, a read-only calendar projection, and bounded chat history are base cloud context.")
                        ) {
                            VStack(spacing: spacing.s12) {
                                if account.consent?.reviewRequired == true {
                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        Label("Review required after Apple linking", systemImage: "exclamationmark.shield.fill")
                                            .font(.lifeboard(.callout))
                                            .foregroundStyle(Color.lifeboard(.statusWarning))
                                        Text("Linking uses the intersection of both accounts' grants. Confirm the current choices before Cloud EVA can use context again.")
                                            .font(.lifeboard(.caption1))
                                            .foregroundStyle(Color.lifeboard(.textSecondary))
                                        Button("Confirm current context") { confirmCurrentConsent() }
                                            .buttonStyle(.lifeBoardPrimaryCompact)
                                    }
                                }
                                consentToggle(.journal, title: String(localized: "Journal"), subtitle: String(localized: "Allow bounded journal context in Cloud EVA requests."), icon: "book.closed.fill")
                                consentToggle(.health, title: String(localized: "Health"), subtitle: String(localized: "Allow bounded health context in Cloud EVA requests."), icon: "heart.text.square.fill")
                                consentToggle(.lifeMoments, title: String(localized: "Life Moments"), subtitle: String(localized: "Allow bounded Life Moments context in Cloud EVA requests."), icon: "sparkles.rectangle.stack.fill")
                                consentToggle(.personalMemory, title: String(localized: "Personal Memory"), subtitle: String(localized: "Allow bounded personal memory context in Cloud EVA requests."), icon: "person.text.rectangle.fill")
                            }
                        }
                    }

                    SettingsSectionView(
                        title: String(localized: "Account Controls"),
                        subtitle: String(localized: "Signing out keeps a protected account, but an unprotected guest may be unrecoverable. Deleting removes sessions, consent, device trust, and quota history.")
                    ) {
                        VStack(spacing: spacing.s12) {
                            SettingsDangerZoneCard(
                                title: String(localized: "Sign Out of Cloud EVA"),
                                subtitle: String(localized: "Offline LifeBoard data and installed MLX models remain on this device."),
                                buttonTitle: String(localized: "Sign out"),
                                buttonRole: nil,
                                accessibilityIdentifier: "evaCloudSettings.signOutButton"
                            ) {
                                run { await account.deactivateCloud() }
                            }

                            SettingsDangerZoneCard(
                                title: String(localized: "Delete Cloud EVA Account"),
                                subtitle: account.identityKind == .apple
                                    ? String(localized: "You will authenticate with Apple again before deletion. This does not delete local LifeBoard data.")
                                    : String(localized: "Confirm using this active device session. This does not delete local LifeBoard data."),
                                buttonTitle: String(localized: "Delete cloud account"),
                                accessibilityIdentifier: "evaCloudSettings.deleteAccountButton"
                            ) {
                                confirmsAccountDeletion = true
                            }
                        }
                    }
                }
            }
            .padding(.bottom, spacing.s24)
        }
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle("Cloud EVA")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference().rawValue
            await restoreState()
        }
        .onChange(of: account.consent) { _, consent in
            selectedGrants = Set(consent?.grants ?? [])
        }
        .alert("Cloud EVA", isPresented: errorPresented) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
        .alert("Delete Cloud EVA account?", isPresented: $confirmsAccountDeletion) {
            Button("Cancel", role: .cancel) {}
            Button(account.identityKind == .apple ? "Continue with Apple" : "Delete Cloud EVA Data", role: .destructive) {
                run { try await account.deleteCloudAccount() }
            }
        } message: {
            Text("This permanently removes your cloud account state. Your local LifeBoard data is not affected.")
        }
    }

    private var statusItems: [SettingsStatusDescriptor] {
        [
            .init(
                id: "account",
                title: String(localized: "Account"),
                value: account.isAuthenticated ? String(localized: "Connected") : String(localized: "Not set up"),
                systemImage: "person.crop.circle.badge.checkmark",
                tone: account.isAuthenticated ? .success : .neutral
            ),
            .init(
                id: "answers",
                title: String(localized: "Answers"),
                value: account.quota.map { "\($0.remaining) / \($0.limit)" } ?? "—",
                systemImage: "bolt.fill",
                tone: (account.quota?.remaining ?? 0) > 0 ? .accent : .warning
            ),
            .init(
                id: "voice",
                title: String(localized: "Voice"),
                value: account.configuration?.ttsEnabled == true ? String(localized: "Available") : String(localized: "Off"),
                systemImage: "waveform",
                tone: account.configuration?.ttsEnabled == true ? .success : .neutral
            ),
        ]
    }

    private var accountSubtitle: String {
        if let error = account.lastError, account.isAuthenticated { return error }
        return account.isAuthenticated
            ? String(localized: "Your session, consent revision, and rolling quota are synchronized with the cloud account.")
            : String(localized: "Guest setup does not ask for your name or email. Cloud EVA is for people age 13 or older.")
    }

    private var quotaTitle: String {
        guard let quota = account.quota else { return String(localized: "Answer quota unavailable") }
        return String(
            format: String(localized: "%1$lld of %2$lld answers remaining"),
            locale: Locale.current,
            Int64(quota.remaining),
            Int64(quota.limit)
        )
    }

    private var quotaSubtitle: String {
        guard let quota = account.quota else { return String(localized: "Refresh Cloud EVA to retrieve the rolling quota.") }
        if quota.used == 0 {
            return String(
                format: String(localized: "All %lld answers are currently available."),
                locale: Locale.current,
                Int64(quota.limit)
            )
        }
        guard let next = quota.nextAvailableAt else {
            return String(
                format: String(localized: "%lld answers are currently available."),
                locale: Locale.current,
                Int64(quota.remaining)
            )
        }
        return String(
            format: String(localized: "The next used slot expires: %@."),
            locale: Locale.current,
            next.formatted(date: .abbreviated, time: .shortened)
        )
    }

    private var quotaPolicyDescription: String {
        let limit = account.quota?.limit ?? 20
        let hours = max(1, Int(round(Double(account.quota?.windowSeconds ?? 86_400) / 3_600)))
        return String(
            format: String(localized: "Up to %1$lld successful billable answers during the preceding rolling %2$lld hours. Failed, cancelled, refused, and moderated requests do not count."),
            locale: Locale.current,
            Int64(limit),
            Int64(hours)
        )
    }

    private var quotaFooter: String {
        let hours = max(1, Int(round(Double(account.quota?.windowSeconds ?? 86_400) / 3_600)))
        return String(
            format: String(localized: "Each successful billable answer consumes one slot. Timestamps expire individually after %lld hours."),
            locale: Locale.current,
            Int64(hours)
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func consentToggle(
        _ grant: EvaConsentPolicy.Grant,
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        SettingsToggleRow(
            iconName: icon,
            title: title,
            subtitle: subtitle,
            isOn: Binding(
                get: { selectedGrants.contains(grant) },
                set: { enabled in updateConsent(grant, enabled: enabled) }
            ),
            accessibilityIdentifier: "evaCloudSettings.consent.\(grant.rawValue)"
        )
        .disabled(isWorking)
    }

    private func activationGrantToggle(_ grant: EvaConsentPolicy.Grant) -> some View {
        Toggle(grantTitle(grant), isOn: Binding(
            get: { selectedGrants.contains(grant) },
            set: { enabled in
                if enabled { selectedGrants.insert(grant) }
                else { selectedGrants.remove(grant) }
            }
        ))
        .accessibilityIdentifier("evaCloudSettings.activationConsent.\(grant.rawValue)")
    }

    private func grantTitle(_ grant: EvaConsentPolicy.Grant) -> String {
        switch grant {
        case .journal: String(localized: "Journal")
        case .health: String(localized: "Health")
        case .lifeMoments: String(localized: "Life Moments")
        case .personalMemory: String(localized: "Personal Memory")
        }
    }

    private func restoreState() async {
        guard (try? await EvaCloudSessionStore.shared.load()) != nil else { return }
        await account.refresh()
        selectedGrants = Set(account.consent?.grants ?? [])
    }

    private func updateConsent(_ grant: EvaConsentPolicy.Grant, enabled: Bool) {
        guard let policy = account.consent else { return }
        var replacement = selectedGrants
        if enabled { replacement.insert(grant) } else { replacement.remove(grant) }
        run {
            let updated = try await EvaCloudTransport.shared.updateConsent(
                expectedRevision: policy.revision,
                grants: replacement.sorted { $0.rawValue < $1.rawValue }
            )
            await account.refresh()
            selectedGrants = Set(updated.grants)
        }
    }

    private func confirmCurrentConsent() {
        guard let policy = account.consent else { return }
        run {
            _ = try await EvaCloudTransport.shared.updateConsent(
                expectedRevision: policy.revision,
                grants: selectedGrants.sorted { $0.rawValue < $1.rawValue }
            )
            await account.refresh()
        }
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do { try await operation() }
            catch { errorMessage = error.localizedDescription }
        }
    }
}
