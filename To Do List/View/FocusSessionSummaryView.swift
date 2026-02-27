import SwiftUI

/// Sheet shown after a focus session ends, displaying duration and XP earned.
public struct FocusSessionSummaryView: View {

    let durationSeconds: Int
    let xpAwarded: Int
    let dailyXPSoFar: Int
    let dailyXPCap: Int
    let onDismiss: () -> Void

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
            }

            Spacer()

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
