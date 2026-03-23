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
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.tasker.accentWash)
                            .frame(width: 58, height: 58)

                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.tasker.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        HStack(spacing: spacing.s8) {
                            Text("Daily Reflection")
                                .font(.tasker(.title3))
                                .foregroundStyle(Color.tasker.textPrimary)
                            TaskerStatusPill(
                                text: statusBadgeText,
                                systemImage: statusBadgeSymbol,
                                tone: statusBadgeTone
                            )
                        }

                        Text(reflectionGuidance)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: spacing.s8) {
                    TaskerHeroMetricTile(
                        title: "Completed",
                        value: "\(tasksCompleted)",
                        detail: tasksCompleted == 0 ? "A tiny restart still counts" : "Visible wins from today",
                        tone: tasksCompleted > 0 ? .success : .neutral
                    )
                    TaskerHeroMetricTile(
                        title: "XP",
                        value: "\(xpEarned)",
                        detail: "Momentum earned today",
                        tone: xpEarned > 0 ? .accent : .neutral
                    )
                    TaskerHeroMetricTile(
                        title: "Streak",
                        value: "\(streakDays)d",
                        detail: streakDays > 0 ? "Continuity stays visible" : "Ready to restart",
                        tone: streakDays > 0 ? .warning : .neutral
                    )
                }
            }
            .padding(spacing.s16)
            .taskerPremiumSurface(
                cornerRadius: TaskerTheme.CornerRadius.card,
                fillColor: Color.tasker.surfacePrimary,
                accentColor: Color.tasker.accentSecondary,
                level: .e2
            )
            .taskerSuccessPulse(isActive: isCelebrating)

            VStack(alignment: .leading, spacing: spacing.s8) {
                Text("Today's signal")
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker.textTertiary)

                Text("\"\(motivationalQuote)\"")
                    .font(.tasker(.bodyEmphasis))
                    .italic()
                    .foregroundStyle(Color.tasker.textPrimary)
                    .multilineTextAlignment(.leading)

                if let statusMessage {
                    HStack(spacing: spacing.s8) {
                        Image(systemName: statusBadgeSymbol)
                            .font(.system(size: 12, weight: .semibold))
                        Text(statusMessage.text)
                            .font(.tasker(.caption1))
                    }
                    .foregroundStyle(statusMessage.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(spacing.s12)
            .taskerDenseSurface(
                cornerRadius: TaskerTheme.CornerRadius.card,
                fillColor: Color.tasker.surfacePrimary,
                strokeColor: Color.tasker.strokeHairline.opacity(0.72)
            )

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
                        .foregroundColor(Color.tasker.textInverse.opacity(0.82))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(buttonFillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(buttonStrokeColor, lineWidth: 1)
                )
            }
            .disabled(!canClaim)
            .opacity(canClaim ? 1.0 : 0.7)
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.vertical, spacing.s16)
        .background(Color.tasker.bgCanvas)
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

    private var statusBadgeText: String {
        switch claimState {
        case .ready:
            return "Ready"
        case .submitting:
            return "Claiming"
        case .claimed:
            return "Claimed"
        case .alreadyClaimed:
            return "Complete"
        case .unavailable:
            return "Retry"
        }
    }

    private var statusBadgeTone: TaskerStatusPillTone {
        switch claimState {
        case .ready:
            return .accent
        case .submitting:
            return .warning
        case .claimed, .alreadyClaimed:
            return .success
        case .unavailable:
            return .danger
        }
    }

    private var statusBadgeSymbol: String {
        switch claimState {
        case .ready:
            return "sparkles"
        case .submitting:
            return "hourglass"
        case .claimed, .alreadyClaimed:
            return "checkmark.circle.fill"
        case .unavailable:
            return "arrow.clockwise"
        }
    }

    private var reflectionGuidance: String {
        if tasksCompleted == 0 {
            return "Use reflection to reset the loop without turning today into a verdict."
        }
        return "Close the day by noticing progress, not chasing perfection."
    }

    private var isCelebrating: Bool {
        if case .claimed = claimState {
            return true
        }
        return false
    }

    private var buttonFillColor: Color {
        switch claimState {
        case .ready:
            return Color.tasker.accentPrimary
        case .submitting:
            return Color.tasker.accentPrimary.opacity(0.84)
        case .claimed, .alreadyClaimed:
            return Color.tasker.statusSuccess
        case .unavailable:
            return Color.tasker.statusDanger
        }
    }

    private var buttonStrokeColor: Color {
        switch claimState {
        case .ready, .submitting:
            return Color.tasker.accentPrimary.opacity(0.12)
        case .claimed, .alreadyClaimed:
            return Color.tasker.statusSuccess.opacity(0.2)
        case .unavailable:
            return Color.tasker.statusDanger.opacity(0.2)
        }
    }
}
