import SwiftUI

struct SunriseInsightsContentView: View {
    @ObservedObject var viewModel: InsightsViewModel
    let homeProgress: HomeProgressState
    let homeCompletionRate: Double
    let reflectionEligible: Bool
    let dailyReflectionEntryState: DailyReflectionEntryState?
    let momentumGuidanceText: String
    let animateMomentumCard: Bool
    let onOpenReflection: () -> Void

    var body: some View {
        switch viewModel.selectedTab {
        case .today:
            SunriseInsightsTodayView(
                viewModel: viewModel,
                homeProgress: homeProgress,
                homeCompletionRate: homeCompletionRate,
                reflectionEligible: reflectionEligible,
                dailyReflectionEntryState: dailyReflectionEntryState,
                momentumGuidanceText: momentumGuidanceText,
                animateMomentumCard: animateMomentumCard,
                onOpenReflection: onOpenReflection
            )
            .accessibilityIdentifier("home.insights.content.today")
        case .week:
            SunriseInsightsWeekView(viewModel: viewModel)
                .accessibilityIdentifier("home.insights.content.week")
        case .systems:
            SunriseInsightsSystemsView(viewModel: viewModel)
                .accessibilityIdentifier("home.insights.content.systems")
        }
    }
}

private struct SunriseInsightsTodayView: View {
    @ObservedObject var viewModel: InsightsViewModel
    let homeProgress: HomeProgressState
    let homeCompletionRate: Double
    let reflectionEligible: Bool
    let dailyReflectionEntryState: DailyReflectionEntryState?
    let momentumGuidanceText: String
    let animateMomentumCard: Bool
    let onOpenReflection: () -> Void

    @State private var showDetails = false
    private var state: InsightsTodayState { viewModel.todayState }

    var body: some View {
        LazyVStack(spacing: LBSpacingTokens.sm) {
            SunriseInsightHeroCard(
                eyebrow: "Today",
                title: state.heroCard.title,
                answer: state.heroCard.hint,
                metric: state.heroCard.metric,
                role: .focus,
                primaryActionTitle: reflectionEligible ? "Reflect" : nil,
                primaryAction: onOpenReflection
            )

            if let dailyReflectionEntryState {
                HomeDailyReflectionEntryCard(
                    state: dailyReflectionEntryState,
                    mode: .compact,
                    onOpen: onOpenReflection
                )
            }

            SunriseInsightActionCard(
                title: "Next decision",
                message: firstDetail(from: state.duePressureMetrics) ?? "No urgent pressure is visible right now.",
                systemImage: "exclamationmark.arrow.triangle.2.circlepath",
                role: .warning
            )

            SunriseInsightActionCard(
                title: "Protect focus",
                message: firstDetail(from: state.focusMetrics) ?? momentumGuidanceText,
                systemImage: "sparkles",
                role: .focus
            )

            SunriseInsightDisclosureCard(
                title: "Today details",
                summary: "XP, pressure, recovery, and completion mix stay here when you need them.",
                isExpanded: $showDetails
            ) {
                VStack(spacing: LBSpacingTokens.sm) {
                    HomeMomentumSummaryCard(
                        progress: homeProgress,
                        completionRate: homeCompletionRate,
                        reflectionEligible: reflectionEligible,
                        momentumGuidanceText: momentumGuidanceText,
                        animate: animateMomentumCard,
                        onOpenReflection: onOpenReflection
                    )
                    SunriseMetricSection(title: "Due pressure", metrics: state.duePressureMetrics)
                    SunriseMetricSection(title: "Focus pulse", metrics: state.focusMetrics)
                    SunriseMetricSection(title: "Momentum", metrics: state.momentumMetrics)
                    SunriseMetricSection(title: "Recovery", metrics: state.recoveryMetrics)
                    SunriseDistributionSections(title: "Completion mix", sections: state.completionMixSections)
                }
            }
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
        .padding(.bottom, LBSpacingTokens.xl)
    }

    private func firstDetail(from metrics: [InsightsMetricTile]) -> String? {
        guard let metric = metrics.first else { return nil }
        return "\(metric.title): \(metric.value). \(metric.detail)"
    }
}

private struct SunriseInsightsWeekView: View {
    @ObservedObject var viewModel: InsightsViewModel
    @State private var showDetails = false
    private var state: InsightsWeekState { viewModel.weekState }

