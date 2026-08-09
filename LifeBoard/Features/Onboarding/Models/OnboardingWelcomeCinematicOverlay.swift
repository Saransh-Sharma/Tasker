import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingWelcomeCinematicOverlay: View {
    @Environment(\.lifeboardLayoutClass) var layoutClass
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    let phase: WelcomeIntroPhase
    let onContinue: () -> Void
    let onSkipDelay: () -> Void

    let trustItems = [
        ("clock", OnboardingCopy.Welcome.durationChip),
        ("arrow.uturn.backward.circle", OnboardingCopy.Welcome.changeLaterChip)
    ]

    var topInset: CGFloat {
        layoutClass.isPad ? 56 : 28
    }

    var titleVisible: Bool {
        phase.showsTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            if phase.showsIntroCard {
                cinematicCard
                    .padding(.top, topInset)
                    .padding(.horizontal, layoutClass.isPad ? 56 : 24)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: -220).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }

            Spacer(minLength: 0)

            if phase.showsIntroCTA {
                VStack(spacing: 14) {
                    Button {
                        onContinue()
                    } label: {
                        Text(OnboardingCopy.Welcome.primaryCTA)
                            .frame(maxWidth: .infinity)
                    }
                    .onboardingPrimaryButton()
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.welcomeIntroContinue)

                    OnboardingTrustRow(items: trustItems)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.welcome)
                .padding(.horizontal, layoutClass.isPad ? 56 : 24)
                .padding(.bottom, layoutClass.isPad ? 32 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.lifeboard(.overlayScrim).opacity(0.006))
        .contentShape(Rectangle())
        .onTapGesture {
            onSkipDelay()
        }
    }

    var cinematicCard: some View {
        VStack(spacing: 18) {
            OnboardingWelcomeIntroLine(
                text: "Welcome to LifeBoard",
                style: .display,
                isVisible: titleVisible,
                secondary: false
            )
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
        .padding(.vertical, 28)
        .frame(maxWidth: layoutClass.isPad ? 520 : 420)
        // One hero surface per screen, at the canonical floating depth. This
        // previously stacked a premium-glass treatment and a hand-rolled drop
        // shadow, which read heavier than anything else in the app.
        .lifeBoardClaySurface(.floating, cornerRadius: 34)
        .opacity(phase.introCardOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to LifeBoard.")
        .accessibilityIdentifier(AppOnboardingAccessibilityID.welcomeIntroTitleCard)
    }
}
