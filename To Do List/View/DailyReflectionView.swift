import SwiftUI

/// Bottom sheet for daily reflection prompt.
/// Shows today's progress summary and awards XP on completion.
public struct DailyReflectionView: View {

    let tasksCompleted: Int
    let xpEarned: Int
    let streakDays: Int
    let isSubmitting: Bool
    let alreadyCompletedToday: Bool
    let statusMessage: String?
    let onComplete: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private var motivationalQuote: String {
        let quotes = [
            "Small steps, big momentum",
            "Progress, not perfection",
            "Every task builds the system",
            "Consistency compounds",
            "You showed up — that matters"
        ]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return quotes[dayOfYear % quotes.count]
    }

    public var body: some View {
        VStack(spacing: spacing.s16) {
            Text("Daily Reflection")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color.tasker.textPrimary)

            // Stats
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text("Today's Progress")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                statRow(icon: "checkmark.circle.fill", color: Color.tasker.statusSuccess,
                        text: "\(tasksCompleted) tasks completed")
                statRow(icon: "star.fill", color: Color.tasker.accentPrimary,
                        text: "\(xpEarned) XP earned")
                statRow(icon: "flame.fill", color: Color.tasker.statusWarning,
                        text: "\(streakDays) day streak")
            }
            .padding(spacing.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tasker.surfacePrimary)
            )

            // Quote
            Text("\"\(motivationalQuote)\"")
                .font(.tasker(.bodyEmphasis))
                .italic()
                .foregroundColor(Color.tasker.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, spacing.s4)

            if let statusMessage {
                Text(statusMessage)
                    .font(.tasker(.caption1))
                    .foregroundColor(alreadyCompletedToday ? Color.tasker.textSecondary : Color.tasker.statusDanger)
                    .multilineTextAlignment(.center)
            }

            // Complete Button
            Button(action: {
                guard !isSubmitting, !alreadyCompletedToday else { return }
                onComplete()
            }) {
                VStack(spacing: 2) {
                    Text(alreadyCompletedToday ? "Reflection Claimed" : "Complete Reflection")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.textInverse)
                    Text(alreadyCompletedToday ? "Already completed today" : "+10 XP")
                        .font(.tasker(.caption2))
                        .foregroundColor(Color.tasker.textInverse.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.tasker.accentPrimary)
                )
            }
            .disabled(isSubmitting || alreadyCompletedToday)
            .opacity((isSubmitting || alreadyCompletedToday) ? 0.6 : 1.0)
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.vertical, spacing.s16)
        .accessibilityElement(children: .contain)
    }

    private func statRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(text)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textSecondary)
        }
    }
}
