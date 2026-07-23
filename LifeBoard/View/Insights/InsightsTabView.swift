import SwiftUI

/// Root view for the Insights screen with Today / Week / Systems tabs.
public struct InsightsTabView: View {
    @ObservedObject var viewModel: InsightsViewModel
    let homeProgress: HomeProgressState
    let homeCompletionRate: Double
    let reflectionEligible: Bool
    let dailyReflectionEntryState: DailyReflectionEntryState?
    let momentumGuidanceText: String
    let animateMomentumCard: Bool
    let onOpenReflection: () -> Void
    let onPerformInsightAction: (InsightsActionIntent) -> Void
    var bottomInset: CGFloat = 0
    var topContentInset: CGFloat = 0
    var onBackToTasks: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @State private var scrollTraceCoordinator = InsightsScrollTraceCoordinator()
    @State private var pendingDetailAnchor: InsightsDetailAnchor?
    @State private var isWeekDetailsExpanded = false
    @State private var isSystemsDetailsExpanded = false

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    public var body: some View {
        SunriseDestinationScaffold(
            title: "Insights",
            subtitle: "Your progress at a glance.",
            headerSymbolName: "chart.bar.xaxis",
            leadingSystemImage: "line.3.horizontal",
            leadingAccessibilityLabel: "Back to tasks",
            leadingAccessibilityIdentifier: "home.sunrise.collapseHint",
            leadingAction: { onBackToTasks?() },
            trailingSystemImage: "gearshape",
            trailingAccessibilityLabel: "Settings",
            trailingAction: { onOpenSettings?() },
            metricPillTitle: attentionPillTitle,
            bottomInset: 0,
            topContentInset: topContentInset
        ) {
            VStack(spacing: LBSpacingTokens.md) {
                SunriseInsightsHeaderView(
                    selectedTab: viewModel.selectedTab,
                    onSelectTab: { tab in
                        viewModel.selectTab(tab)
                    }
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        SunriseInsightsContentView(
                            viewModel: viewModel,
                            homeProgress: homeProgress,
                            homeCompletionRate: homeCompletionRate,
                            reflectionEligible: reflectionEligible,
                            dailyReflectionEntryState: dailyReflectionEntryState,
                            momentumGuidanceText: momentumGuidanceText,
                            animateMomentumCard: animateMomentumCard,
                            onOpenReflection: onOpenReflection,
                            onPerformInsightAction: onPerformInsightAction,
                            pendingDetailAnchor: $pendingDetailAnchor,
                            isWeekDetailsExpanded: $isWeekDetailsExpanded,
                            isSystemsDetailsExpanded: $isSystemsDetailsExpanded
                        )
                        .padding(.bottom, bottomInset + spacing.s24)
                    }
                    .padding(.bottom, spacing.s16)
                    .scrollIndicators(.hidden)
                    .onScrollGeometryChange(
                        for: CGFloat.self,
                        of: { geometry in
                            max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                        },
                        action: { oldOffset, newOffset in
                            scrollTraceCoordinator.recordScrollActivity(
                                oldOffset: oldOffset,
                                newOffset: newOffset
                            )
                        }
                    )
                    .onChange(of: pendingDetailAnchor) { _, anchor in
                        guard let anchor else { return }
                        switch anchor {
                        case .weeklyRhythm:
                            isWeekDetailsExpanded = true
                        case .streakResilience:
                            isSystemsDetailsExpanded = true
                        }
                        DispatchQueue.main.async {
                            withAnimation(LifeBoardAnimation.stateChange) {
                                proxy.scrollTo(anchor, anchor: .top)
                            }
                            pendingDetailAnchor = nil
                        }
                    }
                    .accessibilityIdentifier("home.insights.scroll")
                }
            }
        }
        .accessibilityIdentifier("home.insights.container")
        .onDisappear {
            scrollTraceCoordinator.finishIfNeeded()
        }
        .onAppear { viewModel.onAppear() }
        .onChange(of: viewModel.selectedTab) { _, _ in
            LifeBoardPerformanceTrace.event("InsightsTabSwitch")
            scrollTraceCoordinator.finishIfNeeded()
        }
    }

    private var attentionPillTitle: String {
        let presentation = InsightsTabPresentation.build(
            tab: viewModel.selectedTab,
            viewModel: viewModel,
            momentumGuidanceText: momentumGuidanceText
        )
        return presentation.attentionPillTitle
    }

}

@MainActor
private final class InsightsScrollTraceCoordinator {
    private static let scrollTraceIdleDelayNanoseconds: UInt64 = 250_000_000

    private var interval: LifeBoardPerformanceInterval?
    private var pendingIdleTask: Task<Void, Never>?

    deinit {
        pendingIdleTask?.cancel()
    }

    func recordScrollActivity(oldOffset: CGFloat, newOffset: CGFloat) {
        guard abs(newOffset - oldOffset) > 1 else { return }

        if interval == nil {
            interval = LifeBoardPerformanceTrace.begin("AnalyticsScrollSession")
        }

        pendingIdleTask?.cancel()
        pendingIdleTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.scrollTraceIdleDelayNanoseconds)
            } catch {
                return
            }
            self?.finishIfNeeded()
        }
    }

    func finishIfNeeded() {
        pendingIdleTask?.cancel()
        pendingIdleTask = nil

        guard let interval else { return }
        LifeBoardPerformanceTrace.end(interval)
        self.interval = nil
    }
}
