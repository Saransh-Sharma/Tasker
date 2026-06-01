import SwiftUI

/// Sheet shown after a focus session ends, displaying duration and XP earned.
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

    public var body: some View {
        VStack(spacing: spacing.s16) {
            Spacer().frame(height: spacing.s8)

            EvaMascotView(placement: .focusComplete, size: .card)

            Text("Session Complete")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.lifeboard.textPrimary)

            // XP + Duration Card
            VStack(spacing: spacing.s8) {
                Text("+\(xpAwarded) XP")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.lifeboard.accentPrimary)

                Text("\(minutesFocused) min focused")
                    .font(.lifeboard(.body))
                    .foregroundColor(Color.lifeboard.textSecondary)
            }
            .padding(spacing.s16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.lifeboard.surfacePrimary)
            )

            VStack(spacing: spacing.s4) {
                Text("Today: \(dailyXPSoFar) XP")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textSecondary)

                Text("Next: complete another task to keep momentum.")
                    .font(.lifeboard(.caption2))
                    .foregroundColor(Color.lifeboard.textTertiary)
            }

            Spacer()

            if let onContinueMomentum {
                Button(action: onContinueMomentum) {
                    Text("Complete Another Task")
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundColor(Color.lifeboard.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.lifeboard.accentPrimary, lineWidth: 1.5)
                        )
                }
            }

            Button(action: onDismiss) {
                Text("Done")
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundColor(Color.lifeboard.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lifeboard.accentPrimary)
                    )
            }
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session complete. \(xpAwarded) XP earned. \(minutesFocused) minutes focused.")
    }
}
