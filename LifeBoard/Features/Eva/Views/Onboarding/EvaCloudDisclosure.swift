import SwiftUI

/// One disclosure for every activation surface; defaults are choices, not consent.
struct EvaCloudDisclosure: View {
    let grants: [(grant: EvaConsentPolicy.Grant, title: String, isOn: Binding<Bool>)]
    var isWorking = false
    var identifierPrefix = "eva.disclosure"

    private var name: String { AssistantIdentitySnapshot.current.displayName }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What \(name) can use").lifeboardFont(.bodyStrong)
            Text("Your questions, life areas, tasks, and plans go through LifeBoard’s server to OpenAI.")
                .lifeboardFont(.support)
            Text("Turn off anything you don’t want to share.")
                .lifeboardFont(.caption1)
            ForEach(grants, id: \.grant) { entry in
                Toggle(entry.title, isOn: entry.isOn)
                    .toggleStyle(.lifeBoardClay)
                    .disabled(isWorking)
                    .accessibilityIdentifier("\(identifierPrefix).grant.\(entry.grant.rawValue)")
            }
            Text("Includes Health data you connect later. Apple Health access is asked for separately.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            DisclosureGroup("How it works") {
                Text("LifeBoard’s server sends your request to OpenAI and returns the answer. Changes in Settings apply to your next request.")
                    .lifeboardFont(.caption1)
                    .padding(.top, 8)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The one consent step for Cloud EVA.
///
/// Every category starts on, and every one can be turned off here. Nothing is
/// sent until "Turn on Cloud EVA" is tapped: that tap is what
/// `EvaCloudAccessCoordinator.confirmCloudConsent(grants:source:)` records.
struct EvaCloudConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var access: EvaCloudAccessCoordinator
    let source: EvaCloudAccessSource
    var identifierPrefix = "eva.consent"
    var onConfirmed: (Bool) -> Void = { _ in }

    @State private var isConfirming = false

    var body: some View {
        NavigationStack {
            ScrollView {
                EvaCloudDisclosure(grants: EvaConsentPolicy.Grant.allCases.map { grant in
                    (grant, grant.onboardingTitle, binding(for: grant))
                }, isWorking: isConfirming, identifierPrefix: identifierPrefix)
                .padding(24)
            }
            .navigationTitle("Turn on Eva")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("\(identifierPrefix).notNow")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Turn on") { confirm() }
                        .disabled(isConfirming)
                        .accessibilityIdentifier("\(identifierPrefix).confirm")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isConfirming)
        .accessibilityIdentifier("\(identifierPrefix).sheet")
    }

    private func confirm() {
        guard isConfirming == false else { return }
        isConfirming = true
        let grants = access.selectedGrants
        Task { @MainActor in
            let ready = await access.confirmCloudConsent(grants: grants, source: source)
            isConfirming = false
            dismiss()
            onConfirmed(ready)
        }
    }

    private func binding(for grant: EvaConsentPolicy.Grant) -> Binding<Bool> {
        Binding(
            get: { access.selectedGrants.contains(grant) },
            set: { enabled in
                if enabled { access.selectedGrants.insert(grant) }
                else { access.selectedGrants.remove(grant) }
            }
        )
    }
}

/// Human names for the grants, shared by the activation disclosure, the chat
/// scaffold, and the onboarding grant sheet.
extension EvaConsentPolicy.Grant {
    var onboardingTitle: String {
        switch self {
        case .journal: String(localized: "Journal entries")
        case .health: String(localized: "Health summaries")
        case .lifeMoments: String(localized: "Life moments")
        case .personalMemory: String(localized: "Memories")
        }
    }

    var onboardingBlurb: String {
        switch self {
        case .journal: String(localized: "Lets answers use what you wrote.")
        case .health: String(localized: "Daily summaries only.")
        case .lifeMoments: String(localized: "Dates you’re counting down to.")
        case .personalMemory: String(localized: "Your working style, blockers, and goals.")
        }
    }
}
