import SwiftUI
import UIKit

/// Header only: evidence rows remain direct children of the owning lazy stack.
struct InsightsEvidenceDisclosure: View {
    @Binding var isExpanded: Bool
    let completenessDescription: String

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(completenessDescription)
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        } label: {
            Label("Evidence", systemImage: "checkmark.shield")
                .lifeboardFont(.headline)
        }
        .padding(16)
        .accessibilityIdentifier("insights.evidence")
    }
}
