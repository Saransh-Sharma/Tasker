import SwiftUI

public enum DailyReflectionClaimState: Equatable {
    case ready
    case submitting
    case claimed(xp: Int)
    case alreadyClaimed
    case unavailable(message: String)
}

/// Bottom sheet for daily reflection prompt.
/// Shows today's progress summary and awards XP on completion.
public struct DailyReflectionView: View {

    let tasksCompleted: Int
    let xpEarned: Int
    let streakDays: Int
    let claimState: DailyReflectionClaimState
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
                Text(statusMessage.text)
                    .font(.tasker(.caption1))
                    .foregroundColor(statusMessage.color)
                    .multilineTextAlignment(.center)
            }

            // Complete Button
            Button(action: {
                guard canClaim else { return }
                onComplete()
            }) {
                VStack(spacing: 2) {
                    Text(primaryCTA)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.textInverse)
                    Text(secondaryCTA)
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
            .disabled(!canClaim)
            .opacity(canClaim ? 1.0 : 0.6)
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

    private var canClaim: Bool {
        if case .ready = claimState {
            return true
        }
        if case .unavailable = claimState {
            return true
        }
        return false
    }

    private var primaryCTA: String {
        switch claimState {
        case .ready:
            return "Complete Reflection"
        case .submitting:
            return "Claiming Reflection..."
        case .claimed:
            return "Reflection Claimed"
        case .alreadyClaimed:
            return "Reflection Already Claimed"
        case .unavailable:
            return "Try Again"
        }
    }

    private var secondaryCTA: String {
        switch claimState {
        case .ready:
            return "+10 XP"
        case .submitting:
            return "Applying reward"
        case .claimed(let xp):
            return "+\(xp) XP secured"
        case .alreadyClaimed:
            return "Already completed today"
        case .unavailable:
            return "Claim unavailable"
        }
    }

    private var statusMessage: (text: String, color: Color)? {
        switch claimState {
        case .ready:
            return nil
        case .submitting:
            return ("Claiming reflection reward...", Color.tasker.textSecondary)
        case .claimed(let xp):
            return ("Reflection claimed. +\(xp) XP awarded.", Color.tasker.statusSuccess)
        case .alreadyClaimed:
            return ("Reflection already completed today.", Color.tasker.textSecondary)
        case .unavailable(let message):
            return (message, Color.tasker.statusDanger)
        }
    }
}
