import SwiftUI

struct EvaCloudSettingsView: View {
    @Environment(\.lifeboardTokens) private var tokens
    @State private var account = EvaCloudAccountState.shared
    @AppStorage("eva.provider.preference.v1") private var providerPreference = EvaProviderRouter.Preference.cloud.rawValue
    @State private var selectedGrants: Set<EvaConsentPolicy.Grant> = []
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
                    subtitle: String(localized: "Cloud EVA requires Sign in with Apple and an Apple 18+ age-range result on each device. LifeBoard never asks for your birth date.")
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
                            HStack {
                                Label("18+ verified on this device", systemImage: "checkmark.shield.fill")
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard(.statusSuccess))
                                Spacer()
                                Button("Refresh") { run { await account.refresh() } }
                                    .buttonStyle(.bordered)
                            }
                        } else {
                            Button("Continue with Apple") {
                                run { try await account.activateCloud() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.lifeboard(.accentPrimary))
                            .accessibilityIdentifier("evaCloudSettings.activateButton")
                        }
                    }
                }

                if account.isAuthenticated {
                    SettingsSectionView(
                        title: String(localized: "Credits"),
                        subtitle: String(localized: "Credits are account-wide. Failed, cancelled, rejected, and deterministic requests are not charged.")
                    ) {
                        SettingsFieldCard(
                            title: creditTitle,
                            subtitle: creditSubtitle,
                            footer: String(localized: "A successful billable answer uses one credit and includes its first spoken rendering.")
                        ) {
                            ProgressView(
                                value: Double(account.credits?.balance ?? 0),
                                total: Double(max(account.credits?.capacity ?? 100, 1))
                            )
                            .tint(Color.lifeboard(.accentPrimary))
                        }
                    }

                    SettingsSectionView(
                        title: String(localized: "Sensitive Context"),
                        subtitle: String(localized: "Each category is off by default. Changes apply account-wide before the next cloud request.")
                    ) {
                        SettingsFieldCard(
                            title: String(localized: "Choose what may leave this device"),
                            subtitle: String(localized: "Tasks, projects, habits, a read-only calendar projection, and bounded chat history are base cloud context.")
                        ) {
                            VStack(spacing: spacing.s12) {
                                consentToggle(.journal, title: String(localized: "Journal"), subtitle: String(localized: "Allow bounded journal context in Cloud EVA requests."), icon: "book.closed.fill")
                                consentToggle(.health, title: String(localized: "Health"), subtitle: String(localized: "Allow bounded health context in Cloud EVA requests."), icon: "heart.text.square.fill")
                                consentToggle(.lifeMoments, title: String(localized: "Life Moments"), subtitle: String(localized: "Allow bounded Life Moments context in Cloud EVA requests."), icon: "sparkles.rectangle.stack.fill")
                                consentToggle(.personalMemory, title: String(localized: "Personal Memory"), subtitle: String(localized: "Allow bounded personal memory context in Cloud EVA requests."), icon: "person.text.rectangle.fill")
                            }
                        }
                    }

                    SettingsSectionView(
                        title: String(localized: "Account Controls"),
                        subtitle: String(localized: "Signing out keeps the cloud account. Deleting removes its sessions, consent, device trust, and credit ledger.")
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
                                subtitle: String(localized: "You will authenticate with Apple again before deletion. This does not delete local LifeBoard data."),
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
            Button("Continue with Apple", role: .destructive) {
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
                id: "credits",
                title: String(localized: "Credits"),
                value: account.credits.map { "\($0.balance) / \($0.capacity)" } ?? "—",
                systemImage: "bolt.fill",
                tone: (account.credits?.balance ?? 0) > 0 ? .accent : .warning
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
            ? String(localized: "Your session, age result, consent revision, and credits are synchronized with the cloud account.")
            : String(localized: "Apple shares only the age range you approve. An 18+ result is required for cloud features.")
    }

    private var creditTitle: String {
        guard let credits = account.credits else { return String(localized: "Credit balance unavailable") }
        return String(
            format: String(localized: "%1$lld of %2$lld credits"),
            locale: Locale.current,
            Int64(credits.balance),
            Int64(credits.capacity)
        )
    }

    private var creditSubtitle: String {
        guard let credits = account.credits else { return String(localized: "Refresh Cloud EVA to retrieve the account balance.") }
        return String(
            format: String(localized: "Next refill: %@."),
            locale: Locale.current,
            credits.nextRefillAt.formatted(date: .abbreviated, time: .shortened)
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
