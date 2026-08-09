import SwiftUI

struct HomeScopeSummaryButtonView: View {
    let viewLabel: String
    let accentColor: Color
    let hasActiveFilters: Bool

    var body: some View {
        Image(systemName: "line.3.horizontal.decrease")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.lifeboard.statusWarning)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .accessibilityIdentifier("home.focus.filterButton.nav")
    }
}
