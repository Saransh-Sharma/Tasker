import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Cloud EVA activation, inside onboarding.
///
/// This replaces the standalone `EvaCloudActivationView`, which asked the same
/// questions a second time after the user had already signed in here. The
/// checklist below is the honest version of the old one: its third row used to
/// claim "Choose EVA's boundaries" was satisfied by cloud readiness, while no
/// consent surface was ever shown. Sensitive-context grants are now real,
/// visible, and explicitly confirmed before bootstrap.
///
/// The visible activation action confirms the selected grants and creates the
/// guest account in one transaction; no prompt or LifeBoard context is sent
/// before that confirmation.
struct LifeMapEvaStep: View {
    let isAuthenticated: Bool
    let isAdultEligible: Bool
    let isCloudReady: Bool
    let isWorking: Bool
    let progressCaption: String?
    let errorMessage: String?
    let selectedGrants: Set<EvaConsentPolicy.Grant>
    let onToggleGrant: (EvaConsentPolicy.Grant, Bool) -> Void
    let onChooseOffline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            LifeMapEyebrow("OPTIONAL · PRIVATE · RESUMABLE")
            Text(isCloudReady ? "EVA is connected." : "Enable Cloud EVA.")
                .font(.lifeboard(.heroDisplay))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            Text(isCloudReady
                 ? "Your private cloud session is ready, with a rolling allowance for successful answers."
                 : "One confirmation creates a pseudonymous guest session. You can protect and sync it with Apple later.")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            requirements

            consentList

            if isWorking {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                        .tint(Color.lifeboard(.accentPrimary))
                    Text(progressCaption ?? "Securing your EVA session…")
                        .font(.lifeboard(.bodyStrong))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Prefer everything on-device") { onChooseOffline() }
                .buttonStyle(LifeMapSecondaryButtonStyle())
                .accessibilityIdentifier(LifeMapAccessibilityID.evaOffline)

            Text("Offline EVA runs entirely on this device and is set up from EVA settings, so nothing large downloads now. Core LifeBoard never requires an account.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.eva))
    }

    private var requirements: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            LifeMapEvaRequirement(
                symbol: "person.crop.circle.badge.plus",
                title: "Create a private guest session",
                detail: "No name, email, or installation ID becomes the account ID",
                isComplete: isAuthenticated
            )
            LifeMapEvaRequirement(
                symbol: "checkmark.shield.fill",
                title: "Available for ages 13+",
                detail: "Known under-13 accounts are blocked",
                isComplete: isAdultEligible
            )
            LifeMapEvaRequirement(
                symbol: "clock.arrow.circlepath",
                title: "Successful answers are limited",
                detail: "Rolling window; failures do not count",
                isComplete: isCloudReady
            )
        }
        .padding(Theme.Spacing.lg)
        .lifeBoardClaySurface(.resting, cornerRadius: 22)
        .accessibilityIdentifier(LifeMapAccessibilityID.evaRequirements)
    }

    /// Preselected, but never sent until the activation button confirms them.
    ///
    /// These are the four categories that never travel with a normal request.
    /// Base context — tasks, projects, habits, a read-only calendar projection —
    /// needs no grant; these do, and revocation is authoritative on the server
    /// before the next accepted request on any device.
    private var consentList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("EVA MAY ALSO LOOK AT")
                .font(.lifeboard(.eyebrow))
                .tracking(1.2)
                .foregroundStyle(Color.lifeboard(.textTertiary))
            ForEach(EvaConsentPolicy.Grant.allCases, id: \.rawValue) { grant in
                Toggle(isOn: Binding(
                    get: { selectedGrants.contains(grant) },
                    set: { onToggleGrant(grant, $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(grant.onboardingTitle)
                            .font(.lifeboard(.bodyStrong))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Text(grant.onboardingBlurb)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textTertiary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color.lifeboard(.accentPrimary))
                .disabled(isWorking)
                .padding(Theme.Spacing.md + 2)
                .lifeBoardClaySurface(.resting, cornerRadius: 16)
                .accessibilityIdentifier(LifeMapAccessibilityID.evaConsentRow(grant.rawValue))
            }
            Text("You can change these any time in EVA settings. Turning one off takes effect before EVA's next answer, on every device.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.evaConsentList)
    }
}

extension EvaConsentPolicy.Grant {
    var onboardingTitle: String {
        switch self {
        case .journal: "Journal entries"
        case .health: "Health summaries"
        case .lifeMoments: "Life moments"
        case .personalMemory: "What you've told EVA about you"
        }
    }

    var onboardingBlurb: String {
        switch self {
        case .journal: "So EVA can answer from what you wrote."
        case .health: "Bounded summaries only — never raw samples."
        case .lifeMoments: "The things you are counting down to."
        case .personalMemory: "Your working style, blockers, and goals."
        }
    }
}

struct LifeMapEvaRequirement: View {
    let symbol: String
    let title: String
    let detail: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(isComplete ? .statusSuccess : .accentPrimary))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(detail)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
            Spacer(minLength: Theme.Spacing.sm)
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(Color.lifeboard(isComplete ? .statusSuccess : .textQuaternary))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isComplete ? "Complete" : "Not complete")
    }
}
