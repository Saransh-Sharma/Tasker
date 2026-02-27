import SwiftUI

/// Sheet shown after a focus session ends, displaying duration and XP earned.
public struct FocusSessionSummaryView: View {

    private let durationSeconds: Int
    private let xpAwarded: Int
    private let dailyXPSoFar: Int
    private let dailyXPCap: Int
    private let onDismiss: () -> Void
    private let onContinueMomentum: (() -> Void)?

    public init(
        durationSeconds: Int,
        xpAwarded: Int,
        dailyXPSoFar: Int,
        dailyXPCap: Int,
        onDismiss: @escaping () -> Void,
        onContinueMomentum: (() -> Void)? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.xpAwarded = xpAwarded
        self.dailyXPSoFar = dailyXPSoFar
        self.dailyXPCap = dailyXPCap
        self.onDismiss = onDismiss
        self.onContinueMomentum = onContinueMomentum
    }

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private var minutesFocused: Int { durationSeconds / 60 }

    private var dailyProgress: CGFloat {
        guard dailyXPCap > 0 else { return 0 }
        return min(1.0, CGFloat(dailyXPSoFar) / CGFloat(dailyXPCap))
    }

    public var body: some View {
        VStack(spacing: spacing.s16) {
            Spacer().frame(height: spacing.s8)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.tasker.statusSuccess)

            Text("Session Complete")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.tasker.textPrimary)

            // XP + Duration Card
            VStack(spacing: spacing.s8) {
                Text("+\(xpAwarded) XP")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.tasker.accentPrimary)

                Text("\(minutesFocused) min focused")
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .padding(spacing.s16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.tasker.surfacePrimary)
            )

            // Daily Progress
            VStack(spacing: spacing.s4) {
                Text("Today: \(dailyXPSoFar)/\(dailyXPCap) XP")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.tasker.surfaceTertiary)
                        Capsule()
                            .fill(dailyXPSoFar >= dailyXPCap ? Color.tasker.statusSuccess : Color.tasker.accentPrimary)
                            .frame(width: geo.size.width * dailyProgress)
                            .animation(.easeInOut(duration: 0.3), value: dailyProgress)
                    }
                }
                .frame(height: GamificationTokens.progressBarHeight)

                Text("Next: complete another task to keep momentum.")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
            }

            Spacer()

            if let onContinueMomentum {
                Button(action: onContinueMomentum) {
                    Text("Complete Another Task")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.tasker.accentPrimary, lineWidth: 1.5)
                        )
                }
            }

            Button(action: onDismiss) {
                Text("Done")
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.tasker.accentPrimary)
                    )
            }
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session complete. \(xpAwarded) XP earned. \(minutesFocused) minutes focused.")
    }
}
