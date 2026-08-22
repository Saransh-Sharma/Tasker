import SwiftUI

struct EvaCloudActivationView: View {
    @Environment(\.lifeboardTokens) private var tokens
    @State private var account = EvaCloudAccountState.shared
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var selectedGrants = Set(EvaConsentPolicy.Grant.allCases)

    let onBack: () -> Void
    let onCloudReady: () -> Void
    let onChooseOffline: () -> Void

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        EvaActivationStageView(
            footer: {
                EvaFooterButtons(
                    primaryTitle: primaryTitle,
                    secondaryTitle: String(localized: "Set up Offline EVA"),
                    isPrimaryDisabled: isWorking,
                    onPrimary: activate,
                    onSecondary: onChooseOffline
                )
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                EvaContentHeader(
                    title: String(localized: "Connect Cloud EVA"),
                    bodyText: String(localized: "Continue once to create a private guest session and activate Luna. Successful answers use a rolling allowance shown in EVA settings."),
                    eyebrow: String(localized: "POWERED BY LUNA")
                )

                EvaSectionCard(
                    title: String(localized: "What happens next"),
                    subtitle: String(localized: "No prompt or LifeBoard context leaves this device until you confirm."),
                    accessibilityIdentifier: "eva.activation.cloud.requirements"
                ) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        requirement(String(localized: "Create a pseudonymous guest account"), icon: "person.crop.circle.badge.plus")
                        requirement(String(localized: "Keep credentials only on this device"), icon: "iphone.gen3")
                        requirement(String(localized: "Optionally protect and sync with Apple later"), icon: "apple.logo")
                    }
                }

                EvaSectionCard(
                    title: String(localized: "Choose cloud context"),
                    subtitle: String(localized: "These sensitive categories are preselected. Turn off anything you do not want included in bounded EVA requests."),
                    accessibilityIdentifier: "eva.activation.cloud.consent"
                ) {
                    VStack(spacing: spacing.s12) {
                        grantToggle(.journal, title: String(localized: "Journal"))
                        grantToggle(.health, title: String(localized: "Health"))
                        grantToggle(.lifeMoments, title: String(localized: "Life Moments"))
                        grantToggle(.personalMemory, title: String(localized: "Personal Memory"))
                    }
                }

                EvaSectionCard(
                    title: String(localized: "Clear boundaries"),
                    subtitle: String(localized: "Cloud EVA is for text answers and optional spoken output—not a full-duplex voice assistant."),
                    accessibilityIdentifier: "eva.activation.cloud.boundaries"
                ) {
                    Text("Prompts and the context you confirm pass through LifeBoard's Cloudflare service to OpenAI. LifeBoard does not keep cloud chat or audio history. Guest access cannot be recovered after reinstall unless you later protect it with Apple.")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard(.statusWarning))
                        .accessibilityIdentifier("eva.activation.cloud.error")
                }

                Button("Back") { onBack() }
                    .buttonStyle(.plain)
                    .font(.lifeboard(.button))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .accessibilityIdentifier("eva.activation.cloud.back")
            }
        }
        .accessibilityIdentifier("eva.activation.cloud_setup")
        .task {
            guard (try? await EvaCloudSessionStore.shared.load()) != nil else { return }
            await account.refresh()
        }
    }

    private var primaryTitle: String {
        if isWorking { return String(localized: "Connecting…") }
        return account.canUseCloud ? String(localized: "Continue to First Win") : String(localized: "Continue with Cloud EVA")
    }

    private func requirement(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.lifeboard(.callout))
            .foregroundStyle(Color.lifeboard(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func grantToggle(_ grant: EvaConsentPolicy.Grant, title: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { selectedGrants.contains(grant) },
            set: { enabled in
                if enabled { selectedGrants.insert(grant) }
                else { selectedGrants.remove(grant) }
            }
        ))
        .font(.lifeboard(.callout))
        .tint(Color.lifeboard(.accentPrimary))
        .accessibilityIdentifier("eva.activation.cloud.consent.\(grant.rawValue)")
    }

    private func activate() {
        guard !isWorking else { return }
        if account.canUseCloud {
            onCloudReady()
            return
        }
        isWorking = true
        errorMessage = nil
        Task { @MainActor in
            defer { isWorking = false }
            do {
                try await account.activateCloud(
                    grants: selectedGrants.sorted { $0.rawValue < $1.rawValue }
                )
                if let readinessError = account.readinessError() { throw readinessError }
                onCloudReady()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
