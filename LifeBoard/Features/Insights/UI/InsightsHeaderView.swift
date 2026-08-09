import SwiftUI

struct InsightsHeaderView: View {
    let selectedTab: InsightsViewModel.InsightsTab
    let onSelectTab: (InsightsViewModel.InsightsTab) -> Void

    var body: some View {
        SegmentedControl(
            options: InsightsViewModel.InsightsTab.allCases,
            selection: selectedTab,
            title: { $0.rawValue },
            accessibilityIdentifier: accessibilityIdentifier(for:),
            action: onSelectTab
        )
        .accessibilityElement(children: .contain)
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
