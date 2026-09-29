import SwiftUI

struct EvaCloudSettingsView: View {
    @Environment(\.lifeboardTokens) private var tokens
    @State private var account = EvaCloudAccountState.shared
    @AppStorage("eva.provider.preference.v1") private var providerPreference = EvaProviderRouter.Preference.cloud.rawValue
    @State private var selectedGrants = Set(EvaConsentPolicy.Grant.allCases)
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var confirmsAccountDeletion = false
    @State private var showsConsent = false
    @StateObject private var access = EvaCloudAccessCoordinator.shared

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsHeroCard(
                    eyebrow: String(localized: "Eva"),
                    title: account.isAuthenticated ? String(localized: "Cloud is on") : String(localized: "Use Eva in the cloud"),
                    subtitle: String(localized: "Spoken replies use an AI voice. Dictation stays on \(DeviceNoun.this)."),
                    statusItems: statusItems,
                    accessibilityIdentifier: "evaCloudSettings.hero"
                )
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s16)

                SettingsSectionView(
                    title: String(localized: "Where Eva runs"),
                    subtitle: String(localized: "Eva won’t switch to \(DeviceNoun.this) without asking.")
                ) {
                    SettingsFieldCard(
                        title: String(localized: "Eva runs on"),
                        subtitle: String(localized: "This \(DeviceNoun.current) needs a downloaded model.")
                    ) {
                        let onDeviceTitle = String(localized: "This \(DeviceNoun.current)")
                        // Was `.pickerStyle(.segmented)`, the stock grey segmented
                        // control. The selection is an `@AppStorage` `String`
                        // rawValue rather than the enum, so the rail carries the
                        // raw values and maps titles back through the case.
                        OptionRail(
                            String(localized: "Eva runs on"),
                            selection: $providerPreference,
                            values: [
                                EvaProviderRouter.Preference.cloud.rawValue,
                                EvaProviderRouter.Preference.offline.rawValue
                            ],
                            identifierPrefix: "eva.cloud.provider",
                            title: { raw in
                                raw == EvaProviderRouter.Preference.cloud.rawValue ? String(localized: "Cloud") : onDeviceTitle
                            },
                            // The card title already reads "Eva runs on".
                            showsLabel: false
                        )
                        .accessibilityIdentifier("evaCloudSettings.providerPicker")
                    }
                }

                SettingsSectionView(
                    title: String(localized: "Account"),
                    subtitle: String(localized: "Sign in with Apple to use it on other devices.")
                ) {
                    SettingsFieldCard(
                        title: account.isAuthenticated ? String(localized: "Connected") : String(localized: "Connecting\u{2026}"),
                        subtitle: accountSubtitle,
                        footer: String(localized: "Sent to OpenAI through LifeBoard. Chats and audio aren’t kept.")
                    ) {
                        if isWorking {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else if account.isAuthenticated {
                            VStack(spacing: spacing.s12) {
                              HStack {
                                Label(
                                    account.identityKind == .guest ? "Not signed in" : "Signed in with Apple",
                                    systemImage: account.identityKind == .guest ? "person.crop.circle.dashed" : "checkmark.shield.fill"
                                )
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard(.statusSuccess))
                                Spacer()
                                Button("Refresh") { run { await account.refresh() } }
                                    .buttonStyle(.lifeBoardChip)
                              }
                              if account.identityKind == .guest {
                                Button("Sign in with Apple") {
                                    run { try await account.protectWithApple() }
                                }
                                .buttonStyle(.lifeBoardPrimaryCompact)
                                .accessibilityIdentifier("evaCloudSettings.protectWithApple")
                              }
                            }
                        } else {
                            VStack(spacing: spacing.s12) {
                              Text(access.hasConfirmedCloudConsent
                                   ? "Not connected."
                                   : "Cloud is off.")
                                .font(.lifeboard(.caption1))
                              Button(access.hasConfirmedCloudConsent ? "Reconnect" : "Turn on Eva") {
                                turnOnCloud()
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
                        title: String(localized: "Answers"),
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
                            .accessibilityLabel("Answers left")
                            .accessibilityValue(quotaTitle)
                        }
                    }

                    SettingsSectionView(
                        title: String(localized: "Eva can use"),
                        subtitle: ""
                    ) {
                        SettingsFieldCard(
                            title: String(localized: "Optional"),
                            subtitle: String(localized: "Always included: tasks, projects, habits, calendar, and recent chat.")
                        ) {
                            VStack(spacing: spacing.s12) {
                                if account.consent?.reviewRequired == true {
                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        Label("Check these choices", systemImage: "exclamationmark.shield.fill")
                                            .font(.lifeboard(.callout))
                                            .foregroundStyle(Color.lifeboard(.statusWarning))
                                        Text("Only choices both accounts shared were kept.")
                                            .font(.lifeboard(.caption1))
                                            .foregroundStyle(Color.lifeboard(.textSecondary))
                                        Button("Confirm choices") { confirmCurrentConsent() }
                                            .buttonStyle(.lifeBoardPrimaryCompact)
                                    }
                                }
                                consentToggle(.journal, title: grantTitle(.journal), subtitle: String(localized: "Short excerpts."), icon: "book.closed.fill")
                                consentToggle(.health, title: grantTitle(.health), subtitle: String(localized: "Daily summaries only."), icon: "heart.text.square.fill")
                                consentToggle(.lifeMoments, title: grantTitle(.lifeMoments), subtitle: String(localized: "Dates you’re counting down to."), icon: "sparkles.rectangle.stack.fill")
                                consentToggle(.personalMemory, title: grantTitle(.personalMemory), subtitle: String(localized: "Working style, blockers, and goals."), icon: "person.text.rectangle.fill")
                            }
                        }
                    }

                    SettingsSectionView(
                        title: String(localized: "Manage account"),
                        subtitle: ""
                    ) {
                        VStack(spacing: spacing.s12) {
                            SettingsDangerZoneCard(
                                title: String(localized: "Sign out of cloud"),
                                subtitle: String(localized: "Your data stays on \(DeviceNoun.this)."),
                                buttonTitle: String(localized: "Sign out"),
                                buttonRole: nil,
                                accessibilityIdentifier: "evaCloudSettings.signOutButton",
                                confirmationMessage: account.identityKind == .guest
                                    ? String(localized: "Without Sign in with Apple, this account can’t be restored.")
                                    : String(localized: "You can sign back in with Apple later.")
                            ) {
                                run { await account.deactivateCloud() }
                            }

                            SettingsDangerZoneCard(
                                title: String(localized: "Delete cloud account"),
                                subtitle: account.identityKind == .apple
                                    ? String(localized: "You’ll confirm with Apple first. Data on \(DeviceNoun.this) stays.")
                                    : String(localized: "Data on \(DeviceNoun.this) stays."),
                                buttonTitle: String(localized: "Delete cloud account"),
                                accessibilityIdentifier: "evaCloudSettings.deleteAccountButton",
                                // Presents its own confirmation below.
                                confirmsBeforeAction: false
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
        .navigationTitle("Cloud")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference().rawValue
            _ = await EvaCloudAccessCoordinator.shared.ensureActivated(source: .setupCenter)
            await restoreState()
        }
        .onChange(of: providerPreference) { _, value in
            if value == EvaProviderRouter.Preference.cloud.rawValue {
                turnOnCloud()
            } else { EvaCloudAccessCoordinator.shared.selectOffline() }
        }
        .sheet(isPresented: $showsConsent) {
            EvaCloudConsentSheet(access: access, source: .setupCenter, identifierPrefix: "evaCloudSettings.consent") { _ in
                Task { await restoreState() }
            }
        }
        .onChange(of: account.consent) { _, consent in
            selectedGrants = Set(consent?.grants ?? [])
        }
        .alert("Cloud", isPresented: errorPresented) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? String(localized: "Couldn’t finish. Try again."))
        }
        .alert("Delete cloud account?", isPresented: $confirmsAccountDeletion) {
            Button("Cancel", role: .cancel) {}
            Button(account.identityKind == .apple ? "Continue with Apple" : "Delete account", role: .destructive) {
                run { try await account.deleteCloudAccount() }
            }
        } message: {
            Text("Your cloud account and settings are removed. Data on \(DeviceNoun.this) stays.")
        }
    }
}

