import SwiftUI

struct EvaActivationIntroView: View {
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onContinue: () -> Void
    let onDismiss: () -> Void

    private let trustChips = ["On-device", "Private", "Ready in a minute"]

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var heroHeight: CGFloat {
        layoutClass.isPad ? 420 : 356
    }

    var body: some View {
        EvaActivationStageView(
            showsAmbientBackground: false,
            footer: {
                EvaFooterButtons(
                    primaryTitle: "Activate Eva",
                    secondaryTitle: "Not now",
                    isPrimaryDisabled: false,
                    onPrimary: onContinue,
                    onSecondary: onDismiss
                )
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                mediaPanel
                copyPanel(alignment: .leading)
                    .frame(maxWidth: layoutClass.isPad ? 720 : .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("eva.activation.intro")
    }

    private var mediaPanel: some View {
        Group {
            if layoutClass.isPad {
                EvaHeroMediaView()
                    .accessibilityIdentifier("eva.activation.intro.hero")
            } else {
                EvaHeroMediaView()
                    .accessibilityIdentifier("eva.activation.intro.hero")
                    .padding(.horizontal, -spacing.screenHorizontal)
                    .ignoresSafeArea(.container, edges: .horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .enhancedStaggeredAppearance(index: 0)
    }

    private func copyPanel(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: spacing.s16) {
            EvaContentHeader(
                title: "Meet Eva",
                bodyText: "Your private executive assistant for planning, prioritizing, and keeping momentum. Runs entirely on this device.",
                eyebrow: "EVA"
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
