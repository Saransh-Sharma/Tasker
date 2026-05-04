import SwiftUI

/// XP Hero component for the Home cockpit area.
/// Displays: XP Ring, progress bar, level badge, streak indicator.
public struct HomeXPHeroView: View {

    let dailyXP: Int
    let dailyCap: Int
    let level: Int
    let streakDays: Int

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private var progress: CGFloat {
        guard dailyCap > 0 else { return 0 }
        return min(1.0, CGFloat(dailyXP) / CGFloat(dailyCap))
    }

    private var capReached: Bool {
        dailyXP >= dailyCap
    }

    public var body: some View {
        HStack(spacing: spacing.s16) {
            xpRing
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text("Today")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
                HStack(spacing: spacing.s4) {
                    Text("\(dailyXP)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color.tasker.accentPrimary)
                    Text("/ \(dailyCap) XP")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)
                }
                progressBar
            }

            Spacer()

            levelBadge
            streakIndicator
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.vertical, spacing.s12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's XP: \(dailyXP) of \(dailyCap). Level \(level). \(streakDays) day streak.")
    }

    // MARK: - Subviews

    private var xpRing: some View {
        let size = GamificationTokens.XPRingSize.homeHero
        return ZStack {
            Circle()
                .stroke(Color.tasker.accentSecondaryMuted, lineWidth: size.ringWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.tasker.accentPrimary, Color.tasker.accentSecondary]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: size.ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: GamificationTokens.SpringConfig.ringProgress.response,
                                   dampingFraction: GamificationTokens.SpringConfig.ringProgress.dampingFraction),
                           value: progress)
            Text("\(dailyXP)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.tasker.accentPrimary)
        }
        .frame(width: size.diameter, height: size.diameter)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.tasker.surfaceTertiary)
                Capsule()
                    .fill(capReached ? Color.tasker.statusSuccess : Color.tasker.accentPrimary)
                    .frame(width: geo.size.width * progress)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: GamificationTokens.progressBarHeight)
    }

    private var levelBadge: some View {
        Text("\(level)")
            .font(.system(size: GamificationTokens.levelBadgeFontSize, weight: .bold, design: .rounded))
            .foregroundColor(Color.tasker.textInverse)
            .frame(width: GamificationTokens.levelBadgeSize, height: GamificationTokens.levelBadgeSize)
            .background(Color.tasker.accentPrimary)
            .clipShape(Capsule())
            .accessibilityLabel("Level \(level)")
    }

    private var streakIndicator: some View {
        VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: GamificationTokens.streakFlameSize))
                .foregroundColor(streakDays > 0 ? Color.tasker.statusWarning : Color.tasker.textQuaternary)
                .shadow(
                    color: streakDays > 0
                        ? Color.tasker.statusWarning.opacity(GamificationTokens.streakGlowOpacity)
                        : .clear,
                    radius: 4
                )
            Text("\(streakDays)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color.tasker.textSecondary)
        }
        .accessibilityLabel("\(streakDays) day streak")
    }
}