extension EvaCloudSettingsView {
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
            ? ""
            : String(localized: "No name or email needed.")
    }

    private var quotaTitle: String {
        guard let quota = account.quota else { return String(localized: "Couldn’t load answers") }
        return String(
            format: String(localized: "%1$lld of %2$lld left"),
            locale: Locale.current,
            Int64(quota.remaining),
            Int64(quota.limit)
        )
    }

    private var quotaSubtitle: String {
        guard let quota = account.quota else { return String(localized: "Tap Refresh to update.") }
        // The title already carries the count; the subtitle only adds when
        // the next answer returns.
        guard quota.used > 0, let next = quota.nextAvailableAt else { return "" }
        return String(
            format: String(localized: "Next answer: %@"),
            locale: Locale.current,
            next.formatted(date: .abbreviated, time: .shortened)
        )
    }

    private var quotaPolicyDescription: String {
        let limit = account.quota?.limit ?? 20
        let hours = max(1, Int(round(Double(account.quota?.windowSeconds ?? 86_400) / 3_600)))
        return String(
            format: String(localized: "%1$lld answers every %2$lld hours. Errors don’t count."),
            locale: Locale.current,
            Int64(limit),
            Int64(hours)
        )
    }

    private var quotaFooter: String {
        let hours = max(1, Int(round(Double(account.quota?.windowSeconds ?? 86_400) / 3_600)))
        return String(
            format: String(localized: "Each answer returns %lld hours after use."),
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

    /// Short toggle labels under the "Eva can use" header.
    private func grantTitle(_ grant: EvaConsentPolicy.Grant) -> String {
        switch grant {
        case .journal: String(localized: "Journal")
        case .health: String(localized: "Health")
        case .lifeMoments: String(localized: "Life moments")
        case .personalMemory: String(localized: "Memories")
        }
    }

    /// Connecting the first time is the consent step; afterwards it just reconnects.
    private func turnOnCloud() {
        guard access.hasConfirmedCloudConsent else {
            showsConsent = true
            return
        }
        access.selectCloud()
        run { _ = await access.ensureActivated(source: .setupCenter) }
    }

    private func restoreState() async {
        await account.refresh()
        selectedGrants = Set(account.consent?.grants ?? [])
    }

    private func updateConsent(_ grant: EvaConsentPolicy.Grant, enabled: Bool) {
        guard account.consent != nil else { return }
        var replacement = selectedGrants
        if enabled { replacement.insert(grant) } else { replacement.remove(grant) }
        run {
            let updated = try await account.updateConsent(
                grants: replacement.sorted { $0.rawValue < $1.rawValue }
            )
            EvaCloudActivationRecordStore.save(
                grants: Set(updated.grants),
                origin: .userSelection,
                lastServerConsentRevision: updated.revision
            )
            await account.refresh()
            selectedGrants = Set(updated.grants)
        }
    }

    private func confirmCurrentConsent() {
        guard account.consent != nil else { return }
        run {
            let updated = try await account.updateConsent(
                grants: selectedGrants.sorted { $0.rawValue < $1.rawValue }
            )
            EvaCloudActivationRecordStore.save(
                grants: Set(updated.grants),
                origin: .userSelection,
                lastServerConsentRevision: updated.revision
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
