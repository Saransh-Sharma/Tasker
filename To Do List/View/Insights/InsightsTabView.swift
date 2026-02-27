import SwiftUI

/// Root view for the Insights screen with Today / Week / Systems tabs.
public struct InsightsTabView: View {

    @ObservedObject var viewModel: InsightsViewModel

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    public var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            HStack(spacing: 0) {
                ForEach(InsightsViewModel.InsightsTab.allCases, id: \.self) { tab in
                    Button(action: { viewModel.selectTab(tab) }) {
                        Text(tab.rawValue)
                            .font(.tasker(.callout))
                            .fontWeight(.semibold)
                            .foregroundColor(
                                viewModel.selectedTab == tab
                                    ? Color.tasker.textPrimary
                                    : Color.tasker.textTertiary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, spacing.s8)
                            .background(
                                viewModel.selectedTab == tab
                                    ? Color.tasker.surfacePrimary
                                    : Color.clear
                            )
                            .clipShape(Capsule())
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

            // Tab Content
            ScrollView {
                switch viewModel.selectedTab {
                case .today:
                    InsightsTodayView(viewModel: viewModel)
                        .accessibilityIdentifier("home.insights.content.today")
                case .week:
                    InsightsWeekView(viewModel: viewModel)
                        .accessibilityIdentifier("home.insights.content.week")
                case .systems:
                    InsightsSystemsView(viewModel: viewModel)
                        .accessibilityIdentifier("home.insights.content.systems")
                }
            }
            .accessibilityIdentifier("home.insights.scroll")
        }
        .accessibilityIdentifier("home.insights.container")
        .background(Color.tasker.bgCanvas.ignoresSafeArea())
        .onAppear { viewModel.onAppear() }
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
