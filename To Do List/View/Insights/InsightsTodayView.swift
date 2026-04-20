import SwiftUI

/// Today tab content for the Insights screen.
struct InsightsTodayView: View {

    @ObservedObject var viewModel: InsightsViewModel
    let homeProgress: HomeProgressState
    let homeCompletionRate: Double
    let reflectionEligible: Bool
    let dailyReflectionEntryState: DailyReflectionEntryState?
    let momentumGuidanceText: String
    let animateMomentumCard: Bool
    let onOpenReflection: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var didAppear = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var state: InsightsTodayState { viewModel.todayState }
    private var shouldReduceAnimation: Bool {
        reduceMotion || dynamicTypeSize.isAccessibilitySize || V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled
    }

    private var progress: CGFloat {
        guard state.dailyCap > 0 else { return 0 }
        return min(1.0, CGFloat(state.dailyXP) / CGFloat(state.dailyCap))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: spacing.s12) {
            module(index: 0) {
                HomeMomentumSummaryCard(
                    progress: homeProgress,
                    completionRate: homeCompletionRate,
                    reflectionEligible: reflectionEligible,
                    momentumGuidanceText: momentumGuidanceText,
                    animate: animateMomentumCard,
                    onOpenReflection: onOpenReflection
                )
            }
            module(index: 1) {
                heroCard
            }
            module(index: 2) {
                if let dailyReflectionEntryState {
                    HomeDailyReflectionEntryCard(
                        state: dailyReflectionEntryState,
                        mode: .full,
                        onOpen: onOpenReflection
                    )
                }
            }
            module(index: 3) {
                metricGridCard(
                    eyebrow: "Due pressure",
                    title: "Decide these next",
                    subtitle: "Clear, reschedule, or unblock.",
                    metrics: state.duePressureMetrics
                )
            }
            module(index: 4) {
                goalAndPaceCard
            }
            module(index: 5) {
                metricGridCard(
                    eyebrow: "Focus pulse",
                    title: "Protect deep work",
                    subtitle: "One quality session beats constant switching.",
                    metrics: state.focusMetrics
                )
            }
            module(index: 6) {
                metricGridCard(
                    eyebrow: "Momentum board",
                    title: "Today snapshot",
                    subtitle: "Output and streak status.",
                    metrics: state.momentumMetrics
                )
            }
            module(index: 7) {
                metricGridCard(
                    eyebrow: "Recovery loop",
                    title: "Stop backlog drift",
                    subtitle: "Recovery actions keep pressure from compounding.",
                    metrics: state.recoveryMetrics
                )
            }
            module(index: 8) {
                completionMixCard
            }
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
        .onAppear {
            didAppear = true
        }
    }

    private var heroCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Today")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text(state.heroCard.title)
                    .font(.tasker(.title2))
                    .foregroundColor(Color.tasker.textPrimary)