    var body: some View {
        LazyVStack(spacing: LBSpacingTokens.sm) {
            SunriseInsightHeroCard(
                eyebrow: "Week",
                title: state.heroCard.title,
                answer: state.heroCard.hint,
                metric: state.patternSummary,
                role: .routine,
                primaryActionTitle: nil,
                primaryAction: {}
            )

            SunriseInsightActionCard(
                title: "Pattern to use",
                message: state.deltaSummary,
                systemImage: "chart.bar.xaxis",
                role: .routine
            )

            if let weeklyOperating = state.weeklyOperating {
                SunriseInsightActionCard(
                    title: weeklyOperating.recoveryHeadline,
                    message: weeklyOperating.recoverySummary,
                    systemImage: "arrow.clockwise.heart",
                    role: .assistant
                )
            }

            SunriseInsightDisclosureCard(
                title: "Week details",
                summary: "Momentum bars, project mix, priority mix, and operating review.",
                isExpanded: $showDetails
            ) {
                VStack(spacing: LBSpacingTokens.sm) {
                    SunriseWeekBarsCard(state: state, scaleMode: viewModel.weekScaleMode)
                    SunriseMetricSection(title: "Week summary", metrics: state.weeklySummaryMetrics)
                    SunriseLeaderboardCard(rows: state.projectLeaderboard)
                    SunriseDistributionItems(title: "Priority mix", items: state.priorityMix)
                    SunriseDistributionItems(title: "Task-type mix", items: state.taskTypeMix)
                    if let weeklyOperating = state.weeklyOperating {
                        SunriseNarrativeCard(title: "Operating review", message: weeklyOperating.momentumNarrative)
                        SunriseNarrativeCard(title: "Carry-over", message: weeklyOperating.carryOverSummary)
                    }
                }
            }
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
        .padding(.bottom, LBSpacingTokens.xl)
    }
}

private struct SunriseInsightsSystemsView: View {
    @ObservedObject var viewModel: InsightsViewModel
    @State private var showDetails = false
    private var state: InsightsSystemsState { viewModel.systemsState }

    var body: some View {
        LazyVStack(spacing: LBSpacingTokens.sm) {
            SunriseInsightHeroCard(
                eyebrow: "Systems",
                title: state.heroCard.title,
                answer: state.heroCard.hint,
                metric: state.heroSummary,
                role: .assistant,
                primaryActionTitle: nil,
                primaryAction: {}
            )

            SunriseInsightActionCard(
                title: "Reminder response",
                message: state.reminderResponse.detail,
                systemImage: "bell.badge",
                role: .assistant
            )

            SunriseInsightActionCard(
                title: "Consistency check",
                message: firstDetail(from: state.focusHealthMetrics) ?? "Focus and recovery patterns will sharpen as you use the app.",
                systemImage: "checkmark.seal",
                role: .task
            )

            SunriseInsightDisclosureCard(
                title: "System details",
                summary: "Reminder response, focus health, recovery health, streak resilience, and achievements.",
                isExpanded: $showDetails
            ) {
                VStack(spacing: LBSpacingTokens.sm) {
                    SunriseReminderResponseCard(state: state.reminderResponse)
                    SunriseMetricSection(title: "Focus health", metrics: state.focusHealthMetrics)
                    SunriseMetricSection(title: "Recovery health", metrics: state.recoveryHealthMetrics)
                    SunriseMetricSection(title: "Streak resilience", metrics: state.streakMetrics)
                    SunriseMetricSection(title: "Achievement velocity", metrics: state.achievementVelocityMetrics)
                    SunriseNarrativeCard(
                        title: "Achievements",
                        message: "\(state.unlockedAchievements.count) unlocked. \(state.nextMilestone.map { "Next: \($0.name)." } ?? "Top milestone reached.")"
                    )
                }
            }
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
        .padding(.bottom, LBSpacingTokens.xl)
    }

    private func firstDetail(from metrics: [InsightsMetricTile]) -> String? {
        guard let metric = metrics.first else { return nil }
        return "\(metric.title): \(metric.value). \(metric.detail)"
    }
}

private struct SunriseInsightHeroCard: View {
    let eyebrow: String
    let title: String
    let answer: String
    let metric: String
    let role: LBRole
    let primaryActionTitle: String?
    let primaryAction: () -> Void

    private var style: LBRoleStyle { LBColorTokens.role(role) }

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            Label(eyebrow, systemImage: style.symbolName)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(style.deep)

            Text(title)
                .font(.lifeboard(.title2))
                .foregroundStyle(LBColorTokens.navy)
                .fixedSize(horizontal: false, vertical: true)

            Text(answer)
                .font(.lifeboard(.headline))
                .foregroundStyle(LBColorTokens.navySoft)
                .fixedSize(horizontal: false, vertical: true)

            Text(metric)
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let primaryActionTitle {
                Button(primaryActionTitle, systemImage: "arrow.right", action: primaryAction)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, LBSpacingTokens.md)
                    .frame(minHeight: 44)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: LBColorTokens.actionGradient(for: role),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LBSpacingTokens.lg)
        .sunriseInsightSurface(role: role, cornerRadius: 28)
    }
}

private struct SunriseInsightActionCard: View {
    let title: String
    let message: String
    let systemImage: String
    let role: LBRole

    private var style: LBRoleStyle { LBColorTokens.role(role) }

