import SwiftUI

/// Root view for the Insights screen with Today / Week / Systems tabs.
public struct InsightsTabView: View {
    private static let scrollTraceIdleDelayNanoseconds: UInt64 = 250_000_000

    @ObservedObject var viewModel: InsightsViewModel
    let homeProgress: HomeProgressState
    let homeCompletionRate: Double
    let reflectionEligible: Bool
    let momentumGuidanceText: String
    let animateMomentumCard: Bool
    let onOpenReflection: () -> Void
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scrollTraceInterval: TaskerPerformanceInterval?
    @State private var pendingScrollTraceIdleTask: Task<Void, Never>?

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var shouldReduceAnimation: Bool {
        reduceMotion || dynamicTypeSize.isAccessibilitySize || V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text("Insights")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textTertiary)

                    Text("Reflection without overload")
                        .font(.tasker(.title3))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.tasker.textPrimary)

                    Text("Today for execution, Week for patterns, Systems for reliability.")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                tabSelector
            }
            .taskerReadableContent(maxWidth: layoutClass.isPad ? 980 : .infinity, alignment: .center)
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
                            momentumGuidanceText: momentumGuidanceText,
                            animateMomentumCard: animateMomentumCard,
                            onOpenReflection: onOpenReflection
                        )
                            .accessibilityIdentifier("home.insights.content.today")
                            .transition(contentTransition)
                    case .week:
                        InsightsWeekView(viewModel: viewModel)
                            .accessibilityIdentifier("home.insights.content.week")
                            .transition(contentTransition)
                    case .systems:
                        InsightsSystemsView(viewModel: viewModel)
                            .accessibilityIdentifier("home.insights.content.systems")
                            .transition(contentTransition)
                    }
                }
                .taskerReadableContent(maxWidth: layoutClass.isPad ? 980 : .infinity, alignment: .center)
                .padding(.bottom, spacing.s16)
            }
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                },
                action: { oldOffset, newOffset in
                    handleScrollOffsetChange(oldOffset: oldOffset, newOffset: newOffset)
                }
            )
            .onDisappear {
                finishScrollTraceIfNeeded()
            }
            .accessibilityIdentifier("home.insights.scroll")
            .animation(
                shouldReduceAnimation ? nil : .easeOut(duration: 0.18),
                value: viewModel.selectedTab
            )
        }
        .accessibilityIdentifier("home.insights.container")
        .background(Color.tasker.bgCanvas.ignoresSafeArea())
        .onAppear { viewModel.onAppear() }
        .onChange(of: viewModel.selectedTab) { _, _ in
            TaskerPerformanceTrace.event("InsightsTabSwitch")
            finishScrollTraceIfNeeded()
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
                        .font(.tasker(.callout))
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            viewModel.selectedTab == tab
                                ? Color.tasker.textPrimary
                                : Color.tasker.textTertiary
                        )
                    Text(tabSubtitle(for: tab))
                        .font(.tasker(.caption2))
                        .foregroundStyle(
                            viewModel.selectedTab == tab
                                ? Color.tasker.textSecondary
                                : Color.tasker.textQuaternary
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s12)
                .taskerChromeSurface(
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

    private func handleScrollOffsetChange(oldOffset: CGFloat, newOffset: CGFloat) {
        guard abs(newOffset - oldOffset) > 1 else { return }

        if scrollTraceInterval == nil {
            scrollTraceInterval = TaskerPerformanceTrace.begin("AnalyticsScrollSession")
        }

        pendingScrollTraceIdleTask?.cancel()
        pendingScrollTraceIdleTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.scrollTraceIdleDelayNanoseconds)
            } catch {
                return
            }
            finishScrollTraceIfNeeded()
        }
    }

    private func finishScrollTraceIfNeeded() {
        pendingScrollTraceIdleTask?.cancel()
        pendingScrollTraceIdleTask = nil

        if let scrollTraceInterval {
            TaskerPerformanceTrace.end(scrollTraceInterval)
            self.scrollTraceInterval = nil
        }
    }

    private var contentTransition: AnyTransition {
        .opacity
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
            return Color.tasker.accentPrimary
        case .week:
            return Color.tasker.accentSecondary
        case .systems:
            return Color.tasker.statusSuccess
        }
    }
}
