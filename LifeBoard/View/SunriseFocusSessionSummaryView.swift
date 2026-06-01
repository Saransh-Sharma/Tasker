import SwiftUI

/// Sheet shown after a focus session ends.
public struct SunriseFocusSessionSummaryView: View {

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

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    private var minutesFocused: Int { durationSeconds / 60 }
    private var focusStyle: LBRoleStyle { LBColorTokens.role(.focus) }

    public var body: some View {
        VStack(spacing: spacing.s16) {
            Spacer().frame(height: spacing.s8)

            SunriseDecorImage(asset: .thinkingCup, placement: .emptyState)

            Text("Focus protected")
                .font(.title2.bold())
                .fontDesign(.rounded)
                .foregroundStyle(LBColorTokens.navy)

            VStack(spacing: spacing.s8) {
                Text("\(minutesFocused) min")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(focusStyle.deep)
                    .monospacedDigit()

                Text("Time protected for the task you chose.")
                    .font(.lifeboard(.body))
                    .fontDesign(.rounded)
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(spacing.s16)
            .frame(maxWidth: .infinity)
            .background(focusStyle.softSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(focusStyle.border, lineWidth: 1))

            VStack(spacing: spacing.s4) {
                Text("Next: choose another small action when you are ready.")
                    .font(.lifeboard(.callout))
                    .fontDesign(.rounded)
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if let onContinueMomentum {
                Button("Choose next action", systemImage: "arrow.right", action: onContinueMomentum)
                    .font(.lifeboard(.bodyEmphasis))
                    .fontDesign(.rounded)
                    .foregroundStyle(focusStyle.deep)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(LBColorTokens.glassStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(focusStyle.border, lineWidth: 1))
            }

            Button("Done", systemImage: "checkmark", action: onDismiss)
                .font(.lifeboard(.bodyEmphasis))
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    LinearGradient(colors: LBColorTokens.actionGradient(for: .focus), startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
        .background(LBColorTokens.canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus protected. \(minutesFocused) minutes focused.")
    }
}
