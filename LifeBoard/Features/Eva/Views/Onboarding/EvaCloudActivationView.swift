import SwiftUI

struct EvaCloudActivationView: View {
    @Environment(\.lifeboardTokens) private var tokens
    @State private var account = EvaCloudAccountState.shared
    @State private var isWorking = false
    @State private var errorMessage: String?

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
                    bodyText: String(localized: "Sign in with Apple, confirm an 18+ age range, and start with 100 account-wide credits. Your LifeBoard data stays local unless it is part of the bounded context you authorize."),
                    eyebrow: String(localized: "POWERED BY LUNA")
                )

                EvaSectionCard(
                    title: String(localized: "What happens next"),
                    subtitle: String(localized: "LifeBoard completes these checks before the first cloud request."),
                    accessibilityIdentifier: "eva.activation.cloud.requirements"
                ) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        requirement(String(localized: "Sign in privately with Apple"), icon: "apple.logo")
                        requirement(String(localized: "Share an Apple 18+ age-range result"), icon: "checkmark.shield.fill")
                        requirement(String(localized: "Review sensitive-context permissions in Settings"), icon: "hand.raised.fill")
                    }
                }

                EvaSectionCard(
                    title: String(localized: "Clear boundaries"),
                    subtitle: String(localized: "Cloud EVA is for text answers and optional spoken output—not a full-duplex voice assistant."),
                    accessibilityIdentifier: "eva.activation.cloud.boundaries"
                ) {
                    Text("Prompts and authorized context pass through LifeBoard's Cloudflare service to OpenAI. LifeBoard does not keep cloud chat or audio history. Dictation continues to use Apple's stack, and spoken output is clearly disclosed as AI-generated.")
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
        return account.canUseCloud ? String(localized: "Continue to First Win") : String(localized: "Continue with Apple")
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
            do {
                try await account.activateCloud()
                guard account.canUseCloud else {
                    throw EvaProviderError.unavailable(String(localized: "Cloud EVA is not available yet. You can continue with Offline EVA."))
                }
                onCloudReady()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
