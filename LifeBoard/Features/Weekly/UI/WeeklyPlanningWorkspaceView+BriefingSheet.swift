import SwiftUI

struct WeeklyWorkspaceBriefingSheet: View {
    let briefing: WeeklyOverdueBriefing
    @Binding var showsBriefing: Bool
    /// Runs at once. Moving work to Someday is reversible, so it takes effect
    /// immediately and the workspace's receipt offers Undo — the same path the
    /// tray's per-task "Let them go to Someday" already used.
    let onReleaseAll: () -> Void
    @Binding var lane: WeeklyWorkspaceLane
    let onSpread: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(briefing.headline)
                .lifeboardFont(.title2)
            if let detail = briefing.detail() {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Text("Stops when the week is full.")
                .font(.footnote)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))

            VStack(spacing: 12) {
                Button {
                    onSpread()
                } label: {
                    Text(WeeklyWorkspaceCopy.spreadAction)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .accessibilityIdentifier("plan.week.workspace.spread")

                Button {
                    showsBriefing = false
                    onReleaseAll()
                } label: {
                    Text(WeeklyWorkspaceCopy.bankruptcyAction)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.lifeBoardChip)
                .accessibilityIdentifier("plan.week.workspace.bankruptcy")

                Button {
                    showsBriefing = false
                    lane = .overdue
                } label: {
                    Text(WeeklyWorkspaceCopy.manualAction)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .font(.subheadline)
            }
            Spacer()
        }
        .padding(24)
        .background(Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea())
        .presentationDetents([.medium])
        .accessibilityIdentifier("plan.week.workspace.briefing")
    }
}