    var body: some View {
        HStack(alignment: .top, spacing: LBSpacingTokens.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(style.deep)
                .frame(width: 36, height: 36)
                .background(Circle().fill(style.softSurface))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(LBColorTokens.navy)
                Text(message)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(LBSpacingTokens.md)
        .sunriseInsightSurface(role: role, cornerRadius: 22)
    }
}

private struct SunriseInsightDisclosureCard<Content: View>: View {
    let title: String
    let summary: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? LBSpacingTokens.md : 0) {
            Button {
                withAnimation(LifeBoardAnimation.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: LBSpacingTokens.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(LBColorTokens.navy)
                        Text(summary)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LBColorTokens.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(LBSpacingTokens.md)
        .sunriseInsightSurface(role: .neutral, cornerRadius: 22)
    }
}

private struct SunriseMetricSection: View {
    let title: String
    let metrics: [InsightsMetricTile]

    var body: some View {
        if metrics.isEmpty == false {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text(title)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LBSpacingTokens.xs) {
                    ForEach(metrics) { metric in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(metric.title)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(LBColorTokens.textTertiary)
                            Text(metric.value)
                                .font(.lifeboard(.headline))
                                .foregroundStyle(color(for: metric.tone))
                            Text(metric.detail)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(LBColorTokens.navyMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                        .padding(LBSpacingTokens.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LBColorTokens.glassStrong)
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func color(for tone: InsightsMetricTone) -> Color {
        switch tone {
        case .accent:
            return LBColorTokens.violet
        case .success:
            return LBColorTokens.leaf
        case .warning:
            return LBColorTokens.sunriseGold
        case .neutral:
            return LBColorTokens.navy
        }
    }
}

private struct SunriseDistributionSections: View {
    let title: String
    let sections: [InsightsDistributionSection]

    var body: some View {
        if sections.isEmpty == false {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text(title)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                ForEach(sections) { section in
                    SunriseDistributionItems(title: section.title, items: section.items)
                }
            }
        }
    }
}

private struct SunriseDistributionItems: View {
    let title: String
    let items: [InsightsDistributionItem]

    var body: some View {
        if items.isEmpty == false {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text(title)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navyMuted)
                ForEach(items) { item in
                    HStack(spacing: LBSpacingTokens.xs) {
                        Text(item.label)
                            .font(.lifeboard(.callout))
                            .foregroundStyle(LBColorTokens.navy)
                        Spacer()
                        Text(item.valueText)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(LBColorTokens.navyMuted)
                    }
                    .padding(LBSpacingTokens.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LBColorTokens.glassStrong)
                    )
                }
            }
        }
    }
}

private struct SunriseLeaderboardCard: View {
    let rows: [InsightsLeaderboardRow]

    var body: some View {
        if rows.isEmpty == false {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text("Project movement")
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                ForEach(rows.prefix(5)) { row in
                    HStack(spacing: LBSpacingTokens.xs) {
                        Text(row.subtitle)
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(LBColorTokens.textTertiary)
                        Text(row.title)
                            .font(.lifeboard(.callout))
                            .foregroundStyle(LBColorTokens.navy)
                        Spacer()
                        Text(row.value)
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(LBColorTokens.violet)
                    }
                    .padding(LBSpacingTokens.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LBColorTokens.glassStrong)
                    )
                }
            }
        }
    }
}

private struct SunriseWeekBarsCard: View {
    let state: InsightsWeekState
    let scaleMode: InsightsWeekScaleMode

    private var maxBarXP: Int {
        let personalMax = max(state.weeklyBars.map(\.xp).max() ?? 1, 1)
        switch scaleMode {
        case .goal:
            return max(personalMax, GamificationTokens.dailyXPCap)
        case .personalMax:
            return personalMax
        }
    }

    var body: some View {
        if state.weeklyBars.isEmpty == false {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text("Weekly rhythm")
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)

                HStack(alignment: .bottom, spacing: LBSpacingTokens.xs) {
                    ForEach(state.weeklyBars) { bar in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(bar.isToday ? LBColorTokens.violet : LBColorTokens.sunriseGold.opacity(0.64))
                                .frame(height: max(8, 76 * CGFloat(bar.xp) / CGFloat(maxBarXP)))
                            Text(bar.label)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(bar.isToday ? LBColorTokens.navy : LBColorTokens.navyMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 108, alignment: .bottom)
            }
        }
    }
}

private struct SunriseReminderResponseCard: View {
    let state: InsightsReminderResponseState

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
            Text(state.headline)
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)
            Text(state.detail)
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
            ForEach(state.statusItems) { item in
                HStack {
                    Text(item.label)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navy)
                    Spacer()
                    Text(item.valueText)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(LBColorTokens.violet)
                }
                .padding(LBSpacingTokens.sm)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LBColorTokens.glassStrong)
                )
            }
        }
    }
}

private struct SunriseNarrativeCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)
            Text(message)
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LBSpacingTokens.sm)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LBColorTokens.glassStrong)
        )
    }
}

private extension View {
    func sunriseInsightSurface(role: LBRole, cornerRadius: CGFloat) -> some View {
        modifier(SunriseInsightSurfaceModifier(role: role, cornerRadius: cornerRadius))
    }
}

private struct SunriseInsightSurfaceModifier: ViewModifier {
    let role: LBRole
    let cornerRadius: CGFloat

    private var style: LBRoleStyle { LBColorTokens.role(role) }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(
                        LinearGradient(
                            colors: [style.softSurface, LBColorTokens.glassStrong],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                shape.stroke(style.border.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: LBColorTokens.elevationShadow, radius: 16, x: 0, y: 9)
    }
}
