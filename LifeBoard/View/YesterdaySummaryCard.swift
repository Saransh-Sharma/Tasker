import SwiftUI

struct YesterdaySummaryCard: View {
    let snapshot: DailyReflectionCoreSnapshot

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SunriseDecorImage(asset: decorAsset, size: 164, opacity: reduceTransparency ? 0.18 : 0.34)
                .offset(x: 18, y: 10)

            VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
                HStack(spacing: LBSpacingTokens.sm) {
                    iconToken
                    Text("Yesterday")
                        .font(.lifeboard(.title2).weight(.bold))
                        .foregroundStyle(LBColorTokens.navy)
                    Spacer(minLength: LBSpacingTokens.sm)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summaryCopy.headline)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(LBColorTokens.navy)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(summaryCopy.detail)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.trailing, 72)

                VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                    Text("Habit streaks")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navySoft)

                    if snapshot.habitGrid.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("No streak signal yet")
                                .font(.lifeboard(.callout).weight(.semibold))
                                .foregroundStyle(LBColorTokens.navy)
                            Text("Start with one protected habit today.")
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(LBColorTokens.navyMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(LBSpacingTokens.md)
                        .background(ReflectPlanStyle.cream.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: LBSpacingTokens.sm),
                                GridItem(.flexible(), spacing: LBSpacingTokens.sm)
                            ],
                            spacing: LBSpacingTokens.sm
                        ) {
                            ForEach(snapshot.habitGrid.prefix(4)) { habit in
                                HabitStreakMiniCard(habit: habit)
                            }
                        }
                    }
                }
            }
            .padding(LBSpacingTokens.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(ReflectPlanStyle.peachBorder.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: ReflectPlanStyle.shadow, radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Yesterday summary. \(summaryCopy.headline). \(summaryCopy.detail). Habit streaks available.")
    }

    private var iconToken: some View {
        ZStack {
            Circle()
                .fill(ReflectPlanStyle.goldSurface)
                .frame(width: 42, height: 42)
            Image(systemName: "sunrise.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LBColorTokens.role(.warning).deep)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(ReflectPlanStyle.peachSurfaceStrong)
        } else {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ReflectPlanStyle.peachSurfaceStrong,
                            ReflectPlanStyle.peachSurface,
                            ReflectPlanStyle.cream
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }

    private var decorAsset: SunriseDecorAsset {
        if snapshot.tasksSummary.completedCount <= 0 {
            return .subtleLeaf
        }
        if snapshot.tasksSummary.carryOverCount >= 3 || snapshot.tasksSummary.overdueOpenCount >= 3 {
            return .mountain
        }
        return .growthPlant
    }

    private var summaryCopy: (headline: String, detail: String) {
        if snapshot.tasksSummary.scheduledCount == 0 && snapshot.habitGrid.isEmpty {
            return ("Yesterday was quiet.", "Add a little context so LifeBoard can plan better.")
        }
        if snapshot.tasksSummary.carryOverCount >= 3 || snapshot.tasksSummary.overdueOpenCount >= 3 {
            return ("Yesterday carried too much.", "Today should start smaller and clearer.")
        }
        if snapshot.tasksSummary.completedCount <= 0 {
            return ("Yesterday stayed light.", "Today can stay narrow and easier to finish.")
        }
        if snapshot.tasksSummary.completedCount >= max(2, snapshot.tasksSummary.scheduledCount / 2) {
            return ("Yesterday had momentum.", "Reuse what worked and keep today focused.")
        }
        return ("Small wins build recovery.", "You kept things light and protected what mattered.")
    }
}
