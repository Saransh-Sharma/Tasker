import SwiftUI

/// Root view for the Insights screen with Today / Week / Systems tabs.
public struct InsightsTabView: View {

    @ObservedObject var viewModel: InsightsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(InsightsViewModel.InsightsTab.allCases, id: \.self) { tab in
                    Button(action: { viewModel.selectTab(tab) }) {
                        VStack(spacing: spacing.s2) {
                            Text(tab.rawValue)
                                .font(.tasker(.callout))
                                .fontWeight(.semibold)
                                .foregroundColor(
                                    viewModel.selectedTab == tab
                                        ? Color.tasker.textPrimary
                                        : Color.tasker.textTertiary
                                )
                            Text(tabSubtitle(for: tab))
                                .font(.tasker(.caption2))
                                .foregroundColor(
                                    viewModel.selectedTab == tab
                                        ? Color.tasker.textSecondary
                                        : Color.tasker.textQuaternary
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, spacing.s8)
                        .background(
                            Capsule()
                                .fill(
                                    viewModel.selectedTab == tab
                                        ? Color.tasker.surfacePrimary
                                        : Color.clear
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(accessibilityIdentifier(for: tab))
                }
            }
            .padding(4)
            .background(Color.tasker.surfaceTertiary)
            .clipShape(Capsule())
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.vertical, spacing.s12)

            ScrollView {
                ZStack {
                    switch viewModel.selectedTab {
                    case .today:
                        InsightsTodayView(viewModel: viewModel)
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
                .id(viewModel.selectedTab)
                .padding(.bottom, spacing.s16)
            }
            .accessibilityIdentifier("home.insights.scroll")
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.26),
                value: viewModel.selectedTab
            )
        }
        .accessibilityIdentifier("home.insights.container")
        .background(Color.tasker.bgCanvas.ignoresSafeArea())
        .onAppear { viewModel.onAppear() }
    }

    private var contentTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
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
}
