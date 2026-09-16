import SwiftUI

/// Sheet shown after a focus session ends.
public struct FocusSessionSummaryView: View {
    @Environment(\.lifeboardTokens) private var tokens

    private let durationSeconds: Int
    private let xpAwarded: Int
    private let dailyXPSoFar: Int
    private let onDismiss: () -> Void
    private let onContinueMomentum: (() -> Void)?

    public init(
        durationSeconds: Int,
        xpAwarded: Int,
        dailyXPSoFar: Int,
        onDismiss: @escaping () -> Void,
        onContinueMomentum: (() -> Void)? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.xpAwarded = xpAwarded
        self.dailyXPSoFar = dailyXPSoFar
        self.onDismiss = onDismiss
        self.onContinueMomentum = onContinueMomentum
    }

    private var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }

    private var minutesFocused: Int { durationSeconds / 60 }
    private var focusStyle: RoleStyle { ClayColorTokens.role(.focus) }

    public var body: some View {
        VStack(spacing: spacing.s16) {
            Spacer().frame(height: spacing.s8)

            DecorImage(asset: .thinkingCup, placement: .emptyState)

            // Token-backed type: `.title2.bold()` and `.largeTitle.bold()` were
            // the only sizes in this sheet that did not come from the scale.
            Text("Focus protected")
                .font(Typography.screenTitle())
                .foregroundStyle(ClayColorTokens.navy)

            VStack(spacing: spacing.s8) {
                Text("\(minutesFocused) min")
                    .font(Typography.hero())
                    .foregroundStyle(focusStyle.deep)
                    .monospacedDigit()

                Text("Time protected for the task you chose.")
                    .font(.lifeboard(.body))
                    .fontDesign(.rounded)
                    .foregroundStyle(ClayColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(spacing.s16)
            .frame(maxWidth: .infinity)
            .background(focusStyle.softSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(focusStyle.border, lineWidth: 1))

            VStack(spacing: spacing.s4) {
                Text("Next: choose another small action when you are ready.")
                    .font(.lifeboard(.callout))
                    .fontDesign(.rounded)
                    .foregroundStyle(ClayColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if let onContinueMomentum {
                // The design system's own quiet alternative, rather than a
                // hand-drawn fill, stroke and radius.
                Button("Choose next action", systemImage: "arrow.right", action: onContinueMomentum)
                    .font(.lifeboard(.bodyEmphasis))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.lifeBoardChip)
            }

            // The primary action uses the shared style: pill, 48pt, and the
            // same press response as every other commit in the product.
            Button("Done", systemImage: "checkmark", action: onDismiss)
                .font(.lifeboard(.bodyEmphasis))
                .frame(maxWidth: .infinity, minHeight: 48)
                .buttonStyle(.lifeBoardPrimary)
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
        .background(ClayColorTokens.canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus protected. \(minutesFocused) minutes focused.")
    }
}
