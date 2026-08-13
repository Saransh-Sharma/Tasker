import SwiftUI
import UIKit

/// The collapsible evidence list shown under every lens except Experience.
struct InsightsEvidenceDisclosure: View {
    @Binding var isExpanded: Bool
    let completenessDescription: String
    let events: [NormalizedLifeEvent]
    let focusedEvidenceID: UUID?
    let open: (EvidenceReference) -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                Text(completenessDescription)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(.secondary)
                ForEach(events) { event in
                    EvidenceRow(event: event) { evidence in open(evidence) }
                        .id(event.sourceID)
                        .background {
                            if event.sourceID == focusedEvidenceID {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(SemanticColorTokens.foundationSurfaceSelected))
                                    .padding(.horizontal, -8)
                            }
                        }
                }
            }
            .padding(.top, 12)
            .onAppear {
                guard let focusedEvidenceID else { return }
                // Land on the record the deep link named rather than the
                // top of a long, undifferentiated evidence list.
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(focusedEvidenceID, anchor: .center)
                }
            }
        }
        } label: {
            Label("Evidence", systemImage: "checkmark.shield")
                .lifeboardFont(.headline)
        }
        .padding(16)
        .lifeBoardClaySurface(.resting)
        .accessibilityIdentifier("insights.evidence")    }
}
