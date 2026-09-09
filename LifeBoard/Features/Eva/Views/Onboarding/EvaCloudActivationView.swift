import SwiftUI

struct EvaCloudActivationView: View {
    @Environment(\.lifeboardTokens) private var tokens
    @State private var account = EvaCloudAccountState.shared
    @State private var isWorking = false
    @State private var errorMessage: String?
    @StateObject private var access = EvaCloudAccessCoordinator.shared

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
                    EvaCloudDisclosure(grants: EvaConsentPolicy.Grant.allCases.map { grant in
                        (grant, grant.onboardingTitle, Binding(
                            get: { access.selectedGrants.contains(grant) },
                            set: { enabled in
                                if enabled { access.selectedGrants.insert(grant) } else { access.selectedGrants.remove(grant) }
                            }
                        ))
                    }, isWorking: isWorking, identifierPrefix: "eva.activation.cloud")
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
            _ = await access.hydrate()
        }
    }

    private var primaryTitle: String {
        if isWorking { return String(localized: "Connecting…") }
        return account.canUseCloud ? String(localized: "Continue to First Win") : String(localized: "Enable Cloud EVA")
    }

    private func requirement(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.lifeboard(.callout))
            .foregroundStyle(Color.lifeboard(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
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
            let ready: Bool
            if access.hasCurrentReceipt {
                ready = await access.resumeConfirmedActivation(source: .evaEntry)
            } else {
                ready = await access.confirmAndActivate(grants: access.selectedGrants, source: .evaEntry)
            }
            if ready { onCloudReady() } else { errorMessage = access.errorMessage }

        }
    }
}
