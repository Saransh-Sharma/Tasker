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
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @State private var scrollTraceCoordinator = InsightsScrollTraceCoordinator()

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text("Insights")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textTertiary)

                    Text("Reflection without overload")
                        .font(.lifeboard(.title3))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard.textPrimary)

                    Text("Today for execution, Week for patterns, Systems for reliability.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                }

                tabSelector
            }
            .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 980 : .infinity, alignment: .center)
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.vertical, spacing.s12)

            ScrollView {
                ZStack {
                    switch viewModel.selectedTab {
                    case .today:
                        InsightsTodayView(
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
                        InsightsWeekView(viewModel: viewModel)
                            .accessibilityIdentifier("home.insights.content.week")
                    case .systems:
                        InsightsSystemsView(viewModel: viewModel)
                            .accessibilityIdentifier("home.insights.content.systems")
                    }
                }
                .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 980 : .infinity, alignment: .center)
                .padding(.bottom, spacing.s16)
            }
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
            .onDisappear {
                scrollTraceCoordinator.finishIfNeeded()
            }
            .accessibilityIdentifier("home.insights.scroll")
        }
        .accessibilityIdentifier("home.insights.container")
        .background(Color.lifeboard.bgCanvas.ignoresSafeArea())
        .onAppear { viewModel.onAppear() }
        .onChange(of: viewModel.selectedTab) { _, _ in
            LifeBoardPerformanceTrace.event("InsightsTabSwitch")
            scrollTraceCoordinator.finishIfNeeded()
        }
    }

    private var tabSelector: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing.s8) {
                tabButtons
            }

            VStack(spacing: spacing.s8) {
                tabButtons
            }
        }
    }

    private var tabButtons: some View {
        ForEach(InsightsViewModel.InsightsTab.allCases, id: \.self) { tab in
            Button(action: { viewModel.selectTab(tab) }) {
                VStack(alignment: .leading, spacing: spacing.s2) {
                    Text(tab.rawValue)
                        .font(.lifeboard(.callout))
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            viewModel.selectedTab == tab
                                ? Color.lifeboard.textPrimary
                                : Color.lifeboard.textTertiary
                        )
                    Text(tabSubtitle(for: tab))
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(
                            viewModel.selectedTab == tab
                                ? Color.lifeboard.textSecondary
                                : Color.lifeboard.textQuaternary
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s12)
                .lifeboardChromeSurface(
                    cornerRadius: 18,
                    accentColor: accentColor(for: tab),
                    level: .e1
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(viewModel.selectedTab == tab ? accentColor(for: tab).opacity(0.14) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            viewModel.selectedTab == tab
                                ? accentColor(for: tab).opacity(0.26)
                                : Color.clear,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityIdentifier(accessibilityIdentifier(for: tab))
            .accessibilityAddTraits(viewModel.selectedTab == tab ? .isSelected : [])
        }
    }

    private func tabSubtitle(for tab: InsightsViewModel.InsightsTab) -> String {
        switch tab {
        case .today:
            return "Momentum"
        case .week:
            return "Patterns"
        case .systems:
            return "Health"
        }
    }

    private func accessibilityIdentifier(for tab: InsightsViewModel.InsightsTab) -> String {
        switch tab {
        case .today:
            return "home.insights.tab.today"
        case .week:
            return "home.insights.tab.week"
        case .systems:
            return "home.insights.tab.systems"
        }
    }

    private func accentColor(for tab: InsightsViewModel.InsightsTab) -> Color {
        switch tab {
        case .today:
            return Color.lifeboard.accentPrimary
        case .week:
            return Color.lifeboard.accentSecondary
        case .systems:
            return Color.lifeboard.statusSuccess
        }
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