                Text(state.heroCard.metric)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                Text(state.heroCard.hint)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)

                HStack(alignment: .bottom, spacing: spacing.s16) {
                    xpGauge
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        metricPill(title: "Level", value: "L\(state.level)", tone: .accent)
                        metricPill(
                            title: "XP source",
                            value: state.xpBreakdown.first?.displayName ?? "Waiting",
                            tone: .neutral
                        )
                        metricPill(
                            title: "Next move",
                            value: state.heroCard.hint,
                            tone: .warning
                        )
                    }
                }

                if let detail = state.heroCard.detail, detail.isEmpty == false {
                    DisclosureGroup("Details") {
                        Text(detail)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                            .padding(.top, spacing.s4)
                    }
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(state.heroCard.title). \(state.heroCard.metric). \(state.heroCard.hint)")
        }
    }

    private var xpGauge: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            ZStack {
                Circle()
                    .stroke(Color.tasker.surfaceTertiary, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.tasker.accentPrimary, Color.tasker.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(state.dailyXP)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.tasker.textPrimary)
                    Text("/ \(state.dailyCap)")
                        .font(.tasker(.caption2))
                        .foregroundColor(Color.tasker.textTertiary)
                }
            }
            .frame(width: 116, height: 116)

            Text(progress >= 1 ? "Daily cap reached" : "\(max(0, state.dailyCap - state.dailyXP)) XP still available")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
        }
    }

    private var goalAndPaceCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Goal + pace")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text("Keep output and effort aligned.")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                progressTrack(
                    title: "Daily cap",
                    value: state.dailyXP,
                    total: state.dailyCap,
                    tone: state.dailyXP >= state.dailyCap ? .success : .accent
                )

                ForEach(state.paceMetrics) { metric in
                    HStack(alignment: .top, spacing: spacing.s8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title)
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textTertiary)
                            Text(metric.value)
                                .font(.tasker(.headline))
                                .foregroundColor(toneColor(metric.tone))
                        }
                        Spacer()
                        Text(metric.detail)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var completionMixCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Completion mix")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text(state.completionMixSections.isEmpty
                        ? "Complete one task to unlock today’s mix."
                        : "What got finished.")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                if state.completionMixSections.isEmpty {
                    Text("Mix appears after the first completion.")
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textSecondary)
                } else {
                    ForEach(state.completionMixSections) { section in
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            Text(section.title)
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textSecondary)

                            ForEach(section.items) { item in
                                distributionRow(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private func metricGridCard(
        eyebrow: String,
        title: String,
        subtitle: String,
        metrics: [InsightsMetricTile]
    ) -> some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(eyebrow)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text(title)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                Text(subtitle)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)

                LazyVGrid(columns: columns, spacing: spacing.s8) {
                    ForEach(metrics) { metric in
                        metricCard(metric)
                    }
                }
            }
        }
    }

    private func metricCard(_ metric: InsightsMetricTile) -> some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(metric.title)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)
            Text(metric.value)
                .font(.tasker(.headline))
                .foregroundColor(toneColor(metric.tone))
                .fixedSize(horizontal: false, vertical: true)
            Text(metric.detail)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.tasker.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(toneColor(metric.tone).opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.title). \(metric.value). \(metric.detail)")
    }

    private func metricPill(title: String, value: String, tone: InsightsMetricTone) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)
            Text(value)
                .font(.tasker(.caption1))
                .foregroundColor(toneColor(tone))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.tasker.surfaceSecondary)
        )
    }

    private func progressTrack(title: String, value: Int, total: Int, tone: InsightsMetricTone) -> some View {
        let ratio = total == 0 ? 0 : min(1, CGFloat(value) / CGFloat(total))
        return VStack(alignment: .leading, spacing: spacing.s4) {
            HStack {
                Text(title)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
                Spacer()
                Text("\(value) / \(total)")
                    .font(.tasker(.caption1))
                    .foregroundColor(toneColor(tone))
            }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.tasker.surfaceTertiary)
                Capsule()
                    .fill(toneColor(tone))
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: ratio, y: 1, anchor: .leading)
            }
            .frame(height: 10)
        }
    }

    private func distributionRow(_ item: InsightsDistributionItem) -> some View {
        HStack(spacing: spacing.s8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textPrimary)
                Text(item.valueText)
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
            }
            Spacer()
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.tasker.surfaceTertiary)
                    .frame(width: 84, height: 8)
                Capsule()
                    .fill(toneColor(item.tone))
                    .frame(width: max(8, 84 * CGFloat(item.share)), height: 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.label). \(item.valueText)")
    }

    private func module<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        let delay = min(0.12, Double(index) * 0.015)
        return content()
            .opacity(shouldReduceAnimation || didAppear ? 1 : 0.98)
            .animation(
                shouldReduceAnimation ? nil : TaskerAnimation.quick.delay(delay),
                value: didAppear
            )
    }

    @ViewBuilder
    private func insightsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .taskerAnalyticsSurface(
                cornerRadius: 24,
                fillColor: Color.tasker.surfacePrimary,
                strokeColor: Color.tasker.strokeHairline.opacity(0.82),
                accentColor: Color.tasker.accentSecondary,
                level: .e1
            )
    }

    private func toneColor(_ tone: InsightsMetricTone) -> Color {
        switch tone {
        case .accent:
            return Color.tasker.accentPrimary
        case .success:
            return Color.tasker.statusSuccess
        case .warning:
            return Color.tasker.statusWarning
        case .neutral:
            return Color.tasker.textPrimary
        }
    }
}
