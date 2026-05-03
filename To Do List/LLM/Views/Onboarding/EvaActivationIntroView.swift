import SwiftUI

struct EvaActivationIntroView: View {
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onContinue: () -> Void
    let onDismiss: () -> Void

    @StateObject private var assistantIdentity = AssistantIdentityModel()

    private let trustChips = ["On-device", "Private", "Ready in a minute"]

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var heroHeight: CGFloat {
        layoutClass.isPad ? 420 : 356
    }

    private var stageHorizontalPaddingOverride: CGFloat? {
        layoutClass.isPad ? nil : 0
    }

    var body: some View {
        EvaActivationStageView(
            showsAmbientBackground: false,
            contentHorizontalPaddingOverride: stageHorizontalPaddingOverride,
            contentTopPaddingOverride: 0,
            footer: {
                EvaFooterButtons(
                    primaryTitle: "Activate \(assistantIdentity.snapshot.displayName)",
                    secondaryTitle: "Not now",
                    isPrimaryDisabled: false,
                    onPrimary: onContinue,
                    onSecondary: onDismiss
                )
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                mediaPanel
                copySection
            }
        }
        .accessibilityIdentifier("eva.activation.intro")
    }

    private var mediaPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: layoutClass.isPad ? TaskerTheme.CornerRadius.modal : 0, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tasker(.surfacePrimary),
                            Color.tasker(.accentWash).opacity(0.62),
                            Color.tasker(.surfacePrimary)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            EvaMascotView(
                placement: .chatHelp,
                size: .custom(layoutClass.isPad ? 240 : 204),
                decorative: false,
                accessibilityLabel: assistantIdentity.snapshot.displayName,
                mascotID: assistantIdentity.snapshot.mascotID
            )

            if reduceMotion == false {
                EvaLoopingLottieContainer(size: 76)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(TaskerTheme.Spacing.md)
            }
        }
        .accessibilityIdentifier("eva.activation.intro.hero")
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .overlay(
            RoundedRectangle(cornerRadius: layoutClass.isPad ? TaskerTheme.CornerRadius.modal : 0, style: .continuous)
                .stroke(Color.tasker(.strokeHairline), lineWidth: layoutClass.isPad ? 1 : 0)
        )
        .enhancedStaggeredAppearance(index: 0)
    }

    private var copySection: some View {
        copyPanel(alignment: .leading)
            .frame(maxWidth: layoutClass.isPad ? 720 : .infinity, alignment: .leading)
            .padding(.horizontal, layoutClass.isPad ? 0 : spacing.screenHorizontal)
    }

    private func copyPanel(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: spacing.s16) {
            EvaContentHeader(
                title: "Meet \(assistantIdentity.snapshot.displayName)",
                bodyText: "Your private executive assistant for planning, prioritizing, and keeping momentum. Runs entirely on this device.",
                eyebrow: assistantIdentity.snapshot.uppercaseName
            )
            .enhancedStaggeredAppearance(index: 1)

            EvaFlowLayout(spacing: spacing.s8, rowSpacing: spacing.s8) {
                ForEach(Array(trustChips.enumerated()), id: \.offset) { _, chip in
                    EvaInfoPill(title: chip)
                }
            }
            .enhancedStaggeredAppearance(index: 2)

            Text("No account needed. Setup stays local to your device.")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .enhancedStaggeredAppearance(index: 3)
        }
        .animation(reduceMotion ? nil : TaskerAnimation.gentle, value: layoutClass)
    }
}
