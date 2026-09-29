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
                    secondaryTitle: String(localized: "Run on \(DeviceNoun.this)"),
                    isPrimaryDisabled: isWorking,
                    onPrimary: activate,
                    onSecondary: onChooseOffline
                )
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                EvaContentHeader(
                    title: String(localized: "Connect Eva"),
                    bodyText: String(localized: "Uses a private guest session, with limits shown in Settings."),
                    eyebrow: String(localized: "Cloud")
                )

                EvaSectionCard(
                    title: String(localized: "What happens next"),
                    subtitle: String(localized: "Your questions and allowed data are sent when you ask."),
                    accessibilityIdentifier: "eva.activation.cloud.requirements"
                ) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        requirement(String(localized: "Creates a guest account"), icon: "person.crop.circle.badge.plus")
                        requirement(String(localized: "Keeps sign-in details on \(DeviceNoun.this)"), icon: "iphone.gen3")
                        requirement(String(localized: "Link your Apple account later to sync"), icon: "apple.logo")
                    }
                }

                Text("Journal, Health, life moments, and memories start on. Turn them off in Settings.")
                    .font(.lifeboard(.callout))

                EvaSectionCard(
                    title: String(localized: "How it works"),
                    subtitle: String(localized: "Answers in text, and can read them aloud."),
                    accessibilityIdentifier: "eva.activation.cloud.boundaries"
                ) {
                    Text("Requests pass through LifeBoard’s server to OpenAI. The server doesn’t store chats or audio. Reinstalling resets guest access unless you link Apple.")
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
            if await access.ensureActivated(source: .evaEntry) { onCloudReady() }
        }
    }

    private var primaryTitle: String {
        if isWorking { return String(localized: "Connecting…") }
        return account.canUseCloud ? String(localized: "Continue") : String(localized: "Try again")
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
            let ready = await access.ensureActivated(source: .evaEntry)
            if ready { onCloudReady() } else { errorMessage = access.errorMessage }

        }
    }
}
