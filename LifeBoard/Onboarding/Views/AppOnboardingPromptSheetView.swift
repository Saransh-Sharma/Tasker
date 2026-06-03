import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct AppOnboardingPromptSheetView: View {
    @Environment(\.lifeboardLayoutClass) var layoutClass
    let snapshot: OnboardingWorkspaceSnapshot
    let onStart: () -> Void
    let onNotNow: () -> Void

    var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        ZStack {
            OnboardingPromptBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    promptContent
                        .padding(.top, spacing.s20)
                        .padding(.bottom, spacing.s16)
                }

                promptActionFooter
                    .padding(.bottom, spacing.s16)
            }
            .lifeboardReadableContent(maxWidth: 760, alignment: .center)
            .padding(.horizontal, promptHorizontalPadding)

            OnboardingAccessibilityMarker(
                identifier: AppOnboardingAccessibilityID.prompt,
                label: "Onboarding prompt",
                value: nil
            )
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
        }
        .interactiveDismissDisabled(true)
    }

    var promptHorizontalPadding: CGFloat {
        layoutClass.isPad ? spacing.s24 : max(16, spacing.screenHorizontal)
    }

    var promptContent: some View {
        ViewThatFits(in: .horizontal) {
            promptWideContent
            promptStackedContent
        }
        .padding(promptPanelPadding)
        .onboardingPromptGlassPanel(cornerRadius: 32)
    }

    var promptPanelPadding: CGFloat {
        layoutClass.isPad ? spacing.s24 : spacing.s20
    }

    var promptWideContent: some View {
        HStack(alignment: .top, spacing: spacing.s20) {
            OnboardingPromptValueCard(snapshot: snapshot)
                .frame(minWidth: 250, maxWidth: 310, alignment: .leading)
            promptReuseCard
                .frame(minWidth: 320, maxWidth: .infinity, alignment: .leading)
        }
    }

    var promptStackedContent: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingPromptValueCard(snapshot: snapshot)
            promptReuseCard
        }
    }

    var promptReuseCard: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            Text(String(localized: "onboarding.reuse.title"))
                .lifeboardFont(.bodyEmphasis)
                .foregroundStyle(OnboardingPromptTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            OnboardingPromptChecklistCard(items: [
                String(localized: "onboarding.reuse.item1"),
                String(localized: "onboarding.reuse.item2"),
                String(localized: "onboarding.reuse.item3"),
                String(localized: "onboarding.reuse.item4")
            ])
        }
    }

    var promptActionFooter: some View {
        VStack(spacing: spacing.s12) {
            Button {
                onStart()
            } label: {
                Text("Review matched setup")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPromptPrimaryCTAButtonStyle())
            .accessibilityIdentifier(AppOnboardingAccessibilityID.promptStart)

            Button("Not now") {
                onNotNow()
            }
            .onboardingSecondaryButtonStyle(accent: OnboardingPromptTheme.accent)
            .accessibilityIdentifier(AppOnboardingAccessibilityID.promptDismiss)
        }
        .padding(.top, spacing.s12)
        .padding(.horizontal, spacing.s16)
        .padding(.bottom, spacing.s4)
        .onboardingPromptFooterMaterial()
    }
}
