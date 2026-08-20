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
/// visible, and off by default.
///
/// Skipping them is the expected path, not a degraded one — a fresh account
/// bootstraps with revision 0 and no grants, which is already enough for chat.
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
            Text(isCloudReady ? "EVA is connected." : "Enable EVA with Apple.")
                .font(.lifeboard(.heroDisplay))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            Text(isCloudReady
                 ? "Your private cloud session is ready, with 100 credits to start. Choose anything extra EVA may look at — or continue and decide later."
                 : "Sign in with Apple enables Cloud EVA without sharing your name or email. Apple confirms an 18+ age range; LifeBoard never asks for your birth date.")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            requirements

            if isCloudReady {
                consentList
            }

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
                symbol: "apple.logo",
                title: "Sign in privately with Apple",
                detail: "A nonce-bound session for this device",
                isComplete: isAuthenticated
            )
            LifeMapEvaRequirement(
                symbol: "checkmark.shield.fill",
                title: "Confirm adult eligibility",
                detail: "Apple shares only an 18+ result",
                isComplete: isAdultEligible
            )
            LifeMapEvaRequirement(
                symbol: "creditcard.fill",
                title: "Start with 100 credits",
                detail: "Refills by 20 a day, capped at 100",
                isComplete: isCloudReady
            )
        }
        .padding(Theme.Spacing.lg)
        .lifeBoardClaySurface(.resting, cornerRadius: 22)
        .accessibilityIdentifier(LifeMapAccessibilityID.evaRequirements)
    }

    /// Off by default, every one of them.
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
